package com.registry.telephony.persistence;

import java.time.Instant;
import java.util.List;
import java.util.Optional;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface CallLeadIngestLogRepository extends JpaRepository<CallLeadIngestLog, UUID> {

    boolean existsByIdempotencyKey(String idempotencyKey);

    Optional<CallLeadIngestLog> findByIdempotencyKey(String idempotencyKey);

    @Query(
            """
            SELECT l FROM CallLeadIngestLog l
            WHERE l.processingStatus IN :statuses
            AND l.updatedAt < :cutoff
            """)
    List<CallLeadIngestLog> findStale(
            @Param("statuses") List<CallLeadProcessingStatus> statuses, @Param("cutoff") Instant cutoff);
}

