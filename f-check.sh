#!/bin/bash

# f-check v4.0
# Analizador de archivos EXTENDIDO con mejoras adicionales

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[1;34m'; NC='\033[0m'
LOGFILE="/var/log/f-check/$(date +%Y%m%d_%H%M%S).log"
mkdir -p /var/log/f-check

hash_cmds=(md5sum sha1sum sha256sum)

function barra_progreso() {
  local i=$1 total=$2 ancho=40
  local done=$((i * ancho / total))
  local todo=$((ancho - done))
  printf "\r${BLUE}[%-${ancho}s]${NC} ${YELLOW}%3d%%${NC}" "$(printf '#%.0s' $(seq 1 $done))" $((i * 100 / total))
}

function log() {
  echo -e "$1" | tee -a "$LOGFILE"
}

function analizar_archivo() {
  local file="$1"
  [[ ! -f "$file" ]] && log "${RED}❌ No encontrado: $file${NC}" && return

  log "\n${BLUE}📂 Analizando: $file${NC}"
  ext="${file##*.}"

  # Calcular hashes
  for cmd in "${hash_cmds[@]}"; do
    val=$($cmd "$file" | cut -d ' ' -f1)
    log "  ${YELLOW}${cmd}:${NC} $val"
  done

  # Detectar duplicados
  hash_val=$(sha256sum "$file" | cut -d ' ' -f1)
  if grep -q "$hash_val" /tmp/f-check_hashes.tmp 2>/dev/null; then
    log "  ${RED}⚠️ Archivo duplicado detectado${NC}"
  else
    echo "$hash_val $file" >> /tmp/f-check_hashes.tmp
  fi

  tipo=$(file -b "$file")
  size=$(stat -c%s "$file")
  log "  Tipo: $tipo"
  log "  Tamaño: $size bytes"
  [ "$size" -lt 5 ] && log "  ${RED}⚠️ Archivo sospechosamente pequeño${NC}"
  [ "$size" -gt $((1024 * 1024 * 100)) ] && log "  ${YELLOW}⚠️ Archivo muy grande (>100MB)${NC}"

  perms=$(stat -c "%A" "$file")
  log "  Permisos: $perms"

  ok=1
  case "$ext" in
    py) python3 -m py_compile "$file" &>/dev/null || ok=0 ;;
    c) gcc -fsyntax-only "$file" &>/dev/null || ok=0 ;;
    cpp) g++ -fsyntax-only "$file" &>/dev/null || ok=0 ;;
    java) javac "$file" &>/dev/null || ok=0 ;;
    sh) bash -n "$file" &>/dev/null || ok=0 ;;
    js) node --check "$file" &>/dev/null || ok=0 ;;
    php) php -l "$file" &>/dev/null || ok=0 ;;
    json) python3 -m json.tool "$file" &>/dev/null || ok=0 ;;
    yaml|yml) python3 -c "import yaml, sys; yaml.safe_load(open(sys.argv[1]))" "$file" &>/dev/null || ok=0 ;;
    html) tidy -q -e "$file" &>/dev/null || ok=0 ;;
    zip) unzip -t "$file" &>/dev/null || ok=0 ;;
    gz|tar.gz) tar -tzf "$file" &>/dev/null || ok=0 ;;
    md) grep -oP '(?<=\]\().*?(?=\))' "$file" | while read -r url; do curl --head --silent --fail "$url" > /dev/null || log "  ${RED}❌ Enlace roto: $url${NC}"; done ;;
    *) log "  ${YELLOW}Tipo desconocido, revisión manual sugerida${NC}" ;;
  esac

  [ "$ok" -eq 1 ] && log "  ${GREEN}✔️ OK${NC}" || log "  ${RED}❌ Error de análisis${NC}"
}

if [[ "$1" == "--help" ]]; then
  echo "Uso: sudo f-check archivo1 archivo2 ..."
  exit 0
fi

total=$#
i=1
for f in "$@"; do
  analizar_archivo "$f"
  barra_progreso $i $total
  ((i++))
done

echo -e "\n\n${BLUE}Reporte completo guardado en: $LOGFILE${NC}"
