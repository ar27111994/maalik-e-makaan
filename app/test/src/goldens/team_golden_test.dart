@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maalik_e_makaan/src/features/portfolios/data/portfolio.dart';
import 'package:maalik_e_makaan/src/features/portfolios/presentation/portfolio_details_screen.dart';
import 'package:maalik_e_makaan/src/features/team/data/team.dart';
import 'package:maalik_e_makaan/src/features/team/presentation/accept_invitation_screen.dart';
import 'package:maalik_e_makaan/src/features/team/presentation/invite_member_screen.dart';
import 'package:maalik_e_makaan/src/features/team/presentation/team_screen.dart';
import 'package:maalik_e_makaan/src/settings/app_settings.dart';
import 'package:mm_core/mm_core.dart';
import 'package:mm_ui/mm_ui.dart';

import '../../support/harness.dart';

/// A taller window for the 200% text variant, where a screen needs it.
Map<MmVariant, Size> _large(double height) => {
  MmVariant.largeText: Size(360, height),
};

/// Taps [finder]'s first match, after scrolling to it.
Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder.first);
  await tester.pumpAndSettle();
  await tester.tap(finder.first);
  await tester.pumpAndSettle();
}

/// The link buttons of Portfolio details' "Owner and caretaker".
Finder get _links => find.byWidgetPredicate(
  (w) => w is MmButton && w.variant == MmButtonVariant.link,
);

/// The test app working in Saddar Plaza, where the user is a manager.
TestApp _inPlaza({
  List<PortfolioMembership> portfolios = const [gulberg, plaza],
}) => TestApp(
  portfolios: portfolios,
  settings: {AppSettings.currentPortfolioKey: '$testUserId/${plaza.id}'},
);

/// [app] with Saddar Plaza's owner-abroad question unanswered.
TestApp _plazaUnanswered(TestApp app) {
  app.portfolios.details_[plaza.id] = withSettings(
    app.portfolios.details_[plaza.id]!,
    ownerAbroad: OwnerAbroad.notAnswered,
  );
  return app;
}

void main() {
  // A manager asked about a portfolio nobody has answered for (D-16).
  screenGoldenEveryVariant(
    'owner_abroad_question',
    PortfolioDetailsScreen.new,
    app: () => _plazaUnanswered(
      _inPlaza(portfolios: const [gulberg, plazaUnanswered]),
    ),
    size: const Size(360, 900),
    sizes: _large(2000),
    act: (tester) => _tap(tester, _links),
  );

  // Someone answered first: the sheet shows the answer that won.
  late TestApp answeredFirst;
  screenGoldenEveryVariant(
    'owner_abroad_answered_first',
    PortfolioDetailsScreen.new,
    app: () => answeredFirst = _plazaUnanswered(
      _inPlaza(portfolios: const [gulberg, plazaUnanswered]),
    ),
    size: const Size(360, 900),
    sizes: _large(2000),
    act: (tester) async {
      // An owner answered on another device after the screen was read.
      final list = answeredFirst.portfolios.memberships;
      list[list.indexWhere((m) => m.id == plaza.id)] = plaza.withOwnerAbroad(
        OwnerAbroad.inPakistan,
      );
      answeredFirst.portfolios.details_[plaza.id] = withSettings(
        answeredFirst.portfolios.details_[plaza.id]!,
        ownerAbroad: OwnerAbroad.inPakistan,
      );
      await _tap(tester, _links);
      await _tap(tester, find.byType(RadioListTile<OwnerAbroad>).first);
      await _tap(
        tester,
        find.descendant(
          of: find.byType(BottomSheet),
          matching: find.byType(FilledButton),
        ),
      );
    },
  );

  // A manager reads the answer; they are the caretaker, and cannot step
  // down but by leaving (Q7).
  screenGoldenEveryVariant(
    'portfolio_details_manager',
    PortfolioDetailsScreen.new,
    app: () => _inPlaza()
      ..portfolios.setCaretakerOf(
        plaza.id,
        testUserId,
        DateTime.utc(2026, 11, 3, 6),
      ),
    size: const Size(360, 1100),
    sizes: _large(2400),
  );

  // An owner chooses the caretaker among the managers, or none.
  screenGoldenEveryVariant(
    'caretaker_sheet',
    PortfolioDetailsScreen.new,
    size: const Size(360, 900),
    sizes: _large(2000),
    act: (tester) async {
      await _tap(tester, _links.last);
      await _tap(tester, find.byType(RadioListTile<String>).first);
    },
  );

  // The team marks the caretaker with a word and an icon.
  screenGoldenEveryVariant(
    'team_caretaker',
    TeamScreen.new,
    app: () => TestApp()
      ..portfolios.setCaretakerOf(
        gulberg.id,
        bilalMember.userId,
        DateTime.utc(2026, 11, 3, 6),
      ),
    size: const Size(360, 1100),
    sizes: _large(2600),
  );

  screenGoldenEveryVariant(
    'team',
    TeamScreen.new,
    size: const Size(360, 1100),
    sizes: _large(2600),
  );

  screenGoldenEveryVariant(
    'team_member_sheet',
    TeamScreen.new,
    size: const Size(360, 900),
    sizes: _large(1800),
    act: (tester) async {
      await tester.tap(
        find.textContaining('Bilal Ahmed', findRichText: true).first,
      );
      await tester.pumpAndSettle();
    },
  );

  screenGoldenEveryVariant(
    'invite_member',
    () => const InviteMemberScreen(
      draft: InviteDraft(
        email: 'kamran@example.com',
        role: MemberRole.accountant,
      ),
    ),
    size: const Size(360, 1000),
    sizes: _large(2300),
  );

  screenGoldenEveryVariant(
    'invitation_ready',
    InviteMemberScreen.new,
    app: () => TestApp()..team.delivery = EmailDelivery.rateLimited,
    size: const Size(360, 900),
    sizes: _large(1900),
    act: (tester) async {
      await tester.enterText(
        find.byType(TextField).first,
        'kamran@example.com',
      );
      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();
    },
  );

  screenGoldenEveryVariant(
    'invitation_accepted',
    AcceptInvitationScreen.new,
    app: () => TestApp(settings: {AppSettings.pendingInvitationKey: 'abc.def'}),
    sizes: _large(1000),
  );

  screenGoldenEveryVariant(
    'invitation_mismatch',
    AcceptInvitationScreen.new,
    app: () => TestApp(settings: {AppSettings.pendingInvitationKey: 'abc.def'})
      ..team.acceptOutcome = const InvitationRefused(
        InvitationRefusal.emailMismatch,
      ),
    size: const Size(360, 900),
    sizes: _large(1700),
  );

  screenGoldenEveryVariant(
    'portfolio_details',
    PortfolioDetailsScreen.new,
    // Taller since "Owner and caretaker" came before the defaults.
    size: const Size(360, 2100),
    sizes: {
      MmVariant.largeText: const Size(360, 4500),
      MmVariant.urdu: const Size(360, 2650),
    },
  );
}
