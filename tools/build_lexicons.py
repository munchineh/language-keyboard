#!/usr/bin/env python3
"""Builds the keyboard's bundled word lists and emoji data.

Run from the repo root:
    pip install wordfreq pypinyin opencc-python-reimplemented
    python3 tools/build_lexicons.py path/to/emoji-test.txt

Outputs (app/Keyboard/Resources/):
    ko_words.txt   Korean words, most frequent first (word suggestions)
    zh_pinyin.tsv  pinyin <tab> simplified <tab> Taiwan traditional, most frequent first
    emoji.tsv      group <tab> space-separated emoji (Unicode emoji-test.txt order)
"""
import re
import sys
from pathlib import Path

from opencc import OpenCC
from pypinyin import Style, lazy_pinyin
from wordfreq import top_n_list

OUT = Path(__file__).resolve().parent.parent / "app" / "Keyboard" / "Resources"
OUT.mkdir(parents=True, exist_ok=True)

HANGUL = re.compile(r"^[가-힣]+$")
HAN = re.compile(r"^[一-鿿]+$")
MAX_EMOJI_VERSION = 16.0  # what iOS 18.4+ draws


def korean(n=30000):
    words = [w for w in top_n_list("ko", n * 2) if HANGUL.match(w)][:n]
    (OUT / "ko_words.txt").write_text("\n".join(words) + "\n", encoding="utf-8")
    return len(words)


def chinese(n=40000):
    to_tw = OpenCC("s2twp")  # simplified -> Taiwan traditional, with Taiwan vocabulary
    seen = set()
    rows = []
    for w in top_n_list("zh", n * 2):
        if not HAN.match(w) or w in seen:
            continue
        seen.add(w)
        py = "".join(lazy_pinyin(w, style=Style.NORMAL, v_to_u=False)).replace("ü", "v")
        if not py.isascii() or not py.isalpha():
            continue
        rows.append(f"{py}\t{w}\t{to_tw.convert(w)}")
        if len(rows) >= n:
            break
    (OUT / "zh_pinyin.tsv").write_text("\n".join(rows) + "\n", encoding="utf-8")
    return len(rows)


def emoji(test_file):
    groups, order, group = {}, [], None
    for line in Path(test_file).read_text(encoding="utf-8").splitlines():
        if line.startswith("# group:"):
            group = line.split(":", 1)[1].strip()
            if group != "Component":
                order.append(group)
                groups[group] = []
            continue
        if not line or line.startswith("#") or group == "Component":
            continue
        code, rest = line.split(";", 1)
        if "fully-qualified" not in rest:
            continue
        name = rest.split("#", 1)[1]
        if "skin tone" in name:
            continue  # base emoji only for now
        version = re.search(r"E(\d+\.\d+)", name)
        if version and float(version.group(1)) > MAX_EMOJI_VERSION:
            continue  # newer than iOS can draw
        groups[group].append("".join(chr(int(c, 16)) for c in code.split()))
    lines = [f"{g}\t{' '.join(groups[g])}" for g in order]
    (OUT / "emoji.tsv").write_text("\n".join(lines) + "\n", encoding="utf-8")
    return {g: len(groups[g]) for g in order}


if __name__ == "__main__":
    print("ko words:", korean())
    print("zh entries:", chinese())
    if len(sys.argv) > 1:
        print("emoji:", emoji(sys.argv[1]))
