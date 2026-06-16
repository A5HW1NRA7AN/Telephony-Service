package com.telephony.event.server;

import com.fasterxml.jackson.databind.ObjectMapper;
import lombok.extern.slf4j.Slf4j;
import org.freeswitch.esl.client.outbound.AbstractOutboundClientHandler;
import org.freeswitch.esl.client.outbound.AbstractOutboundPipelineFactory;
import org.freeswitch.esl.client.outbound.SocketClient;
import org.freeswitch.esl.client.transport.event.EslEvent;
import org.jboss.netty.channel.ChannelHandlerContext;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.context.event.ApplicationReadyEvent;
import org.springframework.context.event.EventListener;
import org.springframework.kafka.core.KafkaTemplate;
import org.springframework.stereotype.Component;

import jakarta.annotation.PreDestroy;
import java.time.Instant;
import java.util.HashMap;
import java.util.Map;

@Component
@Slf4j
public class EslOutboundServer {

    private final String host;
    private final int port;
    private final KafkaTemplate<String, String> kafkaTemplate;
    private final String topic;
    private final ObjectMapper objectMapper = new ObjectMapper();

    private SocketClient socketClient;

    public EslOutboundServer(
            @Value("${telephony.esl.outbound-host:0.0.0.0}") String host,
            @Value("${telephony.esl.outbound-port:8084}") int port,
            KafkaTemplate<String, String> kafkaTemplate,
            @Value("${telephony.esl.kafka.topic:telephony-call-events}") String topic) {
        this.host = host;
        this.port = port;
        this.kafkaTemplate = kafkaTemplate;
        this.topic = topic;
    }

    @EventListener(ApplicationReadyEvent.class)
    public void start() {
        log.info("Starting Outbound ESL Server on {}:{}", host, port);
        try {
            socketClient = new SocketClient(
                    port,
                    new AbstractOutboundPipelineFactory() {
                        @Override
                        protected AbstractOutboundClientHandler makeHandler() {
                            return new CallHandler();
                        }
                    }
            );
            socketClient.start();
            log.info("Outbound ESL Server started successfully on port {}", port);
        } catch (Exception e) {
            log.error("Failed to start Outbound ESL Server", e);
        }
    }

    @PreDestroy
    public void stop() {
        if (socketClient != null) {
            log.info("Stopping Outbound ESL Server");
            socketClient.stop();
        }
    }

    private class CallHandler extends AbstractOutboundClientHandler {

        private String getCallerId(Map<String, String> headers) {
            String orig = headers.get("variable_origination_caller_id_number");
            if (orig != null && !orig.isBlank() && !"public".equalsIgnoreCase(orig)) {
                return orig;
            }
            String chan = headers.get("Channel-Caller-ID-Number");
            if (chan != null && !chan.isBlank() && !"public".equalsIgnoreCase(chan)) {
                return chan;
            }
            return headers.get("Caller-Caller-ID-Number");
        }

        @Override
        protected void handleConnectResponse(ChannelHandlerContext ctx, EslEvent event) {
            Map<String, String> headers = event.getEventHeaders();
            String channelUniqueId = headers.get("Unique-ID");
            String callerIdNumber = getCallerId(headers);
            String destinationNumber = headers.get("Caller-Destination-Number");
            String contextName = headers.get("Caller-Context");

            log.info("Received outbound ESL connection from FreeSWITCH. Unique-ID: {}, Caller: {}, Destination: {}, Context: {}",
                    channelUniqueId, callerIdNumber, destinationNumber, contextName);

            // Send CALL_START event to Kafka
            publishCallEvent("CALL_START", channelUniqueId, callerIdNumber, destinationNumber, contextName, headers);

            // Subscribe to events for this channel
            sendSyncSingleLineCommand(ctx.getChannel(), "myevents");

            // Send execute hangup command to FreeSWITCH to terminate the channel after greeting playback.
            java.util.List<String> hangupMsg = new java.util.ArrayList<>();
            hangupMsg.add("sendmsg");
            hangupMsg.add("call-command: execute");
            hangupMsg.add("execute-app-name: hangup");
            hangupMsg.add("");
            sendSyncMultiLineCommand(ctx.getChannel(), hangupMsg);
        }

        @Override
        protected void handleEslEvent(ChannelHandlerContext ctx, EslEvent event) {
            String eventName = event.getEventName();
            Map<String, String> headers = event.getEventHeaders();
            String channelUniqueId = headers.get("Unique-ID");
            String callerIdNumber = getCallerId(headers);
            String destinationNumber = headers.get("Caller-Destination-Number");
            String contextName = headers.get("Caller-Context");

            log.debug("Received ESL event: {} for channel: {}", eventName, channelUniqueId);

            if ("CHANNEL_ANSWER".equals(eventName)) {
                log.info("Call answered. Unique-ID: {}", channelUniqueId);
                publishCallEvent("CALL_ANSWER", channelUniqueId, callerIdNumber, destinationNumber, contextName, headers);
            } else if ("CHANNEL_HANGUP".equals(eventName)) {
                log.info("Call hung up. Unique-ID: {}", channelUniqueId);
                publishCallEvent("CALL_HANGUP", channelUniqueId, callerIdNumber, destinationNumber, contextName, headers);
            }
        }

        @Override
        protected void handleAuthRequest(ChannelHandlerContext ctx) {
            // Outbound connection authentication is usually not required from our end,
            // but the abstract method requires an implementation.
            log.debug("Auth request received in outbound ESL handler (no auth needed).");
        }

        @Override
        protected void handleDisconnectionNotice() {
            log.info("Outbound ESL channel socket disconnected");
        }

        private void publishCallEvent(String eventType, String uniqueId, String caller, String destination, String context, Map<String, String> headers) {
            try {
                Map<String, Object> payload = new HashMap<>();
                payload.put("eventType", eventType);
                payload.put("uniqueId", uniqueId);
                payload.put("callerNumber", caller);
                payload.put("calledNumber", destination);
                payload.put("context", context);
                payload.put("timestamp", Instant.now().toString());

                // Extract IVR results set by FreeSWITCH dialplan
                String ivrSelection = headers.get("variable_ivr_result");
                String ivrLanguage = headers.get("variable_ivr_lang");
                if (ivrSelection != null && !ivrSelection.isBlank()) {
                    payload.put("ivrSelection", ivrSelection);
                }
                if (ivrLanguage != null && !ivrLanguage.isBlank()) {
                    payload.put("ivrLanguage", ivrLanguage);
                }

                payload.put("rawHeaders", headers);

                log.info("Publishing event {} to Kafka for Call: {}. ivrSelection: {}, ivrLanguage: {}", 
                        eventType, uniqueId, ivrSelection, ivrLanguage);

                String json = objectMapper.writeValueAsString(payload);
                kafkaTemplate.send(topic, uniqueId, json);
                log.debug("Published {} event to Kafka topic {}: {}", eventType, topic, json);
            } catch (Exception e) {
                log.error("Failed to publish event to Kafka", e);
            }
        }
    }
}
