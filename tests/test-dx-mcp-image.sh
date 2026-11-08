#!/usr/bin/env bash
# Checks that dx-mcp always runs the pinned GitHub MCP image.
set -euo pipefail

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

workdir="$(mktemp -d)"
trap 'rm -rf "$workdir"' EXIT

# Fake docker CLI that just echoes its args, so we can inspect which image dx-mcp would run.
cat > "$workdir/docker" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*"
exit "${FAKE_DOCKER_EXIT:-0}"
EOF
chmod +x "$workdir/docker"

# No override: must fall back to the pinned default image.
default_output="$(PATH="$workdir:/usr/bin:/bin" bin/dx-mcp github)"
[[ "$default_output" == *"ghcr.io/github/github-mcp-server:v1.10.1"* ]] || fail "default image is not pinned"

override_output="$(GITHUB_MCP_IMAGE="ghcr.io/example/override:latest" PATH="$workdir:/usr/bin:/bin" bin/dx-mcp github)"
[[ "$override_output" == *"ghcr.io/github/github-mcp-server:v1.10.1"* ]] || fail "environment override changed the pinned image"
[[ "$override_output" != *"ghcr.io/example/override:latest"* ]] || fail "environment override was used"

forwarded_output="$(PATH="$workdir:/usr/bin:/bin" bin/dx-mcp github --read-only --toolsets issues)"
[[ "$forwarded_output" == *"--read-only --toolsets issues"* ]] || fail "server arguments were not forwarded"

if bin/dx-mcp >/dev/null 2>&1; then
  fail "missing server argument returned success"
else
  [[ $? -eq 2 ]] || fail "missing server argument returned the wrong status"
fi

if bin/dx-mcp unknown >/dev/null 2>&1; then
  fail "unknown server argument returned success"
else
  [[ $? -eq 2 ]] || fail "unknown server argument returned the wrong status"
fi

if PATH="$workdir:/usr/bin:/bin" FAKE_DOCKER_EXIT=23 bin/dx-mcp github >/dev/null 2>&1; then
  fail "docker failure was not propagated"
else
  [[ $? -eq 23 ]] || fail "docker exit status was not propagated"
fi

echo "dx-mcp image, forwarding, and error contracts pass"
