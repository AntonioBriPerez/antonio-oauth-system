# 🛡️ Antonio Auth System: Kubernetes Native Microservices

![DevOps](https://img.shields.io/badge/DevOps-Architecture-blue?style=for-the-badge&logo=kubernetes)
![Go](https://img.shields.io/badge/Auth_Service-Go-00ADD8?style=for-the-badge&logo=go)
![Python](https://img.shields.io/badge/Resource_API-Python-3776AB?style=for-the-badge&logo=python)
![Vue.js](https://img.shields.io/badge/Frontend-Vue.js-4FC08D?style=for-the-badge&logo=vue.js)

## 📋 Descripción del Proyecto

Este repositorio contiene una implementación completa de una **Arquitectura de Microservicios Segura** desplegada sobre Kubernetes.

El sistema simula un flujo de autenticación **OAuth2 (Client Credentials)** utilizando criptografía asimétrica (**RS256**). El objetivo es demostrar cómo desacoplar la emisión de tokens (Auth Server) de la validación de los mismos (Resource Server) en un entorno distribuido mediante el uso de un **Ingress Controller**.

### 🏗️ Arquitectura

El sistema se compone de 3 microservicios orquestados en K3s:

1.  **Identity Provider (Go):** Gestiona credenciales, conecta con **PostgreSQL**, y firma tokens JWT usando una clave privada RSA.
2.  **Resource API (Python FastAPI):** API protegida que valida la firma de los tokens usando la clave pública, sin necesidad de consultar la base de datos (Stateless Validation).
3.  **Frontend (Vue.js + Nginx):** SPA (Single Page Application) que interactúa con ambos servicios para demostrar el flujo End-to-End.

---

## 🚀 Quick Start (Despliegue en 1 Click)

El proyecto incluye un script de automatización (`start-all.sh`) que realiza todo el ciclo de vida DevOps: construcción de imágenes, inyección en K3s, corrección de permisos, despliegue de base de datos y configuración de reglas de enrutamiento (Ingress).

### Prerrequisitos
* Linux (Debian/Ubuntu recomendado)
* **K3s** instalado y corriendo (con Traefik habilitado por defecto).
* **Docker** y **Kubectl** instalados.

### Instalación

1.  **Configuración DNS Local (Vital):**
    Para que el Ingress funcione en local, añade las siguientes líneas a tu archivo `/etc/hosts` (o `C:\Windows\System32\drivers\etc\hosts` en Windows):
    ```text
    127.0.0.1  antonio.local auth.antonio.local api.antonio.local
    ```
    *(Nota: Si usas una VM, sustituye 127.0.0.1 por la IP de tu máquina virtual).*

2.  **Clonar el repositorio:**
    ```bash
    git clone [https://github.com/TU_USUARIO/antonio-auth-system.git](https://github.com/TU_USUARIO/antonio-auth-system.git)
    cd antonio-auth-system
    ```

3.  **Ejecutar el script maestro:**
    ```bash
    chmod +x start-all.sh
    ./start-all.sh
    ```

4.  **Acceder al sistema:**
    * Abre tu navegador en: **http://antonio.local**

---

## 🛠️ Stack Tecnológico

| Componente | Tecnología | Host (Ingress) | Descripción |
| :--- | :--- | :--- | :--- |
| **Auth Server** | Go (Golang) | `auth.antonio.local` | Emisor de tokens JWT (RS256). |
| **Database** | PostgreSQL | N/A (Interno) | Persistencia de usuarios y clientes. |
| **Resource API** | Python (FastAPI) | `api.antonio.local` | Datos protegidos, validación de firma. |
| **Frontend** | Vue.js 3 / Nginx | `antonio.local` | Interfaz de usuario reactiva. |
| **Infraestructura** | Kubernetes (K3s) | Traefik Ingress | Orquestación y enrutamiento L7. |
| **Scripting** | Bash | N/A | Automatización CI/CD local. |

---

## 🧪 Cómo probarlo manualmente

Si prefieres usar `curl` en lugar del Frontend, utiliza los dominios configurados:

**1. Obtener Token (Auth Server):**
```bash
curl -X POST [http://auth.antonio.local/token](http://auth.antonio.local/token) \
     -H "Content-Type: application/json" \
     -d '{
           "client_id": "mi-app-python",
           "client_secret": "secreto_super_seguro",
           "grant_type": "client_credentials"
         }'
```
**2. Consultar Datos (Resource API):**
```bash
curl -X GET [http://api.antonio.local/dashboard](http://api.antonio.local/dashboard) \
     -H "Authorization: Bearer <TU_TOKEN_AQUI>"
```
**📂 Estructura del Proyecto**
```text
antonio-auth-system/
├── start-all.sh        # ⚡ Script maestro de despliegue
├── ingress.yaml        # 🌐 Reglas de enrutamiento (Ingress)
├── keys/               # (Generado) Claves RSA pública/privada
├── oauth-server/       # Microservicio Go
│   ├── cmd/api/main.go
│   ├── k8s/            # Manifiestos K8s + Postgres
│   └── Dockerfile
├── dashboard-app/      # Microservicio Python
│   ├── main.py
│   └── Dockerfile
└── frontend-app/       # Microservicio Vue.js
    ├── index.html
    └── Dockerfile
```
**🔒 Seguridad**
Gestión de Secretos: Las claves privadas se inyectan como Kubernetes Secrets, nunca se queman en la imagen Docker.

CORS: Configurado explícitamente para permitir la comunicación entre los subdominios locales.

RSA-256: Uso de criptografía asimétrica estándar de la industria para la firma de tokens.