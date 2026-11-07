import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maalik_e_makaan/src/auth/auth_repository.dart';
import 'package:maalik_e_makaan/src/config/app_config.dart';
import 'package:maalik_e_makaan/src/data/cache/swr_cache.dart';
import 'package:maalik_e_makaan/src/data/providers.dart';
import 'package:maalik_e_makaan/src/features/account/data/account_repository.dart';
import 'package:maalik_e_makaan/src/features/account/data/profile_repository.dart';
import 'package:maalik_e_makaan/src/features/portfolios/data/portfolio_repository.dart';

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
      container.read(portfolioRepositoryProvider),
      isA<SupabasePortfolioRepository>(),
    );
    expect(
      container.read(accountRepositoryProvider),
      isA<SupabaseAccountRepository>(),
    );
  });
}
