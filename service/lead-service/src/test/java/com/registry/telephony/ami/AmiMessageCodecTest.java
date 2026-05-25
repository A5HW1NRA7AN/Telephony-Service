package com.registry.telephony.ami;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;

import java.io.BufferedReader;
import java.io.IOException;
import java.io.StringReader;
import java.nio.charset.StandardCharsets;
import java.util.Map;
import org.junit.jupiter.api.Test;

class AmiMessageCodecTest {

    @Test
    void readMessage_parsesHangupBlock() throws IOException {
        String raw =
                """
                Event: Hangup
                Privilege: call,all
                Channel: PJSIP/twilio-00000001
                Context: from-missed-call
                Exten: +15551234567
                Uniqueid: 1730000001.42
                Linkedid: 1730000001.42
                CallerIDNum: +19998887777
                Cause: 16

                """;
        BufferedReader in = new BufferedReader(new StringReader(raw));
        Map<String, String> m = AmiMessageCodec.readMessage(in);
        assertEquals("Hangup", m.get("Event"));
        assertEquals("from-missed-call", m.get("Context"));
        assertEquals("+19998887777", m.get("CallerIDNum"));
        assertEquals("1730000001.42", m.get("Uniqueid"));
    }

    @Test
    void readMessage_eofThrows() {
        BufferedReader in = new BufferedReader(new StringReader("Event: X\n"));
        assertThrows(IOException.class, () -> AmiMessageCodec.readMessage(in));
    }

    @Test
    void buildAction_roundTrip() {
        Map<String, String> fields = new java.util.LinkedHashMap<>();
        fields.put("Action", "Login");
        fields.put("Username", "u");
        fields.put("Secret", "p");
        String s = new String(AmiMessageCodec.buildAction(fields), StandardCharsets.UTF_8);
        assertEquals("Action: Login\r\nUsername: u\r\nSecret: p\r\n\r\n", s);
    }
}

