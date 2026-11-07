import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';

import 'harness.dart';

/// A container over [app]'s fakes, without retries, disposed after the test.
ProviderContainer containerFor(TestApp app) =>
    ProviderContainer.test(overrides: app.overrides, retry: (_, _) => null);

/// Keeps [provider] alive for the test and returns its subscription.
ProviderSubscription<T> listen<T>(
  ProviderContainer container,
  ProviderListenable<T> provider,
) => container.listen(provider, (_, _) {});
