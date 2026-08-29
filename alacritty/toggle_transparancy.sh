#!/usr/bin/env sh
# toggle_transparancy — toggle Alacritty window opacity.

set -eu
export LC_ALL=C
unalias -a 2>/dev/null || true
unset -f sed mv mktemp rm 2>/dev/null || true

readonly PROGNAME="${0##*/}"
readonly CONFIG="${HOME}/.config/alacritty/alacritty.toml"
readonly OPAQUE=1
readonly TRANSLUCENT=0.67

usage() {
    cat <<EOF
Usage: $PROGNAME [OPTION]...
Toggle Alacritty window opacity between $OPAQUE and $TRANSLUCENT.

Mandatory arguments to long options are mandatory for short options too.

  -h, --help            display this help and exit
EOF
}

unrecognized_option() {
    printf '%s: unrecognized option %s\n' "$PROGNAME" "$1" >&2
    printf "Try '%s --help' for more information.\n" "$PROGNAME" >&2
}

extra_operand() {
    printf '%s: extra operand %s\n' "$PROGNAME" "$1" >&2
    printf "Try '%s --help' for more information.\n" "$PROGNAME" >&2
}

parse_args() {
    while [ "$#" -gt 0 ]; do
        case "$1" in
            -h | --help)
                usage
                exit 0
                ;;
            --)
                shift
                break
                ;;
            -*)
                unrecognized_option "$1"
                exit 2
                ;;
            *)
                extra_operand "$1"
                exit 2
                ;;
        esac
    done
    if [ "$#" -gt 0 ]; then
        extra_operand "$1"
        exit 2
    fi
}

require_config() {
    if [ ! -f "$CONFIG" ]; then
        printf '%s: %s: No such file or directory\n' "$PROGNAME" "$CONFIG" >&2
        exit 1
    fi
}

read_opacity() {
    opacity=""
    while IFS= read -r line || [ -n "$line" ]; do
        case "$line" in
            'opacity = '*)
                opacity=${line#opacity = }
                break
                ;;
        esac
    done <"$CONFIG"
    if [ -z "$opacity" ]; then
        printf '%s: no opacity line in %s\n' "$PROGNAME" "$CONFIG" >&2
        exit 1
    fi
}

choose_toggle() {
    case "$opacity" in
        "$OPAQUE")
            toggle_opacity=$TRANSLUCENT
            ;;
        *)
            toggle_opacity=$OPAQUE
            ;;
    esac
}

write_opacity() {
    tmp=$(mktemp)
    trap 'rm -f -- "$tmp"' EXIT
    sed "s/^opacity = ${opacity}$/opacity = ${toggle_opacity}/" -- "$CONFIG" >"$tmp"
    if [ ! -s "$tmp" ]; then
        printf '%s: failed to rewrite %s\n' "$PROGNAME" "$CONFIG" >&2
        exit 1
    fi
    mv -- "$tmp" "$CONFIG"
    trap - EXIT
}

main() {
    parse_args "$@"
    require_config
    read_opacity
    choose_toggle
    write_opacity
}

main "$@"
