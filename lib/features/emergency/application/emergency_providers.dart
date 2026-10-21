import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_providers.dart';
import '../../auth/application/auth_providers.dart';
import '../data/emergency_contact_cache.dart';
import '../data/emergency_contact_repository.dart';
import '../data/emergency_phone.dart';
import '../domain/emergency_contact.dart';
import 'emergency_alerter.dart';

final emergencyContactRepositoryProvider = Provider<EmergencyContactRepository>(
  (ref) => EmergencyContactRepository(ref.watch(supabaseClientProvider)),
);

final emergencyContactCacheProvider = Provider<EmergencyContactCache>((ref) => EmergencyContactCache());

final emergencyPhoneProvider = Provider<EmergencyPhone>((ref) => EmergencyPhone());

final emergencyAlerterProvider = Provider<EmergencyAlerter>(
  (ref) => EmergencyAlerter(ref.watch(emergencyPhoneProvider)),
);

/// Zo lang wachten we op de server; daarna (of offline) de kopie op de gsm.
const _fetchTimeout = Duration(seconds: 5);

/// De eigen noodcontacten. Van de server, met een kopie op de gsm als
/// terugval: een SOS zonder internet moet ze toch kunnen sms'en.
final myEmergencyContactsProvider = FutureProvider<List<EmergencyContact>>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return const [];
  final cache = ref.watch(emergencyContactCacheProvider);
  try {
    final contacts = await ref.watch(emergencyContactRepositoryProvider).fetch(userId).timeout(_fetchTimeout);
    unawaited(cache.write(userId, contacts));
    return contacts;
  } catch (error) {
    debugPrint('Noodcontacten ophalen mislukt, de kopie op de gsm wordt gebruikt: $error');
    return cache.read(userId);
  }
});
