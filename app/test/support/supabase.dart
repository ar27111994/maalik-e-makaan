import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// The project URL of [MockSupabase].
const supabaseUrl = 'https://abcdefgh.supabase.co';

/// A [SupabaseClient] whose HTTP requests go to [respond] instead of the
/// network; every request is kept in [requests], so a test asserts exactly
/// what a repository sent.
final class MockSupabase {
  new(this.respond) {
    addTearDown(client.dispose);
  }

  /// Answers one request.
  Future<http.Response> Function(http.Request request) respond;

  final requests = <http.Request>[];

  late final SupabaseClient client = SupabaseClient(
    supabaseUrl,
    'sb_publishable_test',
    httpClient: MockClient((request) async {
      requests.add(request);
      final response = await respond(request);
      // Clients read the request back from the response, as from a real one.
      return http.Response.bytes(
        response.bodyBytes,
        response.statusCode,
        headers: response.headers,
        request: request,
      );
    }),
    authOptions: const AuthClientOptions(autoRefreshToken: false),
  );

  /// The only request sent.
  http.Request get request => requests.single;
}

/// A JSON response.
http.Response jsonResponse(Object? body, {int status = 200}) => http.Response(
  jsonEncode(body),
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

/// A PostgREST error response.
http.Response postgrestError(
  String code, {
  int status = 400,
  String message = 'refused',
  String? hint,
}) => jsonResponse({
  'code': code,
  'message': message,
  'details': null,
  'hint': hint,
}, status: status);

/// An Edge Function error envelope.
http.Response functionError(
  int status,
  String code, {
  Map<String, Object?>? details,
}) => jsonResponse({
  'error': {
    'code': code,
    'message': 'x',
    'details': ?details,
    'request_id': 'r1',
  },
}, status: status);

/// A matcher for a request's decoded JSON body.
Object? bodyOf(http.Request request) => jsonDecode(request.body);
