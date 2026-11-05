import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mm_ui/mm_ui.dart';

import 'harness.dart';

/// [text] in the body style of the theme, in [color] (ink by default), at
/// [size] and [weight] when given.
class _Line extends StatelessWidget {
  const new(this.text, {this.color, this.size, this.weight});

  final String text;
  final Color Function(MmColorTokens colors)? color;
  final double? size;
  final FontWeight? weight;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: Theme.of(context).textTheme.bodyMedium!.copyWith(
      color: (color ?? (colors) => colors.ink)(context.mm.colors),
      fontSize: size,
      fontWeight: weight,
    ),
  );
}

/// The outline role: a colour for borders, too light for text.
Color _outline(MmColorTokens colors) => colors.outline;

/// The rule role: hairlines only.
Color _rule(MmColorTokens colors) => colors.rule;

/// The runs measured on screen whose text is [text].
Future<MmTextContrast> _run(WidgetTester tester, String text) async =>
    (await measureTextContrast(tester)).singleWhere((run) => run.text == text);

Future<Evaluation> _evaluate(WidgetTester tester) =>
    mmTextContrastGuideline.evaluate(tester);

/// Expects the check to fail, naming [text] in its reason.
Future<void> _expectFailsOn(WidgetTester tester, String text) async {
  final evaluation = await _evaluate(tester);
  expect(evaluation.passed, isFalse);
  expect(evaluation.reason, contains('"$text"'));
}

void main() {
  const light = MmVariant.light;
  final paper = light.colors;

  group('mmTextContrastGuideline measures', () {
    testEveryVariant('ink and muted ink at their token contrast', (
      tester,
      variant,
    ) async {
      await pumpThemed(
        tester,
        const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _Line('Rent due'),
            _Line('Due on the 5th', color: _muted, size: 12),
          ],
        ),
        variant: variant,
      );
      final colors = variant.colors;
      final ink = await _run(tester, 'Rent due');
      expect(ink.color, colors.ink);
      expect(ink.background, colors.bg);
      expect(ink.ratio, mmContrastRatio(colors.ink, colors.bg));
      final muted = await _run(tester, 'Due on the 5th');
      expect(muted.color, colors.inkMuted);
      expect(muted.background, colors.bg);
      expect(muted.passes, isTrue);
      expect((await _evaluate(tester)).passed, isTrue);
    });

    testWidgets('the same ratio wherever thin text falls on the pixel grid', (
      tester,
    ) async {
      final ratios = <double>{};
      for (var step = 0; step < 16; step++) {
        final offset = Offset(step % 4 / 4, step ~/ 4 / 4);
        await pumpThemed(
          tester,
          Padding(
            padding: EdgeInsets.only(left: offset.dx, top: offset.dy),
            child: const _Line(
              'Reminders go to WhatsApp',
              color: _muted,
              size: 12,
            ),
          ),
          variant: MmVariant.lightHighContrast,
        );
        final run = await _run(tester, 'Reminders go to WhatsApp');
        expect(run.passes, isTrue, reason: '$offset: $run');
        ratios.add(run.ratio);
      }
      expect(ratios, hasLength(1));
    });

    testWidgets('the fill an ink decoration paints behind the text', (
      tester,
    ) async {
      await pumpThemed(
        tester,
        Builder(
          builder: (context) => Ink(
            color: context.mm.colors.primary,
            padding: const EdgeInsets.all(MmSpace.s3),
            child: const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _Line('Paid', color: _onPrimary),
                _Line('Overdue'),
              ],
            ),
          ),
        ),
      );
      final onPrimary = await _run(tester, 'Paid');
      expect(onPrimary.background, paper.primary);
      expect(onPrimary.passes, isTrue);
      final ink = await _run(tester, 'Overdue');
      expect(ink.background, paper.primary);
      expect(ink.ratio, mmContrastRatio(paper.ink, paper.primary));
      await _expectFailsOn(tester, 'Overdue');
    });
  });

  group('mmTextContrastGuideline fails', () {
    testWidgets('text in a colour too light for text', (tester) async {
      await pumpThemed(tester, const _Line('Gulberg, Lahore', color: _outline));
      final run = await _run(tester, 'Gulberg, Lahore');
      expect(run.ratio, mmContrastRatio(paper.outline, paper.bg));
      expect(run.ratio, lessThan(mmMinimumTextContrast));
      await _expectFailsOn(tester, 'Gulberg, Lahore');
    });

    testWidgets('large text below 3:1, but not large text above it', (
      tester,
    ) async {
      await pumpThemed(
        tester,
        const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _Line('Rs 45,000', color: _outline, size: mmLargeTextSize),
            _Line(
              'Rs 1,25,000',
              color: _outline,
              size: 19,
              weight: FontWeight.w700,
            ),
          ],
        ),
      );
      expect((await _evaluate(tester)).passed, isTrue);

      await pumpThemed(
        tester,
        const _Line('Rs 45,000', color: _rule, size: mmLargeTextSize),
      );
      final run = await _run(tester, 'Rs 45,000');
      expect(run.isLarge, isTrue);
      expect(run.ratio, lessThan(mmMinimumLargeTextContrast));
      await _expectFailsOn(tester, 'Rs 45,000');
    });

    testWidgets('large text only at the size the style sets', (tester) async {
      await pumpThemed(
        tester,
        const _Line('Ayesha Khan', color: _outline),
        variant: MmVariant.largeText,
      );
      final run = await _run(tester, 'Ayesha Khan');
      expect(run.isLarge, isFalse);
      await _expectFailsOn(tester, 'Ayesha Khan');
    });

    testWidgets('icons below the 3:1 of graphics, but not above it', (
      tester,
    ) async {
      await pumpThemed(
        tester,
        Builder(
          builder: (context) => Icon(
            MmIcons.home,
            size: MmSize.iconMd,
            color: context.mm.colors.outline,
          ),
        ),
      );
      final outline = (await measureTextContrast(tester)).single;
      expect(outline.isIcon, isTrue);
      expect(outline.minimum, mmMinimumIconContrast);
      expect(outline.passes, isTrue);

      await pumpThemed(
        tester,
        Builder(
          builder: (context) => Icon(
            MmIcons.home,
            size: MmSize.iconMd,
            color: context.mm.colors.rule,
          ),
        ),
      );
      final evaluation = await _evaluate(tester);
      expect(evaluation.passed, isFalse);
      expect(evaluation.reason, contains('Icon U+'));
    });

    testWidgets('translucent text', (tester) async {
      await pumpThemed(
        tester,
        _Line('Ali Raza', color: (colors) => colors.ink.withValues(alpha: .3)),
      );
      final run = await _run(tester, 'Ali Raza');
      expect(run.background, paper.bg);
      expect(run.ratio, lessThan(2));
      await _expectFailsOn(tester, 'Ali Raza');
    });

    testWidgets('text under an opacity or a fade', (tester) async {
      await pumpThemed(
        tester,
        const Opacity(opacity: .3, child: _Line('Ali Raza')),
      );
      await _expectFailsOn(tester, 'Ali Raza');

      await pumpThemed(
        tester,
        const FadeTransition(
          opacity: AlwaysStoppedAnimation(.3),
          child: _Line('Ayesha Khan'),
        ),
      );
      await _expectFailsOn(tester, 'Ayesha Khan');
    });

    testWidgets('text the colour of its background', (tester) async {
      await pumpThemed(tester, _Line('Shop 4', color: (colors) => colors.bg));
      final run = await _run(tester, 'Shop 4');
      expect(run.ratio, 1);
      await _expectFailsOn(tester, 'Shop 4');
    });

    testWidgets('one low-contrast span in rich text', (tester) async {
      await pumpThemed(
        tester,
        Builder(
          builder: (context) => Text.rich(
            TextSpan(
              text: 'Rent ',
              children: [
                TextSpan(
                  text: 'overdue',
                  style: TextStyle(color: context.mm.colors.rule),
                ),
              ],
            ),
          ),
        ),
      );
      expect((await _run(tester, 'Rent ')).passes, isTrue);
      await _expectFailsOn(tester, 'overdue');
    });

    testWidgets('text typed into a field', (tester) async {
      await pumpThemed(
        tester,
        Builder(
          builder: (context) => SizedBox(
            width: 280,
            child: TextField(
              controller: TextEditingController(text: '0300 1234567'),
              style: TextStyle(color: context.mm.colors.rule),
              decoration: const InputDecoration(labelText: 'Phone'),
            ),
          ),
        ),
      );
      await _expectFailsOn(tester, '0300 1234567');
    });

    testWidgets("a field's hint, under the field's input", (tester) async {
      await pumpThemed(
        tester,
        Builder(
          builder: (context) => SizedBox(
            width: 280,
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search tenants',
                hintStyle: TextStyle(color: context.mm.colors.outline),
              ),
            ),
          ),
        ),
      );
      await _expectFailsOn(tester, 'Search tenants');
    });

    testWidgets('an icon set in a line of text', (tester) async {
      await pumpThemed(
        tester,
        Builder(
          builder: (context) => Text.rich(
            TextSpan(
              text: 'Paid ',
              children: [
                WidgetSpan(
                  child: Icon(MmIcons.home, color: context.mm.colors.rule),
                ),
              ],
            ),
          ),
        ),
      );
      final evaluation = await _evaluate(tester);
      expect(evaluation.passed, isFalse);
      expect(evaluation.reason, contains('Icon U+'));
    });

    testWidgets(
      "text Flutter's guideline skips: excluded from semantics or merged",
      (tester) async {
        await pumpThemed(
          tester,
          const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ExcludeSemantics(child: _Line('Flat 2B', color: _rule)),
              MergeSemantics(
                child: Column(
                  children: [
                    _Line('Bilal Ahmed'),
                    _Line('Moved out', color: _rule),
                  ],
                ),
              ),
            ],
          ),
        );
        await expectLater(tester, meetsGuideline(textContrastGuideline));
        final evaluation = await _evaluate(tester);
        expect(evaluation.passed, isFalse);
        expect(evaluation.reason, contains('"Flat 2B"'));
        expect(evaluation.reason, contains('"Moved out"'));
      },
    );
  });

  group('mmTextContrastGuideline leaves out', () {
    testWidgets('disabled controls, which WCAG exempts', (tester) async {
      await pumpThemed(
        tester,
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Semantics(
              container: true,
              enabled: false,
              child: const _Line('Archived', color: _rule),
            ),
            MergeSemantics(
              child: Semantics(
                enabled: false,
                child: const _Line('Shop 4', color: _rule),
              ),
            ),
          ],
        ),
      );
      expect(await measureTextContrast(tester), isEmpty);
      expect((await _evaluate(tester)).passed, isTrue);
    });

    testWidgets('text that is not painted', (tester) async {
      await pumpThemed(
        tester,
        const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Offstage(child: _Line('Offstage', color: _outline)),
            Opacity(opacity: 0, child: _Line('Transparent', color: _outline)),
            Visibility(
              visible: false,
              maintainSize: true,
              maintainAnimation: true,
              maintainState: true,
              child: _Line('Invisible', color: _outline),
            ),
            _Line('Shown'),
          ],
        ),
      );
      final runs = await measureTextContrast(tester);
      expect([for (final run in runs) run.text], ['Shown']);
    });

    testWidgets('text under something opaque that lets taps through', (
      tester,
    ) async {
      await pumpThemed(
        tester,
        Builder(
          builder: (context) => Stack(
            children: [
              const _Line('Under the lid', color: _outline),
              Positioned.fill(
                child: IgnorePointer(
                  child: ColoredBox(color: context.mm.colors.surface),
                ),
              ),
            ],
          ),
        ),
      );
      expect(await measureTextContrast(tester), isEmpty);
    });

    testWidgets('text under a fill drawn on top of it', (tester) async {
      await pumpThemed(
        tester,
        Builder(
          builder: (context) => Stack(
            children: [
              const _Line('Under the card', color: _rule),
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(color: context.mm.colors.surface),
                ),
              ),
            ],
          ),
        ),
      );
      expect(await measureTextContrast(tester), isEmpty);
    });

    testWidgets('text scrolled out of view, until it is scrolled in', (
      tester,
    ) async {
      await pumpThemed(
        tester,
        SizedBox(
          height: 200,
          width: 300,
          child: ListView(
            children: const [
              SizedBox(height: 400),
              _Line('Below the fold', color: _rule),
            ],
          ),
        ),
      );
      expect((await _evaluate(tester)).passed, isTrue);
      await tester.drag(find.byType(ListView), const Offset(0, -300));
      await tester.pumpAndSettle();
      await _expectFailsOn(tester, 'Below the fold');
    });

    testWidgets('a page under a modal barrier, but not the dialog', (
      tester,
    ) async {
      await pumpThemed(tester, const _Line('Behind', color: _outline));
      await _expectFailsOn(tester, 'Behind');
      unawaited(
        showDialog<void>(
          context: tester.element(find.text('Behind')),
          builder: (context) => const AlertDialog(
            content: _Line('In the dialog', color: _outline),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final evaluation = await _evaluate(tester);
      expect(evaluation.reason, isNot(contains('"Behind"')));
      expect(evaluation.reason, contains('"In the dialog"'));
    });
  });
}

Color _muted(MmColorTokens colors) => colors.inkMuted;

Color _onPrimary(MmColorTokens colors) => colors.onPrimary;
