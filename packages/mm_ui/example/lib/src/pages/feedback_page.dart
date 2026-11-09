import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mm_ui/mm_ui.dart';

import 'package:mm_ui_gallery/src/copy.dart';
import 'package:mm_ui_gallery/src/sample_data.dart';
import 'package:mm_ui_gallery/src/settings.dart';
import 'package:mm_ui_gallery/src/shell.dart';
import 'package:mm_ui_gallery/src/specimen.dart';

/// Banners, empty and error states, skeletons, snack bars, confirmation
/// dialogs and sheets.
class FeedbackPage extends StatefulWidget {
  const new({super.key});

  @override
  State<FeedbackPage> createState() => _FeedbackPageState();
}

class _FeedbackPageState extends State<FeedbackPage> {
  var _bannerShown = true;
  String? _lastAnswer;

  @override
  Widget build(BuildContext context) {
    final renew = context.tr('Renew lease', 'کرایہ نامہ تجدید کریں');
    return FamilyPage(
      family: GalleryFamily.feedback,
      body: SpecimenList(
        children: [
          Specimen(
            title: context.tr('Banners', 'اعلانات'),
            component: 'MmBanner',
            note: context.tr(
              'An inline notice: info, success, warning or error.',
              'صفحے کے اندر اطلاع: معلومات، کامیابی، انتباہ یا غلطی۔',
            ),
            children: [
              MmBanner(
                tone: MmBannerTone.info,
                message: context.tr(
                  'Reminders go out on the 1st of every month.',
                  'یاد دہانیاں ہر ماہ کی پہلی تاریخ کو جاتی ہیں۔',
                ),
              ),
              MmBanner(
                tone: MmBannerTone.success,
                title: context.tr('Payment recorded', 'ادائیگی درج ہو گئی'),
                message: context.tr(
                  'Ali Raza’s November rent is marked paid.',
                  'علی رضا کا نومبر کا کرایہ ادا شدہ درج ہو گیا۔',
                ),
              ),
              if (_bannerShown)
                MmBanner(
                  tone: MmBannerTone.warning,
                  title: context.tr('Lease ending', 'کرایہ نامہ ختم ہو رہا ہے'),
                  message: context.tr(
                    'Bilal Ahmed’s lease for Shop 7 ends in 14 days.',
                    'دکان 7 کے لیے بلال احمد کا کرایہ نامہ 14 دن میں ختم '
                        'ہو گا۔',
                  ),
                  actionLabel: renew,
                  onAction: () => showPressed(context, renew),
                  onDismiss: () => setState(() => _bannerShown = false),
                )
              else
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: MmButton(
                    label: context.tr(
                      'Show the warning again',
                      'انتباہ دوبارہ دکھائیں',
                    ),
                    variant: MmButtonVariant.tertiary,
                    icon: MmIcons.undo,
                    onPressed: () => setState(() => _bannerShown = true),
                  ),
                ),
              MmBanner(
                tone: MmBannerTone.error,
                title: context.tr(
                  'Reminders not sent',
                  'یاد دہانیاں نہیں گئیں',
                ),
                message: context.tr(
                  '3 SMS reminders failed. Check the phone numbers and try '
                      'again.',
                  '3 ایس ایم ایس یاد دہانیاں ناکام ہوئیں۔ فون نمبر جانچ کر '
                      'دوبارہ کوشش کریں۔',
                ),
                actionLabel: context.tr('Try again', 'دوبارہ کوشش کریں'),
                onAction: () => showPressed(
                  context,
                  context.tr('Try again', 'دوبارہ کوشش کریں'),
                ),
              ),
            ],
          ),
          Specimen(
            title: context.tr('Snack bars', 'مختصر پیغامات'),
            component: 'showMmSnackbar',
            note: context.tr(
              'A passing confirmation at the bottom of the screen.',
              'اسکرین کے نیچے عارضی تصدیق۔',
            ),
            children: [
              SpecimenWrap(
                children: [
                  MmButton(
                    label: context.tr('Plain', 'سادہ'),
                    variant: MmButtonVariant.secondary,
                    onPressed: () => unawaited(
                      showMmSnackbar(
                        context,
                        message: context.tr(
                          'Receipt shared',
                          'رسید بھیج دی گئی',
                        ),
                      ),
                    ),
                  ),
                  MmButton(
                    label: context.tr('Success', 'کامیابی'),
                    variant: MmButtonVariant.secondary,
                    onPressed: () => unawaited(
                      showMmSnackbar(
                        context,
                        tone: MmBannerTone.success,
                        message: context.tr(
                          'Payment recorded',
                          'ادائیگی درج ہو گئی',
                        ),
                      ),
                    ),
                  ),
                  MmButton(
                    label: context.tr('With undo', 'واپسی کے ساتھ'),
                    variant: MmButtonVariant.secondary,
                    onPressed: () => unawaited(
                      showMmSnackbar(
                        context,
                        message: context.tr(
                          'Payment deleted',
                          'ادائیگی حذف ہو گئی',
                        ),
                        actionLabel: context.tr('Undo', 'واپس کریں'),
                        onAction: () => showPressed(
                          context,
                          context.tr('Undo', 'واپس کریں'),
                        ),
                      ),
                    ),
                  ),
                  MmButton(
                    label: context.tr('Error', 'غلطی'),
                    variant: MmButtonVariant.secondary,
                    onPressed: () => unawaited(
                      showMmSnackbar(
                        context,
                        tone: MmBannerTone.error,
                        message: context.tr(
                          'Could not send the receipt.',
                          'رسید نہیں بھیجی جا سکی۔',
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          Specimen(
            title: context.tr('Confirmation dialogs', 'تصدیقی ڈائیلاگ'),
            component: 'showMmConfirmDialog',
            note: context.tr(
              'Destructive actions confirm first; the answer shows below.',
              'مٹانے والے کام پہلے تصدیق مانگتے ہیں؛ جواب نیچے نظر آتا ہے۔',
            ),
            children: [
              SpecimenWrap(
                children: [
                  MmButton(
                    label: context.tr('Send reminder', 'یاد دہانی بھیجیں'),
                    variant: MmButtonVariant.secondary,
                    onPressed: () => _confirm(
                      showMmConfirmDialog(
                        context,
                        title: context.tr(
                          'Send a reminder to Ayesha Khan?',
                          'عائشہ خان کو یاد دہانی بھیجیں؟',
                        ),
                        message: context.tr(
                          'She will get an SMS about Rs 1,25,000 overdue since '
                              '5 October.',
                          'انہیں 5 اکتوبر سے واجب الادا 1,25,000 روپے کے بارے '
                              'میں ایس ایم ایس ملے گا۔',
                        ),
                        confirmLabel: context.tr(
                          'Send reminder',
                          'یاد دہانی بھیجیں',
                        ),
                      ),
                    ),
                  ),
                  MmButton(
                    label: context.tr('Remove tenant', 'کرایہ دار ہٹائیں'),
                    variant: MmButtonVariant.destructive,
                    onPressed: () => _confirm(
                      showMmConfirmDialog(
                        context,
                        title: context.tr(
                          'Remove Ali Raza?',
                          'علی رضا کو ہٹائیں؟',
                        ),
                        message: context.tr(
                          'His ledger and receipts stay in your records; he '
                              'will no longer appear in Raza Manzil.',
                          'ان کا کھاتہ اور رسیدیں آپ کے ریکارڈ میں رہیں گی؛ وہ '
                              'رضا منزل میں مزید نظر نہیں آئیں گے۔',
                        ),
                        confirmLabel: context.tr(
                          'Remove tenant',
                          'کرایہ دار ہٹائیں',
                        ),
                        destructive: true,
                      ),
                    ),
                  ),
                  MmButton(
                    label: context.tr('Delete property', 'جائیداد حذف کریں'),
                    variant: MmButtonVariant.destructive,
                    onPressed: () => _confirm(
                      showMmConfirmDialog(
                        context,
                        title: context.tr(
                          'Delete Raza Manzil?',
                          'رضا منزل حذف کریں؟',
                        ),
                        message: context.tr(
                          'Its 4 units, 2 leases and 38 payments are deleted '
                              'for good.',
                          'اس کے 4 یونٹس، 2 کرایہ نامے اور 38 ادائیگیاں ہمیشہ '
                              'کے لیے حذف ہو جائیں گی۔',
                        ),
                        confirmLabel: context.tr(
                          'Delete property',
                          'جائیداد حذف کریں',
                        ),
                        destructive: true,
                        typedConfirmation: context.tr(
                          'Raza Manzil',
                          'رضا منزل',
                        ),
                        typedConfirmationLabel: context.tr(
                          'Type Raza Manzil to confirm',
                          'تصدیق کے لیے رضا منزل لکھیں',
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              if (_lastAnswer case final answer?)
                Text(answer, style: Theme.of(context).textTheme.bodyMedium),
            ],
          ),
          Specimen(
            title: context.tr('Sheet', 'شیٹ'),
            component: 'showMmSheet',
            note: context.tr(
              'A bottom sheet with a title and a close button.',
              'نیچے سے کھلنے والی شیٹ، عنوان اور بند کرنے کے بٹن کے ساتھ۔',
            ),
            children: [
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: MmButton(
                  label: context.tr('Show dues', 'واجبات دکھائیں'),
                  variant: MmButtonVariant.secondary,
                  icon: MmIcons.ledger,
                  onPressed: () => unawaited(
                    showMmSheet<void>(
                      context,
                      title: context.tr('October dues', 'اکتوبر کے واجبات'),
                      builder: (context) => Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (final tenant in tenants)
                            MmDetailRow.amount(
                              label: tenant.name.of(context),
                              amount: tenant.rent,
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          Specimen(
            title: context.tr('Empty state', 'خالی حالت'),
            component: 'MmEmptyState',
            children: [
              MmEmptyState(
                icon: MmIcons.tenants,
                title: context.tr('No tenants yet', 'ابھی کوئی کرایہ دار نہیں'),
                message: context.tr(
                  'Add your first tenant to start tracking rent.',
                  'کرایہ کا حساب رکھنے کے لیے پہلا کرایہ دار شامل کریں۔',
                ),
                actionLabel: context.tr('Add tenant', 'کرایہ دار شامل کریں'),
                onAction: () => showPressed(
                  context,
                  context.tr('Add tenant', 'کرایہ دار شامل کریں'),
                ),
              ),
            ],
          ),
          Specimen(
            title: context.tr('Error state', 'غلطی کی حالت'),
            component: 'MmErrorState',
            children: [
              MmErrorState(
                title: context.tr('Ledger unavailable', 'کھاتہ دستیاب نہیں'),
                message: context.tr(
                  'Your ledger could not be loaded. Check your connection and '
                      'try again.',
                  'آپ کا کھاتہ لوڈ نہیں ہو سکا۔ انٹرنیٹ کنکشن جانچ کر دوبارہ '
                      'کوشش کریں۔',
                ),
                onRetry: () =>
                    showPressed(context, MmLocalizations.of(context).retry),
                details:
                    'HTTP 503 · ledger/v2/properties/raza-manzil · '
                    'request 7f3c2a',
                detailsLabel: context.tr('Technical details', 'تکنیکی تفصیل'),
              ),
            ],
          ),
          Specimen(
            title: context.tr('Loading', 'لوڈ ہو رہا ہے'),
            component: 'MmSkeleton · MmSkeletonList',
            note: context.tr(
              'Skeletons, not spinners, while content loads.',
              'مواد لوڈ ہوتے وقت اسپنر نہیں، خاکے۔',
            ),
            children: const [
              Row(
                children: [
                  MmSkeleton.circle(diameter: MmSize.iconXl),
                  SizedBox(width: MmSpace.s3),
                  Expanded(child: MmSkeleton.text(lines: 2)),
                ],
              ),
              MmSkeleton.box(height: MmSpace.s16),
              MmSkeletonList(itemCount: 3),
            ],
          ),
        ],
      ),
    );
  }

  void _confirm(Future<bool> answer) => unawaited(
    answer.then((confirmed) {
      if (!mounted) return;
      setState(
        () => _lastAnswer = confirmed
            ? context.tr('Answer: confirmed.', 'جواب: تصدیق کی گئی۔')
            : context.tr('Answer: cancelled.', 'جواب: منسوخ کیا گیا۔'),
      );
    }),
  );
}
