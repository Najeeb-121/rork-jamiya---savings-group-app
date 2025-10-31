import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../models/association_model.dart';
import '../models/payment_status.dart';
import '../models/notification_preferences.dart';
import 'package:provider/provider.dart';
import '../providers/currency_provider.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Collections
  CollectionReference<Map<String, dynamic>> get usersCollection =>
      _db.collection('users');

  CollectionReference<Map<String, dynamic>> get associationsCollection =>
      _db.collection('associations');

  CollectionReference<Map<String, dynamic>> get usernamesCollection =>
      _db.collection('usernames');

  CollectionReference<Map<String, dynamic>> get invitationsCollection =>
      _db.collection('invitations');

  CollectionReference<Map<String, dynamic>> get commitmentsCollection =>
      _db.collection('commitments');

  // User Operations
  Future<void> createUser(UserModel user) async {
    try {
      final batch = _db.batch();

      // Create user document
      batch.set(usersCollection.doc(user.uid), user.toMap());

      // Create username document for uniqueness check
      batch.set(
        usernamesCollection.doc(user.username.toLowerCase()),
        {
          'uid': user.uid,
          'createdAt': FieldValue.serverTimestamp(),
        },
      );

      await batch.commit();
    } catch (e) {
      print('Error creating user: $e');
      rethrow;
    }
  }

  Future<UserModel?> getUser(String uid) async {
    try {
      final doc = await usersCollection.doc(uid).get();
      if (doc.exists) {
        return UserModel.fromMap({
          'uid': doc.id,
          ...doc.data()!,
        });
      }
      return null;
    } catch (e) {
      print('Error getting user: $e');
      return null;
    }
  }

  // Association Operations
  Future<void> createAssociation(
      AssociationModel association, BuildContext context) async {
    try {
      // Convert monthly contribution from selected currency to JOD
      final currencyProvider =
          Provider.of<CurrencyProvider>(context, listen: false);
      final monthlyContributionInJOD =
          currencyProvider.convertToJOD(association.monthlyContribution);

      final associationData = {
        'name': association.name,
        'description': association.description,
        'monthlyContribution': monthlyContributionInJOD, // Save in JOD
        'numberOfMembers': association.numberOfMembers,
        'adminId': association.adminId,
        'memberIds': association.memberIds,
        'startDate': Timestamp.fromDate(association.startDate),
        'endDate': Timestamp.fromDate(association.endDate),
        'payoutDate': Timestamp.fromDate(association.payoutDate),
        'payoutMonths': association.payoutMonths,
        'isDrawComplete': association.isDrawComplete,
        'createdAt': Timestamp.fromDate(association.createdAt),
        'status': association.status,
        'bankAccountNumber': association.bankAccountNumber,
        'cliqName': association.cliqName,
        'cliqNumber': association.cliqNumber,
      };

      final docRef = await associationsCollection.add(associationData);
      print('Association created with ID: ${docRef.id}');
    } catch (e) {
      print('Error creating association: $e');
      rethrow;
    }
  }

  Future<List<AssociationModel>> getUserAssociations(String uid) async {
    try {
      print('Fetching associations for user: $uid');

      // First, get the user document to check their associations
      final userDoc = await usersCollection.doc(uid).get();
      print('User document data: ${userDoc.data()}');

      final snapshot = await associationsCollection
          .where('memberIds', arrayContains: uid)
          .get();

      print('Found ${snapshot.docs.length} associations');
      final associations = snapshot.docs.map((doc) {
        final data = doc.data();
        print('Processing association data: $data');
        return AssociationModel.fromMap({
          'id': doc.id,
          ...data,
        });
      }).toList();

      print('Successfully processed ${associations.length} associations');
      return associations;
    } catch (e) {
      print('Error getting user associations: $e');
      return [];
    }
  }

  // Payment Operations
  Future<List<Map<String, dynamic>>> getAssociationPayments(
      String associationId) async {
    try {
      final snapshot = await associationsCollection
          .doc(associationId)
          .collection('payments')
          .orderBy('month')
          .get();

      return snapshot.docs.map((doc) => doc.data()).toList();
    } catch (e) {
      print('Error getting association payments: $e');
      return [];
    }
  }

  Future<void> updatePaymentStatus({
    required String associationId,
    required String userId,
    required int month,
    required double amount,
    required PaymentStatus status,
  }) async {
    try {
      final paymentRef = _db
          .collection('associations')
          .doc(associationId)
          .collection('payments')
          .doc('month_$month');

      await paymentRef.set({
        'month': month,
        'dueDate': DateTime.now().add(const Duration(days: 30)),
        'payments.$userId': {
          'amount': amount,
          'status': status.toString(),
          'timestamp': FieldValue.serverTimestamp(),
        },
      }, SetOptions(merge: true));
    } catch (e) {
      print('Error updating payment status: $e');
      rethrow;
    }
  }

  // Draw Operations
  Future<void> saveDrawResults({
    required String associationId,
    required Map<String, int> payoutMonths,
  }) async {
    try {
      await associationsCollection.doc(associationId).update({
        'payoutMonths': payoutMonths,
        'isDrawComplete': true,
      });
    } catch (e) {
      print('Error saving draw results: $e');
      rethrow;
    }
  }

  Future<void> performDraw(String associationId) async {
    try {
      final associationDoc =
          await _db.collection('associations').doc(associationId).get();
      if (!associationDoc.exists) {
        throw Exception('Association not found');
      }

      final association = AssociationModel.fromMap(associationDoc.data()!);
      final memberIds = List<String>.from(association.memberIds);

      if (memberIds.length != association.numberOfMembers) {
        throw Exception(
            'Cannot perform draw: Association requires ${association.numberOfMembers} members but only has ${memberIds.length}');
      }

      // Shuffle the list to randomize order
      memberIds.shuffle();

      // Create map of user IDs to payout months (1-based index)
      final Map<String, int> payoutMonths = {};

      // Get the start month (1-12)
      final startMonth = association.startDate.month;

      // Calculate the number of months between start and end
      final totalMonths =
          (association.endDate.year - association.startDate.year) * 12 +
              (association.endDate.month - association.startDate.month) +
              1;

      if (memberIds.length != totalMonths) {
        throw Exception(
            'Number of members (${memberIds.length}) does not match the number of months (${totalMonths})');
      }

      // Assign payout months starting from the start month
      for (int i = 0; i < memberIds.length; i++) {
        // Calculate the month number (1-12) based on start month
        int monthNumber = startMonth + i;
        if (monthNumber > 12) {
          monthNumber -= 12;
        }
        payoutMonths[memberIds[i]] = monthNumber;
      }

      // Update the association document
      await _db.collection('associations').doc(associationId).update({
        'payoutMonths': payoutMonths,
        'isDrawComplete': true,
      });
    } catch (e) {
      print('Error performing draw: $e');
      rethrow;
    }
  }

  Future<void> swapPayoutMonths(
      String associationId, String memberId1, String memberId2) async {
    try {
      final associationRef = FirebaseFirestore.instance
          .collection('associations')
          .doc(associationId);
      final associationDoc = await associationRef.get();

      if (!associationDoc.exists) {
        throw Exception('Association not found');
      }

      final payoutMonths = Map<String, dynamic>.from(
          associationDoc.data()!['payoutMonths'] ?? {});

      if (!payoutMonths.containsKey(memberId1) ||
          !payoutMonths.containsKey(memberId2)) {
        throw Exception('One or both members do not have an assigned month');
      }

      // Swap the months
      final temp = payoutMonths[memberId1];
      payoutMonths[memberId1] = payoutMonths[memberId2];
      payoutMonths[memberId2] = temp;

      await associationRef.update({'payoutMonths': payoutMonths});
    } catch (e) {
      print('Error swapping payout months: $e');
      rethrow;
    }
  }

  Stream<QuerySnapshot> getMembersStream(String associationId) {
    return _db
        .collection('associations')
        .doc(associationId)
        .snapshots()
        .asyncMap((associationDoc) async {
      if (!associationDoc.exists) {
        return await _db
            .collection('users')
            .where(FieldPath.documentId, whereIn: []).get();
      }

      final memberIds =
          List<String>.from(associationDoc.data()!['memberIds'] ?? []);
      if (memberIds.isEmpty) {
        return await _db
            .collection('users')
            .where(FieldPath.documentId, whereIn: []).get();
      }

      return await _db
          .collection('users')
          .where(FieldPath.documentId, whereIn: memberIds)
          .get();
    });
  }

  Future<void> sendFriendRequest(String senderId, String receiverId) async {
    try {
      final batch = _db.batch();

      // Get sender's user data
      final senderDoc = await _db.collection('users').doc(senderId).get();
      final senderData = senderDoc.data()!;

      // Create friend request in receiver's collection
      batch.set(
        _db
            .collection('users')
            .doc(receiverId)
            .collection('friend_requests')
            .doc(senderId),
        {
          'senderId': senderId,
          'senderName': senderData['fullName'] ?? 'Unknown',
          'senderUsername': senderData['username'] ?? 'Unknown',
          'status': 'pending',
          'timestamp': FieldValue.serverTimestamp(),
        },
      );

      // Create notification in the global notifications collection
      batch.set(
        _db.collection('notifications').doc(),
        {
          'type': 'friend_request',
          'senderId': senderId,
          'senderName': senderData['fullName'] ?? 'Unknown',
          'senderUsername': senderData['username'] ?? 'Unknown',
          'timestamp': FieldValue.serverTimestamp(),
          'read': false,
          'recipientId': receiverId,
          'title': 'New Friend Request',
          'message': '${senderData['fullName']} wants to be your friend',
        },
      );

      await batch.commit();
    } catch (e) {
      print('Error sending friend request: $e');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getFriendRequests(String userId) async {
    try {
      final snapshot = await _db
          .collection('users')
          .doc(userId)
          .collection('friend_requests')
          .where('status', isEqualTo: 'pending')
          .get();

      return snapshot.docs.map((doc) => doc.data()).toList();
    } catch (e) {
      print('Error getting friend requests: $e');
      return [];
    }
  }

  Future<List<String>> getFriends(String userId) async {
    try {
      final doc = await _db.collection('users').doc(userId).get();
      if (doc.exists) {
        return List<String>.from(doc.data()?['friends'] ?? []);
      }
      return [];
    } catch (e) {
      print('Error getting friends: $e');
      return [];
    }
  }

  Future<List<UserModel>> getUserFriends(String userId) async {
    try {
      final userDoc = await _db.collection('users').doc(userId).get();
      final friendsList = userDoc.data()?['friends'] as List<dynamic>? ?? [];

      if (friendsList.isEmpty) {
        return [];
      }

      final friends = await Future.wait(
        friendsList.map((friendId) async {
          final friendDoc = await _db.collection('users').doc(friendId).get();
          return UserModel.fromMap({
            'uid': friendId,
            ...friendDoc.data()!,
          });
        }),
      );

      return friends;
    } catch (e) {
      print('Error getting user friends: $e');
      rethrow;
    }
  }

  Future<void> addFriend(String userId, String friendId) async {
    try {
      final batch = _db.batch();

      // Add friend to user's friends list
      batch.update(
        _db.collection('users').doc(userId),
        {
          'friends': FieldValue.arrayUnion([friendId])
        },
      );

      // Add user to friend's friends list
      batch.update(
        _db.collection('users').doc(friendId),
        {
          'friends': FieldValue.arrayUnion([userId])
        },
      );

      await batch.commit();
    } catch (e) {
      print('Error adding friend: $e');
      rethrow;
    }
  }

  Future<void> removeFriend(String userId, String friendId) async {
    try {
      final batch = _db.batch();

      // Remove friend from user's friends list
      batch.update(
        _db.collection('users').doc(userId),
        {
          'friends': FieldValue.arrayRemove([friendId])
        },
      );

      // Remove user from friend's friends list
      batch.update(
        _db.collection('users').doc(friendId),
        {
          'friends': FieldValue.arrayRemove([userId])
        },
      );

      await batch.commit();
    } catch (e) {
      print('Error removing friend: $e');
      rethrow;
    }
  }

  Future<List<UserModel>> searchUsers(String query) async {
    try {
      // Search by name
      final nameResults = await _db
          .collection('users')
          .where('fullName', isGreaterThanOrEqualTo: query)
          .where('fullName', isLessThanOrEqualTo: query + '\uf8ff')
          .get();

      // Search by email
      final emailResults = await _db
          .collection('users')
          .where('email', isGreaterThanOrEqualTo: query)
          .where('email', isLessThanOrEqualTo: query + '\uf8ff')
          .get();

      // Combine and deduplicate results
      final allResults = [...nameResults.docs, ...emailResults.docs];
      final uniqueResults = allResults.toSet().toList();

      return uniqueResults.map((doc) {
        return UserModel.fromMap({
          'uid': doc.id,
          ...doc.data(),
        });
      }).toList();
    } catch (e) {
      print('Error searching users: $e');
      rethrow;
    }
  }

  Future<List<UserModel>> getAssociationMembers(String associationId) async {
    try {
      final associationDoc =
          await _db.collection('associations').doc(associationId).get();
      if (!associationDoc.exists) {
        throw Exception('Association not found');
      }

      final memberIds =
          List<String>.from(associationDoc.data()!['memberIds'] ?? []);
      if (memberIds.isEmpty) {
        return [];
      }

      final membersSnapshot = await _db
          .collection('users')
          .where(FieldPath.documentId, whereIn: memberIds)
          .get();

      return membersSnapshot.docs
          .map((doc) => UserModel.fromMap({
                'uid': doc.id,
                ...doc.data(),
              }))
          .toList();
    } catch (e) {
      print('Error getting association members: $e');
      rethrow;
    }
  }

  Future<void> updatePayment(
      String associationId, String memberId, double amount) async {
    try {
      await _db.collection('associations').doc(associationId).update({
        'payments.$memberId': amount,
      });
    } catch (e) {
      print('Error updating payment: $e');
      rethrow;
    }
  }

  Future<void> updatePaymentInfo(
    String associationId, {
    String? bankAccountNumber,
    String? cliqName,
    String? cliqNumber,
  }) async {
    try {
      final Map<String, dynamic> updates = {};

      if (bankAccountNumber != null) {
        updates['bankAccountNumber'] = bankAccountNumber;
      }
      if (cliqName != null) {
        updates['cliqName'] = cliqName;
      }
      if (cliqNumber != null) {
        updates['cliqNumber'] = cliqNumber;
      }

      await _db.collection('associations').doc(associationId).update(updates);
    } catch (e) {
      throw Exception('Failed to update payment information: $e');
    }
  }

  // Co-Admin Operations
  Future<void> addCoAdmin(String associationId, String userId) async {
    try {
      await _db.collection('associations').doc(associationId).update({
        'coAdmins': FieldValue.arrayUnion([userId]),
      });
    } catch (e) {
      print('Error adding co-admin: $e');
      rethrow;
    }
  }

  Future<void> removeCoAdmin(String associationId, String userId) async {
    try {
      await _db.collection('associations').doc(associationId).update({
        'coAdmins': FieldValue.arrayRemove([userId]),
      });
    } catch (e) {
      print('Error removing co-admin: $e');
      rethrow;
    }
  }

  // Notification Operations
  Future<void> updateNotificationPreferences(
    String userId,
    NotificationPreferences preferences,
  ) async {
    try {
      await _db
          .collection('users')
          .doc(userId)
          .collection('preferences')
          .doc('notifications')
          .set(preferences.toMap());
    } catch (e) {
      print('Error updating notification preferences: $e');
      rethrow;
    }
  }

  Future<NotificationPreferences?> getNotificationPreferences(
      String userId) async {
    try {
      final doc = await _db
          .collection('users')
          .doc(userId)
          .collection('preferences')
          .doc('notifications')
          .get();

      if (doc.exists) {
        return NotificationPreferences.fromMap(doc.data()!);
      }

      // Create default preferences if none exist
      final defaultPreferences = NotificationPreferences(
        userId: userId,
        lastUpdated: DateTime.now(),
      );
      await _db
          .collection('users')
          .doc(userId)
          .collection('preferences')
          .doc('notifications')
          .set(defaultPreferences.toMap());
      return defaultPreferences;
    } catch (e) {
      print('Error getting notification preferences: $e');
      return null;
    }
  }

  Future<void> sendPaymentReminder(
    String associationId,
    String memberId,
    String message,
  ) async {
    try {
      // Get association details
      final associationDoc =
          await _db.collection('associations').doc(associationId).get();
      if (!associationDoc.exists) {
        throw Exception('Association not found');
      }

      final associationData = associationDoc.data()!;

      final notification = {
        'type': 'payment_reminder',
        'associationId': associationId,
        'associationName': associationData['name'],
        'monthlyContribution': associationData['monthlyContribution'],
        'timestamp': FieldValue.serverTimestamp(),
        'read': false,
        'recipientId': memberId,
        'senderId': associationData['adminId'],
      };

      // Add to a global notifications collection
      await _db.collection('notifications').add(notification);
    } catch (e) {
      print('Error sending payment reminder: $e');
      if (e is Exception) {
        rethrow;
      }
      throw Exception('Failed to send payment reminder: $e');
    }
  }

  Future<int> getUnreadNotificationCount(String userId) async {
    try {
      final snapshot = await _db
          .collection('notifications')
          .where('recipientId', isEqualTo: userId)
          .where('read', isEqualTo: false)
          .get();

      return snapshot.docs.length;
    } catch (e) {
      print('Error getting unread notification count: $e');
      return 0;
    }
  }

  Stream<QuerySnapshot> getNotifications(String userId) {
    try {
      print('Setting up notifications stream for user: $userId');
      return _db
          .collection('notifications')
          .where('recipientId', isEqualTo: userId)
          .snapshots()
          .handleError((error) {
        print('Error in notifications stream: $error');
        throw error; // Re-throw the error to be handled by the UI
      });
    } catch (e) {
      print('Error setting up notifications stream: $e');
      throw e; // Re-throw the error to be handled by the UI
    }
  }

  Future<void> updateUserPreferences({
    required String userId,
    required Map<String, dynamic> preferences,
  }) async {
    try {
      await _db
          .collection('users')
          .doc(userId)
          .collection('preferences')
          .doc('notifications')
          .update({
        ...preferences,
        'lastUpdated': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Failed to update user preferences: $e');
    }
  }

  // Invitation Operations
  Future<void> inviteMember(String associationId, String username) async {
    try {
      print('Starting invitation process for username: $username');

      // Get current user
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      // Get user ID from username
      final usernameDoc =
          await _db.collection('usernames').doc(username.toLowerCase()).get();

      if (!usernameDoc.exists) {
        print('Username not found: $username');
        throw Exception('User not found');
      }

      final userId = usernameDoc.data()!['uid'] as String;
      print('Found user ID: $userId');

      // Get association data
      final associationDoc =
          await _db.collection('associations').doc(associationId).get();

      if (!associationDoc.exists) {
        print('Association not found: $associationId');
        throw Exception('Association not found');
      }

      final associationData = associationDoc.data()!;

      // Check if current user is admin
      if (associationData['adminId'] != currentUser.uid) {
        print('Current user is not admin: ${currentUser.uid}');
        throw Exception('Only association admin can invite members');
      }

      // Check if user is already a member
      final memberIds = List<String>.from(associationData['memberIds'] ?? []);
      if (memberIds.contains(userId)) {
        print('User is already a member: $userId');
        throw Exception('User is already a member');
      }

      // Create invitation in association's invitations collection
      print('Creating invitation in association...');
      await _db
          .collection('associations')
          .doc(associationId)
          .collection('invitations')
          .doc(userId)
          .set({
        'userId': userId,
        'username': username,
        'status': 'pending',
        'timestamp': FieldValue.serverTimestamp(),
        'associationId': associationId,
        'associationName': associationData['name'],
        'monthlyContribution': associationData['monthlyContribution'],
        'invitedBy': currentUser.uid,
      });

      // Add invitation to user's invitations collection
      print('Creating invitation in user collection...');
      await _db
          .collection('users')
          .doc(userId)
          .collection('invitations')
          .doc(associationId)
          .set({
        'associationId': associationId,
        'associationName': associationData['name'],
        'monthlyContribution': associationData['monthlyContribution'],
        'status': 'pending',
        'timestamp': FieldValue.serverTimestamp(),
        'invitedBy': currentUser.uid,
      });

      // Create notification for the invited user
      print('Creating notification for invited user...');
      await _db.collection('notifications').add({
        'type': 'association_invite',
        'associationId': associationId,
        'associationName': associationData['name'],
        'monthlyContribution': associationData['monthlyContribution'],
        'timestamp': FieldValue.serverTimestamp(),
        'read': false,
        'recipientId': userId,
        'senderId': currentUser.uid,
        'title': 'New Association Invitation',
        'message': 'You have been invited to join ${associationData['name']}',
      });

      print('Successfully created invitation and notification');
    } catch (e) {
      print('Error in inviteMember: $e');
      throw Exception('Failed to invite member: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getUserInvitations(String userId) async {
    try {
      print('Fetching invitations for user: $userId');
      final snapshot = await _db
          .collection('users')
          .doc(userId)
          .collection('invitations')
          .where('status', isEqualTo: 'pending')
          .get();

      final invitations = await Future.wait(snapshot.docs.map((doc) async {
        final data = doc.data();
        // Ensure we have the associationId
        if (!data.containsKey('associationId')) {
          // If associationId is missing, use the document ID
          data['associationId'] = doc.id;
        }

        // Get additional association details if needed
        if (data.containsKey('associationId')) {
          final associationDoc = await _db
              .collection('associations')
              .doc(data['associationId'])
              .get();

          if (associationDoc.exists) {
            final associationData = associationDoc.data()!;
            data['associationName'] =
                associationData['name'] ?? 'Unknown Association';
            data['monthlyContribution'] =
                associationData['monthlyContribution'] ?? 0;
          }
        }

        return data;
      }));

      print('Found ${invitations.length} invitations');
      return invitations;
    } catch (e) {
      print('Error getting user invitations: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getAssociationInvitations(
      String associationId) async {
    try {
      print('Fetching invitations for association: $associationId');
      final snapshot = await _db
          .collection('associations')
          .doc(associationId)
          .collection('invitations')
          .where('status', isEqualTo: 'pending')
          .get();

      final invitations = snapshot.docs.map((doc) => doc.data()).toList();
      print('Found ${invitations.length} invitations');
      return invitations;
    } catch (e) {
      print('Error getting association invitations: $e');
      return [];
    }
  }

  Future<void> updateInvitationStatus(
      String invitationId, String status) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not authenticated');

      // First, try to get the invitation from the user's invitations subcollection
      final userInvitationDoc = await _db
          .collection('users')
          .doc(user.uid)
          .collection('invitations')
          .doc(invitationId)
          .get();

      if (!userInvitationDoc.exists) {
        // If not found in user's invitations, try the association's invitations
        final associationInvitationDoc = await _db
            .collection('associations')
            .doc(invitationId)
            .collection('invitations')
            .doc(user.uid)
            .get();

        if (!associationInvitationDoc.exists) {
          throw Exception('Invitation not found');
        }

        // Update both collections
        await _db
            .collection('users')
            .doc(user.uid)
            .collection('invitations')
            .doc(invitationId)
            .set({
          'status': status,
          'updatedAt': FieldValue.serverTimestamp(),
          'associationId': invitationId,
        });

        await _db
            .collection('associations')
            .doc(invitationId)
            .collection('invitations')
            .doc(user.uid)
            .update({
          'status': status,
          'updatedAt': FieldValue.serverTimestamp(),
        });

        if (status == 'accepted') {
          await acceptInvitation(invitationId, user.uid);
        }
      } else {
        final userInvitationData =
            userInvitationDoc.data() as Map<String, dynamic>;
        final associationId =
            userInvitationData['associationId'] as String? ?? invitationId;

        // Update both collections
        await _db
            .collection('users')
            .doc(user.uid)
            .collection('invitations')
            .doc(invitationId)
            .update({
          'status': status,
          'updatedAt': FieldValue.serverTimestamp(),
        });

        await _db
            .collection('associations')
            .doc(associationId)
            .collection('invitations')
            .doc(user.uid)
            .update({
          'status': status,
          'updatedAt': FieldValue.serverTimestamp(),
        });

        if (status == 'accepted') {
          await acceptInvitation(associationId, user.uid);
        }
      }
    } catch (e) {
      print('Error in updateInvitationStatus: $e');
      throw Exception('Failed to update invitation status: $e');
    }
  }

  Future<void> acceptInvitation(String associationId, String userId) async {
    try {
      print(
          'Starting acceptInvitation for user: $userId in association: $associationId');

      // Get current user
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      if (currentUser.uid != userId) {
        throw Exception('User can only accept their own invitations');
      }

      // Get association data
      final associationDoc =
          await _db.collection('associations').doc(associationId).get();

      if (!associationDoc.exists) {
        print('Association not found: $associationId');
        throw Exception('Association not found');
      }

      final associationData = associationDoc.data()!;
      final memberIds = List<String>.from(associationData['memberIds'] ?? []);

      // Check if user is already a member
      if (memberIds.contains(userId)) {
        throw Exception('User is already a member of this association');
      }

      // Create a batch operation
      final batch = _db.batch();

      // Add user to association members
      print('Updating association members...');
      batch.update(_db.collection('associations').doc(associationId), {
        'memberIds': FieldValue.arrayUnion([userId]),
      });

      // Update invitation status in association
      print('Updating invitation status in association...');
      batch.update(
        _db
            .collection('associations')
            .doc(associationId)
            .collection('invitations')
            .doc(userId),
        {
          'status': 'accepted',
          'acceptedAt': FieldValue.serverTimestamp(),
        },
      );

      // Update invitation status in user's invitations
      print('Updating invitation status in user collection...');
      batch.update(
        _db
            .collection('users')
            .doc(userId)
            .collection('invitations')
            .doc(associationId),
        {
          'status': 'accepted',
          'acceptedAt': FieldValue.serverTimestamp(),
        },
      );

      // Add association to user's associations list
      print('Adding association to user\'s associations list...');
      batch.update(_db.collection('users').doc(userId), {
        'associations': FieldValue.arrayUnion([associationId]),
      });

      // Create notification for the association admin
      print('Creating notification for admin...');
      final notificationRef = _db.collection('notifications').doc();
      batch.set(notificationRef, {
        'type': 'invitation_accepted',
        'associationId': associationId,
        'associationName': associationData['name'],
        'timestamp': FieldValue.serverTimestamp(),
        'read': false,
        'recipientId': associationData['adminId'],
        'senderId': userId,
        'title': 'Invitation Accepted',
        'message': 'A user has accepted your association invitation',
      });

      // Commit the batch
      await batch.commit();
      print('Invitation accepted successfully');
    } catch (e) {
      print('Error in acceptInvitation: $e');
      throw Exception('Failed to accept invitation: $e');
    }
  }

  Future<void> declineInvitation(String associationId, String userId) async {
    try {
      print(
          'Declining invitation for user: $userId in association: $associationId');

      // Update invitation status in association
      print('Updating invitation status in association...');
      await _db
          .collection('associations')
          .doc(associationId)
          .collection('invitations')
          .doc(userId)
          .update({
        'status': 'declined',
        'declinedAt': FieldValue.serverTimestamp(),
      });

      // Update invitation status in user's invitations
      print('Updating invitation status in user collection...');
      await _db
          .collection('users')
          .doc(userId)
          .collection('invitations')
          .doc(associationId)
          .update({
        'status': 'declined',
        'declinedAt': FieldValue.serverTimestamp(),
      });

      print('Invitation declined successfully');
    } catch (e) {
      print('Error declining invitation: $e');
      throw Exception('Failed to decline invitation: $e');
    }
  }

  Future<List<UserModel>> getUsers(List<String> userIds) async {
    try {
      final users = await Future.wait(
        userIds.map((id) => getUser(id)),
      );
      return users.whereType<UserModel>().toList();
    } catch (e) {
      print('Error getting users: $e');
      rethrow;
    }
  }

  Future<void> swapMemberMonths({
    required String associationId,
    required String member1Id,
    required String member2Id,
  }) async {
    try {
      final associationRef = _db.collection('associations').doc(associationId);

      await _db.runTransaction((transaction) async {
        final associationDoc = await transaction.get(associationRef);
        if (!associationDoc.exists) {
          throw Exception('Association not found');
        }

        final association = AssociationModel.fromMap(associationDoc.data()!);
        final payoutMonths = Map<String, int>.from(association.payoutMonths);

        // Swap the months
        final month1 = payoutMonths[member1Id];
        final month2 = payoutMonths[member2Id];

        if (month1 != null && month2 != null) {
          payoutMonths[member1Id] = month2;
          payoutMonths[member2Id] = month1;
        } else {
          throw Exception('One or both members do not have assigned months');
        }

        // Update the association document
        transaction.update(associationRef, {
          'payoutMonths': payoutMonths,
        });
      });
    } catch (e) {
      print('Error swapping member months: $e');
      rethrow;
    }
  }

  Future<void> acceptFriendRequest(String senderId, String receiverId) async {
    try {
      final batch = _db.batch();

      // Update the request status
      batch.update(
        _db
            .collection('users')
            .doc(receiverId)
            .collection('friend_requests')
            .doc(senderId),
        {'status': 'accepted'},
      );

      // Add each user to the other's friends list
      batch.update(
        _db.collection('users').doc(receiverId),
        {
          'friends': FieldValue.arrayUnion([senderId])
        },
      );

      batch.update(
        _db.collection('users').doc(senderId),
        {
          'friends': FieldValue.arrayUnion([receiverId])
        },
      );

      // Delete the friend request notification
      final notificationQuery = await _db
          .collection('notifications')
          .where('type', isEqualTo: 'friend_request')
          .where('senderId', isEqualTo: senderId)
          .where('recipientId', isEqualTo: receiverId)
          .get();

      for (var doc in notificationQuery.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();
    } catch (e) {
      print('Error accepting friend request: $e');
      rethrow;
    }
  }

  Future<void> rejectFriendRequest(String senderId, String receiverId) async {
    try {
      final batch = _db.batch();

      // Update the request status
      batch.update(
        _db
            .collection('users')
            .doc(receiverId)
            .collection('friend_requests')
            .doc(senderId),
        {'status': 'declined'},
      );

      await batch.commit();
    } catch (e) {
      print('Error rejecting friend request: $e');
      rethrow;
    }
  }

  Future<void> acceptAssociationInvite(
      String associationId, String userId) async {
    try {
      final batch = _db.batch();

      // Update the invitation status
      batch.update(
        _db
            .collection('users')
            .doc(userId)
            .collection('invitations')
            .doc(associationId),
        {'status': 'accepted'},
      );

      // Add user to association members
      batch.update(
        _db.collection('associations').doc(associationId),
        {
          'members': FieldValue.arrayUnion([userId])
        },
      );

      await batch.commit();
    } catch (e) {
      print('Error accepting association invite: $e');
      rethrow;
    }
  }

  Future<void> rejectAssociationInvite(
      String associationId, String userId) async {
    try {
      final batch = _db.batch();

      // Update the invitation status
      batch.update(
        _db
            .collection('users')
            .doc(userId)
            .collection('invitations')
            .doc(associationId),
        {'status': 'declined'},
      );

      await batch.commit();
    } catch (e) {
      print('Error rejecting association invite: $e');
      rethrow;
    }
  }

  Future<void> markNotificationAsRead(
      String notificationId, String userId) async {
    try {
      print('Marking notification as read: $notificationId for user: $userId');
      await _db
          .collection('notifications')
          .doc(notificationId)
          .update({'read': true});
      print('Successfully marked notification as read');
    } catch (e) {
      print('Error marking notification as read: $e');
      rethrow;
    }
  }

  Future<void> deleteNotification(String notificationId, String userId) async {
    try {
      print('Deleting notification: $notificationId for user: $userId');
      await _db.collection('notifications').doc(notificationId).delete();
      print('Successfully deleted notification');
    } catch (e) {
      print('Error deleting notification: $e');
      rethrow;
    }
  }

  Stream<QuerySnapshot> getNotificationsStream(String userId) {
    return _db
        .collection('notifications')
        .where('recipientId', isEqualTo: userId)
        .snapshots();
  }
}
