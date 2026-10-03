#!/usr/bin/env bash
# Build wowpad's version.dll (32-bit) with mingw-w64 and sanity-check it.
set -euo pipefail
cd "$(dirname "$0")"

if ! command -v i686-w64-mingw32-g++ >/dev/null; then
    echo "i686-w64-mingw32-g++ not found."
    echo "  Debian/Ubuntu: sudo apt install g++-mingw-w64-i686"
    echo "  Fedora:        sudo dnf install mingw32-gcc-c++"
    echo "  Arch:          sudo pacman -S mingw-w64-gcc"
    exit 1
fi

python3 scripts/check_signals.py
make "$@"

DLL=build/version.dll
echo
echo "Built $DLL ($(stat -c %s "$DLL") bytes)"
if command -v i686-w64-mingw32-objdump >/dev/null; then
    i686-w64-mingw32-objdump -f "$DLL" | grep -q 'pei-i386' \
        && echo "Arch: x86 (32-bit) OK" || { echo "ERROR: not a 32-bit PE"; exit 1; }
    echo "Imports: $(i686-w64-mingw32-objdump -p "$DLL" | awk '/DLL Name/{print $3}' | tr '\n' ' ')"
    echo "Exports: $(i686-w64-mingw32-objdump -p "$DLL" | sed -n '/Ordinal\/Name Pointer/,/^$/p' | grep -c $'^\t\[')"
fi
