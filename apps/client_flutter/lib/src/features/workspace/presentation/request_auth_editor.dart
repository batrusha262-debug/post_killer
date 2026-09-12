import 'package:flutter/material.dart';

import '../domain/workspace_models.dart';

class RequestAuthEditor extends StatelessWidget {
  const RequestAuthEditor({
    super.key,
    required this.auth,
    this.loginEndpoints = const [],
    required this.onChanged,
  });

  final RequestAuth auth;
  final List<SavedRequest> loginEndpoints;
  final ValueChanged<RequestAuth> onChanged;

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      const Text(
        'Authentication',
        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
      ),
      const SizedBox(height: 4),
      const Text(
        'Attach credentials only when this endpoint needs them.',
        style: TextStyle(fontSize: 12),
      ),
      const SizedBox(height: 16),
      DropdownButtonFormField<RequestAuthKind>(
        key: const Key('auth-kind-picker'),
        initialValue: auth.kind,
        decoration: const InputDecoration(labelText: 'Authentication'),
        items: const [
          DropdownMenuItem(value: RequestAuthKind.none, child: Text('No auth')),
          DropdownMenuItem(
            value: RequestAuthKind.basic,
            child: Text('Basic auth'),
          ),
          DropdownMenuItem(
            value: RequestAuthKind.bearer,
            child: Text('Bearer token'),
          ),
          DropdownMenuItem(
            value: RequestAuthKind.apiKey,
            child: Text('API key'),
          ),
        ],
        onChanged: (kind) {
          if (kind != null) onChanged(auth.copyWith(kind: kind));
        },
      ),
      const SizedBox(height: 16),
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest
              .withValues(alpha: .35),
          borderRadius: BorderRadius.circular(14),
        ),
        child: switch (auth.kind) {
          RequestAuthKind.none => const Text(
            'This request has no authentication.',
          ),
          RequestAuthKind.basic => _BasicFields(
            auth: auth,
            onChanged: onChanged,
          ),
          RequestAuthKind.bearer => _BearerFields(
            auth: auth,
            loginEndpoints: loginEndpoints,
            onChanged: onChanged,
          ),
          RequestAuthKind.apiKey => _ApiKeyFields(
            auth: auth,
            onChanged: onChanged,
          ),
        },
      ),
    ],
  );
}

class _BearerFields extends StatelessWidget {
  const _BearerFields({
    required this.auth,
    required this.loginEndpoints,
    required this.onChanged,
  });

  final RequestAuth auth;
  final List<SavedRequest> loginEndpoints;
  final ValueChanged<RequestAuth> onChanged;

  @override
  Widget build(BuildContext context) {
    final selectedExists = loginEndpoints.any(
      (request) => request.id == auth.loginRequestId,
    );
    return Column(
      children: [
        DropdownButtonFormField<String?>(
          key: const Key('auth-login-request-picker'),
          initialValue: selectedExists ? auth.loginRequestId : null,
          decoration: const InputDecoration(
            labelText: 'Get token from request',
            helperText:
                'This request runs first. Pick any saved login/auth endpoint.',
          ),
          items: [
            const DropdownMenuItem<String?>(
              value: null,
              child: Text('Enter token manually'),
            ),
            for (final request in loginEndpoints)
              DropdownMenuItem<String?>(
                value: request.id,
                child: Text('${request.method.label}  ${request.name}'),
              ),
          ],
          onChanged: (id) =>
              onChanged(auth.copyWith(loginRequestId: id, acquiredToken: null)),
        ),
        const SizedBox(height: 12),
        if (auth.loginRequestId != null) ...[
          _AuthField(
            fieldKey: const Key('auth-token-path-field'),
            label: 'Token JSON path',
            value: auth.tokenPath,
            errorText: auth.tokenPath.trim().isEmpty
                ? 'Token path is required'
                : null,
            onChanged: (value) => onChanged(auth.copyWith(tokenPath: value)),
          ),
          if (auth.acquiredToken case final _?) ...[
            const SizedBox(height: 12),
            Text(
              'Received token: ••••••••',
              key: const Key('auth-acquired-token'),
            ),
          ],
        ] else
          _AuthField(
            fieldKey: const Key('auth-token-field'),
            label: 'Token',
            value: auth.token,
            errorText: auth.token.trim().isEmpty ? 'Token is required' : null,
            obscureText: true,
            onChanged: (value) => onChanged(auth.copyWith(token: value)),
          ),
      ],
    );
  }
}

class _BasicFields extends StatelessWidget {
  const _BasicFields({required this.auth, required this.onChanged});
  final RequestAuth auth;
  final ValueChanged<RequestAuth> onChanged;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      _AuthField(
        fieldKey: const Key('auth-username-field'),
        label: 'Username',
        value: auth.username,
        errorText: auth.username.trim().isEmpty ? 'Username is required' : null,
        onChanged: (value) => onChanged(auth.copyWith(username: value)),
      ),
      const SizedBox(height: 12),
      _AuthField(
        fieldKey: const Key('auth-password-field'),
        label: 'Password',
        value: auth.password,
        errorText: auth.password.isEmpty ? 'Password is required' : null,
        obscureText: true,
        onChanged: (value) => onChanged(auth.copyWith(password: value)),
      ),
    ],
  );
}

class _ApiKeyFields extends StatelessWidget {
  const _ApiKeyFields({required this.auth, required this.onChanged});
  final RequestAuth auth;
  final ValueChanged<RequestAuth> onChanged;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      _AuthField(
        fieldKey: const Key('auth-api-key-field'),
        label: 'Key',
        value: auth.key,
        errorText: auth.key.trim().isEmpty ? 'Key is required' : null,
        onChanged: (value) => onChanged(auth.copyWith(key: value)),
      ),
      const SizedBox(height: 12),
      _AuthField(
        fieldKey: const Key('auth-api-value-field'),
        label: 'Value',
        value: auth.value,
        errorText: auth.value.isEmpty ? 'Value is required' : null,
        obscureText: true,
        onChanged: (value) => onChanged(auth.copyWith(value: value)),
      ),
      const SizedBox(height: 12),
      DropdownButtonFormField<ApiKeyPlacement>(
        key: const Key('auth-api-placement-picker'),
        initialValue: auth.placement,
        decoration: const InputDecoration(labelText: 'Add to'),
        items: const [
          DropdownMenuItem(
            value: ApiKeyPlacement.header,
            child: Text('Header'),
          ),
          DropdownMenuItem(
            value: ApiKeyPlacement.query,
            child: Text('Query parameter'),
          ),
        ],
        onChanged: (placement) {
          if (placement != null) {
            onChanged(auth.copyWith(placement: placement));
          }
        },
      ),
    ],
  );
}

class _AuthField extends StatelessWidget {
  const _AuthField({
    required this.fieldKey,
    required this.label,
    required this.value,
    required this.errorText,
    required this.onChanged,
    this.obscureText = false,
  });
  final Key fieldKey;
  final String label;
  final String value;
  final String? errorText;
  final ValueChanged<String> onChanged;
  final bool obscureText;

  @override
  Widget build(BuildContext context) => TextFormField(
    key: fieldKey,
    initialValue: value,
    obscureText: obscureText,
    enableSuggestions: !obscureText,
    autocorrect: false,
    onChanged: onChanged,
    decoration: InputDecoration(labelText: label, errorText: errorText),
  );
}
