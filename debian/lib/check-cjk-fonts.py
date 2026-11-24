#!/usr/bin/env python3
"""Verify installed UI fonts using actual Fontconfig glyph/locale matching."""
import subprocess
import sys


def check():
    for language in ("zh-cn", "en-us"):
        for weight in ("regular", "bold"):
            for requested in ("JetBrainsMono Nerd Font", "sans-serif", "monospace"):
                pattern = f"{requested}:lang={language}:weight={weight}:charset=4e2d"
                family = subprocess.check_output(["fc-match", "-f", "%{family}", pattern], text=True)
                if not {"Noto Sans CJK SC", "Noto Sans Mono CJK SC"}.intersection(family.split(",")):
                    raise ValueError(f"Chinese glyph fallback for {pattern} is {family}, expected Noto Sans CJK SC")
            pattern = f"JetBrainsMono Nerd Font:lang={language}:weight={weight}:charset=30-39"
            family = subprocess.check_output(["fc-match", "-f", "%{family}", pattern], text=True)
            if "JetBrainsMono Nerd Font" not in family.split(","):
                raise ValueError(f"Latin/digit font for {pattern} is {family}, expected JetBrainsMono Nerd Font")
    print("PASS: Chinese uses Noto Sans CJK SC; Latin/digits retain JetBrainsMono in zh_CN and en_US")


if __name__ == "__main__":
    try:
        check()
    except (OSError, ValueError, subprocess.CalledProcessError) as error:
        sys.exit(f"UI font selection check failed: {error}; ensure fonts-noto-cjk and the Nerd Font are installed.")
