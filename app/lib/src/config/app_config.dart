import 'dart:convert';

/// Which deployment the build talks to.
enum AppEnvironment {
  /// `supabase start` on a developer machine.
  local,

  /// A preview or staging project.
  staging,

  /// The live project.
  production;

  static AppEnvironment parse(String value) => switch (value) {
    'local' => local,
    'staging' => staging,
    'production' || '' => production,
    _ => throw ConfigException(
      'ENVIRONMENT',
      'must be local, staging or production',
    ),
  };
}

/// A build setting that is missing or unsafe. The message names the
/// `--dart-define` and says what is wrong, never the value.
final class ConfigException implements Exception {
  new(this.variable, this.problem);

  final String variable;
  final String problem;

  @override
  String toString() => 'ConfigException: $variable $problem';
}

/// The settings a build is compiled with (`--dart-define-from-file`).
///
/// Only public values belong here: the project URL, the publishable key and
/// the app's own URL. A secret key or a service-role JWT is refused, so a
/// misconfigured build fails at start instead of shipping a key that
/// bypasses row-level security.
final class AppConfig {
  const new({
    required this.supabaseUrl,
    required this.supabasePublishableKey,
    required this.appUrl,
    required this.environment,
  });

  /// Reads the compile-time defines.
  factory fromEnvironment() => AppConfig.parse({
    'SUPABASE_URL': const String.fromEnvironment('SUPABASE_URL'),
    'SUPABASE_PUBLISHABLE_KEY': const String.fromEnvironment(
      'SUPABASE_PUBLISHABLE_KEY',
    ),
    'APP_URL': const String.fromEnvironment('APP_URL'),
    'ENVIRONMENT': const String.fromEnvironment('ENVIRONMENT'),
  });

  /// Validates [values] (the define names mapped to their values).
  factory parse(Map<String, String> values) {
    String read(String name) => (values[name] ?? '').trim();

    final environment = AppEnvironment.parse(read('ENVIRONMENT'));
    final local = environment == AppEnvironment.local;
    return AppConfig(
      supabaseUrl: _origin('SUPABASE_URL', read('SUPABASE_URL'), local: local),
      supabasePublishableKey: _publishableKey(read('SUPABASE_PUBLISHABLE_KEY')),
      appUrl: _webUrl('APP_URL', read('APP_URL'), local: local),
      environment: environment,
    );
  }

  /// The Supabase project, e.g. `https://<ref>.supabase.co`.
  final Uri supabaseUrl;

  /// The publishable (formerly anon) key: safe in a client.
  final String supabasePublishableKey;

  /// Where the web app is served; e-mail links (verification, password
  /// reset, invitations) come back here.
  final Uri appUrl;

  final AppEnvironment environment;

  /// The URL scheme the iOS app registers (`CFBundleURLTypes` in
  /// `ios/Runner/Info.plist`); the hosted project's redirect URLs list
  /// [authCallbackUrlFor] with it (docs/operations.md, E-mail).
  static const nativeLinkScheme = 'io.github.ar27111994.maalikemakaan';

  /// The URL auth e-mails redirect to: the web app's callback, which the
  /// Android app also opens (App Links).
  Uri get authCallbackUrl =>
      appUrl.replace(path: '${appUrl.path}/auth/callback');

  /// [authCallbackUrl], or with [nativeScheme] the same address under
  /// [nativeLinkScheme]. The iOS app has no associated domain, so a link to
  /// the web would open the browser, which lacks the sign-in verifier the app
  /// stored; the scheme brings the link back to the app, and the router sees
  /// the same `/auth/callback` path.
  Uri authCallbackUrlFor({required bool nativeScheme}) => nativeScheme
      ? authCallbackUrl.replace(scheme: nativeLinkScheme)
      : authCallbackUrl;

  static Uri _webUrl(String name, String raw, {required bool local}) {
    if (raw.isEmpty) throw ConfigException(name, 'is required');
    final uri = Uri.tryParse(raw);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      throw ConfigException(name, 'must be an absolute URL');
    }
    if (uri.hasQuery || uri.hasFragment || uri.userInfo.isNotEmpty) {
      throw ConfigException(
        name,
        'must not carry credentials, a query or a fragment',
      );
    }
    final loopback = const {
      'localhost',
      '127.0.0.1',
      '[::1]',
      '::1',
    }.contains(uri.host);
    if (uri.scheme != 'https' &&
        !(uri.scheme == 'http' && (local || loopback))) {
      throw ConfigException(name, 'must use https');
    }
    final path = uri.path.replaceFirst(RegExp(r'/+$'), '');
    return uri.replace(path: path);
  }

  static Uri _origin(String name, String raw, {required bool local}) {
    final uri = _webUrl(name, raw, local: local);
    if (uri.path.isNotEmpty) {
      throw ConfigException(name, 'must be an origin, without a path');
    }
    return uri;
  }

  static String _publishableKey(String key) {
    const name = 'SUPABASE_PUBLISHABLE_KEY';
    if (key.isEmpty) throw ConfigException(name, 'is required');
    if (key.startsWith('sb_secret_')) {
      throw ConfigException(
        name,
        'is a secret key; clients take the publishable key',
      );
    }
    if (key.startsWith('sb_publishable_')) return key;
    // A legacy anon JWT is accepted; a service-role JWT is not.
    final parts = key.split('.');
    if (parts.length == 3) {
      final role = _jwtRole(parts[1]);
      if (role == 'anon') return key;
      if (role != null) {
        throw ConfigException(
          name,
          'is a $role key; clients take the publishable key',
        );
      }
    }
    throw ConfigException(name, 'is not a Supabase publishable key');
  }

  static String? _jwtRole(String payload) {
    try {
      final json = jsonDecode(
        utf8.decode(base64Url.decode(base64Url.normalize(payload))),
      );
      return json is Map<String, Object?> && json['role'] is String
          ? json['role']! as String
          : null;
    } on FormatException {
      return null;
    }
  }
}
