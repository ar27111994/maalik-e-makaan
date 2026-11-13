import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:maalik_e_makaan/src/auth/auth_repository.dart';
import 'package:maalik_e_makaan/src/core/failure.dart';
import 'package:maalik_e_makaan/src/data/cache/swr_cache.dart';
import 'package:maalik_e_makaan/src/data/paging.dart';
import 'package:maalik_e_makaan/src/features/account/data/account_repository.dart';
import 'package:maalik_e_makaan/src/features/account/data/profile.dart';
import 'package:maalik_e_makaan/src/features/account/data/profile_repository.dart';
import 'package:maalik_e_makaan/src/features/account/data/residence.dart';
import 'package:maalik_e_makaan/src/features/account/data/residence_repository.dart';
import 'package:maalik_e_makaan/src/features/documents/data/camera_target.dart';
import 'package:maalik_e_makaan/src/features/documents/data/document.dart';
import 'package:maalik_e_makaan/src/features/documents/data/document_files.dart';
import 'package:maalik_e_makaan/src/features/documents/data/document_repository.dart';
import 'package:maalik_e_makaan/src/features/leases/data/lease.dart';
import 'package:maalik_e_makaan/src/features/leases/data/lease_repository.dart';
import 'package:maalik_e_makaan/src/features/portfolios/data/portfolio.dart';
import 'package:maalik_e_makaan/src/features/portfolios/data/portfolio_details.dart';
import 'package:maalik_e_makaan/src/features/portfolios/data/portfolio_repository.dart';
import 'package:maalik_e_makaan/src/features/properties/data/property.dart';
import 'package:maalik_e_makaan/src/features/properties/data/property_repository.dart';
import 'package:maalik_e_makaan/src/features/team/data/team.dart';
import 'package:maalik_e_makaan/src/features/team/data/team_repository.dart';
import 'package:maalik_e_makaan/src/features/tenants/data/tenant.dart';
import 'package:maalik_e_makaan/src/features/tenants/data/tenant_repository.dart';
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

/// [gulberg], where the user is only a viewer.
const gulbergAsViewer = PortfolioMembership(
  id: '0192d0c4-0000-7000-8000-000000000001',
  name: 'Gulberg Houses',
  role: MemberRole.viewer,
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

/// A [ResidenceRepository] over one in-memory residence.
final class FakeResidenceRepository implements ResidenceRepository {
  new([this.residence = AccountResidence.notStated]);

  AccountResidence residence;
  final calls = <Call>[];
  final gate = Gate();

  /// Fails reads (not writes) with this when set.
  AppFailure? fetchFailure;

  /// Fails writes with this when set.
  AppFailure? updateFailure;

  /// The time the server stamps on a saved answer.
  DateTime now = DateTime.utc(2026, 11, 12, 10, 15);

  @override
  Future<AccountResidence> fetch(String userId) async {
    calls.add(('fetch', [userId]));
    await gate.pass();
    final failure = fetchFailure;
    if (failure != null) throw failure;
    return residence;
  }

  @override
  Future<AccountResidence> update(
    String userId, {
    required CountryCode? country,
    required TimeZoneId? timeZone,
  }) async {
    calls.add(('update', [userId, country, timeZone]));
    await gate.pass();
    final failure = updateFailure;
    if (failure != null) throw failure;
    return residence = AccountResidence(
      residence: Residence(country: country, timeZone: timeZone),
      statedAt: now,
    );
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
    OwnerAbroad ownerAbroad = OwnerAbroad.notAnswered,
  }) async {
    calls.add(('create', [name, id, ownerAbroad]));
    await gate.pass();
    final created = PortfolioMembership(
      id: id,
      name: sanitizeSingleLine(name),
      role: MemberRole.owner,
      ownerAbroad: ownerAbroad,
    );
    memberships.add(created);
    return created;
  }

  /// Fails answering or changing the owner-abroad question with this when
  /// set.
  AppFailure? ownerAbroadFailure;

  @override
  Future<OwnerAbroad> answerOwnerAbroad(
    String portfolioId, {
    required bool abroad,
  }) {
    calls.add(('answerOwnerAbroad', [portfolioId, abroad]));
    return _setOwnerAbroad(portfolioId, abroad: abroad, ifUnanswered: true);
  }

  @override
  Future<OwnerAbroad> changeOwnerAbroad(
    String portfolioId, {
    required bool abroad,
  }) {
    calls.add(('changeOwnerAbroad', [portfolioId, abroad]));
    return _setOwnerAbroad(portfolioId, abroad: abroad, ifUnanswered: false);
  }

  /// As `set_owner_abroad`: a stale question returns the answer already
  /// given.
  Future<OwnerAbroad> _setOwnerAbroad(
    String portfolioId, {
    required bool abroad,
    required bool ifUnanswered,
  }) async {
    await gate.pass();
    final failure = ownerAbroadFailure;
    if (failure != null) throw failure;
    final index = memberships.indexWhere((m) => m.id == portfolioId);
    final current = memberships[index].ownerAbroad;
    if (ifUnanswered && !current.needsAnswer) return current;
    final answer = OwnerAbroad.fromJson(abroad);
    memberships[index] = memberships[index].withOwnerAbroad(answer);
    final stored = details_[portfolioId];
    if (stored != null) {
      details_[portfolioId] = PortfolioDetails(
        id: stored.id,
        name: stored.name,
        defaultDueDay: stored.defaultDueDay,
        defaultGraceDays: stored.defaultGraceDays,
        defaultIncrementBasisPoints: stored.defaultIncrementBasisPoints,
        landlordName: stored.landlordName,
        landlordPhone: stored.landlordPhone,
        raastId: stored.raastId,
        bankAccountTitle: stored.bankAccountTitle,
        bankIban: stored.bankIban,
        ownerAbroad: answer,
        caretaker: stored.caretaker,
      );
    }
    return answer;
  }

  /// Fails reading settings with this when set.
  AppFailure? detailsFailure;

  /// The settings of each portfolio, by id.
  final Map<String, PortfolioDetails> details_ = {
    gulberg.id: gulbergDetails,
    plaza.id: PortfolioDetails(
      id: plaza.id,
      name: plaza.name,
      defaultDueDay: 1,
      defaultGraceDays: 3,
      defaultIncrementBasisPoints: 1000,
    ),
  };

  @override
  Future<PortfolioDetails> details(String portfolioId) async {
    calls.add(('details', [portfolioId]));
    await gate.pass();
    final failure = detailsFailure;
    if (failure != null) throw failure;
    return details_[portfolioId] ?? (throw const NotFoundFailure());
  }

  @override
  Future<PortfolioDetails> updateDetails(PortfolioDetails details) async {
    calls.add(('updateDetails', [details]));
    await gate.pass();
    final saved = PortfolioDetails(
      id: details.id,
      name: sanitizeSingleLine(details.name),
      defaultDueDay: details.defaultDueDay,
      defaultGraceDays: details.defaultGraceDays,
      defaultIncrementBasisPoints: details.defaultIncrementBasisPoints,
      landlordName: sanitizeOptional(details.landlordName),
      landlordPhone: details.landlordPhone,
      raastId: details.raastId,
      bankAccountTitle: sanitizeOptional(details.bankAccountTitle),
      bankIban: details.bankIban,
      // Not written by a save (no client may): kept as stored.
      ownerAbroad: details_[details.id]?.ownerAbroad ?? OwnerAbroad.notAnswered,
      caretaker: details_[details.id]?.caretaker,
    );
    details_[details.id] = saved;
    final index = memberships.indexWhere((m) => m.id == details.id);
    if (index >= 0) {
      final old = memberships[index];
      memberships[index] = PortfolioMembership(
        id: old.id,
        name: saved.name,
        role: old.role,
        ownerAbroad: old.ownerAbroad,
      );
    }
    return saved;
  }

  /// Fails deleting with this when set.
  AppFailure? deleteFailure;

  @override
  Future<void> delete(
    String portfolioId, {
    required String confirmation,
  }) async {
    calls.add(('delete', [portfolioId, confirmation]));
    await gate.pass();
    final failure = deleteFailure;
    if (failure != null) throw failure;
    final stored = details_[portfolioId]?.name;
    if (stored == null ||
        stored.trim().toLowerCase() != confirmation.trim().toLowerCase()) {
      throw const RejectedFailure('confirmation_mismatch');
    }
    memberships.removeWhere((m) => m.id == portfolioId);
    details_.remove(portfolioId);
  }
}

final gulbergDetails = PortfolioDetails(
  id: gulberg.id,
  name: gulberg.name,
  defaultDueDay: 5,
  defaultGraceDays: 5,
  defaultIncrementBasisPoints: 1000,
  landlordName: 'Ayesha Khan',
  landlordPhone: PhoneNumber.fromE164('+923001234567'),
  raastId: PhoneNumber.fromE164('+923001234567'),
  bankAccountTitle: 'Ayesha Khan',
  bankIban: Iban.parse('PK36SCBL0000001123456702'),
);

/// Members of [gulberg]: the test user (owner), a manager and a viewer.
final ayeshaMember = TeamMember(
  userId: testUserId,
  role: MemberRole.owner,
  fullName: 'Ayesha Khan',
  email: testEmail,
  joinedAt: DateTime.utc(2026, 1, 5, 9),
);
final bilalMember = TeamMember(
  userId: '0192d0c4-7a5e-7c1e-9a4b-2f6d1e3c8a91',
  role: MemberRole.manager,
  fullName: 'Bilal Ahmed',
  email: 'bilal.ahmed@example.com',
  joinedAt: DateTime.utc(2026, 2, 1, 9),
);
final saraMember = TeamMember(
  userId: '0192d0c4-7a5e-7c1e-9a4b-2f6d1e3c8a92',
  role: MemberRole.viewer,
  fullName: '',
  email: 'sara@example.com',
  joinedAt: DateTime.utc(2026, 3, 1, 9),
);

/// A pending invitation that works until 2099, and one that expired.
final pendingInvitation = Invitation(
  id: '0192d0c4-1111-7000-8000-000000000001',
  email: 'kamran@example.com',
  role: MemberRole.accountant,
  expiresAt: DateTime.utc(2099, 11, 14, 5),
  createdAt: DateTime.utc(2099, 11, 7, 5),
);
final expiredInvitation = Invitation(
  id: '0192d0c4-1111-7000-8000-000000000002',
  email: 'nadia@example.com',
  role: MemberRole.viewer,
  expiresAt: DateTime.utc(2026, 1, 9, 5),
  createdAt: DateTime.utc(2026, 1, 2, 5),
);

/// A [TeamRepository] over in-memory teams, by portfolio id.
final class FakeTeamRepository implements TeamRepository {
  new() {
    people[gulberg.id] = [ayeshaMember, bilalMember, saraMember];
    pending[gulberg.id] = [pendingInvitation, expiredInvitation];
    people[plaza.id] = [
      TeamMember(
        userId: 'plaza-owner',
        role: MemberRole.owner,
        fullName: 'Imran Qureshi',
        email: 'imran@example.com',
        joinedAt: DateTime.utc(2026),
      ),
      TeamMember(
        userId: testUserId,
        role: MemberRole.manager,
        fullName: 'Ayesha Khan',
        email: testEmail,
        joinedAt: DateTime.utc(2026, 2),
      ),
    ];
  }

  final Map<String, List<TeamMember>> people = {};
  final Map<String, List<Invitation>> pending = {};
  final calls = <Call>[];
  final gate = Gate();

  /// Fails reads (not commands) with this when set.
  AppFailure? readFailure;

  /// What [invite] answers about the e-mail.
  EmailDelivery delivery = EmailDelivery.sent;

  /// What [accept] answers.
  AcceptOutcome acceptOutcome = InvitationAccepted(
    portfolioId: gulberg.id,
    role: MemberRole.manager,
  );

  Future<void> _read() async {
    await gate.pass();
    final failure = readFailure;
    if (failure != null) throw failure;
  }

  @override
  Future<List<TeamMember>> members(String portfolioId) async {
    calls.add(('members', [portfolioId]));
    await _read();
    return sortMembers(people[portfolioId] ?? const []);
  }

  @override
  Future<List<Invitation>> pendingInvitations(String portfolioId) async {
    calls.add(('pendingInvitations', [portfolioId]));
    await _read();
    return [...?pending[portfolioId]];
  }

  @override
  Future<InvitationLink> invite({
    required String portfolioId,
    required String email,
    required MemberRole role,
    required AppLanguage language,
  }) async {
    calls.add(('invite', [portfolioId, email, role, language]));
    await gate.pass();
    final invitation = Invitation(
      id: 'inv-${calls.length}',
      email: email.trim().toLowerCase(),
      role: role,
      expiresAt: DateTime.utc(2099, 11, 14, 5),
      createdAt: DateTime.utc(2099, 11, 7, 5),
    );
    pending[portfolioId] = [
      invitation,
      ...?pending[portfolioId]?.where((i) => i.email != invitation.email),
    ];
    return InvitationLink(
      invitationId: invitation.id,
      email: invitation.email,
      role: role,
      expiresAt: invitation.expiresAt,
      url: Uri.parse(
        'https://maalik-e-makaan.vercel.app/invite#token=${invitation.id}.x',
      ),
      delivery: delivery,
    );
  }

  @override
  Future<void> revokeInvitation(String invitationId) async {
    calls.add(('revokeInvitation', [invitationId]));
    await gate.pass();
    for (final list in pending.values) {
      list.removeWhere((i) => i.id == invitationId);
    }
  }

  @override
  Future<void> changeRole({
    required String portfolioId,
    required String userId,
    required MemberRole role,
  }) async {
    calls.add(('changeRole', [portfolioId, userId, role]));
    await gate.pass();
    final list = people[portfolioId]!;
    final index = list.indexWhere((m) => m.userId == userId);
    final old = list[index];
    list[index] = TeamMember(
      userId: old.userId,
      role: role,
      fullName: old.fullName,
      email: old.email,
      joinedAt: old.joinedAt,
    );
  }

  @override
  Future<void> removeMember({
    required String portfolioId,
    required String userId,
  }) async {
    calls.add(('removeMember', [portfolioId, userId]));
    await gate.pass();
    people[portfolioId]?.removeWhere((m) => m.userId == userId);
  }

  @override
  Future<AcceptOutcome> accept(String token) async {
    calls.add(('accept', [token]));
    await gate.pass();
    return acceptOutcome;
  }

  /// Each portfolio's caretaker, by portfolio id.
  final Map<String, String?> caretakers = {};

  @override
  Future<void> setCaretaker({
    required String portfolioId,
    required String? userId,
  }) async {
    calls.add(('setCaretaker', [portfolioId, userId]));
    await gate.pass();
    if (userId != null) {
      final member = people[portfolioId]?.where((m) => m.userId == userId);
      if (member == null || member.isEmpty) {
        throw const RejectedFailure('member_not_found');
      }
      if (!member.single.role.canBeCaretaker) {
        throw const RejectedFailure('caretaker_not_manager');
      }
    }
    caretakers[portfolioId] = userId;
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

  /// Thrown by every write while set, as by a device that cannot write.
  Exception? writeFailure;

  void _write() {
    final failure = writeFailure;
    if (failure != null) throw failure;
  }

  @override
  String? getString(String key) => values[key] as String?;

  @override
  bool? getBool(String key) => values[key] as bool?;

  @override
  Future<void> setString(String key, String value) async {
    _write();
    values[key] = value;
  }

  @override
  Future<void> setBool(String key, {required bool value}) async {
    _write();
    values[key] = value;
  }

  @override
  Future<void> remove(String key) async {
    _write();
    values.remove(key);
  }
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

/// A house in [gulberg] with three units, and an archived plot.
final gulbergHouse = Property(
  id: '0192d0c4-2222-7000-8000-000000000001',
  name: 'Gulberg House',
  type: PropertyType.house,
  addressLine: '42-B, Main Boulevard',
  locality: 'Gulberg III',
  city: 'Lahore',
  province: Province.punjab,
  plotSize: const Hundredths(1000),
  plotSizeUnit: AreaUnit.marla,
  coveredAreaSqft: 3200,
  yearBuilt: 2012,
  purchasePrice: const Money.fromRupees(32000000),
  purchasedOn: CalendarDate(2015, 3, 1),
  estimatedValue: const Money.fromRupees(60000000),
  valueEstimatedOn: CalendarDate(2026, 6, 30),
  propertyTaxRef: 'LHR-GB-11234',
  notes: 'Gate key with the guard.',
  createdAt: '2026-01-05T09:00:00+00:00',
);
final oldPlot = Property(
  id: '0192d0c4-2222-7000-8000-000000000002',
  name: 'DHA plot',
  type: PropertyType.plot,
  city: 'Karachi',
  province: Province.sindh,
  archivedAt: DateTime.utc(2026, 5, 1, 7),
  createdAt: '2026-01-06T09:00:00+00:00',
);
const saddarPlaza = Property(
  id: '0192d0c4-2222-7000-8000-000000000003',
  name: 'Saddar Plaza',
  type: PropertyType.plaza,
  city: 'Rawalpindi',
  province: Province.punjab,
  createdAt: '2026-01-07T09:00:00+00:00',
);

final groundFloor = Unit(
  id: '0192d0c4-3333-7000-8000-000000000001',
  propertyId: gulbergHouse.id,
  label: 'Ground floor',
  type: UnitType.portion,
  floorLabel: 'Ground',
  bedrooms: 3,
  bathrooms: 3,
  coveredAreaSqft: 1600,
  askingRent: const Money.fromRupees(85000),
  createdAt: '2026-01-05T09:01:00+00:00',
);
final firstFloor = Unit(
  id: '0192d0c4-3333-7000-8000-000000000002',
  propertyId: gulbergHouse.id,
  label: 'First floor',
  type: UnitType.portion,
  bedrooms: 2,
  furnished: true,
  askingRent: const Money.fromRupees(65000),
  createdAt: '2026-01-05T09:02:00+00:00',
);
final annexe = Unit(
  id: '0192d0c4-3333-7000-8000-000000000003',
  propertyId: gulbergHouse.id,
  label: 'Annexe room',
  type: UnitType.room,
  isAvailable: false,
  createdAt: '2026-01-05T09:03:00+00:00',
);

/// A [PropertyRepository] over in-memory properties and units.
final class FakePropertyRepository implements PropertyRepository {
  new() {
    byPortfolio[gulberg.id] = [gulbergHouse, oldPlot];
    byPortfolio[plaza.id] = [saddarPlaza];
    unitList.addAll([groundFloor, firstFloor, annexe]);
    occupancy[groundFloor.id] = const Occupancy(
      status: OccupancyStatus.occupied,
      leaseId: 'lease-1',
      tenantId: 'tenant-1',
    );
    occupancy[firstFloor.id] = Occupancy(
      status: OccupancyStatus.vacant,
      vacantSince: CalendarDate(2026, 9, 1),
    );
    occupancy[annexe.id] = Occupancy(
      status: OccupancyStatus.unavailable,
      vacantSince: CalendarDate(2026, 1, 5),
    );
  }

  final Map<String, List<Property>> byPortfolio = {};
  final List<Unit> unitList = [];
  final Map<String, Occupancy> occupancy = {};
  final calls = <Call>[];
  final gate = Gate();

  /// Fails reads (not commands) with this when set.
  AppFailure? readFailure;

  /// How many rows a page holds (the real one reads 50).
  int pageLimit = pageSize;

  Future<void> _read(String name, List<Object?> arguments) async {
    calls.add((name, arguments));
    await gate.pass();
    final failure = readFailure;
    if (failure != null) throw failure;
  }

  Future<void> _write(String name, List<Object?> arguments) async {
    calls.add((name, arguments));
    await gate.pass();
  }

  Iterable<Property> get _all => byPortfolio.values.expand((list) => list);

  Paged<T> _page<T>(
    List<T> all,
    PageCursor? after,
    PageCursor Function(T) cursor,
  ) {
    var start = 0;
    if (after != null) {
      start = all.indexWhere((item) => cursor(item) == after) + 1;
    }
    final items = all.skip(start).take(pageLimit).toList();
    final more = start + items.length < all.length;
    return Paged(items, next: more ? cursor(items.last) : null);
  }

  @override
  Future<Paged<Property>> properties(
    String portfolioId, {
    required bool archived,
    PageCursor? after,
  }) async {
    await _read('properties', [portfolioId, archived, after]);
    final list = [
      for (final p in byPortfolio[portfolioId] ?? const <Property>[])
        if (p.archived == archived) p,
    ];
    return _page(list, after, (p) => p.cursor);
  }

  @override
  Future<Property> property(String propertyId) async {
    await _read('property', [propertyId]);
    return _all.firstWhere(
      (p) => p.id == propertyId,
      orElse: () => throw const NotFoundFailure(),
    );
  }

  Property _replace(Property property) {
    for (final list in byPortfolio.values) {
      final index = list.indexWhere((p) => p.id == property.id);
      if (index >= 0) list[index] = property;
    }
    return property;
  }

  Property _stored(Property p, {DateTime? archivedAt, String? createdAt}) =>
      Property.fromRow({
        ...p.toRow(),
        ...p.toWrite(),
        'archived_at': archivedAt?.toIso8601String(),
        'created_at': createdAt ?? p.createdAt,
      });

  @override
  Future<Property> createProperty(String portfolioId, Property property) async {
    await _write('createProperty', [portfolioId, property]);
    final stored = _stored(property, createdAt: '2026-11-07T10:00:00+00:00');
    (byPortfolio[portfolioId] ??= []).add(stored);
    return stored;
  }

  @override
  Future<Property> updateProperty(Property property) async {
    await _write('updateProperty', [property]);
    final old = _all.firstWhere((p) => p.id == property.id);
    return _replace(
      _stored(property, archivedAt: old.archivedAt, createdAt: old.createdAt),
    );
  }

  @override
  Future<Property> archiveProperty(
    String propertyId, {
    required bool archived,
  }) async {
    await _write('archiveProperty', [propertyId, archived]);
    final old = _all.firstWhere((p) => p.id == propertyId);
    return _replace(
      _stored(old, archivedAt: archived ? DateTime.utc(2026, 11, 7, 5) : null),
    );
  }

  @override
  Future<void> deleteProperty(String propertyId) async {
    await _write('deleteProperty', [propertyId]);
    for (final list in byPortfolio.values) {
      list.removeWhere((p) => p.id == propertyId);
    }
  }

  UnitSummary _summary(Unit unit) => UnitSummary(unit, occupancy[unit.id]);

  @override
  Future<Paged<UnitSummary>> units(
    String propertyId, {
    PageCursor? after,
  }) async {
    await _read('units', [propertyId, after]);
    return _page(
      [
        for (final u in unitList)
          if (u.propertyId == propertyId) _summary(u),
      ],
      after,
      (s) => s.unit.cursor,
    );
  }

  @override
  Future<UnitSummary> unit(String unitId) async {
    await _read('unit', [unitId]);
    return _summary(
      unitList.firstWhere(
        (u) => u.id == unitId,
        orElse: () => throw const NotFoundFailure(),
      ),
    );
  }

  Unit _storedUnit(Unit u, {DateTime? archivedAt, String? createdAt}) =>
      Unit.fromRow({
        ...u.toRow(),
        ...u.toWrite(),
        'archived_at': archivedAt?.toIso8601String(),
        'created_at': createdAt ?? u.createdAt,
      });

  Unit _replaceUnit(Unit unit) {
    unitList[unitList.indexWhere((u) => u.id == unit.id)] = unit;
    return unit;
  }

  @override
  Future<Unit> createUnit(String portfolioId, Unit unit) async {
    await _write('createUnit', [portfolioId, unit]);
    final stored = _storedUnit(unit, createdAt: '2026-11-07T10:00:00+00:00');
    unitList.add(stored);
    occupancy[stored.id] = Occupancy(
      status: stored.isAvailable
          ? OccupancyStatus.vacant
          : OccupancyStatus.unavailable,
      vacantSince: CalendarDate(2026, 11, 7),
    );
    return stored;
  }

  @override
  Future<Unit> updateUnit(Unit unit) async {
    await _write('updateUnit', [unit]);
    final old = unitList.firstWhere((u) => u.id == unit.id);
    return _replaceUnit(
      _storedUnit(unit, archivedAt: old.archivedAt, createdAt: old.createdAt),
    );
  }

  @override
  Future<Unit> archiveUnit(String unitId, {required bool archived}) async {
    await _write('archiveUnit', [unitId, archived]);
    final old = unitList.firstWhere((u) => u.id == unitId);
    return _replaceUnit(
      _storedUnit(
        old,
        archivedAt: archived ? DateTime.utc(2026, 11, 7, 5) : null,
      ),
    );
  }

  @override
  Future<void> deleteUnit(String unitId) async {
    await _write('deleteUnit', [unitId]);
    unitList.removeWhere((u) => u.id == unitId);
  }
}

/// Tenants of [gulberg]: a family man, a company, and an archived tenant.
final aliRaza = Tenant(
  id: '0192d0c4-4444-7000-8000-000000000001',
  fullName: 'Ali Raza',
  guardianName: 'Ahmed Raza',
  guardianRelation: GuardianRelation.sonOf,
  cnic: Cnic.parse('35202-1234567-1'),
  cnicExpiry: CalendarDate(2030, 4, 30),
  phone: PhoneNumber.fromE164('+923001112233'),
  altPhone: PhoneNumber.fromE164('+924235761234'),
  email: 'ali.raza@example.com',
  occupation: 'Bank officer',
  employer: 'Meezan Bank',
  permanentAddress: 'House 7, Street 3, Sargodha',
  emergencyName: 'Sana Raza',
  emergencyPhone: PhoneNumber.fromE164('+923004445566'),
  emergencyRelation: 'Wife',
  reference1: (
    name: 'Usman Tariq',
    phone: PhoneNumber.fromE164('+923217778899'),
  ),
  householdSize: 4,
  consentRecordedAt: DateTime.utc(2026, 1, 10, 6),
  consentNote: 'Told about CNIC copy and police form.',
  createdAt: '2026-01-10T06:00:00+00:00',
);
final techCorp = Tenant(
  id: '0192d0c4-4444-7000-8000-000000000002',
  fullName: 'Indus Tech (Pvt) Ltd',
  kind: TenantKind.company,
  ntn: '1234567-8',
  phone: PhoneNumber.fromE164('+924235000000'),
  deductsWithholdingTax: true,
  createdAt: '2026-02-01T06:00:00+00:00',
);
final formerTenant = Tenant(
  id: '0192d0c4-4444-7000-8000-000000000003',
  fullName: 'Hamid Ali',
  cnic: Cnic.parse('42101-7654321-3'),
  cnicExpiry: CalendarDate(2024, 1, 1),
  archivedAt: DateTime.utc(2026, 6, 1, 5),
  createdAt: '2025-06-01T06:00:00+00:00',
);

/// A [TenantRepository] over in-memory tenants.
final class FakeTenantRepository implements TenantRepository {
  new() {
    byPortfolio[gulberg.id] = [formerTenant, aliRaza, techCorp];
  }

  final Map<String, List<Tenant>> byPortfolio = {};
  final calls = <Call>[];
  final gate = Gate();
  AppFailure? readFailure;
  int pageLimit = pageSize;

  Iterable<Tenant> get _all => byPortfolio.values.expand((list) => list);

  Future<void> _call(
    String name,
    List<Object?> arguments, {
    bool read = false,
  }) async {
    calls.add((name, arguments));
    await gate.pass();
    final failure = readFailure;
    if (read && failure != null) throw failure;
  }

  @override
  Future<Paged<Tenant>> tenants(
    String portfolioId, {
    required bool archived,
    String search = '',
    PageCursor? after,
  }) async {
    await _call('tenants', [portfolioId, archived, search, after], read: true);
    final needle = search.trim().toLowerCase();
    final all = [
      for (final t in byPortfolio[portfolioId] ?? const <Tenant>[])
        if (t.archived == archived &&
            (needle.isEmpty || t.fullName.toLowerCase().contains(needle)))
          t,
    ];
    var start = 0;
    if (after != null) start = all.indexWhere((t) => t.cursor == after) + 1;
    final items = all.skip(start).take(pageLimit).toList();
    return Paged(
      items,
      next: start + items.length < all.length ? items.last.cursor : null,
    );
  }

  @override
  Future<Tenant> tenant(String tenantId) async {
    await _call('tenant', [tenantId], read: true);
    return _all.firstWhere(
      (t) => t.id == tenantId,
      orElse: () => throw const NotFoundFailure(),
    );
  }

  @override
  Future<List<TenantMatch>> matches(
    String portfolioId, {
    Cnic? cnic,
    PhoneNumber? phone,
    String? exceptId,
  }) async {
    await _call('matches', [portfolioId, cnic, phone, exceptId]);
    return [
      for (final t in byPortfolio[portfolioId] ?? const <Tenant>[])
        if (!t.archived &&
            t.id != exceptId &&
            ((cnic != null && t.cnic == cnic) ||
                (phone != null && t.phone == phone)))
          (id: t.id, fullName: t.fullName),
    ];
  }

  Tenant _stored(Tenant t, {DateTime? archivedAt, String? createdAt}) =>
      Tenant.fromRow({
        ...t.toRow(),
        'archived_at': archivedAt?.toIso8601String(),
        'created_at': createdAt ?? t.createdAt,
      });

  Tenant _replace(Tenant tenant) {
    for (final list in byPortfolio.values) {
      final index = list.indexWhere((t) => t.id == tenant.id);
      if (index >= 0) list[index] = tenant;
    }
    return tenant;
  }

  @override
  Future<Tenant> createTenant(String portfolioId, Tenant tenant) async {
    await _call('createTenant', [portfolioId, tenant]);
    final stored = _stored(tenant, createdAt: '2026-11-07T10:00:00+00:00');
    (byPortfolio[portfolioId] ??= []).add(stored);
    return stored;
  }

  @override
  Future<Tenant> updateTenant(Tenant tenant) async {
    await _call('updateTenant', [tenant]);
    final old = _all.firstWhere((t) => t.id == tenant.id);
    return _replace(
      _stored(tenant, archivedAt: old.archivedAt, createdAt: old.createdAt),
    );
  }

  @override
  Future<Tenant> archiveTenant(
    String tenantId, {
    required bool archived,
  }) async {
    await _call('archiveTenant', [tenantId, archived]);
    final old = _all.firstWhere((t) => t.id == tenantId);
    return _replace(
      _stored(old, archivedAt: archived ? DateTime.utc(2026, 11, 7, 5) : null),
    );
  }

  @override
  Future<void> deleteTenant(String tenantId) async {
    await _call('deleteTenant', [tenantId]);
    for (final list in byPortfolio.values) {
      list.removeWhere((t) => t.id == tenantId);
    }
  }
}

/// Ali Raza's tenancy of [groundFloor], and an ended one of [firstFloor].
final aliLease = Lease(
  id: '0192d0c4-5555-7000-8000-000000000001',
  unitId: groundFloor.id,
  tenantId: aliRaza.id,
  status: LeaseStatus.active,
  tenantName: 'Ali Raza',
  unitLabel: 'Ground floor',
  propertyId: gulbergHouse.id,
  propertyName: 'Gulberg House',
  province: Province.punjab,
  createdAt: '2026-01-10T07:00:00+00:00',
  terms: LeaseTerms(
    startDate: CalendarDate(2026, 1, 15),
    endDate: CalendarDate(2026, 12, 14),
    monthlyRent: const Money.fromRupees(85000),
    billingStartsOn: CalendarDate(2026, 1, 15),
    securityDeposit: const Money.fromRupees(170000),
    lateFee: const DailyLateFee(
      Money.fromRupees(500),
      cap: Money.fromRupees(5000),
    ),
    agreementSignedOn: CalendarDate(2026, 1, 12),
    eStampNumber: 'PB-LHR-2026-445566',
    eStampAmount: const Money.fromRupees(1200),
    permittedUse: 'Family residence',
    utilitiesNote: 'Tenant pays electricity and gas.',
  ),
);
final endedLease = Lease(
  id: '0192d0c4-5555-7000-8000-000000000002',
  unitId: firstFloor.id,
  tenantId: formerTenant.id,
  status: LeaseStatus.ended,
  tenantName: 'Hamid Ali',
  unitLabel: 'First floor',
  propertyId: gulbergHouse.id,
  propertyName: 'Gulberg House',
  province: Province.punjab,
  movedOutOn: CalendarDate(2026, 8, 31),
  endReason: EndReason.tenantMovedOut,
  createdAt: '2025-06-01T07:00:00+00:00',
  terms: LeaseTerms(
    startDate: CalendarDate(2025, 6, 1),
    monthlyRent: const Money.fromRupees(60000),
    billingStartsOn: CalendarDate(2025, 6, 1),
    policeStatus: PoliceStatus.registered,
    policeChannel: PoliceChannel.khidmatMarkaz,
    policeReference: 'TRS-88231',
    policeRegisteredOn: CalendarDate(2025, 6, 5),
  ),
);

/// A [LeaseRepository] over in-memory tenancies.
final class FakeLeaseRepository implements LeaseRepository {
  new() {
    leaseList.addAll([aliLease, endedLease]);
    occupantsOf[aliLease.id] = [
      Occupant(
        id: 'occ-1',
        fullName: 'Sana Raza',
        relation: 'Wife',
        cnic: Cnic.parse('35202-7654321-2'),
        phone: PhoneNumber.fromE164('+923004445566'),
      ),
    ];
    changesOf[aliLease.id] = [
      RentChange(
        id: 'rc-1',
        effectiveFrom: MonthPeriod(2026, 1),
        monthlyRent: const Money.fromRupees(85000),
        reason: RentChangeReason.initial,
      ),
    ];
  }

  final List<Lease> leaseList = [];
  final Map<String, List<Occupant>> occupantsOf = {};
  final Map<String, List<RentChange>> changesOf = {};
  final calls = <Call>[];
  final gate = Gate();
  AppFailure? readFailure;

  Future<void> _call(
    String name,
    List<Object?> arguments, {
    bool read = false,
  }) async {
    calls.add((name, arguments));
    await gate.pass();
    final failure = readFailure;
    if (read && failure != null) throw failure;
  }

  Lease _find(String id) => leaseList.firstWhere(
    (l) => l.id == id,
    orElse: () => throw const NotFoundFailure(),
  );

  Lease _replace(Lease lease) {
    leaseList[leaseList.indexWhere((l) => l.id == lease.id)] = lease;
    return lease;
  }

  Lease _with(
    Lease old, {
    LeaseTerms? terms,
    LeaseStatus? status,
    CalendarDate? movedOutOn,
    EndReason? endReason,
  }) => Lease(
    id: old.id,
    unitId: old.unitId,
    tenantId: old.tenantId,
    status: status ?? old.status,
    terms: terms ?? old.terms,
    tenantName: old.tenantName,
    unitLabel: old.unitLabel,
    propertyId: old.propertyId,
    propertyName: old.propertyName,
    province: old.province,
    movedOutOn: movedOutOn ?? old.movedOutOn,
    endReason: endReason ?? old.endReason,
    createdAt: old.createdAt,
  );

  @override
  Future<List<Lease>> leases({String? unitId, String? tenantId}) async {
    await _call('leases', [unitId, tenantId], read: true);
    return [
      for (final l in leaseList)
        if ((unitId == null || l.unitId == unitId) &&
            (tenantId == null || l.tenantId == tenantId))
          l,
    ];
  }

  @override
  Future<LeaseDetail> lease(String leaseId) async {
    await _call('lease', [leaseId], read: true);
    return LeaseDetail(
      lease: _find(leaseId),
      occupants: [...?occupantsOf[leaseId]],
      rentChanges: [...?changesOf[leaseId]],
    );
  }

  @override
  Future<Lease> createLease({
    required String id,
    required String portfolioId,
    required String unitId,
    required String tenantId,
    required LeaseTerms terms,
  }) async {
    await _call('createLease', [id, portfolioId, unitId, tenantId, terms]);
    final lease = Lease(
      id: id,
      unitId: unitId,
      tenantId: tenantId,
      status: LeaseStatus.active,
      terms: terms,
      tenantName: 'Ali Raza',
      unitLabel: 'Ground floor',
      propertyId: gulbergHouse.id,
      propertyName: 'Gulberg House',
      province: Province.punjab,
      createdAt: '2026-11-07T10:00:00+00:00',
    );
    leaseList.insert(0, lease);
    return lease;
  }

  @override
  Future<Lease> updateLease(String leaseId, LeaseTerms terms) async {
    await _call('updateLease', [leaseId, terms]);
    return _replace(_with(_find(leaseId), terms: terms));
  }

  @override
  Future<void> changeRent(
    String leaseId, {
    required MonthPeriod from,
    required Money rent,
    required RentChangeReason reason,
    String? note,
  }) async {
    await _call('changeRent', [leaseId, from, rent, reason, note]);
    (changesOf[leaseId] ??= []).insert(
      0,
      RentChange(
        id: 'rc-${calls.length}',
        effectiveFrom: from,
        monthlyRent: rent,
        reason: reason,
        note: note,
      ),
    );
  }

  @override
  Future<void> endLease(
    String leaseId, {
    required CalendarDate movedOutOn,
    required EndReason reason,
  }) async {
    await _call('endLease', [leaseId, movedOutOn, reason]);
    _replace(
      _with(
        _find(leaseId),
        status: LeaseStatus.ended,
        movedOutOn: movedOutOn,
        endReason: reason,
      ),
    );
  }

  @override
  Future<void> deleteLease(String leaseId) async {
    await _call('deleteLease', [leaseId]);
    leaseList.removeWhere((l) => l.id == leaseId);
  }

  @override
  Future<Occupant> addOccupant({
    required String portfolioId,
    required String leaseId,
    required Occupant occupant,
  }) async {
    await _call('addOccupant', [portfolioId, leaseId, occupant]);
    final stored = Occupant.fromRow(occupant.toRow());
    (occupantsOf[leaseId] ??= []).add(stored);
    return stored;
  }

  @override
  Future<Occupant> updateOccupant(Occupant occupant) async {
    await _call('updateOccupant', [occupant]);
    final stored = Occupant.fromRow(occupant.toRow());
    for (final list in occupantsOf.values) {
      final index = list.indexWhere((o) => o.id == occupant.id);
      if (index >= 0) list[index] = stored;
    }
    return stored;
  }

  @override
  Future<void> deleteOccupant(String occupantId) async {
    await _call('deleteOccupant', [occupantId]);
    for (final list in occupantsOf.values) {
      list.removeWhere((o) => o.id == occupantId);
    }
  }
}

/// The front and back of Ali Raza's CNIC, and the agreement of his
/// tenancy.
final cnicFrontScan = Document(
  id: '0192d0c4-6666-7000-8000-000000000001',
  owner: (entity: DocumentEntity.tenant, id: aliRaza.id),
  kind: DocumentKind.cnicFront,
  storagePath:
      '${gulberg.id}/tenant/${aliRaza.id}/0192d0c4-6666-7000-8000-000000000001.jpg',
  fileName: 'CNIC front',
  fileType: DocumentFileType.jpeg,
  sizeBytes: 245760,
  createdAt: '2026-11-01T06:30:00+00:00',
);
final cnicBackScan = Document(
  id: '0192d0c4-6666-7000-8000-000000000002',
  owner: (entity: DocumentEntity.tenant, id: aliRaza.id),
  kind: DocumentKind.cnicBack,
  storagePath:
      '${gulberg.id}/tenant/${aliRaza.id}/0192d0c4-6666-7000-8000-000000000002.jpg',
  fileName: 'CNIC back',
  fileType: DocumentFileType.jpeg,
  sizeBytes: 231424,
  createdAt: '2026-10-31T06:30:00+00:00',
);
final agreementScan = Document(
  id: '0192d0c4-6666-7000-8000-000000000003',
  owner: (entity: DocumentEntity.lease, id: aliLease.id),
  kind: DocumentKind.tenancyAgreement,
  storagePath:
      '${gulberg.id}/lease/${aliLease.id}/0192d0c4-6666-7000-8000-000000000003.pdf',
  fileName: 'Signed agreement, January 2026',
  fileType: DocumentFileType.pdf,
  sizeBytes: 1288490,
  createdAt: '2026-01-12T09:00:00+00:00',
);

/// A [DocumentRepository] over in-memory documents and files.
final class FakeDocumentRepository implements DocumentRepository {
  new() {
    for (final document in [cnicFrontScan, cnicBackScan, agreementScan]) {
      documentsOf(document.owner).add(document);
      stored.add(document.storagePath);
    }
  }

  final Map<DocumentOwner, List<Document>> byOwner = {};
  final calls = <Call>[];
  final gate = Gate();
  AppFailure? readFailure;
  int pageLimit = pageSize;

  /// Refusals the next uploads and inserts meet, in turn.
  final uploadFailures = <AppFailure>[];
  final recordFailures = <AppFailure>[];

  /// Fails making links when set.
  AppFailure? linkFailure;

  /// The paths of the stored files.
  final stored = <String>{};

  /// Records that no longer take documents for [ownerTakesDocuments]:
  /// deleted, hidden from the member, archived or voided.
  final closedOwners = <DocumentOwner>{};

  /// Fails [ownerTakesDocuments] when set.
  AppFailure? ownerFailure;

  List<Document> documentsOf(DocumentOwner owner) => byOwner[owner] ??= [];

  Iterable<Document> get _all => byOwner.values.expand((list) => list);

  Future<void> _call(
    String name,
    List<Object?> arguments, {
    bool read = false,
  }) async {
    calls.add((name, arguments));
    await gate.pass();
    final failure = readFailure;
    if (read && failure != null) throw failure;
  }

  @override
  Future<Paged<Document>> documents(
    String portfolioId,
    DocumentOwner owner, {
    PageCursor? after,
  }) async {
    await _call('documents', [portfolioId, owner, after], read: true);
    final all = [...documentsOf(owner)]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    var start = 0;
    if (after != null) start = all.indexWhere((d) => d.cursor == after) + 1;
    final items = all.skip(start).take(pageLimit).toList();
    return Paged(
      items,
      next: start + items.length < all.length ? items.last.cursor : null,
    );
  }

  @override
  Future<bool> ownerTakesDocuments(
    String portfolioId,
    DocumentOwner owner,
  ) async {
    await _call('ownerTakesDocuments', [portfolioId, owner]);
    final failure = ownerFailure;
    if (failure != null) throw failure;
    return !closedOwners.contains(owner);
  }

  @override
  Future<void> uploadFile(DocumentUpload upload) async {
    await _call('uploadFile', [upload.storagePath]);
    if (uploadFailures.isNotEmpty) throw uploadFailures.removeAt(0);
    stored.add(upload.storagePath);
  }

  @override
  Future<Document> recordDocument(
    DocumentUpload upload, {
    required String name,
    required DocumentKind kind,
  }) async {
    await _call('recordDocument', [upload.storagePath, name, kind]);
    if (recordFailures.isNotEmpty) throw recordFailures.removeAt(0);
    if (!stored.contains(upload.storagePath)) {
      throw const RejectedFailure('document_file_missing');
    }
    final document = Document(
      id: upload.id,
      owner: upload.owner,
      kind: kind,
      storagePath: upload.storagePath,
      fileName: documentName(name),
      fileType: upload.file.type,
      sizeBytes: upload.file.size,
      createdAt: '2026-11-07T10:00:00+00:00',
    );
    documentsOf(upload.owner).add(document);
    return document;
  }

  @override
  Future<void> discardFile(String storagePath) async {
    await _call('discardFile', [storagePath]);
    stored.remove(storagePath);
  }

  /// The thumbnail links [thumbnailLinks] answers with, by document id.
  Map<String, Uri> thumbnails = {};

  @override
  Future<Map<String, Uri>> thumbnailLinks(List<Document> documents) async {
    await _call('thumbnailLinks', [for (final d in documents) d.id]);
    return {
      for (final document in documents) document.id: ?thumbnails[document.id],
    };
  }

  @override
  Future<DocumentLinks> links(Document document) async {
    await _call('links', [document.id]);
    final failure = linkFailure;
    if (failure != null) throw failure;
    final open = Uri.parse(
      'https://files.example/${document.storagePath}?token=t',
    );
    return (
      open: open,
      download: open.replace(
        queryParameters: {'token': 't', 'download': document.fileName},
      ),
    );
  }

  @override
  Future<Document> updateDocument(
    Document document, {
    required String name,
    required DocumentKind kind,
  }) async {
    await _call('updateDocument', [document.id, name, kind]);
    final saved = document.copyWith(fileName: documentName(name), kind: kind);
    final list = documentsOf(document.owner);
    list[list.indexWhere((d) => d.id == document.id)] = saved;
    return saved;
  }

  @override
  Future<void> deleteDocument(String documentId) async {
    await _call('deleteDocument', [documentId]);
    final document = _all.firstWhere((d) => d.id == documentId);
    documentsOf(document.owner).remove(document);
  }
}

/// A photo of a CNIC's front as the real preparation leaves a camera
/// photo: a JPEG of 286 KB, made smaller from 2.4 MB. Its picture is a
/// drawing of the card (a green card, its header, the holder's photo and
/// lines of text), so a preview shows something; the bytes after the end
/// of the image bring it to its size.
final Uint8List preparedPhoto = () {
  final card = img.Image(width: 480, height: 300)
    ..clear(img.ColorRgb8(214, 232, 216));
  img.fillRect(
    card,
    x1: 0,
    y1: 0,
    x2: 479,
    y2: 54,
    color: img.ColorRgb8(31, 110, 67),
  );
  img.fillRect(
    card,
    x1: 336,
    y1: 84,
    x2: 448,
    y2: 228,
    color: img.ColorRgb8(150, 160, 170),
  );
  for (var line = 0; line < 5; line++) {
    img.fillRect(
      card,
      x1: 32,
      y1: 90 + line * 32,
      x2: line.isEven ? 296 : 220,
      y2: 104 + line * 32,
      color: img.ColorRgb8(70, 80, 90),
    );
  }
  final jpeg = img.encodeJpg(card, quality: 90);
  return Uint8List(preparedPhotoSize)..setAll(0, jpeg);
}();

/// The sizes of [preparedPhoto], and of the photo before it was prepared.
const int preparedPhotoSize = 286 * 1024;
const int takenPhotoSize = 2516582; // 2.4 MB

/// A picker whose camera and file chooser answer what the test sets, and
/// a preparation that only reads the file's type (the real one is tested
/// on its own): a JPEG becomes [preparedPhoto], made smaller from
/// [takenPhotoSize].
final class FakeDocumentPicker implements DocumentPicker {
  /// What the camera and the file chooser answer (null: cancelled).
  ChosenFile? photo = ChosenFile(
    name: 'image_picker_1234.jpg',
    bytes: Uint8List.fromList([0xFF, 0xD8, 0xFF, ...List.filled(997, 0)]),
  );
  ChosenFile? file = ChosenFile(
    name: 'Agreement scan.pdf',
    bytes: Uint8List.fromList([
      ...latin1.encode('%PDF-1.7'),
      ...List.filled(2040, 0),
    ]),
  );

  /// The photo the camera kept after Android closed the app, handed over
  /// once by [recoverLostPhoto]; null when there is none.
  ChosenFile? lostPhoto;

  /// Thrown by [recoverLostPhoto] when set: the camera's refusal before
  /// the app closed.
  AppFailure? lostFailure;

  /// What a picked JPEG is prepared into.
  Uint8List preparedJpeg = preparedPhoto;

  /// Thrown by the next pick when set.
  AppFailure? failure;
  final calls = <String>[];
  final gate = Gate();

  Future<ChosenFile?> _pick(String name, ChosenFile? answer) async {
    calls.add(name);
    await gate.pass();
    final failure = this.failure;
    if (failure != null) throw failure;
    return answer;
  }

  @override
  Future<ChosenFile?> takePhoto() => _pick('takePhoto', photo);

  @override
  Future<ChosenFile?> chooseFile() => _pick('chooseFile', file);

  @override
  Future<ChosenFile?> recoverLostPhoto() async {
    calls.add('recoverLostPhoto');
    final failure = lostFailure;
    lostFailure = null;
    if (failure != null) throw failure;
    final photo = lostPhoto;
    lostPhoto = null;
    return photo;
  }

  Future<PreparedFile> prepare(ChosenFile file) async {
    final type = DocumentFileType.sniff(file.bytes);
    if (type == null) throw const RejectedFailure('file_type_not_allowed');
    final name = file.name.substring(0, file.name.lastIndexOf('.'));
    return type == DocumentFileType.jpeg
        ? PreparedFile(
            name: name,
            bytes: preparedJpeg,
            type: type,
            originalSize: takenPhotoSize,
          )
        : PreparedFile(
            name: name,
            bytes: file.bytes,
            type: type,
            originalSize: file.bytes.length,
          );
  }
}

/// A [CameraTargetStore] whose writes fail one at a time, as the test
/// sets: [rememberFailure] is thrown by [remember] and [forgetFailure] by
/// [forget]. Like a device's, a write that fails leaves the target that
/// was kept before it ([kept]).
final class FakeCameraTargetStore implements CameraTargetStore {
  new([this.kept]);

  /// The target the device keeps.
  CameraTarget? kept;

  Exception? rememberFailure;
  Exception? forgetFailure;

  /// The writes asked for, in order, failed or not.
  final calls = <String>[];

  @override
  CameraTarget? read() => kept;

  @override
  Future<void> remember(CameraTarget target) async {
    calls.add('remember');
    if (rememberFailure case final failure?) throw failure;
    kept = target;
  }

  @override
  Future<void> forget() async {
    calls.add('forget');
    if (forgetFailure case final failure?) throw failure;
    kept = null;
  }
}
