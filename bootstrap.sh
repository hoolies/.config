#!/usr/bin/env sh
# bootstrap — symlink files from /opt/.config into $HOME.

set -eu
export LC_ALL=C
unalias -a 2>/dev/null || true
unset -f cat dirname find ln mkdir mktemp printf rm 2>/dev/null || true

readonly PROGNAME="${0##*/}"
readonly SOURCE_ROOT=/opt/.config

usage() {
    cat <<EOF
Usage: $PROGNAME [OPTION]...
Create symbolic links from /opt/.config into the home directory.

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

require_source() {
    if [ ! -d "$SOURCE_ROOT" ]; then
        printf '%s: %s: No such file or directory\n' "$PROGNAME" "$SOURCE_ROOT" >&2
        exit 1
    fi
}

require_home() {
    if [ ! -d "$HOME" ]; then
        printf '%s: %s: Not a directory\n' "$PROGNAME" "$HOME" >&2
        exit 1
    fi
}

should_skip() {
    case "$rel" in
        .gitignore | README.md | bootstrap.sh)
            return 0
            ;;
    esac
    return 1
}

destination_for() {
    case "$rel" in
        .vimrc)
            dest="$HOME/.vimrc"
            ;;
        shell/.zshrc)
            dest="$HOME/.zshrc"
            ;;
        *)
            dest="$HOME/.config/$rel"
            ;;
    esac
}

overwrite_dest() {
    if [ -d "$dest" ] && [ ! -L "$dest" ]; then
        printf '%s: cannot overwrite directory %s\n' "$PROGNAME" "$dest" >&2
        exit 1
    fi
    rm -f -- "$dest"
}

link_file() {
    src=$1
    rel=${src#"$SOURCE_ROOT"/}
    if should_skip; then
        return 0
    fi
    destination_for
    mkdir -p -- "$(dirname -- "$dest")"
    overwrite_dest
    ln -s -- "$src" "$dest"
    printf '%s -> %s\n' "$dest" "$src"
}

list_files() {
    find "$SOURCE_ROOT" \( -name .git -o -name xfce4 \) -prune -o -type f -print
}

cleanup() {
    if [ -n "${tmp-}" ]; then
        rm -f -- "$tmp"
    fi
}

main() {
    parse_args "$@"
    require_source
    require_home
    tmp=$(mktemp)
    trap cleanup EXIT
    list_files >"$tmp"
    while IFS= read -r src || [ -n "$src" ]; do
        link_file "$src"
    done <"$tmp"
}

main "$@"
