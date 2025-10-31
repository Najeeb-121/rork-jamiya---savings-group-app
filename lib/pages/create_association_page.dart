import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../models/association_model.dart';
import '../models/user_model.dart';
import '../models/currency.dart';
import '../services/firestore_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import '../providers/language_provider.dart';
import '../providers/currency_provider.dart';

class CreateAssociationPage extends StatefulWidget {
  final UserModel userData;

  const CreateAssociationPage({
    super.key,
    required this.userData,
  });

  @override
  State<CreateAssociationPage> createState() => _CreateAssociationPageState();
}

class _CreateAssociationPageState extends State<CreateAssociationPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _contributionController = TextEditingController();
  final _membersController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _bankAccountController = TextEditingController();
  final _cliqNameController = TextEditingController();
  final _cliqNumberController = TextEditingController();
  final _firestoreService = FirestoreService();
  DateTime _startDate = DateTime.now();
  DateTime _payoutDate = DateTime.now();
  double? _totalAmountPerUser;
  bool _isLoading = false;
  String? _errorMessage;
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
  void initState() {
    super.initState();
    // Add listeners to controllers to update calculations
    _contributionController.addListener(_updateCalculations);
    _membersController.addListener(_updateCalculations);
  }

  void _updateCalculations() {
    final monthlyContribution =
        double.tryParse(_contributionController.text) ?? 0;
    final numberOfMembers = int.tryParse(_membersController.text) ?? 0;

    setState(() {
      if (monthlyContribution > 0 && numberOfMembers > 0) {
        // Total amount per user = (number of members × monthly contribution) - monthly contribution
        _totalAmountPerUser =
            (numberOfMembers * monthlyContribution) - monthlyContribution;

        // Calculate end date based on number of members
        _payoutDate = DateTime(_startDate.year,
            _startDate.month + numberOfMembers, _startDate.day);
      } else {
        _totalAmountPerUser = null;
        _payoutDate = DateTime.now();
      }
    });
  }

  Future<void> _selectDate(BuildContext context, bool isStartDate) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isStartDate ? _startDate : _payoutDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
    );
    if (picked != null && picked != (isStartDate ? _startDate : _payoutDate)) {
      setState(() {
        if (isStartDate) {
          _startDate = picked;
        } else {
          _payoutDate = picked;
        }
        _updateCalculations();
      });
    }
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

  Future<void> _createAssociation() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final monthlyContribution = double.parse(_contributionController.text);
      final numberOfMembers = int.parse(_membersController.text);

      if (numberOfMembers < 2) {
        setState(() {
          _errorMessage = AppLocalizations.of(context)!.error;
          _isLoading = false;
        });
        return;
      }

      final endDate = DateTime(
        _startDate.year,
        _startDate.month + numberOfMembers - 1,
        _startDate.day,
      );

      final association = AssociationModel(
        id: '',
        name: _nameController.text,
        description: _descriptionController.text,
        monthlyContribution: monthlyContribution,
        numberOfMembers: numberOfMembers,
        adminId: widget.userData.uid,
        memberIds: [widget.userData.uid],
        startDate: _startDate,
        endDate: endDate,
        payoutDate: _payoutDate,
        payoutMonths: {},
        payments: {},
        isDrawComplete: false,
        createdAt: DateTime.now(),
        status: 'active',
        bankAccountNumber: _bankAccountController.text.isNotEmpty
            ? _bankAccountController.text
            : null,
        cliqName: _cliqNameController.text.isNotEmpty
            ? _cliqNameController.text
            : null,
        cliqNumber: _cliqNumberController.text.isNotEmpty
            ? _cliqNumberController.text
            : null,
      );

      await _firestoreService.createAssociation(association, context);

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Association created successfully'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = '${AppLocalizations.of(context)!.error}: $e';
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _contributionController.dispose();
    _membersController.dispose();
    _descriptionController.dispose();
    _bankAccountController.dispose();
    _cliqNameController.dispose();
    _cliqNumberController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final languageProvider =
        Provider.of<LanguageProvider>(context, listen: false);
    final isArabic = languageProvider.currentLocale.languageCode == 'ar';

    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.createAssociation),
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        actions: [
          // Debug button
          IconButton(
            icon: const Icon(Icons.bug_report),
            onPressed: () {
              // Pre-fill form with test data
              setState(() {
                _nameController.text = 'Test Association';
                _contributionController.text = '100';
                _membersController.text = '5';
                _startDate = DateTime.now().add(const Duration(days: 30));
                _updateCalculations();
              });
            },
            tooltip: 'Fill test data',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: AppLocalizations.of(context)!.associationName,
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
                controller: _contributionController,
                decoration: InputDecoration(
                  labelText: AppLocalizations.of(context)!.monthlyContribution,
                  border: const OutlineInputBorder(),
                  prefixText: Provider.of<CurrencyProvider>(context)
                          .currentCurrency
                          .symbol +
                      ' ',
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
                controller: _membersController,
                decoration: InputDecoration(
                  labelText: AppLocalizations.of(context)!.numberOfMembers,
                  border: const OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return AppLocalizations.of(context)!.error;
                  }
                  if (int.tryParse(value) == null) {
                    return AppLocalizations.of(context)!.error;
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                decoration: InputDecoration(
                  labelText: AppLocalizations.of(context)!.description,
                  border: const OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              Text(
                AppLocalizations.of(context)!.paymentInformation,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _bankAccountController,
                decoration: InputDecoration(
                  labelText: AppLocalizations.of(context)!.bankAccountNumber,
                  border: const OutlineInputBorder(),
                  helperText: AppLocalizations.of(context)!.optional,
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _cliqNameController,
                decoration: InputDecoration(
                  labelText: AppLocalizations.of(context)!.cliqName,
                  border: const OutlineInputBorder(),
                  helperText: AppLocalizations.of(context)!.optional,
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _cliqNumberController,
                decoration: InputDecoration(
                  labelText: AppLocalizations.of(context)!.cliqNumber,
                  border: const OutlineInputBorder(),
                  helperText: AppLocalizations.of(context)!.optional,
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                title: Text(AppLocalizations.of(context)!.startDate),
                subtitle: Text(_formatDate(context, _startDate)),
                trailing: const Icon(Icons.calendar_today),
                onTap: () => _selectDate(context, true),
              ),
              ListTile(
                title: Text(AppLocalizations.of(context)!.payoutMonth),
                subtitle: Text(_formatDate(context, _payoutDate)),
                trailing: const Icon(Icons.calendar_today),
                onTap: () => _selectDate(context, false),
              ),
              const SizedBox(height: 24),
              if (_errorMessage != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(color: Colors.red),
                    textAlign: TextAlign.center,
                  ),
                ),
              ElevatedButton(
                onPressed: _isLoading ? null : _createAssociation,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : Text(AppLocalizations.of(context)!.create),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.grey,
            fontWeight: FontWeight.w500,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
