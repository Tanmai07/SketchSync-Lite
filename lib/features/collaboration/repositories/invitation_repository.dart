import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';

class InvitationRepository {
  final SupabaseClient _supabase;

  InvitationRepository(this._supabase);

  // Get invitations received by the current user.
/*  Future<List<Map<String, dynamic>>> getMyInvitations() async {
    final user = _supabase.auth.currentUser;

    if (user == null) {
      throw Exception('User is not logged in');
    }

    final response = await _supabase
        .from('board_invitations')
        .select('''
          id,
          board_id,
          invited_user_id,
          invited_by,
          role,
          status,
          created_at,
          expires_at,
          accepted_at,
          boards (
            id,
            title
          ),
          profiles!board_invitations_invited_by_fkey (
            id,
            name,
            email
          )
        ''')
        .eq('invited_user_id', user.id)
        .order('created_at', ascending: false);

    return List<Map<String, dynamic>>.from(response);
  }*/
  Future<List<Map<String, dynamic>>> getMyInvitations() async {
    final user = _supabase.auth.currentUser;

    if (user == null) {
      throw Exception('User is not logged in');
    }

    debugPrint('Current user: ${user.id}');
    debugPrint('Loading invitations...');

    try {
      final response = await _supabase.rpc(
        'get_my_board_invitations',
      );

      debugPrint('Invitation RPC response: $response');

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Invitation RPC ERROR: $e');
      rethrow;
    }
  }

  // Accept an invitation.
  Future<void> acceptInvitation(String invitationId) async {
    await _supabase.rpc(
      'accept_board_invitation',
      params: {
        'invitation_id': invitationId,
      },
    );
  }

  // Decline an invitation.
  Future<void> declineInvitation(String invitationId) async {
    await _supabase.rpc(
      'decline_board_invitation',
      params: {
        'invitation_id': invitationId,
      },
    );
  }

  Future<void> createInvitation({
    required String boardId,
    required String invitedUserId,
    required String role,
  }) async {
    final user = _supabase.auth.currentUser;

    if (user == null) {
      throw Exception('User is not logged in');
    }

    await _supabase.from('board_invitations').insert({
      'board_id': boardId,
      'invited_user_id': invitedUserId,
      'invited_by': user.id,
      'role': role,
    });
  }

  Future<void> inviteUserByEmail({
    required String boardId,
    required String email,
    required String role,
  }) async {
    await _supabase.rpc(
      'create_board_invitation',
      params: {
        'target_board_id': boardId,
        'target_email': email.trim(),
        'target_role': role,
      },
    );
  }
}
