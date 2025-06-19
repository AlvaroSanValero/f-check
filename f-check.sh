#!/bin/bash

# f-check: Verificador avanzado de archivos y proyectos

# Colores ANSI
RED='\\033[0;31m'
GREEN='\\033[0;32m'
YELLOW='\\033[1;33m'
BLUE='\\033[1;34m'
NC='\\033[0m' # Sin color

declare -A hash_cmds=(
  [md5]="md5sum"
  [sha1]="sha1sum"
  [sha256]="sha256sum"
  [sha512]="sha512sum"
)

function barra_progreso() {
    local paso=$1
    local total=$2
    local ancho=40
    local porcentaje=$(( paso * 100 / total ))
    local relleno=$(( paso * ancho / total ))
    local vacio=$(( ancho - relleno ))

    printf "\\r${BLUE}["
    printf "${GREEN}%0.s#" $(seq 1 $relleno)
    printf "${NC}%0.s-" $(seq 1 $vacio)
    printf "${BLUE}] ${YELLOW}%3d%%${NC}" $porcentaje
}

function analizar_archivo() {
    file="$1"
    if [[ ! -f "$file" ]]; then
        echo -e "${RED}❌ El archivo '$file' no existe.${NC}"
        return
    fi

    total=5
    paso=1

    echo -e "${BLUE}📂 Analizando archivo: $file${NC}"

    echo -e "\\n[1/$total] 🔐 Hashes:"
    for algo in "${!hash_cmds[@]}"; do
        echo -e "  ${YELLOW}$algo:${NC} $("${hash_cmds[$algo]}" "$file" | awk '{print $1}')"
    done
    barra_progreso $paso $total; ((paso++)); sleep 0.1

    echo -e "\\n\\n[2/$total] 🔍 Análisis de sintaxis:"
    ext="${file##*.}"
    case "$ext" in
        py)    python3 -m py_compile "$file" && echo -e "  ${GREEN}✅ Python OK${NC}" || echo -e "  ${RED}❌ Error Python${NC}" ;;
        c)     gcc -fsyntax-only "$file" &>/dev/null && echo -e "  ${GREEN}✅ C OK${NC}" || echo -e "  ${RED}❌ Error C${NC}" ;;
        cpp)   g++ -fsyntax-only "$file" &>/dev/null && echo -e "  ${GREEN}✅ C++ OK${NC}" || echo -e "  ${RED}❌ Error C++${NC}" ;;
        java)  javac "$file" &>/dev/null && echo -e "  ${GREEN}✅ Java OK${NC}" || echo -e "  ${RED}❌ Error Java${NC}" ;;
        sh)    bash -n "$file" && echo -e "  ${GREEN}✅ Bash OK${NC}" || echo -e "  ${RED}❌ Error Bash${NC}" ;;
        *)     echo -e "  ${YELLOW}ℹ️ Extensión no reconocida para sintaxis.${NC}" ;;
    esac
    barra_progreso $paso $total; ((paso++)); sleep 0.1

    echo -e "\\n\\n[3/$total] 🧩 Validación de formato:"
    case "$ext" in
        json)
            python3 -m json.tool "$file" > /dev/null && echo -e "  ${GREEN}✅ JSON válido${NC}" || echo -e "  ${RED}❌ JSON inválido${NC}"
            ;;
        yaml|yml)
            if python3 -c "import yaml" &>/dev/null; then
                python3 -c "import yaml, sys; yaml.safe_load(sys.stdin)" < "$file" && echo -e "  ${GREEN}✅ YAML válido${NC}" || echo -e "  ${RED}❌ YAML inválido${NC}"
            else
                echo -e "  ${YELLOW}⚠️ PyYAML no instalado${NC}"
            fi
            ;;
        html)
            if command -v tidy &>/dev/null; then
                tidy -q -e "$file" &>/dev/null && echo -e "  ${GREEN}✅ HTML válido${NC}" || echo -e "  ${YELLOW}⚠️ HTML con advertencias${NC}"
            else
                echo -e "  ${YELLOW}⚠️ tidy no instalado${NC}"
            fi
            ;;
        *) echo -e "  ${YELLOW}ℹ️ No es archivo de datos estructurados reconocido${NC}" ;;
    esac
    barra_progreso $paso $total; ((paso++)); sleep 0.1

    echo -e "\\n\\n[4/$total] 📋 Comentarios:"
    grep -Ei "autor|author|descripción|description" "$file" > /dev/null \
        && echo -e "  ${GREEN}✅ Comentario encontrado${NC}" \
        || echo -e "  ${YELLOW}⚠️ No se encontraron comentarios${NC}"
    barra_progreso $paso $total; ((paso++)); sleep 0.1

    echo -e "\\n\\n[5/$total] 🧹 Limpieza (simulada):"
    [[ "$file" =~ \.(o|class|out)$ ]] && echo -e "  ${YELLOW}⚠️ Archivo compilado${NC}" || echo -e "  ${GREEN}✅ No parece archivo basura${NC}"
    barra_progreso $paso $total; ((paso++)); sleep 0.1

    echo -e "\\n\\n${GREEN}✔️ Análisis completo de '$file'${NC}"
}

# MAIN

if [[ "$1" == "-ndir" && -n "$2" ]]; then
    analizar_archivo "$2"
    exit 0
fi

if [[ $# -eq 0 ]]; then
    echo -e "${YELLOW}Uso:${NC}"
    echo -e "  ${GREEN}sudo f-check -ndir archivo.ext${NC}     # Analiza un archivo"
    echo -e "  ${GREEN}sudo f-check archivo1.ext archivo2.ext${NC}   # Múltiples archivos"
    exit 1
fi

# Analizar múltiples archivos
total_archivos=$#
archivo_n=1
for file in "$@"; do
    echo -e "\\n${BLUE}→ Analizando archivo ${archivo_n}/${total_archivos}: $file${NC}"
    analizar_archivo "$file"
    barra_progreso "$archivo_n" "$total_archivos"
    ((archivo_n++))
    echo ""
done

echo -e "\\n${GREEN}✔️ Análisis de todos los archivos completado${NC}"
