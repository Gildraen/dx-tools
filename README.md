# dx-tools

Portable GitHub MCP launcher and shared Task helpers. This repository does
not install tools or provide agent rules, a Dev Container Feature, or a
PATH wrapper.

  ```yaml
  version: '3'
  includes:
  dx: https://github.com/Gildraen/dx-tools/raw/6630f37ffdc3a8c51af0f4795145a4743a61584b/taskfiles/base.yml # v0.1.0-rc.1

`bin/dx-mcp github [server options...]` runs the official
`ghcr.io/github/github-mcp-server:v1.10.1` image using Bash and Docker.
Docker must have access to a running daemon. The launcher forwards server
options and Docker's exit status, binds the OAuth callback to
`127.0.0.1:8085`, and sets `GITHUB_OAUTH_CALLBACK_PORT=8085`.
`GITHUB_MCP_IMAGE` from the environment does not override the pinned image.

Add this checkout's `bin/` to `PATH`, or call the executable directly.
The executable does not resolve a home directory; installed wrappers are
owned by the installer that provides them.

## Task helpers

With Task v3 installed, include the local file from a consumer Taskfile:

```yaml
version: '3'
includes:
  dx: /path/to/dx-tools/taskfiles/base.yml
```

The candidate tag is `v0.1.0-rc.1`, a prerelease, not a stable release; it
resolves to commit `6630f37ffdc3a8c51af0f4795145a4743a61584b`. With Task
v3.53.1, the remote include uses the direct HTTP URL pinned to that SHA:

```yaml
version: '3'
includes:
  dx: https://github.com/Gildraen/dx-tools/raw/6630f37ffdc3a8c51af0f4795145a4743a61584b/taskfiles/base.yml # v0.1.0-rc.1
```

Allow `github.com` in Task's trusted hosts (`TASK_REMOTE_TRUSTED_HOSTS=github.com`).
The URL selects the fixed commit; the trailing tag comment is Renovate's update stream.

`task dx:doctor` prints the selected home and checks directory existence
offline. It does not check authentication, Docker, or installation contents.
Selection is deterministic:

1. Nonempty `DX_TOOLS_HOME`: a tools checkout or installed tools directory.
2. Nonempty `DX_HOME`: the legacy runtime directory.
3. Existing `$PWD/.devcontainer/.dx/.devcontainer/src/dx/runtime`.
4. `/opt/dx`.

An explicit missing directory fails without fallback. With `DX_TOOLS_HOME`,
the diagnostic is `DX_TOOLS_HOME=<path>`; legacy selection keeps
`DX_HOME=<path>` and the existing `runtime: found` / `runtime: NOT found`
messages.

`task dx:mcp:github -- [server options...]` invokes `dx-mcp github` on
`PATH`. Setting `DX_TOOLS_HOME` alone does not configure `PATH`.
Project contracts such as `validate`, `test`, and `lint` remain in the
consumer's own Taskfile.

## Compatibility

Installers can place `bin/` and `taskfiles/` under an independent tools home
and expose it through `DX_TOOLS_HOME`. Existing installations under
`DX_HOME` remain usable. A wrapper supporting both selects nonempty
`DX_TOOLS_HOME` first, then the legacy resolution above, and executes
`"$selected_home/bin/dx-mcp" "$@"` without suppressing errors.

The legacy doctor path is retained until the Feature, its wrapper, and
consumers use `DX_TOOLS_HOME`. Unsetting `DX_TOOLS_HOME` restores legacy
selection while the old runtime remains installed.

## Development

Run `task validate` and `task test` with Bash and Task v3. MCP tests use a
fake Docker CLI and do not contact GitHub or a Docker daemon. The legacy
doctor test checks success when `/opt/dx` exists and failure when it is absent.

Set `DX_AGENTS_HOME` to a supplied `dx-agents` checkout to load its root
`AGENTS.md` through this repository's minimal bootstrap. Agent guidance is
not bundled here.
