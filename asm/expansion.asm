; The ROM is padded to 2 MiB with $FF by tools/build.py before assembly.
; The ROM size field is log2(size in KiB): $0A = 1 MiB, $0B = 2 MiB.
org $00FFD7
    db $0B
