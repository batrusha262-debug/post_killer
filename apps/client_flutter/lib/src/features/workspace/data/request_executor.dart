import 'dart:convert';
import 'dart:typed_data';

import '../../../rust/api.dart';
import '../domain/workspace_models.dart';

abstract interface class RequestExecutor {
  Future<RequestExecutionView> execute(
    RequestTab request, {
    List<RequestKeyValue> variables = const [],
  });
}

class UnavailableRequestExecutor implements RequestExecutor {
  const UnavailableRequestExecutor();

  @override
  Future<RequestExecutionView> execute(
    RequestTab request, {
    List<RequestKeyValue> variables = const [],
  }) async => RequestExecutionView.error(
    requestId: request.id,
    error: 'Request engine is unavailable.',
  );
}

class FrbRequestExecutor implements RequestExecutor {
  const FrbRequestExecutor();

  @override
  Future<RequestExecutionView> execute(
    RequestTab request, {
    List<RequestKeyValue> variables = const [],
  }) async {
    final outcome = await executeRequestWithVariablesAndOptions(
      request: _toFfiRequest(request),
      variables: _keyValues(variables),
      options: FfiExecutionOptions(
        timeoutMillis: 30000,
        maxRedirects: 10,
        maxResponseBytes: 10 * 1024 * 1024,
        proxyUrl: request.network.proxyUrl.trim().isEmpty
            ? null
            : request.network.proxyUrl.trim(),
        customCaPem: request.network.customCaPem == null
            ? null
            : Uint8List.fromList(request.network.customCaPem!),
      ),
    );
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
        bodyBytes: response.body,
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
      files: [
        for (final file in request.bodyFiles)
          FfiMultipartFile(
            fieldName: file.fieldName,
            path: file.path,
            fileName: file.fileName,
            contentType: file.contentType,
          ),
      ],
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
