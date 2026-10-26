import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/invitation_provider.dart';

class InvitationsScreen extends ConsumerWidget {
  const InvitationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
          child: Text(
            'Failed to load invitations',
            style: TextStyle(
              color: Theme.of(context).colorScheme.error,
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

              final board = invitation['boards'];
              final inviter = invitation['profiles'];

              final boardTitle = board?['title'] ?? 'Untitled Board';

              final inviterName =
                  inviter?['name'] ?? inviter?['email'] ?? 'Unknown user';

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
                        '$inviterName invited you as ${role.toString().toUpperCase()}',
                      ),
                      const SizedBox(height: 12),
                      if (status == 'pending')
                        Row(
                          children: [
                            ElevatedButton(
                              onPressed: () async {
                                try {
                                  await ref
                                      .read(invitationRepositoryProvider)
                                      .acceptInvitation(
                                        invitation['id'],
                                      );

                                  ref.invalidate(myInvitationsProvider);
                                } catch (e) {
                                  if (!context.mounted) return;

                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                          'Failed to accept invitation: $e'),
                                    ),
                                  );
                                }
                              },
                              child: const Text('Accept'),
                            ),
                            const SizedBox(width: 10),
                            OutlinedButton(
                              onPressed: () async {
                                try {
                                  await ref
                                      .read(invitationRepositoryProvider)
                                      .declineInvitation(
                                        invitation['id'],
                                      );

                                  ref.invalidate(myInvitationsProvider);
                                } catch (e) {
                                  if (!context.mounted) return;

                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                          'Failed to decline invitation: $e'),
                                    ),
                                  );
                                }
                              },
                              child: const Text('Decline'),
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
