# SPDX-License-Identifier: GPL-2.0-or-later
"""Package a native bbport Nix build as a relocatable Linux add-on."""

import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import runpy
import shutil
import subprocess
import tarfile
import tempfile


set_fd_interpreter = runpy.run_path(str(Path(__file__).with_name("kernel-loader.py")))["set_fd_interpreter"]
STORE = Path("/nix/store")
PROGRAMS = ("bb-probe", "bb-gpu-capabilities")
# SDL's desktop and controller backends open these with dlopen.
SDL_PLUGINS = {
    "libX11-xcb.so.1": "libx11", "libX11.so.6": "libx11",
    "libXcursor.so.1": "libxcursor", "libXext.so.6": "libxext", "libXfixes.so.3": "libxfixes",
    "libXi.so.6": "libxi", "libXrandr.so.2": "libxrandr", "libXrender.so.1": "libxrender",
    "libXss.so.1": "libxscrnsaver", "libdbus-1.so.3": "dbus",
    "libpulse.so.0": "libpulseaudio", "libudev.so.1": "systemd-minimal-libs", "libusb-1.0.so.0": "libusb",
    "libwayland-client.so.0": "wayland", "libwayland-cursor.so.0": "wayland", "libwayland-egl.so.1": "wayland",
    "libxkbcommon.so.0": "libxkbcommon",
}
WRAPPER = """#!/bin/sh
set -eu
bin_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)
runtime_dir=$bin_dir/../runtime
export BB_DSE_ORIGINAL_LD_LIBRARY_PATH="${LD_LIBRARY_PATH:-}"
export LD_LIBRARY_PATH="$bin_dir/gpu:$runtime_dir/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
case ${ALSA_CONFIG_PATH:-} in
  ''|/proc/self/fd/8/alsa.conf)
    case ${ALSA_CONFIG_DIR:-} in
      ''|/proc/self/fd/8) alsa_dir=$runtime_dir/share/alsa ;;
      *) alsa_dir=$ALSA_CONFIG_DIR ;;
    esac
    exec 8<"$alsa_dir"
    export ALSA_CONFIG_DIR=/proc/self/fd/8
    export ALSA_CONFIG_PATH=$ALSA_CONFIG_DIR/alsa.conf
    ;;
esac
export SDL_VULKAN_LIBRARY="${SDL_VULKAN_LIBRARY:-$runtime_dir/lib/libvulkan.so.1}"
export SDL_X11_XCB_LIBRARY="${SDL_X11_XCB_LIBRARY:-$runtime_dir/lib/libX11-xcb.so.1}"
export XKB_CONFIG_ROOT="${XKB_CONFIG_ROOT:-$runtime_dir/share/xkb}"
exec 9<"$runtime_dir/lib/ld-linux-x86-64.so.2"
exec "$bin_dir/@PROGRAM@.elf" "$@"
"""
README = """# bbport DualSense Edge for Linux x86-64

Extract the whole archive and keep `bin` and `runtime` together. Start the official
[Linux Seamless beta 1 AppImage](https://github.com/Supermedo/bloodborne_pc/releases/tag/linux-seamless-beta.1)
with the supplied script.

```bash
./start-linux.sh ./Bloodborne-Linux-x86_64.AppImage
```

Copy `mods/DSE Haptics` into the Mods folder configured in bbport. Connect the
DualSense Edge by USB and use the original launcher's regular Play button in
offline mode. `Profiles.md` describes the editable settings.

The add-on needs a supported Linux Vulkan driver and the standard `/proc/self/fd`
interface. Dependency versions and source information are in `runtime/sources.json`.
See `LICENSE` and `runtime/notices` for licenses and notices. The project source
and build instructions are available from the [bbport DSE repository](https://github.com/sghhhh/bbport-dse-haptics).
"""


def run(*command: str | Path) -> str:
    env = {key: value for key, value in os.environ.items() if key not in {"LD_PRELOAD", "LD_LIBRARY_PATH"}}
    completed = subprocess.run(command, env=env, check=True, stdout=subprocess.PIPE, text=True)
    return completed.stdout


def package_path(path: Path) -> Path:
    return STORE / path.relative_to(STORE).parts[0]


def read_loader(program: Path) -> Path:
    headers = run("readelf", "-l", program)
    interpreter = re.search(r"Requesting program interpreter: (/[^\]]+)\]", headers)
    if not interpreter:
        raise ValueError(f"Missing PT_INTERP in {program}")
    return Path(interpreter[1])


def dependencies(loader: Path, program: Path) -> dict[str, Path]:
    libraries = {}
    for raw_line in run(loader, "--inhibit-cache", "--list", program).splitlines():
        line = raw_line.strip()
        if not line or line.startswith("linux-vdso.so."):
            continue
        line = re.sub(r"\s+\(0x[0-9a-fA-F]+\)$", "", line)
        name, marker, path_text = line.partition(" => ")
        resolved = Path(path_text if marker else line)
        if not resolved.is_absolute() or not resolved.is_file():
            raise ValueError(f"Missing runtime dependency for {program}: {line}")
        # Direct entries are printed without =>, sometimes under a full name.
        libraries[Path(name).name] = resolved
    return libraries


def sha256(path: Path) -> str:
    with path.open("rb") as file:
        return hashlib.file_digest(file, "sha256").hexdigest()


def unique_store_path(pattern: str) -> Path:
    matches = [path for path in STORE.glob(pattern) if path.exists()]
    if len(matches) != 1:
        raise ValueError(f"Expected one Nix store path for {pattern}: {matches}")
    return matches[0]


def copy_notices(package: Path, destination: Path) -> None:
    for directory in (package, package / "share/licenses", package / "share/doc"):
        if not directory.is_dir():
            continue
        candidates = directory.iterdir() if directory == package else directory.rglob("*")
        for path in candidates:
            if path.is_file() and re.match(r"^(?:COPYING|LICENSE|NOTICE|COPYRIGHT)(?:\b|_)", path.name, re.I):
                target = destination / path.relative_to(package)
                target.parent.mkdir(parents=True, exist_ok=True)
                shutil.copyfile(path, target)


def find_deriver(package: Path) -> str:
    declared = run("nix-store", "--query", "--deriver", package).strip()
    if Path(declared).is_file():
        return declared
    if declared == "unknown-deriver":
        return declared
    name = Path(declared).name.split("-", 1)[1]
    for candidate in STORE.glob(f"*-{name}"):
        if str(package) in run("nix-store", "--query", "--outputs", candidate).splitlines():
            return str(candidate)
    return declared


def build_payload(source: Path, payload: Path, repo: Path, nixpkgs_revision: str) -> None:
    out = source / "out"
    bin_dir = payload / "bin"
    lib_dir = payload / "runtime/lib"
    bin_dir.mkdir(parents=True)
    lib_dir.mkdir(parents=True)
    gpu_src = (out / "gpu/libbbgpu.so").resolve()
    gpu_dst = bin_dir / "gpu/libbbgpu.so"
    gpu_dst.parent.mkdir()
    shutil.copyfile(gpu_src, gpu_dst)
    run("strip", "--strip-debug", gpu_dst)

    runtime = {}
    loader = read_loader(out / PROGRAMS[0])

    def merge_libraries(resolved: dict[str, Path]) -> None:
        for name, path in sorted(resolved.items()):
            if path.resolve() == gpu_src:
                continue
            package_path(path)
            previous = runtime.get(name)
            if previous is not None and path != previous and sha256(path) != sha256(previous):
                raise ValueError(f"The executables require different libraries named {name}")
            runtime[name] = path

    for program_name in PROGRAMS:
        program = out / program_name
        if read_loader(program) != loader:
            raise ValueError(f"The executables use different dynamic loaders: {program}")
        resolved = dependencies(loader, program)
        resolved[loader.name] = loader
        merge_libraries(resolved)

        image = bin_dir / f"{program_name}.elf"
        shutil.copyfile(program, image)
        run("strip", "--strip-debug", image)
        old_interp = set_fd_interpreter(image)
        if Path(old_interp) != loader:
            raise ValueError(f"Interpreter changed during processing for {program_name}")
        image.chmod(0o755)
        script = bin_dir / program_name
        script.write_text(WRAPPER.replace("@PROGRAM@", program_name))
        script.chmod(0o755)

    for name, package in SDL_PLUGINS.items():
        if name not in runtime:
            path = unique_store_path(f"*-{package}-[0-9]*/lib/{name}")
            merge_libraries({name: path, **dependencies(loader, path)})

    # FFmpeg asks for the unversioned Vulkan alias; the engine uses the SONAME.
    vulkan_alias = runtime["libvulkan.so.1"].with_name("libvulkan.so")
    if not vulkan_alias.samefile(runtime["libvulkan.so.1"]):
        raise ValueError("The Vulkan aliases do not identify the same loader")
    runtime[vulkan_alias.name] = vulkan_alias

    if "libasound.so.2" not in runtime:
        raise ValueError("The DSE output requires ALSA")
    alsa = package_path(runtime["libasound.so.2"]) / "share/alsa"
    if not (alsa / "alsa.conf").is_file():
        raise ValueError(f"Missing ALSA configuration: {alsa}")
    shutil.copytree(alsa, payload / "runtime/share/alsa")
    keyboards = unique_store_path("*-xkeyboard-config-[0-9]*/share/xkeyboard-config-2")
    shutil.copytree(keyboards, payload / "runtime/share/xkb")

    libraries = []
    for name, origin in sorted(runtime.items()):
        target = lib_dir / name
        shutil.copyfile(origin, target)
        target.chmod(0o755 if name.startswith("ld-linux-") else 0o644)
        libraries.append({"file": str(target.relative_to(payload)), "sha256": sha256(target), "nix_path": str(origin)})
    store_paths = sorted({package_path(file) for file in runtime.values()} | {package_path(keyboards)})
    packages = {}
    for store_path in store_paths:
        notices = payload / "runtime/notices" / store_path.name
        copy_notices(store_path, notices)
        packages[str(store_path)] = find_deriver(store_path)
    known_derivers = [drv for drv in packages.values() if drv != "unknown-deriver" and Path(drv).is_file()]
    raw_recipes = json.loads(run("nix", "derivation", "show", *known_derivers)) if known_derivers else {}
    recipes = raw_recipes.get("derivations", raw_recipes)
    for recipe in recipes.values():
        env = recipe.get("env", {})
        if "__json" in env:
            env.update(json.loads(env["__json"]))
        recipe.clear()
        recipe.update({key: env[key] for key in ("name", "pname", "version", "src", "patches") if key in env})

    manifest = {
        "nixpkgs_revision": nixpkgs_revision,
        "libraries": libraries,
        "packages": packages,
        "recipes": recipes,
    }
    (payload / "runtime/sources.json").write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n")

    shutil.copyfile(repo / "LICENSE", payload / "LICENSE")
    shutil.copyfile(repo / "docs/profiles.md", payload / "Profiles.md")
    shutil.copyfile(repo / "scripts/start-linux.sh", payload / "start-linux.sh")
    (payload / "start-linux.sh").chmod(0o755)
    shutil.copytree(repo / "mods/DSE Haptics", payload / "mods/DSE Haptics")
    (payload / "README.md").write_text(README)

    portable_loader = lib_dir / loader.name
    library_path = f"{bin_dir / 'gpu'}:{lib_dir}"
    for program_name in PROGRAMS:
        image = bin_dir / f"{program_name}.elf"
        output = run(portable_loader, "--inhibit-cache", "--library-path", library_path, "--list", image)
        for path in re.findall(r"=> (/.*?)\s+\(0x", output):
            if not Path(path).is_relative_to(payload):
                raise ValueError(f"{program_name} resolved a dependency outside the payload: {path}")

    checksums = []
    for path in sorted(payload.rglob("*")):
        if path.is_file():
            checksums.append(f"{sha256(path)}  {path.relative_to(payload)}")
    (payload / "SHA256SUMS").write_text("\n".join(checksums) + "\n")
    print(f"Assembled {len(libraries)} runtime libraries from {len(packages)} Nix packages.")


def archive_metadata(info: tarfile.TarInfo) -> tarfile.TarInfo:
    info.uid = info.gid = 0
    info.uname = info.gname = "root"
    return info


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", type=Path, required=True, help="patched engine directory with out/ binaries")
    parser.add_argument("--output", type=Path, required=True, help="destination .tar.gz file")
    parser.add_argument("--nixpkgs-revision", required=True, help="full Nixpkgs commit used for the build")
    args = parser.parse_args()
    if not re.fullmatch(r"[0-9a-f]{40}", args.nixpkgs_revision):
        parser.error("--nixpkgs-revision must be a full lowercase 40-digit commit hash")
    repo = Path(__file__).resolve().parent.parent
    output = args.output.resolve()
    output.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="bbport-dse-linux-", dir=output.parent) as workspace:
        payload = Path(workspace) / "release-payload"
        build_payload(args.source.resolve(), payload, repo, args.nixpkgs_revision)
        archive = payload.parent / output.name
        with tarfile.open(archive, "w:gz") as tar:
            tar.add(payload, arcname=payload.name, filter=archive_metadata)
        archive.replace(output)
    print(f"{sha256(output)}  {output.name}")


if __name__ == "__main__":
    main()
