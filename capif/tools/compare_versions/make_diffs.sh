#!/bin/sh
set -eu

usage() {
  cat <<EOF
Usage:
  $(basename "$0") --old <old_dir> --new <new_dir> [--out <diffs_dir>] [--service <name>]

Options:
  --old       Path to the folder with the old version (e.g., old-version)
  --new       Path to the folder with the new version (e.g., new-version)
  --out       (Optional) Output folder for diffs. Default: ./diffs
  --service   (Optional) Single top-level service (file or directory name) to compare
  -h, --help  Show this help

Output:
  - <service>.diff       unified diff (-ruN) for the service
  - <service>.diffstat   summary (diffstat or git --no-index --stat fallback)
  - summary.txt          run summary
EOF
}

OLD=""
NEW=""
OUT="diffs"
ONLY_SERVICE=""

# Parse args
while [ $# -gt 0 ]; do
  case "$1" in
    --old) OLD=${2:-}; shift 2 ;;
    --new) NEW=${2:-}; shift 2 ;;
    --out) OUT=${2:-}; shift 2 ;;
    --service) ONLY_SERVICE=${2:-}; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage; exit 1 ;;
  esac
done

[ -n "$OLD" ] || { echo "Error: --old is required." >&2; usage; exit 1; }
[ -n "$NEW" ] || { echo "Error: --new is required." >&2; usage; exit 1; }

[ -d "$OLD" ] || { echo "Error: '$OLD' is not a directory." >&2; exit 1; }
[ -d "$NEW" ] || { echo "Error: '$NEW' is not a directory." >&2; exit 1; }

mkdir -p "$OUT"

SUMMARY_FILE="$OUT/summary.txt"
: > "$SUMMARY_FILE"   # overwrite each run

have_diffstat=0
command -v diffstat >/dev/null 2>&1 && have_diffstat=1

have_git=0
command -v git >/dev/null 2>&1 && have_git=1

# Build service list
if [ -n "$ONLY_SERVICE" ]; then
  # Validate existence in at least one side
  if [ ! -e "$OLD/$ONLY_SERVICE" ] && [ ! -e "$NEW/$ONLY_SERVICE" ]; then
    echo "Error: service '$ONLY_SERVICE' not found in either '$OLD' or '$NEW'." >&2
    exit 1
  fi
  SERVICES_LIST=$ONLY_SERVICE
else
  tmp="$(mktemp)"
  for p in "$OLD"/* "$NEW"/*; do
    [ -e "$p" ] || continue
    base=$(basename "$p")
    printf '%s\n' "$base" >> "$tmp"
  done
  SERVICES_LIST=$(sort -u "$tmp")
  rm -f "$tmp"

  # If nothing found, exit gracefully
  if [ -z "$SERVICES_LIST" ]; then
    echo "No services found in '$OLD' or '$NEW'. Nothing to diff."
    exit 0
  fi
fi

echo "Generating diffs into '$OUT'..."
echo "$SERVICES_LIST" | while IFS= read -r svc; do
  [ -n "$svc" ] || continue

  left="$OLD/$svc"
  right="$NEW/$svc"
  out_diff="$OUT/${svc}.diff"
  out_stat="$OUT/${svc}.diffstat"

  # Clean previous files to ensure overwrite
  rm -f "$out_diff" "$out_stat"

  if [ ! -e "$left" ] && [ ! -e "$right" ]; then
    echo "WARN: '$svc' missing in both sides; skipping." | tee -a "$SUMMARY_FILE"
    continue
  fi

  # 0=no changes, 1=diffs, >1=error
  if diff -ruN "$left" "$right" >"$out_diff" 2>&1; then
    echo "Service '$svc': no differences." | tee -a "$SUMMARY_FILE"
    echo "No differences" >"$out_stat"
  else
    code=$?
    if [ $code -eq 1 ]; then
      echo "Service '$svc': differences found -> $(basename "$out_diff")" | tee -a "$SUMMARY_FILE"
      if [ $have_diffstat -eq 1 ]; then
        if ! diffstat "$out_diff" >"$out_stat" 2>/dev/null; then
          echo "Failed to generate diffstat from diff file." >"$out_stat"
        fi
      elif [ $have_git -eq 1 ] && [ -e "$left" ] && [ -e "$right" ]; then
        if ! git -c color.ui=never diff --no-index --stat -- "$left" "$right" >"$out_stat" 2>/dev/null; then
          echo "Failed to generate stat with git --no-index." >"$out_stat"
        fi
      else
        {
          echo "diffstat and git not available."
          echo "Install 'diffstat' for per-file summaries, e.g.:"
          echo "  - Debian/Ubuntu: sudo apt-get install diffstat"
          echo "  - macOS (brew):  brew install diffstat"
          echo "  - Fedora/RHEL:    sudo dnf install diffstat"
        } >"$out_stat"
      fi
    else
      echo "Service '$svc': diff error (exit $code) -> $(basename "$out_diff")" | tee -a "$SUMMARY_FILE"
      echo "Diff error (exit $code). See $(basename "$out_diff") for details." >"$out_stat"
    fi
  fi
done

echo
echo "Done. Diff files are in: $OUT"
echo "Summary: $SUMMARY_FILE"
