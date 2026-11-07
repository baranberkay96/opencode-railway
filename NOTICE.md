# NOTICE: OpenCode v1 AI Coding Agent in the Browser template

## Software installed in the image

| Component | Source | License | How it is used |
|---|---|---|---|
| OpenCode 1.19.3 | GitHub release assets of https://github.com/anomalyco/opencode (`opencode-linux-x64-baseline.tar.gz`, `opencode-linux-arm64.tar.gz`, SHA-256 checked) | MIT, Copyright (c) 2025 opencode (LICENSE from tag `v1.19.3`, kept in `/usr/local/share/doc/opencode/LICENSE`) | Unmodified release binary, run as `opencode serve` |
| Ubuntu 24.04 LTS | `ubuntu:noble-20260930.1@sha256:68ee2200…` (Docker Hub official image) | various (Ubuntu archive packages) | Base OS; apt packages installed unmodified |
| git, git-lfs, OpenSSH client, tmux, build-essential, Python 3, ripgrep, fd, jq, sqlite3, tini, sudo and other tools | Ubuntu archive | various (GPL, ISC, MIT, BSD, PSF, ...) | Installed unmodified |
| Node.js 24.22.0 LTS | https://nodejs.org/dist/ official tarball (SHA-256 checked) | MIT (plus bundled dependency licenses, kept in `/usr/local/share/doc/nodejs/LICENSE`) | Runtime for npm/npx in the agent's projects |
| GitHub CLI 2.103.3 | GitHub release tarball, https://github.com/cli/cli | MIT | Installed unmodified |
| uv 0.13.1 | Astral installer `astral.sh/uv/0.13.1/install.sh`, https://github.com/astral-sh/uv | MIT or Apache-2.0 | Installed unmodified |
| Caddy 2.11.7 | GitHub release tarball (SHA-512 checked), https://github.com/caddyserver/caddy | Apache-2.0 (license kept in `/usr/local/share/doc/caddy/LICENSE`) | HTTP front and healthcheck, unmodified binary with our own generated Caddyfile |

"OpenCode" and other product names belong to their owners. This is a community template, not affiliated with the OpenCode project, Anomaly, any model provider or Railway. Users connect their own model providers and are bound by each provider's terms.

## Upstream sources and docs checked (2026-10-20)

- GitHub `anomalyco/opencode`: license MIT; release `v1.19.3` (2026-10-16, latest, not a prerelease); asset digests `sha256:531cff24…a5765d` (linux-x64-baseline) and `sha256:7900818a…cee405` (linux-arm64). The amd64 tarball was downloaded and checked: SHA-256 matches, it holds one file `opencode` (ELF x86-64, glibc ≥ 2.30, needs only libc/libm/libpthread/libdl), and contains the embedded web UI file map.
- OpenCode source at `v1.19.3` (read via the GitHub API):
  - `packages/opencode/src/cli/cmd/serve.ts`, `web.ts`, `cli/network.ts`: `serve` and `web` start the same server; flags `--hostname` (default 127.0.0.1), `--port`, `--cors`, `--mdns`; `web` only adds a banner and a browser launch.
  - `packages/opencode/src/server/auth.ts`, `server/routes/instance/httpapi/middleware/authorization.ts`, `server/shared/public-ui.ts`, `server/routes/instance/httpapi/api.ts`: basic auth from `OPENCODE_SERVER_PASSWORD`/`OPENCODE_SERVER_USERNAME` (default `opencode`) on every route incl. `/global/health`; public only `/site.webmanifest` and two manifest icons; `?auth_token=` alternative; PTY WebSocket uses one-time tickets.
  - `packages/server/src/cors.ts`, `server/routes/instance/httpapi/handlers/pty.ts`: PTY ticket and connect require `Origin` host = `Host`.
  - `packages/opencode/src/server/shared/ui.ts`, `packages/opencode/script/build.ts`, `.github/workflows/publish.yml`: release builds embed `packages/app`; fallback proxy to `app.opencode.ai` only without an embedded UI.
  - `packages/core/src/global.ts`: data in `$XDG_DATA_HOME/opencode`, config `$XDG_CONFIG_HOME/opencode`, cache, state.
  - `packages/core/src/flag/flag.ts`, `src/effect/runtime-flags.ts`, `src/index.ts`: `OPENCODE_DISABLE_AUTOUPDATE`, `OPENCODE_CONFIG_CONTENT`, `--print-logs`, `--log-level`.
  - `packages/opencode/src/provider/provider.ts` and models.dev `api.json`: provider env names; free `opencode` models without a key; `GITHUB_TOKEN` = GitHub Copilot credential; Google key passed by the AI SDK's own env name.
  - `packages/opencode/src/plugin/openai/codex.ts`, `plugin/github-copilot/copilot.ts`: headless device logins.
  - `packages/opencode/src/installation/index.ts`: install-method detection (our `/usr/local/bin` binary is "unknown", so in-app upgrades do not replace it).
  - `packages/opencode/Dockerfile`: upstream's own container uses the x64 **baseline** build.
  - Docs `packages/web/src/content/docs/server.mdx`, `web.mdx`, `config.mdx`, `troubleshooting.mdx`; release notes v1.19.0 to v1.19.3 (session sharing discontinued in 1.19.1; OpenCode 2 is a separate major).
- npm `opencode-ai`: `latest` = 1.19.3 (published 2026-10-16), MIT.
- Docker Hub `library/ubuntu`: `noble-20260930.1` = `24.04` = `sha256:68ee22004a9109b44973313b02ff7b1de250f1de0f5ecb628d73f579aaff33ac`.
- Ubuntu noble/noble-updates package indexes (main, universe): all 42 apt packages exist; `setpriv`, `runuser`, `mountpoint` ship in `util-linux` (Priority: required).
- Node.js `SHASUMS256.txt` for v24.22.0; Caddy `caddy_2.11.7_checksums.txt`; gh `gh_2.103.3_checksums.txt`; uv 0.13.1 installer URL.
- Caddy v2.11.7 source: `modules/caddyhttp/rewrite/rewrite.go` (`?` clears the query), `reverseproxy/caddyfile.go` (`handle_response`, named response matchers), `responsematchers.go` (`status 2xx`), `replacer.go` (`{env.*}`), `headers/headers.go` (placeholders in `header_up`), `caddytest/.../reverse_proxy_handle_response.caddyfiletest`.

## Market templates and repositories reviewed

| Template / repo | License | Use |
|---|---|---|
| `opencode` / `LaceLetho/opencode-railway-template` | none found (all rights reserved) | Read only (volume layout, cookie-auth wrapper, source build). Nothing copied. |
| `opencode-ai` / `gridalpha/opencode-railway` | README states MIT, but the repository has no LICENSE file; treated as all rights reserved | Read only (Caddy front with an authenticated health probe, `HOME` on the volume, refuse-to-start check). Ideas reimplemented in our own files; no file or text copied. |
| `opencode-cli-web-app` / image `ghcr.io/yuting1214/opencode-railway:1.0` | not reviewed (prebuilt third-party image) | Only its published template config and README were read. Nothing copied. |

All files in this package (Dockerfile, entrypoint, helpers, Caddyfile renderer, profile and the docs) were written for this template. The supervise loop, env file and privilege-drop patterns follow our own `59-ubuntu-devbox` and `22-ai-workstation` templates.
