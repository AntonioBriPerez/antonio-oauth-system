#!/bin/bash
echo "🚀 INICIANDO DESPLIEGUE COMPLETO (ANTONIO AUTH SYSTEM)"

# 1. Build & Deploy OAuth (Go)
echo "🔒 Desplegando Auth Server..."
cd oauth-server
docker build -t oauth-server:latest .
docker save oauth-server:latest | sudo k3s ctr images import -
kubectl apply -f k8s/postgres/postgres.yaml
# Esperamos un poco a la DB
sleep 5
kubectl apply -f k8s/app.yaml
cd ..

# 2. Build & Deploy Dashboard (Python)
echo "🛡️ Desplegando Dashboard API..."
cd dashboard-api
docker build -t dashboard-api:v1 .
docker save dashboard-api:v1 | sudo k3s ctr images import -
kubectl apply -f k8s-deploy.yaml
cd ..

# 3. Build & Deploy Frontend (Nginx)
echo "🎨 Desplegando Frontend..."
cd frontend-app
docker build -t frontend-app:v1 .
docker save frontend-app:v1 | sudo k3s ctr images import -
kubectl apply -f deploy.yaml
cd ..

echo "✅ Todo desplegado."
echo "👉 Para acceder, abre los túneles en terminales separadas:"
echo "   kubectl port-forward svc/frontend-service 4000:80"
echo "   kubectl port-forward svc/oauth-service 8080:80"
echo "   kubectl port-forward svc/dashboard-service 3000:80"