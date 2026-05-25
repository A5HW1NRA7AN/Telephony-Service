package com.registry.telephony.kafka;

import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.registry.telephony.handlers.HangupLeadIngestService;
import lombok.Data;
import lombok.extern.slf4j.Slf4j;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.kafka.annotation.KafkaListener;
import org.springframework.stereotype.Component;

import java.util.HashMap;
import java.util.Map;

@Component
@ConditionalOnProperty(name = "telephony.kafka.enabled", havingValue = "true", matchIfMissing = true)
@Slf4j
public class KafkaLeadConsumer {

    private final HangupLeadIngestService hangupLeadIngestService;
    private final ObjectMapper objectMapper;

    public KafkaLeadConsumer(HangupLeadIngestService hangupLeadIngestService, ObjectMapper objectMapper) {
        this.hangupLeadIngestService = hangupLeadIngestService;
        this.objectMapper = objectMapper;
    }

    @KafkaListener(topics = "${telephony.kafka.topic:telephony-call-events}", groupId = "${spring.kafka.consumer.group-id:lead-service-group}")
    public void consume(String message) {
        log.debug("Consumed Kafka call event: {}", message);
        try {
            KafkaCallEvent payload = objectMapper.readValue(message, KafkaCallEvent.class);
            
            // We only ingest leads on CALL_HANGUP event
            if (!"CALL_HANGUP".equalsIgnoreCase(payload.getEventType())) {
                log.debug("Ignoring event type: {}", payload.getEventType());
                return;
            }

            log.info("Processing CALL_HANGUP event for uniqueId: {}", payload.getUniqueId());

            // Map Kafka payload to AMI-compatible structure for the ingest service
            Map<String, String> amiMessage = new HashMap<>();
            amiMessage.put("Event", "Hangup");
            amiMessage.put("Context", payload.getContext());
            amiMessage.put("Uniqueid", payload.getUniqueId());
            amiMessage.put("Linkedid", payload.getUniqueId());
            amiMessage.put("CallerIDNum", payload.getCallerNumber());
            amiMessage.put("ConnectedLineNum", payload.getCallerNumber());
            
            // Map destination number
            String called = payload.getCalledNumber();
            amiMessage.put("Exten", called != null ? called : "");
            amiMessage.put("DNID", called != null ? called : "");

            if (payload.getRawHeaders() != null) {
                // FreeSWITCH variables for call duration
                String duration = payload.getRawHeaders().get("variable_duration");
                String billsec = payload.getRawHeaders().get("variable_billsec");
                
                if (duration != null) {
                    amiMessage.put("Duration", duration);
                }
                if (billsec != null) {
                    amiMessage.put("BillableSeconds", billsec);
                }
                
                // Read context from channel headers if not populated
                String channelContext = payload.getRawHeaders().get("Channel-Context");
                if (channelContext != null && (payload.getContext() == null || payload.getContext().isBlank())) {
                    amiMessage.put("Context", channelContext);
                }
            }

            hangupLeadIngestService.onAmiMessage(amiMessage);
            log.info("Successfully dispatched hangup call event for uniqueId: {}", payload.getUniqueId());

        } catch (Exception e) {
            log.error("Failed to process Kafka call event", e);
        }
    }

    @Data
    public static class KafkaCallEvent {
        private String eventType;
        private String uniqueId;
        private String callerNumber;
        private String calledNumber;
        private String context;
        private String timestamp;
        private Map<String, String> rawHeaders;
    }
}
