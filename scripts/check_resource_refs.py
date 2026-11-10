#!/usr/bin/env python3
"""
Static resource-reference check — no Connect IQ SDK required.

Scans source/*.mc and every resources*/**.xml file for references like
Rez.Drawables.X, @Strings.X, getProperty("X"), etc., and checks that each
referenced id is actually defined somewhere in the resource XML files.
This catches dangling references (typos, removed-but-still-referenced
resources) without needing to compile. It does NOT catch everything a
real compile would (e.g. per-device missing resources, unused resources,
type errors) — see scripts/compile-check.sh for that.
"""
import re
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent


def check_xml_well_formed():
    bad = []
    files = list(ROOT.glob("resources*/**/*.xml")) + [ROOT / "manifest.xml"]
    for xml_file in files:
        try:
            ET.parse(xml_file)
        except ET.ParseError as e:
            bad.append((xml_file, str(e)))
    if bad:
        print("Malformed XML found:\n")
        for f, err in bad:
            print(f"  {f.relative_to(ROOT)}: {err}")
        return False
    print(f"OK: {len(files)} XML files are well-formed.")
    return True

DEFINING_TAG_RE = re.compile(r'<(?:bitmap|font|string|property|layout|menu)\b[^>]*\bid="([^"]+)"')
REZ_REF_RE = re.compile(r'Rez\.(?:Drawables|Strings|Fonts|Properties|Menus|Layouts)\.(\w+)')
AT_REF_RE = re.compile(r'@(?:Strings|Properties|Drawables|Fonts)\.(\w+)')
GET_PROPERTY_RE = re.compile(r'getProperty\("(\w+)"\)')


def find_defined_ids():
    defined = set()
    for xml_file in ROOT.glob("resources*/**/*.xml"):
        text = xml_file.read_text(encoding="utf-8")
        for m in DEFINING_TAG_RE.finditer(text):
            defined.add(m.group(1))
    return defined


def find_referenced_ids():
    referenced = {}  # id -> list of (file, snippet)

    def add(ids_iter, path):
        for rid in ids_iter:
            referenced.setdefault(rid, []).append(str(path.relative_to(ROOT)))

    for mc_file in ROOT.glob("source*/**/*.mc"):
        text = mc_file.read_text(encoding="utf-8")
        add((m.group(1) for m in REZ_REF_RE.finditer(text)), mc_file)
        add((m.group(1) for m in GET_PROPERTY_RE.finditer(text)), mc_file)

    for xml_file in list(ROOT.glob("resources*/**/*.xml")) + [ROOT / "manifest.xml"]:
        if not xml_file.exists():
            continue
        text = xml_file.read_text(encoding="utf-8")
        add((m.group(1) for m in AT_REF_RE.finditer(text)), xml_file)

    return referenced


def main():
    if not check_xml_well_formed():
        return 1

    defined = find_defined_ids()
    referenced = find_referenced_ids()

    missing = {rid: files for rid, files in referenced.items() if rid not in defined}

    if missing:
        print("Dangling resource references found (referenced but never defined):\n")
        for rid, files in sorted(missing.items()):
            print(f"  {rid}")
            for f in sorted(set(files)):
                print(f"    - {f}")
        print(f"\n{len(missing)} dangling reference(s).")
        return 1

    print(f"OK: {len(referenced)} referenced ids, all defined ({len(defined)} ids defined across resource XML).")
    return 0


if __name__ == "__main__":
    sys.exit(main())
