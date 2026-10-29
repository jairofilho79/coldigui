import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/dio_provider.dart';
import '../datasources/social_remote_datasource.dart';

final socialRemoteDatasourceProvider = Provider<SocialRemoteDatasource>((ref) {
  return SocialRemoteDatasource(ref.watch(dioProvider));
});
