"""Build and install the flow-field extension for the current host."""
from pathlib import Path
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
BUILD = ROOT / "build" / "native-flow"
SOURCE = ROOT / "tools" / "native_flow"


def main():
    BUILD.mkdir(parents=True, exist_ok=True)
    (BUILD / ".gdignore").touch()
    configure = ["cmake", "-S", str(SOURCE), "-B", str(BUILD), "-DCMAKE_BUILD_TYPE=Release"]
    if not (BUILD / "CMakeCache.txt").exists() and shutil.which("ninja"):
        if sys.platform != "win32" or shutil.which("cl"):
            configure.extend(["-G", "Ninja"])
        elif compiler := shutil.which("g++"):
            configure.extend(["-G", "Ninja", f"-DCMAKE_CXX_COMPILER={compiler}"])
        # With Visual Studio installed but no active developer shell, CMake
        # discovers the installed Visual Studio generator and toolchain itself.
    subprocess.run(configure, check=True)
    subprocess.run(["cmake", "--build", str(BUILD), "--config", "Release", "--parallel", "4"], check=True)
    subprocess.run(["cmake", "--install", str(BUILD), "--config", "Release", "--prefix", str(ROOT)], check=True)


if __name__ == "__main__":
    main()
