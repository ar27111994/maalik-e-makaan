import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maalik_e_makaan/src/app.dart';
import 'package:maalik_e_makaan/src/auth/auth_repository.dart';
import 'package:maalik_e_makaan/src/settings/app_settings.dart';

import 'settings/app_settings_test.dart' show MemorySettingsStore;

/// An [AuthRepository] whose status the test sets.
final class FakeAuthRepository implements AuthRepository {
  new(this._status);

  AuthStatus _status;
  final _changes = StreamController<AuthStatus>.broadcast();

  void emit(AuthStatus status) {
    _status = status;
    _changes.add(status);
  }

  @override
  AuthStatus get status => _status;

  @override
  Stream<AuthStatus> watch() async* {
    yield _status;
    yield* _changes.stream;
  }

  @override
  Future<void> signIn({
    required String email,
    required String password,
  }) async {}

  @override
  Future<SignUpOutcome> signUp({
    required String email,
    required String password,
    required String fullName,
    required String languageCode,
  }) async => SignUpOutcome.confirmationSent;

  @override
  Future<void> resendConfirmation(String email) async {}

  @override
  Future<void> sendPasswordReset(String email) async {}

  @override
  Future<void> updatePassword(String newPassword) async {}

  @override
  Future<void> signOut() async => emit(const SignedOut());
}

const _signedIn = SignedIn(userId: 'u1', email: 'ali@example.com');

Future<FakeAuthRepository> _pumpApp(
  WidgetTester tester, {
  required AuthStatus auth,
  String? language,
  Size size = const Size(390, 844),
}) async {
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final repository = FakeAuthRepository(auth);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        settingsStoreProvider.overrideWithValue(
          MemorySettingsStore({AppSettings.localeKey: ?language}),
        ),
        authRepositoryProvider.overrideWithValue(repository),
      ],
      child: const MaalikApp(),
    ),
  );
  await tester.pumpAndSettle();
  return repository;
}

void main() {
  testWidgets('first launch asks for the language, in English', (tester) async {
    await _pumpApp(tester, auth: const SignedOut());
    expect(
      find.text('Welcome to Maalik-e-Makaan is being built'),
      findsOneWidget,
    );
    expect(
      Directionality.of(tester.element(find.byType(Scaffold).first)),
      TextDirection.ltr,
    );
  });

  testWidgets('a signed-out user with a language lands on sign-in', (
    tester,
  ) async {
    await _pumpApp(tester, auth: const SignedOut(), language: 'en');
    expect(find.text('Sign in is being built'), findsOneWidget);
  });

  testWidgets(
    'a signed-in user sees the five sections, in Urdu and right to left',
    (tester) async {
      await _pumpApp(tester, auth: _signedIn, language: 'ur');
      for (final label in ['ہوم', 'کرایہ دار', 'حساب', 'جائیدادیں', 'مزید']) {
        expect(
          find.descendant(
            of: find.byType(NavigationBar),
            matching: find.text(label),
          ),
          findsOneWidget,
          reason: label,
        );
      }
      expect(find.byType(NavigationBar), findsOneWidget);
      expect(
        Directionality.of(tester.element(find.byType(NavigationBar))),
        TextDirection.rtl,
      );
    },
  );

  testWidgets('sections switch from the navigation bar', (tester) async {
    await _pumpApp(tester, auth: _signedIn, language: 'en');
    await tester.tap(find.text('Money'));
    await tester.pumpAndSettle();
    expect(find.text('Money is being built'), findsOneWidget);
  });

  testWidgets('wide windows use a navigation rail', (tester) async {
    await _pumpApp(
      tester,
      auth: _signedIn,
      language: 'en',
      size: const Size(1280, 800),
    );
    expect(find.byType(NavigationRail), findsOneWidget);
    expect(
      tester.widget<NavigationRail>(find.byType(NavigationRail)).extended,
      isTrue,
    );
  });

  testWidgets('signing out elsewhere returns to sign-in', (tester) async {
    final repository = await _pumpApp(tester, auth: _signedIn, language: 'en');
    repository.emit(const SignedOut());
    await tester.pumpAndSettle();
    expect(find.text('Sign in is being built'), findsOneWidget);
  });
}
