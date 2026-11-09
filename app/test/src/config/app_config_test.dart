import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:maalik_e_makaan/src/config/app_config.dart';

String _jwt(Map<String, Object?> payload) {
  String part(Map<String, Object?> json) =>
      base64Url.encode(utf8.encode(jsonEncode(json))).replaceAll('=', '');
  return '${part({'alg': 'HS256'})}.${part(payload)}.signature';
}

Map<String, String> _values([Map<String, String> overrides = const {}]) => {
  'SUPABASE_URL': 'https://abcdefgh.supabase.co',
  'SUPABASE_PUBLISHABLE_KEY': 'sb_publishable_abc123',
  'APP_URL': 'https://app.maalikemakaan.pk',
  'ENVIRONMENT': 'production',
  ...overrides,
};

Matcher _refuses(String variable, String problem) => throwsA(
  isA<ConfigException>()
      .having((e) => e.variable, 'variable', variable)
      .having((e) => e.problem, 'problem', contains(problem)),
);

void main() {
  test('parses a production configuration', () {
    final config = AppConfig.parse(_values());
    expect(config.supabaseUrl, Uri.parse('https://abcdefgh.supabase.co'));
    expect(config.supabasePublishableKey, 'sb_publishable_abc123');
    expect(config.appUrl, Uri.parse('https://app.maalikemakaan.pk'));
    expect(config.environment, AppEnvironment.production);
    expect(
      config.authCallbackUrl,
      Uri.parse('https://app.maalikemakaan.pk/auth/callback'),
    );
  });

  test('iOS e-mail links come back under the app scheme, same path', () {
    final config = AppConfig.parse(
      _values({'APP_URL': 'https://example.pk/app'}),
    );
    expect(
      config.authCallbackUrlFor(nativeScheme: true).toString(),
      'io.github.ar27111994.maalikemakaan://example.pk/app/auth/callback',
    );
    expect(
      config.authCallbackUrlFor(nativeScheme: false),
      config.authCallbackUrl,
    );
  });

  test('trims values, drops trailing slashes and keeps an app path', () {
    final config = AppConfig.parse(
      _values({
        'SUPABASE_URL': ' https://abcdefgh.supabase.co/ ',
        'APP_URL': 'https://example.pk/app//',
      }),
    );
    expect(config.supabaseUrl.toString(), 'https://abcdefgh.supabase.co');
    expect(config.appUrl.toString(), 'https://example.pk/app');
    expect(
      config.authCallbackUrl.toString(),
      'https://example.pk/app/auth/callback',
    );
  });

  test('an empty environment means production', () {
    expect(
      AppConfig.parse(_values({'ENVIRONMENT': ''})).environment,
      AppEnvironment.production,
    );
    expect(
      AppConfig.parse(_values({'ENVIRONMENT': 'staging'})).environment,
      AppEnvironment.staging,
    );
    expect(
      () => AppConfig.parse(_values({'ENVIRONMENT': 'prod'})),
      _refuses('ENVIRONMENT', 'local, staging or production'),
    );
  });

  test('plain http is allowed only locally or on a loopback host', () {
    final local = AppConfig.parse(
      _values({
        'ENVIRONMENT': 'local',
        'SUPABASE_URL': 'http://192.168.1.20:54321',
        'APP_URL': 'http://192.168.1.20:8080',
      }),
    );
    expect(local.supabaseUrl.scheme, 'http');
    expect(
      AppConfig.parse(_values({'SUPABASE_URL': 'http://127.0.0.1:54321'}))
          .supabaseUrl
          .port,
      54321,
    );
    expect(
      () =>
          AppConfig.parse(_values({'SUPABASE_URL': 'http://abc.supabase.co'})),
      _refuses('SUPABASE_URL', 'https'),
    );
  });

  test('refuses missing, relative, credentialed and path-carrying URLs', () {
    expect(
      () => AppConfig.parse(_values({'SUPABASE_URL': ''})),
      _refuses('SUPABASE_URL', 'required'),
    );
    expect(
      () => AppConfig.parse(_values({'APP_URL': 'app.example.pk'})),
      _refuses('APP_URL', 'absolute'),
    );
    expect(
      () => AppConfig.parse(_values({'APP_URL': 'https://u:p@example.pk'})),
      _refuses('APP_URL', 'credentials'),
    );
    expect(
      () => AppConfig.parse(_values({'APP_URL': 'https://example.pk/?x=1'})),
      _refuses('APP_URL', 'query'),
    );
    expect(
      () => AppConfig.parse(
        _values({'SUPABASE_URL': 'https://abc.supabase.co/rest'}),
      ),
      _refuses('SUPABASE_URL', 'origin'),
    );
  });

  test('accepts a publishable key or a legacy anon JWT', () {
    final anon = _jwt({'role': 'anon', 'iss': 'supabase'});
    expect(
      AppConfig.parse(_values({'SUPABASE_PUBLISHABLE_KEY': anon}))
          .supabasePublishableKey,
      anon,
    );
  });

  test('refuses secret keys, service-role JWTs and anything else', () {
    expect(
      () => AppConfig.parse(
        _values({'SUPABASE_PUBLISHABLE_KEY': 'sb_secret_xyz'}),
      ),
      _refuses('SUPABASE_PUBLISHABLE_KEY', 'secret key'),
    );
    expect(
      () => AppConfig.parse(
        _values({
          'SUPABASE_PUBLISHABLE_KEY': _jwt({'role': 'service_role'}),
        }),
      ),
      _refuses('SUPABASE_PUBLISHABLE_KEY', 'service_role key'),
    );
    for (final key in [
      '',
      'abc',
      'a.b.c',
      _jwt({'sub': 'x'}),
    ]) {
      expect(
        () => AppConfig.parse(_values({'SUPABASE_PUBLISHABLE_KEY': key})),
        throwsA(isA<ConfigException>()),
        reason: key,
      );
    }
  });

  test('the exception names the define, never its value', () {
    final error = ConfigException('APP_URL', 'must use https');
    expect(error.toString(), 'ConfigException: APP_URL must use https');
  });

  test('fromEnvironment reads the compile-time defines', () {
    // Tests run without defines, so the URL is missing.
    expect(AppConfig.fromEnvironment, _refuses('SUPABASE_URL', 'required'));
  });
}
