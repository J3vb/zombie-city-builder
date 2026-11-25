"""Package the exact CI-tested Windows files and produce the launcher's stable feed."""
import hashlib
import json
import re
import shutil
import sys
from pathlib import Path
from zipfile import ZIP_DEFLATED, ZipFile

GAME_FILES = ("HoldTheGates.exe", "town_flow.dll", "godot-cpp-LICENSE.txt")
LAUNCHER = "HoldTheGatesLauncher.exe"
ARCHIVE = "HoldTheGates-Windows-x64.zip"


def main(version, game, launcher, output):
    if not re.fullmatch(r"(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)", version):
        raise ValueError("Invalid release version")
    game, launcher, output = map(Path, (game, launcher, output))
    output.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(launcher, output / LAUNCHER)
    with ZipFile(output / ARCHIVE, "w", compression=ZIP_DEFLATED, compresslevel=6) as archive:
        for name in GAME_FILES:
            archive.write(game / name, name)
    manifest = {"schema": 1, "version": version}
    for key, name in [("launcher", LAUNCHER), ("game", ARCHIVE)]:
        path = output / name
        with path.open("rb") as source:
            manifest[key + "_sha256"] = hashlib.file_digest(source, "sha256").hexdigest()
        manifest[key + "_bytes"] = path.stat().st_size
    (output / "windows-update.json").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main(*sys.argv[1:])

