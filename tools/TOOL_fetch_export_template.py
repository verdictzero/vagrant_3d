#!/usr/bin/env python3
"""Fetch single Godot export templates without downloading all of them.

    python3 tools/TOOL_fetch_export_template.py linux_debug.x86_64
    python3 tools/TOOL_fetch_export_template.py linux_release.x86_64 linux_debug.x86_64

THE TEMPLATES ARE ONE 1.2 GB ZIP (`Godot_v<version>_export_templates.tpz`) and a
build for one platform wants one or two of the 35 files in it. A zip keeps its
table of contents at the END, so with HTTP range requests the table can be read,
and then only the bytes of the wanted entries: the Linux debug template is a
73.6 MB file that comes out of 28 MB of download. Python's `zipfile` does the
reading and checks every entry's CRC as it decompresses, so a damaged range
fails here instead of becoming a broken export.

The version is `godot --version`'s, so the templates always match the editor
that will use them (Godot refuses templates of any other version). They land
where Godot looks: ~/.local/share/godot/export_templates/<version>/.

TLS goes through Python's default context, which honours SSL_CERT_FILE, so a
proxy with its own CA works unchanged. `GODOT` names another editor binary.
"""
import io
import os
import re
import ssl
import subprocess
import sys
import urllib.request
import zipfile

if len(sys.argv) < 2 or sys.argv[1] in ("-h", "--help"):
    print(__doc__.strip())
    sys.exit(0 if len(sys.argv) > 1 else 2)

GODOT = os.environ.get("GODOT", "godot")
ver = subprocess.run([GODOT, "--version"], capture_output=True, text=True,
                     check=True).stdout.strip().splitlines()[-1]
# "4.7.dev5.official.a8643700c" -> "4.7.dev5" (the folder) -> "4.7-dev5" (the tag)
m = re.match(r"^(\d+\.\d+(?:\.\d+)?)\.([a-z]+\d*)\b", ver)
if not m:
    sys.exit("could not read a version out of %r" % ver)
folder = "%s.%s" % (m.group(1), m.group(2))
tag = "%s-%s" % (m.group(1), m.group(2))
url = ("https://github.com/godotengine/godot-builds/releases/download/"
       "%s/Godot_v%s_export_templates.tpz" % (tag, tag))
dest_dir = os.path.expanduser("~/.local/share/godot/export_templates/" + folder)

opener = urllib.request.build_opener(
    urllib.request.HTTPSHandler(context=ssl.create_default_context()))

# Resolve the redirect once: the signed asset URL takes ranges directly.
with opener.open(urllib.request.Request(url, method="HEAD"), timeout=60) as r:
    final, size = r.geturl(), int(r.headers["Content-Length"])
print("%s: %d bytes" % (url, size))


class RangeFile(io.RawIOBase):
    """The remote archive as a seekable file, one range request per read."""

    def __init__(self):
        self.pos, self.fetched = 0, 0

    def seekable(self):
        return True

    def readable(self):
        return True

    def tell(self):
        return self.pos

    def seek(self, off, whence=0):
        base = {0: 0, 1: self.pos, 2: size}[whence]
        self.pos = base + off
        return self.pos

    def readinto(self, b):
        n = min(len(b), size - self.pos)
        if n <= 0:
            return 0
        rq = urllib.request.Request(final, headers={
            "Range": "bytes=%d-%d" % (self.pos, self.pos + n - 1)})
        last = None
        for _ in range(5):
            try:
                with opener.open(rq, timeout=300) as r:
                    data = r.read()
                if len(data) == n:
                    break
                last = "short read: %d of %d bytes" % (len(data), n)
            except OSError as e:
                last = e
        else:
            raise IOError("range %d+%d failed: %s" % (self.pos, n, last))
        b[:n] = data
        self.pos += n
        self.fetched += n
        return n


rf = RangeFile()
z = zipfile.ZipFile(io.BufferedReader(rf, buffer_size=1 << 20))
os.makedirs(dest_dir, exist_ok=True)
for want in sys.argv[1:]:
    name = "templates/" + want
    try:
        info = z.getinfo(name)
    except KeyError:
        have = sorted(n[len("templates/"):] for n in z.namelist())
        sys.exit("no %s in the archive; it has: %s" % (want, ", ".join(have)))
    dest = os.path.join(dest_dir, want)
    with z.open(info) as src, open(dest + ".part", "wb") as dst:
        while True:
            chunk = src.read(8 << 20)
            if not chunk:
                break
            dst.write(chunk)
    os.chmod(dest + ".part", 0o755)
    os.replace(dest + ".part", dest)
    print("  %s  %d bytes" % (dest, info.file_size))
# Godot reads the folder's version.txt to decide the templates are its own.
vtxt = os.path.join(dest_dir, "version.txt")
if not os.path.exists(vtxt):
    with open(vtxt, "w") as f:
        f.write(z.read("templates/version.txt").decode())
print("downloaded %d of the archive's %d bytes" % (rf.fetched, size))
