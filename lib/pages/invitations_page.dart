import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import '../models/user_model.dart';
import '../models/currency.dart';
import '../services/firestore_service.dart';
import '../providers/currency_provider.dart';
import 'association_details_page.dart';

class InvitationsPage extends StatefulWidget {
  final UserModel currentUser;

  const InvitationsPage({
    super.key,
    required this.currentUser,
  });

  @override
  State<InvitationsPage> createState() => _InvitationsPageState();
}

class _InvitationsPageState extends State<InvitationsPage> {
  final _firestoreService = FirestoreService();
  late NumberFormat _currencyFormat;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final currencyProvider = Provider.of<CurrencyProvider>(context);
    _currencyFormat = NumberFormat.currency(
      symbol: '${currencyProvider.currentCurrency.symbol} ',
      decimalDigits: 2,
    );
  }

  String _formatAmount(double amount) {
    final currencyProvider =
        Provider.of<CurrencyProvider>(context, listen: false);
    return _currencyFormat.format(currencyProvider.convertFromJOD(amount));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.invitations),
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _firestoreService.getUserInvitations(widget.currentUser.uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Text('Error: ${snapshot.error}'),
            );
          }

          final invitations = snapshot.data ?? [];

          if (invitations.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.mail_outline,
                    size: 64,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    AppLocalizations.of(context)!.noInvitations,
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            itemCount: invitations.length,
            itemBuilder: (context, index) {
              final invitation = invitations[index];
              final timestamp = invitation['timestamp'] as Timestamp?;
              final date = timestamp?.toDate() ?? DateTime.now();

              return Card(
                margin: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        invitation['associationName'] ?? 'Unknown Association',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Monthly Contribution: ${_formatAmount(invitation['monthlyContribution'] ?? 0)}',
                        style: const TextStyle(fontSize: 16),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Invited on: ${DateFormat('MMM d, y').format(date)}',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => _declineInvitation(invitation),
                            child: const Text(
                              'Decline',
                              style: TextStyle(color: Colors.red),
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: () => _acceptInvitation(invitation),
                            child: const Text('Accept'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _acceptInvitation(Map<String, dynamic> invitation) async {
    try {
      final associationId = invitation['associationId'];
      if (associationId == null || associationId.toString().isEmpty) {
        throw Exception('Invalid invitation: missing association ID');
      }

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      await _firestoreService.acceptInvitation(
          associationId, widget.currentUser.uid);

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.invitationAccepted),
            backgroundColor: Colors.green,
          ),
        );
        setState(() {});
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error accepting invitation: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      print('Error accepting invitation: $e');
    }
  }

  Future<void> _declineInvitation(Map<String, dynamic> invitation) async {
    try {
      await _firestoreService.declineInvitation(
        invitation['associationId'],
        widget.currentUser.uid,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Invitation declined'),
            backgroundColor: Colors.orange,
          ),
        );
        setState(() {}); // Refresh the list
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error declining invitation: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
