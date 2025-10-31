import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import '../models/user_model.dart';
import '../services/firestore_service.dart';
import '../services/friend_service.dart';

class NotificationsPage extends StatefulWidget {
  final UserModel currentUser;

  const NotificationsPage({
    super.key,
    required this.currentUser,
  });

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  final FirestoreService _firestoreService = FirestoreService();
  final FriendService _friendService = FriendService();

  String _getTimeAgo(Timestamp timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp.toDate());

    if (difference.inDays > 365) {
      return '${(difference.inDays / 365).floor()} years ago';
    } else if (difference.inDays > 30) {
      return '${(difference.inDays / 30).floor()} months ago';
    } else if (difference.inDays > 0) {
      return '${difference.inDays} days ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hours ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minutes ago';
    } else {
      return 'Just now';
    }
  }

  Future<void> _deleteNotification(String notificationId) async {
    try {
      await _firestoreService.deleteNotification(
          notificationId, widget.currentUser.uid);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting notification: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.notifications),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream:
            _firestoreService.getNotificationsStream(widget.currentUser.uid),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            print('Error in notifications stream: ${snapshot.error}');
            return Center(
              child: Text('Error loading notifications: ${snapshot.error}'),
            );
          }

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final notifications = snapshot.data!.docs
              .map((doc) => {
                    'id': doc.id,
                    ...doc.data() as Map<String, dynamic>,
                  })
              .toList();

          print('Number of notifications: ${notifications.length}');
          for (var notification in notifications) {
            print('Notification: $notification');
          }

          if (notifications.isEmpty) {
            return Center(
              child: Text(
                l10n.noNotifications,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            );
          }

          return ListView.builder(
            itemCount: notifications.length,
            itemBuilder: (context, index) {
              final notification = notifications[index];
              final notificationId = notification['id'] as String;
              final timestamp = notification['timestamp'] as Timestamp;
              final isRead = notification['read'] as bool? ?? false;

              return Card(
                margin: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: isRead
                        ? Theme.of(context).colorScheme.primary.withOpacity(0.5)
                        : Theme.of(context).colorScheme.primary,
                    child: Icon(
                      notification['type'] == 'friend_request'
                          ? Icons.person_add
                          : notification['type'] == 'association_invite'
                              ? Icons.group_add
                              : Icons.notifications,
                      color: Colors.white,
                    ),
                  ),
                  title: Text(notification['title'] ?? ''),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(notification['message'] ?? ''),
                      const SizedBox(height: 4),
                      Text(
                        _getTimeAgo(timestamp),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                  trailing:
                      _buildNotificationActions(notification, notificationId),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget? _buildNotificationActions(
      Map<String, dynamic> notification, String notificationId) {
    Widget? trailing;

    switch (notification['type']) {
      case 'friend_request':
        trailing = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.check, color: Colors.green),
              onPressed: () async {
                try {
                  await _friendService.acceptFriendRequest(
                    widget.currentUser.uid,
                    notification['senderId'],
                  );
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Friend request accepted'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error accepting friend request: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
            ),
            IconButton(
              icon: const Icon(Icons.close, color: Colors.red),
              onPressed: () async {
                try {
                  await _friendService.rejectFriendRequest(
                    widget.currentUser.uid,
                    notification['senderId'],
                  );
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Friend request rejected'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error rejecting friend request: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
            ),
          ],
        );
        break;
      case 'association_invite':
        trailing = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.check, color: Colors.green),
              onPressed: () async {
                try {
                  await _firestoreService.acceptAssociationInvite(
                    notification['associationId'],
                    widget.currentUser.uid,
                  );
                  await _deleteNotification(notificationId);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Association invite accepted'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error accepting invite: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
            ),
            IconButton(
              icon: const Icon(Icons.close, color: Colors.red),
              onPressed: () async {
                try {
                  await _firestoreService.rejectAssociationInvite(
                    notification['associationId'],
                    widget.currentUser.uid,
                  );
                  await _deleteNotification(notificationId);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Association invite rejected'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error rejecting invite: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
            ),
          ],
        );
        break;
      default:
        trailing = IconButton(
          icon: const Icon(Icons.delete_outline),
          onPressed: () => _deleteNotification(notificationId),
        );
    }

    return trailing;
  }
}
