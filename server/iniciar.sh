#!/usr/bin/env bash
set -e
cd "$(dirname "$0")"

if [ ! -s purpur.jar ]; then
  echo "ERRO: purpur.jar nao encontrado."
  exit 1
fi

exec java \
  -Xms2G -Xmx6G \
  -XX:+UseG1GC \
  -XX:+ParallelRefProcEnabled \
  -XX:MaxGCPauseMillis=200 \
  -XX:+DisableExplicitGC \
  -Dfile.encoding=UTF-8 \
  -jar purpur.jar --nogui
