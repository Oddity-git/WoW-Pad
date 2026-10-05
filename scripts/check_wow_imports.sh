#!/usr/bin/env bash
# Shows whether Wow.exe imports VERSION.dll (so the proxy gets loaded) and
# which version functions it uses. Run once against YOUR Wow.exe.
#   usage: scripts/check_wow_imports.sh /path/to/Wow.exe
set -eu
EXE="${1:?usage: $0 /path/to/Wow.exe}"
OBJDUMP=i686-w64-mingw32-objdump
command -v "$OBJDUMP" >/dev/null || OBJDUMP=objdump

# Capture once: piping objdump into `grep -q` under pipefail gave false negatives.
DUMP="$("$OBJDUMP" -p "$EXE")"

echo "== DLLs imported by $(basename "$EXE") =="
awk '/DLL Name/{print "  " $3}' <<<"$DUMP"

echo
echo "== Functions imported from VERSION.dll =="
awk '
    /DLL Name:/ { inver = (tolower($3) == "version.dll"); next }
    inver && NF >= 2 && $(NF-1) ~ /^[0-9]+$/ && $NF ~ /^[A-Za-z_]/ { print "  " $NF }
    inver && /^[ \t]*$/ { inver = 0 }' <<<"$DUMP"

if grep -qi 'DLL Name: version.dll' <<<"$DUMP"; then
    echo
    echo "OK: imports VERSION.dll statically; the proxy will load at startup."
else
    echo
    echo "WARNING: no static VERSION.dll import. It may still be loaded later by another"
    echo "DLL (check for the 'loaded into' line in wowpad.log). If wowpad.log never"
    echo "appears, the DLL list above shows which other DLL could be proxied instead."
fi
