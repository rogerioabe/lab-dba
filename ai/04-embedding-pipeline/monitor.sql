-- monitor.sql: health of the embedding pipeline, with a diagnosis
WITH queue AS (
    SELECT count(*)                                       AS pending,
           count(*) FILTER (WHERE attempts > 0)           AS failing,
           count(*) FILTER (WHERE attempts >= 5)          AS dead,
           date_trunc('second', max(now() - enqueued_at)) AS oldest_job_age
    FROM kb.embedding_queue
),
workers AS (
    SELECT count(*) AS workers
    FROM pg_stat_activity
    WHERE usename = 'embed_worker'
),
last_err AS (
    SELECT left(last_error, 50) AS last_error
    FROM kb.embedding_queue
    WHERE last_error IS NOT NULL
    ORDER BY id DESC
    LIMIT 1
)
SELECT queue.*, workers.workers, last_err.last_error,
       CASE
           WHEN queue.pending = 0    THEN 'ok: queue empty'
           WHEN workers.workers = 0  THEN 'no worker connected'
           WHEN queue.dead > 0       THEN 'dead letters: read last_error'
           WHEN queue.failing > 0    THEN 'model failing: read last_error'
           ELSE                           'worker running, catching up'
       END AS diagnosis
FROM queue
CROSS JOIN workers
LEFT JOIN last_err ON true;
