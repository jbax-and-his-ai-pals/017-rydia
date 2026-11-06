"""Export where every monster appears in random encounters.

Usage: python tools/export_encounters.py

Writes data/encounters.csv (one row per area x slot x species) and the player
summary notes/monster-locations.md. Reads the clean ROM only; the capturable
column comes from data/monsters.csv.

Chain: area -> encounter set -> 8 formation slots -> species. The tables and the
slot odds are read by the field encounter routine at $00:894D-$00:8B2A; see
notes/addresses.md, section L14.
"""

import csv
import re
from collections import defaultdict, deque

from audit_access import locations
from ff4rom import ROOT, Rom, decode

FORMATIONS, NAMES, SPECIES = 0x0E8000, 0x0E9800, 0xE0
TITLES, PROPS = 0x159620, 0x159C84            # map title list; 13-byte map properties (byte 11 = title)
EXIT_PTRS, EXITS, MAPS = 0x158000, 0x158300, 0x180  # 5-byte records: x, y, map, dest x, dest y

SURFACE_RATE, SURFACE_SET = 0x0EC300, 0x0EC542  # 8x8 grid of 32x32 regions
UNDER_RATE, UNDER_SET = 0x0EC340, 0x0EC582      # one rate; 4x4 grid of 32x32 regions
MOON_RATE, MOON_SET = 0x0EC341, 0x0EC592        # one rate; 2x2 grid of 32x32 regions
MAP_RATE, MAP_SET = 0x0EC342, 0x0EC596          # per map; rate 0 = no encounters
WORLD_SLOTS, MAP_SLOTS = 0x0EC796, 0x0EC816     # 8 formation numbers per set
SLOT_WEIGHTS = (43, 43, 43, 43, 32, 32, 16, 4)  # out of 256, thresholds at $00:8B05

WORLDS = ("surface", "underworld", "moon")
GRIDS = {"surface": (SURFACE_RATE, SURFACE_SET, 8, 8, True),
         "underworld": (UNDER_RATE, UNDER_SET, 4, 4, False),
         "moon": (MOON_RATE, MOON_SET, 2, 2, False)}

CSV_OUT = ROOT / "data" / "encounters.csv"
REPORT = ROOT / "notes" / "monster-locations.md"
FIELDS = ["world", "kind", "area", "area_name", "from_world_map", "rate", "set", "slot", "slot_chance",
          "formation", "can_run", "species", "species_name", "count"]


def formation(rom: Rom, f: int):
    """[(species, count)] and can-run for formation f (layout in addresses.md, L12)."""
    b = rom.read(FORMATIONS + 8 * f, 8)
    counts = ((b[4] >> 6) & 3, (b[4] >> 4) & 3, (b[4] >> 2) & 3)
    return [(s, c) for s, c in zip(b[1:4], counts) if c and s < SPECIES], not b[6] & 1


def map_titles(rom: Rom) -> list[str]:
    titles = [decode(t) for t in rom.read(TITLES, 0x4D1).split(b"\x00")]
    out = []
    for m in range(MAPS):
        i = rom.u8(PROPS + 13 * m + 11)
        out.append(titles[i] if i < len(titles) else "")
    return out


ALIASES = {"Mouth": "Giant of Babil"}  # the Giant's rooms are titled Mouth, Neck, Chest, ...
STORY_ONLY = {"Giant of Babil"}         # door-linked, but its arc is done in the late-game state
FLOOR = re.compile(r"[\s-]*(B?\d+F|B\d+|\d+(st|nd|rd|th) station)$")


def place_name(title: str) -> str:
    """Dungeon name from a map title: 'Tower of Bab-il 1F' -> 'Tower of Bab-il', 'B3F' -> ''."""
    name = FLOOR.sub("", title)
    return ALIASES.get(name, name) if len(name) > 2 else ""  # some rooms are titled just "D"


def proper(name: str, parent: str) -> bool:
    """Does a title start a new place under parent? Floors and one-word rooms
    ('Summit', 'Neck') don't; 'Pass to Bab-il' does."""
    return " " in name and not name.startswith(parent) and not parent.startswith(name)


def map_places(rom: Rom, entrances: list[dict], titles: list[str]) -> dict[int, dict]:
    """Name every map after its dungeon by walking doors out from each world-map
    entrance. Maps no door chain reaches (entered by a scene) are named from
    their own or a door-linked neighbour's title, with linked=False."""
    ptrs = [rom.u16(EXIT_PTRS + 2 * m) for m in range(MAPS)] + [None]
    exits, triggers = defaultdict(set), {}
    for m in range(MAPS):
        start = ptrs[m]
        end = ptrs[m + 1] if ptrs[m + 1] is not None and ptrs[m + 1] >= start else start
        triggers[m] = (end - start) // 5
        for k in range(start, end, 5):
            dest = rom.u8(EXITS + k + 2)
            if dest < 0xFB:  # $FB world map, $FE treasure, $FF event
                exits[m].add(dest | (m & 0x100))

    info, queue = {}, deque()

    def walk():
        while queue:
            m = queue.popleft()
            for d in sorted(exits[m]):
                if d < MAPS and d not in info:
                    own = place_name(titles[d])
                    parent = info[m]["place"]
                    info[d] = {**info[m], "place": own if proper(own, parent) else parent}
                    queue.append(d)

    for e in entrances:
        info[e["map"]] = {"place": place_name(titles[e["map"]]) or e["name"], "world": e["world"], "linked": True}
        queue.append(e["map"])
    walk()
    linked = sorted(m for m in info if m & 0x100)
    # Second pass, for maps entered by a scene: a map whose door leads into a
    # named map belongs to that place; otherwise a titled map names itself.
    changed = True
    while changed:
        changed = False
        for m in range(MAPS):
            if m in info:
                continue
            own = place_name(titles[m])
            into = [info[d] for d in sorted(exits[m]) if d in info]
            if not (own or into):
                continue
            if into:
                base = into[0]
                place, world = (own if own and proper(own, base["place"]) else base["place"]), base["world"]
            else:  # underworld or moon: same world as the nearest door-linked map number
                place = own
                world = info[min(linked, key=lambda n: abs(n - m))]["world"] if m & 0x100 else "surface"
            info[m] = {"place": place, "world": world, "linked": False}
            queue.append(m)
            walk()
            changed = True
    for m in range(MAPS):  # no title and no doors to anything named
        if m not in info:
            world = info[min(linked, key=lambda n: abs(n - m))]["world"] if m & 0x100 else "surface"
            place = f"unknown map {m:03X}" if triggers[m] else f"map {m:03X} (no map-trigger records)"
            info[m] = {"place": place, "world": world, "linked": False}
    return info


def world_areas(rom: Rom, entrances: list[dict], titles: list[str]):
    for world, (rate_at, set_at, cols, rows, per_region_rate) in GRIDS.items():
        # Landmarks: titled entrances, minus story-only ones
        marks = [{**e, "name": place_name(titles[e["map"]])} for e in entrances if e["world"] == world]
        marks = [e for e in marks if e["name"] and e["name"] not in STORY_ONLY]
        for region in range(cols * rows):
            rx, ry = region % cols, region // cols
            inside = [e["name"] for e in marks if e["x"] // 32 == rx and e["y"] // 32 == ry]
            if inside:
                name = ", ".join(inside)
            else:
                cx, cy = 32 * rx + 16, 32 * ry + 16
                near = min(marks, key=lambda e: (e["x"] - cx) ** 2 + (e["y"] - cy) ** 2)
                name = f"near {near['name']}"
            s = rom.u8(set_at + region)
            yield {"world": world, "kind": "region", "area": f"{rx},{ry}", "area_name": name,
                   "from_world_map": "y", "rate": rom.u8(rate_at + (region if per_region_rate else 0)),
                   "set": s, "slots": list(rom.read(WORLD_SLOTS + 8 * s, 8)),
                   "high": 0 if world == "surface" else 0x100, "inside": inside}


def map_areas(rom: Rom, entrances: list[dict], titles: list[str]):
    info = map_places(rom, entrances, titles)
    for m in range(MAPS):
        rate = rom.u8(MAP_RATE + m)
        if not rate:
            continue
        own = titles[m]
        where = info[m]
        place = where["place"]
        if not own:
            floor = "unnamed room"
        elif own == place:
            floor = ""
        elif own.startswith(place) and own[len(place)] in " -":
            floor = own[len(place):].strip(" -")
        else:
            floor = own
        s = rom.u8(MAP_SET + m)
        yield {"world": where["world"], "kind": "map", "area": f"{m:03X}",
               "area_name": f"{place}: {floor}" if floor else place,
               "from_world_map": "y" if where["linked"] else "n", "rate": rate, "set": s,
               "slots": list(rom.read(MAP_SLOTS + 8 * s, 8)), "high": m & 0x100,
               "place": place, "floor": floor}


def export(rom: Rom):
    names = [decode(rom.read(NAMES + 8 * s, 8)) for s in range(SPECIES)]
    entrances, titles = locations(rom), map_titles(rom)
    areas = list(world_areas(rom, entrances, titles)) + list(map_areas(rom, entrances, titles))
    rows = []
    for a in areas:
        for slot, f in enumerate(a["slots"]):
            f |= a["high"]
            monsters, can_run = formation(rom, f)
            for s, c in monsters:
                rows.append({**{k: a[k] for k in FIELDS if k in a}, "slot": slot,
                             "slot_chance": SLOT_WEIGHTS[slot], "formation": f"{f:03X}",
                             "can_run": "y" if can_run else "n", "species": f"{s:02X}",
                             "species_name": names[s], "count": c})
    return areas, rows, names


def chances(rows):
    """{(world, kind, area): {species: chance out of 256 that a fight includes it}}"""
    seen = defaultdict(dict)  # (area key, slot) -> species, so a species counts once per slot
    for r in rows:
        seen[(r["world"], r["kind"], r["area"], r["slot"])][int(r["species"], 16)] = r["slot_chance"]
    out = defaultdict(lambda: defaultdict(int))
    for (w, k, a, _slot), species in seen.items():
        for s, weight in species.items():
            out[(w, k, a)][s] += weight
    return out


def pct(weight: int) -> str:
    return f"{round(100 * weight / 256)}%" if weight >= 3 else "<1%"


def report(rom: Rom, areas, rows, names) -> list[str]:
    with (ROOT / "data" / "monsters.csv").open(newline="", encoding="utf-8") as f:
        capturable = {r["id"] for r in csv.DictReader(f) if r["capturable"] == "y"}
    odds = chances(rows)
    by_key = {(a["world"], a["kind"], a["area"]): a for a in areas}
    dupes = {n for n in names if names.count(n) > 1}
    label = [f"{n} ({s:02X})" if n in dupes else n for s, n in enumerate(names)]

    # Group world regions by set, maps by home location; keep each species' best odds per place.
    places = defaultdict(lambda: defaultdict(dict))  # world -> species -> place -> (weight, detail)
    linked_only = defaultdict(set)
    for key, species in odds.items():
        a = by_key[key]
        if a["kind"] == "region":
            place, detail, open_ = ("world map", a["set"]), "", True
        else:
            open_ = a["from_world_map"] == "y" and a["place"] not in STORY_ONLY
            place, detail = (a["place"], open_), a["floor"]
        for s, w in species.items():
            best = places[a["world"]][s].get(place)
            if best is None or w > best[0]:
                places[a["world"]][s][place] = (w, detail)
            if open_:
                linked_only[s].add(a["world"])

    # Describe each world-map encounter list by the entrances in its regions,
    # or by the nearest entrances when its regions hold none.
    set_marks = defaultdict(lambda: ([], []))
    for a in areas:
        if a["kind"] == "region":
            inside, near = set_marks[(a["world"], a["set"])]
            for n in a["inside"] or []:
                if n not in inside:
                    inside.append(n)
            if not a["inside"] and a["area_name"][5:] not in near:
                near.append(a["area_name"][5:])

    def place_text(world, place, w, detail):
        if place[0] == "world map":
            inside, near = set_marks[(world, place[1])]
            where = "/".join(inside[:3]) if inside else "near " + "/".join(near[:3])
            return f"world map ({where}) {pct(w)}"
        flag = "" if place[1] else " †"
        return f"{place[0]}{flag} {pct(w)}" + (f" ({detail})" if detail and detail != place[0] else "")

    out = ["# Where to find each monster",
           "",
           "Generated by `python tools/export_encounters.py` from the clean ROM; don't edit by hand. "
           "Per-slot data is in [../data/encounters.csv](../data/encounters.csv).",
           "",
           "- Each place lists the chance that a random fight there includes the monster.",
           "  - Locations show their best floor. World-map areas that share an encounter list are merged.",
           "  - How often fights happen differs by place too; the `rate` column in the CSV has it.",
           "- **†** marks places that may be out of reach in this hack:",
           "  - no chain of doors links them to a world-map entrance, so a scene or warp takes you there "
           "(Tower of Zot, Lunar Subterrane, most of the underworld Tower of Bab-il)",
           "  - or they're story-only: the Giant of Babil, whose arc counts as done in the late-game state.",
           "- \"unknown map\" rooms have no title and no doors to a named map. "
           "\"No map-trigger records\" means no door, exit or event-call records in the map-trigger table; "
           "scripts, scenes or warps may still load those maps. This does not establish that a map is unused.",
           "- Only `capturable=y` species from `data/monsters.csv` are listed.",
           ""]
    listed = set()
    for world in WORLDS:
        species = sorted((s for s in places[world] if f"{s:02X}" in capturable), key=lambda s: label[s])
        if not species:
            continue
        out += [f"## {world.capitalize()}", "", "| Monster | Where |", "| --- | --- |"]
        for s in species:
            ranked = sorted(places[world][s].items(), key=lambda kv: -kv[1][0])
            cells = [place_text(world, p, w, d) for p, (w, d) in ranked]
            out.append(f"| {label[s]} | {'; '.join(cells)} |")
            listed.add(s)
        out.append("")

    never = sorted((int(s, 16) for s in capturable if int(s, 16) not in listed), key=lambda s: label[s])
    scene_only = sorted((s for s in listed if f"{s:02X}" in capturable and not linked_only[s]), key=lambda s: label[s])
    forms = defaultdict(list)
    for f in range(0x200):
        for s, _c in formation(rom, f)[0]:
            forms[s].append(f"{f:03X}")
    out += ["## Not in random encounters", ""]
    if never:
        out += ["Capturable, but no random fight includes them; only scripted fights (formations listed).", "",
                "| Monster | Formations |", "| --- | --- |"]
        out += [f"| {label[s]} | {', '.join(f'`{f}`' for f in forms[s]) or 'none'} |" for s in never]
    else:
        out.append("None: every capturable species is in at least one random encounter list.")
    out += ["", "## Only in places marked †", "",
            "Capturable species whose random fights are all in † places. "
            "If those places are out of reach, these can't be collected.", "",
            "| Monster | Where |", "| --- | --- |"]
    for s in scene_only:
        where = sorted({p[0] for w in WORLDS for p in places[w].get(s, {})})
        out.append(f"| {label[s]} | {', '.join(where)} |")
    if not scene_only:
        out.append("| none | |")
    out.append("")
    linked = len([s for s in listed if f"{s:02X}" in capturable])
    out += [f"Check: {linked} capturable species listed by world + {len(never)} not in random encounters "
            f"= {linked + len(never)} of {len(capturable)}.", ""]
    assert linked + len(never) == len(capturable)
    return out


def main() -> None:
    rom = Rom()
    areas, rows, names = export(rom)
    with CSV_OUT.open("w", newline="", encoding="utf-8") as f:
        w = csv.DictWriter(f, fieldnames=FIELDS)
        w.writeheader()
        w.writerows(rows)
    REPORT.write_text("\n".join(report(rom, areas, rows, names)), encoding="utf-8")
    print(f"{len(rows)} rows from {len(areas)} areas -> {CSV_OUT.relative_to(ROOT)}, {REPORT.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
