import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:maalik_e_makaan/src/auth/auth_repository.dart';
import 'package:maalik_e_makaan/src/config/app_config.dart';
import 'package:maalik_e_makaan/src/core/failure.dart';
import 'package:maalik_e_makaan/src/data/cache/swr_cache.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../support/fakes.dart' show MemoryStore;

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
        const SignedOut(cause: SignOutCause.accountDeleted),
        isNot(const SignedOut()),
      );
      expect(
        const SignedIn(userId: 'a', email: null),
        isNot(const SignedIn(userId: 'a', email: 'x')),
      );
      expect(
        const RecoveringPassword(userId: 'a').hashCode,
        const RecoveringPassword(userId: 'a').hashCode,
      );
      expect(const RecoveringPassword(userId: 'a'), isNot(const SignedOut()));
      expect(
        const SignedIn(userId: 'a', email: 'x').hashCode,
        const SignedIn(userId: 'a', email: 'x').hashCode,
      );
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

    test('on iOS the links come back through the app scheme', () async {
      final native = SupabaseAuthRepository(
        auth: auth,
        cache: cache,
        config: _config,
        nativeLinks: true,
      );
      const callback =
          'io.github.ar27111994.maalikemakaan://app.example.pk/auth/callback';
      when(
        () => auth.resetPasswordForEmail(
          any(),
          redirectTo: any(named: 'redirectTo'),
        ),
      ).thenAnswer((_) async {});
      await native.sendPasswordReset('a@b.pk');
      verify(() => auth.resetPasswordForEmail('a@b.pk', redirectTo: callback))
          .called(1);
    });

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
  group('sign-out reasons', () {
    test(
      'a sign-out the user asked for is remembered until a sign-in',
      () async {
        when(() => auth.signOut()).thenAnswer((_) async {
          changes.add(const AuthState(AuthChangeEvent.signedOut, null));
        });
        final statuses = <AuthStatus>[];
        final subscription = repository.watch().listen(statuses.add);
        await pumpEventQueue();
        await repository.signOut(cause: SignOutCause.accountDeleted);
        await pumpEventQueue();
        expect(
          repository.status,
          const SignedOut(cause: SignOutCause.accountDeleted),
        );
        expect(
          statuses.last,
          const SignedOut(cause: SignOutCause.accountDeleted),
        );
        changes.add(AuthState(AuthChangeEvent.signedIn, _session()));
        await pumpEventQueue();
        changes.add(const AuthState(AuthChangeEvent.signedOut, null));
        await pumpEventQueue();
        await subscription.cancel();
        // A later session that ends by itself carries no reason.
        expect(statuses.last, const SignedOut());
      },
    );

    test('a reset link clears the remembered reason', () async {
      when(() => auth.signOut()).thenAnswer((_) async {});
      await repository.signOut();
      expect(
        repository.status,
        const SignedOut(cause: SignOutCause.userRequest),
      );
      final subscription = repository.watch().listen((_) {});
      await pumpEventQueue();
      changes.add(AuthState(AuthChangeEvent.passwordRecovery, _session()));
      await pumpEventQueue();
      changes.add(const AuthState(AuthChangeEvent.signedOut, null));
      await pumpEventQueue();
      await subscription.cancel();
      expect(repository.status, const SignedOut());
    });
  });

  group('reauthenticate', () {
    test('signs in again with the current address', () async {
      when(() => auth.currentUser).thenReturn(_user());
      when(
        () => auth.signInWithPassword(
          email: any(named: 'email'),
          password: any(named: 'password'),
        ),
      ).thenAnswer((_) async => AuthResponse(session: _session()));
      await repository.reauthenticate('Secret1234');
      verify(
        () => auth.signInWithPassword(
          email: 'ali.raza@example.com',
          password: 'Secret1234',
        ),
      ).called(1);
    });

    test('without a user the session has ended', () async {
      when(() => auth.currentUser).thenReturn(null);
      await expectLater(
        repository.reauthenticate('x'),
        throwsA(isA<SessionExpired>()),
      );
    });

    test('a wrong password is invalid_credentials', () async {
      when(() => auth.currentUser).thenReturn(_user());
      when(
        () => auth.signInWithPassword(
          email: any(named: 'email'),
          password: any(named: 'password'),
        ),
      ).thenThrow(const AuthApiException('bad', code: 'invalid_credentials'));
      await expectLater(
        repository.reauthenticate('x'),
        throwsA(
          isA<RejectedFailure>().having(
            (f) => f.reason,
            'reason',
            'invalid_credentials',
          ),
        ),
      );
    });
  });

  group('completeEmailLink', () {
    Matcher rejected(String reason) => throwsA(
      isA<RejectedFailure>().having((f) => f.reason, 'reason', reason),
    );

    setUp(() {
      when(() => auth.exchangeCodeForSession(any())).thenAnswer(
        (_) async =>
            AuthSessionUrlResponse(session: _session(), redirectType: null),
      );
    });

    test('exchanges the code of the link', () async {
      await repository.completeEmailLink(
        Uri.parse('https://app.example.pk/auth/callback?code=abc123'),
      );
      verify(() => auth.exchangeCodeForSession('abc123')).called(1);
    });

    test('reads a code from the fragment too', () async {
      await repository.completeEmailLink(
        Uri.parse('https://app.example.pk/auth/callback#code=xyz'),
      );
      verify(() => auth.exchangeCodeForSession('xyz')).called(1);
    });

    test('a link Supabase refused says why, without a request', () async {
      await expectLater(
        repository.completeEmailLink(
          Uri.parse(
            '/auth/callback?error=access_denied&error_code=otp_expired'
            '&error_description=Email+link+is+invalid+or+has+expired',
          ),
        ),
        rejected('link_expired'),
      );
      await expectLater(
        repository.completeEmailLink(
          Uri.parse('/auth/callback#error=server_error'),
        ),
        rejected('link_invalid'),
      );
      await expectLater(
        repository.completeEmailLink(Uri.parse('/auth/callback')),
        rejected('link_invalid'),
      );
      await expectLater(
        repository.completeEmailLink(Uri.parse('/auth/callback?code=')),
        rejected('link_invalid'),
      );
      verifyNever(() => auth.exchangeCodeForSession(any()));
    });

    test('a link asked for on another device', () async {
      when(() => auth.exchangeCodeForSession(any())).thenThrow(
        const AuthException(
          'Code verifier could not be found in local storage.',
        ),
      );
      await expectLater(
        repository.completeEmailLink(Uri.parse('/auth/callback?code=abc')),
        rejected('link_other_device'),
      );
    });

    test('the server refusing the code', () async {
      when(() => auth.exchangeCodeForSession(any())).thenThrow(
        const AuthApiException(
          'expired',
          statusCode: '403',
          code: 'flow_state_expired',
        ),
      );
      await expectLater(
        repository.completeEmailLink(Uri.parse('/auth/callback?code=abc')),
        rejected('link_expired'),
      );
      when(() => auth.exchangeCodeForSession(any())).thenThrow(
        const AuthApiException(
          'not found',
          statusCode: '404',
          code: 'flow_state_not_found',
        ),
      );
      await expectLater(
        repository.completeEmailLink(Uri.parse('/auth/callback?code=abc')),
        rejected('link_invalid'),
      );
    });

    test('no connection while exchanging', () async {
      when(() => auth.exchangeCodeForSession(any()))
          .thenThrow(AuthRetryableFetchException(message: 'offline'));
      await expectLater(
        repository.completeEmailLink(Uri.parse('/auth/callback?code=abc')),
        throwsA(isA<NetworkFailure>()),
      );
    });
  });
}
