import 'package:cloud_firestore/cloud_firestore.dart';

class FinancialCommitmentModel {
  final String id;
  final String userId;
  final String name;
  final double monthlyAmount;
  final String description;
  final DateTime startDate;
  final DateTime endDate;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isDeleted;

  FinancialCommitmentModel({
    required this.id,
    required this.userId,
    required this.name,
    required this.monthlyAmount,
    required this.description,
    required this.startDate,
    required this.endDate,
    required this.createdAt,
    required this.updatedAt,
    required this.isDeleted,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'name': name,
      'monthlyAmount': monthlyAmount,
      'description': description,
      'startDate': Timestamp.fromDate(startDate),
      'endDate': Timestamp.fromDate(endDate),
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'isDeleted': isDeleted,
    };
  }

  factory FinancialCommitmentModel.fromMap(Map<String, dynamic> map) {
    DateTime _parseDate(dynamic value) {
      if (value == null) {
        return DateTime.now();
      }
      if (value is Timestamp) {
        return value.toDate();
      }
      if (value is String) {
        try {
          return DateTime.parse(value);
        } catch (e) {
          print('Error parsing date string: $value');
          return DateTime.now();
        }
      }
      print('Invalid date format: $value');
      return DateTime.now();
    }

    try {
      return FinancialCommitmentModel(
        id: map['id'] as String? ?? '',
        userId: map['userId'] as String? ?? '',
        name: map['name'] as String? ?? '',
        monthlyAmount: (map['monthlyAmount'] as num?)?.toDouble() ?? 0.0,
        description: map['description'] as String? ?? '',
        startDate: _parseDate(map['startDate']),
        endDate: _parseDate(map['endDate']),
        createdAt: _parseDate(map['createdAt']),
        updatedAt: _parseDate(map['updatedAt']),
        isDeleted: map['isDeleted'] as bool? ?? false,
      );
    } catch (e) {
      print('Error creating FinancialCommitmentModel: $e');
      print('Map data: $map');
      rethrow;
    }
  }

  DateTime getNextPaymentDate() {
    final now = DateTime.now();
    final currentMonth = DateTime(now.year, now.month, 1);

    if (currentMonth.isBefore(startDate)) {
      return startDate;
    }

    if (currentMonth.isAfter(endDate)) {
      return endDate;
    }

    return currentMonth;
  }

  int getDaysUntilPayment() {
    final nextPayment = getNextPaymentDate();
    return nextPayment.difference(DateTime.now()).inDays;
  }

  double getTotalRemainingAmount() {
    final now = DateTime.now();
    if (now.isAfter(endDate)) return 0;

    final start = now.isBefore(startDate) ? startDate : now;
    final months =
        (endDate.year - start.year) * 12 + endDate.month - start.month;
    return monthlyAmount * months;
  }
}
