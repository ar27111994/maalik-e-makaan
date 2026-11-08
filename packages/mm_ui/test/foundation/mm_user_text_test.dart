import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mm_ui/mm_ui.dart';
import 'package:mm_ui/src/foundation/mm_line_icon.dart';
import 'package:mm_ui/src/foundation/mm_text_metrics.dart';
import 'package:mm_ui/src/foundation/mm_user_text.dart';

import '../support/testing.dart';

/// The family of the Latin face as the spans name it.
const _latin = 'packages/mm_ui/${MmFontFamily.latin}';

Widget _user(String text, {TextAlign? textAlign}) => Builder(
  builder: (context) => MmUserText(
    text,
    style: Theme.of(context).textTheme.bodyLarge!,
    textAlign: textAlign,
  ),
);

RenderParagraph _paragraph(WidgetTester tester) =>
    tester.renderObject<RenderParagraph>(
      find
          .descendant(
            of: find.byType(MmUserText),
            matching: find.byType(RichText),
          )
          .first,
    );

void main() {
  group('MmUserText', () {
    testWidgets('keeps Urdu text in the English UI in its own direction, and '
        'reads it as written', (tester) async {
      final semantics = tester.ensureSemantics();
      await pumpThemed(tester, _user('مکان 12، گلبرگ'));
      final shown = _paragraph(tester).text.toPlainText();
      expect(shown, '\u2067مکان 12، گلبرگ\u2069');
      expect(find.bySemanticsLabel('مکان 12، گلبرگ'), findsOneWidget);
      semantics.dispose();
    });

    testWidgets('keeps a Latin name in the Urdu UI in its own direction and '
        'the Latin face', (tester) async {
      await pumpThemed(tester, _user('Ali Raza'), variant: MmVariant.urdu);
      final paragraph = _paragraph(tester);
      expect(paragraph.text.toPlainText(), '\u2066Ali Raza\u2069');
      expect(paragraph.text.style!.fontFamily, _latin);
    });

    testWidgets('sets the Latin parts of an Urdu address in the Latin face', (
      tester,
    ) async {
      await pumpThemed(
        tester,
        _user('مکان 12، Gulberg III، لاہور', textAlign: TextAlign.end),
        variant: MmVariant.urdu,
      );
      final paragraph = _paragraph(tester);
      // Urdu text in the Urdu UI runs its own way already: no isolate.
      expect(paragraph.text.toPlainText(), 'مکان 12، Gulberg III، لاہور');
      expect(paragraph.textAlign, TextAlign.end);
      final latin = <String>[];
      paragraph.text.visitChildren((span) {
        if (span is TextSpan && span.style?.fontFamily == _latin) {
          latin.add(span.text!);
        }
        return true;
      });
      expect(latin, [' 12', ' Gulberg III']);
    });

    testWidgets('leaves text in the UI direction unchanged', (tester) async {
      await pumpThemed(tester, _user('Ali Raza'));
      expect(_paragraph(tester).text.toPlainText(), 'Ali Raza');
    });
  });

  group('MmTextMetrics', () {
    testWidgets('measures the widest word, one line and the line count', (
      tester,
    ) async {
      late MmTextMetrics wrapped;
      late MmTextMetrics word;
      late MmTextMetrics line;
      const style = TextStyle(fontSize: 10);
      await pumpThemed(
        tester,
        Builder(
          builder: (context) {
            final themed = Theme.of(context).textTheme.bodyLarge!.merge(style);
            wrapped = MmTextMetrics.of(
              context,
              'Dashboard Tenants',
              themed,
              maxWidth: 60,
            );
            word = MmTextMetrics.of(context, 'Dashboard', themed);
            line = MmTextMetrics.of(context, 'Dashboard Tenants', themed);
            return const SizedBox();
          },
        ),
      );
      expect(wrapped.lineCount, 2);
      expect(wrapped.minIntrinsicWidth, closeTo(word.maxIntrinsicWidth, 0.01));
      expect(line.lineCount, 1);
      expect(line.maxIntrinsicWidth, closeTo(line.size.width, 0.01));
      expect(line.maxIntrinsicWidth, greaterThan(word.maxIntrinsicWidth));
    });

    testWidgets('finds Nastaliq rising and falling past its lines', (
      tester,
    ) async {
      late MmTextMetrics urdu;
      await pumpThemed(
        tester,
        Builder(
          builder: (context) {
            urdu = MmTextMetrics.of(
              context,
              'کرایہ دار',
              Theme.of(context).textTheme.labelMedium!.copyWith(height: 1),
            );
            return const SizedBox();
          },
        ),
        variant: MmVariant.urdu,
      );
      expect(urdu.overhangAbove + urdu.overhangBelow, greaterThan(0));
    });
  });

  group('MmLineIcon', () {
    for (final (variant, scale) in [
      (MmVariant.light, 1.0),
      (MmVariant.urdu, 1.0),
      (MmVariant.largeText, 2.0),
    ]) {
      testWidgets('centres on the first line and grows at most half again '
          '(${variant.name})', (tester) async {
        late TextStyle style;
        await pumpThemed(
          tester,
          Builder(
            builder: (context) {
              style = Theme.of(context).textTheme.titleLarge!;
              return Align(
                alignment: AlignmentDirectional.topStart,
                child: MmLineIcon(
                  icon: MmIcons.property,
                  color: context.mm.colors.ink,
                  style: style,
                ),
              );
            },
          ),
          variant: variant,
        );
        final size = MmSize.iconLg * (scale > 1.5 ? 1.5 : scale);
        final icon = tester.getRect(find.byIcon(MmIcons.property));
        expect(icon.height, size);
        final line = style.fontSize! * scale * style.height!;
        final top = tester.getTopLeft(find.byType(MmLineIcon)).dy;
        expect(icon.center.dy - top, closeTo(line / 2, 0.01));
      });
    }

    testWidgets('is hidden from assistive technology', (tester) async {
      await pumpThemed(
        tester,
        Builder(
          builder: (context) => MmLineIcon(
            icon: MmIcons.property,
            color: context.mm.colors.ink,
            style: Theme.of(context).textTheme.bodyLarge!,
          ),
        ),
      );
      expect(
        find.ancestor(
          of: find.byIcon(MmIcons.property),
          matching: find.byType(ExcludeSemantics),
        ),
        findsOneWidget,
      );
    });
  });
}
