import 'package:flutter/material.dart';
import 'package:mm_core/mm_core.dart';
import 'package:mm_ui/mm_ui.dart';

import 'package:mm_ui_gallery/src/copy.dart';
import 'package:mm_ui_gallery/src/sample_data.dart';
import 'package:mm_ui_gallery/src/settings.dart';
import 'package:mm_ui_gallery/src/shell.dart';
import 'package:mm_ui_gallery/src/specimen.dart';

/// Text, password, money, CNIC and phone fields, and the masked CNIC.
class InputsPage extends StatefulWidget {
  const new({super.key});

  @override
  State<InputsPage> createState() => _InputsPageState();
}

class _InputsPageState extends State<InputsPage> {
  final _form = GlobalKey<FormState>();
  Money? _rent = const Money.fromRupees(45000);
  Money? _deposit;
  Cnic? _cnic = tenants.first.parsedCnic;
  Cnic? _newCnic;
  PhoneNumber? _phone = tenants.first.parsedPhone;
  PhoneNumber? _newPhone;

  @override
  Widget build(BuildContext context) {
    final ali = tenants.first;
    final required = context.tr(
      'Enter the tenant’s name.',
      'کرایہ دار کا نام لکھیں۔',
    );
    return FamilyPage(
      family: GalleryFamily.inputs,
      body: Form(
        key: _form,
        child: SpecimenList(
          children: [
            Specimen(
              title: context.tr('Text fields', 'لکھنے کے خانے'),
              component: 'MmTextField',
              note: context.tr(
                'Labelled above, helper or error below in words.',
                'نام اوپر، رہنمائی یا غلطی نیچے الفاظ میں۔',
              ),
              children: [
                MmTextField(
                  label: context.tr('Tenant name', 'کرایہ دار کا نام'),
                  hint: ali.name.of(context),
                  required: true,
                  prefixIcon: MmIcons.person,
                  textCapitalization: TextCapitalization.words,
                  autofillHints: const [AutofillHints.name],
                  validator: (value) =>
                      (value ?? '').trim().isEmpty ? required : null,
                ),
                MmTextField(
                  label: context.tr('Address', 'پتہ'),
                  initialValue: ali.unit.of(context),
                  optional: true,
                  minLines: 2,
                  maxLines: 4,
                  helper: context.tr(
                    'As written on the lease.',
                    'جیسا کرایہ نامے پر لکھا ہے۔',
                  ),
                ),
                MmTextField(
                  label: context.tr(
                    'Note for the tenant',
                    'کرایہ دار کے لیے نوٹ',
                  ),
                  initialValue: context.tr(
                    'Rent is due by the 5th of every month.',
                    'کرایہ ہر مہینے کی 5 تاریخ تک دینا ہے۔',
                  ),
                  maxLength: 120,
                  maxLines: 3,
                ),
                MmTextField(
                  label: context.tr('Unit', 'یونٹ'),
                  initialValue: context.tr('Flat 3', 'فلیٹ 3'),
                  errorText: context.tr(
                    'Flat 3 already has a tenant. Choose another unit.',
                    'فلیٹ 3 میں پہلے سے کرایہ دار ہے۔ کوئی اور یونٹ چنیں۔',
                  ),
                ),
                MmTextField(
                  label: context.tr('Property', 'جائیداد'),
                  initialValue: ali.property.of(context),
                  enabled: false,
                  helper: context.tr(
                    'Disabled: set by the lease.',
                    'بند: کرایہ نامے میں طے ہے۔',
                  ),
                ),
                MmTextField(
                  label: context.tr('Tenant ID', 'کرایہ دار آئی ڈی'),
                  initialValue: 'T-2026-0042',
                  readOnly: true,
                  helper: context.tr(
                    'Read only: select and copy.',
                    'صرف پڑھنے کے لیے: چن کر کاپی کریں۔',
                  ),
                ),
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: MmButton(
                    label: context.tr('Check the form', 'فارم چیک کریں'),
                    variant: MmButtonVariant.secondary,
                    icon: MmIcons.check,
                    onPressed: () => _form.currentState!.validate(),
                  ),
                ),
              ],
            ),
            Specimen(
              title: context.tr('Password field', 'پاس ورڈ کا خانہ'),
              component: 'MmPasswordField',
              children: [
                MmPasswordField(
                  label: context.tr('New password', 'نیا پاس ورڈ'),
                  newPassword: true,
                  helper: context.tr(
                    'At least 8 characters.',
                    'کم از کم 8 حروف۔',
                  ),
                ),
                MmPasswordField(
                  label: context.tr('Password', 'پاس ورڈ'),
                  initialValue: 'raseed-2026',
                  errorText: context.tr(
                    'Wrong password. Try again or reset it.',
                    'غلط پاس ورڈ۔ دوبارہ کوشش کریں یا نیا بنائیں۔',
                  ),
                ),
              ],
            ),
            Specimen(
              title: context.tr('Money fields', 'رقم کے خانے'),
              component: 'MmMoneyField',
              note: context.tr(
                'Shows the currency and groups the figures as you type.',
                'کرنسی دکھاتا ہے اور لکھتے وقت ہندسوں کو گروپ کرتا ہے۔',
              ),
              children: [
                MmMoneyField(
                  label: context.tr('Monthly rent', 'ماہانہ کرایہ'),
                  value: _rent,
                  required: true,
                  allowZero: false,
                  max: const Money.fromRupees(10000000),
                  helper: context.tr(
                    'Up to Rs 1 crore.',
                    'زیادہ سے زیادہ 1 کروڑ روپے۔',
                  ),
                  onChanged: (value) => setState(() => _rent = value),
                ),
                MmMoneyField(
                  label: context.tr('Security deposit', 'سیکیورٹی'),
                  value: _deposit,
                  optional: true,
                  onChanged: (value) => setState(() => _deposit = value),
                ),
                MmMoneyField(
                  label: context.tr('Amount received', 'کتنی رقم ملی'),
                  value: const Money.fromRupees(150000),
                  errorText: context.tr(
                    'More than the Rs 1,25,000 due. Check the amount.',
                    'یہ باقی 1,25,000 روپے سے زیادہ ہے۔ رقم چیک کریں۔',
                  ),
                  onChanged: (_) {},
                ),
                MmMoneyField(
                  label: context.tr('Late fee', 'لیٹ فیس'),
                  value: const Money.fromRupees(2500),
                  enabled: false,
                  onChanged: (_) {},
                ),
              ],
            ),
            Specimen(
              title: context.tr(
                'CNIC field and saved CNIC',
                'شناختی کارڈ نمبر',
              ),
              component: 'MmCnicField · MmCnicText',
              note: context.tr(
                'Dashes are added as you type. A saved CNIC shows masked '
                    'until revealed.',
                'لکھتے وقت ڈیش خود لگتے ہیں۔ محفوظ نمبر چھپا رہتا ہے جب '
                    'تک دکھایا نہ جائے۔',
              ),
              children: [
                MmCnicField(
                  label: context.tr('Tenant CNIC', 'کرایہ دار کا شناختی کارڈ'),
                  value: _cnic,
                  required: true,
                  onChanged: (value) => setState(() => _cnic = value),
                ),
                MmCnicField(
                  label: context.tr('Guarantor CNIC', 'ضامن کا شناختی کارڈ'),
                  value: _newCnic,
                  optional: true,
                  helper: context.tr(
                    '13 digits, from the front of the card.',
                    'کارڈ کے سامنے والے 13 ہندسے۔',
                  ),
                  onChanged: (value) => setState(() => _newCnic = value),
                ),
                MmCnicField(
                  label: context.tr('Witness CNIC', 'گواہ کا شناختی کارڈ'),
                  errorText: context.tr(
                    'Enter the witness’s CNIC: 13 digits.',
                    'گواہ کا شناختی کارڈ نمبر لکھیں: 13 ہندسے۔',
                  ),
                  onChanged: (_) {},
                ),
                StateLabel(
                  label: context.tr('Saved CNIC', 'محفوظ شناختی کارڈ'),
                  child: Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: MmCnicText(cnic: ali.parsedCnic),
                  ),
                ),
              ],
            ),
            Specimen(
              title: context.tr('Phone fields', 'فون نمبر کے خانے'),
              component: 'MmPhoneField',
              children: [
                MmPhoneField(
                  label: context.tr('Mobile number', 'موبائل نمبر'),
                  value: _phone,
                  required: true,
                  onChanged: (value) => setState(() => _phone = value),
                ),
                MmPhoneField(
                  label: context.tr('Emergency contact', 'ایمرجنسی رابطہ'),
                  value: _newPhone,
                  optional: true,
                  helper: context.tr(
                    'Pakistani mobile or landline.',
                    'پاکستانی موبائل یا لینڈ لائن۔',
                  ),
                  onChanged: (value) => setState(() => _newPhone = value),
                ),
                MmPhoneField(
                  label: context.tr('Office number', 'دفتر کا نمبر'),
                  enabled: false,
                  value: PhoneNumber.tryParse('042-35550123'),
                  onChanged: (_) {},
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
