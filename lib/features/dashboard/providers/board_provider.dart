import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/auth_provider.dart';
import '../repositories/board_repository.dart';

final boardRepositoryProvider = Provider<BoardRepository>((ref) {
  return BoardRepository(
    ref.watch(supabaseAuthProvider),
  );
});

final boardsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final authState = ref.watch(authStateProvider);

  if (authState.isLoading) {
    return [];
  }

  if (authState.hasError) {
    throw authState.error!;
  }

  final user = authState.value?.session?.user;

  if (user == null) {
    return [];
  }

  final repository = ref.watch(boardRepositoryProvider);

  return repository.getBoards();
});
