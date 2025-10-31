import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/split_payment.dart';

class SplitPaymentService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Create a new split payment request
  Future<void> createSplitPaymentRequest({
    required String userId,
    required String associationId,
    required double amount,
    required String partnerId,
    required double monthlyAmount,
  }) async {
    final splitPayment = SplitPayment(
      id: '', // Will be set by Firestore
      userId: userId,
      associationId: associationId,
      amount: amount,
      paymentType: PaymentType.split,
      splitDetails: SplitDetails(
        partnerId: partnerId,
        status: SplitStatus.pending,
        monthlyAmount: monthlyAmount,
      ),
      status: 'active',
      startDate: DateTime.now(),
      endDate: DateTime.now().add(const Duration(days: 365)), // 1 year default
      totalAmount: amount,
      monthlyPayment: monthlyAmount,
    );

    await _firestore
        .collection('financial_commitments')
        .add(splitPayment.toMap());
  }

  // Accept a split payment request
  Future<void> acceptSplitPaymentRequest(String paymentId) async {
    final paymentRef =
        _firestore.collection('financial_commitments').doc(paymentId);

    await _firestore.runTransaction((transaction) async {
      final paymentDoc = await transaction.get(paymentRef);
      if (!paymentDoc.exists) {
        throw Exception('Payment not found');
      }

      final payment = SplitPayment.fromFirestore(paymentDoc);
      if (payment.splitDetails?.status != SplitStatus.pending) {
        throw Exception('Invalid payment status');
      }

      final updatedSplitDetails = SplitDetails(
        partnerId: payment.splitDetails!.partnerId,
        status: SplitStatus.confirmed,
        monthlyAmount: payment.splitDetails!.monthlyAmount,
      );

      transaction.update(paymentRef, {
        'splitDetails': updatedSplitDetails.toMap(),
      });
    });
  }

  // Reject a split payment request
  Future<void> rejectSplitPaymentRequest(String paymentId) async {
    final paymentRef =
        _firestore.collection('financial_commitments').doc(paymentId);

    await _firestore.runTransaction((transaction) async {
      final paymentDoc = await transaction.get(paymentRef);
      if (!paymentDoc.exists) {
        throw Exception('Payment not found');
      }

      final payment = SplitPayment.fromFirestore(paymentDoc);
      if (payment.splitDetails?.status != SplitStatus.pending) {
        throw Exception('Invalid payment status');
      }

      final updatedSplitDetails = SplitDetails(
        partnerId: payment.splitDetails!.partnerId,
        status: SplitStatus.rejected,
        monthlyAmount: payment.splitDetails!.monthlyAmount,
      );

      transaction.update(paymentRef, {
        'splitDetails': updatedSplitDetails.toMap(),
      });
    });
  }

  // Get all split payment requests for a user
  Stream<List<SplitPayment>> getSplitPaymentRequests(String userId) {
    return _firestore
        .collection('financial_commitments')
        .where('userId', isEqualTo: userId)
        .where('paymentType',
            isEqualTo: PaymentType.split.toString().split('.').last)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => SplitPayment.fromFirestore(doc))
          .toList();
    });
  }

  // Get all pending split payment requests where user is the partner
  Stream<List<SplitPayment>> getPendingSplitRequests(String userId) {
    return _firestore
        .collection('financial_commitments')
        .where('splitDetails.partnerId', isEqualTo: userId)
        .where('splitDetails.status',
            isEqualTo: SplitStatus.pending.toString().split('.').last)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => SplitPayment.fromFirestore(doc))
          .toList();
    });
  }

  // Calculate payout amount for split payments
  Future<Map<String, double>> calculateSplitPayout(String paymentId) async {
    final paymentDoc = await _firestore
        .collection('financial_commitments')
        .doc(paymentId)
        .get();

    if (!paymentDoc.exists) {
      throw Exception('Payment not found');
    }

    final payment = SplitPayment.fromFirestore(paymentDoc);
    if (payment.paymentType != PaymentType.split ||
        payment.splitDetails?.status != SplitStatus.confirmed) {
      throw Exception('Invalid payment type or status');
    }

    // Calculate equal split of the total amount
    final splitAmount = payment.totalAmount / 2;

    return {
      payment.userId: splitAmount,
      payment.splitDetails!.partnerId: splitAmount,
    };
  }
}
