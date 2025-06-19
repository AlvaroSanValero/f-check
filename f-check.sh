#!/bin/bash

# f-check: Verifica integridad de archivos con múltiples algoritmos (md5, sha1, sha256, sha512)
# Uso:
#   ./f-check -g [directorio]    -> Genera sumas
#   ./f-check [directorio]       -> Verifica sumas

# Archivos de sumas por algoritmo
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

function verificar_archivos() {
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

# Main
if [[ "$1" == "-g" && -n "$2" ]]; then
    generar_sumas "$2"
elif [[ -n "$1" ]]; then
    verificar_archivos "$1"
else
    echo "Uso:"
    echo "  $0 -g [directorio]    # Genera checksums con md5, sha1, sha256 y sha512"
    echo "  $0 [directorio]       # Verifica checksums"
    exit 1
fi
