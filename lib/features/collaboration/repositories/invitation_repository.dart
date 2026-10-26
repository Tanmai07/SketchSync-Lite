import 'package:supabase_flutter/supabase_flutter.dart';

class InvitationRepository {
  final SupabaseClient _supabase;

  InvitationRepository(this._supabase);

  // Get invitations received by the current user.
  Future<List<Map<String, dynamic>>> getMyInvitations() async {
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
}
