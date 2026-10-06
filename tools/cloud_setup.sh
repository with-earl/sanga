#!/usr/bin/env bash
# Installs Godot (for headless use) and its web export templates on Linux, so a cloud session or
# CI runner can import, test and export SANGA exactly like the desktop editor does.
#
#   bash tools/cloud_setup.sh
#
# It is self-contained (no other repo file needed), so the same text can be pasted into the
# environment setup script on claude.ai/code. Safe to run more than once: anything already
# installed is skipped. Afterwards `godot --version` prints the version below.
#
# Only the web templates are installed. The full template archive is 1.3 GB; the embedded Python
# reads just the two web templates (about 20 MB) out of it with HTTP range requests.
set -euo pipefail

GODOT_VERSION="${GODOT_VERSION:-4.7.2}"
RELEASES="https://github.com/godotengine/godot-builds/releases/download/${GODOT_VERSION}-stable"
DEST="$HOME/.local/opt/godot-${GODOT_VERSION}"

# 1. The engine.
if [ ! -x "$DEST/godot" ]; then
	echo "Downloading Godot ${GODOT_VERSION}..."
	mkdir -p "$DEST"
	curl -fsSL -o "$DEST/godot.zip" "$RELEASES/Godot_v${GODOT_VERSION}-stable_linux.x86_64.zip"
	python3 -m zipfile -e "$DEST/godot.zip" "$DEST"
	mv "$DEST/Godot_v${GODOT_VERSION}-stable_linux.x86_64" "$DEST/godot"
	chmod +x "$DEST/godot"
	rm "$DEST/godot.zip"
fi

# 2. Put `godot` on the PATH: system-wide if allowed, otherwise in ~/.local/bin.
if [ -w /usr/local/bin ] || sudo -n true 2>/dev/null; then
	if [ -w /usr/local/bin ]; then ln -sf "$DEST/godot" /usr/local/bin/godot; else sudo ln -sf "$DEST/godot" /usr/local/bin/godot; fi
else
	mkdir -p "$HOME/.local/bin"
	ln -sf "$DEST/godot" "$HOME/.local/bin/godot"
	case ":$PATH:" in
		*":$HOME/.local/bin:"*) ;;
		*) echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.bashrc"; export PATH="$HOME/.local/bin:$PATH" ;;
	esac
fi
# GitHub Actions: make it available to later steps too.
if [ -n "${GITHUB_PATH:-}" ]; then
	dirname "$(command -v godot)" >> "$GITHUB_PATH"
fi

# 3. The web export templates (threads off, as the Web preset uses).
python3 - "$GODOT_VERSION" <<'PY'
import io, os, sys, urllib.request, zipfile
from pathlib import Path

version = sys.argv[1]
wanted = ["web_nothreads_release.zip", "web_nothreads_debug.zip", "version.txt"]
data = os.environ.get("XDG_DATA_HOME") or str(Path.home() / ".local" / "share")
target = Path(data) / "godot" / "export_templates" / f"{version}.stable"
if all((target / name).exists() for name in wanted):
    print(f"Web templates already installed in {target}")
    sys.exit(0)

class HttpRangeFile(io.RawIOBase):
    """A read-only, seekable file over HTTP that fetches only the bytes it reads."""
    def __init__(self, url):
        with urllib.request.urlopen(urllib.request.Request(url, method="HEAD")) as response:
            self.url, self.size = response.url, int(response.headers["Content-Length"])
        self.pos = 0
    def seekable(self): return True
    def readable(self): return True
    def tell(self): return self.pos
    def seek(self, offset, whence=0):
        self.pos = {0: 0, 1: self.pos, 2: self.size}[whence] + offset
        return self.pos
    def readinto(self, buffer):
        if self.pos >= self.size or not len(buffer):
            return 0
        end = min(self.pos + len(buffer), self.size) - 1
        request = urllib.request.Request(self.url, headers={"Range": f"bytes={self.pos}-{end}"})
        with urllib.request.urlopen(request) as response:
            chunk = response.read()
        buffer[: len(chunk)] = chunk
        self.pos += len(chunk)
        return len(chunk)

url = (f"https://github.com/godotengine/godot-builds/releases/download/{version}-stable/"
       f"Godot_v{version}-stable_export_templates.tpz")
archive = zipfile.ZipFile(io.BufferedReader(HttpRangeFile(url), buffer_size=1 << 20))
target.mkdir(parents=True, exist_ok=True)
for name in wanted:
    print(f"Extracting templates/{name}")
    with archive.open(f"templates/{name}") as source, open(target / name, "wb") as out:
        while chunk := source.read(1 << 20):
            out.write(chunk)
print(f"Web templates installed in {target}")
PY

godot --headless --version
