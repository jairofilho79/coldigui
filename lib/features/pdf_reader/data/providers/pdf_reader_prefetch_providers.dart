import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../catalog/presentation/providers/catalog_material_lookup_provider.dart';
import '../../../offline/data/providers/offline_providers.dart';
import '../../data/datasources/connectivity_network_connection_checker.dart';
import '../../data/policies/wifi_only_prefetch_network_policy.dart';
import '../../domain/ports/network_connection_checker.dart';
import '../../domain/ports/prefetch_network_policy.dart';
import '../../domain/usecases/prefetch_adjacent_carousel_pdfs.dart';

/// DI — [NetworkConnectionChecker] para política de prefetch.
final networkConnectionCheckerProvider = Provider<NetworkConnectionChecker>((
  ref,
) {
  return ConnectivityNetworkConnectionChecker();
});

/// DI — prefetch apenas em WiFi/Ethernet (sem dados móveis por padrão).
final prefetchNetworkPolicyProvider = Provider<PrefetchNetworkPolicy>((ref) {
  return WifiOnlyPrefetchNetworkPolicy(
    ref.watch(networkConnectionCheckerProvider),
  );
});

/// DI — [PrefetchAdjacentCarouselPdfs] (backlog #8).
final prefetchAdjacentCarouselPdfsProvider =
    Provider<PrefetchAdjacentCarouselPdfs>((ref) {
      return PrefetchAdjacentCarouselPdfs(
        validateAvailability: ref.watch(validatePdfAvailabilityProvider),
        resolvePdf: ref.watch(resolvePdfForReaderProvider),
        networkPolicy: ref.watch(prefetchNetworkPolicyProvider),
      );
    });

/// Resolve o louvor de um vizinho no prefetch — manifest, cache Coldigom e
/// alias legado, pelo mesmo lookup que o leitor usa (não só o manifest).
final prefetchLouvorResolverProvider = Provider<PrefetchLouvorResolver>((ref) {
  return ref.watch(catalogMaterialLookupProvider).louvor;
});
