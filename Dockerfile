FROM postgres:16-alpine

# Variables de entorno para PostgreSQL
ENV POSTGRES_DB=ep03
ENV POSTGRES_USER=ep03_user
ENV POSTGRES_PASSWORD=ep03_pass

# Parcheo de seguridad de los paquetes del sistema base (apk upgrade corrige
# los CVEs HIGH/CRITICAL con fix disponible; ej: CVE-2026-86144 en libxml2).
# Trivy exige 0 HIGH/CRITICAL en la imagen (exit-code: 1 en calidad-codigo.yml).
RUN apk --no-cache upgrade

# Script de inicialización — se ejecuta automáticamente al primer arranque
COPY init.sql /docker-entrypoint-initdb.d/01-init.sql

EXPOSE 5432
