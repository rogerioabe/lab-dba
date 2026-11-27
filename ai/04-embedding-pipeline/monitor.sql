    -- monitor.sql: health of the embedding pipeline
    SELECT count(*)                                       AS pending,
           count(*) FILTER (WHERE attempts > 0)           AS failing,
           count(*) FILTER (WHERE attempts >= 5)          AS dead,
           date_trunc('second', max(now() - enqueued_at)) AS oldest_job_age
    FROM kb.embedding_queue;
