import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maalik_e_makaan/src/core/failure.dart';
import 'package:maalik_e_makaan/src/data/paging.dart';
import 'package:maalik_e_makaan/src/data/providers.dart';
import 'package:maalik_e_makaan/src/data/rows.dart';
import 'package:maalik_e_makaan/src/features/tenants/data/tenant.dart';
import 'package:mm_core/mm_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Tenants. Every method throws [AppFailure].
///
/// Owners and managers add, edit and archive; only owners delete, and only
/// a tenant no tenancy refers to (`still_in_use`).
abstract interface class TenantRepository {
  /// A page of [portfolioId]'s tenants, oldest first, archived or not, and
  /// only those whose name, phone or CNIC contains [search] when given.
  Future<Paged<Tenant>> tenants(
    String portfolioId, {
    required bool archived,
    String search = '',
    PageCursor? after,
  });

  Future<Tenant> tenant(String tenantId);

  /// Other tenants in use in [portfolioId] with [cnic] or [phone] (TEN-02),
  /// not counting [exceptId].
  Future<List<TenantMatch>> matches(
    String portfolioId, {
    Cnic? cnic,
    PhoneNumber? phone,
    String? exceptId,
  });

  /// Adds [tenant] under the id chosen for this attempt. Refusals:
  /// `duplicate_cnic`, `constraint_violation`.
  Future<Tenant> createTenant(String portfolioId, Tenant tenant);

  Future<Tenant> updateTenant(Tenant tenant);

  Future<Tenant> archiveTenant(String tenantId, {required bool archived});

  /// Deletes a tenant added by mistake.
  Future<void> deleteTenant(String tenantId);
}

/// What a search typed by a person becomes in PostgREST's `or` filter:
/// the name part without the characters its syntax reserves, and the
/// digits (Urdu digits read too, a leading 0 of a phone number dropped, as
/// numbers are stored from +92).
({String text, String digits}) searchTerms(String search) {
  final text = sanitizeSingleLine(
    search,
    maxLength: 60,
  ).replaceAll(RegExp(r'[,()*%"\\:.]'), ' ').trim();
  var digits = digitsOnly(normalizeDigits(search));
  if (digits.startsWith('0')) digits = digits.substring(1);
  return (text: text, digits: digits.length < 3 ? '' : digits);
}

/// [TenantRepository] over `tenants`.
final class SupabaseTenantRepository implements TenantRepository {
  new(this._client, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final SupabaseClient _client;
  final DateTime Function() _clock;

  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on PostgrestException catch (error) {
      if (error.code == '23505') throw const RejectedFailure('duplicate_cnic');
      if (error.code == '23503') throw const RejectedFailure('still_in_use');
      throw AppFailure.from(error);
    } on Object catch (error) {
      throw AppFailure.from(error);
    }
  }

  @override
  Future<Paged<Tenant>> tenants(
    String portfolioId, {
    required bool archived,
    String search = '',
    PageCursor? after,
  }) => _guard(() async {
    var query = _client
        .from('tenants')
        .select(Tenant.columns)
        .eq('portfolio_id', portfolioId);
    query = archived
        ? query.not('archived_at', 'is', null)
        : query.isFilter('archived_at', null);
    final terms = searchTerms(search);
    if (terms.text.isNotEmpty || terms.digits.isNotEmpty) {
      query = query.or(
        [
          if (terms.text.isNotEmpty) 'full_name.ilike.*${terms.text}*',
          if (terms.digits.isNotEmpty) ...[
            'phone.ilike.*${terms.digits}*',
            'cnic.ilike.*${terms.digits}*',
          ],
        ].join(','),
      );
    }
    final rows = await query
        .after(after)
        .order('created_at', ascending: true)
        .order('id', ascending: true)
        .limit(pageSize);
    return Paged.page(rows.map(Tenant.fromRow).toList(), (t) => t.cursor);
  });

  @override
  Future<Tenant> tenant(String tenantId) => _guard(() async {
    final row = await _client
        .from('tenants')
        .select(Tenant.columns)
        .eq('id', tenantId)
        .single();
    return Tenant.fromRow(row);
  });

  @override
  Future<List<TenantMatch>> matches(
    String portfolioId, {
    Cnic? cnic,
    PhoneNumber? phone,
    String? exceptId,
  }) => _guard(() async {
    if (cnic == null && phone == null) return const [];
    var query = _client
        .from('tenants')
        .select('id,full_name')
        .eq('portfolio_id', portfolioId)
        .isFilter('archived_at', null)
        .or(
          [
            if (cnic != null) 'cnic.eq.${cnic.digits}',
            if (phone != null) 'phone.eq."${phone.e164}"',
          ].join(','),
        );
    if (exceptId != null) query = query.neq('id', exceptId);
    final rows = await query.limit(5);
    return [
      for (final row in rows)
        (
          id: JsonRow.of(row).string('id'),
          fullName: JsonRow.of(row).string('full_name'),
        ),
    ];
  });

  @override
  Future<Tenant> createTenant(String portfolioId, Tenant tenant) =>
      _guard(() async {
        try {
          final row = await _client
              .from('tenants')
              .insert({
                'id': tenant.id,
                'portfolio_id': portfolioId,
                ...tenant.toWrite(),
              })
              .select(Tenant.columns)
              .single();
          return Tenant.fromRow(row);
        } on PostgrestException catch (error) {
          if (error.code != '23505') rethrow;
          // A retry of an insert that reached the server returns the tenant
          // it added; otherwise the CNIC is someone else's.
          final existing = await _client
              .from('tenants')
              .select(Tenant.columns)
              .eq('id', tenant.id)
              .maybeSingle();
          if (existing == null) rethrow;
          return Tenant.fromRow(existing);
        }
      });

  Future<Tenant> _update(String tenantId, Map<String, Object?> values) async {
    final row = await _client
        .from('tenants')
        .update(values)
        .eq('id', tenantId)
        .select(Tenant.columns)
        .single();
    return Tenant.fromRow(row);
  }

  @override
  Future<Tenant> updateTenant(Tenant tenant) =>
      _guard(() => _update(tenant.id, tenant.toWrite()));

  @override
  Future<Tenant> archiveTenant(String tenantId, {required bool archived}) =>
      _guard(
        () => _update(tenantId, {
          'archived_at': archived ? _clock().toUtc().toIso8601String() : null,
        }),
      );

  @override
  Future<void> deleteTenant(String tenantId) => _guard(() async {
    final deleted = await _client
        .from('tenants')
        .delete()
        .eq('id', tenantId)
        .select('id');
    if (deleted.isEmpty) throw const Forbidden();
  });
}

final tenantRepositoryProvider = Provider<TenantRepository>(
  (ref) => SupabaseTenantRepository(ref.watch(supabaseClientProvider)),
);
