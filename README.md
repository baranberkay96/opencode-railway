# Deploy and Host OpenCode with Railway

[![Deploy on Railway](https://railway.com/button.svg)](https://railway.com/deploy/opencode-v1-ai-coding-agent-in-the-brows?referralCode=20H68q)

OpenCode is an open-source AI coding agent that plans, edits files and runs commands in your projects. This template runs OpenCode 1.19.3 as an always-on server with its browser UI, password login, git and the GitHub CLI, and keeps your projects, sessions and provider logins on a persistent volume.

## About Hosting OpenCode

On a laptop, OpenCode stops when the lid closes. Hosting it on a server keeps sessions running and reachable from any browser, including a phone. This community template runs `opencode serve` from the official 1.19.3 release binary, which ships the matching web UI. OpenCode's own HTTP basic auth protects the server, with a password generated at deploy; the container refuses to start without one. A small Caddy front answers Railway's healthcheck with an authenticated probe and passes the event streams and terminal sessions through unbuffered. The agent runs as a non-root user whose home, `/data`, is the volume, so config, `auth.json`, sessions and `~/workspace` survive redeploys.

## Common Use Cases

- Hand a refactor, migration or bug hunt to the agent and check progress from any browser
- Review diffs and approve the agent's commands from your phone while away from your desk
- A shared, always-reachable coding sandbox next to the services and databases in your Railway project
- Try many models with one setup: Anthropic, OpenAI, Google, OpenRouter, OpenCode's free models and more

## Dependencies for OpenCode Hosting

- A Railway volume mounted at `/data` (included)
- A public Railway domain on port 8080 (included)
- Optional: an API key or login for at least one model provider. OpenCode's free models, when offered, work without a key; the free lineup is set by OpenCode and changes over time
- Optional: a GitHub token (`GH_TOKEN`) for private repositories and pull requests

### Deployment Dependencies

- OpenCode source and releases: https://github.com/anomalyco/opencode
- OpenCode server and authentication: https://opencode.ai/docs/server/
- OpenCode web interface: https://opencode.ai/docs/web/
- OpenCode providers and `opencode auth login`: https://opencode.ai/docs/providers/
- OpenCode configuration: https://opencode.ai/docs/config/
- GitHub personal access tokens: https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/managing-your-personal-access-tokens
- Railway volumes: https://docs.railway.com/volumes
- Railway Fair Use Policy: https://railway.com/legal/fair-use

### Implementation Details

| Service | Source | Purpose |
|---|---|---|
| OpenCode | Dockerfile on `ubuntu:noble-20260930.1` (digest-pinned) with the OpenCode 1.19.3 release binary (SHA-256 checked) | `opencode serve` on 127.0.0.1:4096 with OpenCode's basic auth; Caddy on `PORT` 8080 for the public domain and `/healthz`; git, gh, Node.js 24, Python 3, uv and build tools for the agent; volume at `/data` |

**First login**

1. After the deploy, open the service's **Variables** tab and copy `OPENCODE_SERVER_PASSWORD`.
2. Open the public URL. Your browser asks for a login: user `opencode` (or your `OPENCODE_SERVER_USERNAME`) and that password.
3. Connect a model: use the provider settings in the web UI, set a key variable such as `ANTHROPIC_API_KEY` or `OPENROUTER_API_KEY` and redeploy, or pick one of OpenCode's free models. ChatGPT Plus/Pro and GitHub Copilot use device logins that work on a remote server.
4. Open a project folder under `/data/workspace` and start a session.

**Clone a repository and work on it**

- Easiest: set `GIT_REPO` (for example `https://github.com/{owner}/{repo}.git`) and redeploy. It is cloned once into `/data/workspace/{repo}` in the background; then open that folder as a project in the web UI.
- From the web UI terminal: `cd ~/workspace && git clone https://github.com/{owner}/{repo}.git`.
- Or ask the agent: "Clone https://github.com/{owner}/{repo} into ~/workspace and run its tests."
- Private repositories: set `GH_TOKEN` (a fine-grained token with access to the repository) so `git` and `gh` authenticate over HTTPS, or run `gh auth login` in the terminal; gh stores its login in `/data/.config/gh`. SSH also works: create a key with `ssh-keygen -t ed25519` (it stays in `/data/.ssh`) and add the public key to GitHub as a deploy key. Use `GH_TOKEN`, not `GITHUB_TOKEN`: OpenCode reads `GITHUB_TOKEN` as a GitHub Copilot credential.
- Set `GIT_USER_NAME` and `GIT_USER_EMAIL` so the agent's commits carry your identity.

**Persist provider credentials**

Everything OpenCode stores lives on the volume: logins and API keys added in the web UI or with `opencode auth login` go to `/data/.local/share/opencode/auth.json`, global config and plugins to `/data/.config/opencode/`, sessions and logs to `/data/.local/share/opencode/`. They survive redeploys and restarts. Keys set as Railway variables are read at every start and can be rotated in the Variables tab. To remove a stored login, use the web UI or `opencode auth logout`.

**Terminal access**: the web UI has a built-in terminal. With the Railway CLI, `railway ssh` opens a root shell in the container; run `opencode-shell` to work as the agent's user, or `opencode-tui` to attach OpenCode's terminal UI to the same server and sessions. From your own machine with OpenCode installed: `opencode attach https://{your-domain} -p {password}`.

**What persists**: all of `/data` (projects, OpenCode data, `~/.gitconfig`, `~/.ssh`, gh login, `npm i -g` installs in `~/.npm-global`, uv tools in `~/.local/bin`). Packages installed with `sudo apt` reset on redeploy. A redeploy or restart stops a running agent turn; the session history stays.

**Security**: every path except `/healthz` and three static manifest files requires the login. The agent can run shell commands and spend your model credits, so keep the password private and rotate it by changing `OPENCODE_SERVER_PASSWORD`. Its user has passwordless sudo inside the container for installing tools; set `AGENT_SUDO=false` to remove it. Review OpenCode's permission settings before giving the agent production credentials.

**Scaling**: keep one replica (the volume belongs to one instance). Raise RAM and CPU in the service settings for large repositories, language servers or parallel sessions. For a team, deploy one instance per person or project.

**Pinning and upgrades**: OpenCode, Node.js, uv, gh and Caddy versions and checksums are build arguments at the top of `services/opencode/Dockerfile`. The server always runs the image's OpenCode; update checks are off (`OPENCODE_DISABLE_AUTOUPDATE=true`). To upgrade within OpenCode 1.x, change `PIN_OPENCODE` and its SHA-256 values (from the GitHub release assets) and redeploy. OpenCode 2 is a separate major release and is not part of this template.

**Fair use**: this is your own coding agent. Do not use it for cryptocurrency mining, proxies or VPNs, or sharing access with others; Railway's Fair Use Policy applies.

### Why Deploy OpenCode on Railway?

Railway gives OpenCode an HTTPS URL, a persistent volume and automatic restarts with no server to manage, so the agent keeps working while you are away. You pay for the CPU and memory the service uses, and model usage is billed by the provider you connect.
