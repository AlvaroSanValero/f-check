#!/bin/bash

# f-check: Verificador avanzado de archivos y directorios de código y datos
# Uso:
#   sudo f-check -ndir archivo.ext   # Analiza archivo único
#   sudo f-check directorio/         # Analiza un directorio

declare -A hash_cmds=(
  [md5]="md5sum"
  [sha1]="sha1sum"
  [sha256]="sha256sum"
  [sha512]="sha512sum"
)

function analizar_archivo() {
    file="$1"
    if [[ ! -f "$file" ]]; then
        echo "❌ El archivo '$file' no existe."
        exit 1
    fi

    echo "📂 Archivo: $file"

    # Mostrar hashes
    echo "[🔐] Hashes:"
    for algo in "${!hash_cmds[@]}"; do
        echo "  $algo: $("${hash_cmds[$algo]}" "$file" | awk '{print $1}')"
    done

    # Analizar sintaxis si es código fuente
    ext="${file##*.}"
    echo "[🔍] Análisis de código ($ext):"
    case "$ext" in
        py)
            python3 -m py_compile "$file" && echo "  ✅ Python OK" || echo "  ❌ Error en Python"
            ;;
        c)
            gcc -fsyntax-only "$file" &>/dev/null && echo "  ✅ C OK" || echo "  ❌ Error en C"
            ;;
        cpp)
            g++ -fsyntax-only "$file" &>/dev/null && echo "  ✅ C++ OK" || echo "  ❌ Error en C++"
            ;;
        java)
            javac "$file" &>/dev/null && echo "  ✅ Java OK" || echo "  ❌ Error en Java"
            ;;
        sh)
            bash -n "$file" && echo "  ✅ Bash OK" || echo "  ❌ Error en Bash"
            ;;
        *)
            echo "  ℹ️ Archivo no es código fuente reconocido."
            ;;
    esac

    # Validar JSON/YAML/HTML
    echo "[🧩] Validación de formato:"
    case "$ext" in
        json)
            python3 -m json.tool "$file" > /dev/null && echo "  ✅ JSON válido" || echo "  ❌ JSON inválido"
            ;;
        yaml|yml)
            if python3 -c "import yaml" &>/dev/null; then
                python3 -c "import yaml, sys; yaml.safe_load(sys.stdin)" < "$file" && echo "  ✅ YAML válido" || echo "  ❌ YAML inválido"
            else
                echo "  ⚠️ PyYAML no instalado"
            fi
            ;;
        html)
            if command -v tidy &>/dev/null; then
                tidy -q -e "$file" &>/dev/null && echo "  ✅ HTML válido" || echo "  ⚠️ HTML con advertencias"
            else
                echo "  ⚠️ tidy no instalado"
            fi
            ;;
        *)
            echo "  ℹ️ No es archivo de datos web reconocido"
            ;;
    esac

    # Verificar comentarios/documentación
    echo "[📋] Comentarios:"
    grep -Ei "autor|author|descripción|description" "$file" > /dev/null \
        && echo "  ✅ Comentario encontrado" \
        || echo "  ⚠️ No se encontraron comentarios tipo cabecera"

    echo "[✔️] Análisis completo del archivo '$file'"
}

function analizar_directorio() {
    dir="$1"
    if [[ ! -d "$dir" ]]; then
        echo "❌ El directorio '$dir' no existe."
        exit 1
    fi

    verificar_hashes "$dir"
    verificar_codigo_fuente "$dir"
    ejecutar_pruebas "$dir"
    verificar_comentarios "$dir"
    verificar_datos_web "$dir"
    limpiar_basura "$dir"
}

# Añadir aquí las funciones ya definidas como verificar_hashes, etc.
# (omitidas para no duplicar, pero las tomamos del script anterior)

# MAIN
if [[ "$1" == "-ndir" && -n "$2" ]]; then
    analizar_archivo "$2"
elif [[ -n "$1" ]]; then
    analizar_directorio "$1"
else
    echo "Uso:"
    echo "  sudo f-check -ndir archivo.ext     # Analiza archivo único"
    echo "  sudo f-check directorio/           # Analiza un proyecto completo"
    exit 1
fi
