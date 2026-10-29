#!/usr/bin/env bash
set -e
cd "$(dirname "$0")"

if [ -x ./playit ] && command -v tmux >/dev/null 2>&1; then
  if ! tmux has-session -t cedaf-playit 2>/dev/null; then
    tmux new-session -d -s cedaf-playit "./playit"
  fi
fi

exec ./iniciar.sh
