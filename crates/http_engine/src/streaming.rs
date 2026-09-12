use super::*;

/// Streams response metadata and chunks to a caller-owned channel. The caller
/// owns the task that awaits this function; no background task is detached.
pub async fn execute_streaming(
    request: RequestDefinition,
    options: ExecutionOptions,
    cancellation: CancellationToken,
    events: mpsc::Sender<ExecutionEvent>,
) -> Result<ResponsePayload, ExecuteError> {
    let execution_id = request.id.clone();
    // The deadline includes channel backpressure, not only socket I/O.
    let result = tokio::time::timeout(
        options.timeout,
        execute_streaming_inner(&request, options.clone(), &cancellation, &events),
    )
    .await
    .unwrap_or(Err(ExecuteError::Timeout));

    let terminal_event = match &result {
        Ok(payload) => ExecutionEvent::Completed {
            execution_id,
            duration_millis: payload.duration.as_millis().try_into().unwrap_or(u64::MAX),
        },
        Err(ExecuteError::Cancelled) => ExecutionEvent::Cancelled { execution_id },
        Err(error) => ExecutionEvent::Failed {
            execution_id,
            message: error.to_string(),
        },
    };
    send_terminal_event(&events, terminal_event, options.timeout).await?;
    result
}

async fn execute_streaming_inner(
    request: &RequestDefinition,
    options: ExecutionOptions,
    cancellation: &CancellationToken,
    events: &mpsc::Sender<ExecutionEvent>,
) -> Result<ResponsePayload, ExecuteError> {
    request.validate().map_err(ExecuteError::InvalidRequest)?;
    check_cancelled(cancellation)?;

    let builder = build_request(request, &options)?;
    let started_at = std::time::Instant::now();
    let response = tokio::select! {
        _ = cancellation.cancelled() => return Err(ExecuteError::Cancelled),
        result = builder.send() => result.map_err(classify_transport)?,
    };
    let status = response.status().as_u16();
    let effective_url = response.url().as_str().to_owned();
    let headers: Vec<_> = response
        .headers()
        .iter()
        .map(|(name, value)| ResponseHeader {
            name: name.as_str().to_owned(),
            value: value.as_bytes().to_vec(),
        })
        .collect();
    if response
        .content_length()
        .is_some_and(|length| length > options.max_response_bytes as u64)
    {
        return Err(ExecuteError::ResponseTooLarge {
            limit: options.max_response_bytes,
        });
    }
    send_stream_event(
        events,
        cancellation,
        ExecutionEvent::ResponseStarted {
            execution_id: request.id.clone(),
            status,
            headers: headers.clone(),
            effective_url: effective_url.clone(),
        },
    )
    .await?;

    let mut body = Vec::new();
    let mut chunks = response.bytes_stream();
    loop {
        let next_chunk = tokio::select! {
            _ = cancellation.cancelled() => return Err(ExecuteError::Cancelled),
            chunk = chunks.next() => chunk,
        };
        let Some(chunk) = next_chunk else {
            break;
        };
        let chunk = chunk.map_err(classify_transport)?;
        if chunk.len() > options.max_response_bytes.saturating_sub(body.len()) {
            return Err(ExecuteError::ResponseTooLarge {
                limit: options.max_response_bytes,
            });
        }
        body.extend_from_slice(&chunk);
        send_stream_event(
            events,
            cancellation,
            ExecutionEvent::BodyChunk {
                execution_id: request.id.clone(),
                bytes: chunk.to_vec(),
            },
        )
        .await?;
    }
    Ok(ResponsePayload {
        request_id: request.id.clone(),
        status,
        headers,
        body,
        effective_url,
        duration: started_at.elapsed(),
    })
}

fn check_cancelled(cancellation: &CancellationToken) -> Result<(), ExecuteError> {
    if cancellation.is_cancelled() {
        Err(ExecuteError::Cancelled)
    } else {
        Ok(())
    }
}

async fn send_stream_event(
    events: &mpsc::Sender<ExecutionEvent>,
    cancellation: &CancellationToken,
    event: ExecutionEvent,
) -> Result<(), ExecuteError> {
    tokio::select! {
        _ = cancellation.cancelled() => Err(ExecuteError::Cancelled),
        result = events.send(event) => result.map_err(|_| ExecuteError::EventReceiverDropped),
    }
}

async fn send_terminal_event(
    events: &mpsc::Sender<ExecutionEvent>,
    event: ExecutionEvent,
    timeout: Duration,
) -> Result<(), ExecuteError> {
    // A receiver that remains alive without draining must not retain this task.
    tokio::time::timeout(timeout, events.send(event))
        .await
        .map_err(|_| ExecuteError::Timeout)?
        .map_err(|_| ExecuteError::EventReceiverDropped)
}
