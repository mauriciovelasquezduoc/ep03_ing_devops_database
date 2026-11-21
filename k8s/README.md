# Kubernetes - Proyecto database

Configuración autónoma para desplegar PostgreSQL en Kubernetes. Este proyecto se instala de forma independiente, sin depender de un repo centralizado.

## Estructura

```
k8s/
├── values.yaml                  # Configuración del proyecto
├── templates/
│   ├── namespace.yaml           # Namespace compartido
│   ├── database-secret.yaml     # Credenciales (POSTGRES_PASSWORD)
│   ├── database-deployment.yaml # PostgreSQL con health checks TCP
│   └── database-service.yaml    # ClusterIP ${NAMESPACE}-database:5432
├── output/                      # YAMLs generados (gitignore)
├── generate.sh                  # Solo genera los YAMLs
└── apply.sh                     # Genera y aplica
```

## Instalación

```bash
cd k8s
./apply.sh
```

Opcionalmente, si el cluster es EKS y quieres actualizar el kubeconfig desde este repo:

```bash
CLUSTER_NAME=laboratorio-ep03-eks ./apply.sh
```

## Previsualizar sin aplicar

```bash
./generate.sh
```

## Configuración

Edita `values.yaml`:

```bash
NAMESPACE=ep03                                  # debe coincidir con backend y frontend
DATABASE_IMAGE=<AWSAccountId>.dkr.ecr.us-east-1.amazonaws.com/ep03-database:latest
DATABASE_NAME=ep03
DATABASE_USER=ep03_user
DATABASE_PASSWORD_B64=YWx1bW5vc19wYXNz          # password en base64
DATABASE_PORT=5432
DATABASE_REPLICAS=1
```

La cuenta AWS de la imagen no se hardcodea: `apply.sh` la resuelve en runtime con `aws sts get-caller-identity`.

## Orden de instalación del sistema completo

Este proyecto va **primero**: crea el namespace, el Secret `database-secret` y el Service `${NAMESPACE}-database` que el backend consume.

1. `ep03_ing_devops_database` (este proyecto)
2. `ep03_ing_devops_backend`
3. `ep03_ing_devops_frontend`

## Acoplamientos con otros proyectos

| Valor | Quién lo consume |
|---|---|
| `NAMESPACE` | backend y frontend (debe coincidir) |
| Service `${NAMESPACE}-database` | backend (via `DB_URL`) |
| Secret `database-secret` | backend (via `DB_PASSWORD`) |
| `DATABASE_NAME`, `DATABASE_USER`, `DATABASE_PORT` | backend (`values.yaml` del backend debe coincidir) |

## Verificación

```bash
kubectl get all -n ep03
kubectl get secret database-secret -n ep03
```
