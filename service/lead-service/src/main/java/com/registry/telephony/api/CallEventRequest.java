package com.registry.telephony.api;

import java.util.Map;
import lombok.Data;

/**
 * DTO for call events received from event-publisher via REST.
 * Matches the payload structure sent by EslOutboundServer.
 */
@Data
public class CallEventRequest {

    private String eventType;
    private String uniqueId;
    private String callerNumber;
    private String calledNumber;
    private String context;
    private String timestamp;
    private String ivrSelection;
    private String ivrLanguage;
    private Map<String, String> rawHeaders;
}
