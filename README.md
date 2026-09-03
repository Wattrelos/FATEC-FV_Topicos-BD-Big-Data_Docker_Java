# Docker para Java Spring Boot: Ambiente Docker2

Bem-vindo ao novo ambiente de desenvolvimento **Docker2**, adaptado especificamente para o ecossistema **Java 21 LTS** e **Spring Boot 3**, seguindo as diretrizes de [ambiente.md](file:///home/wattrelos/Docker2/ambiente.md).

---

## 1. O que muda em relação ao Docker 1 (PHP)?

No projeto anterior em PHP, a arquitetura exigia um servidor web **NGINX** na frente para receber requisições HTTP e repassar via FastCGI para o **PHP-FPM** na porta 9000.

No **Java Spring Boot**, essa complexidade não é necessária:
- **Embedded Tomcat**: O Spring Boot já inclui um servidor web HTTP embutido de alta performance dentro do próprio arquivo `.jar`.
- **Um único contêiner para a aplicação**: Não precisamos de NGINX nem de contêiner separado de Tomcat. O próprio contêiner Java expõe a porta `8089` diretamente para o seu navegador.
- **Compilação Multi-stage**: O Dockerfile compila o código-fonte com **Maven + Java 21** e gera uma imagem final ultraleve baseada em **Alpine Linux + JRE 21**.

---

## 2. Visão Geral da Arquitetura de Contêineres

O arquivo [docker-compose.yml](file:///home/wattrelos/Docker2/docker-compose.yml) orquestra os seguintes serviços:

| Serviço | Imagem Base | Porta Externa (Host) | Porta Interna (Rede Docker) | Finalidade |
| :--- | :--- | :--- | :--- | :--- |
| **`app`** | Customizada via [Dockerfile](file:///home/wattrelos/Docker2/Dockerfile) | **8090** | `8089` | Backend Java 21 Spring Boot com servidor Tomcat embutido |
| **`mariadb`** | `mariadb:10.11` | **3308** | `3306` | Banco de dados relacional (MariaDB 10 LTS) |
| **`phpmyadmin`** | `phpmyadmin:latest` | **5657** | `80` | Interface Web para gerenciar o banco MariaDB visualmente |
| **`redis`** | `redis:alpine` | **6380** | `6379` | Cache em memória ultrarrápido |
| **`rabbitmq`** | `rabbitmq:3-management-alpine` | **5673** / **15673** | `5672` / `15672` | Broker de mensageria e painel web de gerenciamento |

> [!TIP]
> **Zero Conflito com Docker 1 (PHP):**
> Todas as portas externas do **Docker2** foram intencionalmente mapeadas de forma isolada (`8090`, `3308`, `5657`, `6380`, `5673`, `15673`). Assim, você pode manter tanto o **Docker 1** (PHP SaaS) quanto o **Docker 2** (Java Spring Boot) ativos simultaneamente sem nenhum conflito de porta no seu computador. Internamente na rede Docker, cada serviço continua ouvindo em suas portas padrão.

---

## 3. Como funciona o Dockerfile Multi-stage?

O arquivo [Dockerfile](file:///home/wattrelos/Docker2/Dockerfile) utiliza o padrão moderno **Multi-Stage Build**:

```dockerfile
# 1. Estágio de Build: Compila com Maven e Java 21 oficial
FROM maven:3.9.6-eclipse-temurin-21 AS build
WORKDIR /app
COPY pom.xml .
RUN mvn dependency:go-offline -B || true
COPY src ./src
RUN mvn clean package -DskipTests

# 2. Estágio de Runtime: Imagem final enxuta com JRE 21
FROM eclipse-temurin:21-jre-alpine
WORKDIR /app
RUN addgroup -S appgroup && adduser -S appuser -G appgroup
USER appuser
COPY --from=build /app/target/*.jar app.jar
EXPOSE 8089
ENTRYPOINT ["java", "-XX:+UseContainerSupport", "-XX:MaxRAMPercentage=75.0", "-jar", "app.jar"]
```

### Vantagens:
- **Você não precisa ter o Maven instalado** na sua máquina para compilar ou subir o projeto; o Docker faz tudo isoladamente.
- **Tamanho reduzido**: O código-fonte e as ferramentas de compilação ficam no primeiro estágio; a imagem final contém apenas o binário `.jar` e o JRE.
- **Segurança**: A aplicação roda com usuário não-root (`appuser`).

---

## 4. Como a aplicação se comunica com os serviços?

Dentro da rede do Docker Compose, a comunicação entre contêineres utiliza os **nomes dos serviços como hostnames**:

- **Host do MariaDB**: `mariadb` (porta interna `3306`)
  - URL JDBC interna: `jdbc:mariadb://mariadb:3306/tgos_db`
- **Host do Redis**: `redis` (porta interna `6379`)
- **Host do RabbitMQ**: `rabbitmq` (porta interna `5672`)

### E se eu quiser rodar o Spring Boot fora do Docker (na IDE)?
Se preferir rodar a aplicação localmente pelo VS Code / IntelliJ conectando nos contêineres do Docker:
- Suba apenas as dependências:
  ```bash
  docker compose up -d mariadb phpmyadmin redis rabbitmq
  ```
- O banco estará disponível para sua máquina em `localhost:3307`. As classes [AppConfig](file:///home/wattrelos/Docker2/Tgos/src/main/java/com/gwj/AppConfig.java) e [application.properties](file:///home/wattrelos/Docker2/Tgos/src/main/resources/application.properties) já possuem tratamento automático para alternar entre as conexões.

---

## 5. Comandos essenciais para o dia a dia

1. **Construir e iniciar todos os serviços em segundo plano**:
   ```bash
   docker compose up -d --build
   ```
2. **Verificar se os contêineres estão rodando**:
   ```bash
   docker compose ps
   ```
3. **Acompanhar os logs da aplicação Java em tempo real**:
   ```bash
   docker compose logs -f app
   ```
4. **Reiniciar apenas a aplicação após alterações**:
   ```bash
   docker compose restart app
   ```
5. **Parar todos os contêineres sem perder os dados do banco**:
   ```bash
   docker compose down
   ```

---

## 6. Dashboard de Diagnóstico em Tempo Real

Assim como no Docker 1, criamos um painel visual completo de diagnóstico em tempo real no Spring Boot:

👉 **[http://localhost:8090/diagnostico](http://localhost:8090/diagnostico)**

### O que o diagnóstico valida:
- ☕ **Java Runtime**: Versão exata do Java 21 LTS (Eclipse Temurin), vendor e uso de memória em MB.
- 🐬 **MariaDB**: Conexão ativa com o banco `tgos_db`, versão do banco (10.11 LTS) e latência em milissegundos.
- ⚡ **Redis**: Teste de conexão na porta `6380` (interna `6379`), resposta `+PONG` e latência.
- 🐇 **RabbitMQ**: Teste de conexão no protocolo AMQP na porta `5673` (interna `5672`) e latência.
- 🔗 **Acesso Rápido**:
  - Interface Web do Banco (phpMyAdmin): **[http://localhost:5657](http://localhost:5657)** (usuário: `desenvolvedor` / senha: `b2#FbXPQTu4FYw` ou `root` / `rootsecret`)
  - Painel Web RabbitMQ: **[http://localhost:15673](http://localhost:15673)** (usuário: `guest` / senha: `guest`)
  - Página Inicial do Sistema: **[http://localhost:8090](http://localhost:8090)**