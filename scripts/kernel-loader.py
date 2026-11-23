# SPDX-License-Identifier: GPL-2.0-or-later
"""Make a staged x86-64 ELF load its interpreter from inherited descriptor 9."""

import os
from pathlib import Path
import struct
import sys


PT_INTERP = 3
INTERPRETER = b"/proc/self/fd/9\0"


def set_fd_interpreter(path: Path) -> str:
    with path.open("r+b") as elf:
        header = elf.read(64)
        if header[:7] != b"\x7fELF\x02\x01\x01":
            raise ValueError(f"Expected a little-endian ELF64 executable: {path}")
        machine, = struct.unpack_from("<H", header, 18)
        if machine != 62:
            raise ValueError(f"Expected an x86-64 ELF executable: {path}")
        phoff, = struct.unpack_from("<Q", header, 32)
        entry_size, entry_count = struct.unpack_from("<HH", header, 54)
        if entry_size != 56 or phoff + entry_size * entry_count > os.fstat(elf.fileno()).st_size:
            raise ValueError(f"Invalid program header table: {path}")
        for index in range(entry_count):
            elf.seek(phoff + index * entry_size)
            kind, _, offset, _, _, size, _, _ = struct.unpack("<IIQQQQQQ", elf.read(entry_size))
            if kind != PT_INTERP:
                continue
            if size < len(INTERPRETER) or offset + size > os.fstat(elf.fileno()).st_size:
                raise ValueError(f"Cannot fit portable interpreter in original segment: {path}")
            elf.seek(offset)
            original = elf.read(size)
            if not original.startswith(b"/") or not original.endswith(b"\0"):
                raise ValueError(f"Invalid original interpreter path: {path}")
            elf.seek(offset)
            elf.write(INTERPRETER.ljust(size, b"\0"))
            return original.split(b"\0", 1)[0].decode()
        raise ValueError(f"Missing ELF interpreter: {path}")


if __name__ == "__main__":
    for argument in sys.argv[1:]:
        print(set_fd_interpreter(Path(argument)))
