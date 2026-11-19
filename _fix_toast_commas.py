import re
from pathlib import Path

ROOTS = [
    Path(r"D:/laragon/www/playbook/kocourt_flutter/lib"),
    Path(r"D:/laragon/www/playbook/kocourt_owner/lib"),
    Path(r"D:/laragon/www/playbook/kocourt_shared/lib"),
]

# toastX(...),  -> toastX(...);
# toastX(...),); -> toastX(...);
PAT = re.compile(
    r"(toast(?:Success|Error|Info|Warning)\((?:[^()]|\([^()]*\))*\))\s*,\s*\)?;?"
)

nfiles = 0
for root in ROOTS:
    for path in root.rglob("*.dart"):
        text = path.read_text(encoding="utf-8")
        new, n = PAT.subn(r"\1;", text)
        if n:
            path.write_text(new, encoding="utf-8")
            nfiles += 1
            print(n, path)
print("files", nfiles)
