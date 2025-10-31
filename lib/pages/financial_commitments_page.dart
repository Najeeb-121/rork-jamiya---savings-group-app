import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import '../models/user_model.dart';
import '../models/financial_commitment_model.dart';
import '../models/currency.dart';
import '../services/financial_commitment_service.dart';
import '../providers/language_provider.dart';
import '../providers/currency_provider.dart';
import 'package:intl/intl.dart';
import 'split_payment_screen.dart';

class FinancialCommitmentsPage extends StatefulWidget {
  final UserModel currentUser;

  const FinancialCommitmentsPage({
    super.key,
    required this.currentUser,
  });

  @override
  State<FinancialCommitmentsPage> createState() =>
      _FinancialCommitmentsPageState();
}

class _FinancialCommitmentsPageState extends State<FinancialCommitmentsPage> {
  final _commitmentService = FinancialCommitmentService();
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

  String _formatDate(BuildContext context, DateTime date) {
    final languageProvider =
        Provider.of<LanguageProvider>(context, listen: false);
    final isArabic = languageProvider.currentLocale.languageCode == 'ar';

    if (isArabic) {
      final arabicMonths = [
        'يناير',
        'فبراير',
        'مارس',
        'إبريل',
        'مايو',
        'يونيو',
        'يوليو',
        'أغسطس',
        'سبتمبر',
        'أكتوبر',
        'نوفمبر',
        'ديسمبر'
      ];
      return '${date.day} ${arabicMonths[date.month - 1]} ${date.year}';
    }

    return '${date.day}/${date.month}/${date.year}';
  }

  Future<void> _showAddCommitmentDialog() async {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController();
    final amountController = TextEditingController();
    final descriptionController = TextEditingController();
    DateTime startDate = DateTime.now();
    DateTime endDate = DateTime.now().add(const Duration(days: 365));

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(AppLocalizations.of(context)!.addCommitment),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: nameController,
                    decoration: InputDecoration(
                      labelText: AppLocalizations.of(context)!.commitmentName,
                      border: const OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return AppLocalizations.of(context)!.error;
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: amountController,
                    decoration: InputDecoration(
                      labelText: AppLocalizations.of(context)!.monthlyAmount,
                      border: const OutlineInputBorder(),
                      prefixText:
                          '${Provider.of<CurrencyProvider>(context).currentCurrency.symbol} ',
                    ),
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return AppLocalizations.of(context)!.error;
                      }
                      if (double.tryParse(value) == null) {
                        return AppLocalizations.of(context)!.error;
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: descriptionController,
                    decoration: InputDecoration(
                      labelText: AppLocalizations.of(context)!.description,
                      border: const OutlineInputBorder(),
                    ),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 16),
                  ListTile(
                    title: Text(AppLocalizations.of(context)!.startDate),
                    subtitle: Text(_formatDate(context, startDate)),
                    trailing: const Icon(Icons.calendar_today),
                    onTap: () async {
                      final DateTime? picked = await showDatePicker(
                        context: context,
                        initialDate: startDate,
                        firstDate: DateTime.now(),
                        lastDate:
                            DateTime.now().add(const Duration(days: 365 * 5)),
                      );
                      if (picked != null) {
                        setState(() => startDate = picked);
                      }
                    },
                  ),
                  ListTile(
                    title: Text(AppLocalizations.of(context)!.endDate),
                    subtitle: Text(_formatDate(context, endDate)),
                    trailing: const Icon(Icons.calendar_today),
                    onTap: () async {
                      final DateTime? picked = await showDatePicker(
                        context: context,
                        initialDate: endDate,
                        firstDate: startDate,
                        lastDate:
                            DateTime.now().add(const Duration(days: 365 * 5)),
                      );
                      if (picked != null) {
                        setState(() => endDate = picked);
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(AppLocalizations.of(context)!.cancel),
            ),
            ElevatedButton(
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;

                try {
                  final now = DateTime.now();
                  final commitment = FinancialCommitmentModel(
                    id: '',
                    userId: widget.currentUser.uid,
                    name: nameController.text,
                    monthlyAmount: double.parse(amountController.text),
                    description: descriptionController.text,
                    startDate: startDate,
                    endDate: endDate,
                    createdAt: now,
                    updatedAt: now,
                    isDeleted: false,
                  );

                  await _commitmentService.addCommitment(commitment);

                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(AppLocalizations.of(context)!.success),
                        backgroundColor: Colors.green,
                      ),
                    );
                    setState(() {}); // Refresh the list
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content:
                            Text('${AppLocalizations.of(context)!.error}: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              child: Text(AppLocalizations.of(context)!.addCommitment),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.financialCommitments),
        actions: [
          IconButton(
            icon: const Icon(Icons.account_balance_wallet),
            tooltip: 'Split Payments',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => SplitPaymentScreen(
                    userId: widget.currentUser.uid,
                    associationId: widget.currentUser.associations
                        .first, // Assuming user has at least one association
                  ),
                ),
              );
            },
          ),
        ],
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
      ),
      body: FutureBuilder<List<FinancialCommitmentModel>>(
        future: _commitmentService.getUserCommitments(widget.currentUser.uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Text(
                  '${AppLocalizations.of(context)!.error}: ${snapshot.error}'),
            );
          }

          final commitments = snapshot.data ?? [];

          if (commitments.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.account_balance_wallet_outlined,
                    size: 64,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    AppLocalizations.of(context)!.noCommitments,
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
            padding: const EdgeInsets.all(16),
            itemCount: commitments.length,
            itemBuilder: (context, index) {
              final commitment = commitments[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 16),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              commitment.name,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete),
                            color: Colors.red,
                            onPressed: () async {
                              try {
                                await _commitmentService
                                    .deleteCommitment(commitment.id);
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                          AppLocalizations.of(context)!
                                              .success),
                                      backgroundColor: Colors.green,
                                    ),
                                  );
                                  setState(() {}); // Refresh the list
                                }
                              } catch (e) {
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                          '${AppLocalizations.of(context)!.error}: $e'),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                }
                              }
                            },
                          ),
                        ],
                      ),
                      if (commitment.description.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          commitment.description,
                          style: TextStyle(
                            color: Colors.grey[600],
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 2,
                        ),
                      ],
                      const SizedBox(height: 16),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final isNarrow = constraints.maxWidth < 300;
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${AppLocalizations.of(context)!.monthlyAmount}: ${_formatAmount(commitment.monthlyAmount)}',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w500),
                              ),
                              const SizedBox(height: 8),
                              if (isNarrow) ...[
                                Text(
                                  '${AppLocalizations.of(context)!.startDate}: ${_formatDate(context, commitment.startDate)}',
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 12,
                                  ),
                                ),
                                Text(
                                  '${AppLocalizations.of(context)!.endDate}: ${_formatDate(context, commitment.endDate)}',
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  '${AppLocalizations.of(context)!.nextPayment}: ${_formatDate(context, commitment.getNextPaymentDate())}',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w500),
                                ),
                                Text(
                                  '${AppLocalizations.of(context)!.daysUntilPayment}: ${commitment.getDaysUntilPayment()}',
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 12,
                                  ),
                                ),
                              ] else
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '${AppLocalizations.of(context)!.startDate}: ${_formatDate(context, commitment.startDate)}',
                                          style: TextStyle(
                                            color: Colors.grey[600],
                                            fontSize: 12,
                                          ),
                                        ),
                                        Text(
                                          '${AppLocalizations.of(context)!.endDate}: ${_formatDate(context, commitment.endDate)}',
                                          style: TextStyle(
                                            color: Colors.grey[600],
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          '${AppLocalizations.of(context)!.nextPayment}: ${_formatDate(context, commitment.getNextPaymentDate())}',
                                          style: const TextStyle(
                                              fontWeight: FontWeight.w500),
                                        ),
                                        Text(
                                          '${AppLocalizations.of(context)!.daysUntilPayment}: ${commitment.getDaysUntilPayment()}',
                                          style: TextStyle(
                                            color: Colors.grey[600],
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddCommitmentDialog,
        child: const Icon(Icons.add),
      ),
    );
  }
}
