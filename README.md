# Docker para Java Spring Boot: Ambiente Docker2

Bem-vindo ao novo ambiente de desenvolvimento **Docker2**, adaptado especificamente para o ecossistema **Java 21 LTS** e **Spring Boot 3**, seguindo as diretrizes de [ambiente.md](file:///home/wattrelos/Docker2/ambiente.md).

---

## 1. O que muda em relação ao Docker 1 (PHP)?

No projeto anterior em PHP, a arquitetura exigia um servidor web **NGINX** na frente para receber requisições HTTP e repassar via FastCGI para o **PHP-FPM** na porta 9000.

No **Java Spring Boot**, essa complexidade não é necessária:
- **Embedded Tomcat**: O Spring Boot já inclui um servidor web HTTP embutido de alta performance dentro do próprio arquivo `.jar`.
- **Um único contêiner para a aplicação**: Não precisamos de NGINX nem de contêiner separado de Tomcat. O próprio contêiner Java expõe a porta `8089` diretamente para o seu navegador (mapeada para `8090` no host).
- **Compilação Multi-stage**: O Dockerfile compila o código-fonte com **Maven + Java 21** e gera uma imagem final ultraleve baseada em **Alpine Linux + JRE 21**.

---

## 2. Visão Geral da Arquitetura e Opções de Banco de Dados

O ambiente foi estruturado de forma modular para permitir que você escolha entre **MariaDB 10 LTS** (Recomendado) ou **PostgreSQL 16** (Suportado), atendendo aos requisitos de [ambiente.md](file:///home/wattrelos/Docker2/ambiente.md).

### Serviços Compartilhados ([docker-compose.yml](file:///home/wattrelos/Docker2/docker-compose.yml))
| Serviço | Imagem Base | Porta Host | Porta Docker | Finalidade |
| :--- | :--- | :--- | :--- | :--- |
| **`app`** | Customizada via [Dockerfile](file:///home/wattrelos/Docker2/Dockerfile) | **8090** | `8089` | Backend Java 21 Spring Boot |
| **`redis`** | `redis:alpine` | **6380** | `6379` | Cache em memória ultrarrápido |
| **`rabbitmq`** | `rabbitmq:3-management-alpine` | **5673** / **15673** | `5672` / `15672` | Broker AMQP e painel web de filas |

### Opção 1: MariaDB ([docker-compose.mariadb.yml](file:///home/wattrelos/Docker2/docker-compose.mariadb.yml)) - *Recomendado*
| Serviço | Imagem Base | Porta Host | Porta Docker | Finalidade |
| :--- | :--- | :--- | :--- | :--- |
| **`db`** | `mariadb:10.11` | **3308** | `3306` | Banco Relacional MariaDB 10 LTS |
| **`phpmyadmin`** | `phpmyadmin:latest` | **5657** | `80` | Interface Web para gerenciar o MariaDB |

### Opção 2: PostgreSQL ([docker-compose.postgres.yml](file:///home/wattrelos/Docker2/docker-compose.postgres.yml)) - *Suportado*
| Serviço | Imagem Base | Porta Host | Porta Docker | Finalidade |
| :--- | :--- | :--- | :--- | :--- |
| **`db`** | `postgres:16-alpine` | **5433** | `5432` | Banco Relacional PostgreSQL 16 |
| **`pgadmin`** | `dpage/pgadmin4:latest` | **5658** | `80` | Interface Web para gerenciar o PostgreSQL |

> [!TIP]
> **Zero Conflito com Docker 1 (PHP) e Portas Locais:**
> Todas as portas externas do **Docker2** foram intencionalmente mapeadas de forma isolada (`8090`, `3308`, `5433`, `5657`, `5658`, `6380`, `5673`, `15673`). Assim, você pode manter tanto o **Docker 1** quanto o **Docker 2** ativos simultaneamente sem nenhum conflito de portas.

---

## 3. Como Escolher e Alternar o Banco de Dados

Você tem **3 formas práticas** de alternar entre as opções:

### Modo 1: Script Interativo (Mais Fácil)
Basta executar o script [start.sh](file:///home/wattrelos/Docker2/start.sh):
```bash
./start.sh
```
Ou passar diretamente o argumento:
```bash
./start.sh mariadb   # Sobe com MariaDB 10 + phpMyAdmin
./start.sh postgres  # Sobe com PostgreSQL 16 + pgAdmin 4
./start.sh down      # Encerra os contêineres
./start.sh status    # Exibe o status dos contêineres
```

### Modo 2: Pelo arquivo [.env](file:///home/wattrelos/Docker2/.env)
Edite a variável `COMPOSE_FILE` no arquivo `.env`:
```env
# Para MariaDB (padrão):
COMPOSE_FILE=docker-compose.yml:docker-compose.mariadb.yml

# Para PostgreSQL:
# COMPOSE_FILE=docker-compose.yml:docker-compose.postgres.yml
```
Depois, basta rodar o comando padrão do compose:
```bash
docker compose up -d
```

### Modo 3: Flags Explícitas na Linha de Comando
```bash
# Rodar com MariaDB:
docker compose -f docker-compose.yml -f docker-compose.mariadb.yml up -d

# Rodar com PostgreSQL:
docker compose -f docker-compose.yml -f docker-compose.postgres.yml up -d
```

### 3.1 Centralização e Segurança das Credenciais
Todas as credenciais de banco, filas e portas estão centralizadas e protegidas no arquivo [`.env`](file:///home/wattrelos/Docker2/.env) (com modelo de referência em [`.env.example`](file:///home/wattrelos/Docker2/.env.example)):
- O arquivo `.env` é protegido pelo [`.gitignore`](file:///home/wattrelos/Docker2/.gitignore) para nunca expor senhas no repositório.
- Se você clonar o projeto em outra máquina, basta rodar `cp .env.example .env` (ou executar `./start.sh`, que cria o `.env` automaticamente).
- Os arquivos do Docker Compose utilizam valores dinâmicos (`${DB_PASSWORD:-...}`) com fallbacks seguros.

---

## 4. Como a aplicação se comunica com os serviços?

Dentro da rede Docker Compose, o Spring Boot conecta-se ao banco de dados utilizando o hostname padrão **`db`**:

- **Com MariaDB**:
  - URL JDBC: `jdbc:mariadb://db:3306/tgos_db`
  - Driver: `org.mariadb.jdbc.Driver`
- **Com PostgreSQL**:
  - URL JDBC: `jdbc:postgresql://db:5432/tgos_db`
  - Driver: `org.postgresql.Driver`
- **Host do Redis**: `redis:6379`
- **Host do RabbitMQ**: `rabbitmq:5672`

### E se eu quiser rodar o Spring Boot fora do Docker (na IDE)?
Se preferir rodar a aplicação localmente pelo VS Code / IntelliJ conectando nos contêineres do Docker:
- Suba as dependências (exemplo com MariaDB):
  ```bash
  docker compose -f docker-compose.yml -f docker-compose.mariadb.yml up -d db phpmyadmin redis rabbitmq
  ```
  *(Ou para PostgreSQL, use `-f docker-compose.postgres.yml` subindo `db pgadmin redis rabbitmq`)*
- O MariaDB estará disponível em `localhost:3308`.
- O PostgreSQL estará disponível em `localhost:5433`.

---

## 5. Comandos essenciais para o dia a dia

1. **Construir e iniciar os serviços em segundo plano**:
   ```bash
   docker compose up -d --build
   ```
2. **Verificar o status dos contêineres**:
   ```bash
   docker compose ps
   ```
3. **Acompanhar os logs da aplicação Java**:
   ```bash
   docker compose logs -f app
   ```
4. **Acompanhar os logs do banco de dados**:
   ```bash
   docker compose logs -f db
   ```
5. **Parar os contêineres sem perder os dados dos volumes**:
   ```bash
   docker compose down
   ```

---

## 6. URLs de Acesso e Credenciais

- ☕ **Aplicação Java Spring Boot**: **[http://localhost:8090](http://localhost:8090)**
  - Dashboard de Diagnóstico: **[http://localhost:8090/diagnostico](http://localhost:8090/diagnostico)**
- 🐬 **MariaDB Web (phpMyAdmin)**: **[http://localhost:5657](http://localhost:5657)**
  - Usuário: `desenvolvedor` / Senha: `` (ou `root` / `rootsecret`)
  - Banco de Dados: `tgos_db`
- 🐘 **PostgreSQL Web (pgAdmin 4)**: **[http://localhost:5658](http://localhost:5658)**
  - Email: `admin@tgos.local` / Senha: `rootsecret`
  - Conexão com o banco: Host `db`, Porta `5432`, Usuário `desenvolvedor`, Senha ``, Banco `tgos_db`
- 🐇 **Painel Web do RabbitMQ**: **[http://localhost:15673](http://localhost:15673)**
  - Usuário: `guest` / Senha: `guest`
- ⚡ **Redis**: `localhost:6380` (porta interna `6379`)