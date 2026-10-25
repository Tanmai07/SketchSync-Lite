import 'package:supabase_flutter/supabase_flutter.dart';

class WhiteboardRepository {
  final SupabaseClient _supabase;

  WhiteboardRepository(this._supabase);

  Future<void> createStickyNote({
    required String boardId,
    required double x,
    required double y,
    required String text,
  }) async {
    final user = _supabase.auth.currentUser;

    if (user == null) {
      throw Exception('User is not logged in.');
    }

    await _supabase.from('board_objects').insert({
      'board_id': boardId,
      'type': 'sticky_note',
      'data': {
        'x': x,
        'y': y,
        'text': text,
      },
      'created_by': user.id,
    });
  }
}
