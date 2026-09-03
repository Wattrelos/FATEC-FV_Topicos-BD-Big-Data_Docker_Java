# ==========================================
# Estágio 1: Build (Compilação do JAR com Java 21)
# ==========================================
FROM maven:3.9.6-eclipse-temurin-21 AS build
WORKDIR /app

# Copia a configuração de dependências primeiro para cache eficiente
COPY pom.xml .
RUN mvn dependency:go-offline -B || true

# Copia o código-fonte
COPY src ./src

# Compila a aplicação gerando o .jar executável (sem rodar testes para acelerar o build)
RUN mvn clean package -DskipTests

# ==========================================
# Estágio 2: Runtime (Ambiente de Execução leve)
# ==========================================
FROM eclipse-temurin:21-jre-alpine
WORKDIR /app

# Criação de usuário sem privilégios de root para segurança
RUN addgroup -S appgroup && adduser -S appuser -G appgroup
USER appuser

# Copia o .jar compilado do estágio de build
COPY --from=build /app/target/*.jar app.jar

# Porta padrão exposta pelo Spring Boot (8089)
EXPOSE 8089

# Executa com flags JVM otimizadas para contêineres
ENTRYPOINT ["java", "-XX:+UseContainerSupport", "-XX:MaxRAMPercentage=75.0", "-jar", "app.jar"]
