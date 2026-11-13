import 'package:flutter_test/flutter_test.dart';
import 'package:maalik_e_makaan/src/core/failure.dart';
import 'package:maalik_e_makaan/src/features/account/data/profile.dart';
import 'package:maalik_e_makaan/src/features/portfolios/data/portfolio.dart';
import 'package:maalik_e_makaan/src/features/team/data/team.dart';
import 'package:maalik_e_makaan/src/features/team/data/team_repository.dart';

import '../../../../support/fakes.dart';
import '../../../../support/supabase.dart';

const _bilal = '0192d0c4-7a5e-7c1e-9a4b-2f6d1e3c8a91';

/// `portfolio_members` rows as PostgREST returns them.
const List<Map<String, Object?>> _memberRows = [
  {
    'user_id': _bilal,
    'role': 'manager',
    'created_at': '2026-02-01T09:00:00.123456+00:00',
  },
  {
    'user_id': testUserId,
    'role': 'owner',
    'created_at': '2026-01-05T09:00:00+00:00',
  },
  {
    'user_id': 'no-profile',
    'role': 'viewer',
    'created_at': '2026-03-01T09:00:00+00:00',
  },
];

const List<Map<String, Object?>> _profileRows = [
  {'id': testUserId, 'full_name': 'Ayesha Khan', 'email': testEmail},
  {'id': _bilal, 'full_name': 'Bilal Ahmed', 'email': null},
];

const Map<String, Object?> _invitationRow = {
  'id': '0192d0c4-1111-7000-8000-000000000001',
  'email': 'kamran@example.com',
  'role': 'accountant',
  'expires_at': '2026-11-14T05:00:00.5+00:00',
  'created_at': '2026-11-07T05:00:00+00:00',
};

const Map<String, Object?> _inviteAnswer = {
  'invitation_id': '0192d0c4-1111-7000-8000-000000000003',
  'email': 'kamran@example.com',
  'role': 'accountant',
  'expires_at': '2026-11-14T05:00:00+00:00',
  'invite_url': 'https://maalik-e-makaan.vercel.app/invite#token=abc.def',
  'email_delivery': 'sent',
};

void main() {
  late MockSupabase supabase;
  late SupabaseTeamRepository repository;

  setUp(() {
    supabase = MockSupabase((request) async {
      if (request.url.path.endsWith('/profiles')) {
        return jsonResponse(_profileRows);
      }
      return jsonResponse(_memberRows);
    });
    repository = SupabaseTeamRepository(supabase.client);
  });

  group('models', () {
    test('a member reads its membership and profile', () {
      final member = TeamMember.fromRows(_memberRows[1], _profileRows[0]);
      expect(member, ayeshaMember);
      expect(member.joinedAt.isUtc, isTrue);
      expect(TeamMember.fromJson(member.toJson()), member);
      expect(member.hashCode, ayeshaMember.hashCode);
      final hidden = TeamMember.fromRows(_memberRows[2], null);
      expect(hidden.fullName, isEmpty);
      expect(hidden.email, isNull);
    });

    test('malformed members and invitations are refused', () {
      for (final (member, profile) in <(Object?, Object?)>[
        (null, null),
        ({'user_id': 'x', 'role': 'owner'}, null),
        ({..._memberRows[0], 'role': 'landlord'}, null),
        ({..._memberRows[0], 'created_at': 'yesterday'}, null),
        (_memberRows[0], {'id': _bilal, 'email': 'x'}),
        (_memberRows[0], {'id': _bilal, 'full_name': 3, 'email': null}),
      ]) {
        expect(
          () => TeamMember.fromRows(member, profile),
          throwsFormatException,
          reason: '$member $profile',
        );
      }
      for (final row in <Object?>[
        'x',
        {..._invitationRow}..remove('expires_at'),
        {..._invitationRow, 'role': 'boss'},
        {..._invitationRow, 'email': null},
      ]) {
        expect(
          () => Invitation.fromRow(row),
          throwsFormatException,
          reason: '$row',
        );
      }
    });

    test('an invitation knows when it expires', () {
      final invitation = Invitation.fromRow(_invitationRow);
      expect(invitation.expiresAt, DateTime.utc(2026, 11, 14, 5, 0, 0, 500));
      expect(invitation.isExpired(DateTime.utc(2026, 11, 14)), isFalse);
      expect(invitation.isExpired(invitation.expiresAt), isTrue);
      expect(Invitation.fromRow(invitation.toRow()), invitation);
      expect(invitation.hashCode, Invitation.fromRow(_invitationRow).hashCode);
    });

    test('a team counts roles and survives the cache', () {
      final team = Team(
        members: [ayeshaMember, bilalMember, saraMember],
        invitations: [pendingInvitation],
      );
      expect(team.count(MemberRole.owner), 1);
      expect(team.count(MemberRole.accountant), 0);
      expect(Team.fromJson(team.toJson()), team);
      expect(Team.fromJson(team.toJson()).hashCode, team.hashCode);
      expect(
        () => Team.fromJson(const {'members': <Object?>[]}),
        throwsFormatException,
      );
    });

    test('members are sorted by role, then name or address, then id', () {
      TeamMember member(
        String id,
        MemberRole role,
        String name, [
        String? email,
      ]) => TeamMember(
        userId: id,
        role: role,
        fullName: name,
        email: email,
        joinedAt: DateTime.utc(2026),
      );
      final viewer = member('a', MemberRole.viewer, 'Aamir');
      final ownerZ = member('b', MemberRole.owner, 'Zainab');
      final ownerA = member('c', MemberRole.owner, '', 'asad@example.com');
      final ownerA2 = member('d', MemberRole.owner, 'asad@example.com');
      final nobody = member('e', MemberRole.owner, '');
      expect(sortMembers([viewer, ownerZ, ownerA2, ownerA, nobody]), [
        nobody,
        ownerA,
        ownerA2,
        ownerZ,
        viewer,
      ]);
    });

    test('an invitation link reads the function answer', () {
      final link = InvitationLink.fromJson(_inviteAnswer);
      expect(link.url.fragment, 'token=abc.def');
      expect(link.delivery, EmailDelivery.sent);
      expect(link, InvitationLink.fromJson(_inviteAnswer));
      expect(link.hashCode, InvitationLink.fromJson(_inviteAnswer).hashCode);
      for (final (value, delivery) in [
        ('not_configured', EmailDelivery.notConfigured),
        ('rate_limited', EmailDelivery.rateLimited),
        ('failed', EmailDelivery.failed),
        ('carrier_pigeon', EmailDelivery.unknown),
        ('unknown', EmailDelivery.unknown),
      ]) {
        expect(
          InvitationLink.fromJson({..._inviteAnswer, 'email_delivery': value})
              .delivery,
          delivery,
        );
      }
      for (final json in <Object?>[
        {..._inviteAnswer, 'invite_url': 'javascript:alert(1)'},
        {..._inviteAnswer, 'invite_url': '::'},
        {..._inviteAnswer}..remove('email_delivery'),
        {..._inviteAnswer, 'role': 'king'},
      ]) {
        expect(
          () => InvitationLink.fromJson(json),
          throwsFormatException,
          reason: '$json',
        );
      }
    });

    test('accepting answers with a status', () {
      expect(
        AcceptOutcome.fromJson({
          'status': 'accepted',
          'portfolio_id': gulberg.id,
          'role': 'viewer',
        }),
        InvitationAccepted(portfolioId: gulberg.id, role: MemberRole.viewer),
      );
      expect(
        InvitationAccepted(
          portfolioId: gulberg.id,
          role: MemberRole.viewer,
        ).hashCode,
        InvitationAccepted(
          portfolioId: gulberg.id,
          role: MemberRole.viewer,
        ).hashCode,
      );
      for (final refusal in InvitationRefusal.values) {
        expect(
          AcceptOutcome.fromJson({'status': refusal.db}),
          InvitationRefused(refusal),
        );
      }
      expect(
        AcceptOutcome.fromJson(const {'status': 'abducted'}),
        const InvitationRefused(InvitationRefusal.unknown),
      );
      expect(
        const InvitationRefused(InvitationRefusal.expired).hashCode,
        InvitationRefusal.expired.hashCode,
      );
      expect(
        () => AcceptOutcome.fromJson(const {'status': 'accepted'}),
        throwsFormatException,
      );
      expect(() => AcceptOutcome.fromJson('accepted'), throwsFormatException);
    });
  });

  group('reading', () {
    test('members are read with their profiles, owners first', () async {
      final members = await repository.members(gulberg.id);
      expect(
        [for (final m in members) m.fullName],
        ['Ayesha Khan', 'Bilal Ahmed', ''],
      );
      expect(members[1].email, isNull);
      final [memberships, profiles] = supabase.requests;
      expect(memberships.method, 'GET');
      expect(memberships.url.path, '/rest/v1/portfolio_members');
      expect(memberships.url.queryParameters, {
        'select': 'user_id,role,created_at',
        'portfolio_id': 'eq.${gulberg.id}',
      });
      expect(profiles.url.path, '/rest/v1/profiles');
      expect(profiles.url.queryParameters, {
        'select': 'id,full_name,email',
        'id': 'in.("$_bilal","$testUserId","no-profile")',
      });
    });

    test('a portfolio without members asks for no profiles', () async {
      supabase.respond = (_) async => jsonResponse(<Object?>[]);
      expect(await repository.members(gulberg.id), isEmpty);
      expect(supabase.requests, hasLength(1));
    });

    test(
      'pending invitations: neither accepted nor revoked, newest first',
      () async {
        supabase.respond = (_) async => jsonResponse([_invitationRow]);
        final invitations = await repository.pendingInvitations(gulberg.id);
        expect(invitations.single.email, 'kamran@example.com');
        expect(supabase.request.url.queryParameters, {
          'select': 'id,email,role,expires_at,created_at',
          'portfolio_id': 'eq.${gulberg.id}',
          'accepted_at': 'is.null',
          'revoked_at': 'is.null',
          'order': 'created_at.desc.nullslast',
        });
      },
    );

    test('read failures are AppFailures', () async {
      supabase.respond = (_) async => postgrestError('PGRST301', status: 401);
      await expectLater(
        repository.members(gulberg.id),
        throwsA(isA<SessionExpired>()),
      );
      supabase.respond = (_) async => jsonResponse([
        {'user_id': 'x'},
      ]);
      await expectLater(
        repository.pendingInvitations(gulberg.id),
        throwsA(isA<ServerFailure>()),
      );
    });
  });

  group('inviting', () {
    test('posts to invite-member and reads the link', () async {
      supabase.respond = (_) async => jsonResponse(_inviteAnswer, status: 201);
      final link = await repository.invite(
        portfolioId: gulberg.id,
        email: '  Kamran@Example.com ',
        role: MemberRole.accountant,
        language: AppLanguage.urdu,
      );
      expect(link.email, 'kamran@example.com');
      final request = supabase.request;
      expect(request.method, 'POST');
      expect(request.url.toString(), '$supabaseUrl/functions/v1/invite-member');
      expect(bodyOf(request), {
        'portfolio_id': gulberg.id,
        'email': 'kamran@example.com',
        'role': 'accountant',
        'locale': 'ur',
      });
    });

    test('maps the refusals', () async {
      final cases = {
        functionError(
          422,
          'validation_failed',
          details: {'reason': 'already_member'},
        ): 'already_member',
        functionError(
          422,
          'validation_failed',
          details: {'field': 'email', 'reason': 'not_an_email'},
        ): 'invalid_email',
        functionError(
          422,
          'validation_failed',
          details: {'reason': 'invalid_role'},
        ): 'invalid_role',
      };
      for (final MapEntry(key: response, value: reason) in cases.entries) {
        supabase.respond = (_) async => response;
        await expectLater(
          repository.invite(
            portfolioId: gulberg.id,
            email: 'x@example.com',
            role: MemberRole.viewer,
            language: AppLanguage.english,
          ),
          throwsA(
            isA<RejectedFailure>().having((f) => f.reason, 'reason', reason),
          ),
        );
      }
      supabase.respond = (_) async => functionError(403, 'forbidden');
      await expectLater(
        repository.invite(
          portfolioId: gulberg.id,
          email: 'x@example.com',
          role: MemberRole.viewer,
          language: AppLanguage.english,
        ),
        throwsA(isA<Forbidden>()),
      );
      supabase.respond = (_) async =>
          functionError(429, 'rate_limited', details: {'retry_after': 60});
      await expectLater(
        repository.invite(
          portfolioId: gulberg.id,
          email: 'x@example.com',
          role: MemberRole.viewer,
          language: AppLanguage.english,
        ),
        throwsA(isA<RateLimited>()),
      );
      supabase.respond = (_) async => jsonResponse({'invitation_id': 'x'});
      await expectLater(
        repository.invite(
          portfolioId: gulberg.id,
          email: 'x@example.com',
          role: MemberRole.viewer,
          language: AppLanguage.english,
        ),
        throwsA(isA<ServerFailure>()),
      );
    });
  });

  group('membership functions', () {
    setUp(() => supabase.respond = (_) async => jsonResponse(null));

    test('revoke_invitation', () async {
      await repository.revokeInvitation('i1');
      expect(supabase.request.url.path, '/rest/v1/rpc/revoke_invitation');
      expect(bodyOf(supabase.request), {'p_invitation_id': 'i1'});
    });

    test('update_member_role', () async {
      await repository.changeRole(
        portfolioId: gulberg.id,
        userId: _bilal,
        role: MemberRole.accountant,
      );
      expect(supabase.request.url.path, '/rest/v1/rpc/update_member_role');
      expect(bodyOf(supabase.request), {
        'p_portfolio_id': gulberg.id,
        'p_user_id': _bilal,
        'p_role': 'accountant',
      });
    });

    test('remove_member', () async {
      await repository.removeMember(portfolioId: gulberg.id, userId: _bilal);
      expect(supabase.request.url.path, '/rest/v1/rpc/remove_member');
      expect(bodyOf(supabase.request), {
        'p_portfolio_id': gulberg.id,
        'p_user_id': _bilal,
      });
    });

    test('set_caretaker names a manager or clears the caretaker', () async {
      await repository.setCaretaker(portfolioId: gulberg.id, userId: _bilal);
      expect(supabase.request.url.path, '/rest/v1/rpc/set_caretaker');
      expect(bodyOf(supabase.request), {
        'p_portfolio_id': gulberg.id,
        'p_user_id': _bilal,
      });
      await repository.setCaretaker(portfolioId: gulberg.id, userId: null);
      expect(bodyOf(supabase.requests.last), {
        'p_portfolio_id': gulberg.id,
        'p_user_id': null,
      });
    });

    test('set_caretaker refusals', () async {
      for (final reason in ['member_not_found', 'caretaker_not_manager']) {
        supabase.respond = (_) async =>
            postgrestError('22023', message: reason);
        await expectLater(
          repository.setCaretaker(portfolioId: gulberg.id, userId: _bilal),
          throwsA(
            isA<RejectedFailure>().having((f) => f.reason, 'reason', reason),
          ),
        );
      }
      supabase.respond = (_) async => postgrestError('42501', status: 403);
      await expectLater(
        repository.setCaretaker(portfolioId: gulberg.id, userId: _bilal),
        throwsA(isA<Forbidden>()),
      );
    });

    test('accept_invitation', () async {
      supabase.respond = (_) async => jsonResponse({'status': 'expired'});
      expect(
        await repository.accept('abc.def'),
        const InvitationRefused(InvitationRefusal.expired),
      );
      expect(supabase.request.url.path, '/rest/v1/rpc/accept_invitation');
      expect(bodyOf(supabase.request), {'p_token': 'abc.def'});
    });

    test('their refusals are RejectedFailures', () async {
      for (final reason in ['last_owner', 'member_not_found', 'invalid_role']) {
        supabase.respond = (_) async =>
            postgrestError('22023', message: reason);
        await expectLater(
          repository.changeRole(
            portfolioId: gulberg.id,
            userId: _bilal,
            role: MemberRole.viewer,
          ),
          throwsA(
            isA<RejectedFailure>().having((f) => f.reason, 'reason', reason),
          ),
        );
      }
      supabase.respond = (_) async => postgrestError('42501', status: 403);
      await expectLater(
        repository.removeMember(portfolioId: gulberg.id, userId: _bilal),
        throwsA(isA<Forbidden>()),
      );
      await expectLater(
        repository.revokeInvitation('i1'),
        throwsA(isA<Forbidden>()),
      );
      supabase.respond = (_) async =>
          postgrestError('rate_limited', status: 429, hint: '600');
      await expectLater(
        repository.accept('abc.def'),
        throwsA(isA<RateLimited>()),
      );
    });
  });
}
