import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:maalik_e_makaan/src/core/failure.dart';
import 'package:maalik_e_makaan/src/core/swr_notifier.dart';
import 'package:maalik_e_makaan/src/data/cache/swr_cache.dart';
import 'package:maalik_e_makaan/src/data/paging.dart';
import 'package:maalik_e_makaan/src/features/tenants/data/tenant.dart';
import 'package:maalik_e_makaan/src/features/tenants/data/tenant_repository.dart';
import 'package:mm_core/mm_core.dart';

/// Which tenants a list shows: a portfolio's in use or archived, and what
/// was searched for.
typedef TenantList = ({String portfolioId, bool archived, String search});

/// A list of tenants, the saved copy first, 50 at a time.
final StreamNotifierProviderFamily<
  TenantsController,
  Snapshot<Paged<Tenant>>,
  TenantList
>
tenantsProvider = StreamNotifierProvider.autoDispose
    .family<TenantsController, Snapshot<Paged<Tenant>>, TenantList>(
      TenantsController.new,
    );

/// Reads a list of tenants and adds new ones. Commands throw [AppFailure].
final class TenantsController extends SwrNotifier<Paged<Tenant>> {
  new(this.list);

  final TenantList list;

  TenantRepository get _repository => ref.read(tenantRepositoryProvider);

  @override
  String get query =>
      'tenants.${list.portfolioId}.${list.archived ? 'archived' : 'active'}'
      '.${list.search.trim().toLowerCase()}';

  @override
  Stream<Snapshot<Paged<Tenant>>> build() {
    ref.watch(tenantRepositoryProvider);
    return super.build();
  }

  @override
  Future<Paged<Tenant>> fetch() => _repository.tenants(
    list.portfolioId,
    archived: list.archived,
    search: list.search,
  );

  @override
  Paged<Tenant> decode(Object? json) => Paged.fromJson(json, Tenant.fromRow);

  @override
  Object? encode(Paged<Tenant> value) => value.toJson((t) => t.toRow());

  Future<void> loadMore() async {
    final current = state.value?.value;
    final next = current?.next;
    if (current == null || next == null) return;
    final more = await _repository.tenants(
      list.portfolioId,
      archived: list.archived,
      search: list.search,
      after: next,
    );
    await show(current.followedBy(more));
  }

  /// Other tenants in use with [cnic] or [phone], to warn before saving.
  Future<List<TenantMatch>> matches({
    Cnic? cnic,
    PhoneNumber? phone,
    String? exceptId,
  }) => _repository.matches(
    list.portfolioId,
    cnic: cnic,
    phone: phone,
    exceptId: exceptId,
  );

  /// Adds [tenant] (its id names this attempt: keep it for retries).
  Future<Tenant> create(Tenant tenant) async {
    final created = await _repository.createTenant(list.portfolioId, tenant);
    ref.invalidate(tenantsProvider);
    return created;
  }
}

/// One tenant, the saved copy first.
final StreamNotifierProviderFamily<TenantController, Snapshot<Tenant>, String>
tenantProvider = StreamNotifierProvider.autoDispose
    .family<TenantController, Snapshot<Tenant>, String>(TenantController.new);

/// Reads a tenant and changes them. Commands throw [AppFailure].
final class TenantController extends SwrNotifier<Tenant> {
  new(this.tenantId);

  final String tenantId;

  TenantRepository get _repository => ref.read(tenantRepositoryProvider);

  @override
  String get query => 'tenant.$tenantId';

  @override
  Stream<Snapshot<Tenant>> build() {
    ref.watch(tenantRepositoryProvider);
    return super.build();
  }

  @override
  Future<Tenant> fetch() => _repository.tenant(tenantId);

  @override
  Tenant decode(Object? json) => Tenant.fromRow(json);

  @override
  Object? encode(Tenant value) => value.toRow();

  Future<Tenant> _saved(Tenant tenant) async {
    ref.invalidate(tenantsProvider);
    await show(tenant);
    return tenant;
  }

  Future<Tenant> save(Tenant tenant) async =>
      await _saved(await _repository.updateTenant(tenant));

  Future<Tenant> archive({required bool archived}) async => await _saved(
    await _repository.archiveTenant(tenantId, archived: archived),
  );

  Future<void> delete() async {
    await _repository.deleteTenant(tenantId);
    ref.invalidate(tenantsProvider);
  }
}
