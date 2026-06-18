package com.registry.telephony.persistence;

import java.util.List;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;

/**
 * Repository for the call_event_log audit table.
 */
public interface CallEventLogRepository extends JpaRepository<CallEventLog, UUID> {

    List<CallEventLog> findByCallUniqueIdOrderByReceivedAtAsc(String callUniqueId);
}
