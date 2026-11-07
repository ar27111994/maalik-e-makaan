import 'dart:async';

import 'package:maalik_e_makaan/src/auth/auth_repository.dart';
import 'package:maalik_e_makaan/src/core/failure.dart';
import 'package:maalik_e_makaan/src/data/cache/swr_cache.dart';
import 'package:maalik_e_makaan/src/features/account/data/account_repository.dart';
import 'package:maalik_e_makaan/src/features/account/data/profile.dart';
import 'package:maalik_e_makaan/src/features/account/data/profile_repository.dart';
import 'package:maalik_e_makaan/src/features/portfolios/data/portfolio.dart';
import 'package:maalik_e_makaan/src/features/portfolios/data/portfolio_repository.dart';
import 'package:maalik_e_makaan/src/settings/app_settings.dart';
import 'package:mm_core/mm_core.dart';

/// The user most tests sign in as.
const testUserId = '0192d0c4-7a5e-7c1e-9a4b-2f6d1e3c8a90';
const testEmail = 'ayesha.khan@example.com';
const signedIn = SignedIn(userId: testUserId, email: testEmail);

const gulberg = PortfolioMembership(
  id: '0192d0c4-0000-7000-8000-000000000001',
  name: 'Gulberg Houses',
  role: MemberRole.owner,
);
const plaza = PortfolioMembership(
  id: '0192d0c4-0000-7000-8000-000000000002',
  name: 'Saddar Plaza',
  role: MemberRole.manager,
);

final ayesha = Profile(
  id: testUserId,
  email: testEmail,
  fullName: 'Ayesha Khan',
  phone: PhoneNumber.fromE164('+923001234567'),
  language: AppLanguage.english,
);

/// A call a fake recorded: its name and arguments.
typedef Call = (String, List<Object?>);

/// Lets a test hold a fake's answer until it decides, to see the busy
/// state, and fail it with an [AppFailure].
final class Gate {
  Completer<void>? _completer;
  AppFailure? failure;

  /// Holds every call until [open].
  void close() => _completer = Completer<void>();

  /// Lets held calls continue.
  void open() {
    _completer?.complete();
    _completer = null;
  }

  Future<void> pass() async {
    final completer = _completer;
    if (completer != null) await completer.future;
    final failure = this.failure;
    if (failure != null) throw failure;
  }
}

/// An [AuthRepository] whose status the test sets.
final class FakeAuthRepository implements AuthRepository {
  new([this._status = const SignedOut()]);

  AuthStatus _status;
  final _changes = StreamController<AuthStatus>.broadcast();
  final calls = <Call>[];
  final gate = Gate();
  SignUpOutcome signUpOutcome = SignUpOutcome.confirmationSent;

  void emit(AuthStatus status) {
    _status = status;
    _changes.add(status);
  }

  @override
  AuthStatus get status => _status;

  /// Like the real repository: the current status at once, then every
  /// change, subscribed as soon as the stream is listened to.
  @override
  Stream<AuthStatus> watch() => Stream.multi((controller) {
    controller.add(_status);
    final subscription = _changes.stream.listen(controller.add);
    controller.onCancel = subscription.cancel;
  });

  Future<void> _record(String name, List<Object?> arguments) async {
    calls.add((name, arguments));
    await gate.pass();
  }

  @override
  Future<void> signIn({required String email, required String password}) async {
    await _record('signIn', [email, password]);
    emit(SignedIn(userId: testUserId, email: email));
  }

  @override
  Future<SignUpOutcome> signUp({
    required String email,
    required String password,
    required String fullName,
    required String languageCode,
  }) async {
    await _record('signUp', [email, password, fullName, languageCode]);
    if (signUpOutcome == SignUpOutcome.signedIn) {
      emit(SignedIn(userId: testUserId, email: email));
    }
    return signUpOutcome;
  }

  @override
  Future<void> resendConfirmation(String email) =>
      _record('resendConfirmation', [email]);

  @override
  Future<void> sendPasswordReset(String email) =>
      _record('sendPasswordReset', [email]);

  @override
  Future<void> updatePassword(String newPassword) async {
    await _record('updatePassword', [newPassword]);
    emit(signedIn);
  }

  @override
  Future<void> reauthenticate(String password) =>
      _record('reauthenticate', [password]);

  @override
  Future<void> completeEmailLink(Uri link) async {
    await _record('completeEmailLink', [link]);
    emit(signedIn);
  }

  @override
  Future<void> signOut({SignOutCause cause = SignOutCause.userRequest}) async {
    calls.add(('signOut', [cause]));
    emit(SignedOut(cause: cause));
    await gate.pass();
  }
}

/// A [ProfileRepository] over one in-memory profile.
final class FakeProfileRepository implements ProfileRepository {
  new([this.profile]);

  Profile? profile;
  final calls = <Call>[];
  final gate = Gate();

  /// Fails reads (not writes) with this when set.
  AppFailure? fetchFailure;

  @override
  Future<Profile> fetch(String userId) async {
    calls.add(('fetch', [userId]));
    await gate.pass();
    final failure = fetchFailure;
    if (failure != null) throw failure;
    return profile ?? (throw const NotFoundFailure());
  }

  @override
  Future<Profile> updateDetails(
    String userId, {
    required String fullName,
    required PhoneNumber? phone,
  }) async {
    calls.add(('updateDetails', [userId, fullName, phone]));
    await gate.pass();
    final current = profile!;
    return profile = Profile(
      id: current.id,
      email: current.email,
      fullName: sanitizeSingleLine(fullName),
      phone: phone,
      language: current.language,
    );
  }

  @override
  Future<void> updateLanguage(String userId, AppLanguage language) async {
    calls.add(('updateLanguage', [userId, language]));
    await gate.pass();
    profile = profile?.copyWith(language: language);
  }
}

/// A [PortfolioRepository] over an in-memory list.
final class FakePortfolioRepository implements PortfolioRepository {
  new([List<PortfolioMembership>? memberships])
    : memberships = [...?memberships];

  final List<PortfolioMembership> memberships;
  final calls = <Call>[];
  final gate = Gate();

  /// Fails reads (not creation) with this when set.
  AppFailure? listFailure;

  @override
  Future<List<PortfolioMembership>> listMine(String userId) async {
    calls.add(('listMine', [userId]));
    await gate.pass();
    final failure = listFailure;
    if (failure != null) throw failure;
    return sortByName(memberships);
  }

  @override
  Future<PortfolioMembership> create({
    required String name,
    required String id,
  }) async {
    calls.add(('create', [name, id]));
    await gate.pass();
    final created = PortfolioMembership(
      id: id,
      name: sanitizeSingleLine(name),
      role: MemberRole.owner,
    );
    memberships.add(created);
    return created;
  }
}

/// An [AccountRepository] with a fixed preview.
final class FakeAccountRepository implements AccountRepository {
  new([DeletionPreview? preview])
    : preview =
          preview ??
          const DeletionPreview(
            portfoliosToDelete: [
              DoomedPortfolio(
                id: 'p1',
                name: 'Gulberg Houses',
                otherMembers: 2,
              ),
              DoomedPortfolio(
                id: 'p2',
                name: 'Model Town Flats',
                otherMembers: 0,
              ),
            ],
            reauthMaxAge: Duration(minutes: 10),
            secondFactorRequired: false,
          );

  DeletionPreview preview;
  final calls = <Call>[];
  final gate = Gate();

  /// Fails the preview (not the deletion) with this when set.
  AppFailure? previewFailure;

  @override
  Future<DeletionPreview> deletionPreview() async {
    calls.add(('deletionPreview', const []));
    await gate.pass();
    final failure = previewFailure;
    if (failure != null) throw failure;
    return preview;
  }

  @override
  Future<int> deleteAccount({required String confirmEmail}) async {
    calls.add(('deleteAccount', [confirmEmail]));
    await gate.pass();
    return preview.portfoliosToDelete.length;
  }
}

/// An in-memory [SettingsStore].
final class MemorySettingsStore implements SettingsStore {
  new([Map<String, Object>? values]) : values = {...?values};

  final Map<String, Object> values;

  @override
  String? getString(String key) => values[key] as String?;

  @override
  bool? getBool(String key) => values[key] as bool?;

  @override
  Future<void> setString(String key, String value) async => values[key] = value;

  @override
  Future<void> setBool(String key, {required bool value}) async =>
      values[key] = value;

  @override
  Future<void> remove(String key) async => values.remove(key);
}

/// An in-memory [KeyValueStore].
final class MemoryStore implements KeyValueStore {
  final Map<String, String> values = {};

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async => values[key] = value;

  @override
  Future<void> delete(String key) async => values.remove(key);

  @override
  Future<Set<String>> keys() async => values.keys.toSet();
}
