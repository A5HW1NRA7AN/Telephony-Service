package com.registry.telephony.api;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.registry.telephony.handlers.HangupLeadIngestService;
import com.registry.telephony.persistence.CallEventLog;
import com.registry.telephony.persistence.CallEventLogRepository;
import java.time.Instant;
import java.util.HashMap;
import java.util.Map;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

/**
 * REST endpoint that receives call events from event-publisher.
 * Replaces the previous Kafka consumer (KafkaLeadConsumer).
 *
 * <p>ALL events (CALL_START, CALL_ANSWER, CALL_HANGUP) are persisted to
 * the call_event_log audit table. Only CALL_HANGUP events trigger lead creation.</p>
 */
@RestController
@RequestMapping("/api/v1/call-events")
@RequiredArgsConstructor
@Slf4j
public class CallEventController {

    private final CallEventLogRepository callEventLogRepository;
    private final HangupLeadIngestService hangupLeadIngestService;
    private final ObjectMapper objectMapper;

    @PostMapping
    public ResponseEntity<Map<String, String>> receiveCallEvent(@RequestBody CallEventRequest request) {
        log.info("Received {} event for call: {}", request.getEventType(), request.getUniqueId());

        // 1. Persist ALL events to call_event_log for audit trail
        CallEventLog logEntry = mapToLogEntry(request);
        try {
            callEventLogRepository.save(logEntry);
            log.debug("Persisted {} event to call_event_log for uniqueId: {}",
                    request.getEventType(), request.getUniqueId());
        } catch (Exception e) {
            log.error("Failed to persist call event to call_event_log", e);
            return ResponseEntity.internalServerError()
                    .body(Map.of("status", "error", "message", "Failed to persist event"));
        }

        // 2. For CALL_HANGUP events, also trigger lead ingestion
        if ("CALL_HANGUP".equalsIgnoreCase(request.getEventType())) {
            log.info("Processing CALL_HANGUP event for uniqueId: {}", request.getUniqueId());
            Map<String, String> eventData = mapToEventData(request);
            try {
                hangupLeadIngestService.onCallEvent(eventData);
                log.info("Successfully dispatched hangup call event for uniqueId: {}", request.getUniqueId());
            } catch (Exception e) {
                log.error("Failed to process hangup event for lead ingestion", e);
            }
        }

        return ResponseEntity.ok(Map.of(
                "status", "accepted",
                "eventId", logEntry.getId() != null ? logEntry.getId().toString() : "pending"
        ));
    }

    private CallEventLog mapToLogEntry(CallEventRequest request) {
        CallEventLog log = new CallEventLog();
        log.setEventType(request.getEventType());
        log.setCallUniqueId(request.getUniqueId() != null ? request.getUniqueId() : "");
        log.setCallerNumber(request.getCallerNumber());
        log.setCalledNumber(request.getCalledNumber());
        log.setContext(request.getContext());
        log.setIvrSelection(request.getIvrSelection());
        log.setIvrLanguage(request.getIvrLanguage());
        log.setEventTimestamp(request.getTimestamp());
        log.setReceivedAt(Instant.now());

        if (request.getRawHeaders() != null) {
            log.setRawHeaders(objectMapper.valueToTree(request.getRawHeaders()));
        }

        return log;
    }

    /**
     * Maps the REST request to the stack-agnostic event data map
     * expected by HangupLeadIngestService.onCallEvent().
     * This replaces the mapping that was previously in KafkaLeadConsumer.
     */
    private Map<String, String> mapToEventData(CallEventRequest request) {
        Map<String, String> eventData = new HashMap<>();
        eventData.put("Event", "Hangup");
        eventData.put("Context", request.getContext() != null ? request.getContext() : "");
        eventData.put("Uniqueid", request.getUniqueId() != null ? request.getUniqueId() : "");
        eventData.put("Linkedid", request.getUniqueId() != null ? request.getUniqueId() : "");
        eventData.put("CallerIDNum", request.getCallerNumber() != null ? request.getCallerNumber() : "");
        eventData.put("ConnectedLineNum", request.getCallerNumber() != null ? request.getCallerNumber() : "");

        // IVR selection and language
        eventData.put("ivrSelection", request.getIvrSelection() != null ? request.getIvrSelection() : "");
        eventData.put("ivrLanguage", request.getIvrLanguage() != null ? request.getIvrLanguage() : "");

        // Destination number
        String called = request.getCalledNumber();
        eventData.put("Exten", called != null ? called : "");
        eventData.put("DNID", called != null ? called : "");

        // Extract duration from raw headers if available
        if (request.getRawHeaders() != null) {
            String duration = request.getRawHeaders().get("variable_duration");
            String billsec = request.getRawHeaders().get("variable_billsec");

            if (duration != null) {
                eventData.put("Duration", duration);
            }
            if (billsec != null) {
                eventData.put("BillableSeconds", billsec);
            }

            // Read context from channel headers if not populated
            String channelContext = request.getRawHeaders().get("Channel-Context");
            if (channelContext != null && (request.getContext() == null || request.getContext().isBlank())) {
                eventData.put("Context", channelContext);
            }
        }

        return eventData;
    }
}
