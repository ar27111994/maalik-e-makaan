import 'package:flutter/material.dart';
import 'package:mm_core/mm_core.dart';
import 'package:mm_ui/mm_ui.dart';

import 'package:mm_ui_gallery/src/copy.dart';
import 'package:mm_ui_gallery/src/sample_data.dart';
import 'package:mm_ui_gallery/src/settings.dart';
import 'package:mm_ui_gallery/src/shell.dart';
import 'package:mm_ui_gallery/src/specimen.dart';

enum _Method { cash, bank, wallet }

/// Dates, selects, switches, checkboxes, radio groups, search, filter
/// chips and steppers.
class ChoicesPage extends StatefulWidget {
  const new({super.key});

  @override
  State<ChoicesPage> createState() => _ChoicesPageState();
}

class _ChoicesPageState extends State<ChoicesPage> {
  CalendarDate? _leaseStart = CalendarDate(2026, 7, 1);
  CalendarDate? _paidOn;
  CalendarDate? _moveOut = CalendarDate(2027, 6, 30);
  int? _property = 0;
  int? _unit;
  var _reminders = true;
  var _lateFees = false;
  var _electricity = true;
  bool? _allUnits;
  var _cnicChecked = false;
  _Method? _method = _Method.bank;
  _Method? _unanswered;
  var _query = '';
  Set<MmStatus> _filters = {MmStatus.overdue};
  Set<String> _city = {'lahore'};
  var _advance = 2;
  var _reminderDays = 3;

  @override
  Widget build(BuildContext context) {
    final first = CalendarDate(2020, 1, 1);
    final last = CalendarDate(2030, 12, 31);
    final properties = [
      for (final (index, tenant) in tenants.indexed)
        MmOption(
          value: index,
          label: tenant.property.of(context),
          description: tenant.unit.of(context),
          icon: tenant.status == MmStatus.dueSoon
              ? MmIcons.shop
              : MmIcons.property,
        ),
    ];
    final matching = [
      for (final tenant in tenants)
        if (_query.trim().isEmpty ||
            tenant.name.en.toLowerCase().contains(
              _query.trim().toLowerCase(),
            ) ||
            tenant.name.ur.contains(_query.trim()))
          tenant.name.of(context),
    ];
    return FamilyPage(
      family: GalleryFamily.choices,
      body: SpecimenList(
        children: [
          Specimen(
            title: context.tr('Date fields', 'تاریخ کے خانے'),
            component: 'MmDateField',
            note: context.tr(
              'Tap to pick from the calendar.',
              'کیلنڈر سے چننے کے لیے دبائیں۔',
            ),
            children: [
              MmDateField(
                label: context.tr('Lease start', 'کرایہ نامے کا آغاز'),
                value: _leaseStart,
                firstDate: first,
                lastDate: last,
                required: true,
                onChanged: (value) => setState(() => _leaseStart = value),
              ),
              MmDateField(
                label: context.tr('Lease end', 'کرایہ نامے کا اختتام'),
                value: _moveOut,
                firstDate: first,
                lastDate: last,
                optional: true,
                helper: context.tr(
                  'Optional: clear it for a rolling lease.',
                  'اختیاری: غیر معینہ مدت کے لیے خالی کریں۔',
                ),
                onChanged: (value) => setState(() => _moveOut = value),
              ),
              MmDateField(
                label: context.tr('Paid on', 'ادائیگی کی تاریخ'),
                value: _paidOn,
                firstDate: first,
                lastDate: last,
                required: true,
                errorText: _paidOn == null
                    ? context.tr(
                        'Choose the day the rent was received.',
                        'وہ دن چنیں جب کرایہ وصول ہوا۔',
                      )
                    : null,
                onChanged: (value) => setState(() => _paidOn = value),
              ),
              MmDateField(
                label: context.tr('Agreement signed', 'معاہدے پر دستخط'),
                value: CalendarDate(2026, 6, 24),
                firstDate: first,
                lastDate: last,
                enabled: false,
                onChanged: (_) {},
              ),
            ],
          ),
          Specimen(
            title: context.tr('Select fields', 'انتخاب کے خانے'),
            component: 'MmSelectField',
            note: context.tr(
              'Opens a sheet of options.',
              'اختیارات کی شیٹ کھولتا ہے۔',
            ),
            children: [
              MmSelectField<int>(
                label: context.tr('Property', 'جائیداد'),
                options: properties,
                value: _property,
                required: true,
                onChanged: (value) => setState(() => _property = value),
              ),
              MmSelectField<int>(
                label: context.tr('Unit', 'یونٹ'),
                options: [
                  for (var floor = 1; floor <= 4; floor++)
                    MmOption(
                      value: floor,
                      label: context.tr('Flat $floor', 'فلیٹ $floor'),
                    ),
                ],
                value: _unit,
                placeholder: context.tr('Choose a unit', 'یونٹ چنیں'),
                errorText: _unit == null
                    ? context.tr(
                        'Choose the unit the tenant rents.',
                        'وہ یونٹ چنیں جو کرایہ دار نے لیا ہے۔',
                      )
                    : null,
                onChanged: (value) => setState(() => _unit = value),
              ),
              MmSelectField<int>(
                label: context.tr('Landlord', 'مالک مکان'),
                options: [
                  MmOption(
                    value: 0,
                    label: context.tr('Imran Qureshi', 'عمران قریشی'),
                  ),
                ],
                value: 0,
                helper: context.tr(
                  'Disabled: only one landlord on this account.',
                  'غیر فعال: اس اکاؤنٹ میں ایک ہی مالک مکان ہے۔',
                ),
                onChanged: null,
              ),
            ],
          ),
          Specimen(
            title: context.tr('Switches', 'سوئچ'),
            component: 'MmSwitchTile',
            note: context.tr(
              'A setting that takes effect at once.',
              'ایسی ترتیب جو فوراً لاگو ہو۔',
            ),
            children: [
              MmSwitchTile(
                label: context.tr(
                  'Send rent reminders',
                  'کرائے کی یاد دہانیاں بھیجیں',
                ),
                description: context.tr(
                  'By SMS, 3 days before the due date.',
                  'ایس ایم ایس سے، مقررہ تاریخ سے 3 دن پہلے۔',
                ),
                value: _reminders,
                onChanged: (value) => setState(() => _reminders = value),
              ),
              MmSwitchTile(
                label: context.tr('Add late fees', 'تاخیر کی فیس لگائیں'),
                value: _lateFees,
                onChanged: (value) => setState(() => _lateFees = value),
              ),
              MmSwitchTile(
                label: context.tr('Sync with bank', 'بینک سے ہم آہنگ کریں'),
                description: context.tr(
                  'Disabled: link a bank account first.',
                  'غیر فعال: پہلے بینک اکاؤنٹ جوڑیں۔',
                ),
                value: false,
                onChanged: null,
              ),
            ],
          ),
          Specimen(
            title: context.tr('Checkboxes', 'چیک باکس'),
            component: 'MmCheckboxTile',
            note: context.tr(
              'A yes-or-no choice saved with a form.',
              'ہاں یا نہیں کا انتخاب جو فارم کے ساتھ محفوظ ہو۔',
            ),
            children: [
              MmCheckboxTile(
                label: context.tr(
                  'Rent includes electricity',
                  'کرائے میں بجلی شامل ہے',
                ),
                value: _electricity,
                onChanged: (value) => setState(() => _electricity = value!),
              ),
              MmCheckboxTile(
                label: context.tr(
                  'CNIC seen in person',
                  'شناختی کارڈ خود دیکھا',
                ),
                description: context.tr(
                  'Confirm you checked the original card.',
                  'تصدیق کریں کہ اصل کارڈ دیکھا گیا۔',
                ),
                value: _cnicChecked,
                onChanged: (value) => setState(() => _cnicChecked = value!),
              ),
              MmCheckboxTile(
                label: context.tr(
                  'Apply to every unit',
                  'ہر یونٹ پر لاگو کریں',
                ),
                description: context.tr(
                  'Mixed: some units already have it.',
                  'ملا جلا: کچھ یونٹس پر پہلے سے لاگو ہے۔',
                ),
                tristate: true,
                value: _allUnits,
                onChanged: (value) => setState(() => _allUnits = value),
              ),
              MmCheckboxTile(
                label: context.tr('Lease registered', 'کرایہ نامہ رجسٹرڈ'),
                value: true,
                onChanged: null,
              ),
            ],
          ),
          Specimen(
            title: context.tr('Radio groups', 'ریڈیو گروپ'),
            component: 'MmRadioGroup',
            children: [
              MmRadioGroup<_Method>(
                label: context.tr('How was it paid?', 'ادائیگی کیسے ہوئی؟'),
                required: true,
                options: _methods(context),
                value: _method,
                helper: context.tr(
                  'Shown on the receipt.',
                  'رسید پر لکھا جائے گا۔',
                ),
                onChanged: (value) => setState(() => _method = value),
              ),
              MmRadioGroup<_Method>(
                label: context.tr('Deposit returned by', 'زر ضمانت کی واپسی'),
                options: _methods(context),
                value: _unanswered,
                errorText: _unanswered == null
                    ? context.tr(
                        'Choose how the deposit was returned.',
                        'چنیں کہ زر ضمانت کیسے واپس ہوا۔',
                      )
                    : null,
                onChanged: (value) => setState(() => _unanswered = value),
              ),
              MmRadioGroup<_Method>(
                label: context.tr('Advance paid by', 'پیشگی ادائیگی'),
                options: _methods(context),
                value: _Method.cash,
                onChanged: null,
              ),
            ],
          ),
          Specimen(
            title: context.tr('Search', 'تلاش'),
            component: 'MmSearchField',
            children: [
              MmSearchField(
                hint: context.tr('Search tenants', 'کرایہ دار تلاش کریں'),
                onChanged: (value) => setState(() => _query = value),
              ),
              Text(
                matching.isEmpty
                    ? context.tr(
                        'No tenants match.',
                        'کوئی کرایہ دار نہیں ملا۔',
                      )
                    : matching.join(context.tr(', ', '، ')),
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
          Specimen(
            title: context.tr('Filter chips', 'فلٹر چپس'),
            component: 'MmFilterChips',
            children: [
              StateLabel(
                label: context.tr('Several at once', 'ایک سے زیادہ'),
                child: MmFilterChips<MmStatus>(
                  options: [
                    MmFilterOption(
                      value: MmStatus.overdue,
                      label: context.tr('Overdue', 'واجب الادا'),
                      count: 3,
                    ),
                    MmFilterOption(
                      value: MmStatus.dueSoon,
                      label: context.tr('Due soon', 'جلد واجب'),
                      count: 2,
                    ),
                    MmFilterOption(
                      value: MmStatus.paid,
                      label: context.tr('Paid', 'ادا شدہ'),
                      count: 12,
                    ),
                    MmFilterOption(
                      value: MmStatus.credit,
                      label: context.tr('Advance', 'پیشگی'),
                    ),
                  ],
                  selected: _filters,
                  onChanged: (value) => setState(() => _filters = value),
                ),
              ),
              StateLabel(
                label: context.tr('One at a time', 'ایک وقت میں ایک'),
                child: MmFilterChips<String>(
                  multiSelect: false,
                  options: [
                    MmFilterOption(
                      value: 'lahore',
                      label: context.tr('Lahore', 'لاہور'),
                    ),
                    MmFilterOption(
                      value: 'karachi',
                      label: context.tr('Karachi', 'کراچی'),
                    ),
                    MmFilterOption(
                      value: 'islamabad',
                      label: context.tr('Islamabad', 'اسلام آباد'),
                    ),
                  ],
                  selected: _city,
                  onChanged: (value) => setState(() => _city = value),
                ),
              ),
              StateLabel(
                label: context.tr('Disabled', 'غیر فعال'),
                child: MmFilterChips<String>(
                  options: [
                    MmFilterOption(
                      value: 'shops',
                      label: context.tr('Shops', 'دکانیں'),
                    ),
                    MmFilterOption(
                      value: 'flats',
                      label: context.tr('Flats', 'فلیٹ'),
                    ),
                  ],
                  selected: const {'flats'},
                  onChanged: null,
                ),
              ),
            ],
          ),
          Specimen(
            title: context.tr('Steppers', 'گنتی کے خانے'),
            component: 'MmStepperField',
            children: [
              MmStepperField(
                label: context.tr(
                  'Months of advance rent',
                  'پیشگی کرائے کے مہینے',
                ),
                value: _advance,
                min: 0,
                max: 12,
                decreaseLabel: context.tr('Fewer months', 'کم مہینے'),
                increaseLabel: context.tr('More months', 'زیادہ مہینے'),
                format: (value) => context.tr(
                  value == 1 ? '1 month' : '$value months',
                  '$value ماہ',
                ),
                helper: context.tr(
                  'Up to 12 months.',
                  'زیادہ سے زیادہ 12 ماہ۔',
                ),
                onChanged: (value) => setState(() => _advance = value),
              ),
              MmStepperField(
                label: context.tr(
                  'Remind before due date',
                  'مقررہ تاریخ سے پہلے یاد دہانی',
                ),
                value: _reminderDays,
                min: 1,
                max: 7,
                decreaseLabel: context.tr('Fewer days', 'کم دن'),
                increaseLabel: context.tr('More days', 'زیادہ دن'),
                format: (value) => context.tr(
                  value == 1 ? '1 day' : '$value days',
                  '$value دن',
                ),
                onChanged: (value) => setState(() => _reminderDays = value),
              ),
              MmStepperField(
                label: context.tr('Rooms', 'کمرے'),
                value: 3,
                min: 1,
                max: 10,
                decreaseLabel: context.tr('Fewer rooms', 'کم کمرے'),
                increaseLabel: context.tr('More rooms', 'زیادہ کمرے'),
                onChanged: null,
              ),
            ],
          ),
        ],
      ),
    );
  }

  List<MmOption<_Method>> _methods(BuildContext context) => [
    MmOption(
      value: _Method.cash,
      label: context.tr('Cash', 'نقد'),
      icon: MmIcons.cash,
    ),
    MmOption(
      value: _Method.bank,
      label: context.tr('Bank transfer', 'بینک ٹرانسفر'),
      description: context.tr(
        'Into the account ending 4417.',
        '4417 پر ختم ہونے والے اکاؤنٹ میں۔',
      ),
      icon: MmIcons.bank,
    ),
    MmOption(
      value: _Method.wallet,
      label: context.tr('Mobile wallet', 'موبائل والیٹ'),
      description: context.tr(
        'Easypaisa or JazzCash.',
        'ایزی پیسہ یا جاز کیش۔',
      ),
      icon: MmIcons.phone,
    ),
  ];
}
