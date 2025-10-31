import 'package:cloud_firestore/cloud_firestore.dart';

enum PaymentType {
  full,
  split,
}

enum SplitStatus {
  pending,
  confirmed,
  rejected,
}

class SplitPayment {
  final String id;
  final String userId;
  final String associationId;
  final double amount;
  final PaymentType paymentType;
  final SplitDetails? splitDetails;
  final String status;
  final DateTime startDate;
  final DateTime endDate;
  final double totalAmount;
  final double monthlyPayment;

  SplitPayment({
    required this.id,
    required this.userId,
    required this.associationId,
    required this.amount,
    required this.paymentType,
    this.splitDetails,
    required this.status,
    required this.startDate,
    required this.endDate,
    required this.totalAmount,
    required this.monthlyPayment,
  });

  factory SplitPayment.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return SplitPayment(
      id: doc.id,
      userId: data['userId'] ?? '',
      associationId: data['associationId'] ?? '',
      amount: (data['amount'] ?? 0).toDouble(),
      paymentType: PaymentType.values.firstWhere(
        (e) => e.toString() == 'PaymentType.${data['paymentType']}',
        orElse: () => PaymentType.full,
      ),
      splitDetails: data['splitDetails'] != null
          ? SplitDetails.fromMap(data['splitDetails'])
          : null,
      status: data['status'] ?? 'active',
      startDate: (data['startDate'] as Timestamp).toDate(),
      endDate: (data['endDate'] as Timestamp).toDate(),
      totalAmount: (data['totalAmount'] ?? 0).toDouble(),
      monthlyPayment: (data['monthlyPayment'] ?? 0).toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'associationId': associationId,
      'amount': amount,
      'paymentType': paymentType.toString().split('.').last,
      'splitDetails': splitDetails?.toMap(),
      'status': status,
      'startDate': Timestamp.fromDate(startDate),
      'endDate': Timestamp.fromDate(endDate),
      'totalAmount': totalAmount,
      'monthlyPayment': monthlyPayment,
    };
  }
}

class SplitDetails {
  final String partnerId;
  final SplitStatus status;
  final double monthlyAmount;

  SplitDetails({
    required this.partnerId,
    required this.status,
    required this.monthlyAmount,
  });

  factory SplitDetails.fromMap(Map<String, dynamic> map) {
    return SplitDetails(
      partnerId: map['partnerId'] ?? '',
      status: SplitStatus.values.firstWhere(
        (e) => e.toString() == 'SplitStatus.${map['status']}',
        orElse: () => SplitStatus.pending,
      ),
      monthlyAmount: (map['monthlyAmount'] ?? 0).toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'partnerId': partnerId,
      'status': status.toString().split('.').last,
      'monthlyAmount': monthlyAmount,
    };
  }
}
