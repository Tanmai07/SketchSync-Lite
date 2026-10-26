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

    // Get boards owned by the current user.
    final ownedResponse = await supabase
        .from('boards')
        .select()
        .eq('owner_id', user.id)
        .order('updated_at', ascending: false);

    final ownedBoards = List<Map<String, dynamic>>.from(ownedResponse);

    // Get board IDs where the current user is a member.
    final memberResponse = await supabase
        .from('board_members')
        .select('board_id')
        .eq('user_id', user.id);

    final memberBoardIds =
        memberResponse.map((row) => row['board_id'].toString()).toSet();

    if (memberBoardIds.isEmpty) {
      return ownedBoards;
    }

    // Get the shared boards.
    final sharedResponse = await supabase
        .from('boards')
        .select()
        .inFilter('id', memberBoardIds.toList())
        .order('updated_at', ascending: false);

    final sharedBoards = List<Map<String, dynamic>>.from(sharedResponse);

    // Combine owned + shared boards without duplicates.
    final boardsById = <String, Map<String, dynamic>>{};

    for (final board in ownedBoards) {
      boardsById[board['id'].toString()] = board;
    }

    for (final board in sharedBoards) {
      boardsById[board['id'].toString()] = board;
    }

    return boardsById.values.toList();
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
