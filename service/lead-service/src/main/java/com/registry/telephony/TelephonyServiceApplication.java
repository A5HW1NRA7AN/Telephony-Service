package com.registry.telephony;

import com.registry.telephony.config.TelephonyProperties;
import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.boot.context.properties.EnableConfigurationProperties;
import org.springframework.scheduling.annotation.EnableAsync;
import org.springframework.scheduling.annotation.EnableScheduling;

@SpringBootApplication
@EnableConfigurationProperties(TelephonyProperties.class)
@EnableAsync
@EnableScheduling
public class TelephonyServiceApplication {
    public static void main(String[] args) {
        SpringApplication.run(TelephonyServiceApplication.class, args);
    }
}

