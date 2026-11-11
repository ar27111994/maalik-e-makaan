import 'package:flutter/material.dart';
import 'package:mm_core/mm_core.dart';
import 'package:mm_ui/mm_ui.dart';

import 'package:mm_ui_gallery/src/copy.dart';
import 'package:mm_ui_gallery/src/sample_data.dart';
import 'package:mm_ui_gallery/src/settings.dart';
import 'package:mm_ui_gallery/src/shell.dart';
import 'package:mm_ui_gallery/src/specimen.dart';

/// Nameplates, receipts, meters, score gauges and timelines.
class RecordsPage extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    final ali = tenants.first;
    const collected = Money.fromRupees(270000);
    const due = Money.fromRupees(320000);
    return FamilyPage(
      family: GalleryFamily.records,
      body: SpecimenList(
        children: [
          Specimen(
            title: context.tr('Nameplate', 'نام کی تختی'),
            component: 'MmNameplate',
            note: context.tr(
              'The brass plate: a property’s name, at most once per screen.',
              'پیتل کی تختی: جائیداد کا نام، ہر اسکرین پر زیادہ سے زیادہ '
                  'ایک بار۔',
            ),
            children: [
              MmNameplate(
                name: ali.property.of(context),
                subtitle: context.tr(
                  'House 12, Street 4, Gulberg III, Lahore',
                  'مکان 12، گلی 4، گلبرگ III، لاہور',
                ),
                icon: MmIcons.property,
              ),
              StateLabel(
                label: context.tr('Name only', 'صرف نام'),
                child: const Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: MmNameplate(name: 'Clifton Residency'),
                ),
              ),
            ],
          ),
          Specimen(
            title: context.tr('Receipt', 'رسید'),
            component: 'MmReceipt',
            note: context.tr(
              'The raseed: perforated edge, brass seal, the amount first.',
              'رسید: سوراخ دار کنارہ، پیتل کی مہر، سب سے پہلے رقم۔',
            ),
            children: [
              _receipt(context),
              StateLabel(
                label: context.tr('Void', 'کینسل'),
                child: _receipt(context, voided: true),
              ),
            ],
          ),
          Specimen(
            title: context.tr('Meters', 'پیمانے'),
            component: 'MmMeter',
            children: [
              MmMeter(
                value: collected.paisa / due.paisa,
                label: context.tr(
                  'Rent collected, October',
                  'اکتوبر میں کرایہ وصول',
                ),
                valueLabel: context.tr(
                  '${money(context, collected)} of ${money(context, due)}',
                  '${money(context, due)} میں سے ${money(context, collected)}',
                ),
                semanticValue: context.tr(
                  '${spoken(context, collected)} of '
                      '${spoken(context, due)}',
                  '${spoken(context, due)} میں سے '
                      '${spoken(context, collected)}',
                ),
                tone: MmMeterTone.paid,
              ),
              MmMeter(
                value: 10 / 12,
                label: context.tr('Lease used, Flat 3', 'کرایہ نامہ، فلیٹ 3'),
                valueLabel: context.tr('10 of 12 months', '12 میں سے 10 مہینے'),
                tone: MmMeterTone.dueSoon,
              ),
              MmMeter(
                value: 11 / 12,
                label: context.tr('Units let', 'کرائے پر یونٹس'),
                valueLabel: context.tr('11 of 12', '12 میں سے 11'),
              ),
            ],
          ),
          Specimen(
            title: context.tr('Payment score', 'ادائیگی اسکور'),
            component: 'MmScoreGauge',
            note: context.tr(
              'Out of 100, filled from the start edge.',
              '100 میں سے، شروع والے کنارے سے بھرا ہوا۔',
            ),
            children: [
              SpecimenWrap(
                children: [
                  for (final score in [92, 68, 41]) _gauge(context, score),
                ],
              ),
            ],
          ),
          Specimen(
            title: context.tr('Timeline', 'ٹائم لائن'),
            component: 'MmTimeline',
            children: [
              MmTimeline(
                items: [
                  MmTimelineItem(
                    dateLabel: dateLabel(context, CalendarDate(2026, 11, 5)),
                    title: context.tr('Payment received', 'ادائیگی وصول ہوئی'),
                    subtitle: context.tr(
                      '${money(context, ali.rent)} by bank transfer',
                      '${money(context, ali.rent)} بینک ٹرانسفر سے',
                    ),
                    semanticLabel: context.tr(
                      '5 November 2026, payment received, '
                          '${spoken(context, ali.rent)} by bank transfer',
                      '5 نومبر 2026، ادائیگی وصول ہوئی، '
                          '${spoken(context, ali.rent)} بینک ٹرانسفر سے',
                    ),
                    icon: MmIcons.payment,
                    tone: MmTimelineTone.paid,
                  ),
                  MmTimelineItem(
                    dateLabel: dateLabel(context, CalendarDate(2026, 11, 1)),
                    title: context.tr('Rent due', 'کرائے کی تاریخ'),
                    subtitle: context.tr(
                      'Reminder sent by SMS',
                      'ایس ایم ایس سے یاد دہانی',
                    ),
                    icon: MmIcons.dueDate,
                    tone: MmTimelineTone.dueSoon,
                  ),
                  MmTimelineItem(
                    dateLabel: dateLabel(context, CalendarDate(2026, 9, 12)),
                    title: context.tr('Rent overdue', 'کرایہ لیٹ'),
                    subtitle: context.tr(
                      'Paid 7 days late',
                      '7 دن لیٹ ادا ہوا',
                    ),
                    tone: MmTimelineTone.overdue,
                  ),
                  MmTimelineItem(
                    dateLabel: dateLabel(context, CalendarDate(2026, 7, 1)),
                    title: context.tr('Lease signed', 'کرایہ نامے پر دستخط'),
                    subtitle: context.tr(
                      '12 months, Flat 3',
                      '12 مہینے، فلیٹ 3',
                    ),
                    icon: MmIcons.lease,
                    tone: MmTimelineTone.primary,
                  ),
                  MmTimelineItem(
                    dateLabel: dateLabel(context, CalendarDate(2026, 6, 28)),
                    title: context.tr('Tenant added', 'کرایہ دار شامل ہوا'),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _receipt(BuildContext context, {bool voided = false}) {
    final ali = tenants.first;
    return MmReceipt(
      issuer: context.tr('Imran Qureshi, Raza Manzil', 'عمران قریشی، رضا منزل'),
      numberLabel: context.tr('Receipt no.', 'رسید نمبر'),
      receiptNumber: voided ? 'R-2026-0139' : 'R-2026-0142',
      amountLabel: context.tr('Amount received', 'کتنی رقم ملی'),
      amount: ali.rent,
      rows: [
        MmReceiptRow(
          label: context.tr('Tenant', 'کرایہ دار'),
          value: ali.name.of(context),
        ),
        MmReceiptRow(
          label: context.tr('Property', 'جائیداد'),
          value: ali.unit.of(context),
        ),
        MmReceiptRow(
          label: context.tr('Period', 'مدت'),
          value: context.tr('November 2026', 'نومبر 2026'),
        ),
        MmReceiptRow(
          label: context.tr('Method', 'طریقہ'),
          value: context.tr('Bank transfer', 'بینک ٹرانسفر'),
        ),
        MmReceiptRow(
          label: context.tr('Received on', 'وصولی کی تاریخ'),
          value: dateLabel(context, CalendarDate(2026, 11, 5)),
        ),
      ],
      footer: context.tr(
        'Thank you. Keep this receipt for your records.',
        'شکریہ۔ یہ رسید اپنے ریکارڈ کے لیے محفوظ رکھیں۔',
      ),
      voidedLabel: voided
          ? context.tr(
              'VOID: cancelled on 6 Nov 2026',
              'کینسل: 6 نومبر 2026 کو کینسل ہوئی',
            )
          : null,
    );
  }

  Widget _gauge(BuildContext context, int score) {
    final band = MmScoreBand.of(score);
    final word = switch (band) {
      MmScoreBand.good => context.tr('Good', 'اچھا'),
      MmScoreBand.fair => context.tr('Fair', 'مناسب'),
      MmScoreBand.poor => context.tr('Poor', 'کمزور'),
    };
    return MmScoreGauge(
      score: score,
      bandLabel: word,
      semanticLabel: context.tr(
        'Payment score $score out of 100, $word',
        'ادائیگی اسکور 100 میں سے $score، $word',
      ),
      caption: context.tr('12 months of payments', '12 مہینوں کی ادائیگیاں'),
    );
  }
}
