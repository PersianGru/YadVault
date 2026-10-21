#!/usr/bin/env python3
"""Checks of this repository's files, run by CI (.github/workflows/checks.yml):

- no text file or file name contains characters from the Unicode blocks U+0600-06FF, U+0750-077F,
  U+08A0-08FF, U+FB50-FDFF or U+FE70-FEFF: the files and screenshots here are in English, while
  YadVault itself handles any language;
- PNG files carry no text chunks at all;
- relative links in the Markdown files point at files that exist;
- every YAML file parses; compose files have no `build:` section (except the DNS variant of
  Caddy, docker-compose.https-dns.yml) and every image has a pinned version.
"""

from __future__ import annotations

import re
import struct
import sys
import zlib
from pathlib import Path
from urllib.parse import unquote

import yaml

ROOT = Path(__file__).resolve().parents[2]
SCRIPT = re.compile("[\u0600-\u06ff\u0750-\u077f\u08a0-\u08ff\ufb50-\ufdff\ufe70-\ufeff]")
LINK = re.compile(r"\[[^\]]*\]\(([^)\s]+)\)")
BUILD_EXEMPT = {"docker-compose.https-dns.yml"}


def files() -> list[Path]:
    return [p for p in sorted(ROOT.rglob("*")) if p.is_file() and ".git" not in p.relative_to(ROOT).parts]


def png_texts(data: bytes) -> list[bytes]:
    texts, pos = [], 8
    while pos < len(data):
        (length,) = struct.unpack(">I", data[pos:pos + 4])
        kind, body = data[pos + 4:pos + 8], data[pos + 8:pos + 8 + length]
        if kind in (b"tEXt", b"iTXt", b"zTXt", b"eXIf"):
            texts.append(zlib.decompress(body.partition(b"\0")[2][1:]) if kind == b"zTXt" else body)
        pos += 12 + length
    return texts


class Loader(yaml.SafeLoader):
    pass


Loader.add_multi_constructor("!", lambda loader, suffix, node: None)  # compose tags such as !reset


def main() -> int:
    problems: list[str] = []
    for path in files():
        rel = path.relative_to(ROOT).as_posix()
        data = path.read_bytes()
        if SCRIPT.search(rel):
            problems.append(f"{rel}: character from a blocked Unicode block in the file name")
        if path.suffix == ".png":
            texts = png_texts(data)
            if texts:
                problems.append(f"{rel}: PNG with text chunks")
            continue
        text = data.decode("utf-8")
        for n, line in enumerate(text.splitlines(), 1):
            if SCRIPT.search(line):
                problems.append(f"{rel}:{n}: character from a blocked Unicode block")
        if path.suffix == ".md":
            for target in LINK.findall(text):
                if re.match(r"^[a-z]+:", target) or target.startswith("#"):
                    continue
                file_part = unquote(target.split("#", 1)[0])
                if file_part and not (path.parent / file_part).exists():
                    problems.append(f"{rel}: broken link {target}")
        if path.suffix in (".yml", ".yaml"):
            try:
                doc = yaml.load(text, Loader=Loader)
            except yaml.YAMLError as e:
                problems.append(f"{rel}: YAML does not parse ({type(e).__name__})")
                continue
            if path.name.startswith("docker-compose") and isinstance(doc, dict) and path.name not in BUILD_EXEMPT:
                for name, svc in (doc.get("services") or {}).items():
                    svc = svc or {}
                    if "build" in svc:
                        problems.append(f"{rel}: service {name} has a build section")
                    image = str(svc.get("image", ""))
                    if image and re.search(r":(latest|main)$|:-latest\}", image):
                        problems.append(f"{rel}: service {name} image {image} is not pinned")
    for p in problems:
        print(p)
    print(f"{len(files())} files checked, {len(problems)} problems")
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
