FROM maven:3.9-eclipse-temurin-17 AS build
WORKDIR /src
COPY . .
RUN mvn package

FROM eclipse-temurin:17-jre
WORKDIR /app
COPY --from=build /src/target/sample-risk-java-api-0.1.0.jar /app/app.jar
ENTRYPOINT ["java", "-cp", "/app/app.jar", "com.example.pdlc.App"]

