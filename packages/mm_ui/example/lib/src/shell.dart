import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mm_core/mm_core.dart';
import 'package:mm_ui/mm_ui.dart';

import 'package:mm_ui_gallery/src/copy.dart';
import 'package:mm_ui_gallery/src/pages/actions_page.dart';
import 'package:mm_ui_gallery/src/pages/charts_page.dart';
import 'package:mm_ui_gallery/src/pages/choices_page.dart';
import 'package:mm_ui_gallery/src/pages/display_page.dart';
import 'package:mm_ui_gallery/src/pages/feedback_page.dart';
import 'package:mm_ui_gallery/src/pages/inputs_page.dart';
import 'package:mm_ui_gallery/src/pages/layout_page.dart';
import 'package:mm_ui_gallery/src/pages/records_page.dart';
import 'package:mm_ui_gallery/src/sample_data.dart';
import 'package:mm_ui_gallery/src/settings.dart';

/// The name of [family]'s page in both languages.
Words familyTitle(GalleryFamily family) => switch (family) {
  GalleryFamily.actions => (en: 'Actions', ur: 'ایکشن'),
  GalleryFamily.inputs => (en: 'Inputs', ur: 'لکھنے کے خانے'),
  GalleryFamily.choices => (en: 'Choices', ur: 'انتخاب'),
  GalleryFamily.display => (en: 'Display', ur: 'نمائش'),
  GalleryFamily.records => (en: 'Records', ur: 'ریکارڈ'),
  GalleryFamily.feedback => (en: 'Feedback', ur: 'اطلاعات'),
  GalleryFamily.layout => (en: 'Layout', ur: 'ترتیب'),
  GalleryFamily.charts => (en: 'Charts', ur: 'چارٹ'),
};

IconData _familyIcon(GalleryFamily family) => switch (family) {
  GalleryFamily.actions => MmIcons.send,
  GalleryFamily.inputs => MmIcons.edit,
  GalleryFamily.choices => MmIcons.adjust,
  GalleryFamily.display => MmIcons.tenants,
  GalleryFamily.records => MmIcons.receipt,
  GalleryFamily.feedback => MmIcons.notifications,
  GalleryFamily.layout => MmIcons.home,
  GalleryFamily.charts => MmIcons.reports,
};

/// The components [family] shows, for the list of families.
Words familyComponents(GalleryFamily family) => switch (family) {
  GalleryFamily.actions => (
    en: 'Buttons, icon buttons, floating button, segments',
    ur: 'بٹن، آئیکن بٹن، تیرتا بٹن، حصوں والے بٹن',
  ),
  GalleryFamily.inputs => (
    en: 'Text, password, money, CNIC and phone fields',
    ur: 'الفاظ، پاس ورڈ، رقم، شناختی کارڈ اور فون کے خانے',
  ),
  GalleryFamily.choices => (
    en: 'Dates, selects, switches, checkboxes, search, filters',
    ur: 'تاریخ، انتخاب، سوئچ، چیک باکس، تلاش، فلٹر',
  ),
  GalleryFamily.display => (
    en: 'Badges, amounts, stat tiles, cards, rows, avatars',
    ur: 'نشان، رقمیں، نمبر، کارڈ، قطاریں، اوتار',
  ),
  GalleryFamily.records => (
    en: 'Nameplate, receipt, meters, score, timeline',
    ur: 'نام کی تختی، رسید، پیمانے، اسکور، ٹائم لائن',
  ),
  GalleryFamily.feedback => (
    en: 'Banners, snack bars, dialogs, sheets, empty and loading',
    ur: 'اعلانات، پیغامات، ڈائیلاگ، شیٹ، خالی اور لوڈنگ',
  ),
  GalleryFamily.layout => (
    en: 'Frame, page, list and detail, grid, forms, tabs',
    ur: 'ڈھانچہ، صفحہ، فہرست اور تفصیل، گرڈ، فارم، ٹیبز',
  ),
  GalleryFamily.charts => (
    en: 'Bar charts, proportion bars, sparklines, tables',
    ur: 'بار چارٹ، حصوں والی بار، رجحان، ٹیبل',
  ),
};

/// How many families a phone's bottom bar holds before "More": Material's
/// bottom bar takes three to five destinations, and labels break inside
/// words beyond that.
const _barFamilies = 4;

/// The gallery's frame, an [MmAdaptiveScaffold]: on tablets and desktops a
/// rail with every component family; on phones a bottom bar with the first
/// four families and "More", which lists the rest.
class GalleryShell extends StatefulWidget {
  const new({this.initialFamily = GalleryFamily.actions, super.key});

  final GalleryFamily initialFamily;

  @override
  State<GalleryShell> createState() => _GalleryShellState();
}

class _GalleryShellState extends State<GalleryShell> {
  late GalleryFamily _family = widget.initialFamily;

  /// Whether a phone shows the list of the families under "More".
  var _more = false;

  void _open(GalleryFamily family) => setState(() {
    _family = family;
    _more = false;
  });

  @override
  Widget build(BuildContext context) {
    final compact = MmWindowSize.of(context) == MmWindowSize.compact;
    final barFamilies = compact
        ? GalleryFamily.values.take(_barFamilies)
        : GalleryFamily.values;
    final underMore = compact && _family.index >= _barFamilies;
    final locale = Localizations.localeOf(context);
    return MmAdaptiveScaffold(
      destinations: [
        for (final family in barFamilies)
          MmDestination(
            icon: _familyIcon(family),
            label: familyTitle(family).of(context),
            badgeCount: family == GalleryFamily.feedback ? 3 : null,
          ),
        if (compact)
          MmDestination(
            icon: MmIcons.more,
            label: context.tr('More', 'مزید'),
            badgeCount: 3,
          ),
      ],
      selectedIndex: compact && (_more || underMore)
          ? _barFamilies
          : _family.index,
      onDestinationSelected: (index) => index < barFamilies.length
          ? _open(GalleryFamily.values[index])
          : setState(() => _more = true),
      // A new language starts the page afresh, so fields show their sample
      // text in that language.
      body: compact && _more
          ? KeyedSubtree(
              key: ValueKey(('more', locale)),
              child: MorePage(onOpen: _open),
            )
          : KeyedSubtree(
              key: ValueKey((_family, locale)),
              child: GalleryBack(
                onBack: underMore ? () => setState(() => _more = true) : null,
                child: switch (_family) {
                  GalleryFamily.actions => const ActionsPage(),
                  GalleryFamily.inputs => const InputsPage(),
                  GalleryFamily.choices => const ChoicesPage(),
                  GalleryFamily.display => const DisplayPage(),
                  GalleryFamily.records => const RecordsPage(),
                  GalleryFamily.feedback => const FeedbackPage(),
                  GalleryFamily.layout => const LayoutPage(),
                  GalleryFamily.charts => const ChartsPage(),
                },
              ),
            ),
    );
  }
}

/// Where a family page opened from "More" goes back to.
class GalleryBack extends InheritedWidget {
  const new({required this.onBack, required super.child, super.key});

  /// Returns to the list of families under "More", or null when the page
  /// has its own destination.
  final VoidCallback? onBack;

  static VoidCallback? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<GalleryBack>()?.onBack;

  @override
  bool updateShouldNotify(GalleryBack oldWidget) =>
      (onBack == null) != (oldWidget.onBack == null);
}

/// The families a phone's bottom bar has no room for.
class MorePage extends StatelessWidget {
  const new({required this.onOpen, super.key});

  final ValueChanged<GalleryFamily> onOpen;

  @override
  Widget build(BuildContext context) => MmPage(
    title: context.tr('More components', 'مزید اجزا'),
    actions: const [SettingsButton()],
    body: MmCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (final family in GalleryFamily.values.skip(_barFamilies)) ...[
            if (family.index > _barFamilies)
              const Divider(
                height: MmSize.hairline,
                thickness: MmSize.hairline,
              ),
            MmListTile(
              title: familyTitle(family).of(context),
              subtitle: familyComponents(family).of(context),
              leading: Icon(_familyIcon(family)),
              trailing: const Icon(MmIcons.chevronEnd),
              onTap: () => onOpen(family),
            ),
          ],
        ],
      ),
    ),
  );
}

/// A family's page: an [MmPage] titled with the family's name, with the
/// display settings in its app bar, and a way back to "More" when it was
/// opened from there.
class FamilyPage extends StatelessWidget {
  const new({
    required this.family,
    required this.body,
    this.floatingActionButton,
    super.key,
  });

  final GalleryFamily family;
  final Widget body;
  final Widget? floatingActionButton;

  @override
  Widget build(BuildContext context) {
    final back = GalleryBack.of(context);
    return MmPage(
      title: familyTitle(family).of(context),
      leading: back == null
          ? null
          : MmIconButton(
              icon: MmIcons.back,
              tooltip: context.tr('More components', 'مزید اجزا'),
              onPressed: back,
            ),
      actions: const [SettingsButton()],
      floatingActionButton: floatingActionButton,
      // MmPage leaves no room for its floating button: without this the
      // end of the page stays under it when scrolled to the bottom.
      body: floatingActionButton == null
          ? body
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                body,
                const SizedBox(height: MmSize.fab + MmSpace.s4),
              ],
            ),
    );
  }
}

/// The app bar button that opens the display settings.
class SettingsButton extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) => MmIconButton(
    icon: MmIcons.settings,
    tooltip: context.tr('Display settings', 'ڈسپلے کی سیٹنگز'),
    onPressed: () => unawaited(
      showMmSheet<void>(
        context,
        title: context.tr('Display settings', 'ڈسپلے کی سیٹنگز'),
        builder: (context) => const SettingsPanel(),
      ),
    ),
  );
}

/// The gallery's display settings: mode, contrast, language, text size and
/// digit grouping. Every change applies at once, to the whole gallery.
class SettingsPanel extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    final notifier = GallerySettingsScope.of(context);
    final settings = notifier.value;
    void update(GallerySettings next) => notifier.value = next;
    final text = Theme.of(context).textTheme;
    Widget heading(String label) => Padding(
      padding: const EdgeInsetsDirectional.only(bottom: MmSpace.s2),
      child: Text(label, style: text.titleSmall),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        heading(context.tr('Mode', 'موڈ')),
        MmSegmentedControl<Brightness>(
          expand: true,
          segments: [
            MmSegment(
              value: Brightness.light,
              label: context.tr('Light', 'لائٹ'),
            ),
            MmSegment(
              value: Brightness.dark,
              label: context.tr('Dark', 'ڈارک'),
            ),
          ],
          selected: settings.brightness,
          onChanged: (value) => update(settings.copyWith(brightness: value)),
        ),
        const SizedBox(height: MmSpace.s3),
        MmSwitchTile(
          label: context.tr('High contrast', 'زیادہ کنٹراسٹ'),
          description: context.tr(
            'Darker ink and stronger borders: text at 7:1 or better.',
            'گہری سیاہی اور واضح کنارے: الفاظ کا کنٹراسٹ کم از کم 7:1۔',
          ),
          value: settings.highContrast,
          onChanged: (value) => update(settings.copyWith(highContrast: value)),
        ),
        const SizedBox(height: MmSpace.s4),
        heading(context.tr('Language', 'زبان')),
        MmSegmentedControl<String>(
          expand: true,
          segments: const [
            MmSegment(value: 'en', label: 'English'),
            MmSegment(value: 'ur', label: 'اردو'),
          ],
          selected: settings.locale.languageCode,
          // The page behind starts afresh in the new language; close the
          // sheet so it does too.
          onChanged: (value) {
            update(settings.copyWith(locale: Locale(value)));
            Navigator.of(context).pop();
          },
        ),
        const SizedBox(height: MmSpace.s4),
        heading(context.tr('Text size', 'الفاظ کا سائز')),
        MmSegmentedControl<double>(
          expand: true,
          segments: [
            for (final scale in galleryTextScales)
              MmSegment(value: scale, label: '${(scale * 100).round()}%'),
          ],
          selected: settings.textScale,
          onChanged: (value) => update(settings.copyWith(textScale: value)),
        ),
        const SizedBox(height: MmSpace.s3),
        MmSwitchTile(
          label: context.tr(
            'Lakh and crore grouping',
            'لاکھ اور کروڑ کی گروپنگ',
          ),
          description: context.tr(
            'Rs 1,25,000 instead of Rs 125,000.',
            '125,000 روپے کے بجائے 1,25,000 روپے۔',
          ),
          value: settings.grouping == DigitGrouping.southAsian,
          onChanged: (value) => update(
            settings.copyWith(
              grouping: value
                  ? DigitGrouping.southAsian
                  : DigitGrouping.western,
            ),
          ),
        ),
      ],
    );
  }
}
