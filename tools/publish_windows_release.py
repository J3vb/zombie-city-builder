"""Publish a complete tested bundle, resume an interrupted draft, and preserve latest ordering."""
import json
import os
import re
import subprocess
from pathlib import Path


def gh(*args):
    return subprocess.check_output(["gh", *args], text=True)


def main():
    repo = os.environ["GITHUB_REPOSITORY"]
    sha = os.environ["GITHUB_SHA"]
    version = "0.1." + str(int(os.environ["GITHUB_RUN_NUMBER"]))
    tag = "v" + version
    release = Path("build/release")
    names = ["HoldTheGatesLauncher.exe", "HoldTheGates-Windows-x64.zip", "windows-update.json"]
    # Authenticated release listing includes drafts; do not treat a network failure as an empty list.
    pages = json.loads(gh("api", "--paginate", "--slurp", f"repos/{repo}/releases?per_page=100"))
    releases = [item for page in pages for item in page]
    existing = next((item for item in releases if item["tag_name"] == tag), None)
    if existing:
        if existing["target_commitish"] != sha:
            raise RuntimeError(f"{tag} is already reserved for another commit")
        if not existing["draft"]:
            if set(names) <= {asset["name"] for asset in existing["assets"]}:
                return
            raise RuntimeError(f"The published release {tag} is incomplete")
    else:
        notes = ("Download **HoldTheGatesLauncher.exe** and open it to install or play. "
                 "The launcher keeps itself and the game up to date. "
                 "The Windows x64 ZIP is also available for manual installation.")
        gh("release", "create", tag, "--repo", repo, "--draft", "--target", sha,
           "--title", "Hold the Gates " + version, "--notes", notes)
    gh("release", "upload", tag, "--repo", repo, "--clobber", *[str(release / name) for name in names])
    newer = any(not item["draft"] and not item["prerelease"]
                and re.fullmatch(r"v\d+\.\d+\.\d+", item["tag_name"])
                and tuple(map(int, item["tag_name"][1:].split("."))) > tuple(map(int, version.split(".")))
                for item in releases)
    gh("release", "edit", tag, "--repo", repo, "--draft=false", "--latest=" + str(not newer).lower())


if __name__ == "__main__":
    main()
