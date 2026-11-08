import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maalik_e_makaan/src/auth/auth_repository.dart';
import 'package:maalik_e_makaan/src/core/display_text.dart';
import 'package:maalik_e_makaan/src/core/failure.dart';
import 'package:maalik_e_makaan/src/features/account/data/profile.dart';
import 'package:maalik_e_makaan/src/features/portfolios/data/portfolio.dart';
import 'package:maalik_e_makaan/src/features/portfolios/presentation/portfolio_details_screen.dart';
import 'package:maalik_e_makaan/src/features/team/data/team.dart';
import 'package:maalik_e_makaan/src/features/team/presentation/accept_invitation_screen.dart';
import 'package:maalik_e_makaan/src/features/team/presentation/invite_member_screen.dart';
import 'package:maalik_e_makaan/src/features/team/presentation/team_screen.dart';
import 'package:maalik_e_makaan/src/routing/routes.dart';
import 'package:maalik_e_makaan/src/settings/app_settings.dart';
import 'package:mm_core/mm_core.dart';
import 'package:mm_ui/mm_ui.dart';

import '../../../../support/harness.dart';

/// The test app working in Saddar Plaza, where the user is a manager.
TestApp _inPlaza() => TestApp(
  settings: {AppSettings.currentPortfolioKey: '$testUserId/${plaza.id}'},
);

/// The test app with an invitation link opened on the device.
TestApp _invited([AcceptOutcome? outcome]) {
  final app = TestApp(settings: {AppSettings.pendingInvitationKey: 'abc.def'});
  if (outcome != null) app.team.acceptOutcome = outcome;
  return app;
}

Future<void> _tap(WidgetTester tester, String text) async {
  await tester.ensureVisible(find.text(text).last);
  await tester.tap(find.text(text).last);
  await tester.pumpAndSettle();
}

/// Confirms the open dialog with its button labelled [label].
Future<void> _confirm(WidgetTester tester, String label) async {
  await tester.tap(
    find.descendant(
      of: find.byWidgetPredicate((widget) => widget is Dialog),
      matching: find.text(label),
    ),
  );
  await tester.pumpAndSettle();
}

/// Captures what the app puts on the clipboard.
List<String> _clipboard(WidgetTester tester) {
  final copied = <String>[];
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    SystemChannels.platform,
    (call) async {
      if (call.method == 'Clipboard.setData') {
        copied.add((call.arguments as Map)['text'] as String);
      }
      return null;
    },
  );
  addTearDown(
    () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      null,
    ),
  );
  return copied;
}

void main() {
  group('the team', () {
    testWidgets('an owner sees members, invitations and can invite', (
      tester,
    ) async {
      await pumpScreen(tester, TeamScreen.new, size: const Size(360, 1400));
      expect(find.text('Ayesha Khan (you)'), findsOneWidget);
      expect(
        find.text('Manager\u00a0· bilal.ahmed@\u200bexample.com'),
        findsOneWidget,
      );
      // A member without a name is shown by their address.
      expect(find.text(breakableEmail('sara@example.com')), findsOneWidget);
      expect(find.text('Viewer'), findsOneWidget);
      expect(find.text('Invitations waiting for an answer'), findsOneWidget);
      expect(find.text('Accountant\u00a0· Until 14 Nov 2099'), findsOneWidget);
      expect(find.text('Viewer\u00a0· Expired on 9 Jan 2026'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(MmStatusBadge),
          matching: find.textContaining('Expired', findRichText: true),
        ),
        findsOneWidget,
      );
      await _tap(tester, 'Invite someone');
      expect(routeShown(Routes.inviteMember), findsOneWidget);
    });

    testWidgets('an owner changes a role', (tester) async {
      final app = await pumpScreen(tester, TeamScreen.new);
      await _tap(tester, 'Bilal Ahmed');
      expect(find.byType(MemberSheet), findsOneWidget);
      expect(
        find.text(breakableEmail('bilal.ahmed@example.com')),
        findsWidgets,
      );
      // Nothing to save until the role changes.
      final change = find.widgetWithText(MmButton, 'Change role');
      expect(tester.widget<MmButton>(change).onPressed, isNull);
      await _tap(tester, 'Accountant');
      await _tap(tester, 'Change role');
      expect(find.byType(MemberSheet), findsNothing);
      expect(find.text('Bilal Ahmed is now Accountant.'), findsOneWidget);
      expect(app.team.calls.firstWhere((c) => c.$1 == 'changeRole').$2, [
        gulberg.id,
        bilalMember.userId,
        MemberRole.accountant,
      ]);
      expect(
        find.text('Accountant\u00a0· bilal.ahmed@\u200bexample.com'),
        findsOneWidget,
      );
    });

    testWidgets('a refused role change says why in the sheet', (tester) async {
      final app = await pumpScreen(tester, TeamScreen.new);
      app.team.gate.failure = const RejectedFailure('member_not_found');
      await _tap(tester, 'Bilal Ahmed');
      await _tap(tester, 'Viewer');
      await _tap(tester, 'Change role');
      expect(find.byType(MemberSheet), findsOneWidget);
      expect(
        find.text('This person is no longer in the portfolio.'),
        findsOneWidget,
      );
    });

    testWidgets('an owner removes a member after confirming', (tester) async {
      final app = await pumpScreen(tester, TeamScreen.new);
      await _tap(tester, breakableEmail('sara@example.com'));
      await _tap(tester, 'Remove from portfolio');
      expect(find.text('Remove sara@example.com?'), findsOneWidget);
      // Cancelling keeps them.
      await _tap(tester, 'Cancel');
      expect(app.team.calls.where((c) => c.$1 == 'removeMember'), isEmpty);
      await _tap(tester, 'Remove from portfolio');
      await _confirm(tester, 'Remove from portfolio');
      expect(find.text('sara@example.com was removed.'), findsOneWidget);
      expect(find.text(breakableEmail('sara@example.com')), findsNothing);
    });

    testWidgets('the only owner cannot change their role or leave', (
      tester,
    ) async {
      await pumpScreen(tester, TeamScreen.new, size: const Size(360, 1400));
      expect(
        find.text(
          'You are the only owner. '
          'Make someone else an owner before you leave.',
        ),
        findsOneWidget,
      );
      expect(
        tester
            .widget<MmButton>(find.widgetWithText(MmButton, 'Leave portfolio'))
            .onPressed,
        isNull,
      );
      await _tap(tester, 'Ayesha Khan (you)');
      expect(
        find.textContaining('A portfolio always keeps an owner.'),
        findsOneWidget,
      );
      expect(find.text('Remove from portfolio'), findsNothing);
    });

    testWidgets('an owner with another owner may change their own role', (
      tester,
    ) async {
      final app = TestApp();
      app.team.people[gulberg.id]!.add(
        TeamMember(
          userId: 'second-owner',
          role: MemberRole.owner,
          fullName: 'Zubair Khan',
          email: 'zubair@example.com',
          joinedAt: DateTime.utc(2026, 4),
        ),
      );
      await pumpScreen(tester, TeamScreen.new, app: app);
      await _tap(tester, 'Ayesha Khan (you)');
      expect(find.text('Change role'), findsOneWidget);
      // Yourself you leave, not remove.
      expect(find.text('Remove from portfolio'), findsNothing);
    });

    testWidgets('an owner cancels an invitation, or sends it again', (
      tester,
    ) async {
      final app = await pumpScreen(
        tester,
        TeamScreen.new,
        size: const Size(360, 1400),
      );
      await _tap(tester, breakableEmail('kamran@example.com'));
      expect(find.byType(InvitationSheet), findsOneWidget);
      expect(find.text('Works until'), findsOneWidget);
      await _tap(tester, 'Cancel invitation');
      expect(
        find.text('Cancel the invitation to kamran@\u200bexample.com?'),
        findsOneWidget,
      );
      // Its way out names itself: "Cancel" beside it is ambiguous.
      expect(find.text('Keep the invitation'), findsOneWidget);
      await _confirm(tester, 'Cancel invitation');
      expect(find.text('Invitation cancelled.'), findsOneWidget);
      expect(app.team.calls.firstWhere((c) => c.$1 == 'revokeInvitation').$2, [
        pendingInvitation.id,
      ]);
      expect(find.text(breakableEmail('kamran@example.com')), findsNothing);
      await _tap(tester, breakableEmail('nadia@example.com'));
      expect(find.text('Expired', findRichText: true), findsWidgets);
      await _tap(tester, 'Invite again');
      expect(
        find.textContaining('route:${Routes.inviteMember}'),
        findsOneWidget,
      );
    });

    testWidgets('a failed cancellation stays in the sheet', (tester) async {
      final app = await pumpScreen(tester, TeamScreen.new);
      app.team.gate.failure = const Forbidden();
      await _tap(tester, breakableEmail('kamran@example.com'));
      await _tap(tester, 'Cancel invitation');
      await _confirm(tester, 'Cancel invitation');
      expect(find.byType(InvitationSheet), findsOneWidget);
      expect(
        find.text('You do not have permission to do this.'),
        findsOneWidget,
      );
    });

    testWidgets('others see the team, and may leave', (tester) async {
      final app = _inPlaza();
      await pumpScreen(tester, TeamScreen.new, app: app);
      expect(find.text('Imran Qureshi'), findsOneWidget);
      expect(find.text('Invite someone'), findsNothing);
      expect(find.byIcon(MmIcons.chevronEnd), findsNothing);
      // Tapping a member does nothing for a manager.
      await _tap(tester, 'Imran Qureshi');
      expect(find.byType(MemberSheet), findsNothing);
      app.portfolios.memberships.remove(plaza);
      await _tap(tester, 'Leave portfolio');
      expect(find.text('Leave Saddar Plaza?'), findsOneWidget);
      await _confirm(tester, 'Leave portfolio');
      expect(app.team.calls.firstWhere((c) => c.$1 == 'removeMember').$2, [
        plaza.id,
        testUserId,
      ]);
      expect(routeShown(Routes.home), findsOneWidget);
      expect(find.text('You left Saddar Plaza.'), findsOneWidget);
    });

    testWidgets('a refused leave says why', (tester) async {
      final app = _inPlaza();
      await pumpScreen(tester, TeamScreen.new, app: app);
      app.team.gate.failure = const RejectedFailure('last_owner');
      await _tap(tester, 'Leave portfolio');
      await _confirm(tester, 'Leave portfolio');
      expect(
        find.textContaining('A portfolio needs at least one owner.'),
        findsOneWidget,
      );
    });

    testWidgets('a team that cannot load says so, with a retry', (
      tester,
    ) async {
      final app = TestApp()..team.readFailure = const Forbidden();
      await pumpScreen(tester, TeamScreen.new, app: app);
      expect(find.text('The team could not be loaded'), findsOneWidget);
      app.team.readFailure = null;
      await _tap(tester, 'Try again');
      expect(find.text('Ayesha Khan (you)'), findsOneWidget);
    });

    testWidgets('while loading, a skeleton', (tester) async {
      final app = TestApp()..team.gate.close();
      await pumpScreen(tester, TeamScreen.new, app: app, settle: false);
      await tester.pump();
      expect(find.bySemanticsLabel('Loading the team'), findsOneWidget);
      app.team.gate.open();
      await tester.pumpAndSettle();
    });

    testWidgets('without a portfolio yet, a skeleton', (tester) async {
      final app = TestApp()..portfolios.gate.close();
      await pumpScreen(tester, TeamScreen.new, app: app, settle: false);
      expect(find.bySemanticsLabel('Loading the team'), findsOneWidget);
      app.portfolios.gate.open();
      await tester.pumpAndSettle();
    });
  });

  group('inviting', () {
    Future<void> fill(WidgetTester tester, String email) async {
      await tester.enterText(find.byType(TextField).first, email);
      await tester.pump();
    }

    testWidgets('checks the address, then shows the link', (tester) async {
      final app = await pumpScreen(
        tester,
        InviteMemberScreen.new,
        size: const Size(360, 1200),
      );
      final copied = _clipboard(tester);
      await _tap(tester, 'Send invitation');
      expect(shown('Enter this to continue.'), findsOneWidget);
      await fill(tester, 'not an address');
      expect(
        shown('Enter an e-mail address like name@example.com.'),
        findsOneWidget,
      );
      await fill(tester, 'Kamran@Example.com');
      await _tap(tester, 'Viewer');
      await _tap(tester, 'Send invitation');
      expect(app.team.calls.firstWhere((c) => c.$1 == 'invite').$2, [
        gulberg.id,
        'Kamran@Example.com',
        MemberRole.viewer,
        AppLanguage.english,
      ]);
      expect(find.text('Invitation ready'), findsOneWidget);
      expect(
        find.text('We e-mailed the invitation to kamran@\u200bexample.com.'),
        findsOneWidget,
      );
      expect(
        find.textContaining('The link works once, until 14 Nov 2099'),
        findsOneWidget,
      );
      await _tap(tester, 'Copy link');
      expect(copied.single, contains('/invite#token='));
      expect(find.text('Link copied.'), findsOneWidget);
      await _tap(tester, 'Share on WhatsApp');
      final whatsApp = app.opened.single;
      expect(whatsApp.host, 'wa.me');
      expect(
        whatsApp.queryParameters['text'],
        startsWith('You are invited to Gulberg Houses on Maalik-e-Makaan.'),
      );
      expect(whatsApp.queryParameters['text'], contains(copied.single));
      app.canOpenLinks = false;
      await _tap(tester, 'Share on WhatsApp');
      expect(find.text('The link could not be opened.'), findsOneWidget);
      await _tap(tester, 'Done');
      expect(routeShown(Routes.team), findsOneWidget);
    });

    testWidgets('says when the e-mail did not go', (tester) async {
      for (final (delivery, words) in [
        (EmailDelivery.notConfigured, 'E-mail is not set up'),
        (EmailDelivery.rateLimited, 'Too many e-mails'),
        (EmailDelivery.failed, 'could not be sent'),
        (EmailDelivery.unknown, 'did not get an e-mail'),
      ]) {
        final app = TestApp()..team.delivery = delivery;
        await pumpScreen(tester, InviteMemberScreen.new, app: app);
        await fill(tester, 'kamran@example.com');
        await _tap(tester, 'Send invitation');
        expect(find.textContaining(words), findsOneWidget, reason: '$delivery');
      }
    });

    testWidgets('an address that cannot be invited is shown on the field', (
      tester,
    ) async {
      final app = TestApp()
        ..team.gate.failure = const RejectedFailure('already_member');
      await pumpScreen(tester, InviteMemberScreen.new, app: app);
      await fill(tester, 'bilal.ahmed@example.com');
      await _tap(tester, 'Send invitation');
      expect(
        tester.widget<MmTextField>(find.byType(MmTextField)).errorText,
        'This person is already in the portfolio.',
      );
      await fill(tester, 'bilal@example.com');
      expect(
        tester.widget<MmTextField>(find.byType(MmTextField)).errorText,
        isNull,
      );
    });

    testWidgets('other failures go above the form; cancel goes back', (
      tester,
    ) async {
      final app = TestApp()..team.gate.failure = const NetworkFailure();
      await pumpScreen(tester, InviteMemberScreen.new, app: app);
      await fill(tester, 'kamran@example.com');
      await _tap(tester, 'Send invitation');
      expect(
        find.text('No connection. Check your internet and try again.'),
        findsOneWidget,
      );
      await _tap(tester, 'Cancel');
      expect(routeShown(Routes.team), findsOneWidget);
    });

    testWidgets('inviting again starts from the earlier invitation', (
      tester,
    ) async {
      await pumpScreen(
        tester,
        () => const InviteMemberScreen(
          draft: InviteDraft(
            email: 'nadia@example.com',
            role: MemberRole.owner,
          ),
        ),
      );
      expect(find.text('nadia@example.com'), findsOneWidget);
      final group = tester.widget<MmRadioGroup<MemberRole>>(
        find.byType(MmRadioGroup<MemberRole>),
      );
      expect(group.value, MemberRole.owner);
    });
  });

  group('accepting an invitation', () {
    testWidgets('welcomes the new member to the portfolio', (tester) async {
      final app = _invited(
        InvitationAccepted(portfolioId: plaza.id, role: MemberRole.manager),
      );
      await pumpScreen(tester, AcceptInvitationScreen.new, app: app);
      expect(find.text('Welcome to Saddar Plaza'), findsOneWidget);
      expect(find.text('You joined as Manager.'), findsOneWidget);
      expect(app.team.calls.single.$2, ['abc.def']);
      expect(
        app.settings.values[AppSettings.currentPortfolioKey],
        '$testUserId/${plaza.id}',
      );
      await _tap(tester, 'Open the portfolio');
      expect(routeShown(Routes.home), findsOneWidget);
    });

    testWidgets('a portfolio not listed yet is welcomed without a name', (
      tester,
    ) async {
      final app = _invited(
        const InvitationAccepted(portfolioId: 'new', role: MemberRole.viewer),
      );
      await pumpScreen(tester, AcceptInvitationScreen.new, app: app);
      expect(find.text('You joined the portfolio'), findsOneWidget);
    });

    testWidgets('shows progress while it accepts', (tester) async {
      final app = _invited()..team.gate.close();
      await pumpScreen(
        tester,
        AcceptInvitationScreen.new,
        app: app,
        settle: false,
      );
      await tester.pump();
      expect(find.text('Opening your invitation…'), findsOneWidget);
      app.team.gate.open();
      await tester.pumpAndSettle();
    });

    testWidgets('says why an invitation cannot be used', (tester) async {
      for (final (reason, words) in [
        (InvitationRefusal.invalid, 'not a working invitation link'),
        (InvitationRefusal.revoked, 'was cancelled'),
        (InvitationRefusal.alreadyUsed, 'accepted already'),
        (InvitationRefusal.expired, 'has expired'),
        (InvitationRefusal.emailNotVerified, 'Confirm your e-mail address'),
        (InvitationRefusal.unknown, 'cannot be accepted'),
      ]) {
        final app = _invited(InvitationRefused(reason));
        await pumpScreen(tester, AcceptInvitationScreen.new, app: app);
        expect(find.text('This invitation cannot be used'), findsOneWidget);
        expect(find.textContaining(words), findsOneWidget, reason: '$reason');
        expect(find.text('Sign out'), findsNothing);
        await _tap(tester, 'Go to the app');
        expect(routeShown(Routes.home), findsOneWidget);
        expect(
          app.settings.values,
          isNot(contains(AppSettings.pendingInvitationKey)),
        );
      }
    });

    testWidgets('another address can sign out and keep the invitation', (
      tester,
    ) async {
      final app = _invited(
        const InvitationRefused(InvitationRefusal.emailMismatch),
      );
      await pumpScreen(tester, AcceptInvitationScreen.new, app: app);
      expect(
        find.textContaining('sent to another e-mail address'),
        findsOneWidget,
      );
      expect(find.text(breakableEmail(testEmail)), findsOneWidget);
      await _tap(tester, 'Sign out');
      expect(app.auth.calls.single.$1, 'signOut');
      expect(app.settings.values[AppSettings.pendingInvitationKey], 'abc.def');
    });

    testWidgets('offline, it can try again or be set aside', (tester) async {
      final app = _invited()..team.gate.failure = const NetworkFailure();
      await pumpScreen(tester, AcceptInvitationScreen.new, app: app);
      expect(find.text('The invitation could not be opened'), findsOneWidget);
      app.team.gate.failure = null;
      await _tap(tester, 'Try again');
      expect(find.text('Welcome to Gulberg Houses'), findsOneWidget);
    });

    testWidgets('setting it aside forgets it', (tester) async {
      final app = _invited()..team.gate.failure = const NetworkFailure();
      await pumpScreen(tester, AcceptInvitationScreen.new, app: app);
      await _tap(tester, 'Not now');
      expect(routeShown(Routes.home), findsOneWidget);
      expect(
        app.settings.values,
        isNot(contains(AppSettings.pendingInvitationKey)),
      );
    });

    testWidgets('without an invitation it says where to find one', (
      tester,
    ) async {
      await pumpScreen(tester, AcceptInvitationScreen.new);
      expect(find.textContaining('No invitation is waiting'), findsOneWidget);
      await _tap(tester, 'Go to the app');
      expect(routeShown(Routes.home), findsOneWidget);
    });
  });

  group('portfolio details', () {
    Finder field(String label) => find.byWidgetPredicate(
      (widget) => widget is MmTextField && widget.label == label,
    );

    Future<void> type(WidgetTester tester, String label, String text) async {
      await tester.ensureVisible(field(label));
      await tester.enterText(
        find.descendant(of: field(label), matching: find.byType(TextField)),
        text,
      );
      await tester.pump();
    }

    testWidgets('an owner checks and saves them', (tester) async {
      final app = await pumpScreen(
        tester,
        PortfolioDetailsScreen.new,
        size: const Size(360, 2000),
      );
      expect(find.text('Gulberg Houses'), findsOneWidget);
      expect(find.text('PK36 SCBL 0000 0011 2345 6702'), findsOneWidget);
      await type(tester, 'Yearly increase (%)', '120');
      await type(tester, 'Phone on receipts', '12');
      await type(tester, 'Raast ID', '0423456789');
      await type(tester, 'IBAN', 'PK00 SCBL 0000 0011 2345 6702');
      await _tap(tester, 'Save');
      expect(shown('Enter a percentage from 0 to 100'), findsOneWidget);
      expect(shown('Enter a phone number like 03001234567.'), findsOneWidget);
      expect(shown('Enter a Pakistani mobile number'), findsOneWidget);
      expect(shown('Enter a Pakistani IBAN'), findsOneWidget);
      expect(
        app.portfolios.calls.where((c) => c.$1 == 'updateDetails'),
        isEmpty,
      );

      await type(tester, 'Portfolio name', 'Gulberg Homes');
      await type(tester, 'Yearly increase (%)', '۱۲.۵');
      await type(tester, 'Phone on receipts', '');
      await type(tester, 'Raast ID', '03211234567');
      await type(tester, 'IBAN', '');
      await type(tester, 'Name on receipts', '  ');
      await tester.ensureVisible(find.byType(MmStepperField));
      await tester.tap(find.byTooltip('More days'));
      await tester.pump();
      await tester.ensureVisible(find.text('Rent due on day'));
      await tester.tap(find.text('5').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('10').last);
      await tester.pumpAndSettle();
      await _tap(tester, 'Save');
      final saved = app.portfolios.calls
          .lastWhere((c) => c.$1 == 'updateDetails')
          .$2
          .single;
      expect(saved, isA<Object>());
      final details = app.portfolios.details_[gulberg.id]!;
      expect(details.name, 'Gulberg Homes');
      expect(details.defaultIncrementBasisPoints, 1250);
      expect(details.defaultGraceDays, 6);
      expect(details.defaultDueDay, 10);
      expect(details.landlordPhone, isNull);
      expect(details.landlordName, isNull);
      expect(details.raastId, PhoneNumber.fromE164('+923211234567'));
      expect(details.bankIban, isNull);
      expect(find.text('Portfolio details saved.'), findsOneWidget);
    });

    testWidgets('a refusal is shown above the form; cancel goes back', (
      tester,
    ) async {
      final app = await pumpScreen(tester, PortfolioDetailsScreen.new);
      app.portfolios.gate.failure = const RejectedFailure(
        'constraint_violation',
      );
      await _tap(tester, 'Save');
      expect(find.textContaining('Some details are not valid'), findsOneWidget);
      await type(tester, 'Portfolio name', 'Gulberg');
      expect(find.textContaining('Some details are not valid'), findsNothing);
      await _tap(tester, 'Cancel');
      expect(routeShown(Routes.more), findsOneWidget);
    });

    testWidgets('an owner deletes it once its name is typed', (tester) async {
      final app = await pumpScreen(
        tester,
        PortfolioDetailsScreen.new,
        size: const Size(360, 2400),
      );
      expect(find.text('Delete this portfolio'), findsOneWidget);
      final button = find.widgetWithText(MmButton, 'Delete portfolio');
      // It asks first: outlined, the dialog's button is the filled one.
      expect(
        tester.widget<MmButton>(button).variant,
        MmButtonVariant.destructiveOutlined,
      );
      await tester.ensureVisible(button);
      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(find.textContaining('and everything in it?'), findsOneWidget);
      final dialog = find.byWidgetPredicate((widget) => widget is Dialog);
      final typed = find.descendant(
        of: dialog,
        matching: find.byType(TextField),
      );
      // A server refusal is shown beside the button, not above the form.
      app.portfolios.deleteFailure = const TemporarilyUnavailable();
      await tester.enterText(typed, 'Gulberg Houses');
      await tester.pump();
      await _confirm(tester, 'Delete portfolio');
      expect(app.portfolios.memberships, hasLength(2));
      final banner = find.byType(MmBanner);
      expect(banner, findsOneWidget);
      expect(
        tester.getTopLeft(banner).dy,
        greaterThan(tester.getTopLeft(find.text('Delete this portfolio')).dy),
      );

      app.portfolios.deleteFailure = null;
      await tester.ensureVisible(button);
      await tester.tap(button);
      await tester.pumpAndSettle();
      await tester.enterText(typed, 'Gulberg Houses');
      await tester.pump();
      await _confirm(tester, 'Delete portfolio');
      expect(app.portfolios.calls.where((c) => c.$1 == 'delete').last.$2, [
        gulberg.id,
        'Gulberg Houses',
      ]);
      expect(app.portfolios.memberships, [plaza]);
      expect(routeShown(Routes.home), findsOneWidget);
      expect(find.textContaining('deleted.'), findsOneWidget);
    });

    testWidgets('others see them but cannot change them', (tester) async {
      await pumpScreen(tester, PortfolioDetailsScreen.new, app: _inPlaza());
      expect(find.text('Saddar Plaza'), findsOneWidget);
      expect(find.text('Save'), findsNothing);
      expect(find.text('Delete portfolio'), findsNothing);
      expect(
        tester.widget<MmTextField>(field('Portfolio name')).enabled,
        isFalse,
      );
    });

    testWidgets('details that cannot load say so, with a retry', (
      tester,
    ) async {
      final app = TestApp()..portfolios.detailsFailure = const Forbidden();
      await pumpScreen(tester, PortfolioDetailsScreen.new, app: app);
      expect(
        find.text('The portfolio details could not be loaded'),
        findsOneWidget,
      );
      app.portfolios.detailsFailure = null;
      await _tap(tester, 'Try again');
      expect(find.text('Gulberg Houses'), findsOneWidget);
    });

    testWidgets('while loading, a skeleton', (tester) async {
      final app = TestApp()..portfolios.gate.close();
      await pumpScreen(
        tester,
        PortfolioDetailsScreen.new,
        app: app,
        settle: false,
      );
      expect(
        find.bySemanticsLabel('Loading the portfolio details'),
        findsOneWidget,
      );
      app.portfolios.gate.open();
      await tester.pumpAndSettle();
      expect(find.text('Gulberg Houses'), findsOneWidget);
    });
  });

  testEveryVariant('team screens fit at 320 dp', (tester, variant) async {
    for (final (screen, app) in <(Widget Function(), TestApp Function())>[
      (TeamScreen.new, TestApp.new),
      (TeamScreen.new, _inPlaza),
      (InviteMemberScreen.new, TestApp.new),
      (PortfolioDetailsScreen.new, TestApp.new),
      (AcceptInvitationScreen.new, _invited),
      (
        AcceptInvitationScreen.new,
        () =>
            _invited(const InvitationRefused(InvitationRefusal.emailMismatch)),
      ),
    ]) {
      await pumpScreen(
        tester,
        screen,
        app: app(),
        variant: variant,
        size: const Size(320, 640),
      );
      expect(tester.takeException(), isNull, reason: '$screen');
      await expectAccessible(tester);
    }
  });

  testEveryVariant('the invitation link fits at 320 dp', (
    tester,
    variant,
  ) async {
    await pumpScreen(
      tester,
      InviteMemberScreen.new,
      variant: variant,
      size: const Size(320, 640),
    );
    await tester.enterText(find.byType(TextField).first, 'kamran@example.com');
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byType(InvitationReady), findsOneWidget);
    await expectAccessible(tester);
  });

  testWidgets('signed out, nothing is shown as you', (tester) async {
    await pumpScreen(
      tester,
      TeamScreen.new,
      app: TestApp(auth: const SignedOut()),
      settle: false,
    );
    expect(find.textContaining('(you)'), findsNothing);
  });
}
