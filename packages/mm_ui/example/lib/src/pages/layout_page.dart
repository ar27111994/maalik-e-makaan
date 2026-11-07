import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mm_core/mm_core.dart';
import 'package:mm_ui/mm_ui.dart';

import 'package:mm_ui_gallery/src/copy.dart';
import 'package:mm_ui_gallery/src/sample_data.dart';
import 'package:mm_ui_gallery/src/settings.dart';
import 'package:mm_ui_gallery/src/shell.dart';
import 'package:mm_ui_gallery/src/specimen.dart';

/// The app frame, pages, list and detail, grids, form sections, action
/// bars and tabs.
class LayoutPage extends StatefulWidget {
  const new({super.key});

  @override
  State<LayoutPage> createState() => _LayoutPageState();
}

class _LayoutPageState extends State<LayoutPage> {
  int? _tenant;
  Money? _rent = const Money.fromRupees(52000);
  PhoneNumber? _phone;
  CalendarDate? _start = CalendarDate(2026, 12, 1);

  @override
  Widget build(BuildContext context) {
    final size = MmWindowSize.of(context);
    final sizeName = switch (size) {
      MmWindowSize.compact => context.tr('compact (phone)', 'کمپیکٹ (فون)'),
      MmWindowSize.medium => context.tr(
        'medium (small tablet)',
        'درمیانہ (چھوٹا ٹیبلیٹ)',
      ),
      MmWindowSize.expanded => context.tr('expanded (tablet)', 'وسیع (ٹیبلیٹ)'),
      MmWindowSize.large => context.tr('large (desktop)', 'بڑا (ڈیسک ٹاپ)'),
    };
    final record = context.tr('Record payment', 'ادائیگی درج کریں');
    final draft = context.tr('Save draft', 'مسودہ محفوظ کریں');
    return FamilyPage(
      family: GalleryFamily.layout,
      body: SpecimenList(
        children: [
          Specimen(
            title: context.tr('App frame', 'ایپ کا ڈھانچہ'),
            component: 'MmAdaptiveScaffold · MmDestination',
            note: context.tr(
              'This gallery’s navigation: a bottom bar on phones, a rail '
                  'from 600 dp, labels beside the icons from 1200 dp. The '
                  'Feedback destination carries a badge of 3.',
              'اس گیلری کی نیویگیشن: فون پر نیچے کی بار، 600 ڈی پی سے سائیڈ '
                  'ریل، 1200 ڈی پی سے آئیکن کے ساتھ نام۔ اطلاعات پر 3 کا '
                  'نشان ہے۔',
            ),
            children: [
              Text(
                context.tr(
                  'This window is $sizeName.',
                  'یہ ونڈو $sizeName ہے۔',
                ),
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ],
          ),
          Specimen(
            title: context.tr('Page', 'صفحہ'),
            component: 'MmPage · MmActionBar',
            note: context.tr(
              'Every gallery page is an MmPage. Open a tenant’s page: a long '
                  'title moves under the buttons, and the main action sits '
                  'in a bar at the bottom.',
              'گیلری کا ہر صفحہ MmPage ہے۔ کرایہ دار کا صفحہ کھولیں: لمبا '
                  'عنوان بٹنوں کے نیچے آ جاتا ہے، اور مرکزی کام نیچے کی بار '
                  'میں ہوتا ہے۔',
            ),
            children: [
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: MmButton(
                  label: context.tr(
                    'Open tenant page',
                    'کرایہ دار کا صفحہ کھولیں',
                  ),
                  variant: MmButtonVariant.secondary,
                  icon: MmIcons.forward,
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (context) => const _TenantScreen(),
                    ),
                  ),
                ),
              ),
              StateLabel(
                label: context.tr(
                  'Action bar: main action and one alternative',
                  'ایکشن بار: مرکزی کام اور ایک متبادل',
                ),
                child: MmCard(
                  padding: EdgeInsets.zero,
                  child: MmActionBar(
                    primary: FilledButton(
                      onPressed: () => showPressed(context, record),
                      child: Text(record),
                    ),
                    secondary: OutlinedButton(
                      onPressed: () => showPressed(context, draft),
                      child: Text(draft),
                    ),
                  ),
                ),
              ),
            ],
          ),
          Specimen(
            title: context.tr('List and detail', 'فہرست اور تفصیل'),
            component: 'MmListDetail',
            note: context.tr(
              'One at a time on phones, side by side from 840 dp. Choose a '
                  'tenant.',
              'فون پر ایک وقت میں ایک، 840 ڈی پی سے ساتھ ساتھ۔ کوئی کرایہ دار '
                  'چنیں۔',
            ),
            children: [
              MmCard(
                padding: EdgeInsets.zero,
                child: SizedBox(
                  height: 420 * MediaQuery.textScalerOf(context).scale(1),
                  child: MmListDetail(
                    list: ListView(
                      children: [
                        for (final (index, tenant) in tenants.indexed)
                          MmListTile(
                            title: tenant.name.of(context),
                            subtitle: tenant.property.of(context),
                            leading: MmAvatar(name: tenant.name.of(context)),
                            selected: index == _tenant,
                            onTap: () => setState(() => _tenant = index),
                          ),
                      ],
                    ),
                    detail: _tenant == null
                        ? null
                        : _TenantDetail(
                            tenant: tenants[_tenant!],
                            onClose: () => setState(() => _tenant = null),
                          ),
                    emptyDetail: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(MmSpace.s4),
                        child: Text(
                          context.tr('Choose a tenant', 'کرایہ دار چنیں'),
                          style: Theme.of(context).textTheme.bodyLarge
                              ?.copyWith(color: context.mm.colors.inkMuted),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          Specimen(
            title: context.tr('Responsive grid', 'لچکدار گرڈ'),
            component: 'MmResponsiveGrid',
            note: context.tr(
              'As many equal columns as fit: one on a phone, more on wider '
                  'windows.',
              'جتنے برابر کالم سما سکیں: فون پر ایک، چوڑی ونڈو میں زیادہ۔',
            ),
            children: [
              MmResponsiveGrid(
                children: [
                  for (final tenant in tenants.take(4))
                    MmStatTile(
                      label: tenant.property.of(context),
                      value: MmAmount(
                        amount: tenant.rent,
                        size: MmAmountSize.large,
                      ),
                      caption: Text(tenant.name.of(context)),
                    ),
                ],
              ),
            ],
          ),
          Specimen(
            title: context.tr('Form sections', 'فارم کے حصے'),
            component: 'MmFormSection',
            note: context.tr(
              'Two sections of an “Add tenant” form.',
              'کرایہ دار شامل کرنے کے فارم کے دو حصے۔',
            ),
            children: [
              MmFormSection(
                title: context.tr('Tenant details', 'کرایہ دار کی تفصیل'),
                description: context.tr(
                  'As written on the tenant’s CNIC.',
                  'جیسا کرایہ دار کے شناختی کارڈ پر لکھا ہے۔',
                ),
                children: [
                  MmTextField(
                    label: context.tr('Full name', 'پورا نام'),
                    initialValue: tenants[4].name.of(context),
                    required: true,
                  ),
                  MmPhoneField(
                    label: context.tr('Mobile number', 'موبائل نمبر'),
                    value: _phone,
                    optional: true,
                    onChanged: (value) => setState(() => _phone = value),
                  ),
                ],
              ),
              MmFormSection(
                title: context.tr('Rent', 'کرایہ'),
                children: [
                  MmMoneyField(
                    label: context.tr('Monthly rent', 'ماہانہ کرایہ'),
                    value: _rent,
                    required: true,
                    onChanged: (value) => setState(() => _rent = value),
                  ),
                  MmDateField(
                    label: context.tr('First rent due', 'پہلا کرایہ واجب'),
                    value: _start,
                    firstDate: CalendarDate(2026, 1, 1),
                    lastDate: CalendarDate(2027, 12, 31),
                    required: true,
                    onChanged: (value) => setState(() => _start = value),
                  ),
                ],
              ),
            ],
          ),
          Specimen(
            title: context.tr('Tabs', 'ٹیبز'),
            component: 'MmTabs',
            note: context.tr(
              'The views of one screen.',
              'ایک اسکرین کے مختلف منظر۔',
            ),
            children: const [_TabsDemo()],
          ),
        ],
      ),
    );
  }
}

/// The detail pane of the list and detail specimen.
class _TenantDetail extends StatelessWidget {
  const new({required this.tenant, required this.onClose});

  final SampleTenant tenant;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.all(MmSpace.s4),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            MmIconButton(
              icon: MmIcons.back,
              tooltip: context.tr('Back to tenants', 'کرایہ داروں پر واپس'),
              onPressed: onClose,
            ),
            const SizedBox(width: MmSpace.s2),
            Expanded(
              child: Semantics(
                header: true,
                child: Text(
                  tenant.name.of(context),
                  style: context.mm.styleFor(
                    tenant.name.of(context),
                    Theme.of(context).textTheme.titleLarge!,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: MmSpace.s2),
        MmDetailRow(
          label: context.tr('Unit', 'یونٹ'),
          value: tenant.unit.of(context),
        ),
        MmDetailRow.amount(
          label: context.tr('Monthly rent', 'ماہانہ کرایہ'),
          amount: tenant.rent,
        ),
        MmDetailRow(
          label: context.tr('Status', 'حالت'),
          value: tenant.statusLabel.of(context),
          userData: false,
        ),
      ],
    ),
  );
}

/// A tenant's own screen, pushed over the gallery: a long title, app bar
/// actions, pull to refresh and an action bar.
class _TenantScreen extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) {
    final ayesha = tenants[1];
    final record = context.tr('Record payment', 'ادائیگی درج کریں');
    final remind = context.tr('Send reminder', 'یاد دہانی بھیجیں');
    final refresh = context.tr('Refresh', 'تازہ کریں');
    return MmPage(
      title: context.tr(
        'Ayesha Khan, House 12, DHA Phase 5',
        'عائشہ خان، مکان 12، ڈی ایچ اے فیز 5',
      ),
      actions: [
        MmIconButton(
          icon: MmIcons.refresh,
          tooltip: refresh,
          onPressed: () => showPressed(context, refresh),
        ),
        MmIconButton(
          icon: MmIcons.edit,
          tooltip: context.tr('Edit tenant', 'کرایہ دار میں ترمیم'),
          onPressed: () => showPressed(
            context,
            context.tr('Edit tenant', 'کرایہ دار میں ترمیم'),
          ),
        ),
      ],
      onRefresh: () => Future<void>.delayed(MmDuration.standard),
      bottomBar: MmActionBar(
        primary: FilledButton(
          onPressed: () => showPressed(context, record),
          child: Text(record),
        ),
        secondary: OutlinedButton(
          onPressed: () => showPressed(context, remind),
          child: Text(remind),
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: MmStatusBadge(
              status: ayesha.status,
              label: ayesha.statusLabel.of(context),
            ),
          ),
          const SizedBox(height: MmSpace.s4),
          MmCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                MmDetailRow(
                  label: context.tr('Phone', 'فون'),
                  value: ayesha.phone,
                ),
                MmDetailRow(
                  label: context.tr('CNIC', 'شناختی کارڈ'),
                  value: ayesha.parsedCnic.masked,
                  semanticValue: context.tr(
                    'CNIC starting 35201, ending 4',
                    'شناختی کارڈ 35201 سے شروع، 4 پر ختم',
                  ),
                ),
                MmDetailRow.amount(
                  label: context.tr('Monthly rent', 'ماہانہ کرایہ'),
                  amount: ayesha.rent,
                ),
                MmDetailRow.amount(
                  label: context.tr('Total due', 'کل واجب'),
                  amount: const Money.fromRupees(127500),
                  emphasized: true,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Tabs over the views of a tenant's record.
class _TabsDemo extends StatefulWidget {
  const new();

  @override
  State<_TabsDemo> createState() => _TabsDemoState();
}

class _TabsDemoState extends State<_TabsDemo>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 3, vsync: this);

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ali = tenants.first;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MmTabs(
          controller: _tabs,
          labels: [
            context.tr('Dues', 'واجبات'),
            context.tr('Payments', 'ادائیگیاں'),
            context.tr('Documents', 'دستاویزات'),
          ],
        ),
        const SizedBox(height: MmSpace.s3),
        ListenableBuilder(
          listenable: _tabs,
          builder: (context, _) => switch (_tabs.index) {
            0 => MmDetailRow.amount(
              label: context.tr('November rent', 'نومبر کا کرایہ'),
              amount: ali.rent,
            ),
            1 => MmDetailRow.amount(
              label: dateLabel(context, CalendarDate(2026, 11, 5)),
              amount: ali.rent,
            ),
            _ => MmDetailRow(
              label: context.tr('Lease', 'کرایہ نامہ'),
              value: context.tr('Signed 1 Jul 2026', 'دستخط 1 جولائی 2026'),
              userData: false,
            ),
          },
        ),
      ],
    );
  }
}
