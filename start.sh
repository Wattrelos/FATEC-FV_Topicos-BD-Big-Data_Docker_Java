#!/usr/bin/env bash
# ==============================================================================
# Script de Inicialização Rápida: Docker 2 (Java Spring Boot)
# Permite selecionar interativamente ou via argumento o banco de dados desejado.
# ==============================================================================

set -e
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
cd "$DIR"

ENV_FILE=".env"

# Se o .env não existir (clone recente), cria a partir de .env.example
if [ ! -f "$ENV_FILE" ] && [ -f ".env.example" ]; then
    cp .env.example "$ENV_FILE"
fi

load_env() {
    if [ -f "$ENV_FILE" ]; then
        set -a
        # shellcheck disable=SC1090
        . "$ENV_FILE"
        set +a
    fi
}

# Carrega variáveis de ambiente inicialmente
load_env

set_env_db() {
    local option="$1"
    if [ "$option" = "mariadb" ]; then
        sed -i 's|^COMPOSE_FILE=.*|COMPOSE_FILE=docker-compose.yml:docker-compose.mariadb.yml|' "$ENV_FILE" 2>/dev/null || true
    elif [ "$option" = "postgres" ]; then
        sed -i 's|^COMPOSE_FILE=.*|COMPOSE_FILE=docker-compose.yml:docker-compose.postgres.yml|' "$ENV_FILE" 2>/dev/null || true
    fi
    load_env
}

start_mariadb() {
    echo ""
    echo "🐬 Iniciando ambiente com MariaDB 10 LTS + phpMyAdmin..."
    set_env_db "mariadb"
    docker compose -f docker-compose.yml -f docker-compose.mariadb.yml up -d
    echo ""
    echo "✅ Ambiente iniciado com sucesso!"
    echo "👉 Aplicação Spring Boot: http://localhost:${APP_PORT:-8090}"
    echo "👉 phpMyAdmin (MariaDB):  http://localhost:${PMA_PORT:-5657} (user: ${DB_USER:-desenvolvedor} / pass: ${DB_PASSWORD})"
    echo "👉 Painel RabbitMQ:       http://localhost:${RABBITMQ_MANAGEMENT_PORT:-15673} (${RABBITMQ_USER:-guest} / ${RABBITMQ_PASS:-guest})"
    echo "👉 Cache Redis:           localhost:${REDIS_PORT:-6380}"
}

start_postgres() {
    echo ""
    echo "🐘 Iniciando ambiente com PostgreSQL 16 + pgAdmin 4..."
    set_env_db "postgres"
    docker compose -f docker-compose.yml -f docker-compose.postgres.yml up -d
    echo ""
    echo "✅ Ambiente iniciado com sucesso!"
    echo "👉 Aplicação Spring Boot: http://localhost:${APP_PORT:-8090}"
    echo "👉 pgAdmin 4 (Postgres):  http://localhost:${PGADMIN_PORT:-5658} (${PGADMIN_EMAIL:-admin@tgos.local} / ${PGADMIN_PASSWORD})"
    echo "👉 Conexão PostgreSQL:    localhost:${POSTGRES_PORT:-5433} (user: ${DB_USER:-desenvolvedor} / pass: ${DB_PASSWORD})"
    echo "👉 Painel RabbitMQ:       http://localhost:${RABBITMQ_MANAGEMENT_PORT:-15673} (${RABBITMQ_USER:-guest} / ${RABBITMQ_PASS:-guest})"
    echo "👉 Cache Redis:           localhost:${REDIS_PORT:-6380}"
}

stop_all() {
    echo ""
    echo "🛑 Parando contêineres do Docker 2..."
    docker compose -f docker-compose.yml -f docker-compose.mariadb.yml -f docker-compose.postgres.yml down
    echo "✅ Contêineres parados com sucesso."
}

show_status() {
    echo ""
    docker compose ps
}

# Tratamento de parâmetros de linha de comando
case "$1" in
    mariadb|maria)
        start_mariadb
        exit 0
        ;;
    postgres|pg)
        start_postgres
        exit 0
        ;;
    down|stop)
        stop_all
        exit 0
        ;;
    status|ps)
        show_status
        exit 0
        ;;
esac

# Menu Interativo
[ -t 0 ] && clear || true
echo "======================================================="
echo "   ☕ Docker 2 - Java Spring Boot: Seleção de Banco"
echo "======================================================="
echo "  1) MariaDB 10 LTS (Recomendado + phpMyAdmin)"
echo "  2) PostgreSQL 16 (Suportado + pgAdmin 4)"
echo "  3) Verificar status dos contêineres"
echo "  4) Parar todos os contêineres (down)"
echo "  0) Sair"
echo "======================================================="
read -rp "Selecione uma opção [1-4, 0]: " OPCAO

case "$OPCAO" in
    1)
        start_mariadb
        ;;
    2)
        start_postgres
        ;;
    3)
        show_status
        ;;
    4)
        stop_all
        ;;
    0)
        echo "Operação cancelada."
        exit 0
        ;;
    *)
        echo "Opção inválida."
        exit 1
        ;;
esac
