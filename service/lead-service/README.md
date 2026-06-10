# Lead Service - Java Application

Spring Boot microservice that consumes call event messages from Apache Kafka, filters and normalizes the call logs, and registers qualified leads with the external Lead Registry database.

## Local development (without Docker)

**Prerequisites:** JDK 17, Maven 3.9+, PostgreSQL, and a running Apache Kafka broker.

1. Configure connection properties or environment variables in `src/main/resources/application.properties`.
2. Start the application:
   ```bash
   cd service/lead-service
   mvn spring-boot:run
   ```

Override any configuration via environment variables:
```bash
KAFKA_BOOTSTRAP_SERVERS=localhost:9092 DB_URL=jdbc:postgresql://localhost:5432/lead_db mvn spring-boot:run
```

## Running tests

To run the unit and integration tests:
```bash
mvn test
```

## Building the JAR

To compile the code and build the executable JAR:
```bash
mvn package -DskipTests
java -jar target/lead-telephony-service-0.0.1-SNAPSHOT.jar
```

## Project Structure

```
src/main/java/com/registry/telephony/
├── TelephonyServiceApplication.java   - Application entry point
├── config/                            - Properties mappings and Spring configuration beans
├── handlers/                          - Lead ingestion and business logic handlers
├── job/                               - Retry scheduler and sweep jobs for failed lead posts
├── kafka/                             - Kafka consumers and serialization configs
└── persistence/                       - JPA entities and repositories (telephony_call_lead_ingest_log)
```

See the root README for architecture details and the complete CI/CD setup guide.
