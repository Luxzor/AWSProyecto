#!/bin/bash
# =============================================================
# Script de instalación para Amazon Linux 2023 (t2.micro/nano)
# Ejecutar como: bash setup.sh
#
# Flujo:
#   Flask corre en puerto 8080
#   Nginx escucha en puerto 80 y redirige a 8080
#   El autotest conecta a http://<ip>/ (puerto 80)
# =============================================================

set -e

echo ">>> Actualizando paquetes..."
sudo yum update -y

echo ">>> Instalando Python 3, pip y Nginx..."
sudo yum install -y python3 python3-pip nginx

echo ">>> Instalando dependencias de Python..."
pip3 install -r requirements.txt

# ------------------------------------------------------------------
# Configuración de Nginx como proxy inverso
# ------------------------------------------------------------------
echo ">>> Configurando Nginx..."
sudo tee /etc/nginx/conf.d/sicei.conf > /dev/null <<'NGINX'
server {
    listen 80;
    server_name _;

    location / {
        proxy_pass         http://127.0.0.1:8080;
        proxy_http_version 1.1;
        proxy_set_header   Host $host;
        proxy_set_header   X-Real-IP $remote_addr;
        proxy_set_header   X-Forwarded-For $proxy_add_x_forwarded_for;
    }
}
NGINX

# Desactivar el bloque default de Nginx que también usa el puerto 80
sudo sed -i 's/^[[:space:]]*listen[[:space:]]*80[[:space:]]*default_server/# &/' /etc/nginx/nginx.conf
sudo sed -i 's/^[[:space:]]*listen[[:space:]]*\[::\]:80[[:space:]]*default_server/# &/' /etc/nginx/nginx.conf

echo ">>> Iniciando y habilitando Nginx..."
sudo systemctl enable nginx
sudo systemctl restart nginx

# ------------------------------------------------------------------
# Matar cualquier instancia anterior de la app y volver a lanzar
# ------------------------------------------------------------------
echo ">>> Deteniendo instancia anterior de la app (si existe)..."
pkill -f "python3 app.py" || true

echo ">>> Iniciando la aplicación Flask en puerto 8080..."
nohup python3 app.py > app.log 2>&1 &

sleep 2

echo ""
echo "=============================================="
echo "  Flask corriendo en:  http://localhost:8080"
echo "  Nginx escuchando en: http://0.0.0.0:80"
echo ""
echo "  Prueba local:"
echo "    curl http://localhost/alumnos"
echo ""
echo "  Desde el autotest (ya configurado):"
echo "    http://ec2-34-201-141-2.compute-1.amazonaws.com/"
echo ""
echo "  IMPORTANTE: Verifica en el Security Group de AWS"
echo "  que el puerto 80 (HTTP) esté abierto para 0.0.0.0/0"
echo "=============================================="
