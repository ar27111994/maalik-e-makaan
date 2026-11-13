import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maalik_e_makaan/src/auth/auth_repository.dart';
import 'package:maalik_e_makaan/src/config/app_config.dart';
import 'package:maalik_e_makaan/src/core/external_links.dart';
import 'package:maalik_e_makaan/src/data/cache/swr_cache.dart';
import 'package:maalik_e_makaan/src/data/providers.dart';
import 'package:maalik_e_makaan/src/features/account/data/account_repository.dart';
import 'package:maalik_e_makaan/src/features/account/data/profile_repository.dart';
import 'package:maalik_e_makaan/src/features/account/data/residence_repository.dart';
import 'package:maalik_e_makaan/src/features/documents/data/document_files.dart';
import 'package:maalik_e_makaan/src/features/documents/data/document_repository.dart';
import 'package:maalik_e_makaan/src/features/leases/data/lease_repository.dart';
import 'package:maalik_e_makaan/src/features/portfolios/data/portfolio_repository.dart';
import 'package:maalik_e_makaan/src/features/properties/data/property_repository.dart';
import 'package:maalik_e_makaan/src/features/team/data/team_repository.dart';
import 'package:maalik_e_makaan/src/features/tenants/data/tenant_repository.dart';

import '../../support/fakes.dart';
import '../../support/supabase.dart';

void main() {
  test('the repositories are the Supabase ones over the shared client', () {
    final supabase = MockSupabase((_) async => jsonResponse(null));
    final container = ProviderContainer.test(
      overrides: [
        supabaseClientProvider.overrideWithValue(supabase.client),
        swrCacheProvider.overrideWithValue(SwrCache(MemoryStore())),
        appConfigProvider.overrideWithValue(
          AppConfig.parse({
            'SUPABASE_URL': supabaseUrl,
            'SUPABASE_PUBLISHABLE_KEY': 'sb_publishable_test',
            'APP_URL': 'https://app.example.pk',
          }),
        ),
      ],
    );
    expect(
      container.read(authRepositoryProvider),
      isA<SupabaseAuthRepository>(),
    );
    expect(
      container.read(profileRepositoryProvider),
      isA<SupabaseProfileRepository>(),
    );
    expect(
      container.read(residenceRepositoryProvider),
      isA<SupabaseResidenceRepository>(),
    );
    expect(
      container.read(portfolioRepositoryProvider),
      isA<SupabasePortfolioRepository>(),
    );
    expect(
      container.read(accountRepositoryProvider),
      isA<SupabaseAccountRepository>(),
    );
    expect(
      container.read(teamRepositoryProvider),
      isA<SupabaseTeamRepository>(),
    );
    expect(
      container.read(propertyRepositoryProvider),
      isA<SupabasePropertyRepository>(),
    );
    expect(
      container.read(tenantRepositoryProvider),
      isA<SupabaseTenantRepository>(),
    );
    expect(
      container.read(leaseRepositoryProvider),
      isA<SupabaseLeaseRepository>(),
    );
    expect(
      container.read(documentRepositoryProvider),
      isA<SupabaseDocumentRepository>(),
    );
    expect(container.read(documentPickerProvider), isA<PluginDocumentPicker>());
    expect(container.read(filePreparerProvider), prepareFile);
    expect(container.read(linkOpenerProvider), openExternally);
    expect(
      whatsAppLink('hi', phoneDigits: '923001234567').toString(),
      'https://wa.me/923001234567?text=hi',
    );
  });
}
