import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:maalik_e_makaan/src/auth/auth_repository.dart';
import 'package:maalik_e_makaan/src/config/app_config.dart';
import 'package:maalik_e_makaan/src/core/failure.dart';
import 'package:maalik_e_makaan/src/data/cache/swr_cache.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/cache/swr_cache_test.dart' show MemoryStore;

class _MockAuth extends Mock implements GoTrueClient;

const _userId = '0192d0c4-7a5e-7c1e-9a4b-2f6d1e3c8a90';

User _user({String email = 'ali.raza@example.com'}) => User(
  id: _userId,
  appMetadata: const {},
  userMetadata: const {},
  aud: 'authenticated',
  email: email,
  createdAt: '2026-11-01T00:00:00Z',
);

Session _session() =>
    Session(accessToken: 'a', tokenType: 'bearer', user: _user());

final _config = AppConfig.parse({
  'SUPABASE_URL': 'https://abcdefgh.supabase.co',
  'SUPABASE_PUBLISHABLE_KEY': 'sb_publishable_abc',
  'APP_URL': 'https://app.example.pk',
});

void main() {
  late _MockAuth auth;
  late MemoryStore store;
  late SwrCache cache;
  late StreamController<AuthState> changes;
  late SupabaseAuthRepository repository;

  setUpAll(() {
    registerFallbackValue(UserAttributes());
    registerFallbackValue(OtpType.signup);
    registerFallbackValue(SignOutScope.local);
  });

  setUp(() {
    auth = _MockAuth();
    store = MemoryStore();
    cache = SwrCache(store);
    // Broadcast: closing it does not wait for a listener.
    changes = StreamController<AuthState>.broadcast();
    when(() => auth.onAuthStateChange).thenAnswer((_) => changes.stream);
    when(() => auth.currentSession).thenReturn(null);
    repository = SupabaseAuthRepository(
      auth: auth,
      cache: cache,
      config: _config,
    );
  });

  tearDown(() => changes.close());

  group('status', () {
    test('follows the current session', () {
      expect(repository.status, const SignedOut());
      when(() => auth.currentSession).thenReturn(_session());
      expect(
        repository.status,
        const SignedIn(userId: _userId, email: 'ali.raza@example.com'),
      );
    });

    test(
      'watch starts with the current status and follows the events',
      () async {
        final statuses = <AuthStatus>[];
        final subscription = repository.watch().listen(statuses.add);
        await pumpEventQueue();
        changes
          ..add(AuthState(AuthChangeEvent.signedIn, _session()))
          ..add(AuthState(AuthChangeEvent.passwordRecovery, _session()))
          ..add(AuthState(AuthChangeEvent.tokenRefreshed, _session()))
          ..add(AuthState(AuthChangeEvent.userUpdated, _session()))
          ..add(const AuthState(AuthChangeEvent.signedOut, null));
        await pumpEventQueue();
        await subscription.cancel();
        expect(statuses, const [
          SignedOut(),
          SignedIn(userId: _userId, email: 'ali.raza@example.com'),
          RecoveringPassword(userId: _userId),
          RecoveringPassword(userId: _userId),
          SignedIn(userId: _userId, email: 'ali.raza@example.com'),
          SignedOut(),
        ]);
      },
    );

    test('a sign-out from anywhere clears the cache', () async {
      await cache.write(_userId, 'dashboard', 1);
      final subscription = repository.watch().listen((_) {});
      await pumpEventQueue();
      changes.add(const AuthState(AuthChangeEvent.signedOut, null));
      await pumpEventQueue();
      await subscription.cancel();
      expect(store.values, isEmpty);
    });

    test('statuses compare by value', () {
      expect(const SignedOut().hashCode, const SignedOut().hashCode);
      expect(
        const SignedIn(userId: 'a', email: null),
        isNot(const SignedIn(userId: 'a', email: 'x')),
      );
      expect(
        const RecoveringPassword(userId: 'a').hashCode,
        const RecoveringPassword(userId: 'a').hashCode,
      );
      expect(const RecoveringPassword(userId: 'a'), isNot(const SignedOut()));
    });
  });

  group('actions', () {
    test('signIn trims the e-mail', () async {
      when(
        () => auth.signInWithPassword(
          email: any(named: 'email'),
          password: any(named: 'password'),
        ),
      ).thenAnswer((_) async => AuthResponse(session: _session()));
      await repository.signIn(email: ' ali@example.com ', password: 'pw');
      verify(
        () => auth.signInWithPassword(email: 'ali@example.com', password: 'pw'),
      ).called(1);
    });

    test('signIn failures are AppFailures', () async {
      when(
        () => auth.signInWithPassword(
          email: any(named: 'email'),
          password: any(named: 'password'),
        ),
      ).thenThrow(const AuthException('bad', code: 'invalid_credentials'));
      await expectLater(
        repository.signIn(email: 'a@b.pk', password: 'x'),
        throwsA(
          isA<RejectedFailure>().having(
            (f) => f.reason,
            'reason',
            'invalid_credentials',
          ),
        ),
      );
    });

    test('signUp sends the name, language and callback URL', () async {
      when(
        () => auth.signUp(
          email: any(named: 'email'),
          password: any(named: 'password'),
          emailRedirectTo: any(named: 'emailRedirectTo'),
          data: any(named: 'data'),
        ),
      ).thenAnswer((_) async => AuthResponse(user: _user()));
      final outcome = await repository.signUp(
        email: 'ayesha@example.com ',
        password: 'secret123',
        fullName: '  Ayesha Khan ',
        languageCode: 'ur',
      );
      expect(outcome, SignUpOutcome.confirmationSent);
      verify(
        () => auth.signUp(
          email: 'ayesha@example.com',
          password: 'secret123',
          emailRedirectTo: 'https://app.example.pk/auth/callback',
          data: {'full_name': 'Ayesha Khan', 'locale': 'ur'},
        ),
      ).called(1);
    });

    test('signUp with a session signs in at once', () async {
      when(
        () => auth.signUp(
          email: any(named: 'email'),
          password: any(named: 'password'),
          emailRedirectTo: any(named: 'emailRedirectTo'),
          data: any(named: 'data'),
        ),
      ).thenAnswer((_) async => AuthResponse(session: _session()));
      expect(
        await repository.signUp(
          email: 'a@b.pk',
          password: 'secret123',
          fullName: 'A',
          languageCode: 'en',
        ),
        SignUpOutcome.signedIn,
      );
    });

    test(
      'resendConfirmation and sendPasswordReset use the callback URL',
      () async {
        when(
          () => auth.resend(
            type: any(named: 'type'),
            email: any(named: 'email'),
            emailRedirectTo: any(named: 'emailRedirectTo'),
          ),
        ).thenAnswer((_) async => ResendResponse());
        when(
          () => auth.resetPasswordForEmail(
            any(),
            redirectTo: any(named: 'redirectTo'),
          ),
        ).thenAnswer((_) async {});
        await repository.resendConfirmation(' a@b.pk');
        await repository.sendPasswordReset('a@b.pk ');
        verify(
          () => auth.resend(
            type: OtpType.signup,
            email: 'a@b.pk',
            emailRedirectTo: 'https://app.example.pk/auth/callback',
          ),
        ).called(1);
        verify(
          () => auth.resetPasswordForEmail(
            'a@b.pk',
            redirectTo: 'https://app.example.pk/auth/callback',
          ),
        ).called(1);
      },
    );

    test('updatePassword sends the new password', () async {
      when(() => auth.updateUser(any()))
          .thenAnswer((_) async => UserResponse.fromJson(_user().toJson()));
      await repository.updatePassword('newsecret1');
      final attributes =
          verify(() => auth.updateUser(captureAny())).captured.single
              as UserAttributes;
      expect(attributes.password, 'newsecret1');
    });

    test(
      'signOut clears the cache even when the server cannot be reached',
      () async {
        await cache.write(_userId, 'q', 1);
        when(() => auth.signOut(scope: any(named: 'scope')))
            .thenThrow(AuthRetryableFetchException(message: 'offline'));
        await expectLater(repository.signOut(), throwsA(isA<NetworkFailure>()));
        expect(store.values, isEmpty);
        verify(() => auth.signOut()).called(1);
      },
    );
  });
}
