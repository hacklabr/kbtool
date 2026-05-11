_kbtool_clusters_dir="${HOME}/.config/kbtool/clusters"
_kbtool_cache_dir="${HOME}/.config/kbtool/cache"

_kbtool_commands=(cp bash logs mariadb mysql psql pgdump mariadb_dump mysql_dump cluster config use)
_kbtool_cluster_subcmds=(add rm update list)

_kbtool_get_slugs() {
    local slugs=""
    if [[ -d "$_kbtool_clusters_dir" ]]; then
        for f in "$_kbtool_clusters_dir"/*.yaml; do
            [[ -f "$f" ]] || continue
            slugs+=" $(basename "$f" .yaml)"
        done
    fi
    echo "$slugs"
}

_kbtool_get_active_slug() {
    local sess
    sess=$(tty 2>/dev/null | tr -c 'a-zA-Z0-9' '_') || return
    cat "/tmp/kbtool_active${sess}" 2>/dev/null
}

_kbtool_get_ns() {
    local slug
    slug=$(_kbtool_get_active_slug)
    if [[ -z "$slug" ]]; then
        return
    fi
    local cache="${_kbtool_cache_dir}/${slug}.ns"
    if [[ -f "$cache" ]]; then
        cat "$cache" | tr '\n' ' '
    else
        local kc="${_kbtool_clusters_dir}/${slug}.yaml"
        KUBECONFIG="$kc" kubectl get namespaces --request-timeout=5s \
            -o jsonpath='{.items[*].metadata.name}' 2>/dev/null
    fi
}

_kbtool_get_pods() {
    local ns="$1"
    local slug
    slug=$(_kbtool_get_active_slug)
    if [[ -n "$slug" ]] && [[ -f "${_kbtool_cache_dir}/${slug}.ns" ]]; then
        local kc="${_kbtool_clusters_dir}/${slug}.yaml"
        KUBECONFIG="$kc" kubectl get pods -n "$ns" --request-timeout=5s \
            -o jsonpath='{.items[*].metadata.name}' 2>/dev/null
    fi
}

_kbtool_match() {
    local query="$1"
    shift
    local w
    for w in "$@"; do
        [[ "$w" == *"$query"* ]] && echo "$w"
    done
}

# ─── Bash completion ─────────────────────────────────────────────────────────

_kbtool_bash() {
    local cur prev words cword

    if type _init_completion &>/dev/null; then
        _init_completion -n = || return
    else
        COMPREPLY=()
        cur="${COMP_WORDS[COMP_CWORD]}"
        cword=$COMP_CWORD
        words=("${COMP_WORDS[@]}")
    fi

    local command="" subcommand=""
    [[ ${#words[@]} -ge 2 ]] && command="${words[1]}"
    [[ ${#words[@]} -ge 3 ]] && subcommand="${words[2]}"

    case $cword in
        1)
            COMPREPLY=($(compgen -W "${_kbtool_commands[*]}" -- "$cur"))
            ;;
        2)
            case "$command" in
                cluster)
                    COMPREPLY=($(compgen -W "${_kbtool_cluster_subcmds[*]}" -- "$cur"))
                    ;;
                use)
                    COMPREPLY=($(compgen -W "$(_kbtool_get_slugs)" -- "$cur"))
                    ;;
                config)
                    COMPREPLY=()
                    ;;
                *)
                    COMPREPLY=($(_kbtool_match "$cur" $(_kbtool_get_ns)))
                    ;;
            esac
            ;;
        3)
            case "$command" in
                cluster)
                    case "$subcommand" in
                        rm|update)
                            COMPREPLY=($(compgen -W "$(_kbtool_get_slugs)" -- "$cur"))
                            ;;
                    esac
                    ;;
                cp)
                    local pods="$(_kbtool_get_pods "$subcommand")"
                    local pod_complete=()
                    local p
                    for p in $pods; do pod_complete+=("$p:"); done
                    _filedir 2>/dev/null || \
                        COMPREPLY+=($(compgen -f -- "$cur"))
                    COMPREPLY+=("${pod_complete[@]}")
                    ;;
                bash|logs|mariadb|mysql|psql|pgdump|mariadb_dump|mysql_dump)
                    COMPREPLY=($(_kbtool_match "$cur" $(_kbtool_get_pods "$subcommand")))
                    ;;
            esac
            ;;
        4)
            case "$command" in
                cp|pgdump|mariadb_dump|mysql_dump)
                    _filedir 2>/dev/null || \
                        COMPREPLY+=($(compgen -f -- "$cur"))
                    ;;
            esac
            ;;
    esac
}

# ─── Zsh native completion ───────────────────────────────────────────────────

_kbtool_zsh() {
    local cur cmd subcmd
    local -a candidates

    cur="${words[CURRENT]:-}"
    cmd="${words[2]:-}"
    subcmd="${words[3]:-}"

    case $CURRENT in
        2)
            compadd "${_kbtool_commands[@]}"
            ;;
        3)
            case "$cmd" in
                cluster)
                    compadd "${_kbtool_cluster_subcmds[@]}"
                    ;;
                use)
                    candidates=($(_kbtool_get_slugs))
                    ;;
                config)
                    ;;
                *)
                    candidates=($(_kbtool_match "$cur" $(_kbtool_get_ns)))
                    ;;
            esac
            [[ ${#candidates[@]} -gt 0 ]] && compadd "${candidates[@]}"
            ;;
        4)
            case "$cmd" in
                cluster)
                    case "$subcmd" in
                        rm|update)
                            candidates=($(_kbtool_get_slugs))
                            [[ ${#candidates[@]} -gt 0 ]] && compadd "${candidates[@]}"
                            ;;
                    esac
                    ;;
                cp)
                    candidates=($(_kbtool_get_pods "$subcmd"))
                    [[ ${#candidates[@]} -gt 0 ]] && compadd "${candidates[@]}"
                    _files
                    ;;
                bash|logs|mariadb|mysql|psql|pgdump|mariadb_dump|mysql_dump)
                    candidates=($(_kbtool_match "$cur" $(_kbtool_get_pods "$subcmd")))
                    [[ ${#candidates[@]} -gt 0 ]] && compadd "${candidates[@]}"
                    ;;
            esac
            ;;
        5)
            case "$cmd" in
                cp|pgdump|mariadb_dump|mysql_dump)
                    _files
                    ;;
            esac
            ;;
    esac
}

# ─── Registration ─────────────────────────────────────────────────────────────

if [[ -n "${ZSH_VERSION:-}" ]]; then
    _kbtool_zsh_complete() { _kbtool_zsh; }
    compdef _kbtool_zsh_complete kbtool
else
    complete -F _kbtool_bash kbtool
fi
