import 'package:flutter/material.dart';
import 'package:mm_core/mm_core.dart';
import 'package:mm_ui/mm_ui.dart';

import 'package:mm_ui_gallery/src/copy.dart';
import 'package:mm_ui_gallery/src/sample_data.dart';
import 'package:mm_ui_gallery/src/settings.dart';
import 'package:mm_ui_gallery/src/shell.dart';
import 'package:mm_ui_gallery/src/specimen.dart';

/// Cards, list rows, status badges, amounts, stat tiles, avatars, section
/// headers and detail rows.
class DisplayPage extends StatefulWidget {
  const new({super.key});

  @override
  State<DisplayPage> createState() => _DisplayPageState();
}

class _DisplayPageState extends State<DisplayPage> {
  var _selected = 1;

  @override
  Widget build(BuildContext context) {
    final ayesha = tenants[1];
    final text = Theme.of(context).textTheme;
    return FamilyPage(
      family: GalleryFamily.display,
      body: SpecimenList(
        children: [
          Specimen(
            title: context.tr('Status badges', 'حالت کے نشان'),
            component: 'MmStatusBadge',
            note: context.tr(
              'Colour, icon and word together, never colour alone.',
              'رنگ، آئیکن اور لفظ ایک ساتھ، کبھی صرف رنگ نہیں۔',
            ),
            children: [
              SpecimenWrap(
                children: [
                  for (final tenant in tenants)
                    MmStatusBadge(
                      status: tenant.status,
                      label: tenant.statusLabel.of(context),
                    ),
                  MmStatusBadge(
                    status: MmStatus.neutral,
                    label: context.tr('Vacant', 'خالی'),
                    icon: MmIcons.unit,
                  ),
                ],
              ),
            ],
          ),
          Specimen(
            title: context.tr('Amounts', 'رقوم'),
            component: 'MmAmount',
            note: context.tr(
              'Tabular figures in the chosen grouping. Switch lakh and crore '
                  'grouping in the display settings.',
              'منتخب گروپنگ میں یکساں ہندسے۔ لاکھ اور کروڑ کی گروپنگ ڈسپلے '
                  'کی ترتیبات میں بدلیں۔',
            ),
            children: [
              StateLabel(
                label: context.tr('Large, regular, small', 'بڑا، عام، چھوٹا'),
                child: Wrap(
                  spacing: MmSpace.s6,
                  runSpacing: MmSpace.s2,
                  crossAxisAlignment: WrapCrossAlignment.end,
                  children: [
                    const MmAmount(
                      amount: Money.fromRupees(1250000),
                      size: MmAmountSize.large,
                    ),
                    MmAmount(amount: ayesha.rent),
                    MmAmount(
                      amount: Money.parseDecimal('4500.50'),
                      size: MmAmountSize.small,
                    ),
                  ],
                ),
              ),
              StateLabel(
                label: context.tr('Tones', 'رنگ'),
                child: const Wrap(
                  spacing: MmSpace.s6,
                  runSpacing: MmSpace.s2,
                  children: [
                    MmAmount(amount: Money.fromRupees(45000)),
                    MmAmount(
                      amount: Money.fromRupees(90000),
                      tone: MmAmountTone.muted,
                    ),
                    MmAmount(
                      amount: Money.fromRupees(45000),
                      tone: MmAmountTone.paid,
                    ),
                    MmAmount(
                      amount: Money.fromRupees(125000),
                      tone: MmAmountTone.overdue,
                    ),
                  ],
                ),
              ),
              StateLabel(
                label: context.tr(
                  'Negative: a word, or a minus sign',
                  'منفی: لفظ کے ساتھ، یا منفی کا نشان',
                ),
                child: Wrap(
                  spacing: MmSpace.s6,
                  runSpacing: MmSpace.s2,
                  children: [
                    MmAmount(
                      amount: const Money.fromRupees(-15000),
                      creditLabel: context.tr('advance', 'پیشگی'),
                    ),
                    const MmAmount(amount: Money.fromRupees(-5000)),
                  ],
                ),
              ),
            ],
          ),
          Specimen(
            title: context.tr('Stat tiles', 'اعداد کے خانے'),
            component: 'MmStatTile',
            children: [
              MmStatTile(
                label: context.tr('Collected in October', 'اکتوبر میں وصولی'),
                value: const MmAmount(
                  amount: Money.fromRupees(270000),
                  size: MmAmountSize.large,
                ),
                caption: Wrap(
                  children: [
                    Text(context.tr('of ', 'کل ')),
                    const MmAmount(
                      amount: Money.fromRupees(320000),
                      tone: MmAmountTone.muted,
                      size: MmAmountSize.small,
                    ),
                    Text(context.tr(' due', ' واجب میں سے')),
                  ],
                ),
                trend: MmTrend(
                  direction: MmTrendDirection.up,
                  label: context.tr(
                    'Up 12% from September',
                    'ستمبر سے 12% زیادہ',
                  ),
                  favourable: true,
                ),
                onTap: () => showPressed(
                  context,
                  context.tr('Collected in October', 'اکتوبر میں وصولی'),
                ),
              ),
              MmStatTile(
                label: context.tr('Overdue', 'واجب الادا'),
                value: const MmAmount(
                  amount: Money.fromRupees(125000),
                  size: MmAmountSize.large,
                ),
                caption: Text(context.tr('1 tenant', '1 کرایہ دار')),
                trend: MmTrend(
                  direction: MmTrendDirection.up,
                  label: context.tr(
                    'Up from Rs 60,000',
                    '60,000 روپے سے زیادہ',
                  ),
                  favourable: false,
                ),
              ),
              MmStatTile(
                label: context.tr('Units let', 'کرائے پر یونٹس'),
                value: Text(context.tr('11 of 12', '12 میں سے 11')),
                trend: MmTrend(
                  direction: MmTrendDirection.flat,
                  label: context.tr('Same as September', 'ستمبر جتنے'),
                ),
              ),
            ],
          ),
          Specimen(
            title: context.tr('Cards and list rows', 'کارڈ اور فہرست'),
            component: 'MmCard · MmListTile · MmAvatar',
            note: context.tr(
              'A card groups one thing; rows inside it pad themselves. '
                  'Tap a row to select it.',
              'کارڈ ایک چیز کو یکجا کرتا ہے؛ اس کی قطاریں اپنا فاصلہ خود '
                  'رکھتی ہیں۔ منتخب کرنے کے لیے قطار دبائیں۔',
            ),
            children: [
              MmCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    for (final (index, tenant) in tenants.indexed) ...[
                      if (index > 0)
                        const Divider(
                          height: MmSize.hairline,
                          thickness: MmSize.hairline,
                        ),
                      MmListTile(
                        title: tenant.name.of(context),
                        subtitle: tenant.unit.of(context),
                        leading: MmAvatar(name: tenant.name.of(context)),
                        trailing: MmAmount(
                          amount: tenant.rent,
                          textAlign: TextAlign.end,
                        ),
                        selected: index == _selected,
                        onTap: () => setState(() => _selected = index),
                      ),
                    ],
                  ],
                ),
              ),
              StateLabel(
                label: context.tr(
                  'Static row, with a status',
                  'ساکن قطار، حالت کے ساتھ',
                ),
                child: MmCard(
                  padding: EdgeInsets.zero,
                  child: MmListTile(
                    title: context.tr(
                      'Electricity bill, October',
                      'بجلی کا بل، اکتوبر',
                    ),
                    subtitle: context.tr(
                      'LESCO · Consumer no. 0412 3345 6789',
                      'لیسکو · صارف نمبر '
                          '${MmSemantics.leftToRight('0412 3345 6789')}',
                    ),
                    leading: const Icon(MmIcons.electricity),
                    trailing: MmStatusBadge(
                      status: MmStatus.dueSoon,
                      label: context.tr('Due 12 Nov', '12 نومبر تک'),
                    ),
                  ),
                ),
              ),
              StateLabel(
                label: context.tr(
                  'Rows that open something, with a chevron',
                  'کچھ کھولنے والی قطاریں، تیر کے ساتھ',
                ),
                child: MmCard(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      MmListTile(
                        title: context.tr(
                          'Police registration for Ayesha Khan, House 12',
                          'عائشہ خان، مکان 12 کی پولیس رجسٹریشن',
                        ),
                        subtitle: context.tr('Due 14 Nov', '14 نومبر تک'),
                        leading: const Icon(MmIcons.police),
                        chevron: true,
                        onTap: () => showPressed(
                          context,
                          context.tr('Police registration', 'پولیس رجسٹریشن'),
                        ),
                      ),
                      const Divider(
                        height: MmSize.hairline,
                        thickness: MmSize.hairline,
                      ),
                      MmListTile(
                        title: context.tr('PDF receipts', 'PDF رسیدیں'),
                        subtitle: context.tr(
                          'Every receipt of 2026, sent on WhatsApp to the '
                              'tenant who paid it',
                          '2026 کی ہر رسید، ادا کرنے والے کرایہ دار کو '
                              'WhatsApp پر بھیجی گئی',
                        ),
                        subtitleMaxLines: null,
                        // Words from the app, not the landlord's data.
                        userData: false,
                        leading: const Icon(MmIcons.receiptText),
                        chevron: true,
                        onTap: () => showPressed(
                          context,
                          context.tr('PDF receipts', 'PDF رسیدیں'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              StateLabel(
                label: context.tr('A tappable card', 'دبانے والا کارڈ'),
                child: MmCard(
                  semanticLabel: context.tr(
                    'Ayesha Khan, House 12, owes 125000 rupees, overdue 12 '
                        'days',
                    'عائشہ خان، مکان 12، 125000 روپے واجب، 12 دن سے واجب '
                        'الادا',
                  ),
                  onTap: () => showPressed(context, ayesha.name.of(context)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          MmAvatar(name: ayesha.name.of(context), size: 48),
                          const SizedBox(width: MmSpace.s3),
                          Expanded(
                            child: Text(
                              ayesha.name.of(context),
                              style: text.titleMedium,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: MmSpace.s3),
                      MmAmount(amount: ayesha.rent, size: MmAmountSize.large),
                      const SizedBox(height: MmSpace.s2),
                      MmStatusBadge(
                        status: ayesha.status,
                        label: ayesha.statusLabel.of(context),
                      ),
                    ],
                  ),
                ),
              ),
              StateLabel(
                label: context.tr(
                  'Avatars: initials, either script, an icon, sizes',
                  'اوتار: ابتدائی حروف، دونوں رسم الخط، آئیکن، سائز',
                ),
                child: const SpecimenWrap(
                  children: [
                    MmAvatar(name: 'Ali Raza'),
                    MmAvatar(name: 'عائشہ خان'),
                    MmAvatar(name: 'Raza Manzil', icon: MmIcons.property),
                    MmAvatar(name: 'Bilal Ahmed', size: 56),
                    MmAvatar(name: 'Fatima Siddiqui', size: 32),
                  ],
                ),
              ),
            ],
          ),
          Specimen(
            title: context.tr('Section headers', 'حصوں کے عنوان'),
            component: 'MmSectionHeader',
            children: [
              StateLabel(
                label: context.tr(
                  'With a line of context and an action',
                  'وضاحتی سطر اور ایک عمل کے ساتھ',
                ),
                child: MmSectionHeader(
                  title: context.tr('Tenants', 'کرایہ دار'),
                  subtitle: context.tr(
                    '3 overdue this month',
                    'اس ماہ 3 واجب الادا',
                  ),
                  actionLabel: context.tr('See all', 'سب دیکھیں'),
                  onAction: () =>
                      showPressed(context, context.tr('See all', 'سب دیکھیں')),
                ),
              ),
              StateLabel(
                label: context.tr(
                  'A property’s name in English; the action disabled',
                  'انگریزی میں جائیداد کا نام؛ عمل غیر فعال',
                ),
                child: MmSectionHeader(
                  title: 'Gulberg Heights',
                  actionLabel: context.tr('Edit', 'ترمیم'),
                ),
              ),
              StateLabel(
                label: context.tr('Title only', 'صرف عنوان'),
                child: MmSectionHeader(
                  title: context.tr('October dues', 'اکتوبر کے واجبات'),
                ),
              ),
            ],
          ),
          Specimen(
            title: context.tr('Detail rows', 'تفصیل کی قطاریں'),
            component: 'MmDetailRow',
            note: context.tr(
              'A label and its value, as on a raseed.',
              'نام اور اس کی قیمت، جیسے رسید پر۔',
            ),
            children: [
              MmCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    MmDetailRow(
                      label: context.tr('Tenant', 'کرایہ دار'),
                      value: ayesha.name.of(context),
                      trailing: MmStatusBadge(
                        status: ayesha.status,
                        label: ayesha.statusLabel.of(context),
                      ),
                    ),
                    MmDetailRow(
                      label: context.tr('CNIC', 'شناختی کارڈ'),
                      value: ayesha.cnic,
                      action: MmIconButton(
                        icon: MmIcons.copy,
                        tooltip: context.tr(
                          'Copy CNIC',
                          'شناختی کارڈ نمبر کاپی کریں',
                        ),
                        onPressed: () => showPressed(
                          context,
                          context.tr('Copy CNIC', 'شناختی کارڈ نمبر کاپی کریں'),
                        ),
                      ),
                    ),
                    MmDetailRow(
                      label: context.tr('Lease start', 'کرایہ نامے کا آغاز'),
                      value: dateLabel(context, CalendarDate(2026, 7, 1)),
                      userData: false,
                    ),
                    MmDetailRow.amount(
                      label: context.tr('Monthly rent', 'ماہانہ کرایہ'),
                      amount: ayesha.rent,
                    ),
                    MmDetailRow.amount(
                      label: context.tr('Late fee', 'تاخیر کی فیس'),
                      amount: const Money.fromRupees(2500),
                    ),
                    MmDetailRow.amount(
                      label: context.tr('Advance held', 'جمع شدہ پیشگی'),
                      amount: const Money.fromRupees(-10000),
                      creditLabel: context.tr('advance', 'پیشگی'),
                    ),
                    const Divider(),
                    MmDetailRow.amount(
                      label: context.tr('Total due', 'کل واجب'),
                      amount: const Money.fromRupees(117500),
                      emphasized: true,
                    ),
                  ],
                ),
              ),
              StateLabel(
                label: context.tr(
                  "A passage of the landlord's words",
                  'مالک کے اپنے الفاظ کا اقتباس',
                ),
                child: MmCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      MmDetailRow.prose(
                        label: context.tr('Notes', 'نوٹ'),
                        value: context.tr(
                          'Paid in cash before the deadline. Asked for the '
                              'receipt on WhatsApp.',
                          'مقررہ تاریخ سے پہلے نقد ادا کیا۔ رسید WhatsApp پر '
                              'مانگی۔',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
