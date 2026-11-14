import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maalik_e_makaan/src/features/insights/presentation/dashboard_screen.dart';
import 'package:maalik_e_makaan/src/features/portfolios/presentation/portfolio_details_screen.dart';
import 'package:maalik_e_makaan/src/features/team/presentation/team_screen.dart';
import 'package:maalik_e_makaan/src/features/tenants/presentation/tenant_detail_screen.dart';

import '../../support/harness.dart';

/// Where the test user says they live (D-16): theirs alone. These words
/// name it in either language.
const _residence = ['United Kingdom', 'برطانیہ', 'London', 'لندن'];

/// Every text on screen, rich text included.
List<String> _texts(WidgetTester tester) => [
  for (final text in tester.widgetList<RichText>(find.byType(RichText)))
    text.text.toPlainText(),
];

/// The texts that name the user's residence.
List<String> _naming(WidgetTester tester) => [
  for (final text in _texts(tester))
    if (_residence.any(text.contains)) text,
];

const _tall = Size(390, 3000);

void main() {
  for (final variant in [MmVariant.light, MmVariant.urdu]) {
    final language = variant.locale.languageCode;

    testWidgets('the team never shows where you live ($language)', (
      tester,
    ) async {
      await pumpScreen(
        tester,
        TeamScreen.new,
        app: TestApp(residence: residentInLondon),
        variant: variant,
        size: _tall,
      );
      expect(_naming(tester), isEmpty);
      await tester.tap(find.textContaining('Bilal').first);
      await tester.pumpAndSettle();
      expect(_naming(tester), isEmpty);
    });

    testWidgets('portfolio details never show where you live ($language)', (
      tester,
    ) async {
      await pumpScreen(
        tester,
        PortfolioDetailsScreen.new,
        app: TestApp(residence: residentInLondon),
        variant: variant,
        size: _tall,
      );
      expect(_naming(tester), isEmpty);
    });

    testWidgets('a tenant never sees or shows where you live ($language)', (
      tester,
    ) async {
      await pumpScreen(
        tester,
        () => TenantDetailScreen(tenantId: aliRaza.id),
        app: TestApp(residence: residentInLondon),
        variant: variant,
        size: _tall,
      );
      expect(_naming(tester), isEmpty);
    });

    testWidgets('the dashboard names your city only beside your own time, and '
        'keeps rupees ($language)', (tester) async {
      await pumpScreen(
        tester,
        DashboardScreen.new,
        app: TestApp(residence: residentInLondon),
        variant: variant,
        size: _tall,
      );
      final naming = _naming(tester);
      expect(naming, isNotEmpty);
      for (final text in naming) {
        // Only the city of a dual time: "… Pakistan time (5:30 AM London)".
        expect(text, isNot(contains('United Kingdom')));
        expect(text, isNot(contains('برطانیہ')));
        expect(
          text,
          anyOf(contains('Pakistan time ('), contains('پاکستانی وقت')),
        );
      }
      // Money stays in rupees: no other currency anywhere.
      for (final text in _texts(tester)) {
        expect(text, isNot(matches(RegExp(r'[£$€]|GBP|USD|EUR'))));
      }
      expect(
        _texts(tester).any((t) => t.contains('Rs') || t.contains('روپے')),
        isTrue,
      );
    });
  }
}
