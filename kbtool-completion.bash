_kbtool_ns_cache=""
_kbtool_ns_cache_time=0
_kbtool_pod_cache=""
_kbtool_pod_cache_time=0
_kbtool_pod_cache_ns=""

_kbtool_clusters_dir="${HOME}/.config/kbtool/clusters"

_kbtool_get_ns() {
    local now
    now=$(date +%s)
    if (( now - _kbtool_ns_cache_time > 60 )); then
        _kbtool_ns_cache=$(kubectl get namespaces -o jsonpath='{.items[*].metadata.name}' 2>/dev/null)
        _kbtool_ns_cache_time=$now
    fi
    echo "$_kbtool_ns_cache"
}

_kbtool_get_pods() {
    local ns="$1" now
    now=$(date +%s)
    if [[ "$ns" != "_kbtool_pod_cache_ns" ]] || (( now - _kbtool_pod_cache_time > 30 )); then
        _kbtool_pod_cache=$(kubectl get pods -n "$ns" -o jsonpath='{.items[*].metadata.name}' 2>/dev/null)
        _kbtool_pod_cache_time=$now
        _kbtool_pod_cache_ns="$ns"
    fi
    echo "$_kbtool_pod_cache"
}

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

_kbtool() {
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
            COMPREPLY=($(compgen -W \
                "cp bash mariadb mysql psql pgdump mariadb_dump mysql_dump cluster use" -- "$cur"))
            ;;
        2)
            case "$command" in
                cluster)
                    COMPREPLY=($(compgen -W "add rm update list" -- "$cur"))
                    ;;
                use)
                    COMPREPLY=($(compgen -W "$(_kbtool_get_slugs)" -- "$cur"))
                    ;;
                *)
                    COMPREPLY=($(compgen -W "$(_kbtool_get_ns)" -- "$cur"))
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
                bash|mariadb|mysql|psql)
                    COMPREPLY=($(compgen -W "$(_kbtool_get_pods "$subcommand")" -- "$cur"))
                    ;;
                pgdump|mariadb_dump|mysql_dump)
                    COMPREPLY=($(compgen -W "$(_kbtool_get_pods "$subcommand")" -- "$cur"))
                    ;;
            esac
            ;;
        4)
            case "$command" in
                cp)
                    _filedir 2>/dev/null || \
                        COMPREPLY=($(compgen -f -- "$cur"))
                    ;;
                pgdump|mariadb_dump|mysql_dump)
                    _filedir 2>/dev/null || \
                        COMPREPLY=($(compgen -f -- "$cur"))
                    ;;
            esac
            ;;
    esac
}

complete -F _kbtool kbtool
