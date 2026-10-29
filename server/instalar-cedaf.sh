#!/usr/bin/env bash
set -Eeuo pipefail
cd "$(dirname "$0")"

MC="1.21.11"
STAMP="$(date +%Y%m%d-%H%M%S)"

echo "========================================="
echo "       CEDAF SMP - INSTALACAO COMPLETA"
echo "========================================="

if ! command -v java >/dev/null 2>&1; then
  echo "ERRO: Java nao encontrado neste Codespace."
  exit 1
fi

java -version

read -r -p "Voce aceita a EULA oficial do Minecraft? (s/N): " ACEITA
case "$ACEITA" in
  s|S|sim|SIM|Sim) ;;
  *) echo "Instalacao cancelada. Leia a EULA oficial antes de continuar."; exit 0 ;;
esac

mkdir -p plugins

# Backup das configuracoes e dos plugins existentes.
BACKUP="backup-${STAMP}"
if [ -f purpur.jar ] || [ -f server.properties ] || \
   [ -d plugins/Geyser-Spigot ] || [ -d world ]; then
  mkdir -p "$BACKUP"
  for f in purpur.jar server.properties eula.txt purpur.yml \
           spigot.yml bukkit.yml; do
    [ ! -e "$f" ] || cp -a "$f" "$BACKUP/"
  done
  [ ! -d plugins ] || cp -a plugins "$BACKUP/"
  echo "Backup criado em: $BACKUP"
fi

echo "[1/7] Baixando Purpur ${MC}..."
curl -fLsS --retry 3 \
  "https://api.purpurmc.org/v2/purpur/${MC}/latest/download" \
  -o purpur.jar.new
mv purpur.jar.new purpur.jar

echo "[2/7] Baixando Geyser e Floodgate..."
curl -fLsS --retry 3 \
  "https://download.geysermc.org/v2/projects/geyser/versions/latest/builds/latest/downloads/spigot" \
  -o plugins/Geyser-Spigot.jar.new
curl -fLsS --retry 3 \
  "https://download.geysermc.org/v2/projects/floodgate/versions/latest/builds/latest/downloads/spigot" \
  -o plugins/floodgate-spigot.jar.new

mv plugins/Geyser-Spigot.jar.new plugins/Geyser-Spigot.jar
mv plugins/floodgate-spigot.jar.new plugins/floodgate-spigot.jar

echo "[3/7] Baixando EssentialsX..."
curl -fLsS --retry 3 \
  "https://repo.essentialsx.net/releases/net/essentialsx/EssentialsX/2.22.0/EssentialsX-2.22.0.jar" \
  -o plugins/EssentialsX.jar.new
curl -fLsS --retry 3 \
  "https://repo.essentialsx.net/releases/net/essentialsx/EssentialsXSpawn/2.22.0/EssentialsXSpawn-2.22.0.jar" \
  -o plugins/EssentialsXSpawn.jar.new

mv plugins/EssentialsX.jar.new plugins/EssentialsX.jar
mv plugins/EssentialsXSpawn.jar.new plugins/EssentialsXSpawn.jar

echo "[4/7] Baixando ViaVersion, LuckPerms e SkinsRestorer..."

# Downloads oficiais das releases mais recentes publicadas no GitHub.
python3 <<'PY'
import json
import urllib.request
from pathlib import Path

plugins = Path("plugins")

def download_latest(repo, keyword, target):
    api = f"https://api.github.com/repos/{repo}/releases/latest"
    req = urllib.request.Request(
        api, headers={"User-Agent": "CEDAF-SMP-Installer"}
    )
    with urllib.request.urlopen(req, timeout=30) as response:
        release = json.load(response)

    assets = [
        a for a in release.get("assets", [])
        if a["name"].lower().endswith(".jar")
        and keyword.lower() in a["name"].lower()
    ]
    if not assets:
        raise RuntimeError(f"Nenhum JAR encontrado para {repo}")

    asset = assets[0]
    req = urllib.request.Request(
        asset["browser_download_url"],
        headers={"User-Agent": "CEDAF-SMP-Installer"}
    )
    with urllib.request.urlopen(req, timeout=90) as response:
        data = response.read()

    if not data.startswith(b"PK"):
        raise RuntimeError(f"Arquivo JAR invalido: {asset['name']}")

    (plugins / target).write_bytes(data)
    print(f"OK: {asset['name']}")

download_latest(
    "ViaVersion/ViaVersion", "viaversion", "ViaVersion.jar"
)
download_latest(
    "SkinsRestorer/SkinsRestorer", "skinsrestorer", "SkinsRestorer.jar"
)
PY

# LuckPerms: versao publicada conhecida e download oficial.
curl -fLsS --retry 3 \
  "https://download.luckperms.net/5.5.88/bukkit/loader/LuckPerms-Bukkit-5.5.88.jar" \
  -o plugins/LuckPerms.jar

echo "[5/7] Configurando o servidor..."

cat > eula.txt <<'EULA'
eula=true
EULA

python3 <<'PY'
from pathlib import Path

path = Path("server.properties")
values = {
    "motd": "CEDAF SMP - Java + Bedrock",
    "server-port": "25565",
    "server-ip": "",
    "online-mode": "true",
    "max-players": "20",
    "view-distance": "7",
    "simulation-distance": "5",
    "network-compression-threshold": "256",
    "use-native-transport": "true",
    "allow-flight": "true",
    "spawn-protection": "0",
    "enable-command-block": "false",
    "enable-rcon": "false",
    "white-list": "false",
    "difficulty": "normal",
    "gamemode": "survival",
}

lines = path.read_text().splitlines() if path.exists() else []
output = []
found = set()

for line in lines:
    if "=" in line and not line.lstrip().startswith("#"):
        key = line.split("=", 1)[0].strip()
        if key in values:
            output.append(f"{key}={values[key]}")
            found.add(key)
            continue
    output.append(line)

for key, value in values.items():
    if key not in found:
        output.append(f"{key}={value}")

path.write_text("\n".join(output) + "\n")
PY

echo "[6/7] Preparando Playit..."

ARCH="$(uname -m)"
case "$ARCH" in
  x86_64|amd64) PLAYIT_ASSET="playit-linux-amd64" ;;
  aarch64|arm64) PLAYIT_ASSET="playit-linux-aarch64" ;;
  *)
    PLAYIT_ASSET=""
    echo "Aviso: arquitetura sem binario Playit automatico: $ARCH"
    ;;
esac

if [ -n "$PLAYIT_ASSET" ]; then
  if curl -fLsS --retry 2 \
    "https://github.com/playit-cloud/playit-agent/releases/latest/download/${PLAYIT_ASSET}" \
    -o playit; then
    chmod +x playit
    echo "Agente Playit instalado."
  else
    rm -f playit
    echo "Aviso: Playit nao baixado; voce ainda pode configurar isso depois."
  fi
fi

cat > iniciar.sh <<'START'
#!/usr/bin/env bash
set -Eeuo pipefail
cd "$(dirname "$0")"

if [ ! -f purpur.jar ]; then
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
START

cat > configurar-playit.sh <<'PLAYIT'
#!/usr/bin/env bash
set -Eeuo pipefail
cd "$(dirname "$0")"
if [ ! -x ./playit ]; then
  echo "Playit nao esta instalado."
  exit 1
fi
exec ./playit
PLAYIT

cat > iniciar-tudo.sh <<'STARTALL'
#!/usr/bin/env bash
set -Eeuo pipefail
cd "$(dirname "$0")"

if [ -x ./playit ]; then
  if command -v tmux >/dev/null 2>&1; then
    if ! tmux has-session -t cedaf-playit 2>/dev/null; then
      tmux new-session -d -s cedaf-playit \
        "cd '$PWD' && ./playit"
      echo "Playit iniciado na sessao tmux cedaf-playit."
    fi
  else
    echo "Aviso: tmux nao instalado."
    echo "Para usar o Playit, execute ./configurar-playit.sh em outro terminal."
  fi
fi

exec ./iniciar.sh
STARTALL

chmod +x iniciar.sh iniciar-tudo.sh configurar-playit.sh

echo "[7/7] Gerando configuracoes iniciais..."
if [ ! -f plugins/Geyser-Spigot/config.yml ]; then
  FIFO=".instalacao-console"
  LOG="instalacao-inicial.log"
  rm -f "$FIFO"
  mkfifo "$FIFO"

  java -Xms1G -Xmx6G -XX:+UseG1GC \
    -jar purpur.jar --nogui < "$FIFO" > "$LOG" 2>&1 &
  PID=$!
  exec 3>"$FIFO"

  READY=0
  for i in $(seq 1 180); do
    if grep -q "Done (" "$LOG"; then
      READY=1
      break
    fi
    if ! kill -0 "$PID" 2>/dev/null; then
      break
    fi
    sleep 2
  done

  if [ "$READY" -eq 1 ]; then
    # Permissoes basicas para jogadores comuns.
    for CMD in \
      "lp group default permission set essentials.tpa true" \
      "lp group default permission set essentials.tpaccept true" \
      "lp group default permission set essentials.tpdeny true" \
      "lp group default permission set essentials.tpacancel true" \
      "lp group default permission set essentials.back true" \
      "lp group default permission set essentials.back.ondeath true" \
      "lp group default permission set essentials.home true" \
      "lp group default permission set essentials.sethome true" \
      "lp group default permission set essentials.delhome true" \
      "lp group default permission set essentials.list true" \
      "lp group default permission set essentials.spawn true"; do
      printf '%s\n' "$CMD" >&3
      sleep 0.4
    done
    sleep 2
    printf 'stop\n' >&3
  else
    echo "ERRO: primeira inicializacao nao terminou."
    echo "Veja o log em $LOG."
    kill -INT "$PID" 2>/dev/null || true
  fi

  exec 3>&-
  wait "$PID" || true
  rm -f "$FIFO"

  if [ "$READY" -ne 1 ]; then
    tail -n 60 "$LOG" || true
    exit 1
  fi
else
  echo "Configuracao Geyser existente: preservada."
fi

# Ativa o keepalive alternativo do Purpur, que tolera
# perda ocasional de pacotes sem expulsar jogadores tao cedo.
python3 <<'PY'
from pathlib import Path
import re

path = Path("purpur.yml")
if path.exists():
    text = path.read_text()
    if re.search(r"(?m)^use-alternate-keepalive\s*:", text):
        text = re.sub(
            r"(?m)^use-alternate-keepalive\s*:.*$",
            "use-alternate-keepalive: true",
            text
        )
    else:
        text += "\nuse-alternate-keepalive: true\n"
    path.write_text(text)

path = Path("plugins/Geyser-Spigot/config.yml")
if path.exists():
    text = path.read_text()
    updated, count = re.subn(
        r"(?m)^([ \t]*auth-type:[ \t]*)[^#\r\n]+",
        r"\1floodgate",
        text,
        count=1
    )
    if count:
        path.write_text(updated)
        print("Geyser configurado para autenticar via Floodgate.")
    else:
        print("AVISO: confira auth-type no config.yml do Geyser.")
else:
    raise SystemExit("Config do Geyser nao foi gerada.")
PY

# Atalho para iniciar pelo terminal bash.
ALIAS="alias cedaf='cd /workspaces/Cedaf-Smp/server && ./iniciar-tudo.sh'"
touch "$HOME/.bashrc"
if ! grep -Fq "alias cedaf=" "$HOME/.bashrc"; then
  echo "$ALIAS" >> "$HOME/.bashrc"
fi

echo
echo "========================================="
echo " CEDAF SMP CONFIGURADO!"
echo " Minecraft: $MC"
echo " Plugins: plugins/"
echo " Java: ./iniciar.sh"
echo " Tudo: ./iniciar-tudo.sh"
echo " Atalho bash: cedaf"
echo "========================================="
