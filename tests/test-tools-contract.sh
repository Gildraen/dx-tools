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

node <<'EOF'
const assert = require('node:assert/strict');
const fs = require('node:fs');
const config = JSON.parse(fs.readFileSync('release-please-config.json', 'utf8'));
const manifest = JSON.parse(fs.readFileSync('.release-please-manifest.json', 'utf8'));
assert.equal(config['include-v-in-tag'], false);
assert.equal(config['bootstrap-sha'], 'f7b5a41f48026571cafe3e7d287dd0234db9c0b6');
assert.equal(config.packages['.']['release-type'], 'simple');
assert.equal(config.packages['.']['version-file'], 'version.txt');
assert.equal(manifest['.'], '0.1.0');
assert.equal(fs.readFileSync('version.txt', 'utf8').trim(), manifest['.']);
assert.equal(JSON.parse(fs.readFileSync('renovate.json', 'utf8')).extends[0], 'github>Gildraen/renovate-config#0.2.0');
const workflow = fs.readFileSync('.github/workflows/validate.yml', 'utf8');
assert.match(workflow, /needs: validate/);
assert.match(workflow, /if: github\.event_name == 'push' && github\.ref == 'refs\/heads\/main'/);
assert.match(workflow, /permissions:\n      contents: write\n      issues: write\n      pull-requests: write/);
assert.match(workflow, /reusable-release-please\.yml@4b4026ff669b5fe8da2aa83e216591bb09e1e8a1 # 0\.2\.0/);
assert.match(workflow, /config-file: release-please-config\.json/);
assert.match(workflow, /manifest-file: \.release-please-manifest\.json/);
assert.match(workflow, /target-branch: main/);
assert.match(workflow, /release-please-token: \$\{\{ secrets\.RELEASE_PLEASE_TOKEN \|\| secrets\.GITHUB_TOKEN \}\}/);
assert.doesNotMatch(workflow, /googleapis\/release-please-action/);
EOF

echo "tools home priority, legacy fallback, callback, and missing Docker contracts pass"
