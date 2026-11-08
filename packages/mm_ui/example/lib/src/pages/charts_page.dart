import 'package:flutter/material.dart';
import 'package:mm_core/mm_core.dart';
import 'package:mm_ui/mm_ui.dart';

import 'package:mm_ui_gallery/src/copy.dart';
import 'package:mm_ui_gallery/src/sample_data.dart';
import 'package:mm_ui_gallery/src/settings.dart';
import 'package:mm_ui_gallery/src/shell.dart';
import 'package:mm_ui_gallery/src/specimen.dart';

/// Rent collected and due, June to November 2026, in rupees.
const _collected = [285000, 310000, 298000, 320000, 270000, 45000];
const _due = [320000, 320000, 320000, 320000, 320000, 320000];

/// Bar charts, proportion bars, sparklines and data tables.
class ChartsPage extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    final months = [for (var month = 6; month <= 11; month++) month];
    final collectedGroups = [
      for (final (index, month) in months.indexed)
        MmBarGroup(
          label: monthName(context, month),
          values: [
            Money.fromRupees(_collected[index]),
            Money.fromRupees(_due[index]),
          ],
        ),
    ];
    const net = [
      (en: 'Flat 3', ur: 'فلیٹ 3', value: 38000),
      (en: 'Flat 5B', ur: 'فلیٹ 5 بی', value: 31500),
      (en: 'Shop 7', ur: 'دکان 7', value: -12000),
      (en: 'House 12', ur: 'مکان 12', value: 104000),
    ];
    return FamilyPage(
      family: GalleryFamily.charts,
      body: SpecimenList(
        children: [
          Specimen(
            title: context.tr('Bar chart', 'بار چارٹ'),
            component: 'MmBarChart',
            note: context.tr(
              'Tap or use the arrow keys to read a month; switch to a table '
                  'from the chart’s button.',
              'کسی مہینے کو پڑھنے کے لیے دبائیں یا تیر والی کیز استعمال کریں؛ '
                  'چارٹ کے بٹن سے جدول دیکھیں۔',
            ),
            children: [
              MmBarChart(
                title: context.tr('Rent, last 6 months', 'کرایہ، پچھلے 6 ماہ'),
                groupLabel: context.tr('Month', 'مہینہ'),
                series: [
                  MmBarSeries(label: context.tr('Collected', 'وصول')),
                  MmBarSeries(label: context.tr('Due', 'واجب')),
                ],
                groups: collectedGroups,
                semanticSummary: context.tr(
                  'Rent collected against rent due each month from June to '
                      'November 2026. October collected 270000 of 320000 '
                      'rupees; November so far 45000.',
                  'جون سے نومبر 2026 تک ہر ماہ واجب کرائے کے مقابلے میں '
                      'وصولی۔ اکتوبر میں 320000 میں سے 270000 روپے؛ نومبر میں '
                      'اب تک 45000۔',
                ),
              ),
              StateLabel(
                label: context.tr(
                  'One series, with a loss below zero',
                  'ایک سلسلہ، صفر سے نیچے نقصان کے ساتھ',
                ),
                child: MmBarChart(
                  title: context.tr(
                    'Net income by unit, October',
                    'یونٹ کے لحاظ سے خالص آمدن، اکتوبر',
                  ),
                  groupLabel: context.tr('Unit', 'یونٹ'),
                  groupKind: MmBarGroupKind.names,
                  series: [
                    MmBarSeries(label: context.tr('Net income', 'خالص آمدن')),
                  ],
                  groups: [
                    for (final unit in net)
                      MmBarGroup(
                        label: context.tr(unit.en, unit.ur),
                        values: [Money.fromRupees(unit.value)],
                      ),
                  ],
                  semanticSummary: context.tr(
                    'Net income in October: House 12 earned most, 104000 '
                        'rupees; Shop 7 lost 12000 rupees to repairs.',
                    'اکتوبر میں خالص آمدن: مکان 12 سب سے زیادہ، 104000 روپے؛ '
                        'دکان 7 میں مرمت پر 12000 روپے کا نقصان۔',
                  ),
                ),
              ),
            ],
          ),
          Specimen(
            title: context.tr('Proportion bars', 'تناسب کی بار'),
            component: 'MmProportionBar',
            note: context.tr(
              'One whole split into parts, each with its own pattern.',
              'ایک کل کے حصے، ہر حصہ اپنے نمونے کے ساتھ۔',
            ),
            children: [
              StateLabel(
                label: context.tr('November rent', 'نومبر کا کرایہ'),
                child: MmProportionBar(
                  segments: [
                    MmProportionSegment(
                      label: context.tr('Paid', 'ادا شدہ'),
                      value: const Money.fromRupees(97000),
                      tone: MmSegmentTone.paid,
                    ),
                    MmProportionSegment(
                      label: context.tr('Due soon', 'جلد واجب'),
                      value: const Money.fromRupees(60000),
                      tone: MmSegmentTone.dueSoon,
                    ),
                    MmProportionSegment(
                      label: context.tr('Overdue', 'واجب الادا'),
                      value: const Money.fromRupees(125000),
                      tone: MmSegmentTone.overdue,
                    ),
                    MmProportionSegment(
                      label: context.tr('Not yet due', 'ابھی واجب نہیں'),
                      value: const Money.fromRupees(38000),
                      tone: MmSegmentTone.neutral,
                    ),
                  ],
                  semanticSummary: context.tr(
                    '30% paid, 19% due soon, 39% overdue, 12% not yet due.',
                    '30% ادا شدہ، 19% جلد واجب، 39% واجب الادا، 12% ابھی '
                        'واجب نہیں۔',
                  ),
                ),
              ),
              StateLabel(
                label: context.tr('Overdue by age', 'تاخیر کی مدت کے لحاظ سے'),
                child: MmProportionBar(
                  segments: [
                    MmProportionSegment(
                      label: context.tr('Up to 30 days', '30 دن تک'),
                      value: const Money.fromRupees(60000),
                      tone: MmSegmentTone.dueSoon,
                    ),
                    MmProportionSegment(
                      label: context.tr('31 to 60 days', '31 سے 60 دن'),
                      value: const Money.fromRupees(125000),
                      tone: MmSegmentTone.overdue,
                    ),
                    MmProportionSegment(
                      label: context.tr('Over 60 days', '60 دن سے زیادہ'),
                      value: const Money.fromRupees(45000),
                      tone: MmSegmentTone.overdueSevere,
                    ),
                  ],
                  semanticSummary: context.tr(
                    'Overdue rent by age: 60000 rupees up to 30 days, 125000 '
                        'from 31 to 60 days, 45000 over 60 days.',
                    'تاخیر کی مدت کے لحاظ سے: 30 دن تک 60000 روپے، 31 سے 60 '
                        'دن 125000، 60 دن سے زیادہ 45000۔',
                  ),
                ),
              ),
              StateLabel(
                label: context.tr(
                  'Money held for tenants',
                  'کرایہ داروں کی جمع رقم',
                ),
                child: MmProportionBar(
                  segments: [
                    MmProportionSegment(
                      label: context.tr('Security deposits', 'زر ضمانت'),
                      value: const Money.fromRupees(250000),
                      tone: MmSegmentTone.primary,
                    ),
                    MmProportionSegment(
                      label: context.tr('Advance rent', 'پیشگی کرایہ'),
                      value: const Money.fromRupees(15000),
                      tone: MmSegmentTone.credit,
                    ),
                  ],
                  semanticSummary: context.tr(
                    'Held for tenants: 250000 rupees of security deposits '
                        'and 15000 of advance rent.',
                    'کرایہ داروں کے لیے جمع: 250000 روپے زر ضمانت اور 15000 '
                        'پیشگی کرایہ۔',
                  ),
                ),
              ),
              StateLabel(
                label: context.tr('Nothing due yet', 'ابھی کچھ واجب نہیں'),
                child: MmProportionBar(
                  segments: [
                    MmProportionSegment(
                      label: context.tr('Paid', 'ادا شدہ'),
                      value: Money.zero,
                      tone: MmSegmentTone.paid,
                    ),
                    MmProportionSegment(
                      label: context.tr('Overdue', 'واجب الادا'),
                      value: Money.zero,
                      tone: MmSegmentTone.overdue,
                    ),
                  ],
                  emptyLabel: context.tr(
                    'No rent due yet this month.',
                    'اس ماہ ابھی کوئی کرایہ واجب نہیں۔',
                  ),
                  semanticSummary: context.tr(
                    'No rent due yet this month.',
                    'اس ماہ ابھی کوئی کرایہ واجب نہیں۔',
                  ),
                ),
              ),
            ],
          ),
          Specimen(
            title: context.tr('Sparklines', 'مختصر رجحان'),
            component: 'MmSparkline',
            note: context.tr(
              'A word-sized trend beside a figure; time runs from the start '
                  'edge.',
              'کسی عدد کے ساتھ لفظ جتنا رجحان؛ وقت شروع والے کنارے سے چلتا ہے۔',
            ),
            children: [
              MmCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    for (final (index, tenant) in tenants.take(3).indexed)
                      MmListTile(
                        title: tenant.name.of(context),
                        subtitle: context.tr(
                          'Days late, last 6 months',
                          'تاخیر کے دن، پچھلے 6 ماہ',
                        ),
                        trailing: ExcludeSemantics(
                          child: MmSparkline(
                            values: const <List<double>>[
                              [0, 0, 2, 0, 1, 0],
                              [3, 8, 5, 12, 9, 12],
                              [1, 2, 1, 3, 2, 4],
                            ][index],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          Specimen(
            title: context.tr('Data table', 'جدول'),
            component: 'MmDataTable',
            note: context.tr(
              'A plain ledger table; figures line up at the end.',
              'سادہ کھاتے کا جدول؛ اعداد آخر میں ایک سیدھ میں۔',
            ),
            children: [
              MmDataTable(
                caption: context.tr(
                  'Rent roll, November',
                  'کرایہ رجسٹر، نومبر',
                ),
                columns: [
                  MmDataColumn(label: context.tr('Tenant', 'کرایہ دار')),
                  MmDataColumn(label: context.tr('Property', 'جائیداد')),
                  MmDataColumn(
                    label: context.tr('Rent', 'کرایہ'),
                    numeric: true,
                  ),
                  MmDataColumn(
                    label: context.tr('Score', 'اسکور'),
                    numeric: true,
                  ),
                ],
                rows: [
                  for (final tenant in tenants)
                    [
                      tenant.name.of(context),
                      tenant.property.of(context),
                      MmFormats.moneyOf(context).format(tenant.rent),
                      '${tenant.score}',
                    ],
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
