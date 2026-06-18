# Lead Service - Java Application

Spring Boot microservice that receives call event data via REST API from the Event-Publisher, logs all events to the `call_event_log` audit table, and registers qualified leads (from HANGUP events) with the external Lead Registry.

## REST API

### POST /api/v1/call-events

Receives call events from `event-publisher`. All events are logged to the `call_event_log` table. Only `CALL_HANGUP` events trigger lead creation.

**Request Body:**
```json
{
  "eventType": "CALL_HANGUP",
  "uniqueId": "abc-123-def",
  "callerNumber": "+81312345678",
  "calledNumber": "+81398765432",
  "context": "public",
  "timestamp": "2026-06-18T10:30:00Z",
  "ivrSelection": "1",
  "ivrLanguage": "en",
  "rawHeaders": { "variable_duration": "15", "variable_billsec": "10" }
}
```

**Response:**
```json
{ "status": "accepted", "eventId": "uuid" }
```

## Database Tables

| Table | Purpose |
|-------|---------|
| `call_event_log` | Audit trail for ALL call events (START, ANSWER, HANGUP) |
| `telephony_call_lead_ingest_log` | Lead records created from HANGUP events only |

## Local Development

**Prerequisites:** JDK 17, Maven 3.9+, PostgreSQL.

1. Configure connection properties or environment variables in `src/main/resources/application.properties`.
2. Start the application:
   ```bash
   cd service/lead-service
   mvn spring-boot:run
   ```

Override any configuration via environment variables:
```bash
DB_URL=jdbc:postgresql://localhost:5432/lead_db mvn spring-boot:run
```

## Running Tests

```bash
mvn test
```

## Building the JAR

```bash
mvn package -DskipTests
java -jar target/lead-telephony-service-0.0.1-SNAPSHOT.jar
```

## Project Structure

```
src/main/java/com/registry/telephony/
├── TelephonyServiceApplication.java   - Application entry point
├── api/                               - REST controllers and DTOs (CallEventController)
├── config/                            - Properties mappings and Spring configuration beans
├── handlers/                          - Lead ingestion and business logic handlers
├── job/                               - Retry scheduler and sweep jobs for failed lead posts
└── persistence/                       - JPA entities and repositories (CallEventLog, CallLeadIngestLog)
```

See the root README for architecture details and the complete CI/CD setup guide.
