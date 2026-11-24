#!/usr/bin/env python3
"""Run via kitty +runpy: inspect its real config parser and font selection."""
from pathlib import Path

from kitty.config import load_config
from kitty.fonts.common import get_font_files
from kitty.fonts.render import font_for_family


root = Path(__file__).resolve().parents[1]
bad_lines = []
options = load_config(str(root / "config/.config/kitty/kitty.conf"), accumulate_bad_lines=bad_lines)
assert not bad_lines, bad_lines
for char in "中文汉字字体测试（）【】。！？，":
    matching = [family for (first, last), family in options.symbol_map.items() if first <= ord(char) <= last]
    assert matching == ["Noto Sans CJK SC"], (char, matching)
for char in "0123456789ABCxyz\uf1eb\uef44":
    assert not any(first <= ord(char) <= last for first, last in options.symbol_map), char
fonts = get_font_files(options)
assert fonts["medium"]["family"] == "JetBrainsMono Nerd Font", fonts["medium"]
for family in set(options.symbol_map.values()):
    font, _, _ = font_for_family(family)
    assert font["family"] == "Noto Sans CJK SC", font
    assert font["postscript_name"].startswith("NotoSansCJKsc-"), font
print("PASS: real Kitty loads Noto Sans CJK SC for Han/punctuation and retains JetBrainsMono for Latin/digits/icons")
