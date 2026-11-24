#!/usr/bin/env python3
"""Check Waybar's real fonts, icons, ASCII digits and Chinese sans fallback."""

import argparse
import ctypes as ct
from ctypes.util import find_library
import json
import os
from pathlib import Path
import re
import subprocess
import sys


def check_pango_digits(quiet, size_px):
    # Use Pango itself, as Waybar does, rather than inferring the face from CSS.
    def library(name):
        path = find_library(name)
        if not path:
            raise ValueError(f"Required Waybar rendering library is missing: {name}")
        return ct.CDLL(path)

    pango = library("pango-1.0")
    cairo = library("pangocairo-1.0")
    gobject = library("gobject-2.0")
    signatures = {
        "pango_font_map_create_context": (ct.c_void_p, [ct.c_void_p]),
        "pango_font_description_new": (ct.c_void_p, []),
        "pango_font_description_set_family": (None, [ct.c_void_p, ct.c_char_p]),
        "pango_font_description_set_weight": (None, [ct.c_void_p, ct.c_int]),
        "pango_font_description_set_absolute_size": (None, [ct.c_void_p, ct.c_double]),
        "pango_font_description_get_family": (ct.c_char_p, [ct.c_void_p]),
        "pango_font_description_free": (None, [ct.c_void_p]),
        "pango_language_from_string": (ct.c_void_p, [ct.c_char_p]),
        "pango_context_set_language": (None, [ct.c_void_p, ct.c_void_p]),
        "pango_context_load_fontset": (ct.c_void_p, [ct.c_void_p, ct.c_void_p, ct.c_void_p]),
        "pango_fontset_get_font": (ct.c_void_p, [ct.c_void_p, ct.c_uint]),
        "pango_font_describe": (ct.c_void_p, [ct.c_void_p]),
        "pango_layout_new": (ct.c_void_p, [ct.c_void_p]),
        "pango_layout_set_font_description": (None, [ct.c_void_p, ct.c_void_p]),
        "pango_layout_set_text": (None, [ct.c_void_p, ct.c_char_p, ct.c_int]),
        "pango_layout_get_size": (None, [ct.c_void_p, ct.POINTER(ct.c_int), ct.POINTER(ct.c_int)]),
    }
    for name, (restype, argtypes) in signatures.items():
        function = getattr(pango, name)
        function.restype, function.argtypes = restype, argtypes
    cairo.pango_cairo_font_map_get_default.restype = ct.c_void_p
    gobject.g_object_unref.restype = None
    gobject.g_object_unref.argtypes = [ct.c_void_p]
    context = pango.pango_font_map_create_context(cairo.pango_cairo_font_map_get_default())
    description = pango.pango_font_description_new()
    pango.pango_font_description_set_family(description, b"JetBrainsMono Nerd Font")
    pango.pango_font_description_set_absolute_size(description, size_px * 1024)
    language = pango.pango_language_from_string(b"zh-cn")
    pango.pango_context_set_language(context, language)
    try:
        for weight in (400, 500):
            pango.pango_font_description_set_weight(description, weight)
            fontset = pango.pango_context_load_fontset(context, description, language)
            try:
                for char in "0123456789.%:ABCxyz":
                    font = pango.pango_fontset_get_font(fontset, ord(char))
                    selected = pango.pango_font_describe(font)
                    family = pango.pango_font_description_get_family(selected).decode()
                    pango.pango_font_description_free(selected)
                    gobject.g_object_unref(font)
                    if family != "JetBrainsMono Nerd Font":
                        raise ValueError(f"Pango zh-CN selected {family} for {char!r}")
                for char in "中文汉字字体开发科研终端":
                    font = pango.pango_fontset_get_font(fontset, ord(char))
                    selected = pango.pango_font_describe(font)
                    family = pango.pango_font_description_get_family(selected).decode()
                    pango.pango_font_description_free(selected)
                    gobject.g_object_unref(font)
                    if family != "Noto Sans CJK SC":
                        raise ValueError(f"Pango zh-CN selected {family} for Chinese {char!r}; expected Noto Sans CJK SC")
                if not quiet:
                    print(f"PASS Pango zh-CN weight {weight}: Chinese glyphs use Noto Sans CJK SC")
            finally:
                gobject.g_object_unref(fontset)
            layout = pango.pango_layout_new(context)
            try:
                pango.pango_layout_set_font_description(layout, description)
                widths = []
                for text in (b"0123456789", b"ABCDEFGHIJ"):
                    pango.pango_layout_set_text(layout, text, len(text))
                    width, height = ct.c_int(), ct.c_int()
                    pango.pango_layout_get_size(layout, ct.byref(width), ct.byref(height))
                    widths.append(width.value / 1024)
                if abs(widths[0] - widths[1]) > 1 or not 0 < widths[0] < 10 * size_px * 0.8:
                    raise ValueError(f"Unexpected full-width/proportional ASCII layout: {widths}")
                if not quiet:
                    print(f"PASS Pango zh-CN weight {weight}: ASCII digits use JetBrainsMono Nerd Font; 10 digits = {widths[0]:g}px at {size_px:g}px")
            finally:
                gobject.g_object_unref(layout)
    finally:
        pango.pango_font_description_free(description)
        gobject.g_object_unref(context)


def strings(value):
    if isinstance(value, str):
        yield value
    elif isinstance(value, list):
        for item in value:
            yield from strings(item)
    elif isinstance(value, dict):
        for item in value.values():
            yield from strings(item)


def check(config, quiet=False):
    # The launcher uses the same scoped configuration, without changing other apps.
    scoped = Path(config).parent / "fontconfig.conf"
    if scoped.is_file():
        os.environ["FONTCONFIG_FILE"] = str(scoped.resolve())
    data = json.loads(Path(config).read_text(encoding="utf-8"))
    icons = {
        ord(char)
        for text in strings(data)
        for char in text
        if 0xE000 <= ord(char) <= 0xF8FF
        or 0xF0000 <= ord(char) <= 0xFFFFD
        or 0x100000 <= ord(char) <= 0x10FFFD
    }
    for weight in ("regular", "medium"):
        match = subprocess.check_output(
            ["fc-match", "-f", "%{family}\n%{file}\n", f"JetBrainsMono Nerd Font:weight={weight}"],
            text=True,
        ).splitlines()
        if len(match) != 2 or "JetBrainsMono Nerd Font" not in match[0].split(","):
            raise ValueError(f"{weight}: fontconfig substituted a different font: {match}")
        charset = subprocess.check_output(
            ["fc-query", "-f", "%{charset}", match[1]], text=True
        )
        ranges = []
        for token in charset.split():
            first, _, last = token.partition("-")
            ranges.append((int(first, 16), int(last or first, 16)))
        required = icons | set(range(0x20, 0x7F))
        missing = sorted(code for code in required if not any(a <= code <= b for a, b in ranges))
        if missing:
            raise ValueError(
                f"{match[1]} is missing Waybar ASCII/icon characters: "
                + ", ".join(f"U+{code:04X}" for code in missing)
            )
        if not quiet:
            print(f"PASS Waybar {weight}: {match[1]} ({len(icons)} icon codepoints)")
    style = Path(config).with_name("style.css").read_text(encoding="utf-8")
    size = re.search(r"font-size:\s*([0-9]+(?:\.[0-9]+)?)px\s*;", style)
    if not size or float(size[1]) <= 0:
        raise ValueError("Waybar CSS has no valid font-size in px")
    check_pango_digits(quiet, float(size[1]))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("config", type=Path)
    parser.add_argument("--quiet", action="store_true")
    args = parser.parse_args()
    try:
        check(args.config, args.quiet)
    except (OSError, ValueError, subprocess.CalledProcessError) as error:
        if not args.quiet:
            print(f"Waybar font check failed: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
