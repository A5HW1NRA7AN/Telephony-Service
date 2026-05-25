package com.registry.telephony.handlers;

import static org.junit.jupiter.api.Assertions.assertEquals;

import org.junit.jupiter.api.Test;

class HangupLeadIngestServiceTest {

    @Test
    void idempotencyKey_prefersLinkedId() {
        assertEquals("L1", HangupLeadIngestService.idempotencyKey("U1", "L1"));
    }

    @Test
    void idempotencyKey_fallsBackToUniqueId() {
        assertEquals("U9", HangupLeadIngestService.idempotencyKey("U9", null));
        assertEquals("U9", HangupLeadIngestService.idempotencyKey("U9", "   "));
    }
}

