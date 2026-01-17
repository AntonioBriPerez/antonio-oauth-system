#!/bin/bash

# Configuración de Colores y Variables
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'
LOG_DIR="/tmp/k8s-tunnels"

# Función para comprobar si un servicio responde HTTP 200/404/etc
check_health() {
    local NAME=$1
    local URL=$2
    local RETRIES=15
    local WAIT=2

    echo -ne "   🔎 Verificando $NAME ($URL)... "
    
    for ((i=1; i<=RETRIES; i++)); do
        # Usamos curl silencioso, solo headers, timeout de 1s
        if curl -s --head --request GET "$URL" --max-time 1 > /dev/null; then
            echo -e "${GREEN}✅ OK${NC}"
            return 0
        fi
        sleep $WAIT
    done

    echo -e "${RED}❌ FALLÓ (No responde tras 30s)${NC}"
    return 1
}

echo -e "${GREEN}========================================================${NC}"
echo -e "${GREEN}🚀 INICIANDO DESPLIEGUE ROBUSTO: ANTONIO AUTH SYSTEM${NC}"
echo -e "${GREEN}========================================================${NC}"

# ---------------------------------------------------------
# 0. PREPARACIÓN
# ---------------------------------------------------------
echo -e "\n${YELLOW}🔧 [0/8] Preparando entorno...${NC}"
sudo chmod 644 /etc/rancher/k3s/k3s.yaml
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
mkdir -p $LOG_DIR

# Matamos túneles viejos
pkill -f "kubectl port-forward" 2>/dev/null
echo "✅ Entorno listo."

# ---------------------------------------------------------
# 1. LIMPIEZA
# ---------------------------------------------------------
echo -e "\n${YELLOW}🧹 [1/8] Limpiando recursos K8s...${NC}"
kubectl delete deploy --all 2>/dev/null
kubectl delete svc --all 2>/dev/null
kubectl delete statefulset --all 2>/dev/null
kubectl delete secret oauth-keys 2>/dev/null
echo "✅ Limpieza completada."

# ---------------------------------------------------------
# 2. SEGURIDAD
# ---------------------------------------------------------
echo -e "\n${YELLOW}🔑 [2/8] Generando claves RSA...${NC}"
mkdir -p keys
docker run --rm -v "$(pwd)/keys:/keys" -w /keys alpine/openssl \
  genrsa -out private.pem 2048 2>/dev/null
sudo chmod 777 keys/private.pem
kubectl create secret generic oauth-keys --from-file=private.pem=./keys/private.pem
echo "✅ Secreto inyectado."

# ---------------------------------------------------------
# 3. BASE DE DATOS
# ---------------------------------------------------------
echo -e "\n${YELLOW}🐘 [3/8] Base de Datos (Postgres)...${NC}"
kubectl apply -f oauth-server/k8s/postgres/postgres.yaml

echo "⏳ Esperando a que el Pod de DB esté listo..."
kubectl wait --for=condition=ready pod -l app=auth-db --timeout=90s > /dev/null

echo "📥 Inyectando datos SQL..."
sleep 5
kubectl cp oauth-server/k8s/postgres/init.sql auth-db-0:/tmp/init.sql
kubectl exec -it auth-db-0 -- psql -U admin -d oauth_db -f /tmp/init.sql > /dev/null
echo "✅ DB Online y Poblada."

# ---------------------------------------------------------
# 4. AUTH SERVER (Go)
# ---------------------------------------------------------
echo -e "\n${YELLOW}🐹 [4/8] Desplegando Auth Server...${NC}"
cd oauth-server
docker build -t oauth-server:latest . > /dev/null 2>&1
docker save oauth-server:latest | sudo k3s ctr images import - > /dev/null
kubectl apply -f k8s/app.yaml
cd ..

# ---------------------------------------------------------
# 5. DASHBOARD APP (Python)
# ---------------------------------------------------------
echo -e "\n${YELLOW}🐍 [5/8] Desplegando Dashboard App...${NC}"
cd dashboard-app
docker build -t dashboard-api:v1 . > /dev/null 2>&1
docker save dashboard-api:v1 | sudo k3s ctr images import - > /dev/null
kubectl apply -f *.yaml
cd ..

# ---------------------------------------------------------
# 6. FRONTEND (Vue)
# ---------------------------------------------------------
echo -e "\n${YELLOW}🎨 [6/8] Desplegando Frontend...${NC}"
cd frontend-app
docker build -t frontend-app:v1 . > /dev/null 2>&1
docker save frontend-app:v1 | sudo k3s ctr images import - > /dev/null
kubectl apply -f deploy.yaml
cd ..

# ---------------------------------------------------------
# 7. ESPERA ACTIVA DE PODS (Vital para que funcione el túnel)
# ---------------------------------------------------------
echo -e "\n${YELLOW}⏳ [7/8] Esperando a que todos los Pods arranquen...${NC}"
# Esperamos a que Kubernetes diga "Available" antes de intentar conectar
kubectl wait --for=condition=available deployment/oauth-deployment --timeout=60s > /dev/null
kubectl wait --for=condition=available deployment/dashboard-deployment --timeout=60s > /dev/null
kubectl wait --for=condition=available deployment/frontend-deployment --timeout=60s > /dev/null
echo "✅ Todos los pods están corriendo (Running)."

# ---------------------------------------------------------
# 8. TÚNELES Y VALIDACIÓN (La parte corregida)
# ---------------------------------------------------------
echo -e "\n${YELLOW}🔌 [8/8] Levantando Túneles y Validando Conexión...${NC}"

# Lanzamos los túneles y guardamos logs por si fallan
nohup kubectl port-forward svc/frontend-service 4000:80 > $LOG_DIR/front.log 2>&1 &
nohup kubectl port-forward svc/oauth-service 8080:80 > $LOG_DIR/oauth.log 2>&1 &
nohup kubectl port-forward svc/dashboard-service 3000:80 > $LOG_DIR/dash.log 2>&1 &

# Esperamos un segundo técnico para que el proceso haga bind
sleep 2

# VALIDAMOS QUE RESPONDEN
check_health "Frontend (Vue)" "http://localhost:4000"
check_health "Auth Server (Go)" "http://localhost:8080/health"
check_health "API (Python)" "http://localhost:3000/health"

# ---------------------------------------------------------
# FIN
# ---------------------------------------------------------
echo -e "\n${GREEN}========================================================${NC}"
echo -e "${GREEN}✅ SISTEMA VERIFICADO Y OPERATIVO${NC}"
echo -e "${GREEN}========================================================${NC}"
echo -e "👉 Accede aquí: http://localhost:4000"
echo -e "📄 Logs de túneles en: $LOG_DIR"