#!/usr/bin/env bash
# Helper to serve a local Edge0 model for HRTBRKR.
# Requires: Edge0 cloned + installed, model downloaded, Apple Silicon Mac.
set -euo pipefail

TIER="${1:-edge0-8b}"
HOST="${EDGE0_HOST:-127.0.0.1}"
PORT="${EDGE0_PORT:-8000}"
EDGE0_ROOT="${EDGE0_ROOT:-}"

if [[ -z "$EDGE0_ROOT" ]]; then
  if [[ -d "$HOME/src/Edge0" ]]; then
    EDGE0_ROOT="$HOME/src/Edge0"
  elif [[ -d "$HOME/Edge0" ]]; then
    EDGE0_ROOT="$HOME/Edge0"
  elif command -v edge0 >/dev/null 2>&1; then
    EDGE0_ROOT=""
  else
    echo "Set EDGE0_ROOT to your Edge0 checkout, or install the edge0 CLI." >&2
    echo "  git clone https://github.com/Edge0-AI/Edge0.git" >&2
    exit 1
  fi
fi

if [[ -n "$EDGE0_ROOT" ]]; then
  cd "$EDGE0_ROOT"
  if [[ -x .venv/bin/edge0 ]]; then
    BIN=".venv/bin/edge0"
  elif [[ -x .venv/bin/python ]]; then
    BIN=".venv/bin/python -m edge0"
  else
    BIN="edge0"
  fi
else
  BIN="edge0"
fi

MODEL_DIR=""
case "$TIER" in
  edge0-8b)
    MODEL_DIR="${EDGE0_8B_MODEL:-models/edge0-8b}"
    ;;
  edge0-35b)
    MODEL_DIR="${EDGE0_35B_MODEL:-models/edge0-35b}"
    ;;
  *)
    MODEL_DIR="$TIER"
    ;;
esac

echo "HRTBRKR ← Edge0 serve $TIER on http://$HOST:$PORT"
# Prefer the tier name so EDGE0_*_MODEL env vars resolve; fall back to a path.
TARGET="$TIER"
case "$TIER" in
  edge0-8b|edge0-35b)
    if [[ -n "${EDGE0_8B_MODEL:-}" && "$TIER" == "edge0-8b" ]]; then
      TARGET="$EDGE0_8B_MODEL"
    elif [[ -n "${EDGE0_35B_MODEL:-}" && "$TIER" == "edge0-35b" ]]; then
      TARGET="$EDGE0_35B_MODEL"
    elif [[ -d "$MODEL_DIR" ]]; then
      TARGET="$MODEL_DIR"
    fi
    ;;
  *)
    TARGET="$MODEL_DIR"
    ;;
esac
echo "Model: $TARGET"
exec $BIN serve "$TARGET" --host "$HOST" --port "$PORT"
