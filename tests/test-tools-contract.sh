#!/usr/bin/env bash
set -euo pipefail

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
workdir="$(mktemp -d)"
trap 'rm -rf "$workdir"' EXIT
mkdir -p "$workdir/tools checkout" "$workdir/fake-bin"
cp "$repo_root/taskfiles/base.yml" "$workdir/Taskfile.yml"

output="$(DX_TOOLS_HOME="$workdir/tools checkout" DX_HOME="$workdir/missing" task --silent --dir "$workdir" doctor)"
[[ "$output" == *"DX_TOOLS_HOME=$workdir/tools checkout"* ]] || fail "tools home did not take priority"
[[ "$output" == *"runtime: found"* ]] || fail "tools home with spaces was not found"
[[ "$output" != *"DX_HOME="* ]] || fail "tools selection reported the legacy home"

if DX_TOOLS_HOME="$workdir/missing" DX_HOME="$repo_root" task --silent --dir "$workdir" doctor >"$workdir/output" 2>&1; then
  fail "missing tools home silently fell back to DX_HOME"
fi
grep -Fq 'runtime: NOT found' "$workdir/output" || fail "missing tools diagnostic was lost"

output="$(DX_TOOLS_HOME= DX_HOME="$repo_root" task --silent --dir "$workdir" doctor)"
[[ "$output" == *"DX_HOME=$repo_root"* ]] || fail "empty tools home did not preserve the legacy fallback"

cat > "$workdir/fake-bin/docker" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$@"
EOF
chmod +x "$workdir/fake-bin/docker"
output="$(PATH="$workdir/fake-bin:$PATH" "$repo_root/bin/dx-mcp" github --toolsets 'issues,pull_requests')"
[[ "$output" == *"127.0.0.1:8085:8085"* ]] || fail "callback binding changed"
[[ "$output" == *"GITHUB_OAUTH_CALLBACK_PORT=8085"* ]] || fail "callback environment changed"
[[ "$output" == *"issues,pull_requests"* ]] || fail "server option changed"

ln -s "$(command -v bash)" "$workdir/fake-bin/bash"
rm "$workdir/fake-bin/docker"
if PATH="$workdir/fake-bin" "$repo_root/bin/dx-mcp" github >"$workdir/output" 2>&1; then
  fail "missing Docker returned success"
else
  [[ $? -eq 1 ]] || fail "missing Docker status changed"
fi
grep -Fq 'Docker is required' "$workdir/output" || fail "missing Docker diagnostic changed"

echo "tools home priority, legacy fallback, callback, and missing Docker contracts pass"
