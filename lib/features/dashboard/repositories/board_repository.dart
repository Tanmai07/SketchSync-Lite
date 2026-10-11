import 'package:supabase_flutter/supabase_flutter.dart';

class BoardRepository {
  final SupabaseClient supabase;

  BoardRepository(this.supabase);

  // ============================================================
  // GET BOARDS
  // ============================================================

  Future<List<Map<String, dynamic>>> getBoards() async {
    final user = supabase.auth.currentUser;

    if (user == null) {
      throw Exception('User is not logged in.');
    }

    final response =
        await supabase.from('boards').select().eq('owner_id', user.id).order(
              'updated_at',
              ascending: false,
            );

    return List<Map<String, dynamic>>.from(response);
  }

  // ============================================================
  // CREATE BOARD
  // ============================================================

  Future<Map<String, dynamic>> createBoard(String title) async {
    final user = supabase.auth.currentUser;

    if (user == null) {
      throw Exception('You must be logged in to create a board.');
    }

    final cleanTitle = title.trim();

    if (cleanTitle.isEmpty) {
      throw Exception('Board name cannot be empty.');
    }

    // ----------------------------------------------------------
    // STEP 1: Create board
    // ----------------------------------------------------------

    final boardResponse = await supabase
        .from('boards')
        .insert({
          'title': cleanTitle,
          'owner_id': user.id,
        })
        .select()
        .single();

    final boardId = boardResponse['id'].toString();

    try {
      // --------------------------------------------------------
      // STEP 2: Add creator as owner
      // --------------------------------------------------------

      await supabase.from('board_members').insert({
        'board_id': boardId,
        'user_id': user.id,
        'role': 'owner',
      });
    } catch (e) {
      // --------------------------------------------------------
      // STEP 3: Cleanup if member creation fails
      // --------------------------------------------------------

      try {
        await supabase.from('boards').delete().eq('id', boardId);
      } catch (_) {}

      rethrow;
    }

    return Map<String, dynamic>.from(boardResponse);
  }

  // ============================================================
  // DELETE BOARD
  // ============================================================

  Future<void> deleteBoard(String boardId) async {
    await supabase.from('boards').delete().eq('id', boardId);
  }
}
