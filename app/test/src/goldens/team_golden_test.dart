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

import '../../support/harness.dart';

/// A taller window for the 200% text variant, where a screen needs it.
Map<MmVariant, Size> _large(double height) => {
  MmVariant.largeText: Size(360, height),
};

void main() {
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
    size: const Size(360, 1700),
    sizes: {
      MmVariant.largeText: const Size(360, 3600),
      MmVariant.urdu: const Size(360, 2200),
    },
  );
}
