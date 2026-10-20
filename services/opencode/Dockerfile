# syntax=docker/dockerfile:1
#
# OpenCode v1 on Railway.
#   - OpenCode server with its built-in web UI (`opencode serve`), bound to
#     127.0.0.1 and protected by OpenCode's own basic auth
#     (OPENCODE_SERVER_PASSWORD)
#   - Caddy on $PORT: /healthz for Railway's probe (replayed as an
#     authenticated request to OpenCode's /global/health), everything else
#     proxied to OpenCode
#   - A toolchain for the agent: git, gh, Node.js LTS, Python 3, uv,
#     build-essential, ripgrep
# Persistent data (config, sessions, credentials, caches, projects) lives on a
# Railway volume mounted at /data, the home directory of the "opencode" user.
#
# Base image pinned by dated tag and digest (Docker Hub library/ubuntu, checked 2026-10-20).
FROM ubuntu:noble-20260930.1@sha256:68ee22004a9109b44973313b02ff7b1de250f1de0f5ecb628d73f579aaff33ac

# Pinned versions. Bump deliberately; checksums must match the new release.
# (PIN_ prefix keeps build args from colliding with the tools' own env variables.)
# OpenCode: GitHub release assets of anomalyco/opencode. amd64 uses the
# "baseline" build (no AVX2 requirement), as upstream's own container image does.
ARG PIN_OPENCODE=1.19.3
ARG PIN_OPENCODE_SHA256_AMD64=531cff2441129c30f0edd5878af494108ad07f5feb46d7ee29a2a5b830a5765d
ARG PIN_OPENCODE_SHA256_ARM64=7900818a6a98881edbbadab4b7525940eff3b9750040c200481f9f56cacee405
ARG PIN_OPENCODE_LICENSE_SHA256=625f0f619133f89bbbb2abe37369613dfa1885eba1e50d02170deb62bb42cb6b
ARG PIN_NODE=24.22.0
ARG PIN_NODE_SHA256_AMD64=cc2f601cee82d9a5a233302fe307abc600727035fd7d2c3a3571755989e95008
ARG PIN_NODE_SHA256_ARM64=fef00bb4d36e1c50104a9775a10359beee98f162b4104dd12472c75065c6a143
ARG PIN_UV=0.13.1
ARG PIN_GH=2.102.0
ARG PIN_CADDY=2.11.7
ARG PIN_CADDY_SHA512_AMD64=a7a433a1b133efc3c8d10eb0b99d52a24b5ef5c322dc77f5282182b1c0402139ab83f3a99f0c52409df77d20123fb0b523edad8a66d8f5e49136197bf61ef0e7
ARG PIN_CADDY_SHA512_ARM64=3db36ba90c7a6e8dda40ee3dd71fa08844c76b5fb08f61b31e5e78d2ed38e71c51dc7baed875e50d1ca1279196e84302967237386ae87c91ae9f2aaceada682e

ENV DEBIAN_FRONTEND=noninteractive \
    LANG=C.UTF-8 \
    LC_ALL=C.UTF-8

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# Base system and the agent's toolchain from the Ubuntu archive.
RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      ca-certificates curl wget gnupg sudo tini tzdata \
      git git-lfs openssh-client tmux \
      build-essential pkg-config \
      python3 python3-dev python3-pip python3-venv python-is-python3 \
      jq ripgrep fd-find unzip zip xz-utils bzip2 zstd less tree file rsync \
      htop procps psmisc lsof iproute2 iputils-ping dnsutils netcat-openbsd \
      nano vim bash-completion sqlite3 \
 && ln -sf /usr/bin/fdfind /usr/local/bin/fd \
 && rm -rf /var/lib/apt/lists/*

# Non-root user "opencode" (UID/GID 1000). Its home is /data, the volume mount
# point. Passwordless sudo lets the agent install system packages; set
# AGENT_SUDO=false to remove it at start. The stock "ubuntu" user (UID 1000)
# is removed first.
RUN userdel -r ubuntu 2>/dev/null || true \
 && groupadd --gid 1000 opencode \
 && useradd --uid 1000 --gid 1000 --home-dir /data --no-create-home --shell /bin/bash opencode \
 && printf 'opencode ALL=(ALL:ALL) NOPASSWD:ALL\n' > /etc/sudoers.d/90-opencode \
 && chmod 0440 /etc/sudoers.d/90-opencode \
 && visudo -cf /etc/sudoers.d/90-opencode \
 && install -d -m 0750 -o opencode -g opencode /data

# Node.js LTS from the official nodejs.org tarball, checksum-verified
# (npm/npx for JavaScript projects and MCP servers).
RUN case "$(dpkg --print-architecture)" in \
      amd64) node_arch=x64;   node_sha="${PIN_NODE_SHA256_AMD64}" ;; \
      arm64) node_arch=arm64; node_sha="${PIN_NODE_SHA256_ARM64}" ;; \
      *) echo "unsupported architecture: $(dpkg --print-architecture)" >&2; exit 1 ;; \
    esac \
 && curl -fsSLo /tmp/node.tar.xz "https://nodejs.org/dist/v${PIN_NODE}/node-v${PIN_NODE}-linux-${node_arch}.tar.xz" \
 && echo "${node_sha}  /tmp/node.tar.xz" | sha256sum -c - \
 && tar -xJf /tmp/node.tar.xz -C /usr/local --strip-components=1 --no-same-owner \
 && rm -f /tmp/node.tar.xz /usr/local/CHANGELOG.md /usr/local/README.md \
 && install -d /usr/local/share/doc/nodejs \
 && mv /usr/local/LICENSE /usr/local/share/doc/nodejs/LICENSE \
 && corepack enable \
 && node --version && npm --version

# GitHub CLI from GitHub's signed apt repository.
RUN install -d -m 0755 /etc/apt/keyrings \
 && curl -fsSLo /etc/apt/keyrings/githubcli-archive-keyring.gpg https://cli.github.com/packages/githubcli-archive-keyring.gpg \
 && chmod 0644 /etc/apt/keyrings/githubcli-archive-keyring.gpg \
 && echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
      > /etc/apt/sources.list.d/github-cli.list \
 && apt-get update \
 && apt-get install -y --no-install-recommends "gh=${PIN_GH}" \
 && rm -rf /var/lib/apt/lists/* \
 && gh --version

# Caddy (HTTP front on $PORT): release tarball, checksum-verified.
RUN case "$(dpkg --print-architecture)" in \
      amd64) caddy_arch=amd64; caddy_sha="${PIN_CADDY_SHA512_AMD64}" ;; \
      arm64) caddy_arch=arm64; caddy_sha="${PIN_CADDY_SHA512_ARM64}" ;; \
      *) echo "unsupported architecture: $(dpkg --print-architecture)" >&2; exit 1 ;; \
    esac \
 && curl -fsSLo /tmp/caddy.tar.gz "https://github.com/caddyserver/caddy/releases/download/v${PIN_CADDY}/caddy_${PIN_CADDY}_linux_${caddy_arch}.tar.gz" \
 && echo "${caddy_sha}  /tmp/caddy.tar.gz" | sha512sum -c - \
 && install -d /usr/local/share/doc/caddy \
 && tar -xzf /tmp/caddy.tar.gz -C /usr/local/bin --no-same-owner caddy \
 && tar -xzf /tmp/caddy.tar.gz -C /usr/local/share/doc/caddy --no-same-owner LICENSE \
 && rm -f /tmp/caddy.tar.gz \
 && caddy version

# uv (Python projects and tools) via Astral's official installer, pinned.
RUN curl -fsSL "https://astral.sh/uv/${PIN_UV}/install.sh" \
      | env UV_INSTALL_DIR=/usr/local/bin UV_NO_MODIFY_PATH=1 sh \
 && uv --version

# OpenCode: the official release binary (embeds the matching web UI),
# checksum-verified, plus its MIT license.
RUN case "$(dpkg --print-architecture)" in \
      amd64) oc_asset=opencode-linux-x64-baseline; oc_sha="${PIN_OPENCODE_SHA256_AMD64}" ;; \
      arm64) oc_asset=opencode-linux-arm64;        oc_sha="${PIN_OPENCODE_SHA256_ARM64}" ;; \
      *) echo "unsupported architecture: $(dpkg --print-architecture)" >&2; exit 1 ;; \
    esac \
 && curl -fsSLo /tmp/opencode.tar.gz "https://github.com/anomalyco/opencode/releases/download/v${PIN_OPENCODE}/${oc_asset}.tar.gz" \
 && echo "${oc_sha}  /tmp/opencode.tar.gz" | sha256sum -c - \
 && tar -xzf /tmp/opencode.tar.gz -C /usr/local/bin --no-same-owner opencode \
 && chmod 0755 /usr/local/bin/opencode \
 && rm -f /tmp/opencode.tar.gz \
 && install -d /usr/local/share/doc/opencode \
 && curl -fsSLo /usr/local/share/doc/opencode/LICENSE "https://raw.githubusercontent.com/anomalyco/opencode/v${PIN_OPENCODE}/LICENSE" \
 && echo "${PIN_OPENCODE_LICENSE_SHA256}  /usr/local/share/doc/opencode/LICENSE" | sha256sum -c - \
 && oc_version="$(env HOME=/tmp/oc-build XDG_CONFIG_HOME=/tmp/oc-build/config XDG_DATA_HOME=/tmp/oc-build/data \
      XDG_CACHE_HOME=/tmp/oc-build/cache XDG_STATE_HOME=/tmp/oc-build/state OPENCODE_DISABLE_AUTOUPDATE=1 \
      /usr/local/bin/opencode --version)" \
 && rm -rf /tmp/oc-build /tmp/opencode \
 && echo "opencode --version: ${oc_version}" \
 && printf '%s\n' "${oc_version}" | grep -qxF "${PIN_OPENCODE}"

# Template wiring: entrypoint, helpers, Caddyfile renderer, shell profile.
COPY rootfs/ /
RUN chmod 0755 /usr/local/bin/opencode-entrypoint /usr/local/bin/opencode-shell /usr/local/bin/opencode-tui \
      /usr/local/lib/opencode-railway/* \
 && chmod 0644 /etc/profile.d/opencode-railway.sh \
 && echo '[ -r /etc/profile.d/opencode-railway.sh ] && . /etc/profile.d/opencode-railway.sh' >> /etc/bash.bashrc \
 && install -d -m 0755 /etc/opencode-railway \
 && /usr/local/lib/opencode-railway/collect-versions > /etc/opencode-railway/versions.txt \
 && cat /etc/opencode-railway/versions.txt

ENV PORT=8080
EXPOSE 8080

# Railway runs its own init as PID 1, so tini runs as a subreaper (-s) that
# reaps orphaned processes (shells, LSP and MCP servers the agent starts) and
# forwards signals to the whole process group (-g). The entrypoint starts
# OpenCode under a restart loop and then execs Caddy, the healthchecked
# process on $PORT.
ENTRYPOINT ["/usr/bin/tini", "-s", "-g", "--", "/usr/local/bin/opencode-entrypoint"]
CMD []
