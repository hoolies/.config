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

overwrite_dest() {
    if [ -d "$dest" ] && [ ! -L "$dest" ]; then
        printf '%s: cannot overwrite directory %s\n' "$PROGNAME" "$dest" >&2
        exit 1
    fi
    rm -f -- "$dest"
}

link_file() {
    src=$1
    dest=$2
    if [ ! -f "$src" ]; then
        printf '%s: %s: No such file or directory\n' "$PROGNAME" "$src" >&2
        exit 1
    fi
    mkdir -p -- "$(dirname -- "$dest")"
    overwrite_dest
    ln -s -- "$src" "$dest"
    printf '%s -> %s\n' "$dest" "$src"
}

link_tree() {
    srcdir=$1
    destdir=$2
    if [ ! -d "$srcdir" ]; then
        printf '%s: %s: No such file or directory\n' "$PROGNAME" "$srcdir" >&2
        exit 1
    fi
    mkdir -p -- "$destdir"
    find "$srcdir" -type f -print >"$tmp"
    while IFS= read -r src || [ -n "$src" ]; do
        rel=${src#"$srcdir"/}
        link_file "$src" "$destdir/$rel"
    done <"$tmp"
}

cleanup() {
    if [ -n "${tmp-}" ]; then
        rm -f -- "$tmp"
    fi
}

link_all() {
    link_file "$SOURCE_ROOT/.vimrc" "$HOME/.vimrc"
    link_file "$SOURCE_ROOT/shell/.zshrc" "$HOME/.zshrc"
    link_file "$SOURCE_ROOT/conky/conky.config" "$HOME/.config/conky/conky.config"
    link_file "$SOURCE_ROOT/tmux/tmux.conf" "$HOME/.config/tmux/tmux.conf"
    link_tree "$SOURCE_ROOT/alacritty" "$HOME/.config/alacritty"
    link_tree "$SOURCE_ROOT/espanso" "$HOME/.config/espanso"
    link_tree "$SOURCE_ROOT/helix" "$HOME/.config/helix"
    link_tree "$SOURCE_ROOT/yazi" "$HOME/.config/yazi"
}

main() {
    parse_args "$@"
    require_source
    require_home
    tmp=$(mktemp)
    trap cleanup EXIT
    link_all
}

main "$@"
