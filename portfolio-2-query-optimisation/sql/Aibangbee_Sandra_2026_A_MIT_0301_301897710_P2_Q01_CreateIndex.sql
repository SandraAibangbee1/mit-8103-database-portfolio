-- Q01: Find a wallet's ledger entries in newest-first order.
-- wallet_id supports filtering; the remaining columns match ORDER BY.
-- The index uses storage and adds maintenance work when entries are written.

CREATE INDEX idx_p2_ledger_wallet_recent
ON ledger_entries (
    wallet_id,
    created_at DESC,
    ledger_entry_id DESC
);

SELECT
    indexname,
    indexdef,
    pg_size_pretty(
        pg_relation_size('public.idx_p2_ledger_wallet_recent'::regclass)
    ) AS index_size
FROM pg_indexes
WHERE schemaname = 'public'
  AND indexname = 'idx_p2_ledger_wallet_recent';