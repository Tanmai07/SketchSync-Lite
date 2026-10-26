import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../dashboard/providers/board_provider.dart';
import '../providers/invitation_provider.dart';

class InvitationsScreen extends ConsumerStatefulWidget {
  const InvitationsScreen({super.key});

  @override
  ConsumerState<InvitationsScreen> createState() => _InvitationsScreenState();
}

class _InvitationsScreenState extends ConsumerState<InvitationsScreen> {
  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.invalidate(myInvitationsProvider);
      ref.invalidate(boardsProvider);
    });
  }

  @override
  Widget build(BuildContext context) {
    final invitationsAsync = ref.watch(myInvitationsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Invitations'),
      ),
      body: invitationsAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(),
        ),
        error: (error, stack) => Center(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Text(
              'Failed to load invitations:\n\n$error',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Theme.of(context).colorScheme.error,
              ),
            ),
          ),
        ),
        data: (invitations) {
          if (invitations.isEmpty) {
            return const Center(
              child: Text('No invitations yet'),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: invitations.length,
            itemBuilder: (context, index) {
              final invitation = invitations[index];

              final boardTitle = invitation['board_title'] ?? 'Untitled Board';

              final inviterName = invitation['inviter_name'] ??
                  invitation['inviter_email'] ??
                  'Unknown user';

              final role = invitation['role'] ?? 'viewer';
              final status = invitation['status'] ?? 'pending';

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        boardTitle,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '$inviterName invited you as '
                        '${role.toString().toUpperCase()}',
                      ),
                      const SizedBox(height: 12),
                      if (status == 'pending')
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () async {
                                  try {
                                    await ref
                                        .read(
                                          invitationRepositoryProvider,
                                        )
                                        .acceptInvitation(
                                          invitation['id'],
                                        );

                                    ref.invalidate(
                                      myInvitationsProvider,
                                    );
                                  } catch (e) {
                                    if (!context.mounted) return;

                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'Failed to accept invitation: $e',
                                        ),
                                      ),
                                    );
                                  }
                                },
                                child: const Text('Accept'),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () async {
                                  try {
                                    await ref
                                        .read(
                                          invitationRepositoryProvider,
                                        )
                                        .declineInvitation(
                                          invitation['id'],
                                        );

                                    ref.invalidate(
                                      myInvitationsProvider,
                                    );
                                  } catch (e) {
                                    if (!context.mounted) return;

                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'Failed to decline invitation: $e',
                                        ),
                                      ),
                                    );
                                  }
                                },
                                child: const Text('Decline'),
                              ),
                            ),
                          ],
                        )
                      else
                        Text(
                          'Status: ${status.toString().toUpperCase()}',
                        ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
