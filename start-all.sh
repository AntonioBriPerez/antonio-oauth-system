#!/bin/bash

# Colores
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${GREEN}========================================================${NC}"
echo -e "${GREEN}🚀 INICIANDO DESPLIEGUE: ANTONIO AUTH SYSTEM (FULL STACK)${NC}"
echo -e "${GREEN}========================================================${NC}"

# ---------------------------------------------------------
# 0. PREPARACIÓN PREVIA (FIX PERMISOS K3S)
# ---------------------------------------------------------
echo -e "\n${YELLOW}🔧 [0/7] Arreglando permisos de Kubernetes...${NC}"
# Esto soluciona el error "permission denied" en k3s.yaml de raíz
sudo chmod 644 /etc/rancher/k3s/k3s.yaml
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
echo "✅ Permisos corregidos y variable de entorno cargada."

# ---------------------------------------------------------
# 1. LIMPIEZA
# ---------------------------------------------------------
echo -e "\n${YELLOW}🧹 [1/7] Limpiando entorno anterior...${NC}"
# Matamos túneles viejos
pkill -f "kubectl port-forward" 2>/dev/null

kubectl delete deploy --all 2>/dev/null
kubectl delete svc --all 2>/dev/null
kubectl delete statefulset --all 2>/dev/null
kubectl delete secret oauth-keys 2>/dev/null
echo "✅ Entorno limpio."

# ---------------------------------------------------------
# 2. SEGURIDAD
# ---------------------------------------------------------
echo -e "\n${YELLOW}🔑 [2/7] Generando claves criptográficas...${NC}"
mkdir -p keys
# Generar clave
docker run --rm -v "$(pwd)/keys:/keys" -w /keys alpine/openssl \
  genrsa -out private.pem 2048 2>/dev/null

# Fix permisos clave privada
echo "🔓 Aplicando permisos 777 a la clave privada..."
sudo chmod 777 keys/private.pem

# Crear secreto
kubectl create secret generic oauth-keys --from-file=private.pem=./keys/private.pem
echo "✅ Secreto creado."

# ---------------------------------------------------------
# 3. BASE DE DATOS
# ---------------------------------------------------------
echo -e "\n${YELLOW}🐘 [3/7] Desplegando Base de Datos...${NC}"
kubectl apply -f oauth-server/k8s/postgres/postgres.yaml

echo "⏳ Esperando a que Postgres arranque..."
kubectl rollout status statefulset/auth-db --timeout=90s > /dev/null

echo "📥 Inyectando datos iniciales..."
sleep 5
kubectl cp oauth-server/k8s/postgres/init.sql auth-db-0:/tmp/init.sql
kubectl exec -it auth-db-0 -- psql -U admin -d oauth_db -f /tmp/init.sql
echo "✅ Base de datos lista."

# ---------------------------------------------------------
# 4. AUTH SERVER (Go)
# ---------------------------------------------------------
echo -e "\n${YELLOW}🐹 [4/7] Desplegando OAuth Server (Go)...${NC}"
cd oauth-server
docker build -t oauth-server:latest . > /dev/null 2>&1
docker save oauth-server:latest | sudo k3s ctr images import - > /dev/null
kubectl apply -f k8s/app.yaml
cd ..

# ---------------------------------------------------------
# 5. DASHBOARD APP (Python)
# ---------------------------------------------------------
echo -e "\n${YELLOW}🐍 [5/7] Desplegando Dashboard App (Python)...${NC}"
cd dashboard-app
docker build -t dashboard-api:v1 . > /dev/null 2>&1
docker save dashboard-api:v1 | sudo k3s ctr images import - > /dev/null
kubectl apply -f *.yaml
cd ..

# ---------------------------------------------------------
# 6. FRONTEND (Vue)
# ---------------------------------------------------------
echo -e "\n${YELLOW}🎨 [6/7] Desplegando Frontend (Vue.js)...${NC}"
cd frontend-app
docker build -t frontend-app:v1 . > /dev/null 2>&1
docker save frontend-app:v1 | sudo k3s ctr images import - > /dev/null
kubectl apply -f deploy.yaml
cd ..

# ---------------------------------------------------------
# 7. TÚNELES (PORT-FORWARDING)
# ---------------------------------------------------------
echo -e "\n${YELLOW}🔌 [7/7] Estableciendo Túneles en Segundo Plano...${NC}"
sleep 3

echo "   -> Abriendo puerto 4000 (Frontend)..."
kubectl port-forward svc/frontend-service 4000:80 > /dev/null 2>&1 &

echo "   -> Abriendo puerto 8080 (OAuth)..."
kubectl port-forward svc/oauth-service 8080:80 > /dev/null 2>&1 &

echo "   -> Abriendo puerto 3000 (Dashboard)..."
kubectl port-forward svc/dashboard-service 3000:80 > /dev/null 2>&1 &

# ---------------------------------------------------------
# FIN
# ---------------------------------------------------------
echo -e "\n${GREEN}========================================================${NC}"
echo -e "${GREEN}✅ ¡SISTEMA TOTALMENTE OPERATIVO!${NC}"
echo -e "${GREEN}========================================================${NC}"
echo -e "👉 Accede ya mismo: http://localhost:4000"