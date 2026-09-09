# Walkthrough: Suporte a Múltiplos Bancos de Dados (MariaDB e PostgreSQL)

Configuramos o ambiente **Docker2** para permitir alternar facilmente entre o banco recomendado (**MariaDB 10 LTS**) e o banco suportado (**PostgreSQL 16**), atendendo plenamente aos requisitos de [ambiente.md](/ambiente.md).

---

## 1. O que foi feito

### Arquitetura Modular Docker Compose
1. **[docker-compose.yml](/docker-compose.yml)**:
   - Mantém os serviços compartilhados (`app`, `redis`, `rabbitmq`).
   - Padroniza a dependência de banco de dados no serviço abstrato `db` com `condition: service_healthy`.

2. **[docker-compose.mariadb.yml](/docker-compose.mariadb.yml)**:
   - Configura o serviço `db` com imagem `mariadb:10.11`.
   - Inclui o **phpMyAdmin** na porta host `5657` (porta contêiner `80`).
   - Mapeia o banco na porta host `3308` (evitando conflito com porta 3306).
   - Injeta no Spring Boot a URL `jdbc:mariadb://db:3306/tgos_db` e driver `org.mariadb.jdbc.Driver`.
   - Cria volume dedicado e isolado `mariadb_data`.

3. **[docker-compose.postgres.yml](/docker-compose.postgres.yml)**:
   - Corrige as variáveis oficiais do PostgreSQL (`POSTGRES_DB`, `POSTGRES_USER`, `POSTGRES_PASSWORD`).
   - Corrige a imagem para `postgres:16-alpine`.
   - Mapeia o banco na porta host `5433` (porta contêiner `5432`).
   - Configura healthcheck nativo com `pg_isready`.
   - Inclui o **pgAdmin 4** na porta host `5658` (porta contêiner `80`).
   - Injeta no Spring Boot a URL `jdbc:postgresql://db:5432/tgos_db` e driver `org.postgresql.Driver`.
   - Cria volume dedicado e isolado `postgres_data`.

4. **[.env](/.env) e [.env.example](/.env.example)**:
   - Centraliza **todas as credenciais, usuários, senhas e portas** do ambiente em um único lugar seguro.
   - Permite que o comando padrão `docker compose up -d` já suba o banco configurado na variável `COMPOSE_FILE`.
   - `.env` devidamente protegido no [`.gitignore`](/.gitignore), com modelo completo versionado em [`.env.example`](/.env.example).
   - Todos os arquivos compose utilizam interpolação dinâmica `${VAR:-default}` com fallbacks seguros.

5. **[start.sh](/start.sh)**:
   - Script com menu interativo e opções via argumento CLI (`./start.sh mariadb`, `./start.sh postgres`, `./start.sh down`, `./start.sh status`).

6. **[README.md](/README.md)**:
   - Documentação atualizada com a nova tabela de serviços, portas, credenciais e instruções de uso.

---

## 2. Validações Realizadas

- `docker compose -f docker-compose.yml -f docker-compose.mariadb.yml config -q`: **Sucesso (Código 0)**.
- `docker compose -f docker-compose.yml -f docker-compose.postgres.yml config -q`: **Sucesso (Código 0)**.
- Alternância via variável `COMPOSE_FILE` no arquivo [`.env`](/.env): **Sucesso (Código 0)**.
- Permissões e execução do script [`start.sh status`](/start.sh): **Sucesso (Código 0)**.
