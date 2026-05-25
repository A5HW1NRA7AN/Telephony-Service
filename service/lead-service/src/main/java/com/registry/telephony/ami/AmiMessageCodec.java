package com.registry.telephony.ami;

import java.io.BufferedReader;
import java.io.IOException;
import java.util.LinkedHashMap;
import java.util.Map;

public final class AmiMessageCodec {

    private AmiMessageCodec() {}

    public static Map<String, String> readMessage(BufferedReader in) throws IOException {
        Map<String, String> map = new LinkedHashMap<>();
        while (true) {
            String line = in.readLine();
            if (line == null) {
                throw new java.io.EOFException("AMI stream closed before message end");
            }
            if (line.isEmpty()) {
                break;
            }
            int colon = line.indexOf(':');
            if (colon > 0) {
                String key = line.substring(0, colon).trim();
                String value = line.substring(colon + 1).trim();
                map.put(key, value);
            }
        }
        return map;
    }

    public static byte[] buildAction(Map<String, String> fields) {
        StringBuilder sb = new StringBuilder();
        for (Map.Entry<String, String> e : fields.entrySet()) {
            sb.append(e.getKey()).append(": ").append(e.getValue()).append("\r\n");
        }
        sb.append("\r\n");
        return sb.toString().getBytes(java.nio.charset.StandardCharsets.UTF_8);
    }
}

