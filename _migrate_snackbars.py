import re
from pathlib import Path

ROOTS = [
    Path(r"D:/laragon/www/playbook/kocourt_flutter/lib"),
    Path(r"D:/laragon/www/playbook/kocourt_owner/lib"),
    Path(r"D:/laragon/www/playbook/kocourt_shared/lib"),
]

SNACK = re.compile(
    r"ScaffoldMessenger\.of\((?P<ctx>[^)]+)\)\.showSnackBar\(\s*(?:const\s+)?SnackBar\(\s*"
    r"content:\s*Text\((?P<msg>(?:'[^']*'|\"[^\"]*\"|[^,)]+))\)(?P<rest>.*?)\)\s*\)",
    re.S,
)


def classify(rest: str, msg: str) -> str:
    r = rest or ""
    if "AppColors.error" in r or "Colors.red" in r:
        return "toastError"
    if "AppColors.secondary" in r:
        return "toastSuccess"
    low = msg.lower()
    if any(
        w in low
        for w in [
            "fail",
            "could not",
            "couldn't",
            "error",
            "unable",
            "invalid",
            "need",
            "add a",
            "add the",
            "please sign",
        ]
    ):
        return "toastError"
    if any(
        w in low
        for w in [
            "saved",
            "renew",
            "copied",
            "success",
            "updated",
            "added",
            "done",
            "sent",
            "published",
            "checked",
        ]
    ):
        return "toastSuccess"
    return "toastInfo"


changed = []
for root in ROOTS:
    for path in root.rglob("*.dart"):
        text = path.read_text(encoding="utf-8")
        if "showSnackBar" not in text:
            continue

        def repl(m: re.Match) -> str:
            ctx = m.group("ctx").strip()
            msg = m.group("msg").strip()
            rest = m.group("rest") or ""
            method = classify(rest, msg)
            return f"{ctx}.{method}({msg})"

        new, n = SNACK.subn(repl, text)
        if n:
            path.write_text(new, encoding="utf-8")
            changed.append((str(path), n))

print(f"updated {len(changed)} files")
for p, n in changed:
    print(f"  {n}: {p}")
