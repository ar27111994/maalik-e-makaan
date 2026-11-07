import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mm_ui/mm_ui.dart';
import 'package:mm_ui/src/foundation/mm_icon_label.dart';

import '../../support/testing.dart';
import 'support.dart';

const _title = 'Lease ending';
const _message = 'Ali Raza’s lease for Flat 3 ends in 14 days.';
const _action = 'Renew lease';

/// The fill of the banner.
BoxDecoration _decoration(WidgetTester tester) =>
    tester
            .widget<DecoratedBox>(
              find
                  .descendant(
                    of: find.byType(MmBanner),
                    matching: find.byType(DecoratedBox),
                  )
                  .first,
            )
            .decoration
        as BoxDecoration;

void main() {
  group('MmBannerTone', () {
    test('maps each tone to its colours and icon', () {
      const colors = MmColorModes.light;
      expect(MmBannerTone.info.containerOf(colors), colors.creditContainer);
      expect(MmBannerTone.success.containerOf(colors), colors.paidContainer);
      expect(MmBannerTone.warning.containerOf(colors), colors.dueSoonContainer);
      expect(MmBannerTone.error.containerOf(colors), colors.overdueContainer);
      expect(MmBannerTone.info.onContainerOf(colors), colors.onCreditContainer);
      expect(
        MmBannerTone.success.onContainerOf(colors),
        colors.onPaidContainer,
      );
      expect(
        MmBannerTone.warning.onContainerOf(colors),
        colors.onDueSoonContainer,
      );
      expect(
        MmBannerTone.error.onContainerOf(colors),
        colors.onOverdueContainer,
      );
      expect(MmBannerTone.info.colorOf(colors), colors.credit);
      expect(MmBannerTone.success.colorOf(colors), colors.paid);
      expect(MmBannerTone.warning.colorOf(colors), colors.dueSoon);
      expect(MmBannerTone.error.colorOf(colors), colors.overdue);
      expect(MmBannerTone.info.icon, MmIcons.info);
      expect(MmBannerTone.success.icon, MmIcons.success);
      expect(MmBannerTone.warning.icon, MmIcons.warning);
      expect(MmBannerTone.error.icon, MmIcons.error);
      expect(MmBannerTone.values.where((tone) => tone.urgent), [
        MmBannerTone.warning,
        MmBannerTone.error,
      ]);
    });
  });

  group('MmBanner', () {
    testEveryVariant('each tone has its container, ink and icon', (
      tester,
      variant,
    ) async {
      final colors = colorsOf(variant);
      for (final tone in MmBannerTone.values) {
        await pumpThemed(
          tester,
          MmBanner(tone: tone, title: _title, message: _message),
          variant: variant,
        );
        final decoration = _decoration(tester);
        expect(decoration.color, tone.containerOf(colors), reason: tone.name);
        expect(
          decoration.borderRadius,
          const BorderRadius.all(Radius.circular(MmRadius.md)),
        );
        expect(styleOf(tester, _title).color, tone.onContainerOf(colors));
        expect(styleOf(tester, _message).color, tone.onContainerOf(colors));
        expect(iconColorOf(tester, tone.icon), tone.onContainerOf(colors));
      }
    });

    testWidgets('sets the title and message in the theme styles', (
      tester,
    ) async {
      await pumpThemed(
        tester,
        const MmBanner(
          tone: MmBannerTone.info,
          title: _title,
          message: _message,
        ),
      );
      final text = MmVariant.light.theme.textTheme;
      expect(styleOf(tester, _title).fontSize, text.titleMedium!.fontSize);
      expect(styleOf(tester, _title).fontWeight, text.titleMedium!.fontWeight);
      expect(styleOf(tester, _message).fontSize, text.bodyLarge!.fontSize);
      // The title comes first.
      expect(
        tester.getRect(find.text(_title)).top,
        lessThan(tester.getRect(find.text(_message)).top),
      );
    });

    testWidgets('a custom icon replaces the tone icon', (tester) async {
      await pumpThemed(
        tester,
        const MmBanner(
          tone: MmBannerTone.info,
          icon: MmIcons.reminder,
          message: _message,
        ),
      );
      expect(find.byIcon(MmIcons.reminder), findsOneWidget);
      expect(find.byIcon(MmIcons.info), findsNothing);
      expect(find.text(_title), findsNothing);
    });

    testWidgets('the icon is centred on the first line, at any size', (
      tester,
    ) async {
      for (final variant in [MmVariant.light, MmVariant.urdu]) {
        for (final title in [null, _title]) {
          await pumpThemed(
            tester,
            MmBanner(
              tone: MmBannerTone.warning,
              title: title,
              message: '$_message $_message',
            ),
            variant: variant,
          );
          final first = tester.getRect(
            find.text(title ?? '$_message $_message'),
          );
          final style = title == null
              ? variant.theme.textTheme.bodyLarge!
              : variant.theme.textTheme.titleMedium!;
          final line = style.fontSize! * style.height!;
          expect(
            tester.getCenter(find.byIcon(MmIcons.warning)).dy,
            moreOrLessEquals(first.top + line / 2, epsilon: 0.5),
          );
        }
      }
    });

    testWidgets('reads as one node; warnings and errors as live regions', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      for (final tone in MmBannerTone.values) {
        await pumpThemed(
          tester,
          MmBanner(tone: tone, title: _title, message: _message),
        );
        expect(
          tester.getSemantics(find.text(_message)),
          isSemantics(label: '$_title\n$_message', isLiveRegion: tone.urgent),
          reason: tone.name,
        );
      }
      handle.dispose();
    });

    testWidgets('its action calls onAction on tap and from the keyboard', (
      tester,
    ) async {
      var actions = 0;
      await pumpThemed(
        tester,
        MmBanner(
          tone: MmBannerTone.warning,
          message: _message,
          actionLabel: _action,
          onAction: () => actions++,
        ),
      );
      expect(find.byType(TextButton), findsOneWidget);
      await tester.tap(find.text(_action));
      expect(actions, 1);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      expect(focusedAt(tester, _action), isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(actions, 2);
      expect(
        tester.getSemantics(find.byType(TextButton)),
        isSemantics(label: _action, isButton: true, isEnabled: true),
      );
      // Under the message, at the end edge.
      final banner = tester.getRect(find.byType(MmBanner));
      final button = tester.getRect(find.byType(TextButton));
      expect(button.top, greaterThan(tester.getRect(find.text(_message)).top));
      expect(button.right, lessThanOrEqualTo(banner.right));
      expect(button.right, greaterThan(banner.right - MmSpace.s6));
    });

    testWidgets('without onAction its action is disabled', (tester) async {
      await pumpThemed(
        tester,
        const MmBanner(
          tone: MmBannerTone.error,
          message: _message,
          actionLabel: _action,
        ),
      );
      expect(
        tester.getSemantics(find.byType(TextButton)),
        isSemantics(label: _action, isButton: true, isEnabled: false),
      );
    });

    test('an action without a label is a programming error', () {
      expect(
        () => MmBanner(
          tone: MmBannerTone.info,
          message: _message,
          onAction: tapped,
        ),
        throwsAssertionError,
      );
    });

    testEveryVariant('the dismiss button says "Dismiss" once', (
      tester,
      variant,
    ) async {
      final handle = tester.ensureSemantics();
      var dismissals = 0;
      await pumpThemed(
        tester,
        MmBanner(
          tone: MmBannerTone.success,
          message: _message,
          onDismiss: () => dismissals++,
        ),
        variant: variant,
      );
      final dismiss = MmLocalizations.forLocale(variant.locale).dismiss;
      final button = find.byType(IconButton);
      expect(
        tester.getSemantics(button),
        isSemantics(label: dismiss, tooltip: '', isButton: true),
      );
      expect(tester.widget<Tooltip>(find.byType(Tooltip)).message, dismiss);
      expect(
        iconColorOf(tester, MmIcons.close),
        MmBannerTone.success.onContainerOf(colorsOf(variant)),
      );
      // The glyph grows with the text, as the banner's icon does; the button
      // is the glyph in its padding, and at least a touch target.
      final glyph = variant == MmVariant.largeText
          ? MmSize.iconLg * MmIconLabel.maxIconScale
          : MmSize.iconLg;
      expect(tester.getSize(find.byIcon(MmIcons.close)), Size.square(glyph));
      expect(
        tester.getSize(button),
        Size.square(math.max(MmSize.minTarget, glyph + 2 * MmSpace.s2)),
      );
      // Centred on the first line of the message.
      final message = tester.getRect(find.text(_message));
      final line = styleOf(tester, _message);
      expect(
        tester.getCenter(button).dy,
        moreOrLessEquals(
          message.top + (variant.textScale * line.fontSize! * line.height!) / 2,
          epsilon: 1,
        ),
      );
      await tester.tap(button);
      expect(dismissals, 1);
      handle.dispose();
    });

    testWidgets('dismisses from the keyboard', (tester) async {
      var dismissals = 0;
      await pumpThemed(
        tester,
        MmBanner(
          tone: MmBannerTone.warning,
          message: _message,
          actionLabel: _action,
          onAction: tapped,
          onDismiss: () => dismissals++,
        ),
      );
      // In reading order: the dismiss button on the first line, then the
      // action under the message.
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      expect(
        Focus.of(tester.element(find.byIcon(MmIcons.close))).hasPrimaryFocus,
        isTrue,
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(dismissals, 1);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      expect(focusedAt(tester, _action), isTrue);
    });

    testWidgets('without onDismiss there is no dismiss button', (tester) async {
      await pumpThemed(
        tester,
        const MmBanner(tone: MmBannerTone.info, message: _message),
      );
      expect(find.byType(IconButton), findsNothing);
    });

    testWidgets('wraps at 200% text on a 320 dp phone without overflow', (
      tester,
    ) async {
      const long =
          'Ali Raza’s lease for Flat 3, Gulberg III, Lahore ends in 14 '
          'days and Rs 1,25,000 is still due.';
      const subject = MmBanner(
        tone: MmBannerTone.warning,
        title: 'Lease ending for Ali Raza',
        message: long,
        actionLabel: 'Renew the lease now',
        onAction: tapped,
        onDismiss: tapped,
      );
      // In English and in Urdu, on a scrolling page as a screen holds it.
      await expectFitsNarrowLargeText(
        tester,
        Builder(
          builder: (context) {
            final say = sayIn(context);
            return MmBanner(
              tone: MmBannerTone.warning,
              title: say(subject.title!, 'علی رضا کا معاہدہ ختم ہو رہا ہے'),
              message: say(
                long,
                'فلیٹ 3، گلبرگ III، لاہور میں علی رضا کا معاہدہ 14 دن میں ختم '
                'ہو گا اور 1,25,000 روپے ابھی واجب الادا ہیں۔',
              ),
              actionLabel: say(subject.actionLabel!, 'ابھی معاہدہ تجدید کریں'),
              onAction: tapped,
              onDismiss: tapped,
            );
          },
        ),
      );
      await pumpLargeNarrow(tester, subject, height: 1600);
      expect(tester.takeException(), isNull);
      for (final text in [long, 'Lease ending for Ali Raza']) {
        final paragraph = tester.renderObject<RenderParagraph>(find.text(text));
        expect(paragraph.didExceedMaxLines, isFalse);
      }
      // The dismiss button stays on the first line, at the end.
      final banner = tester.getRect(find.byType(MmBanner));
      final dismiss = tester.getRect(find.byType(IconButton));
      expect(dismiss.right, lessThanOrEqualTo(banner.right));
      expect(dismiss.top, lessThan(tester.getRect(find.text(long)).top));
    });

    testWidgets('the icon grows with the text, up to 150%', (tester) async {
      for (final (variant, size) in [
        (MmVariant.light, MmSize.iconLg),
        (MmVariant.largeText, MmSize.iconLg * MmIconLabel.maxIconScale),
      ]) {
        await pumpThemed(
          tester,
          const MmBanner(tone: MmBannerTone.info, message: _message),
          variant: variant,
        );
        expect(
          tester.getSize(find.byIcon(MmIcons.info)),
          Size.square(size),
          reason: variant.name,
        );
      }
    });

    testEveryVariant('the action ends in the same place with or without a '
        'dismiss button', (tester, variant) async {
      double actionEnd({required bool dismissible}) {
        final banner = tester.getRect(
          find.byType(MmBanner).at(dismissible ? 1 : 0),
        );
        final action = tester.getRect(
          find.descendant(
            of: find.byType(MmBanner).at(dismissible ? 1 : 0),
            matching: find.byType(TextButton),
          ),
        );
        // The distance from the banner's end edge.
        return variant == MmVariant.urdu
            ? action.left - banner.left
            : banner.right - action.right;
      }

      await pumpThemed(
        tester,
        const Column(
          spacing: MmSpace.s3,
          children: [
            MmBanner(
              tone: MmBannerTone.error,
              message: _message,
              actionLabel: _action,
              onAction: tapped,
            ),
            MmBanner(
              tone: MmBannerTone.warning,
              message: _message,
              actionLabel: _action,
              onAction: tapped,
              onDismiss: tapped,
            ),
          ],
        ),
        variant: variant,
        size: const Size(360, 1000),
      );
      expect(actionEnd(dismissible: true), actionEnd(dismissible: false));
      expect(actionEnd(dismissible: false), MmSpace.s2);
    });

    testWidgets('sets figures in Urdu text in the Latin face', (tester) async {
      const title = 'عائشہ خان کے 2 ماہ';
      const message = '3 کرایہ داروں سے 1,25,000 روپے واجب الادا ہیں۔';
      await pumpThemed(
        tester,
        const MmBanner(
          tone: MmBannerTone.error,
          title: title,
          message: message,
        ),
        variant: MmVariant.urdu,
      );
      expect(isLatinFace(runStyleIn(tester, message, '1,25,000')), isTrue);
      expect(isLatinFace(runStyleIn(tester, message, 'روپے')), isFalse);
      expect(isLatinFace(runStyleIn(tester, title, '2')), isTrue);
    });

    testWidgets('mirrors for Urdu: icon at the right, dismiss at the left', (
      tester,
    ) async {
      await pumpThemed(
        tester,
        const MmBanner(
          tone: MmBannerTone.error,
          message: '3 کرایہ داروں سے 1,25,000 روپے واجب الادا ہیں۔',
          onDismiss: tapped,
        ),
        variant: MmVariant.urdu,
      );
      final banner = tester.getRect(find.byType(MmBanner));
      expect(
        tester.getCenter(find.byIcon(MmIcons.error)).dx,
        greaterThan(banner.center.dx),
      );
      expect(
        tester.getCenter(find.byType(IconButton)).dx,
        lessThan(banner.center.dx),
      );
    });
  });
}
