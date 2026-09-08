-- Execution history intentionally stores metadata only. Request/response payloads,
-- headers, cookies, URLs, credentials, and raw error messages have no columns here.
-- History is deleted with its request: this makes deleting a request a reliable
-- privacy boundary and avoids retaining metadata the user can no longer manage.
CREATE TABLE execution_history (
    execution_id TEXT PRIMARY KEY NOT NULL CHECK (length(trim(execution_id)) > 0),
    request_id TEXT NOT NULL REFERENCES requests(id) ON DELETE CASCADE,
    executed_at_unix_ms INTEGER NOT NULL CHECK (executed_at_unix_ms >= 0),
    status_code INTEGER CHECK (status_code BETWEEN 100 AND 599),
    duration_ms INTEGER NOT NULL CHECK (duration_ms >= 0),
    response_size_bytes INTEGER NOT NULL CHECK (response_size_bytes >= 0),
    result_kind TEXT NOT NULL CHECK (result_kind IN ('response', 'error', 'cancelled')),
    error_category TEXT CHECK (
        error_category IS NULL OR error_category IN (
            'timeout', 'dns', 'connection', 'tls', 'proxy', 'redirect',
            'request_body', 'response_body', 'other'
        )
    ),
    CHECK (
        (result_kind = 'response' AND error_category IS NULL) OR
        (result_kind = 'error' AND error_category IS NOT NULL AND status_code IS NULL) OR
        (result_kind = 'cancelled' AND error_category IS NULL AND status_code IS NULL)
    )
);

CREATE INDEX execution_history_request_time_idx
    ON execution_history(request_id, executed_at_unix_ms DESC, execution_id DESC);
