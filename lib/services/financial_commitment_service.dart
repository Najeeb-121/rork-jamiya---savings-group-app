import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/financial_commitment_model.dart';

class FinancialCommitmentService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get all commitments for a user
  Future<List<FinancialCommitmentModel>> getUserCommitments(
      String userId) async {
    try {
      print('Fetching commitments for user: $userId');
      final querySnapshot = await _firestore
          .collection('financial_commitments')
          .where('userId', isEqualTo: userId)
          .where('isDeleted', isEqualTo: false)
          .get();

      print('Found ${querySnapshot.docs.length} commitments');
      return querySnapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id; // Ensure the ID is set
        return FinancialCommitmentModel.fromMap(data);
      }).toList();
    } catch (e) {
      print('Error fetching commitments: $e');
      rethrow;
    }
  }

  // Add a new commitment
  Future<void> addCommitment(FinancialCommitmentModel commitment) async {
    try {
      final data = commitment.toMap();
      data.remove('id'); // Remove the id field before creating the document
      data['updatedAt'] = Timestamp.fromDate(DateTime.now());
      data['isDeleted'] = false;

      final docRef =
          await _firestore.collection('financial_commitments').add(data);

      // Update the document with its ID
      await docRef.update({
        'id': docRef.id,
      });
    } catch (e) {
      print('Error adding commitment: $e');
      rethrow;
    }
  }

  // Update a commitment
  Future<void> updateCommitment(FinancialCommitmentModel commitment) async {
    try {
      print('Updating commitment: ${commitment.id}');
      await _firestore
          .collection('financial_commitments')
          .doc(commitment.id)
          .update(commitment.toMap());
      print('Commitment updated successfully');
    } catch (e) {
      print('Error updating commitment: $e');
      rethrow;
    }
  }

  // Delete a commitment (soft delete)
  Future<void> deleteCommitment(String commitmentId) async {
    try {
      print('Deleting commitment: $commitmentId');

      if (commitmentId.isEmpty || commitmentId.trim().isEmpty) {
        print('Error: Empty commitment ID');
        throw Exception('Invalid commitment ID');
      }

      final docRef =
          _firestore.collection('financial_commitments').doc(commitmentId);

      // First check if the document exists
      final doc = await docRef.get();
      if (!doc.exists) {
        print('Error: Document not found');
        throw Exception('Commitment not found');
      }

      // Check if the user owns this commitment
      final data = doc.data();
      if (data == null) {
        print('Error: Document data is null');
        throw Exception('Invalid commitment data');
      }

      final currentUserId = FirebaseAuth.instance.currentUser?.uid;
      if (currentUserId == null) {
        print('Error: No authenticated user');
        throw Exception('User not authenticated');
      }

      if (data['userId'] != currentUserId) {
        print('Error: User does not own this commitment');
        throw Exception('You do not have permission to delete this commitment');
      }

      // Soft delete by updating isDeleted flag
      await docRef.update({'isDeleted': true});
      print('Commitment deleted successfully');
    } catch (e) {
      print('Error deleting commitment: $e');
      rethrow;
    }
  }

  // Get upcoming payments summary
  Future<Map<String, dynamic>> getUpcomingPaymentsSummary(String userId) async {
    try {
      print('Fetching payment summary for user: $userId');
      final commitments = await getUserCommitments(userId);

      if (commitments.isEmpty) {
        return {
          'nextPaymentDate': null,
          'nextPaymentAmount': 0.0,
          'daysUntilPayment': 0,
          'totalMonthlyCommitments': 0.0,
          'totalRemainingAmount': 0.0,
        };
      }

      // Sort commitments by next payment date
      commitments.sort(
          (a, b) => a.getNextPaymentDate().compareTo(b.getNextPaymentDate()));

      final nextCommitment = commitments.first;
      final nextPaymentDate = nextCommitment.getNextPaymentDate();
      final daysUntilPayment = nextCommitment.getDaysUntilPayment();

      final totalMonthlyCommitments = commitments.fold<double>(
        0,
        (sum, commitment) => sum + commitment.monthlyAmount,
      );

      final totalRemainingAmount = commitments.fold<double>(
        0,
        (sum, commitment) => sum + commitment.getTotalRemainingAmount(),
      );

      print('Payment summary calculated successfully');
      return {
        'nextPaymentDate': nextPaymentDate,
        'nextPaymentAmount': nextCommitment.monthlyAmount,
        'daysUntilPayment': daysUntilPayment,
        'totalMonthlyCommitments': totalMonthlyCommitments,
        'totalRemainingAmount': totalRemainingAmount,
      };
    } catch (e) {
      print('Error calculating payment summary: $e');
      rethrow;
    }
  }
}
