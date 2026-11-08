#!/usr/bin/env bash
set -euo pipefail

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source_taskfile="$repo_root/taskfiles/base.yml"
workdir="$(mktemp -d)"
trap 'rm -rf "$workdir"' EXIT

project="$workdir/project"
dogfood_runtime="$project/.devcontainer/.dx/.devcontainer/src/dx/runtime"
mkdir -p "$dogfood_runtime" "$workdir/explicit"
cp "$source_taskfile" "$workdir/Taskfile.yml"
cp "$source_taskfile" "$project/Taskfile.yml"

stable_status=0
stable_output="$(env -u DX_HOME task --dir "$workdir" doctor 2>&1)" || stable_status=$?
[[ "$stable_output" == *"DX_HOME=/opt/dx"* ]] || fail "doctor did not select the stable runtime"
if [[ -d /opt/dx ]]; then
  [[ "$stable_status" -eq 0 ]] || fail "doctor failed for an existing stable runtime"
  [[ "$stable_output" == *"runtime: found"* ]] || fail "doctor did not find the stable runtime"
else
  [[ "$stable_status" -ne 0 ]] || fail "doctor succeeded for a missing stable runtime"
  [[ "$stable_output" == *"runtime: NOT found"* ]] || fail "doctor did not report the missing stable runtime"
fi

dogfood_output="$(env -u DX_HOME task --dir "$project" doctor)"
[[ "$dogfood_output" == *"DX_HOME=$dogfood_runtime"* ]] || fail "doctor did not resolve the documented dogfood path"
[[ "$dogfood_output" == *"runtime: found"* ]] || fail "doctor did not find the dogfood runtime"

explicit_output="$(DX_HOME="$workdir/explicit" task --dir "$project" doctor)"
[[ "$explicit_output" == *"DX_HOME=$workdir/explicit"* ]] || fail "doctor did not honor DX_HOME"

if (DX_HOME="$workdir/missing" task --dir "$project" doctor >/dev/null 2>&1); then
  fail "doctor succeeded for a missing explicit runtime"
fi

echo "dx doctor runtime resolution and missing-runtime failure pass"
