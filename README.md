# dx-tools

Portable GitHub MCP launcher and shared Task helpers. This repository does
not install tools or provide agent rules, a Dev Container Feature, or a
PATH wrapper.

`bin/dx-mcp github [server options...]` runs the official GitHub MCP server
image pinned in this launcher using Bash and Docker.
Docker must have access to a running daemon. The launcher forwards server
options and Docker's exit status, binds the OAuth callback to
`127.0.0.1:8085`, and sets `GITHUB_OAUTH_CALLBACK_PORT=8085`.
`GITHUB_MCP_IMAGE` from the environment does not override the pinned image.

Add this checkout's `bin/` to `PATH`, or call the executable directly.
The executable does not resolve a home directory; installed wrappers are
owned by the installer that provides them.

## Task helpers

With Go Task v3, include the local file from a consumer Taskfile:

```yaml
version: '3'
includes:
  dx: /path/to/dx-tools/taskfiles/base.yml
```

For a remote include, use a direct HTTP URL with the commit SHA in its path
and the full release tag in a trailing comment:

```yaml
version: '3'
includes:
  dx: https://github.com/Gildraen/dx-tools/raw/<commit-sha>/taskfiles/base.yml # <full-semver-tag>
```

Use a Task release that supports native HTTP remote includes and allow
`github.com` in Task's trusted hosts (`TASK_REMOTE_TRUSTED_HOSTS=github.com`).
The URL SHA pins the file revision; the trailing tag records the release for
version tracking. Automated Renovate updates require a matching configuration.

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

doctor test checks success when `/opt/dx` exists and failure when it is absent.
Run `task validate` and `task test` with Bash, Node.js and Go Task. MCP tests
use a fake Docker CLI and do not contact GitHub or a Docker daemon. The legacy
doctor test checks success when `/opt/dx` exists and failure when it is absent.

## Releases

After `validate` succeeds on a push to `main`, the separate `release-please.yml`
workflow waits for that run and calls the shared Release Please workflow. It
opens or updates a release PR from Conventional Commits. Merge it to create a GitHub Release and
a stable tag without `v`; the historical `v` tags remain unchanged. Release
Please starts from the current tag and increments the manifest and `version.txt`
together. The release job calls the shared Release Please workflow from
`Gildraen/ci-workflows`, pinned to commit
`b04cfb98139aa06de661c70a128452184f2004dd` (future tag `0.2.0`). Publish that
ci-workflows release before merging this PR. The Renovate pin tracks preset
`0.2.0`, which must also be published before this PR is merged.

Configure `RELEASE_PLEASE_TOKEN` as a fine-grained repository secret so CI runs
automatically on the release PR. GitHub suppresses workflow runs for pull
requests created with `GITHUB_TOKEN`; without the secret, required PR checks
may not run and must be handled before merging.

Set `DX_AGENTS_HOME` to a supplied `dx-agents` checkout to load its root
`AGENTS.md` through this repository's minimal bootstrap. Agent guidance is
not bundled here.
