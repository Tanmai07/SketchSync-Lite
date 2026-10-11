import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../repositories/board_repository.dart';

final boardRepositoryProvider = Provider<BoardRepository>((ref) {
  return BoardRepository(
    Supabase.instance.client,
  );
});

final boardsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final repository = ref.watch(boardRepositoryProvider);

  return repository.getBoards();
});
