#!/bin/bash

# f-check: Verifica integridad (hashes) y validez estructural de archivos de código fuente
# Uso:
#   ./f-check -g [directorio]  -> Genera sumas
#   ./f-check [directorio]     -> Verifica sumas y estructura de código

declare -A sum_files=(
  [md5]="checksums.md5"
  [sha1]="checksums.sha1"
  [sha256]="checksums.sha256"
  [sha512]="checksums.sha512"
)

function generar_sumas() {
    dir="$1"
    echo "[+] Generando sumas en '$dir'..."
    for algo in "${!sum_files[@]}"; do
        file="${sum_files[$algo]}"
        echo "  - Generando $algo..."
        find "$dir" -type f ! -name "${sum_files[md5]}" ! -name "${sum_files[sha1]}" ! -name "${sum_files[sha256]}" ! -name "${sum_files[sha512]}" \
            -exec "${algo}sum" "{}" \; > "$dir/$file"
        echo "    ✓ Guardado en $file"
    done
    echo "[✓] Todas las sumas generadas."
}

function verificar_hashes() {
    dir="$1"
    cd "$dir" || exit 1
    for algo in "${!sum_files[@]}"; do
        file="${sum_files[$algo]}"
        if [[ -f "$file" ]]; then
            echo "[+] Verificando con $algo:"
            "${algo}sum" -c "$file"
        else
            echo "[!] Archivo de suma $file no encontrado. Saltando..."
        fi
        echo
    done
}

function verificar_codigo_fuente() {
    dir="$1"
    echo "[🔍] Verificando estructura de archivos de código fuente..."

    while IFS= read -r -d '' file; do
        ext="${file##*.}"
        echo "  → Analizando '$file'..."

        case "$ext" in
            py)
                python3 -m py_compile "$file" && echo "    ✅ Python OK" || echo "    ❌ Error de sintaxis Python"
                ;;
            c)
                gcc -fsyntax-only "$file" &>/dev/null && echo "    ✅ C OK" || echo "    ❌ Error de sintaxis C"
                ;;
            cpp)
                g++ -fsyntax-only "$file" &>/dev/null && echo "    ✅ C++ OK" || echo "    ❌ Error de sintaxis C++"
                ;;
            java)
                javac "$file" &>/dev/null && echo "    ✅ Java OK" || echo "    ❌ Error de compilación Java"
                ;;
            sh)
                bash -n "$file" && echo "    ✅ Bash OK" || echo "    ❌ Error de sintaxis Bash"
                ;;
            *)
                echo "    ℹ️ Extensión '$ext' no soportada (aún)."
                ;;
        esac
    done < <(find "$dir" -type f \( -name "*.py" -o -name "*.c" -o -name "*.cpp" -o -name "*.java" -o -name "*.sh" \) -print0)

    echo "[✓] Análisis de estructura de código finalizado."
}

# Main
if [[ "$1" == "-g" && -n "$2" ]]; then
    generar_sumas "$2"
elif [[ -n "$1" ]]; then
    verificar_hashes "$1"
    verificar_codigo_fuente "$1"
else
    echo "Uso:"
    echo "  $0 -g [directorio]   # Genera checksums con md5, sha1, sha256, sha512"
    echo "  $0 [directorio]      # Verifica checksums y archivos de código"
    exit 1
fi
