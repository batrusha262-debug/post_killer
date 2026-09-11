import 'dart:convert';

import '../../../rust/api.dart';
import '../domain/workspace_models.dart';

abstract interface class RequestExecutor {
  Future<RequestExecutionView> execute(RequestTab request);
}

class UnavailableRequestExecutor implements RequestExecutor {
  const UnavailableRequestExecutor();

  @override
  Future<RequestExecutionView> execute(RequestTab request) async =>
      RequestExecutionView.error(
        requestId: request.id,
        error: 'Request engine is unavailable.',
      );
}

class FrbRequestExecutor implements RequestExecutor {
  const FrbRequestExecutor();

  @override
  Future<RequestExecutionView> execute(RequestTab request) async {
    final outcome = await executeRequest(request: _toFfiRequest(request));
    final response = outcome.response;
    if (response != null) {
      return RequestExecutionView.response(
        requestId: request.id,
        status: response.status,
        durationMillis: response.durationMillis.toInt(),
        headers: [
          for (final header in response.headers)
            RequestResponseHeader(
              name: header.name,
              value: utf8.decode(header.value, allowMalformed: true),
            ),
        ],
        body: utf8.decode(response.body, allowMalformed: true),
      );
    }
    return RequestExecutionView.error(
      requestId: request.id,
      error: outcome.error?.message ?? 'Request execution failed unexpectedly.',
    );
  }

  FfiRequest _toFfiRequest(RequestTab request) => FfiRequest(
    id: request.id,
    name: request.title,
    method: switch (request.method) {
      HttpMethod.get => FfiRequestMethod.get_,
      HttpMethod.post => FfiRequestMethod.post,
      HttpMethod.put => FfiRequestMethod.put,
      HttpMethod.patch => FfiRequestMethod.patch,
      HttpMethod.delete => FfiRequestMethod.delete,
      HttpMethod.head => FfiRequestMethod.head,
      HttpMethod.options => FfiRequestMethod.options,
    },
    url: request.url,
    queryParams: _keyValues(request.query),
    headers: _keyValues(request.headers),
    body: FfiRequestBody(
      kind: switch (request.bodyFormat) {
        RequestBodyFormat.json when request.body.isEmpty =>
          FfiRequestBodyKind.empty,
        RequestBodyFormat.json => FfiRequestBodyKind.json,
        RequestBodyFormat.text => FfiRequestBodyKind.text,
        RequestBodyFormat.formUrlEncoded => FfiRequestBodyKind.formUrlEncoded,
        RequestBodyFormat.multipart => FfiRequestBodyKind.multipart,
      },
      content: request.body,
      fields: _keyValues(request.bodyFields),
    ),
    auth: FfiRequestAuth(
      kind: switch (request.auth.kind) {
        RequestAuthKind.none => FfiRequestAuthKind.none,
        RequestAuthKind.basic => FfiRequestAuthKind.basic,
        RequestAuthKind.bearer => FfiRequestAuthKind.bearer,
        RequestAuthKind.apiKey => FfiRequestAuthKind.apiKey,
      },
      username: request.auth.username,
      password: request.auth.password,
      token: request.auth.token,
      key: request.auth.key,
      value: request.auth.value,
      placement: request.auth.placement == ApiKeyPlacement.header
          ? FfiApiKeyPlacement.header
          : FfiApiKeyPlacement.query,
    ),
  );

  List<FfiKeyValue> _keyValues(List<RequestKeyValue> values) => [
    for (final value in values)
      FfiKeyValue(key: value.key, value: value.value, enabled: value.enabled),
  ];
}
