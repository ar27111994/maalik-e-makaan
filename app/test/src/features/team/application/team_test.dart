import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maalik_e_makaan/src/auth/auth_repository.dart';
import 'package:maalik_e_makaan/src/core/failure.dart';
import 'package:maalik_e_makaan/src/data/cache/swr_cache.dart';
import 'package:maalik_e_makaan/src/features/account/data/profile.dart';
import 'package:maalik_e_makaan/src/features/portfolios/application/portfolio_details.dart';
import 'package:maalik_e_makaan/src/features/portfolios/application/portfolios.dart';
import 'package:maalik_e_makaan/src/features/portfolios/data/portfolio.dart';
import 'package:maalik_e_makaan/src/features/portfolios/data/portfolio_details.dart';
import 'package:maalik_e_makaan/src/features/team/application/invitation.dart';
import 'package:maalik_e_makaan/src/features/team/application/team.dart';
import 'package:maalik_e_makaan/src/features/team/data/team.dart';
import 'package:maalik_e_makaan/src/settings/app_settings.dart';
import 'package:mm_core/mm_core.dart';

import '../../../../support/container.dart';
import '../../../../support/harness.dart';

/// Reads [membership]'s team once it has settled.
Future<Team> _team(
  ProviderContainer container,
  PortfolioMembership membership,
) async {
  listen(container, teamProvider(membership));
  await pumpEventQueue();
  return container.read(teamProvider(membership)).value!.value;
}

List<String> _names(List<Call> calls) => [for (final call in calls) call.$1];

void main() {
  group('reading the team', () {
    test('an owner reads the members and the pending invitations', () async {
      final app = TestApp();
      final team = await _team(containerFor(app), gulberg);
      expect(team.members, [ayeshaMember, bilalMember, saraMember]);
      expect(team.invitations, [pendingInvitation, expiredInvitation]);
      expect(_names(app.team.calls), ['members', 'pendingInvitations']);
    });

    test('others read no invitations', () async {
      final app = TestApp();
      final team = await _team(containerFor(app), plaza);
      expect(team.members, hasLength(2));
      expect(team.invitations, isEmpty);
      expect(_names(app.team.calls), ['members']);
    });

    test('the saved team shows first, and is kept when offline', () async {
      final app = TestApp()..team.readFailure = const NetworkFailure();
      const saved = Team(members: [], invitations: []);
      await app.cache.write(testUserId, 'team.${gulberg.id}', saved.toJson());
      final container = containerFor(app);
      listen(container, teamProvider(gulberg));
      await pumpEventQueue();
      final state = container.read(teamProvider(gulberg));
      expect(state.value!.value, saved);
      expect(state.value!.fromCache, isTrue);
      expect(state.error, isA<NetworkFailure>());
    });

    test('nobody signed in is an expired session', () async {
      final container = containerFor(TestApp(auth: const SignedOut()));
      listen(container, teamProvider(gulberg));
      await pumpEventQueue();
      expect(
        container.read(teamProvider(gulberg)).error,
        isA<SessionExpired>(),
      );
    });
  });

  group('commands', () {
    late TestApp app;
    late ProviderContainer container;
    TeamController team() => container.read(teamProvider(gulberg).notifier);

    setUp(() async {
      app = TestApp();
      container = containerFor(app);
      await _team(container, gulberg);
      app.team.calls.clear();
    });

    test('inviting returns the link and lists the invitation', () async {
      final link = await team().invite(
        email: 'Kamran.New@example.com',
        role: MemberRole.manager,
        language: AppLanguage.urdu,
      );
      expect(link.email, 'kamran.new@example.com');
      expect(app.team.calls.first.$2, [
        gulberg.id,
        'Kamran.New@example.com',
        MemberRole.manager,
        AppLanguage.urdu,
      ]);
      final shown = container.read(teamProvider(gulberg)).value!;
      expect(shown.source, SnapshotSource.network);
      expect(shown.value.invitations.first.email, 'kamran.new@example.com');
      // Saved for next time.
      final saved = await app.cache.read(
        testUserId,
        'team.${gulberg.id}',
        Team.fromJson,
      );
      expect(saved!.value, shown.value);
    });

    test('a refusal throws and changes nothing', () async {
      app.team.gate.failure = const RejectedFailure('already_member');
      await expectLater(
        team().invite(
          email: 'bilal.ahmed@example.com',
          role: MemberRole.viewer,
          language: AppLanguage.english,
        ),
        throwsA(isA<RejectedFailure>()),
      );
      expect(_names(app.team.calls), ['invite']);
    });

    test('revoking drops the invitation', () async {
      await team().revoke(pendingInvitation.id);
      expect(container.read(teamProvider(gulberg)).value!.value.invitations, [
        expiredInvitation,
      ]);
    });

    test("changing someone's role shows it", () async {
      await team().changeRole(bilalMember.userId, MemberRole.accountant);
      final members = container
          .read(teamProvider(gulberg))
          .value!
          .value
          .members;
      expect(members[1].role, MemberRole.accountant);
      expect(app.portfolios.calls.where((c) => c.$1 == 'listMine'), isEmpty);
    });

    test('changing your own role reads the portfolios again', () async {
      await team().changeRole(testUserId, MemberRole.manager);
      expect(
        app.portfolios.calls.where((c) => c.$1 == 'listMine'),
        hasLength(2),
      );
    });

    test('when the portfolios cannot be read again, they start over', () async {
      listen(container, portfoliosProvider(testUserId));
      await pumpEventQueue();
      app.portfolios.listFailure = const NetworkFailure();
      await team().changeRole(testUserId, MemberRole.manager);
      await pumpEventQueue();
      expect(
        container.read(portfoliosProvider(testUserId)).error,
        isA<NetworkFailure>(),
      );
    });

    test('removing someone takes them off the team', () async {
      await team().remove(saraMember.userId);
      expect(container.read(teamProvider(gulberg)).value!.value.members, [
        ayeshaMember,
        bilalMember,
      ]);
    });

    test(
      'a failed refresh after a command shows the error, not a failure',
      () async {
        app.team.readFailure = const NetworkFailure();
        await team().remove(saraMember.userId);
        await pumpEventQueue();
        final state = container.read(teamProvider(gulberg));
        expect(state.error, isA<NetworkFailure>());
        // The saved copy is still on screen.
        expect(state.value!.value.members, hasLength(3));
      },
    );

    test('leaving removes the user and moves to another portfolio', () async {
      listen(container, currentPortfolioProvider);
      app.portfolios.memberships.remove(gulberg);
      await team().leave();
      expect(app.team.calls.single.$2, [gulberg.id, testUserId]);
      expect(container.read(currentPortfolioProvider).value, plaza);
    });

    group('the caretaker', () {
      int detailsReads() =>
          app.portfolios.calls.where((c) => c.$1 == 'details').length;

      setUp(() async {
        listen(container, portfolioDetailsProvider(gulberg.id));
        await pumpEventQueue();
      });

      test('naming a manager reads the settings again', () async {
        final before = detailsReads();
        await team().setCaretaker(bilalMember.userId);
        await pumpEventQueue();
        expect(app.team.calls.last.$2, [gulberg.id, bilalMember.userId]);
        expect(app.team.caretakers[gulberg.id], bilalMember.userId);
        expect(detailsReads(), before + 1);
        await team().setCaretaker(null);
        expect(app.team.caretakers[gulberg.id], isNull);
      });

      test('only a manager may be named', () async {
        await expectLater(
          team().setCaretaker(saraMember.userId),
          throwsA(
            isA<RejectedFailure>().having(
              (f) => f.reason,
              'reason',
              'caretaker_not_manager',
            ),
          ),
        );
        await expectLater(
          team().setCaretaker('someone-else'),
          throwsA(
            isA<RejectedFailure>().having(
              (f) => f.reason,
              'reason',
              'member_not_found',
            ),
          ),
        );
      });

      test('a role change or removal reads the settings again', () async {
        // The server clears a caretaker who stops being manager.
        final before = detailsReads();
        await team().changeRole(bilalMember.userId, MemberRole.viewer);
        await pumpEventQueue();
        expect(detailsReads(), before + 1);
        await team().remove(bilalMember.userId);
        await pumpEventQueue();
        expect(detailsReads(), before + 2);
      });
    });

    test('leaving while signed out is an expired session', () async {
      app.auth.emit(const SignedOut());
      await pumpEventQueue();
      await expectLater(team().leave(), throwsA(isA<SessionExpired>()));
    });
  });

  group('portfolio details', () {
    test('are read, saved, and the new name reaches the list', () async {
      final app = TestApp();
      final container = containerFor(app);
      listen(container, portfolioDetailsProvider(gulberg.id));
      listen(container, currentPortfolioProvider);
      await pumpEventQueue();
      expect(
        container.read(portfolioDetailsProvider(gulberg.id)).value!.value,
        gulbergDetails,
      );
      final renamed = PortfolioDetails(
        id: gulberg.id,
        name: 'Gulberg Homes',
        defaultDueDay: 10,
        defaultGraceDays: 3,
        defaultIncrementBasisPoints: 500,
      );
      final saved = await container
          .read(portfolioDetailsProvider(gulberg.id).notifier)
          .save(renamed);
      expect(saved, renamed);
      expect(
        container.read(portfolioDetailsProvider(gulberg.id)).value!.value,
        renamed,
      );
      expect(
        container.read(currentPortfolioProvider).value!.name,
        'Gulberg Homes',
      );
    });

    test('changing the owner-abroad answer shows it everywhere', () async {
      final app = TestApp();
      final container = containerFor(app);
      listen(container, portfolioDetailsProvider(gulberg.id));
      listen(container, currentPortfolioProvider);
      await pumpEventQueue();
      final answer = await container
          .read(portfolioDetailsProvider(gulberg.id).notifier)
          .changeOwnerAbroad(abroad: true);
      expect(answer, OwnerAbroad.abroad);
      expect(
        app.portfolios.calls.firstWhere((c) => c.$1 == 'changeOwnerAbroad').$2,
        [gulberg.id, true],
      );
      expect(
        container
            .read(portfolioDetailsProvider(gulberg.id))
            .value!
            .value
            .ownerAbroad,
        OwnerAbroad.abroad,
      );
      expect(
        container.read(currentPortfolioProvider).value!.ownerAbroad,
        OwnerAbroad.abroad,
      );
      // A save keeps it: no client writes the answer.
      await container
          .read(portfolioDetailsProvider(gulberg.id).notifier)
          .save(gulbergDetails);
      expect(
        container
            .read(portfolioDetailsProvider(gulberg.id))
            .value!
            .value
            .ownerAbroad,
        OwnerAbroad.abroad,
      );
    });

    test('a refused change throws and keeps the answer', () async {
      final app = TestApp()
        ..portfolios.ownerAbroadFailure = const RejectedFailure(
          'owner_abroad_answered',
        );
      final container = containerFor(app);
      listen(container, portfolioDetailsProvider(gulberg.id));
      await pumpEventQueue();
      await expectLater(
        container
            .read(portfolioDetailsProvider(gulberg.id).notifier)
            .changeOwnerAbroad(abroad: false),
        throwsA(isA<RejectedFailure>()),
      );
      expect(
        container.read(portfolioDetailsProvider(gulberg.id)).value!.value,
        gulbergDetails,
      );
    });

    test('a list that cannot be read again starts over', () async {
      final app = TestApp();
      final container = containerFor(app);
      listen(container, portfolioDetailsProvider(gulberg.id));
      listen(container, currentPortfolioProvider);
      await pumpEventQueue();
      app.portfolios.listFailure = const NetworkFailure();
      await container
          .read(portfolioDetailsProvider(gulberg.id).notifier)
          .save(gulbergDetails);
      expect(
        container.read(portfolioDetailsProvider(gulberg.id)).value!.value,
        gulbergDetails,
      );
    });
  });

  group('a pending invitation', () {
    test('is kept on the device, tidy and bounded', () async {
      final app = TestApp();
      final container = containerFor(app);
      final pending = container.read(pendingInvitationProvider.notifier);
      expect(container.read(pendingInvitationProvider), isNull);
      await pending.hold('   ');
      await pending.hold('x' * 201);
      expect(container.read(pendingInvitationProvider), isNull);
      await pending.hold(' abc.def ');
      expect(container.read(pendingInvitationProvider), 'abc.def');
      expect(app.settings.values[AppSettings.pendingInvitationKey], 'abc.def');
      // A new start reads it back.
      expect(containerFor(app).read(pendingInvitationProvider), 'abc.def');
      await pending.clear();
      expect(
        app.settings.values,
        isNot(contains(AppSettings.pendingInvitationKey)),
      );
    });

    test('accepted, it opens the portfolio and is forgotten', () async {
      final app =
          TestApp(settings: {AppSettings.pendingInvitationKey: 'abc.def'})
            ..team.acceptOutcome = InvitationAccepted(
              portfolioId: plaza.id,
              role: MemberRole.manager,
            );
      final container = containerFor(app);
      listen(container, currentPortfolioProvider);
      await pumpEventQueue();
      expect(container.read(currentPortfolioProvider).value, gulberg);
      final outcome = await container
          .read(pendingInvitationProvider.notifier)
          .accept();
      expect(outcome, isA<InvitationAccepted>());
      expect(app.team.calls.single.$2, ['abc.def']);
      expect(container.read(currentPortfolioProvider).value, plaza);
      expect(container.read(pendingInvitationProvider), isNull);
    });

    test(
      'accepted while the list cannot be read, it still selects it',
      () async {
        final app = TestApp(
          settings: {AppSettings.pendingInvitationKey: 'abc.def'},
        );
        final container = containerFor(app);
        listen(container, currentPortfolioProvider);
        await pumpEventQueue();
        app.portfolios.listFailure = const NetworkFailure();
        await container.read(pendingInvitationProvider.notifier).accept();
        expect(
          container.read(selectedPortfolioProvider(testUserId)),
          gulberg.id,
        );
      },
    );

    test('refused, it is forgotten unless the account is the reason', () async {
      for (final reason in InvitationRefusal.values) {
        final app = TestApp(
          settings: {AppSettings.pendingInvitationKey: 'abc.def'},
        )..team.acceptOutcome = InvitationRefused(reason);
        final container = containerFor(app);
        final outcome = await container
            .read(pendingInvitationProvider.notifier)
            .accept();
        expect(outcome, InvitationRefused(reason));
        final kept =
            reason == InvitationRefusal.emailMismatch ||
            reason == InvitationRefusal.emailNotVerified;
        expect(
          container.read(pendingInvitationProvider),
          kept ? 'abc.def' : isNull,
          reason: '$reason',
        );
      }
    });

    test('a failure keeps it to try again', () async {
      final app = TestApp(
        settings: {AppSettings.pendingInvitationKey: 'abc.def'},
      )..team.gate.failure = const NetworkFailure();
      final container = containerFor(app);
      await expectLater(
        container.read(pendingInvitationProvider.notifier).accept(),
        throwsA(isA<NetworkFailure>()),
      );
      expect(container.read(pendingInvitationProvider), 'abc.def');
    });

    test('without one there is nothing to accept', () async {
      final app = TestApp();
      final outcome = await containerFor(app)
          .read(pendingInvitationProvider.notifier)
          .accept();
      expect(outcome, const InvitationRefused(InvitationRefusal.invalid));
      expect(app.team.calls, isEmpty);
    });

    test('the token comes from the fragment of the link', () {
      expect(invitationToken(Uri.parse('/invite#token=abc.def')), 'abc.def');
      expect(invitationToken(Uri.parse('/invite#x=1&token=a%2Eb')), 'a.b');
      expect(invitationToken(Uri.parse('/invite')), isNull);
      expect(invitationToken(Uri.parse('/invite#')), isNull);
      expect(invitationToken(Uri.parse('/invite#token=')), isNull);
      expect(invitationToken(Uri.parse('/invite#other=1')), isNull);
      expect(invitationToken(Uri.parse('/invite#token=%E0%A4%A')), isNull);
    });
  });
}
