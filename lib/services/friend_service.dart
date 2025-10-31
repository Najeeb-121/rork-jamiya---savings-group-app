import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';

class FriendService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> sendFriendRequest(String senderId, String receiverId) async {
    try {
      print('Starting friend request process...');
      print('Sender ID: $senderId');
      print('Receiver ID: $receiverId');

      // First check if they are already friends
      final senderDoc =
          await _firestore.collection('users').doc(senderId).get();
      final receiverDoc =
          await _firestore.collection('users').doc(receiverId).get();

      if (!senderDoc.exists || !receiverDoc.exists) {
        print('Error: One or both users not found');
        throw Exception('User not found');
      }

      final senderData = senderDoc.data()!;
      final receiverData = receiverDoc.data()!;

      print('Checking friendship status...');
      // Check if they are already friends
      if (senderData['friends']?.contains(receiverId) == true ||
          receiverData['friends']?.contains(senderId) == true) {
        print('Error: Users are already friends');
        throw Exception('Users are already friends');
      }

      print('Checking for existing requests...');
      // Check if there's already a pending request
      if (senderData['sentFriendRequests']?.contains(receiverId) == true ||
          receiverData['pendingFriendRequests']?.contains(senderId) == true) {
        print('Error: Friend request already sent');
        throw Exception('Friend request already sent');
      }

      // Check if there's a pending request from the other user
      if (senderData['pendingFriendRequests']?.contains(receiverId) == true ||
          receiverData['sentFriendRequests']?.contains(senderId) == true) {
        print('Error: Pending request already exists');
        throw Exception(
            'You already have a pending friend request from this user');
      }

      print('Creating batch operation...');
      final batch = _firestore.batch();

      // Add to sender's sent requests
      batch.update(
        _firestore.collection('users').doc(senderId),
        {
          'sentFriendRequests': FieldValue.arrayUnion([receiverId]),
        },
      );

      // Add to receiver's pending requests
      batch.update(
        _firestore.collection('users').doc(receiverId),
        {
          'pendingFriendRequests': FieldValue.arrayUnion([senderId]),
        },
      );

      print('Creating notification...');
      // Create notification in the global notifications collection
      final notificationRef = _firestore.collection('notifications').doc();
      final notificationData = {
        'type': 'friend_request',
        'senderId': senderId,
        'senderName': senderData['fullName'] ?? 'Unknown',
        'senderUsername': senderData['username'] ?? 'Unknown',
        'recipientId': receiverId,
        'timestamp': FieldValue.serverTimestamp(),
        'read': false,
        'title': 'New Friend Request',
        'message': '${senderData['fullName']} wants to be your friend',
      };
      print('Notification data: $notificationData');
      batch.set(notificationRef, notificationData);

      print('Committing batch...');
      await batch.commit();
      print('Friend request sent successfully');
    } catch (e) {
      print('Error sending friend request: $e');
      rethrow;
    }
  }

  Future<void> acceptFriendRequest(String userId, String friendId) async {
    try {
      print('Starting accept friend request process...');
      print('User ID: $userId');
      print('Friend ID: $friendId');

      // First, get both user documents to verify the request exists
      final userDoc = await _firestore.collection('users').doc(userId).get();
      final friendDoc =
          await _firestore.collection('users').doc(friendId).get();

      if (!userDoc.exists || !friendDoc.exists) {
        throw Exception('User not found');
      }

      final userData = userDoc.data()!;
      final friendData = friendDoc.data()!;

      // Initialize arrays if they don't exist
      final userPendingRequests =
          List<String>.from(userData['pendingFriendRequests'] ?? []);
      final userFriends = List<String>.from(userData['friends'] ?? []);
      final friendSentRequests =
          List<String>.from(friendData['sentFriendRequests'] ?? []);
      final friendFriends = List<String>.from(friendData['friends'] ?? []);

      // Verify the friend request exists
      if (!userPendingRequests.contains(friendId) ||
          !friendSentRequests.contains(userId)) {
        throw Exception('Friend request not found');
      }

      // Create a new batch for friend request acceptance
      final batch = _firestore.batch();

      // Update user's document
      batch.update(
        _firestore.collection('users').doc(userId),
        {
          'pendingFriendRequests': FieldValue.arrayRemove([friendId]),
          'friends': FieldValue.arrayUnion([friendId]),
        },
      );

      // Update friend's document
      batch.update(
        _firestore.collection('users').doc(friendId),
        {
          'sentFriendRequests': FieldValue.arrayRemove([userId]),
          'friends': FieldValue.arrayUnion([userId]),
        },
      );

      // Get the notification before committing the batch
      final notificationQuery = await _firestore
          .collection('notifications')
          .where('type', isEqualTo: 'friend_request')
          .where('senderId', isEqualTo: friendId)
          .where('recipientId', isEqualTo: userId)
          .get();

      // Add notification deletion to the batch
      for (var doc in notificationQuery.docs) {
        batch.delete(doc.reference);
      }

      print('Committing all changes...');
      await batch.commit();
      print('Friend request accepted and notification deleted successfully');
    } catch (e) {
      print('Error accepting friend request: $e');
      rethrow;
    }
  }

  Future<void> rejectFriendRequest(String userId, String friendId) async {
    try {
      print('Starting reject friend request process...');
      print('User ID: $userId');
      print('Friend ID: $friendId');

      final batch = _firestore.batch();

      // Remove from pending requests
      batch.update(
        _firestore.collection('users').doc(userId),
        {
          'pendingFriendRequests': FieldValue.arrayRemove([friendId]),
        },
      );

      // Remove from sent requests
      batch.update(
        _firestore.collection('users').doc(friendId),
        {
          'sentFriendRequests': FieldValue.arrayRemove([userId]),
        },
      );

      print('Deleting friend request notification...');
      // Delete the friend request notification
      final notificationQuery = await _firestore
          .collection('notifications')
          .where('type', isEqualTo: 'friend_request')
          .where('senderId', isEqualTo: friendId)
          .where('recipientId', isEqualTo: userId)
          .get();

      print('Found ${notificationQuery.docs.length} notifications to delete');
      for (var doc in notificationQuery.docs) {
        batch.delete(doc.reference);
      }

      print('Committing batch...');
      await batch.commit();
      print('Friend request rejected successfully');
    } catch (e) {
      print('Error rejecting friend request: $e');
      rethrow;
    }
  }

  Future<void> removeFriend(String userId, String friendId) async {
    try {
      print('Starting remove friend process...');
      print('User ID: $userId');
      print('Friend ID: $friendId');

      final batch = _firestore.batch();

      // Remove friend from user's friends list
      batch.update(
        _firestore.collection('users').doc(userId),
        {
          'friends': FieldValue.arrayRemove([friendId]),
        },
      );

      // Remove user from friend's friends list
      batch.update(
        _firestore.collection('users').doc(friendId),
        {
          'friends': FieldValue.arrayRemove([userId]),
        },
      );

      print('Committing batch...');
      await batch.commit();
      print('Friend removed successfully');
    } catch (e) {
      print('Error removing friend: $e');
      rethrow;
    }
  }

  Future<void> makeAdmin(
      String associationId, String currentUserId, String targetUserId) async {
    try {
      print('Starting make admin process...');
      print('Association ID: $associationId');
      print('Current User ID: $currentUserId');
      print('Target User ID: $targetUserId');

      final batch = _firestore.batch();

      // Add to target user's adminOf list
      batch.update(
        _firestore.collection('users').doc(targetUserId),
        {
          'adminOf': FieldValue.arrayUnion([associationId]),
        },
      );

      print('Committing batch...');
      await batch.commit();
      print('User made admin successfully');
    } catch (e) {
      print('Error making user admin: $e');
      rethrow;
    }
  }

  Future<void> removeAdmin(
      String associationId, String currentUserId, String targetUserId) async {
    try {
      print('Starting remove admin process...');
      print('Association ID: $associationId');
      print('Current User ID: $currentUserId');
      print('Target User ID: $targetUserId');

      final batch = _firestore.batch();

      // Remove from target user's adminOf list
      batch.update(
        _firestore.collection('users').doc(targetUserId),
        {
          'adminOf': FieldValue.arrayRemove([associationId]),
        },
      );

      print('Committing batch...');
      await batch.commit();
      print('Admin privileges removed successfully');
    } catch (e) {
      print('Error removing admin privileges: $e');
      rethrow;
    }
  }
}
