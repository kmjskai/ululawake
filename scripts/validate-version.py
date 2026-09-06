#!/usr/bin/env python3
import os
import plistlib
import re
from pathlib import Path

info = plistlib.loads(Path("UlulaWake/Info.plist").read_bytes())
version = info["CFBundleShortVersionString"]
build = info["CFBundleVersion"]
if not re.fullmatch(r"[0-9]{4}\.[0-9]{1,2}\.[0-9]+", version):
    raise SystemExit("Expected YYYY.M.PATCH version")
if not build.isdigit() or int(build) < 1:
    raise SystemExit("Build must be a positive integer")
if os.environ.get("RELEASE_TAG", "v" + version) != "v" + version:
    raise SystemExit("Tag does not match the source version")
if os.environ.get("GITHUB_ENV"):
    with open(os.environ["GITHUB_ENV"], "a") as output:
        output.write("VERSION=" + version + "\n")
print("Version: " + version + " (" + build + ")")
