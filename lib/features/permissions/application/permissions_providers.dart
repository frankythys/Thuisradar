import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../location/application/location_providers.dart';
import 'permission_service.dart';

final permissionServiceProvider = Provider<PermissionService>(
  (ref) => PermissionService(ref.watch(deviceLocationSourceProvider)),
);
