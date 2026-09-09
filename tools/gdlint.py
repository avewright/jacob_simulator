#!/usr/bin/env python3
"""Static checks for the GDScript in this project.

Godot is not installed in the environment this game is usually edited from, so
nothing here can be run before it reaches the player. These are the parse
errors that have actually got through, each one added after it broke a build:

  arity        Vector3(a, b) and friends - a wrong argument count is a parse
               error, not a runtime one.
  inference    `var x := <expr>` where the expression is Variant. The usual
               source is a loop variable bound to a bare array literal:
               `for side in [-1.0, 1.0]` makes `side` Variant, so
               `var a := side * FOUL` cannot infer. Fix by typing the loop
               variable: `for side: float in [...]`.
  undefined    a call to a _method that no function in the file defines.
  collision    a member and a function sharing a name.
  colons       a block header with no trailing colon.
  indent       spaces mixed into leading tabs.
  paths        a res:// reference with no file behind it.

Ternaries with typed branches and `as` casts read as Variant to a regex but
compile fine, so KNOWN_OK lists the ones already checked by hand.

    python3 tools/gdlint.py          # exit 1 if anything new is found
"""

import glob
import os
import re
import sys

ARITY = {
    "Vector2": (2,), "Vector3": (3,), "Vector2i": (2,), "Vector3i": (3,),
    "Color": (1, 2, 3, 4), "Rect2": (2, 3, 4), "Basis": (2, 3),
    "Transform2D": (1, 2, 3, 4), "Transform3D": (2, 4), "Quaternion": (2, 3, 4),
}

# Verified by hand: typed ternary branches, or an `as` cast, or a typed array.
KNOWN_OK = {
    "scripts/games/tennis_match.gd:497",   # _trail is Array[MeshInstance3D]
    "scripts/jacob_look.gd:261",           # lump[0] is a Vector3, copy ctor
    "scripts/jacob_look.gd:342",           # ... as MeshInstance3D
    "scripts/jacob_look.gd:353",           # ... as MeshInstance3D
    "scripts/chastain_place.gd:272",       # both ternary branches are float
    "scripts/chastain_place.gd:433",       # both ternary branches are float
    "scripts/chastain_place.gd:460",       # both ternary branches are Vector3
}


def strip_comment(line: str) -> str:
    """Drop a trailing # comment without touching a # inside a string."""
    out, quote = "", None
    for i, ch in enumerate(line):
        if quote:
            out += ch
            if ch == quote and line[i - 1] != "\\":
                quote = None
        elif ch in "\"'":
            quote = ch
            out += ch
        elif ch == "#":
            break
        else:
            out += ch
    return out


def split_args(text: str) -> list:
    depth, current, out = 0, "", []
    for ch in text:
        if ch in "([{":
            depth += 1
        elif ch in ")]}":
            depth -= 1
        if ch == "," and depth == 0:
            out.append(current)
            current = ""
        else:
            current += ch
    if current.strip():
        out.append(current)
    return out


def check(path: str) -> list:
    src = open(path).read()
    lines = src.split("\n")
    found = []

    funcs = set(re.findall(r"^\s*(?:static\s+)?func\s+(\w+)", src, re.M))
    members = (set(re.findall(r"^\s*(?:@\w+\s+)?(?:static\s+)?var\s+(\w+)", src, re.M))
               | set(re.findall(r"^\s*const\s+(\w+)", src, re.M))
               | set(re.findall(r"^\s*signal\s+(\w+)", src, re.M)))
    top = (set(re.findall(r"^(?:@\w+\s+)?(?:static\s+)?var\s+(\w+)", src, re.M))
           | set(re.findall(r"^const\s+(\w+)", src, re.M)))
    for name in sorted(top & funcs):
        found.append((path, 0, "collision", "'%s' is both a member and a func" % name))

    # Loop variables bound to a bare literal are Variant until they are typed.
    variants = []
    for n, raw in enumerate(lines, 1):
        line = strip_comment(raw)
        indent = len(raw) - len(raw.lstrip("\t"))
        if raw.strip():
            variants = [(v, i) for v, i in variants if i < indent]

        loop = re.match(r"\s*for\s+(\w+)\s+in\s*(\[|\{)", line)
        if loop:
            variants.append((loop.group(1), indent))
        else:
            infer = re.match(r"\s*var\s+(\w+)\s*:=\s*(.+)$", line)
            if infer:
                for var, _ in variants:
                    if re.search(r"(?<![\w.])%s(?![\w])" % re.escape(var), infer.group(2)):
                        found.append((path, n, "inference",
                                      "var %s := ... uses untyped loop var '%s' (write "
                                      "`for %s: <type> in [...]`)" % (infer.group(1), var, var)))
                        break
        if re.search(r"\bvar\s+\w+\s*:=\s*\w+\[", line):
            found.append((path, n, "inference", "var ... := <indexed>, which is Variant"))

        for m in re.finditer(r"\b(%s)\(" % "|".join(ARITY), line):
            name, i, depth, j = m.group(1), m.end(), 1, m.end()
            while j < len(line) and depth > 0:
                if line[j] == "(":
                    depth += 1
                elif line[j] == ")":
                    depth -= 1
                j += 1
            if depth != 0:
                continue
            count = len(split_args(line[i:j - 1]))
            if count and count not in ARITY[name]:
                found.append((path, n, "arity", "%s takes %s args, given %d"
                              % (name, "/".join(str(a) for a in ARITY[name]), count)))

        for m in re.finditer(r"(?<![\w.])(_\w+)\s*\(", line):
            if m.group(1) not in funcs | members and not m.group(1).startswith("__"):
                found.append((path, n, "undefined", "no %s() in this file" % m.group(1)))

        # A header spanning several lines has its colon further down, so only
        # judge one whose brackets already balance.
        if (re.match(r"\s*(func|if|elif|else|for|while|match|class)\b", line)
                and sum(line.count(c) for c in "([{") == sum(line.count(c) for c in ")]}")
                and not line.rstrip().endswith((":", "\\", ","))):
            found.append((path, n, "colons", raw.strip()))

        lead = raw[:len(raw) - len(raw.lstrip())]
        if "\t" in lead and " " in lead:
            found.append((path, n, "indent", "spaces mixed into leading tabs"))
    return found


def main() -> int:
    root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    os.chdir(root)
    problems = []
    scripts = sorted(glob.glob("scripts/**/*.gd", recursive=True))
    for path in scripts:
        problems += check(path)

    for path in scripts + sorted(glob.glob("scenes/**/*.tscn", recursive=True)) + ["project.godot"]:
        for m in re.finditer(r"res://([\w/.\-]+)", open(path).read()):
            if not os.path.exists(m.group(1)):
                problems.append((path, 0, "paths", "missing %s" % m.group(0)))

    problems = [p for p in problems if "%s:%d" % (p[0], p[1]) not in KNOWN_OK]
    for path, line, kind, detail in problems:
        print("%s:%d  %s: %s" % (path, line, kind, detail))
    print("%d scripts checked, %d problem%s"
          % (len(scripts), len(problems), "" if len(problems) == 1 else "s"))
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
