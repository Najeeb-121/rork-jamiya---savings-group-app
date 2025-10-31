import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String email;
  final String fullName;
  final String username;
  final String? photoUrl;
  final DateTime createdAt;
  final List<String> associations;
  final List<String> adminOf;
  final Map<String, dynamic>? bankDetails;
  final String? phoneNumber;
  final List<String> friends;
  final List<String> pendingFriendRequests;
  final List<String> sentFriendRequests;

  UserModel({
    required this.uid,
    required this.email,
    required this.fullName,
    required this.username,
    this.photoUrl,
    required this.createdAt,
    this.associations = const [],
    this.adminOf = const [],
    this.bankDetails,
    this.phoneNumber,
    this.friends = const [],
    this.pendingFriendRequests = const [],
    this.sentFriendRequests = const [],
  });

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'fullName': fullName,
      'username': username,
      'photoUrl': photoUrl,
      'createdAt': Timestamp.fromDate(createdAt),
      'associations': associations,
      'adminOf': adminOf,
      'bankDetails': bankDetails,
      'phoneNumber': phoneNumber,
      'friends': friends,
      'pendingFriendRequests': pendingFriendRequests,
      'sentFriendRequests': sentFriendRequests,
    };
  }

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      uid: map['uid'] ?? '',
      email: map['email'] ?? '',
      fullName: map['fullName'] ?? '',
      username: map['username'] ?? '',
      photoUrl: map['photoUrl'] as String?,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      associations: List<String>.from(map['associations'] ?? []),
      adminOf: List<String>.from(map['adminOf'] ?? []),
      bankDetails: map['bankDetails'],
      phoneNumber: map['phoneNumber'] as String?,
      friends: List<String>.from(map['friends'] ?? []),
      pendingFriendRequests:
          List<String>.from(map['pendingFriendRequests'] ?? []),
      sentFriendRequests: List<String>.from(map['sentFriendRequests'] ?? []),
    );
  }

  bool isAdmin(String associationId) {
    return adminOf.contains(associationId);
  }
}
