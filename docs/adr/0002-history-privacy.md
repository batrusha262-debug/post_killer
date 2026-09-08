# ADR 0002: history stores metadata, not request or response payloads

**Status:** accepted  
**Date:** 2026-09-08

## Context

Executed requests frequently carry API tokens, cookies, personally identifiable
data and private endpoint details. A convenience history must not quietly become
another unencrypted cache of that material.

## Decision

The local execution history stores only: execution and request identifiers,
timestamp, completion kind, optional HTTP status, duration and response byte
count. It never stores request URL, query, headers, body, authentication,
cookies, response headers, response body or raw transport error text.

History is independently deletable and supports clearing per request. Any future
full response retention is a separate opt-in feature, must use an explicit size
limit, redaction policy and separate ADR.

## Consequences

- The response viewer can show the current response but cannot reopen an old
  payload from history.
- A history row can safely outlive a deleted request as an anonymous audit
  record, if its foreign-key policy permits it.
- Diagnosing transport failures relies on typed categories rather than captured
  sensitive text.
