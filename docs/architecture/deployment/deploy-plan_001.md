# Configuração de Múltiplas Opções de Banco de Dados (MariaDB e PostgreSQL)

Este plano visa estruturar o ambiente **Docker2** para permitir que o usuário escolha facilmente qual banco de dados relacional deseja utilizar (**MariaDB 10 LTS** ou **PostgreSQL 16**), conforme especificado nos requisitos de [ambiente.md](/ambiente.md).

---

## User Review Required

> [!IMPORTANT]
> **Estratégia de Escolha do Banco de Dados:**
> Existem duas abordagens recomendadas no ecossistema Docker Compose. Ambas serão disponibilizadas de forma harmoniosa:
> 1. **Modular por Arquivos Compose (`-f`) com `.env` (Abordagem que você iniciou):**
>    - `docker compose -f docker-compose.yml -f docker-compose.mariadb.yml up -d`
>    - `docker compose -f docker-compose.yml -f docker-compose.postgres.yml up -d`
>    - Definindo `COMPOSE_FILE=docker-compose.yml:docker-compose.mariadb.yml` no arquivo `.env`, o comando padrão `docker compose up -d` já sobe a opção configurada sem precisar digitar flags extras.
> 2. **Docker Compose Profiles:**
>    - Também podemos adicionar perfis `profiles: ["mariadb"]` e `profiles: ["postgres"]`, permitindo `docker compose --profile postgres up -d`.

> [!WARNING]
> **Correções Críticas nos Arquivos Existentes:**
> - **PostgreSQL**: A imagem `postgres:18` não existe (versão atual é 16 ou 17); as variáveis oficiais são `POSTGRES_DB`, `POSTGRES_USER` e `POSTGRES_PASSWORD` (e não `POSTGRES_ROOT_PASSWORD` ou `POSTGRES_DATABASE`); a porta interna do Postgres é `5432` (mapeada para `5433` no host); o volume deve ser isolado (`postgres_data`) para não corromper dados do MariaDB; o healthcheck deve usar `pg_isready`.
> - **phpMyAdmin**: O phpMyAdmin funciona apenas com MySQL/MariaDB. Para PostgreSQL, configuraremos o **pgAdmin 4** (ou **Adminer**, que suporta ambos) associado ao arquivo do PostgreSQL.
> - **Aplicação Spring Boot (`app`)**: O `SPRING_DATASOURCE_URL` e o driver JDBC não podem ficar fixos para MariaDB no `docker-compose.yml`; utilizaremos variáveis ou sobrescrita no compose específico de cada banco.

---

## Decisões de Arquitetura Definidas

> [!NOTE]
> 1. **Interface Web para PostgreSQL**: Definido o **pgAdmin 4** na porta host **`5658`** (com alternativa comentada para o Adminer caso necessário).
> 2. **Porta Externa do PostgreSQL**: Definida a porta do host **`5433`** (mapeada para a `5432` interna do contêiner), garantindo isolamento contra serviços locais na 5432 padrão.

---

## Proposed Changes

### Orquestração Docker Compose

#### [MODIFY] [docker-compose.yml](/docker-compose.yml)
- Parametrizar as variáveis de conexão com o banco (`SPRING_DATASOURCE_URL`, `SPRING_DATASOURCE_USERNAME`, `SPRING_DATASOURCE_PASSWORD`) usando variáveis de ambiente com fallbacks.
- Mover a dependência e a definição do gerenciador web específico do MariaDB (`phpmyadmin`) para o arquivo correspondente `docker-compose.mariadb.yml`, mantendo o `docker-compose.yml` estritamente com os serviços compartilhados (`app`, `redis`, `rabbitmq`).
- Adicionar declaração dos volumes nomeados compartilhados.

#### [MODIFY] [docker-compose.mariadb.yml](/docker-compose.mariadb.yml)
- Corrigir indentação YAML.
- Padronizar o serviço de banco com o hostname `db` (ou alias `mariadb`).
- Incluir o serviço `phpmyadmin` vinculado ao MariaDB (porta host `5657`).
- Definir volume dedicado `mariadb_data`.
- Configurar as variáveis do Spring Boot para MariaDB (`SPRING_DATASOURCE_URL: jdbc:mariadb://db:3306/tgos_db`, `SPRING_DATASOURCE_DRIVER_CLASS_NAME: org.mariadb.jdbc.Driver`).

#### [MODIFY] [docker-compose.postgres.yml](/docker-compose.postgres.yml)
- Corrigir imagem para `postgres:16-alpine`.
- Corrigir variáveis de ambiente para `POSTGRES_DB`, `POSTGRES_USER`, `POSTGRES_PASSWORD`.
- Corrigir portas para `5433:5432`.
- Corrigir healthcheck para `test: ["CMD-SHELL", "pg_isready -U desenvolvedor -d tgos_db"]`.
- Adicionar volume dedicado `postgres_data`.
- Incluir gerenciador web para PostgreSQL (**pgAdmin 4** na porta host `5658` ou Adminer).
- Configurar as variáveis do Spring Boot para PostgreSQL (`SPRING_DATASOURCE_URL: jdbc:postgresql://db:5432/tgos_db`, `SPRING_DATASOURCE_DRIVER_CLASS_NAME: org.postgresql.Driver`).

---

### Configuração de Ambiente e Usabilidade

#### [NEW] [.env.example](/.env.example) e [.env](/.env)
- Arquivo de configuração que define o banco padrão selecionado através da variável `COMPOSE_FILE`:
  ```env
  # Descomente a opção desejada:
  # Opção 1: MariaDB (Padrão Recomendado)
  COMPOSE_FILE=docker-compose.yml:docker-compose.mariadb.yml

  # Opção 2: PostgreSQL
  # COMPOSE_FILE=docker-compose.yml:docker-compose.postgres.yml
  ```
- Permite alternar simplesmente alterando uma linha, sem precisar digitar comandos longos.

#### [NEW] [start.sh](/start.sh)
- Script interativo amigável em Shell script (`chmod +x start.sh`) que exibe um menu simples no terminal:
  ```text
  Escolha o banco de dados:
  1) MariaDB 10 LTS (Recomendado + phpMyAdmin)
  2) PostgreSQL 16 (Suportado + pgAdmin)
  ```
- Executa o comando compose correto automaticamente.

#### [MODIFY] [README.md](/README.md)
- Atualizar a documentação do projeto explicando como inicializar cada uma das opções de banco de dados.
- Documentar portas, URLs de acesso e credenciais de cada serviço (MariaDB + phpMyAdmin vs PostgreSQL + pgAdmin).

---

## Verification Plan

### Automated Tests
- Validar a sintaxe de todos os arquivos compose usando o comando:
  ```bash
  docker compose -f docker-compose.yml -f docker-compose.mariadb.yml config
  docker compose -f docker-compose.yml -f docker-compose.postgres.yml config
  ```
- Validar a resolução de variáveis e volumes.

### Manual Verification
- Iniciar os serviços de banco e gerenciador web para testar a subida e healthcheck:
  - Testar subida do MariaDB e conferir `healthy`.
  - Testar subida do PostgreSQL e conferir `healthy`.
- Conferir que não há conflitos de portas com o Docker 1 (PHP) ou portas padrão locais.
