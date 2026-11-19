from pathlib import Path
for r in [Path("kocourt_flutter/lib"), Path("kocourt_owner/lib"), Path("kocourt_shared/lib")]:
    for p in r.rglob("*.dart"):
        t = p.read_text(encoding="utf-8")
        if "showSnackBar" in t:
            print("SNACK", p)
