Que hace el script: 

Comprueba salud de archivos

- Guarda el script como f-check en una carpeta:
nano f-check

- Dale permisos de ejecución:
  chmod +x f-check

- Muévelo a /usr/local/bin:
  sudo mv f-check /usr/local/bin/

- Así se ejecuta
sudo f-check -ndir archivo.py
sudo f-check mi_proyecto/
