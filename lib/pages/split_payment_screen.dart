import 'package:flutter/material.dart';
import '../models/split_payment.dart';
import '../services/split_payment_service.dart';
import '../widgets/split_payment_request.dart';

class SplitPaymentScreen extends StatefulWidget {
  final String userId;
  final String associationId;

  const SplitPaymentScreen({
    Key? key,
    required this.userId,
    required this.associationId,
  }) : super(key: key);

  @override
  State<SplitPaymentScreen> createState() => _SplitPaymentScreenState();
}

class _SplitPaymentScreenState extends State<SplitPaymentScreen> {
  final SplitPaymentService _service = SplitPaymentService();
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _monthlyAmountController = TextEditingController();
  String? _selectedPartnerId;

  @override
  void dispose() {
    _amountController.dispose();
    _monthlyAmountController.dispose();
    super.dispose();
  }

  Future<void> _createSplitPaymentRequest() async {
    if (_formKey.currentState!.validate()) {
      try {
        await _service.createSplitPaymentRequest(
          userId: widget.userId,
          associationId: widget.associationId,
          amount: double.parse(_amountController.text),
          partnerId: _selectedPartnerId!,
          monthlyAmount: double.parse(_monthlyAmountController.text),
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Split payment request created')),
          );
          _amountController.clear();
          _monthlyAmountController.clear();
          setState(() {
            _selectedPartnerId = null;
          });
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: ${e.toString()}')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Split Payments'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'My Requests'),
              Tab(text: 'Pending Requests'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            // My Requests Tab
            StreamBuilder<List<SplitPayment>>(
              stream: _service.getSplitPaymentRequests(widget.userId),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final payments = snapshot.data!;
                if (payments.isEmpty) {
                  return const Center(child: Text('No split payment requests'));
                }

                return ListView.builder(
                  itemCount: payments.length,
                  itemBuilder: (context, index) {
                    return SplitPaymentRequest(payment: payments[index]);
                  },
                );
              },
            ),
            // Pending Requests Tab
            StreamBuilder<List<SplitPayment>>(
              stream: _service.getPendingSplitRequests(widget.userId),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final payments = snapshot.data!;
                if (payments.isEmpty) {
                  return const Center(child: Text('No pending requests'));
                }

                return ListView.builder(
                  itemCount: payments.length,
                  itemBuilder: (context, index) {
                    return SplitPaymentRequest(payment: payments[index]);
                  },
                );
              },
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () {
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Create Split Payment Request'),
                content: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: _amountController,
                        decoration: const InputDecoration(
                          labelText: 'Total Amount',
                        ),
                        keyboardType: TextInputType.number,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter an amount';
                          }
                          if (double.tryParse(value) == null) {
                            return 'Please enter a valid number';
                          }
                          return null;
                        },
                      ),
                      TextFormField(
                        controller: _monthlyAmountController,
                        decoration: const InputDecoration(
                          labelText: 'Monthly Amount',
                        ),
                        keyboardType: TextInputType.number,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter a monthly amount';
                          }
                          if (double.tryParse(value) == null) {
                            return 'Please enter a valid number';
                          }
                          return null;
                        },
                      ),
                      // TODO: Add partner selection dropdown
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  TextButton(
                    onPressed: () {
                      if (_formKey.currentState!.validate()) {
                        _createSplitPaymentRequest();
                        Navigator.pop(context);
                      }
                    },
                    child: const Text('Create'),
                  ),
                ],
              ),
            );
          },
          child: const Icon(Icons.add),
        ),
      ),
    );
  }
}
