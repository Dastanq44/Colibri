import 'package:colibri/data/remote/supabase_client_provider.dart';
import 'package:colibri/features/auth/application/auth_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('auth providers report signed-out when backend is unconfigured', () async {
    final container = ProviderContainer(
      overrides: <Override>[
        supabaseClientProvider.overrideWithValue(null),
      ],
    );
    addTearDown(container.dispose);

    expect(container.read(currentUserProvider), isNull);
    expect(container.read(currentUserIdProvider), isNull);
    expect(container.read(isSignedInProvider), isFalse);
    expect(await container.read(authStateChangesProvider.future), isNull);
  });

  test('backendConfiguredProvider mirrors the data-layer configured flag', () {
    final unconfigured = ProviderContainer(
      overrides: <Override>[
        supabaseClientProvider.overrideWithValue(null),
      ],
    );
    addTearDown(unconfigured.dispose);
    expect(unconfigured.read(backendConfiguredProvider), isFalse);

    final configured = ProviderContainer(
      overrides: <Override>[
        supabaseConfiguredProvider.overrideWithValue(true),
      ],
    );
    addTearDown(configured.dispose);
    expect(configured.read(backendConfiguredProvider), isTrue);
  });
}
