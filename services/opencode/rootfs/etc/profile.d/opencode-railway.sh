# OpenCode on Railway: shell defaults (sourced by login shells and, through
# /etc/bash.bashrc, by interactive shells). OpenCode runs its bash tool and the
# web terminal as login shells of the "opencode" user, so keep this quiet.

if [ "$(id -u)" -ne 0 ]; then
  # Per-user installs live on the volume: `npm i -g` goes to ~/.npm-global,
  # uv/pipx tools to ~/.local/bin.
  export NPM_CONFIG_PREFIX="${HOME}/.npm-global"
  case ":${PATH}:" in
    *":${HOME}/.npm-global/bin:"*) ;;
    *) PATH="${HOME}/.npm-global/bin:${PATH}" ;;
  esac
  case ":${PATH}:" in
    *":${HOME}/.local/bin:"*) ;;
    *) PATH="${HOME}/.local/bin:${PATH}" ;;
  esac
  export PATH
  if [ -r /etc/opencode-railway/env.sh ]; then
    . /etc/opencode-railway/env.sh
  fi
else
  case "$-" in
    *i*)
      if [ -z "${OPENCODE_RAILWAY_HINT_SHOWN:-}" ]; then
        export OPENCODE_RAILWAY_HINT_SHOWN=1
        echo "OpenCode on Railway: you are root. Run 'opencode-shell' to work as the agent user"
        echo "(home /data, projects in /data/workspace) or 'opencode-tui' for the terminal UI."
      fi
      ;;
  esac
fi
