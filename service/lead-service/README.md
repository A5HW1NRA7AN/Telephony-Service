# Lead Service — Java Source

Spring Boot microservice that connects to Asterisk/FreePBX via AMI and captures missed-call leads.

## Local development (without Docker)

**Prerequisites:** JDK 17, Maven 3.9+, PostgreSQL

```bash
cd service/
mvn spring-boot:run
```

The service starts with AMI **disabled** by default — it will connect to Postgres and be ready for when you enable AMI.

Override any config via environment variables:

```bash
AMI_ENABLED=true AMI_HOST=<your-pbx-ip> mvn spring-boot:run
```

## Running tests

```bash
mvn test
```

## Building the JAR

```bash
mvn package -DskipTests
java -jar target/lead-telephony-service-0.0.1-SNAPSHOT.jar
```

## Project structure

```
src/main/java/com/registry/telephony/
├── TelephonyServiceApplication.java   ← Entry point
├── config/                            ← Properties + Spring beans
├── ami/                               ← AMI TCP client + message parser
├── handlers/                          ← Hangup → lead ingest logic
├── job/                               ← Async dispatch + retry sweeper
└── persistence/                       ← JPA entity + repository
```

See the root [README](../README.md) for architecture details and the full setup guide.
