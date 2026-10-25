import 'package:supabase_flutter/supabase_flutter.dart';

class WhiteboardRepository {
  final SupabaseClient _supabase;

  WhiteboardRepository(this._supabase);

  Future<String> createStickyNote({
    required String boardId,
    required double x,
    required double y,
    required String text,
  }) async {
    final user = _supabase.auth.currentUser;

    if (user == null) {
      throw Exception('User is not logged in.');
    }

    final response = await _supabase
        .from('board_objects')
        .insert({
          'board_id': boardId,
          'type': 'sticky_note',
          'data': {
            'x': x,
            'y': y,
            'text': text,
          },
          'created_by': user.id,
        })
        .select('id')
        .single();

    return response['id'] as String;
  }

  Future<List<Map<String, dynamic>>> getStickyNotes({
    required String boardId,
  }) async {
    final response = await _supabase
        .from('board_objects')
        .select('id, data')
        .eq('board_id', boardId)
        .eq('type', 'sticky_note')
        .order('created_at');

    return List<Map<String, dynamic>>.from(response);
  }

  Future<void> deleteStickyNote({
    required String objectId,
  }) async {
    await _supabase.from('board_objects').delete().eq('id', objectId);
  }

  Future<void> updateStickyNotePosition({
    required String objectId,
    required double x,
    required double y,
  }) async {
    final existing = await _supabase
        .from('board_objects')
        .select('data')
        .eq('id', objectId)
        .single();

    final data = Map<String, dynamic>.from(
      existing['data'] as Map,
    );

    data['x'] = x;
    data['y'] = y;

    await _supabase.from('board_objects').update({
      'data': data,
    }).eq('id', objectId);
  }

  Future<void> updateStickyNoteText({
    required String objectId,
    required String text,
  }) async {
    final existing = await _supabase
        .from('board_objects')
        .select('data')
        .eq('id', objectId)
        .single();

    final data = Map<String, dynamic>.from(
      existing['data'] as Map,
    );

    data['text'] = text;

    await _supabase.from('board_objects').update({
      'data': data,
    }).eq('id', objectId);
  }
}
