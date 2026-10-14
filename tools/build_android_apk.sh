#!/bin/sh
set -eu

project_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
output_path="$project_dir/build/LivingTerrarium3D-v8.4-ARM64.apk"
install_after_build=0

if [ "${1:-}" = "--install" ]; then
	install_after_build=1
	shift
fi
if [ "$#" -gt 0 ]; then
	printf 'Usage: %s [--install]\n' "$0" >&2
	exit 2
fi

godot_bin=${GODOT_BIN:-}
if [ -z "$godot_bin" ]; then
	for candidate in godot godot4; do
		if command -v "$candidate" >/dev/null 2>&1; then
			godot_bin=$candidate
			break
		fi
	done
fi
if [ -z "$godot_bin" ] || ! command -v "$godot_bin" >/dev/null 2>&1; then
	printf 'Godot 4 executable not found. Set GODOT_BIN to a Godot 4 binary.\n' >&2
	exit 127
fi

mkdir -p "$project_dir/build"
"$godot_bin" --headless --path "$project_dir" --editor --quit
"$godot_bin" --headless --path "$project_dir" --export-debug "Android" "$output_path"
if [ ! -s "$output_path" ]; then
	printf 'Godot completed without producing %s. Check Android SDK and export templates.\n' "$output_path" >&2
	exit 1
fi
printf 'Built APK: %s\n' "$output_path"

if [ "$install_after_build" -eq 1 ]; then
	if ! command -v adb >/dev/null 2>&1; then
		printf 'adb not found; APK built but could not be installed.\n' >&2
		exit 127
	fi
	adb install -r "$output_path"
fi
