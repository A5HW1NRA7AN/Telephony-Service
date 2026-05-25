package com.registry.telephony.job;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.registry.telephony.config.TelephonyProperties;
import com.registry.telephony.persistence.CallLeadIngestLog;
import com.registry.telephony.persistence.CallLeadIngestLogRepository;
import com.registry.telephony.persistence.CallLeadProcessingStatus;
import java.time.Instant;
import java.util.HashMap;
import java.util.Map;
import java.util.UUID;
import lombok.extern.slf4j.Slf4j;
import org.apache.commons.lang3.StringUtils;
import org.springframework.beans.factory.annotation.Qualifier;
import org.springframework.http.HttpEntity;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.scheduling.annotation.Async;
import org.springframework.stereotype.Service;
import org.springframework.transaction.support.TransactionTemplate;
import org.springframework.web.client.RestTemplate;

@Service
@Slf4j
public class LeadDispatchService {

    private final CallLeadIngestLogRepository repository;
    private final TelephonyProperties telephonyProperties;
    private final RestTemplate restTemplate;
    private final ObjectMapper objectMapper;
    private final TransactionTemplate transactionTemplate;

    public LeadDispatchService(
            CallLeadIngestLogRepository repository,
            TelephonyProperties telephonyProperties,
            RestTemplate restTemplate,
            ObjectMapper objectMapper,
            @Qualifier("telephonyTransactionTemplate") TransactionTemplate transactionTemplate) {
        this.repository = repository;
        this.telephonyProperties = telephonyProperties;
        this.restTemplate = restTemplate;
        this.objectMapper = objectMapper;
        this.transactionTemplate = transactionTemplate;
    }

    @Async
    public void dispatchAsync(UUID logId) {
        dispatchNow(logId);
    }

    public void dispatchNow(UUID logId) {
        transactionTemplate.executeWithoutResult(s -> executeDispatch(logId));
    }

    private void executeDispatch(UUID logId) {
        CallLeadIngestLog row = repository.findById(logId).orElse(null);
        if (row == null) {
            return;
        }
        if (row.getProcessingStatus() != CallLeadProcessingStatus.RECEIVED
                && row.getProcessingStatus() != CallLeadProcessingStatus.SENDING) {
            return;
        }

        String url = StringUtils.trimToNull(telephonyProperties.getLeadRegistry().getUrl());
        row.setUpdatedAt(Instant.now());

        if (url == null) {
            row.setProcessingStatus(CallLeadProcessingStatus.SKIPPED_NO_REGISTRY_URL);
            row.setLastError(null);
            row.setSentAt(Instant.now());
            repository.save(row);
            return;
        }

        row.setProcessingStatus(CallLeadProcessingStatus.SENDING);
        repository.saveAndFlush(row);

        HttpHeaders headers = new HttpHeaders();
        headers.setContentType(MediaType.APPLICATION_JSON);
        String apiKeyHeader = StringUtils.trimToNull(telephonyProperties.getLeadRegistry().getApiKeyHeader());
        String apiKeyValue = StringUtils.trimToNull(telephonyProperties.getLeadRegistry().getApiKeyValue());
        if (apiKeyHeader != null && apiKeyValue != null) {
            headers.set(apiKeyHeader, apiKeyValue);
        }

        @SuppressWarnings("unchecked")
        Map<String, Object> body = objectMapper.convertValue(row.getNormalizedLeadPayload(), Map.class);

        try {
            ResponseEntity<String> resp = restTemplate.postForEntity(url, new HttpEntity<>(body, headers), String.class);
            row.setProcessingStatus(CallLeadProcessingStatus.SENT);
            row.setLastError(null);
            String snippet = resp.getBody() == null ? "" : resp.getBody();
            row.setExternalResponseSnippet(snippet.length() > 2048 ? snippet.substring(0, 2048) : snippet);
            row.setSentAt(Instant.now());
            log.info("Successfully dispatched lead {}. Registry response: {}", logId, snippet);
        } catch (Exception e) {
            row.setProcessingStatus(CallLeadProcessingStatus.FAILED);
            row.setLastError(StringUtils.abbreviate(e.getMessage(), 4000));
            log.error("Lead dispatch failed for {}", logId, e);
        }

        row.setUpdatedAt(Instant.now());
        repository.save(row);
    }
}

