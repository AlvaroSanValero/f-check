#!/bin/bash

# f-check EXTENDIDO v3.0
# Autor: ChatGPT personalizado
# Características: análisis de archivos, sintaxis, estructura, seguridad, heurística de calidad, etc.

RED='\\033[0;31m'; GREEN='\\033[0;32m'; YELLOW='\\033[1;33m'; BLUE='\\033[1;34m'; NC='\\033[0m'
LOGFILE="/tmp/f-check.log"
REPORT_HTML=""
GENERAR_REPORTE=false
SHOW_VERSION=false
SHOW_HELP=false
declare -i TOTAL_OK=0 TOTAL_WARN=0 TOTAL_ERR=0

declare -A hash_cmds=(
  [md5]="md5sum"
  [sha1]="sha1sum"
  [sha256]="sha256sum"
)

function version() {
  echo "f-check v3.0 - desarrollado por ChatGPT"
  exit 0
}

function help() {
  echo "Uso: f-check [--report] archivo1 archivo2 ..."
  echo "     f-check -ndir archivo.c"
  echo "     f-check --version / --help"
  exit 0
}

function log() {
  echo -e "$1" | tee -a "$LOGFILE"
}

function barra_progreso() {
  local paso=$1 total=$2 ancho=40
  local porcentaje=$(( paso * 100 / total ))
  local relleno=$(( paso * ancho / total ))
  local vacio=$(( ancho - relleno ))

  printf "\\r${BLUE}["
  printf "${GREEN}%0.s#" $(seq 1 $relleno)
  printf "${NC}%0.s-" $(seq 1 $vacio)
  printf "${BLUE}] ${YELLOW}%3d%%${NC}" $porcentaje
}

function detectar_codificacion() {
  enc=$(file -bi "$1" | cut -d= -f2)
  log "  ${BLUE}Codificación:${NC} $enc"
}

function heuristica_codigo() {
  lines=$(wc -l < "$1")
  comments=$(grep -cE '^\s*#|//|/\*|\*' "$1")
  todos=$(grep -ciE 'todo|fixme' "$1")
  funcs=$(grep -cE 'def |function |void |int .*\\(|public .*\\(' "$1")
  log "  📈 Líneas: $lines | Comentarios: $comments | Funciones: $funcs | TODO/FIXME: $todos"
}

function analizar_archivo() {
  local file="$1"
  [[ ! -f "$file" ]] && log "${RED}❌ No encontrado: $file${NC}" && TOTAL_ERR+=1 && return

  log "\\n${BLUE}📂 Analizando: $file${NC}"
  ext="${file##*.}"

  for algo in "${!hash_cmds[@]}"; do
    hval=$("${hash_cmds[$algo]}" "$file" | cut -d' ' -f1)
    log "  ${YELLOW}${algo}:${NC} $hval"
  done

  detectar_codificacion "$file"
  heuristica_codigo "$file"

  case "$ext" in
    py) python3 -m py_compile "$file" && status=OK || status=ERR ;;
    c) gcc -fsyntax-only "$file" &>/dev/null && status=OK || status=ERR ;;
    cpp) g++ -fsyntax-only "$file" &>/dev/null && status=OK || status=ERR ;;
    java) javac "$file" &>/dev/null && status=OK || status=ERR ;;
    sh) bash -n "$file" && status=OK || status=ERR ;;
    js) node --check "$file" &>/dev/null && status=OK || status=ERR ;;
    php) php -l "$file" &>/dev/null && status=OK || status=ERR ;;
    json)
      python3 -m json.tool "$file" > /dev/null && status=OK || status=ERR ;;
    yaml|yml)
      python3 -c "import yaml, sys; yaml.safe_load(sys.stdin)" < "$file" && status=OK || status=ERR ;;
    html)
      tidy -q -e "$file" &>/dev/null && status=OK || status=WARN ;;
    *) status=WARN ;;
  esac

  case "$status" in
    OK) log "  ${GREEN}✅ Análisis correcto${NC}" && TOTAL_OK+=1 ;;
    WARN) log "  ${YELLOW}⚠️ Resultado con advertencias${NC}" && TOTAL_WARN+=1 ;;
    ERR) log "  ${RED}❌ Error de análisis${NC}" && TOTAL_ERR+=1 ;;
  esac

  if [[ -x "$file" ]]; then
    log "  ${RED}⚠️ Archivo ejecutable${NC}"
  fi

  # Escaneo antivirus si ClamAV está disponible
  if command -v clamscan &>/dev/null; then
    scanres=$(clamscan "$file" 2>/dev/null | grep -v "OK$")
    [[ -n "$scanres" ]] && log "  ${RED}🚨 Posible virus:${NC} $scanres" && TOTAL_WARN+=1
  fi
}

function analizar_directorio() {
  local dir="$1"
  find "$dir" -type f ! -path "*/\\.*" ! -path "*/node_modules/*" ! -path "*/__pycache__/*" | while read -r f; do
    analizar_archivo "$f"
  done
}

# MAIN
[[ "$1" == "--version" ]] && version
[[ "$1" == "--help" ]] && help
[[ "$1" == "--report" ]] && GENERAR_REPORTE=true && shift
[[ "$1" == "-ndir" && -n "$2" ]] && analizar_archivo "$2" && exit 0

[[ $# -eq 0 ]] && help

echo "" > "$LOGFILE"
n=1
total=$#
for arg in "$@"; do
  echo -e "\\n${YELLOW}[$n/$total] Analizando: $arg${NC}"
  [[ -d "$arg" ]] && analizar_directorio "$arg" || analizar_archivo "$arg"
  barra_progreso $n $total
  ((n++))
done

echo -e "\\n\\n${BLUE}📊 Resumen:${NC}"
echo -e "  ${GREEN}✔️ Correctos: $TOTAL_OK${NC}"
echo -e "  ${YELLOW}⚠️ Advertencias: $TOTAL_WARN${NC}"
echo -e "  ${RED}❌ Errores: $TOTAL_ERR${NC}"
