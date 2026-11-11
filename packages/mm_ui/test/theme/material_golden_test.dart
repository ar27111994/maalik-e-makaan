@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mm_core/mm_core.dart';
import 'package:mm_ui/mm_ui.dart';

import '../support/harness.dart';

/// Stock Material widgets as the theme styles them, in the states the
/// theme changes: keyboard focus on filled and outlined controls, disabled
/// buttons, segmented buttons, chips, badges and tabs, and user data and
/// amounts in the other script.
class _MaterialSpecimen extends StatefulWidget {
  const new();

  @override
  State<_MaterialSpecimen> createState() => _MaterialSpecimenState();
}

class _MaterialSpecimenState extends State<_MaterialSpecimen> {
  /// One "focused" state per control that shows focus without holding it
  /// (only one widget can hold real focus: the floating action button).
  final List<WidgetStatesController> _focused = [
    for (var i = 0; i < 6; i++) WidgetStatesController({WidgetState.focused}),
  ];

  @override
  void dispose() {
    for (final controller in _focused) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mm = context.mm;
    final text = Theme.of(context).textTheme;
    final urdu = mm.script == MmScript.urdu;
    String say(String english, String inUrdu) => urdu ? inUrdu : english;
    final record = say('Record payment', 'ادائیگی درج کریں');
    final edit = say('Edit', 'ایڈٹ کریں');
    // A name in the other script than the UI's, and a tenant's advance as a
    // negative amount: the minus stays on the left of the figures.
    final name = urdu ? 'Ali Raza' : 'علی رضا';
    final advance = MmFormats.moneyOf(context)
        .format(const Money.fromRupees(-5000));
    final urduAdvance = const MoneyFormat(language: MoneyLanguage.urdu)
        .format(const Money.fromRupees(-125000));
    Widget row(List<Widget> children) => Wrap(
      spacing: MmSpace.s3,
      runSpacing: MmSpace.s3,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: children,
    );
    return ColoredBox(
      color: mm.colors.bg,
      child: Padding(
        padding: const EdgeInsets.all(MmSpace.s3),
        child: SizedBox(
          width: 312,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            spacing: MmSpace.s3,
            children: [
              row([
                FilledButton(
                  statesController: _focused[0],
                  onPressed: () {},
                  child: Text(record),
                ),
                FilledButton(onPressed: null, child: Text(record)),
                FilledButton(onPressed: () {}, child: Text(record)),
              ]),
              row([
                OutlinedButton(
                  statesController: _focused[1],
                  onPressed: () {},
                  child: Text(say('Send reminder', 'یاد دہانی بھیجیں')),
                ),
                TextButton(onPressed: null, child: Text(say('Skip', 'چھوڑیں'))),
              ]),
              row([
                IconButton.filled(
                  statesController: _focused[2],
                  onPressed: () {},
                  tooltip: edit,
                  icon: const Icon(MmIcons.edit),
                ),
                IconButton.outlined(
                  onPressed: () {},
                  tooltip: edit,
                  icon: const Icon(MmIcons.edit),
                ),
                IconButton.outlined(
                  statesController: _focused[3],
                  onPressed: () {},
                  tooltip: edit,
                  icon: const Icon(MmIcons.edit),
                ),
                IconButton(
                  statesController: _focused[4],
                  onPressed: () {},
                  tooltip: edit,
                  icon: const Icon(MmIcons.edit),
                ),
                FloatingActionButton(
                  autofocus: true,
                  onPressed: () {},
                  tooltip: say('Add tenant', 'کرایہ دار شامل کریں'),
                  child: const Icon(MmIcons.add),
                ),
              ]),
              SegmentedButton<int>(
                segments: [
                  ButtonSegment(
                    value: 0,
                    label: Text(say('Monthly', 'ماہانہ')),
                  ),
                  ButtonSegment(value: 1, label: Text(say('Yearly', 'سالانہ'))),
                ],
                selected: const {0},
                onSelectionChanged: (_) {},
              ),
              row([
                FilterChip(
                  label: Text(say('Gulberg', 'گلبرگ')),
                  selected: true,
                  onSelected: (_) {},
                ),
                FilterChip(
                  label: Text(say('Model Town', 'ماڈل ٹاؤن')),
                  onSelected: (_) {},
                ),
              ]),
              // Badges grow with the text only as far as navigation labels
              // do (as MmAdaptiveScaffold's), so they never hide their icon.
              MediaQuery.withClampedTextScaling(
                maxScaleFactor: 1.3,
                child: Row(
                  spacing: MmSpace.s8,
                  children: [
                    Badge.count(
                      count: 3,
                      child: Icon(MmIcons.notifications, color: mm.colors.ink),
                    ),
                    Badge.count(
                      count: 1250,
                      child: Icon(MmIcons.tenants, color: mm.colors.ink),
                    ),
                  ],
                ),
              ),
              DefaultTabController(
                length: 2,
                child: TabBar(
                  isScrollable: true,
                  tabAlignment: TabAlignment.start,
                  tabs: [
                    Tab(height: MmSize.minTarget, text: say('Dues', 'چارجز')),
                    Tab(
                      height: MmSize.minTarget,
                      text: say('Payments', 'ادائیگیاں'),
                    ),
                  ],
                ),
              ),
              Text(name, style: mm.styleFor(name, text.bodyLarge!)),
              Text(advance, style: mm.amount),
              Text(urduAdvance, style: mm.amount),
            ],
          ),
        ),
      ),
    );
  }
}

void main() {
  goldenEveryVariant(
    'material_widgets',
    () => const _MaterialSpecimen(),
    size: const Size(360, 1000),
  );
}
