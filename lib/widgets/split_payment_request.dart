import 'package:flutter/material.dart';
import '../models/split_payment.dart';
import '../services/split_payment_service.dart';

class SplitPaymentRequest extends StatelessWidget {
  final SplitPayment payment;
  final SplitPaymentService _service = SplitPaymentService();

  SplitPaymentRequest({Key? key, required this.payment}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(8.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Split Payment Request',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
                'Monthly Amount: \$${payment.monthlyPayment.toStringAsFixed(2)}'),
            Text('Total Amount: \$${payment.totalAmount.toStringAsFixed(2)}'),
            const SizedBox(height: 16),
            if (payment.splitDetails?.status == SplitStatus.pending)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton(
                    onPressed: () async {
                      try {
                        await _service.acceptSplitPaymentRequest(payment.id);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Request accepted')),
                        );
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Error: ${e.toString()}')),
                        );
                      }
                    },
                    child: const Text('Accept'),
                  ),
                  ElevatedButton(
                    onPressed: () async {
                      try {
                        await _service.rejectSplitPaymentRequest(payment.id);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Request rejected')),
                        );
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Error: ${e.toString()}')),
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                    ),
                    child: const Text('Reject'),
                  ),
                ],
              )
            else
              Text(
                'Status: ${payment.splitDetails?.status.toString().split('.').last ?? 'Unknown'}',
                style: TextStyle(
                  color: payment.splitDetails?.status == SplitStatus.confirmed
                      ? Colors.green
                      : Colors.red,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
