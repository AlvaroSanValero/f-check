#!/bin/bash

# f-check: Herramienta de análisis de archivos para validación, detección de errores y buenas prácticas
# Versión: 5.1 (Multiplataforma y comentada)

# ------------------------------
# Colores para salida en terminal (ANSI escape codes)
# ------------------------------
RED='\033[0;31m'      # Rojo para errores
GREEN='\033[0;32m'    # Verde para éxito
YELLOW='\033[1;33m'   # Amarillo para advertencias
BLUE='\033[1;34m'     # Azul para información
NC='\033[0m'          # Sin color (reset)

# ------------------------------
# Detectar sistema operativo
# ------------------------------
OS=$(uname -s)        # Obtener nombre del sistema operativo
case "$OS" in
  Linux*)     PLATFORM="linux" ;;                      # Linux
  Darwin*)    PLATFORM="macos" ;;                      # macOS (Intel o M1)
  MINGW*|MSYS*|CYGWIN*) PLATFORM="windows" ;;          # Windows con entorno Unix (Git Bash, etc.)
  *)          PLATFORM="unknown" ;;                    # Otro/Desconocido
esac

# ------------------------------
# Directorio y archivo de log
# ------------------------------
LOGDIR="$HOME/.f-check/logs"   # Carpeta donde guardar logs
LOGFILE="$LOGDIR/fcheck_$(date +%Y%m%d_%H%M%S).log"   # Archivo de log con timestamp
mkdir -p "$LOGDIR"             # Crear el directorio si no existe
touch "$LOGFILE"               # Crear el archivo de log

# ------------------------------
# Detectar comandos hash disponibles en el sistema
# ------------------------------
declare -A hash_cmds
hash_cmds[md5]=$(command -v md5sum || command -v md5)                # Buscar md5sum o md5
hash_cmds[sha1]=$(command -v sha1sum || command -v shasum)           # Buscar sha1sum o shasum
hash_cmds[sha256]=$(command -v sha256sum || command -v shasum)       # Buscar sha256sum o shasum

# ------------------------------
# Función para mostrar barra de progreso en consola
# ------------------------------
function barra_progreso() {
  local paso=$1 total=$2 ancho=40
  local porc=$(( paso * 100 / total ))             # Porcentaje completado
  local done=$(( paso * ancho / total ))           # Cantidad de caracteres completados
  local todo=$(( ancho - done ))                   # Restantes

  printf "\r${BLUE}["
  printf "${GREEN}%0.s#" $(seq 1 $done)            # Mostrar "#" completado
  printf "${NC}%0.s-" $(seq 1 $todo)               # Mostrar "-" restante
  printf "${BLUE}] ${YELLOW}%3d%%${NC}" $porc      # Mostrar porcentaje
}

# ------------------------------
# Función para registrar mensajes en el log
# ------------------------------
function log() {
  echo -e "$1" | tee -a "$LOGFILE"                # Imprime y guarda en log
}

# ------------------------------
# Función principal para analizar un archivo individual
# ------------------------------
function analizar_archivo() {
  local file="$1"
  local total=6 paso=1                             # Total de pasos del análisis

  # Verificar que el archivo exista
  if [[ ! -f "$file" ]]; then
    log "${RED}❌ El archivo '$file' no existe.${NC}"
    return
  fi

  log "\n${BLUE}📂 Analizando archivo: $file${NC}"
  ext="${file##*.}"                               # Extraer extensión del archivo

  # -------- Paso 1: Cálculo de hashes --------
  log "\n[${paso}/$total] 🔐 Hashes:"
  for algo in "${!hash_cmds[@]}"; do
    cmd=${hash_cmds[$algo]}
    if [[ "$cmd" == *shasum* ]]; then
      flag=""
      [[ "$algo" == "sha256" ]] && flag="-a 256"   # Usar argumento correcto para sha256
      val=$($cmd $flag "$file" | awk '{print $1}') # Calcular hash
    else
      val=$($cmd "$file" | awk '{print $1}')
    fi
    log "  ${YELLOW}$algo:${NC} $val"
  done
  paso=$((paso+1)); barra_progreso $paso $total; sleep 0.1

  # Comprobación de duplicados (temporal, usando hash SHA256)
  hash_val=$(sha256sum "$file" 2>/dev/null | awk '{print $1}')
  [[ -z "$hash_val" && "$PLATFORM" == "macos" ]] && hash_val=$(shasum -a 256 "$file" | awk '{print $1}')
  if grep -q "$hash_val" /tmp/f-check_hashes.tmp 2>/dev/null; then
    log "  ${RED}⚠️ Archivo duplicado detectado${NC}"
  else
    echo "$hash_val $file" >> /tmp/f-check_hashes.tmp
  fi

  # -------- Paso 2: Validación de sintaxis --------
  log "\n[${paso}/$total] 🔍 Análisis de sintaxis:"
  ok=1
  case "$ext" in
    py)    python3 -m py_compile "$file" &>/dev/null || ok=0 ;;
    c)     gcc -fsyntax-only "$file" &>/dev/null || ok=0 ;;
    cpp)   g++ -fsyntax-only "$file" &>/dev/null || ok=0 ;;
    java)  javac "$file" &>/dev/null || ok=0 ;;
    sh)    bash -n "$file" &>/dev/null || ok=0 ;;
    js)    node --check "$file" &>/dev/null || ok=0 ;;
    php)   php -l "$file" &>/dev/null || ok=0 ;;
    *)     log "  ${YELLOW}ℹ️ No se reconoce la extensión para análisis de sintaxis${NC}" ;;
  esac
  [[ "$ok" -eq 1 ]] && log "  ${GREEN}✅ Sintaxis OK${NC}" || log "  ${RED}❌ Error de sintaxis${NC}"
  paso=$((paso+1)); barra_progreso $paso $total; sleep 0.1

  # -------- Paso 3: Validación de estructura/formato --------
  log "\n[${paso}/$total] 🧩 Validación de formato:"
  case "$ext" in
    json) python3 -m json.tool "$file" &>/dev/null && log "  ${GREEN}✅ JSON válido${NC}" || log "  ${RED}❌ JSON inválido${NC}" ;;
    yaml|yml) python3 -c "import yaml, sys; yaml.safe_load(open(sys.argv[1]))" "$file" &>/dev/null && log "  ${GREEN}✅ YAML válido${NC}" || log "  ${RED}❌ YAML inválido${NC}" ;;
    html) command -v tidy &>/dev/null && tidy -q -e "$file" &>/dev/null && log "  ${GREEN}✅ HTML válido${NC}" || log "  ${YELLOW}⚠️ HTML sin validar (instala tidy)${NC}" ;;
    md)
      grep -oP '\[.*?\]\(\K[^)]+' "$file" | while read -r url; do
        curl --head --silent --fail "$url" > /dev/null || log "  ${RED}❌ Enlace roto: $url${NC}"
      done ;;
    *) log "  ${YELLOW}ℹ️ No es archivo estructurado conocido${NC}" ;;
  esac
  paso=$((paso+1)); barra_progreso $paso $total; sleep 0.1

  # -------- Paso 4: Revisión de comentarios en código --------
  log "\n[${paso}/$total] 📋 Comentarios:"
  grep -Ei "author|description|creado" "$file" &>/dev/null && log "  ${GREEN}✅ Comentarios presentes${NC}" || log "  ${YELLOW}⚠️ Faltan comentarios informativos${NC}"
  paso=$((paso+1)); barra_progreso $paso $total; sleep 0.1

  # -------- Paso 5: Comprobación de archivos basura --------
  log "\n[${paso}/$total] 🧹 Limpieza:"
  [[ "$file" =~ \.(o|class|out|tmp|log)$ ]] && log "  ${YELLOW}⚠️ Archivo puede ser basura/compilado${NC}" || log "  ${GREEN}✅ No parece archivo temporal${NC}"
  paso=$((paso+1)); barra_progreso $paso $total; sleep 0.1

  # -------- Paso 6: Mostrar metadatos del archivo --------
  log "\n[${paso}/$total] ℹ️ Metadatos:"
  tipo=$(file -b "$file")                                     # Tipo MIME o descripción
  case "$PLATFORM" in
    linux|macos) size=$(stat -c%s "$file" 2>/dev/null || stat -f%z "$file") ;;   # Tamaño
    windows) size=$(stat -c%s "$file") ;;
  esac
  perms=$(stat -c "%A" "$file" 2>/dev/null || stat -f "%Sp" "$file")            # Permisos

  log "  Tipo: $tipo"
  log "  Tamaño: $size bytes"
  log "  Permisos: $perms"
  [[ "$size" -lt 5 ]] && log "  ${RED}⚠️ Archivo muy pequeño${NC}"
  [[ "$size" -gt $((1024 * 1024 * 100)) ]] && log "  ${YELLOW}⚠️ Archivo muy grande${NC}"

  log "\n${GREEN}✔️ Análisis completo de '$file'${NC}"
}

# ------------------------------
# Mostrar ayuda si se invoca con --help
# ------------------------------
if [[ "$1" == "--help" ]]; then
  echo -e "${YELLOW}Uso:${NC}"
  echo -e "  ${GREEN}bash f-check.sh archivo1 archivo2 ...${NC}"
  exit 0
fi

# ------------------------------
# Validación de argumentos de entrada
# ------------------------------
if [[ $# -eq 0 ]]; then
  echo -e "${RED}❌ No se especificaron archivos.${NC}"
  exit 1
fi

# ------------------------------
# Procesar archivos uno por uno
# ------------------------------
total_archivos=$#
archivo_n=1
for f in "$@"; do
  echo -e "\n${BLUE}→ Archivo ${archivo_n}/${total_archivos}: $f${NC}"
  analizar_archivo "$f"
  barra_progreso $archivo_n $total_archivos
  ((archivo_n++))
  echo ""
done

# ------------------------------
# Finalización del script
# ------------------------------
echo -e "\n${BLUE}📝 Log guardado en: $LOGFILE${NC}"
echo -e "${GREEN}✔️ Todos los archivos analizados exitosamente${NC}"
