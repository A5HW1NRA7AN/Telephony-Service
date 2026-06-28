package com.registry.telephony.persistence;

import com.fasterxml.jackson.databind.JsonNode;
import io.hypersistence.utils.hibernate.type.json.JsonBinaryType;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import java.time.Instant;
import java.util.UUID;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;
import org.hibernate.annotations.Type;

/**
 * Audit log entity for ALL call events (CALL_START, CALL_ANSWER, CALL_HANGUP).
 * Every event received from event-publisher is persisted here for observability.
 */
@Entity
@Table(name = "call_event_log")
@Getter
@Setter
@NoArgsConstructor
public class CallEventLog {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    @Column(name = "event_type", nullable = false, length = 32)
    private String eventType;

    @Column(name = "call_unique_id", nullable = false, length = 64)
    private String callUniqueId;

    @Column(name = "caller_number", length = 32)
    private String callerNumber;

    @Column(name = "called_number", length = 32)
    private String calledNumber;

    @Column(name = "context", length = 64)
    private String context;

    @Type(JsonBinaryType.class)
    @Column(name = "raw_headers", columnDefinition = "jsonb")
    private JsonNode rawHeaders;

    @Column(name = "event_timestamp", length = 64)
    private String eventTimestamp;

    @Column(name = "received_at", nullable = false)
    private Instant receivedAt = Instant.now();
}
