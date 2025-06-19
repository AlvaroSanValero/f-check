Que hace el script: 
Guardará una lista de archivos esperados con sus sha256 en un archivo de suma (como checksums.sha256).

Comprobará que los archivos estén en el directorio.

Validará su integridad comparando las sumas actuales con las originales.

Mostrará un resumen con los resultados.

Para ejecutarlo:

1. chmod +x f-check
2. ./f-check -g carpeta/
3. Transfiere la carpeta a otra máquina.
4. Después de transferir, verifica en la máquina destino:./f-check carpeta/ esto imprimirá o un OK o FAILED

Ahora se calculan varios tipos de sumas de verificación: md5, sha1, sha256 y sha512
