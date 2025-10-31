import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import '../models/user_model.dart';
import '../services/friend_service.dart';

class UserDetailsDialog extends StatelessWidget {
  final UserModel currentUser;
  final UserModel targetUser;
  final String associationId;
  final bool isAdmin;
  final FriendService _friendService = FriendService();

  UserDetailsDialog({
    super.key,
    required this.currentUser,
    required this.targetUser,
    required this.associationId,
    required this.isAdmin,
  });

  Future<void> _makeAdmin(BuildContext context) async {
    try {
      await _friendService.makeAdmin(
        associationId,
        currentUser.uid,
        targetUser.uid,
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('User is now an admin')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    }
  }

  Future<void> _removeAdmin(BuildContext context) async {
    try {
      await _friendService.removeAdmin(
        associationId,
        currentUser.uid,
        targetUser.uid,
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Admin privileges removed')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    }
  }

  Future<void> _sendFriendRequest(BuildContext context) async {
    try {
      print(
          'Sending friend request from ${currentUser.uid} to ${targetUser.uid}');
      await _friendService.sendFriendRequest(
        currentUser.uid,
        targetUser.uid,
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Friend request sent')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      print('Error sending friend request: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    }
  }

  Future<void> _acceptFriendRequest(BuildContext context) async {
    try {
      print('Accepting friend request from ${targetUser.uid}');
      await _friendService.acceptFriendRequest(
        currentUser.uid,
        targetUser.uid,
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Friend request accepted')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      print('Error accepting friend request: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isTargetAdmin = targetUser.isAdmin(associationId);
    final isFriend = currentUser.friends.contains(targetUser.uid);
    final hasPendingRequest =
        currentUser.pendingFriendRequests.contains(targetUser.uid);
    final hasSentRequest =
        currentUser.sentFriendRequests.contains(targetUser.uid);

    print('Building UserDetailsDialog');
    print('Current user ID: ${currentUser.uid}');
    print('Target user ID: ${targetUser.uid}');
    print('Is friend: $isFriend');
    print('Has pending request: $hasPendingRequest');
    print('Has sent request: $hasSentRequest');

    return AlertDialog(
      title: Text(targetUser.fullName),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              leading: const Icon(Icons.person),
              title: const Text('Username'),
              subtitle: Text(targetUser.username),
            ),
            ListTile(
              leading: const Icon(Icons.phone),
              title: const Text('Phone Number'),
              subtitle: Text(targetUser.phoneNumber ?? 'Not available'),
            ),
            ListTile(
              leading: const Icon(Icons.calendar_today),
              title: const Text('Member Since'),
              subtitle: Text(targetUser.createdAt.toString().split(' ')[0]),
            ),
            if (isAdmin && !isTargetAdmin && currentUser.uid != targetUser.uid)
              ListTile(
                leading: const Icon(Icons.admin_panel_settings),
                title: const Text('Make Admin'),
                onTap: () => _makeAdmin(context),
              ),
            if (isAdmin && isTargetAdmin && currentUser.uid != targetUser.uid)
              ListTile(
                leading: const Icon(Icons.remove_moderator),
                title: const Text('Remove Admin'),
                onTap: () => _removeAdmin(context),
              ),
            if (!isFriend &&
                !hasPendingRequest &&
                !hasSentRequest &&
                currentUser.uid != targetUser.uid)
              ListTile(
                leading: const Icon(Icons.person_add),
                title: const Text('Add Friend'),
                onTap: () => _sendFriendRequest(context),
              ),
            if (hasPendingRequest)
              ListTile(
                leading: const Icon(Icons.person_add),
                title: const Text('Accept Friend Request'),
                onTap: () => _acceptFriendRequest(context),
              ),
            if (hasSentRequest)
              const ListTile(
                leading: Icon(Icons.person_add),
                title: Text('Friend Request Sent'),
                subtitle: Text('Waiting for response'),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }
}
