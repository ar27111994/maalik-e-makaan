import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maalik_e_makaan/src/shell/pending_screen.dart';

import '../../support/harness.dart';

void main() {
  final builders = <String, Widget Function(BuildContext)>{
    'Dashboard': PendingScreen.dashboard,
    'Properties': PendingScreen.properties,
    'Tenants': PendingScreen.tenants,
    'Money': PendingScreen.money,
  };

  for (final MapEntry(key: name, value: builder) in builders.entries) {
    testWidgets('$name says it is being built', (tester) async {
      await pumpScreen(tester, () => Builder(builder: builder));
      expect(find.text(name), findsOneWidget);
      expect(find.text('$name is being built'), findsOneWidget);
      expect(
        find.text('This part of the app arrives in the next update.'),
        findsOneWidget,
      );
    });
  }

  testEveryVariant('fits and reads well', (tester, variant) async {
    await pumpScreen(
      tester,
      () => const Builder(builder: PendingScreen.dashboard),
      variant: variant,
      size: const Size(320, 640),
    );
    expect(tester.takeException(), isNull);
    await expectAccessible(tester);
  });
}
