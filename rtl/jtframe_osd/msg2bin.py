# Re-implements jtframe's msg.go encoder (jotego/jtcores,
# modules/jtframe/src/jtframe/msg/msg.go) so mrdo can build a jtframe_credits
# msg.hex without the Go toolchain. Matches its exact bit layout:
#   per-character 9-bit word = (palette<<7) | ((ascii - 0x20) & 0x7f)
#   palette: \R=0 \G=1 \B=2 \W=3 (default 3/white)
#   each source line -> 32 fixed-width columns, padded with palette-3 space
#   (space=0x20 -> coded 0, so pad value is exactly (3<<7)|0 = 0x180)
#   total data rounded up to the next 1024-entry (1 page) boundary with 0x0000
import sys

SRC = r"D:\Arcade\AI\aCORES\mrdo\rtl\jtframe_osd\msg.txt"
# jtframe_credits.v's own RAM instance hardcodes SYNFILE("msg.bin") with
# ASCII_BIN(1) -- i.e. $readmemb, one 9-bit ASCII binary string per line, NOT
# hex. Filename and format must match exactly for the vendored, unmodified
# jtframe_credits.v to find and parse it correctly.
OUT = r"D:\Arcade\AI\aCORES\mrdo\rtl\jtframe_osd\msg.bin"

PAL = {'R': 0, 'G': 1, 'B': 2, 'W': 3}

data = []
with open(SRC, encoding='utf-8') as f:
    for lineno, raw in enumerate(f.read().split('\n'), 1):
        line = raw.rstrip('\r')
        col = [0] * 32
        pal = 3
        i = 0
        n = 0
        it = iter(range(len(line)))
        idx = 0
        while idx < len(line):
            c = line[idx]
            if c == '\\':
                idx += 1
                if idx >= len(line):
                    raise ValueError(f"line {lineno}: trailing backslash")
                esc = line[idx]
                if esc not in PAL:
                    raise ValueError(f"line {lineno}: invalid palette code \\{esc}")
                pal = PAL[esc]
                idx += 1
                continue
            code = ord(c)
            if code < 0x20 or code > 0x7f:
                raise ValueError(f"line {lineno}: character code out of range: {c!r}")
            if n == 32:
                raise ValueError(f"line {lineno}: longer than 32 characters")
            col[n] = (pal << 7) | ((code - 0x20) & 0x7f)
            n += 1
            idx += 1
        data.extend(col)

# round up to next 1024-entry page
rest = len(data) % 1024
if rest != 0:
    data.extend([0] * (1024 - rest))

with open(OUT, 'w', encoding='utf-8') as f:
    for v in data:
        f.write(f"{v:09b}\n")

print(f"{len(data)} entries ({len(data)//1024} page(s)) written to {OUT}")
