"""Fix broken toast call tails: ');),  '););  ');,  """
import re
from pathlib import Path

ROOTS = [
    Path(r"D:/laragon/www/playbook/kocourt_flutter/lib"),
    Path(r"D:/laragon/www/playbook/kocourt_owner/lib"),
]

# After a toast call, collapse junk closers into a single semicolon.
# Matches: toastX(...)<junk> where junk is , ; ) combinations
PAT = re.compile(
    r"(toast(?:Success|Error|Info|Warning)\((?:[^;()]|\([^;()]*\))*\))"
    r"(?:\s*[;,\)])+",
)

for root in ROOTS:
    for path in root.rglob("*.dart"):
        text = path.read_text(encoding="utf-8")
        new, n = PAT.subn(r"\1;", text)
        if n:
            # Also remove orphan lines that are only `);` after a toast (common corruption)
            lines = new.splitlines(keepends=True)
            cleaned = []
            for i, line in enumerate(lines):
                stripped = line.strip()
                if stripped in {");", ");,", "););"} and i > 0 and "toast" in lines[i - 1]:
                    continue
                cleaned.append(line)
            path.write_text("".join(cleaned), encoding="utf-8")
            print(n, path)
