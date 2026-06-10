package com.registry.telephony.config;

import java.util.ArrayList;
import java.util.List;
import lombok.Getter;
import lombok.Setter;
import org.springframework.boot.context.properties.ConfigurationProperties;

@ConfigurationProperties(prefix = "telephony")
@Getter
@Setter
public class TelephonyProperties {

    private final LeadRegistry leadRegistry = new LeadRegistry();
    private final Dispatch dispatch = new Dispatch();

    @Getter
    @Setter
    public static class LeadRegistry {
        private String url = "http://34.221.40.211:8080/";
        private String apiKeyHeader = "";
        private String apiKeyValue = "";
    }

    @Getter
    @Setter
    public static class Dispatch {
        private boolean sweeperEnabled = true;
        private int staleAfterSeconds = 300;
        private long sweeperIntervalMs = 60000;
    }

    private List<String> leadContextAllowlist = new ArrayList<>(List.of("from-missed-call"));

    public List<String> getLeadContextAllowlist() {
        if (leadContextAllowlist == null || leadContextAllowlist.isEmpty()) {
            return List.of("from-missed-call");
        }
        return leadContextAllowlist;
    }

    public void setLeadContextAllowlist(List<String> leadContextAllowlist) {
        this.leadContextAllowlist =
                leadContextAllowlist != null ? new ArrayList<>(leadContextAllowlist) : new ArrayList<>();
    }
}

