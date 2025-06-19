#!/bin/bash

# f-check: Verifica integridad de archivos usando SHA256
# Uso:
#   ./f-check -g [directorio]     -> Genera archivo checksums.sha256
#   ./f-check [directorio]       -> Verifica integridad de archivos

checksum_file="checksums.sha256"

function generar_sumas() {
    dir="$1"
    echo "[+] Generando sumas SHA256 en '$dir'..."
    find "$dir" -type f ! -name "$checksum_file" -exec sha256sum "{}" \; > "$dir/$checksum_file"
    echo "[✓] Sumas guardadas en $checksum_file"
}

function verificar_archivos() {
    dir="$1"
    if [[ ! -f "$dir/$checksum_file" ]]; then
        echo "[!] Archivo de sumas no encontrado: $dir/$checksum_file"
        exit 1
    fi
    echo "[+] Verificando archivos en '$dir'..."
    cd "$dir" || exit 1
    sha256sum -c "$checksum_file"
}

# Main
if [[ "$1" == "-g" && -n "$2" ]]; then
    generar_sumas "$2"
elif [[ -n "$1" ]]; then
    verificar_archivos "$1"
else
    echo "Uso:"
    echo "  $0 -g [directorio]   # Genera checksums.sha256"
    echo "  $0 [directorio]      # Verifica archivos con checksums.sha256"
    exit 1
fi
#!/bin/bash

# f-check: Verifica integridad de archivos usando SHA256
# Uso:
#   ./f-check -g [directorio]     -> Genera archivo checksums.sha256
#   ./f-check [directorio]       -> Verifica integridad de archivos

checksum_file="checksums.sha256"

function generar_sumas() {
    dir="$1"
    echo "[+] Generando sumas SHA256 en '$dir'..."
    find "$dir" -type f ! -name "$checksum_file" -exec sha256sum "{}" \; > "$dir/$checksum_file"
    echo "[✓] Sumas guardadas en $checksum_file"
}

function verificar_archivos() {
    dir="$1"
    if [[ ! -f "$dir/$checksum_file" ]]; then
        echo "[!] Archivo de sumas no encontrado: $dir/$checksum_file"
        exit 1
    fi
    echo "[+] Verificando archivos en '$dir'..."
    cd "$dir" || exit 1
    sha256sum -c "$checksum_file"
}

# Main
if [[ "$1" == "-g" && -n "$2" ]]; then
    generar_sumas "$2"
elif [[ -n "$1" ]]; then
    verificar_archivos "$1"
else
    echo "Uso:"
    echo "  $0 -g [directorio]   # Genera checksums.sha256"
    echo "  $0 [directorio]      # Verifica archivos con checksums.sha256"
    exit 1
fi
