import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../constants/feature_flags.dart';

/// Flags de feature do build atual ([FeatureFlags.fromEnvironment]) —
/// sobreescrevível em teste (`featureFlagsProvider.overrideWithValue(...)`).
final featureFlagsProvider = Provider<FeatureFlags>(
  (ref) => FeatureFlags.fromEnvironment(),
);
