#!/bin/bash

# f-check: Verifica integridad, estructura de código, pruebas unitarias y comentarios
# Requiere: gcc, g++, python3, javac, make (opcional), unittest (Python)
# Uso:
#   ./f-check -g [directorio]     # Genera hashes
#   ./f-check [directorio]        # Verifica todo

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

function ejecutar_pruebas() {
    dir="$1"
    echo "[🧪] Ejecutando pruebas unitarias..."

    # Python
    py_tests=$(find "$dir" -name "test_*.py")
    if [[ -n "$py_tests" ]]; then
        for f in $py_tests; do
            echo "  → Python: Ejecutando $f..."
            python3 "$f" && echo "    ✅ Test OK" || echo "    ❌ Test FALLÓ"
        done
    fi

    # C/C++
    if [[ -f "$dir/Makefile" ]]; then
        echo "  → C/C++: Se detectó Makefile. Ejecutando 'make test' si existe..."
        make -C "$dir" test && echo "    ✅ make test OK" || echo "    ❌ make test FALLÓ"
    else
        for cfile in $(find "$dir" -name "*_test.c"); do
            exe="${cfile%.c}.out"
            echo "  → C Test: Compilando $cfile..."
            gcc "$cfile" -o "$exe" && ./"$exe" && echo "    ✅ C test OK" || echo "    ❌ C test FALLÓ"
        done
    fi

    # Java
    for jfile in $(find "$dir" -name "*Test.java"); do
        echo "  → Java Test: Compilando y ejecutando $jfile..."
        javac "$jfile" && java "${jfile%.java}" && echo "    ✅ Java Test OK" || echo "    ❌ Java Test FALLÓ"
    done

    echo "[✓] Pruebas unitarias finalizadas."
}

function verificar_comentarios() {
    dir="$1"
    echo "[📋] Verificando presencia de comentarios/documentación..."

    while IFS= read -r -d '' file; do
        echo "  → Revisando '$file'..."
        head -n 10 "$file" | grep -E "autor|author|description|descripción" -i > /dev/null
        if [[ $? -eq 0 ]]; then
            echo "    ✅ Comentario mínimo presente."
        else
            echo "    ⚠️ No se encontró cabecera de autor/descripción."
        fi
    done < <(find "$dir" -type f \( -name "*.py" -o -name "*.c" -o -name "*.cpp" -o -name "*.java" \) -print0)

    echo "[✓] Verificación de comentarios finalizada."
}

function limpiar_basura() {
    dir="$1"
    echo "[🧹] Buscando archivos potencialmente innecesarios..."
    find "$dir" -type f \( -name "*.o" -o -name "*.class" -o -name "*.out" -o -name "*~" \) -print |
    while read -r f; do
        echo "  ⚠️ Archivo generado: $f"
    done
}

# MAIN
if [[ "$1" == "-g" && -n "$2" ]]; then
    generar_sumas "$2"
elif [[ -n "$1" ]]; then
    verificar_hashes "$1"
    verificar_codigo_fuente "$1"
    ejecutar_pruebas "$1"
    verificar_comentarios "$1"
    limpiar_basura "$1"
else
    echo "Uso:"
    echo "  $0 -g [directorio]     # Genera checksums"
    echo "  $0 [directorio]        # Verifica hashes, código, pruebas y más"
    exit 1
fi
