#!/bin/bash

# Aplica la configuración de Kubernetes del proyecto database.
# Autónomo: no depende de ningún repo centralizado.

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VALUES_FILE="${SCRIPT_DIR}/values.yaml"
TEMPLATES_DIR="${SCRIPT_DIR}/templates"
OUTPUT_DIR="${SCRIPT_DIR}/output"

echo "=== Kubernetes - Proyecto database ==="

# Opcional: actualizar kubeconfig para un cluster EKS.
# Si se despliega en otro cluster (minikube, k3d, etc.), basta con tener
# el contexto de kubectl apuntando al cluster correcto.
CLUSTER_NAME="${CLUSTER_NAME:-}"
if [ -n "$CLUSTER_NAME" ] && command -v aws >/dev/null 2>&1; then
    REGION="${AWS_REGION:-us-east-1}"
    aws eks update-kubeconfig --region "$REGION" --name "$CLUSTER_NAME" \
        || echo "ADVERTENCIA: no se pudo actualizar kubeconfig; se usara el contexto actual de kubectl"
fi

# Verificar que exista values.yaml
if [ ! -f "$VALUES_FILE" ]; then
    echo "Error: No se encontro values.yaml"
    exit 1
fi

# Crear directorio de salida
mkdir -p "$OUTPUT_DIR"

# Cargar variables desde values.yaml
echo "1/3 Leyendo valores desde values.yaml..."

# Parseo literal key=value (NO usar "source": <AWSAccountId> seria
# interpretado por el shell como redireccion)
while IFS='=' read -r key value || [ -n "$key" ]; do
    key="${key//[[:space:]]/}"
    [ -z "$key" ] && continue
    [[ "$key" == \#* ]] && continue
    value="${value#"${value%%[![:space:]]*}"}"
    value="${value%"${value##*[![:space:]]}"}"
    [ -z "$value" ] && continue
    export "$key=$value"
done < "$VALUES_FILE"

echo "   Variables cargadas"

# Desacoplar la imagen de la cuenta: reemplazar "<account>.dkr.ecr.<region>"
# por la cuenta real (STS), SIN modificar values.yaml.
REGION="${AWS_REGION:-us-east-1}"
ACCOUNT_ID="$(aws sts get-caller-identity --query Account --output text 2>/dev/null || echo "")"
if [ -n "$ACCOUNT_ID" ]; then
    val="${DATABASE_IMAGE:-}"
    new="$(echo "$val" | sed -E "s#^[^/]+\.dkr\.ecr\.[a-z0-9-]+#${ACCOUNT_ID}.dkr.ecr.${REGION}#")"
    export DATABASE_IMAGE="$new"
    echo "   DATABASE_IMAGE = $new"
else
    echo "ADVERTENCIA: STS no respondio; se usa DATABASE_IMAGE tal cual esta en values.yaml"
fi

# Generar YAMLs desde templates
echo ""
echo "2/3 Generando manifiestos..."
for template in "$TEMPLATES_DIR"/*.yaml; do
    filename=$(basename "$template")
    cp "$template" "$OUTPUT_DIR/$filename"

    awk '{
        line = $0
        while (match(line, /\$\{[A-Z_0-9]+\}/)) {
            var = substr(line, RSTART + 2, RLENGTH - 3)
            value = ENVIRON[var]
            if (value != "") {
                line = substr(line, 1, RSTART - 1) value substr(line, RSTART + RLENGTH)
            } else {
                break
            }
        }
        print line
    }' "$OUTPUT_DIR/$filename" > "$OUTPUT_DIR/$filename.tmp"
    mv "$OUTPUT_DIR/$filename.tmp" "$OUTPUT_DIR/$filename"

    echo "   - $filename"
done

# Aplicar manifiestos en orden
echo ""
echo "3/3 Aplicando manifiestos a Kubernetes..."
kubectl apply -f "$OUTPUT_DIR/namespace.yaml"
kubectl apply -f "$OUTPUT_DIR/database-secret.yaml"
kubectl apply -f "$OUTPUT_DIR/database-deployment.yaml"
kubectl apply -f "$OUTPUT_DIR/database-service.yaml"

echo ""
echo "=== Despliegue database completado ==="
kubectl get all -n "$NAMESPACE"
