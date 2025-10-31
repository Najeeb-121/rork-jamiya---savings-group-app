import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationPreferences {
  final String userId;
  final bool paymentReminders;
  final int reminderDaysBefore;
  final bool adminNotifications;
  final bool friendRequests;
  final bool associationInvites;
  final DateTime lastUpdated;

  const NotificationPreferences({
    required this.userId,
    this.paymentReminders = true,
    this.reminderDaysBefore = 3,
    this.adminNotifications = true,
    this.friendRequests = true,
    this.associationInvites = true,
    required this.lastUpdated,
  });

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'paymentReminders': paymentReminders,
      'reminderDaysBefore': reminderDaysBefore,
      'adminNotifications': adminNotifications,
      'friendRequests': friendRequests,
      'associationInvites': associationInvites,
      'lastUpdated': Timestamp.fromDate(lastUpdated),
    };
  }

  factory NotificationPreferences.fromMap(Map<String, dynamic> map) {
    return NotificationPreferences(
      userId: map['userId'] ?? '',
      paymentReminders: map['paymentReminders'] ?? true,
      reminderDaysBefore: map['reminderDaysBefore']?.toInt() ?? 3,
      adminNotifications: map['adminNotifications'] ?? true,
      friendRequests: map['friendRequests'] ?? true,
      associationInvites: map['associationInvites'] ?? true,
      lastUpdated: (map['lastUpdated'] as Timestamp).toDate(),
    );
  }

  NotificationPreferences copyWith({
    String? userId,
    bool? paymentReminders,
    int? reminderDaysBefore,
    bool? adminNotifications,
    bool? friendRequests,
    bool? associationInvites,
    DateTime? lastUpdated,
  }) {
    return NotificationPreferences(
      userId: userId ?? this.userId,
      paymentReminders: paymentReminders ?? this.paymentReminders,
      reminderDaysBefore: reminderDaysBefore ?? this.reminderDaysBefore,
      adminNotifications: adminNotifications ?? this.adminNotifications,
      friendRequests: friendRequests ?? this.friendRequests,
      associationInvites: associationInvites ?? this.associationInvites,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }
}
