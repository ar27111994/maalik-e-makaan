import 'package:flutter/material.dart';
import 'package:mm_ui/mm_ui.dart';

import 'package:mm_ui_gallery/src/copy.dart';
import 'package:mm_ui_gallery/src/settings.dart';
import 'package:mm_ui_gallery/src/shell.dart';
import 'package:mm_ui_gallery/src/specimen.dart';

enum _Period { monthly, quarterly, yearly }

enum _Method { cash, bank, card }

/// Buttons, icon buttons, the floating action button and segmented
/// controls.
class ActionsPage extends StatefulWidget {
  const new({super.key});

  @override
  State<ActionsPage> createState() => _ActionsPageState();
}

class _ActionsPageState extends State<ActionsPage> {
  _Period _period = _Period.monthly;
  _Method _method = _Method.bank;
  var _muted = false;

  @override
  Widget build(BuildContext context) {
    final record = context.tr('Record payment', 'ادائیگی درج کریں');
    final remind = context.tr('Send reminder', 'یاد دہانی بھیجیں');
    final ledger = context.tr('View ledger', 'کھاتہ دیکھیں');
    final remove = context.tr('Remove tenant', 'کرایہ دار ہٹائیں');
    final addTenant = context.tr('Add tenant', 'کرایہ دار شامل کریں');
    return FamilyPage(
      family: GalleryFamily.actions,
      floatingActionButton: MmFab(
        label: addTenant,
        icon: MmIcons.add,
        onPressed: () => showPressed(context, addTenant),
      ),
      body: SpecimenList(
        children: [
          Specimen(
            title: context.tr('Buttons', 'بٹن'),
            component: 'MmButton',
            note: context.tr(
              'One filled button per screen for the main action; the others '
                  'outlined or text.',
              'ہر اسکرین پر مرکزی کام کے لیے ایک بھرا ہوا بٹن۔ دوسرے بٹن صرف '
                  'کنارے یا الفاظ والے۔',
            ),
            children: [
              StateLabel(
                label: context.tr('Variants', 'قسمیں'),
                child: SpecimenWrap(
                  children: [
                    MmButton(
                      label: record,
                      icon: MmIcons.payment,
                      onPressed: () => showPressed(context, record),
                    ),
                    MmButton(
                      label: remind,
                      icon: MmIcons.reminder,
                      variant: MmButtonVariant.secondary,
                      onPressed: () => showPressed(context, remind),
                    ),
                    MmButton(
                      label: ledger,
                      variant: MmButtonVariant.tertiary,
                      onPressed: () => showPressed(context, ledger),
                    ),
                    MmButton(
                      label: remove,
                      icon: MmIcons.delete,
                      variant: MmButtonVariant.destructive,
                      onPressed: () => showPressed(context, remove),
                    ),
                  ],
                ),
              ),
              StateLabel(
                label: context.tr('Disabled', 'بند'),
                child: SpecimenWrap(
                  children: [
                    MmButton(label: record, onPressed: null),
                    MmButton(
                      label: remind,
                      variant: MmButtonVariant.secondary,
                      onPressed: null,
                    ),
                    MmButton(
                      label: ledger,
                      variant: MmButtonVariant.tertiary,
                      onPressed: null,
                    ),
                  ],
                ),
              ),
              StateLabel(
                label: context.tr('Busy', 'جاری'),
                child: SpecimenWrap(
                  children: [
                    MmButton(label: record, busy: true, onPressed: () {}),
                    MmButton(
                      label: remind,
                      variant: MmButtonVariant.secondary,
                      busy: true,
                      onPressed: () {},
                    ),
                  ],
                ),
              ),
              StateLabel(
                label: context.tr('Full width', 'پوری چوڑائی'),
                child: MmButton(
                  label: record,
                  icon: MmIcons.payment,
                  expand: true,
                  onPressed: () => showPressed(context, record),
                ),
              ),
              StateLabel(
                label: context.tr(
                  'A link, lined up with the words above it',
                  'لنک، اوپر کے الفاظ کی سیدھ میں',
                ),
                child: MmCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.tr(
                          "Ayesha Khan's rent is 12 days late.",
                          'عائشہ خان کا کرایہ 12 دن سے لیٹ ہے۔',
                        ),
                      ),
                      MmButton(
                        label: context.tr(
                          "Open Ayesha Khan's tenancy",
                          'عائشہ خان کی کرایہ داری کھولیں',
                        ),
                        variant: MmButtonVariant.link,
                        onPressed: () => showPressed(
                          context,
                          context.tr('Open tenancy', 'کرایہ داری کھولیں'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          Specimen(
            title: context.tr('Icon buttons', 'آئیکن بٹن'),
            component: 'MmIconButton',
            note: context.tr(
              'Every icon button has a tooltip that is also its label.',
              'ہر آئیکن بٹن کا ٹول ٹپ ہی اس کا نام بھی ہے۔',
            ),
            children: [
              StateLabel(
                label: context.tr(
                  'Standard, filled, tonal, outlined',
                  'سادہ، بھرا ہوا، ہلکا رنگ، خاکہ',
                ),
                child: SpecimenWrap(
                  children: [
                    _icon(
                      context,
                      MmIcons.edit,
                      'Edit tenant',
                      'کرایہ دار ایڈٹ کریں',
                    ),
                    _icon(
                      context,
                      MmIcons.add,
                      'Add payment',
                      'ادائیگی شامل کریں',
                      variant: MmIconButtonVariant.filled,
                    ),
                    _icon(
                      context,
                      MmIcons.share,
                      'Share receipt',
                      'رسید بھیجیں',
                      variant: MmIconButtonVariant.tonal,
                    ),
                    _icon(
                      context,
                      MmIcons.print,
                      'Print receipt',
                      'رسید پرنٹ کریں',
                      variant: MmIconButtonVariant.outlined,
                    ),
                  ],
                ),
              ),
              StateLabel(
                label: context.tr('Toggle and disabled', 'ٹوگل اور بند'),
                child: SpecimenWrap(
                  children: [
                    MmIconButton(
                      icon: MmIcons.notifications,
                      selectedIcon: MmIcons.notificationsOff,
                      tooltip: context.tr(
                        'Mute reminders',
                        'یاد دہانیاں بند کریں',
                      ),
                      selected: _muted,
                      variant: MmIconButtonVariant.tonal,
                      onPressed: () => setState(() => _muted = !_muted),
                    ),
                    MmIconButton(
                      icon: MmIcons.delete,
                      tooltip: context.tr(
                        'Delete payment',
                        'ادائیگی ڈیلیٹ کریں',
                      ),
                      onPressed: null,
                    ),
                    MmIconButton(
                      icon: MmIcons.add,
                      tooltip: context.tr('Add payment', 'ادائیگی شامل کریں'),
                      variant: MmIconButtonVariant.filled,
                      onPressed: null,
                    ),
                  ],
                ),
              ),
            ],
          ),
          Specimen(
            title: context.tr('Floating action button', 'تیرتا ہوا بٹن'),
            component: 'MmFab',
            note: context.tr(
              'The one action a screen exists for, in thumb reach. This '
                  'page has one at the bottom.',
              'وہ ایک کام جس کے لیے اسکرین بنی ہے، انگوٹھے کی پہنچ میں۔ اس '
                  'صفحے کے نیچے ایک موجود ہے۔',
            ),
            children: [
              SpecimenWrap(
                children: [
                  MmFab(
                    label: addTenant,
                    icon: MmIcons.add,
                    extended: false,
                    heroTag: null,
                    onPressed: () => showPressed(context, addTenant),
                  ),
                  MmFab(
                    label: addTenant,
                    icon: MmIcons.add,
                    heroTag: null,
                    onPressed: null,
                  ),
                ],
              ),
            ],
          ),
          Specimen(
            title: context.tr('Segmented controls', 'حصوں والے بٹن'),
            component: 'MmSegmentedControl',
            note: context.tr(
              'Two to five options, one always chosen.',
              'دو سے پانچ آپشن، ایک ہمیشہ چنا ہوا۔',
            ),
            children: [
              StateLabel(
                label: context.tr('Report period', 'رپورٹ کی مدت'),
                child: MmSegmentedControl<_Period>(
                  semanticLabel: context.tr('Report period', 'رپورٹ کی مدت'),
                  segments: [
                    MmSegment(
                      value: _Period.monthly,
                      label: context.tr('Monthly', 'ماہانہ'),
                    ),
                    MmSegment(
                      value: _Period.quarterly,
                      label: context.tr('Quarterly', 'سہ ماہی'),
                    ),
                    MmSegment(
                      value: _Period.yearly,
                      label: context.tr('Yearly', 'سالانہ'),
                    ),
                  ],
                  selected: _period,
                  onChanged: (value) => setState(() => _period = value),
                ),
              ),
              StateLabel(
                label: context.tr(
                  'Payment method, with icons, full width',
                  'ادائیگی کا طریقہ، آئیکن کے ساتھ، پوری چوڑائی',
                ),
                child: MmSegmentedControl<_Method>(
                  expand: true,
                  semanticLabel: context.tr(
                    'Payment method',
                    'ادائیگی کا طریقہ',
                  ),
                  segments: [
                    MmSegment(
                      value: _Method.cash,
                      label: context.tr('Cash', 'نقد'),
                      icon: MmIcons.cash,
                    ),
                    MmSegment(
                      value: _Method.bank,
                      label: context.tr('Bank', 'بینک'),
                      icon: MmIcons.bank,
                    ),
                    MmSegment(
                      value: _Method.card,
                      label: context.tr('Card', 'کارڈ'),
                      icon: MmIcons.card,
                    ),
                  ],
                  selected: _method,
                  onChanged: (value) => setState(() => _method = value),
                ),
              ),
              StateLabel(
                label: context.tr('Disabled', 'بند'),
                child: MmSegmentedControl<_Period>(
                  semanticLabel: context.tr('Report period', 'رپورٹ کی مدت'),
                  segments: [
                    MmSegment(
                      value: _Period.monthly,
                      label: context.tr('Monthly', 'ماہانہ'),
                    ),
                    MmSegment(
                      value: _Period.yearly,
                      label: context.tr('Yearly', 'سالانہ'),
                    ),
                  ],
                  selected: _Period.monthly,
                  onChanged: null,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _icon(
    BuildContext context,
    IconData icon,
    String en,
    String ur, {
    MmIconButtonVariant variant = MmIconButtonVariant.standard,
  }) {
    final tooltip = context.tr(en, ur);
    return MmIconButton(
      icon: icon,
      tooltip: tooltip,
      variant: variant,
      onPressed: () => showPressed(context, tooltip),
    );
  }
}
