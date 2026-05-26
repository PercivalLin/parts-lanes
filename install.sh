#!/bin/sh
set -eu

REPO="${PARTS_LANES_REPO:-PercivalLin/parts-lanes}"
BRANCH="${PARTS_LANES_BRANCH:-main}"
SCRIPT_PATH=".agents/skills/parts-lanes/scripts/parts-lane"
TARGET="."
TARGET_SET=0
FORCE=0
DRY_RUN=0

usage() {
    cat <<EOF
Usage: install.sh [options] [target-directory]

When no target directory is provided, the installer uses the nearest Git
repository root. If the current directory is not in a Git repository, it uses
the current directory.

Options:
  --branch <name>  Install from a different branch (default: main)
  --force          Overwrite existing managed files
  --dry-run        Show what init would change without writing files
  -h, --help       Show this help
EOF
}

while [ "$#" -gt 0 ]; do
    case "$1" in
        --branch)
            [ "$#" -ge 2 ] || { echo "Error: --branch requires a value." >&2; exit 1; }
            BRANCH="$2"
            shift 2
            ;;
        --force)
            FORCE=1
            shift
            ;;
        --dry-run)
            DRY_RUN=1
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        -*)
            echo "Error: unknown option: $1" >&2
            usage >&2
            exit 1
            ;;
        *)
            TARGET="$1"
            TARGET_SET=1
            shift
            ;;
    esac
done

if [ "$TARGET_SET" -eq 0 ] && command -v git >/dev/null 2>&1; then
    GIT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || true)
    if [ -n "$GIT_ROOT" ]; then
        TARGET="$GIT_ROOT"
    fi
fi

RAW_URL="${PARTS_LANES_RAW_URL:-https://raw.githubusercontent.com/${REPO}/${BRANCH}/${SCRIPT_PATH}}"

echo "Parts Lanes installer"
echo "====================="
echo ""

if ! command -v python3 >/dev/null 2>&1; then
    echo "Error: python3 is required." >&2
    exit 1
fi

if [ -e "$TARGET" ] && [ ! -d "$TARGET" ]; then
    echo "Error: $TARGET exists but is not a directory." >&2
    exit 1
fi

if [ "$DRY_RUN" -eq 0 ]; then
    mkdir -p "$TARGET"
fi

if [ ! -d "$TARGET" ]; then
    echo "Error: $TARGET is not a directory." >&2
    exit 1
fi

TARGET=$(cd "$TARGET" && pwd)

download() {
    dest="$1"
    if command -v curl >/dev/null 2>&1; then
        curl -fsSL "$RAW_URL" -o "$dest"
    elif command -v wget >/dev/null 2>&1; then
        wget -q "$RAW_URL" -O "$dest"
    else
        echo "Error: curl or wget is required." >&2
        exit 1
    fi
}

INIT_ARGS=""
[ "$FORCE" -eq 1 ] && INIT_ARGS="$INIT_ARGS --force"
[ "$DRY_RUN" -eq 1 ] && INIT_ARGS="$INIT_ARGS --dry-run"

if [ "$DRY_RUN" -eq 1 ]; then
    TMP_SCRIPT=$(mktemp)
    trap 'rm -f "$TMP_SCRIPT"' EXIT
    echo "Downloading parts-lane for dry run ..."
    download "$TMP_SCRIPT"
    chmod +x "$TMP_SCRIPT"
    echo "Planning Parts Lanes init in $TARGET ..."
    (cd "$TARGET" && python3 "$TMP_SCRIPT" init $INIT_ARGS)
    echo ""
    echo "Dry run complete."
    exit 0
fi

mkdir -p "$TARGET/.agents/skills/parts-lanes/scripts"

echo "Downloading parts-lane ..."
download "$TARGET/$SCRIPT_PATH"
chmod +x "$TARGET/$SCRIPT_PATH"

echo "Initializing Parts Lanes in $TARGET ..."
(cd "$TARGET" && python3 "$SCRIPT_PATH" init $INIT_ARGS)

echo ""
echo "Done. Parts Lanes is ready."
echo ""
echo "Next:"
echo "  cd $TARGET"
echo "  ./parts-lane doctor"
echo "  ./parts-lane begin --worktree"
