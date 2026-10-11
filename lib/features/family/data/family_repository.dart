import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/family.dart';
import '../domain/family_member.dart';

class FamilyRepository {
  FamilyRepository(this._client);

  final SupabaseClient _client;

  /// De familie van de ingelogde gebruiker, of null als die er nog geen heeft.
  Future<Family?> fetchMyFamily(String userId) async {
    final row = await _client
        .from('family_members')
        .select('families(id, name, invite_code)')
        .eq('user_id', userId)
        .order('joined_at')
        .limit(1)
        .maybeSingle();

    final family = row?['families'] as Map<String, dynamic>?;
    return family == null ? null : Family.fromJson(family);
  }

  Future<Family> createFamily(String name) async {
    final row = await _client.rpc('create_family', params: {'family_name': name});
    return Family.fromJson(row as Map<String, dynamic>);
  }

  Future<Family> joinFamily(String inviteCode) async {
    final row = await _client.rpc('join_family', params: {'code': inviteCode});
    return Family.fromJson(row as Map<String, dynamic>);
  }

  /// De actuele uitnodigingscode en haar vervaldatum. Zonder migratie 017
  /// bestaat `invite_expires_at` nog niet: dan enkel de code.
  Future<Family> fetchInvite(String familyId) async {
    try {
      final row = await _client
          .from('families')
          .select('id, name, invite_code, invite_expires_at')
          .eq('id', familyId)
          .single();
      return Family.fromJson(row);
    } on PostgrestException catch (error) {
      if (error.code != '42703') rethrow;
      final row = await _client.from('families').select('id, name, invite_code').eq('id', familyId).single();
      return Family.fromJson(row);
    }
  }

  /// Nieuwe code, weer 7 dagen geldig (enkel de beheerder; migratie 017).
  Future<Family> rotateInviteCode(String familyId) async {
    final row = await _client.rpc('rotate_invite_code', params: {'fid': familyId});
    return Family.fromJson(row as Map<String, dynamic>);
  }

  /// Haalt [userId] uit het gezin en van de kaart, en vernieuwt de code
  /// (enkel de beheerder; migratie 017).
  Future<void> removeMember(String familyId, String userId) async {
    await _client.rpc('remove_member', params: {'fid': familyId, 'member': userId});
  }

  /// Draagt het beheer over aan [userId]; de huidige beheerder wordt gewoon
  /// gezinslid (enkel de beheerder; migratie 018).
  Future<void> transferOwnership(String familyId, String userId) async {
    await _client.rpc('transfer_ownership', params: {'fid': familyId, 'new_owner': userId});
  }

  /// De ingelogde gebruiker verlaat de familie.
  Future<void> leaveFamily(String userId, String familyId) {
    return _client.from('family_members').delete().eq('user_id', userId).eq('family_id', familyId);
  }

  Future<List<FamilyMember>> fetchMembers(String familyId) async {
    final rows = await _client
        .from('family_members')
        .select('user_id, role, joined_at, profiles(display_name, color_index, phone)')
        .eq('family_id', familyId)
        .order('joined_at');

    return [for (final (index, row) in rows.indexed) FamilyMember.fromJson(row, colorIndex: index)];
  }

  /// Realtime ledenlijst: herlaadt de (met profielen gejoinde) leden telkens de
  /// lidmaatschappen wijzigen. Vereist family_members in de realtime-publicatie
  /// (zie supabase/migrations/002_realtime_members.sql).
  Stream<List<FamilyMember>> watchMembers(String familyId) {
    return _client
        .from('family_members')
        .stream(primaryKey: ['family_id', 'user_id'])
        .eq('family_id', familyId)
        .asyncMap((_) => fetchMembers(familyId));
  }
}
