-- Supports date-range reporting for successful transfers.
-- Adds storage and maintenance work when qualifying rows are written.
CREATE INDEX idx_p2_successful_transfer_date
ON public.transactions (created_at)
WHERE transaction_type = 'TRANSFER'
  AND status = 'SUCCESSFUL';

SELECT
    indexname,
    indexdef,
    pg_size_pretty(
        pg_relation_size('public.idx_p2_successful_transfer_date'::regclass)
    ) AS index_size
FROM pg_indexes
WHERE schemaname = 'public'
  AND indexname = 'idx_p2_successful_transfer_date';
