#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN_DIR="/usr/local/bin"
TARGET="$SCRIPT_DIR/kbtool"
COMPLETION="$SCRIPT_DIR/kbtool-completion.bash"

RED=$'\033[0;31m'
GREEN=$'\033[0;32m'
CYAN=$'\033[0;36m'
NC=$'\033[0m'

log_ok()   { echo -e "${GREEN}✓${NC} $*"; }
log_info() { echo -e "${CYAN}→${NC} $*"; }
log_err()  { echo -e "${RED}✗${NC} $*" >&2; }

if [[ ! -f "$TARGET" ]]; then
    log_err "kbtool not found at ${TARGET}"
    exit 1
fi

if [[ ! -f "$COMPLETION" ]]; then
    log_err "Completion file not found at ${COMPLETION}"
    exit 1
fi

if [[ ! -w "$BIN_DIR" ]] && [[ $EUID -ne 0 ]]; then
    log_err "No write access to ${BIN_DIR}. Run with sudo."
    exit 1
fi

ln -sfn "$TARGET" "${BIN_DIR}/kbtool"
log_ok "Linked ${TARGET} → ${BIN_DIR}/kbtool"

detect_shell() {
    basename "${SHELL:-}"
}

add_to_rc() {
    local rc_file="$1" line="$2"
    if grep -qF "$line" "$rc_file" 2>/dev/null; then
        log_ok "Already configured in ${rc_file}"
    else
        echo "" >> "$rc_file"
        echo "# kbtool completion" >> "$rc_file"
        echo "$line" >> "$rc_file"
        log_ok "Added to ${rc_file}"
    fi
}

current_shell=$(detect_shell)
case "$current_shell" in
    zsh)
        add_to_rc "${HOME}/.zshrc" "_kb_tty=\$(tty 2>/dev/null) && [[ \"\$_kb_tty\" == /dev/* ]] && rm -f \"/tmp/kbtool_active\$(echo \"\$_kb_tty\" | tr -c 'a-zA-Z0-9' '_')\""
        add_to_rc "${HOME}/.zshrc" "autoload -Uz compinit && compinit -u"
        add_to_rc "${HOME}/.zshrc" "source ${COMPLETION}"
        ;;
    bash)
        add_to_rc "${HOME}/.bashrc" "_kb_tty=\$(tty 2>/dev/null) && [[ \"\$_kb_tty\" == /dev/* ]] && rm -f \"/tmp/kbtool_active\$(echo \"\$_kb_tty\" | tr -c 'a-zA-Z0-9' '_')\""
        add_to_rc "${HOME}/.bashrc" "source ${COMPLETION}"
        ;;
    *)
        log_info "Shell '${current_shell}' not supported for autocomplete. Adding bash config."
        add_to_rc "${HOME}/.bashrc" "_kb_tty=\$(tty 2>/dev/null) && [[ \"\$_kb_tty\" == /dev/* ]] && rm -f \"/tmp/kbtool_active\$(echo \"\$_kb_tty\" | tr -c 'a-zA-Z0-9' '_')\""
        add_to_rc "${HOME}/.bashrc" "source ${COMPLETION}"
        ;;
esac

echo ""
log_ok "Done. Restart your shell or run: source ~/.${current_shell}rc"
