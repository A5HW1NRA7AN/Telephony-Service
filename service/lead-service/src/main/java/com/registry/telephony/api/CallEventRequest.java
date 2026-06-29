package com.registry.telephony.api;

import com.fasterxml.jackson.annotation.JsonIgnoreProperties;
import java.util.Map;
import lombok.Data;

/**
 * DTO for call events received from event-publisher via REST.
 * Matches the payload structure sent by EslOutboundServer.
 */
@Data
@JsonIgnoreProperties(ignoreUnknown = true)
public class CallEventRequest {

    private String eventType;
    private String uniqueId;
    private String callerNumber;
    private String calledNumber;
    private String context;
    private String timestamp;
    private Map<String, String> rawHeaders;
}
