#!/bin/bash

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}🚀 DESPLIEGUE ANTONIO AUTH SYSTEM (MODO INGRESS)${NC}"

# 0. PREPARACIÓN
echo -e "\n${YELLOW}🔧 [0/5] Preparando entorno...${NC}"
sudo chmod 644 /etc/rancher/k3s/k3s.yaml
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
# ¡Matamos túneles viejos porque ya no los queremos!
pkill -f "kubectl port-forward" 2>/dev/null

# 1. LIMPIEZA
echo -e "\n${YELLOW}🧹 [1/5] Limpiando...${NC}"
kubectl delete deploy --all 2>/dev/null
kubectl delete svc --all 2>/dev/null
kubectl delete ingress --all 2>/dev/null # <-- Borramos ingress viejos
kubectl delete secret oauth-keys 2>/dev/null

# 2. SEGURIDAD & DB
echo -e "\n${YELLOW}🔑 [2/5] Seguridad y Datos...${NC}"
mkdir -p keys
docker run --rm -v "$(pwd)/keys:/keys" -w /keys alpine/openssl genrsa -out private.pem 2048 2>/dev/null
sudo chmod 777 keys/private.pem
kubectl create secret generic oauth-keys --from-file=private.pem=./keys/private.pem

kubectl apply -f oauth-server/k8s/postgres/postgres.yaml
echo "⏳ Esperando DB..."
kubectl wait --for=condition=ready pod -l app=auth-db --timeout=90s > /dev/null
sleep 2
kubectl cp oauth-server/k8s/postgres/init.sql auth-db-0:/tmp/init.sql
kubectl exec auth-db-0 -- psql -U admin -d oauth_db -f /tmp/init.sql > /dev/null

# 3. CONSTRUCCIÓN Y DESPLIEGUE DE APPS
echo -e "\n${YELLOW}🏗️ [3/5] Construyendo y Desplegando Microservicios...${NC}"

# Auth (Go)
cd oauth-server
docker build -t oauth-server:latest . > /dev/null 2>&1
docker save oauth-server:latest | sudo k3s ctr images import - > /dev/null
kubectl apply -f k8s/app.yaml
cd ..

# Dashboard (Python)
cd dashboard-app
docker build -t dashboard-api:v1 . > /dev/null 2>&1
docker save dashboard-api:v1 | sudo k3s ctr images import - > /dev/null
kubectl apply -f *.yaml
cd ..

# Frontend (Vue) - IMPORTANTE: Reconstruir para coger el cambio de URLs
cd frontend-app
docker build -t frontend-app:v1 . > /dev/null 2>&1
docker save frontend-app:v1 | sudo k3s ctr images import - > /dev/null
kubectl apply -f deploy.yaml
cd ..

# 4. INGRESS (LA MAGIA)
echo -e "\n${YELLOW}🌐 [4/5] Configurando Ingress Controller...${NC}"
kubectl apply -f ingress.yaml

# 5. VERIFICACIÓN FINAL
echo -e "\n${YELLOW}⏳ [5/5] Esperando a que todo arranque...${NC}"
kubectl wait --for=condition=available deployment/frontend-deployment --timeout=60s > /dev/null

echo -e "\n${GREEN}==============================================${NC}"
echo -e "${GREEN}✅ SISTEMA LISTO (SIN TÚNELES)${NC}"
echo -e "${GREEN}==============================================${NC}"
echo -e "Asegúrate de tener esto en tu /etc/hosts:"
echo -e "   127.0.0.1  antonio.local auth.antonio.local api.antonio.local"
echo -e "\n👉 Entra aquí: http://antonio.local"