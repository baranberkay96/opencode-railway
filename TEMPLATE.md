# OpenCode v1 AI Coding Agent in the Browser: Railway template spec

## Listing

| Field | Value |
|---|---|
| Name | **OpenCode v1 AI Coding Agent in the Browser** (42 chars, as given; "v1" = pinned major 1.19.3) |
| Description | Run the OpenCode coding agent 24/7 with web UI, git and a persistent disk. (74 chars, as given) |
| Category | AI/ML |
| Tags | opencode, ai-coding-agent, coding-agent, web-ui, llm, git, anthropic, openai, openrouter, developer-tools |
| Icon | `https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/svg/opencode.svg` (200, image/svg+xml) |
| Expected template code | `opencode-v1-ai-coding-agent-in-the-brows` (Railway slug truncated to 40 chars; the README deploy button uses it, confirm after publishing) |

The description is delivered as written: restart policy ALWAYS and no app sleeping (24/7), the OpenCode web UI on the public domain, git and the GitHub CLI in the image, and `/data` on a Railway volume.

## Base market template

Three market templates were reviewed (`_market/*.json`, `_upstream/*`):

| Market template | Active | Source | What we kept | Problems fixed |
|---|---|---|---|---|
| `opencode` ("OpenCode") | 47 | `LaceLetho/opencode-railway-template` (no license, read only) | Volume at `/data` with all state on it, password login, `opencode attach` from a laptop | No password generated (empty required input); builds OpenCode from source with Bun at deploy (slow, fragile; the template default `v1.14.41` is behind); a custom 1,250-line Node auth proxy; installs `oh-my-openagent@latest` and runs `npx skills update -g` on every start (unpinned third-party code); Serverless sleep on by default; no healthcheck |
| `opencode-cli-web-app` ("OpenCode CLI + Web App") | 38 | prebuilt image `ghcr.io/yuting1214/opencode-railway:1.0` (third party, contents not reviewable) | `secret()` password, provider keys as optional variables, git + gh, volume | Opaque third-party image; healthcheck on `/site.webmanifest`, a static file that does not prove the API or auth works |
| `opencode-ai` ("OpenCode") | 25 | `gridalpha/opencode-railway` (README says MIT, no LICENSE file in the repo: read only) | **Closest to our design, used as the functional base**: Caddy front, authenticated health probe idea, `HOME` on the volume, refuse to start without a password, tini as subreaper | Unpinned `opencode-ai@latest` and `caddy:2-alpine`; runs everything as root; `opencode web` (tries to open a browser, needs a shim); restart policy ON_FAILURE with 10 retries; health endpoint returns OpenCode's JSON (version) to anyone |

No file or text from these repositories was copied. All files here were written for this template; the supervise loop and the env-file pattern come from our own `59-ubuntu-devbox`.

## Pinned versions

| Component | Source | Version | Released | Checked |
|---|---|---|---|---|
| Base image | `ubuntu:noble-20260930.1@sha256:68ee2200…aff33ac` (= `24.04`) | Ubuntu 24.04 LTS | pushed 2026-10-17 | 2026-10-20 |
| OpenCode | GitHub release `v1.19.3`: `opencode-linux-x64-baseline.tar.gz` (amd64), `opencode-linux-arm64.tar.gz` (arm64), SHA-256 from the release asset digests; LICENSE from the tag, SHA-256 pinned | 1.19.3 (npm `opencode-ai` `latest`) | 2026-10-16 | 2026-10-20 |
| Node.js | nodejs.org tarball, SHA-256 pinned | 24.22.0 LTS "Krypton" | 2026-10-14 | 2026-10-20 |
| GitHub CLI | GitHub release tarball, SHA-256 pinned (the apt repo lists only the newest release, so pins there stop building) | 2.103.3 | 2026-11-03 | 2026-11-07 |
| Caddy | GitHub release tarball, SHA-512 pinned | 2.11.7 (latest) | 2026-10-03 | 2026-10-20 |
| uv | Astral installer `astral.sh/uv/0.13.1/install.sh` | 0.13.1 (0.13.2 came out 2026-10-19) | 2026-10-14 | 2026-10-20 |

All pins are `PIN_*` build args at the top of `services/opencode/Dockerfile` (prefix avoids collisions with tools' env variables, Rule 8.10). The amd64 build uses OpenCode's "baseline" binary (no AVX2 requirement), the same choice upstream makes in `packages/opencode/Dockerfile`; the npm package would instead pick a binary from the build machine's CPU flags at install time. The release binary embeds the web UI of the same version (`packages/opencode/script/build.ts` builds `packages/app` into the binary unless `--skip-embed-web-ui`; the publish workflow does not pass it; the file map is present in the downloaded binary), so the UI never comes from `app.opencode.ai` and always matches the server. OpenCode 2 is a separate major line (`opencode upgrade --major`) and out of scope for this "v1" template.

## Architecture

```
 Browser ── HTTPS (Railway edge) ──► :8080 Caddy (www-data) ─┬─ /healthz ─► GET /global/health with Authorization → "ok" | 503
                                                              └─ /*  ──────► 127.0.0.1:4096 OpenCode (basic auth, SSE unbuffered, WebSocket PTY)
             ┌───────────────────────────────────────────────────────────────────────────┐
             │ OpenCode service (Dockerfile in services/opencode)                         │
             │ Railway init (PID 1) → tini -s -g → opencode-entrypoint (root)            │
             │   ├─ supervise → setpriv opencode → opencode serve 127.0.0.1:4096         │
             │   └─ exec caddy run :$PORT as www-data                                    │
             │ opencode · git · gh · node 24 · python 3 · uv · build-essential · rg      │
             │ volume /data = $HOME of "opencode": .config/opencode, .local/share/opencode│
             │   (auth.json, sessions, logs), .local/state, .cache, workspace/ (projects) │
             └───────────────────────────────────────────────────────────────────────────┘
```

Why a front proxy although OpenCode has its own auth: with `OPENCODE_SERVER_PASSWORD` set, OpenCode requires basic auth on every route, including `/global/health` (`RootHttpApi` carries the `Authorization` middleware; only `/site.webmanifest` and two manifest icons are public, `server/shared/public-ui.ts`). Railway's healthcheck is anonymous, so Caddy answers `/healthz` by replaying it as an authenticated request (query string cleared) and returns only `ok` or 503. Authentication of real traffic stays with OpenCode. Caddy passes `Host` through unchanged, which OpenCode's terminal endpoints need (they compare `Origin` with `Host`), and flushes event streams immediately.

## Services

### OpenCode

| Setting | Value |
|---|---|
| Source | repo `baranberkay96/opencode-railway`, root `/services/opencode` (Dockerfile) |
| Start command | none (image entrypoint) |
| Healthcheck | `/healthz` on `PORT=8080`, timeout 300 s (authenticated probe of OpenCode's `/global/health`) |
| Public domain | yes, target port 8080 |
| TCP proxy | none |
| Volume | `/data` (home of user `opencode`) |
| Restart policy | ALWAYS (no max retries) |
| Replicas | 1 (volume-backed) |

Files in `services/opencode/`:
- `Dockerfile`: digest-pinned Ubuntu 24.04; apt toolchain (git, git-lfs, openssh-client, tmux, build-essential, Python 3, ripgrep, fd, jq, sqlite3, ...); user `opencode` (UID 1000, home `/data`, passwordless sudo via `/etc/sudoers.d/90-opencode`); checksum-verified Node.js, Caddy and OpenCode; gh from its signed apt repo; uv; build fails if `opencode --version` is not `1.19.3`; versions recorded in `/etc/opencode-railway/versions.txt`.
- `rootfs/usr/local/bin/opencode-entrypoint` (bash): validates inputs (password required, at least 12 characters, no line breaks; username charset; ports), applies `AGENT_SUDO`, prepares `/data` (first boot: skel files, OpenCode's XDG directories, `workspace`, `.ssh`; later boots: non-recursive ownership repair of those directories only), writes `/etc/opencode-railway/env.sh` (0640 root:opencode), sets git defaults and identity, runs `gh auth setup-git` when `GH_TOKEN` is set, warns when `GITHUB_TOKEN` is set (OpenCode reads it as a Copilot key), clones `GIT_REPO` once in the background, starts OpenCode under `supervise` with `PORT` removed from its environment (so dev servers the agent starts default to their own ports), renders and validates the Caddyfile, and execs Caddy as `www-data` with a minimal environment holding only the health-probe header.
- `rootfs/usr/local/lib/opencode-railway/`: `run-server` (`cd /data/workspace && exec opencode serve --hostname 127.0.0.1 --port 4096 --print-logs --log-level $OPENCODE_LOG_LEVEL`), `render-caddyfile`, `supervise` (restart loop, 3→30 s backoff), `collect-versions`.
- `rootfs/usr/local/bin/opencode-shell` (login shell as `opencode` after `railway ssh`), `opencode-tui` (`opencode attach http://127.0.0.1:4096` as `opencode`).
- `rootfs/etc/profile.d/opencode-railway.sh`: `~/.local/bin` and `~/.npm-global/bin` in `PATH`, `NPM_CONFIG_PREFIX`, env file; a one-line hint for root shells.

### Variables

| Variable | Default | Notes |
|---|---|---|
| `OPENCODE_SERVER_PASSWORD` | `${{secret(32, "<57-char unambiguous alphabet>")}}` | OpenCode's own basic auth (about 187 bits). Empty or shorter than 12 characters stops the container. |
| `OPENCODE_SERVER_USERNAME` | `opencode` | An empty value is normalized to `opencode` (OpenCode would otherwise expect an empty username). |
| `PORT` | `8080` | Caddy listen port (healthcheck, Rule 8.1); public domain target. |
| `ANTHROPIC_API_KEY`, `OPENAI_API_KEY`, `OPENROUTER_API_KEY`, `GOOGLE_GENERATIVE_AI_API_KEY`, `OPENCODE_API_KEY` | empty | Optional provider keys (env names from models.dev; Google uses `GOOGLE_GENERATIVE_AI_API_KEY` because OpenCode passes a key explicitly only for single-env providers and the AI SDK reads that name). |
| `GH_TOKEN` | empty | gh and HTTPS git. Not `GITHUB_TOKEN` (OpenCode's `github-copilot` provider reads it). |
| `GIT_USER_NAME`, `GIT_USER_EMAIL` | empty | Identity for commits; fallback `OpenCode` / `opencode@localhost` only when nothing is configured. |
| `GIT_REPO` | empty | Cloned once into `/data/workspace/{name}` (https://, ssh:// or git@ only). |
| `AGENT_SUDO` | `true` | `false` deletes the sudoers entry at start. |
| `OPENCODE_DISABLE_AUTOUPDATE` | `true` | No update checks/offers; the image pins the version. |
| `OPENCODE_LOG_LEVEL` | `WARN` | Passed as `--log-level` with `--print-logs`. |
| `RAILWAY_DEPLOYMENT_DRAINING_SECONDS` | `15` | Clean shutdown on redeploy. |

Advanced (not in the template, read at start): `OPENCODE_INTERNAL_PORT` (default 4096), `OPENCODE_ENV_PASSTHROUGH` (extra variable names for `opencode-shell`), `OPENCODE_CONFIG_CONTENT` (inline OpenCode JSON config, e.g. a default `model`), `TZ`. Any other provider key that OpenCode knows (e.g. `GROQ_API_KEY`, `DEEPSEEK_API_KEY`) can be added as a variable and is picked up at the next start.

No required inputs: the service boots with a generated password, and OpenCode's free models (when offered) work without a key.

## First login

1. Variables tab: copy `OPENCODE_SERVER_PASSWORD`. The deploy logs print the web UI URL.
2. Open `https://{public-domain}`; the browser asks for basic auth: `opencode` / the password.
3. Add a provider in the web UI (or set a key variable and redeploy), or choose a free model.
4. Open `/data/workspace/{repo}` (cloned via `GIT_REPO`, the terminal or the agent) as a project and start a session.

## Improvements over market templates

1. **Generated password, zero required inputs, never an open agent.** `secret(32)` with an unambiguous alphabet; the entrypoint and `run-server` both refuse to start without a password. The most-used market template ships an empty required password field.
2. **Official release binary, pinned and checksum-verified, with the matching embedded web UI.** No Bun build from source at deploy (LaceLetho), no `@latest` (gridalpha), no opaque third-party image (yuting1214). The build fails if the binary reports another version.
3. **A healthcheck that proves the server and its auth work**, while leaking nothing: `/healthz` returns only `ok` or 503 (gridalpha returns OpenCode's JSON including the version; yuting1214 probes a static file; LaceLetho has none).
4. **Non-root agent with an opt-out sudo**, `HOME` on the volume. All market templates run OpenCode as root.
5. **`opencode serve` instead of `opencode web`**: same server and UI, without the browser-launch attempt and its shim.
6. **Restart policy ALWAYS plus an in-container restart loop** for OpenCode (gridalpha: ON_FAILURE with 10 retries; LaceLetho: ON_FAILURE with Serverless sleep, contradicting "24/7").
7. **No unpinned code at runtime**: no plugin injection or `npx ... update` on start (LaceLetho installs `oh-my-openagent@latest` and updates skills on every boot); update checks are off.
8. **Git workflow built in**: gh credential helper from `GH_TOKEN`, `GIT_REPO` one-time clone, commit identity, SSH keys persisted, and a warning for the `GITHUB_TOKEN`/Copilot clash.
9. **Agent-friendly runtime**: `PORT` removed from the agent's environment (dev servers do not collide with Caddy), `npm i -g` and uv tools persist on the volume, tini subreaper for orphaned LSP/MCP processes, `opencode-shell`/`opencode-tui` for `railway ssh`.
10. **Security headers** (`nosniff`, `SAMEORIGIN`, `no-referrer`) at the edge of a UI that can run shell commands; OpenCode reachable only through Caddy (loopback bind).

## Resource estimate

Railway prices: RAM $10/GB-month, vCPU $20/vCPU-month, volume $0.15/GB-month. Estimates, not measurements.

| Profile | RAM | CPU | Volume | $/month |
|---|---|---|---|---|
| Idle (server up, nobody connected) | ~0.3 GB (OpenCode ~0.25, Caddy ~0.02) | ~0.01 vCPU | 1 GB | ≈ $3.5 |
| Typical (a few sessions a day, language servers, test runs) | ~1.0 GB avg, 2-3 GB peaks | ~0.2 vCPU avg | 5 GB | ≈ $15 |
| Heavy (long agent runs most of the day, builds, several repos) | ~2.5 GB avg | ~0.6 vCPU avg | 20 GB | ≈ $40 |

Model usage is billed by the provider. Minimum plan: **Trial** boots it (well under 1 GB idle), but language servers and builds can hit the 1 GB limit; **Hobby** is the realistic plan (5 GB volume cap fits the typical profile); **Pro** for bigger volumes and the heavy profile.

## Verification checklist

- [ ] Build completes on Railway; the log shows `opencode --version: 1.19.3` and the versions table (OpenCode 1.19.3, Node v24.22.0, uv 0.13.1, gh 2.103.3, Caddy v2.11.7).
- [ ] Deploy logs: `first boot: preparing /data`, `starting OpenCode server on 127.0.0.1:4096`, `web UI: https://...`, no `not a mounted volume` warning, no restart-loop lines.
- [ ] `GET /healthz` → 200 `ok` without credentials (body is only `ok`); `GET /healthz?auth_token=x` → still `ok`.
- [ ] `GET /` and `GET /global/health` without credentials → 401 with `WWW-Authenticate: Basic`; with `opencode`/password → web UI / JSON `{"healthy":true,"version":"1.19.3"}`.
- [ ] Browser: login prompt, UI loads, a session with a free model (or a configured key) streams its answer live (SSE through Caddy and Railway's edge).
- [ ] Web UI terminal opens (PTY WebSocket with ticket), runs as `opencode` in `/data/...`; `echo $PORT` is empty; `sudo -n true` works (and fails with `AGENT_SUDO=false`).
- [ ] `GIT_REPO=https://github.com/{public repo}` → cloned into `/data/workspace/{repo}`; opens as a project; the agent edits a file and commits with the configured identity.
- [ ] `GH_TOKEN` set → `git push` to a private test repo works without prompts; `gh auth status` shows the token.
- [ ] Add a provider key in the web UI → `/data/.local/share/opencode/auth.json` exists; persists after redeploy, together with sessions, `~/workspace`, `npm i -g cowsay`.
- [ ] `railway ssh` → hint shown; `opencode-shell` gives a shell as `opencode`; `opencode-tui` attaches to the running server.
- [ ] From a laptop: `opencode attach https://{domain} -p {password}` lists the same sessions.
- [ ] From `railway ssh`: `pkill -f 'opencode serve'` → restarted by `supervise` within ~3 s (log line `opencode exited ... restarting in 3s`); `/healthz` returns 503 meanwhile (Caddy 502 → unhealthy), then `ok`.
- [ ] Clear `OPENCODE_SERVER_PASSWORD` and redeploy → container exits with the clear error, the deploy fails its healthcheck (no open agent).

## Open questions

- **Not built locally** (no Docker by instruction): the first Railway build is the first build of this Dockerfile. Package names, tags, digests, release assets and checksums were checked against the registries; scripts were syntax-checked and their logic tested with stubs (see the round 5 report).
- **Caddyfile not run through Caddy locally** (no Caddy binary here). Each directive was checked against Caddy v2.11.7 source and its own adapt tests; the entrypoint runs `caddy validate` and exits with a clear error if it fails.
- **Browser basic auth for XHR, SSE and the PTY ticket request**: browsers resend cached same-origin basic credentials; this is what OpenCode's docs and the gridalpha template rely on, but Safari behaviour and the PWA install flow are untested here. Fallback: OpenCode also accepts `?auth_token=` (base64 `user:password`).
- **Long-lived event streams through Railway's edge**: the client is expected to reconnect if the edge closes long streams; untested.
- **bun-pty in the compiled binary on Railway's runtime** (web terminal) is assumed to work as in upstream releases.
- **`--print-logs` volume**: OpenCode may still log at INFO to files under `~/.local/share/opencode/log`; harmless.
- **sudo on Railway**: works only if the runtime does not set `no_new_privs`; the entrypoint logs a warning in that case. Nothing else depends on sudo.
- **Railway SSH environment**: whether `railway ssh` sessions carry service variables is not verified; `opencode-shell`/`opencode-tui` load `/etc/opencode-railway/env.sh` so they work either way.
