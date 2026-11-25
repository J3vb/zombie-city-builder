"""Install the release's official Windows editor and x64 export template into a cache."""
import argparse
import hashlib
import shutil
import tempfile
import urllib.request
import zipfile
from pathlib import Path

VERSION = "4.5.1-stable"
ASSETS = {
    "win64.exe.zip": "defccc78669e644861b4247626b01ae362cd9f23975edf19c8bfd2eb1f6a1783",
    "export_templates.tpz": "1998af37f1387684e2c211cdb483daf492fc64dc6b12096bddcdca25b6910c86",
}


def install(cache: Path) -> None:
    version = cache / VERSION
    editor = f"Godot_v{VERSION}_win64"
    selections = {
        "win64.exe.zip": {
            f"{editor}.exe": version / f"{editor}.exe",
            f"{editor}_console.exe": version / f"{editor}_console.exe",
        },
        "export_templates.tpz": {
            f"templates/{name}": cache / "Godot/export_templates/4.5.1.stable" / name
            for name in ("windows_release_x86_64.exe", "windows_release_x86_64_console.exe")
        },
    }
    cache.mkdir(parents=True, exist_ok=True)
    for suffix, members in selections.items():
        if all(path.is_file() for path in members.values()):
            continue
        filename = f"Godot_v{VERSION}_{suffix}"
        url = f"https://github.com/godotengine/godot-builds/releases/download/{VERSION}/{filename}"
        print(f"Downloading {filename}", flush=True)
        with tempfile.TemporaryDirectory(dir=cache) as scratch:
            archive = Path(scratch) / filename
            with urllib.request.urlopen(url, timeout=180) as response, archive.open("wb") as out:
                shutil.copyfileobj(response, out, 1024 * 1024)
            with archive.open("rb") as source:
                if hashlib.file_digest(source, "sha256").hexdigest() != ASSETS[suffix]:
                    raise ValueError(f"Wrong SHA-256 for {filename}")
            with zipfile.ZipFile(archive) as bundle:
                for member, dest in members.items():
                    dest.parent.mkdir(parents=True, exist_ok=True)
                    pending = dest.with_suffix(".partial")
                    with bundle.open(member) as source, pending.open("wb") as out:
                        shutil.copyfileobj(source, out)
                    pending.replace(dest)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("cache", type=Path)
    install(parser.parse_args().cache.resolve())
