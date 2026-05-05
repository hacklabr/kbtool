_kbtool_ns_cache=""
_kbtool_ns_cache_time=0
_kbtool_pod_cache=""
_kbtool_pod_cache_time=0
_kbtool_pod_cache_ns=""

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
    if [[ "$ns" != "$_kbtool_pod_cache_ns" ]] || (( now - _kbtool_pod_cache_time > 30 )); then
        _kbtool_pod_cache=$(kubectl get pods -n "$ns" -o jsonpath='{.items[*].metadata.name}' 2>/dev/null)
        _kbtool_pod_cache_time=$now
        _kbtool_pod_cache_ns="$ns"
    fi
    echo "$_kbtool_pod_cache"
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

    local command="" namespace=""
    [[ ${#words[@]} -ge 2 ]] && command="${words[1]}"
    [[ ${#words[@]} -ge 3 ]] && namespace="${words[2]}"

    case $cword in
        1)
            COMPREPLY=($(compgen -W \
                "cp bash mariadb mysql psql pgdump mariadb_dump mysql_dump" -- "$cur"))
            ;;
        2)
            COMPREPLY=($(compgen -W "$(_kbtool_get_ns)" -- "$cur"))
            ;;
        *)
            case "$command" in
                cp)
                    case $cword in
                        3)
                            local pods="$(_kbtool_get_pods "$namespace")"
                            local pod_complete=()
                            local p
                            for p in $pods; do pod_complete+=("$p:"); done
                            _filedir 2>/dev/null || \
                                COMPREPLY+=($(compgen -f -- "$cur"))
                            COMPREPLY+=("${pod_complete[@]}")
                            ;;
                        4)
                            _filedir 2>/dev/null || \
                                COMPREPLY=($(compgen -f -- "$cur"))
                            ;;
                    esac
                    ;;
                bash|mariadb|mysql|psql)
                    if [[ $cword -eq 3 ]]; then
                        COMPREPLY=($(compgen -W "$(_kbtool_get_pods "$namespace")" -- "$cur"))
                    fi
                    ;;
                pgdump|mariadb_dump|mysql_dump)
                    case $cword in
                        3)
                            COMPREPLY=($(compgen -W "$(_kbtool_get_pods "$namespace")" -- "$cur"))
                            ;;
                        4)
                            _filedir 2>/dev/null || \
                                COMPREPLY=($(compgen -f -- "$cur"))
                            ;;
                    esac
                    ;;
            esac
            ;;
    esac
}

complete -F _kbtool kbtool
