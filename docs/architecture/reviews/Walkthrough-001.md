# Walkthrough: Suporte a Múltiplos Bancos e Centralização de Credenciais no .env

Configuramos o ambiente **Docker2** para permitir alternar facilmente entre o banco recomendado (**MariaDB 10 LTS**) e o banco suportado (**PostgreSQL 16**), atendendo plenamente aos requisitos de [ambiente.md](file:///home/wattrelos/Docker2/ambiente.md), com todas as credenciais protegidas e centralizadas.

---

## 1. O que foi feito

### Centralização de Credenciais e Segurança
1. **[.env](file:///home/wattrelos/Docker2/.env)**:
   - Centraliza todas as credenciais do banco (`DB_NAME`, `DB_USER`, `DB_PASSWORD`, `DB_ROOT_PASSWORD`), gerenciadores web (`PGADMIN_EMAIL`, `PGADMIN_PASSWORD`, `PMA_UPLOAD_LIMIT`), filas RabbitMQ (`RABBITMQ_USER`, `RABBITMQ_PASS`) e portas do host (`APP_PORT`, `MARIADB_PORT`, `POSTGRES_PORT`, `PMA_PORT`, `PGADMIN_PORT`, `REDIS_PORT`, `RABBITMQ_AMQP_PORT`, `RABBITMQ_MANAGEMENT_PORT`).
   - A senha com caractere `#` foi devidamente protegida com aspas duplas.
   - Protegido no [`.gitignore`](file:///home/wattrelos/Docker2/.gitignore) para nunca vazar em repositórios remotos.

2. **[.env.example](file:///home/wattrelos/Docker2/.env.example)**:
   - Modelo completo e documentado versionado no Git para que novos desenvolvedores possam copiar (`cp .env.example .env`).

### Arquitetura Modular Docker Compose
3. **[docker-compose.yml](file:///home/wattrelos/Docker2/docker-compose.yml)**:
   - Mantém os serviços compartilhados (`app`, `redis`, `rabbitmq`).
   - Parametrizado com `${VAR:-default}` para portas e credenciais do RabbitMQ.
   - Padroniza a dependência de banco de dados no serviço abstrato `db` com `condition: service_healthy`.

4. **[docker-compose.mariadb.yml](file:///home/wattrelos/Docker2/docker-compose.mariadb.yml)**:
   - Configura o serviço `db` com imagem `mariadb:10.11` usando variáveis de ambiente.
   - Inclui o **phpMyAdmin** na porta `${PMA_PORT:-5657}`.
   - Mapeia o banco na porta host `${MARIADB_PORT:-3308}`.
   - Injeta no Spring Boot a URL `jdbc:mariadb://db:3306/${DB_NAME:-tgos_db}` e driver `org.mariadb.jdbc.Driver`.
   - Volume dedicado e isolado `mariadb_data`.

5. **[docker-compose.postgres.yml](file:///home/wattrelos/Docker2/docker-compose.postgres.yml)**:
   - Configura o serviço `db` com imagem `postgres:16-alpine` usando variáveis de ambiente.
   - Mapeia o banco na porta host `${POSTGRES_PORT:-5433}`.
   - Configura healthcheck nativo com `pg_isready`.
   - Inclui o **pgAdmin 4** na porta host `${PGADMIN_PORT:-5658}` com credenciais parametrizadas.
   - Injeta no Spring Boot a URL `jdbc:postgresql://db:5432/${DB_NAME:-tgos_db}` e driver `org.postgresql.Driver`.
   - Volume dedicado e isolado `postgres_data`.

6. **[start.sh](file:///home/wattrelos/Docker2/start.sh)**:
   - Criação automática do `.env` a partir do `.env.example` se o arquivo ainda não existir.
   - Script com menu interativo e opções via argumento CLI (`./start.sh mariadb`, `./start.sh postgres`, `./start.sh down`, `./start.sh status`).

7. **[README.md](file:///home/wattrelos/Docker2/README.md)**:
   - Documentação atualizada com seção sobre segurança e centralização de credenciais.

---

## 2. Validações Realizadas

- `docker compose -f docker-compose.yml -f docker-compose.mariadb.yml config -q`: **Sucesso (Código 0)**.
- `docker compose -f docker-compose.yml -f docker-compose.postgres.yml config -q`: **Sucesso (Código 0)**.
- Resolução de variáveis interpoladas com `.env`: **Sucesso**.
- Fallback seguro quando executado sem `.env`: **Sucesso**.
- Criação automática do `.env` no [`start.sh`](file:///home/wattrelos/Docker2/start.sh): **Sucesso**.
