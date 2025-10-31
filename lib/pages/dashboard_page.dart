import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import '../models/association_model.dart';
import '../models/user_model.dart';
import '../models/currency.dart';
import '../services/user_service.dart';
import '../services/financial_commitment_service.dart';
import '../providers/language_provider.dart';
import '../providers/currency_provider.dart';
import 'create_association_page.dart';
import 'association_details_page.dart';
import 'financial_commitments_page.dart';
import 'invitations_page.dart';
import 'notifications_page.dart';
import 'friends_page.dart';
import 'search_users_page.dart';
import 'profile_page.dart';
import 'notification_preferences_page.dart';
import 'settings_page.dart';
import 'sign_in_page.dart';
import '../services/phone_auth_service.dart';

class DashboardPage extends StatefulWidget {
  final UserModel userData;

  const DashboardPage({
    super.key,
    required this.userData,
  });

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final _userService = UserService();
  final _commitmentService = FinancialCommitmentService();
  final _auth = FirebaseAuth.instance;
  late NumberFormat _currencyFormat;
  int _currentIndex = 0;

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

  Future<List<AssociationModel>> _loadUserAssociations() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('associations')
          .where('memberIds', arrayContains: widget.userData.uid)
          .get();

      return snapshot.docs
          .map((doc) => AssociationModel.fromMap({
                'id': doc.id,
                ...doc.data(),
              }))
          .toList();
    } catch (e) {
      print('Error loading associations: $e');
      return [];
    }
  }

  Widget _buildAssociationCard(AssociationModel association) {
    final now = DateTime.now();
    final monthsPassed = association.startDate.difference(now).inDays ~/ 30;
    final userPayoutMonth = association.payoutMonths[widget.userData.uid];
    final isAdmin = association.adminId == widget.userData.uid;
    final languageProvider =
        Provider.of<LanguageProvider>(context, listen: false);
    final isArabic = languageProvider.currentLocale.languageCode == 'ar';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Card(
        child: InkWell(
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => AssociationDetailsPage(
                  association: association,
                  currentUser: widget.userData,
                ),
              ),
            );
          },
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
                        association.name,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    if (isAdmin)
                      const Padding(
                        padding: EdgeInsets.only(left: 8),
                        child: Icon(Icons.admin_panel_settings,
                            color: Colors.blue),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '${AppLocalizations.of(context)!.monthlyContribution}: ${_formatAmount(association.monthlyContribution)}',
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 4),
                Text(
                  '${AppLocalizations.of(context)!.members}: ${isArabic ? _convertToArabicNumbers('${association.memberIds.length}/${association.numberOfMembers}') : '${association.memberIds.length}/${association.numberOfMembers}'}',
                  style: const TextStyle(fontSize: 16),
                ),
                if (userPayoutMonth != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      '${AppLocalizations.of(context)!.yourPayoutMonth}: ${_getMonthName(userPayoutMonth)}',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (isAdmin)
                      TextButton.icon(
                        onPressed: () =>
                            _showDeleteAssociationDialog(association),
                        icon: const Icon(Icons.delete),
                        label: Text(
                            AppLocalizations.of(context)!.deleteAssociation),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.red,
                        ),
                      )
                    else
                      TextButton.icon(
                        onPressed: () =>
                            _showLeaveAssociationDialog(association),
                        icon: const Icon(Icons.exit_to_app),
                        label: Text(
                            AppLocalizations.of(context)!.leaveAssociation),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.red,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoColumn(String label, String value) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryRow(String label, String value) {
    final languageProvider =
        Provider.of<LanguageProvider>(context, listen: false);
    final isArabic = languageProvider.currentLocale.languageCode == 'ar';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
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
            isArabic ? _convertToArabicNumbers(value) : value,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
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

    return DateFormat('MMM d, y').format(date);
  }

  Widget _buildPaymentSummary() {
    return FutureBuilder<Map<String, dynamic>>(
      future:
          _commitmentService.getUpcomingPaymentsSummary(widget.userData.uid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Text('Error: ${snapshot.error}'),
          );
        }

        final summary = snapshot.data!;
        final nextPaymentDate = summary['nextPaymentDate'] as DateTime?;
        final nextPaymentAmount = summary['nextPaymentAmount'] as double;
        final daysUntilPayment = summary['daysUntilPayment'] as int;
        final totalMonthlyAmount = summary['totalMonthlyCommitments'] as double;
        final totalRemainingAmount = summary['totalRemainingAmount'] as double;

        return Padding(
          padding: const EdgeInsets.all(16),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        AppLocalizations.of(context)!.paymentSummary,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      IconButton(
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: Text(AppLocalizations.of(context)!.create),
                              content: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  ListTile(
                                    leading: const Icon(Icons.group),
                                    title: Text(AppLocalizations.of(context)!
                                        .createAssociation),
                                    onTap: () {
                                      Navigator.pop(context);
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) =>
                                              CreateAssociationPage(
                                            userData: widget.userData,
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                  ListTile(
                                    leading: const Icon(Icons.payment),
                                    title: Text(AppLocalizations.of(context)!
                                        .addCommitment),
                                    onTap: () {
                                      Navigator.pop(context);
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) =>
                                              FinancialCommitmentsPage(
                                            currentUser: widget.userData,
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                        icon: const Icon(Icons.add),
                        tooltip: AppLocalizations.of(context)!.create,
                      ),
                    ],
                  ),
                  const Divider(),
                  if (nextPaymentDate != null) ...[
                    _buildSummaryRow(
                      AppLocalizations.of(context)!.nextPayment,
                      '${_formatAmount(nextPaymentAmount)} ${AppLocalizations.of(context)!.on} ${_formatDate(context, nextPaymentDate)}',
                    ),
                    _buildSummaryRow(
                      AppLocalizations.of(context)!.daysUntilPayment,
                      daysUntilPayment.toString(),
                    ),
                  ],
                  _buildSummaryRow(
                    AppLocalizations.of(context)!.totalMonthlyCommitments,
                    _formatAmount(totalMonthlyAmount),
                  ),
                  _buildSummaryRow(
                    AppLocalizations.of(context)!.totalRemainingAmount,
                    _formatAmount(totalRemainingAmount),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _showDeleteAssociationDialog(
      AssociationModel association) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.deleteAssociation),
        content: Text(
          AppLocalizations.of(context)!.deleteAssociationConfirm,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(AppLocalizations.of(context)!.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              AppLocalizations.of(context)!.delete,
              style: const TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await FirebaseFirestore.instance
            .collection('associations')
            .doc(association.id)
            .delete();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(AppLocalizations.of(context)!.associationDeleted),
              backgroundColor: Colors.green,
            ),
          );
          setState(() {}); // Refresh the list
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${AppLocalizations.of(context)!.error}: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _showLeaveAssociationDialog(AssociationModel association) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.leaveAssociation),
        content: Text(
          AppLocalizations.of(context)!.leaveAssociationConfirm,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(AppLocalizations.of(context)!.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              AppLocalizations.of(context)!.leaveAssociation,
              style: const TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final batch = FirebaseFirestore.instance.batch();

        // Remove user from association members
        final memberIds = List<String>.from(association.memberIds);
        memberIds.remove(widget.userData.uid);
        batch.update(
          FirebaseFirestore.instance
              .collection('associations')
              .doc(association.id),
          {'memberIds': memberIds},
        );

        // Remove association from user's associations list
        batch.update(
          FirebaseFirestore.instance
              .collection('users')
              .doc(widget.userData.uid),
          {
            'associations': FieldValue.arrayRemove([association.id])
          },
        );

        await batch.commit();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(AppLocalizations.of(context)!.leftAssociation),
              backgroundColor: Colors.green,
            ),
          );
          setState(() {}); // Refresh the list
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${AppLocalizations.of(context)!.error}: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  String _convertToArabicNumbers(String input) {
    const english = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];
    const arabic = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
    for (int i = 0; i < english.length; i++) {
      input = input.replaceAll(english[i], arabic[i]);
    }
    return input;
  }

  String _getMonthName(int month) {
    switch (month) {
      case 1:
        return AppLocalizations.of(context)!.january;
      case 2:
        return AppLocalizations.of(context)!.february;
      case 3:
        return AppLocalizations.of(context)!.march;
      case 4:
        return AppLocalizations.of(context)!.april;
      case 5:
        return AppLocalizations.of(context)!.may;
      case 6:
        return AppLocalizations.of(context)!.june;
      case 7:
        return AppLocalizations.of(context)!.july;
      case 8:
        return AppLocalizations.of(context)!.august;
      case 9:
        return AppLocalizations.of(context)!.september;
      case 10:
        return AppLocalizations.of(context)!.october;
      case 11:
        return AppLocalizations.of(context)!.november;
      case 12:
        return AppLocalizations.of(context)!.december;
      default:
        return '';
    }
  }

  Future<void> _showLanguageSelectionDialog(BuildContext context) async {
    final languageProvider =
        Provider.of<LanguageProvider>(context, listen: false);
    final isEnglish = languageProvider.currentLocale.languageCode == 'en';

    final selected = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.language),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.language),
              title: Text(AppLocalizations.of(context)!.english),
              selected: isEnglish,
              onTap: () => Navigator.pop(context, 'en'),
            ),
            ListTile(
              leading: const Icon(Icons.language),
              title: Text(AppLocalizations.of(context)!.arabic),
              selected: !isEnglish,
              onTap: () => Navigator.pop(context, 'ar'),
            ),
          ],
        ),
      ),
    );

    if (selected != null) {
      languageProvider.changeLanguage(selected);
      Navigator.pop(context); // Close drawer
    }
  }

  Future<void> _showCurrencySelectionDialog(BuildContext context) async {
    final currencyProvider =
        Provider.of<CurrencyProvider>(context, listen: false);
    final currentCurrency = currencyProvider.currentCurrency;

    final selected = await showDialog<Currency>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.selectCurrency),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Text('JD'),
              title: Text(AppLocalizations.of(context)!.jordanianDinar),
              selected: currentCurrency == Currency.JOD,
              onTap: () => Navigator.pop(context, Currency.JOD),
            ),
            ListTile(
              leading: const Text('SR'),
              title: Text(AppLocalizations.of(context)!.saudiRiyal),
              selected: currentCurrency == Currency.SAR,
              onTap: () => Navigator.pop(context, Currency.SAR),
            ),
            ListTile(
              leading: const Text('AED'),
              title: Text(AppLocalizations.of(context)!.emiratiDirham),
              selected: currentCurrency == Currency.AED,
              onTap: () => Navigator.pop(context, Currency.AED),
            ),
          ],
        ),
      ),
    );

    if (selected != null) {
      currencyProvider.setCurrency(selected);
      Navigator.pop(context); // Close drawer
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.appTitle),
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircleAvatar(
                    backgroundColor: Colors.white,
                    child: Text(
                      widget.userData.fullName[0].toUpperCase(),
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.userData.fullName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    '@${widget.userData.username}',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.add_circle_outline),
              title: Text(AppLocalizations.of(context)!.createAssociation),
              onTap: () {
                Navigator.of(context).pop(); // Close drawer
                Navigator.of(context)
                    .push(
                  MaterialPageRoute(
                    builder: (context) => CreateAssociationPage(
                      userData: widget.userData,
                    ),
                  ),
                )
                    .then((created) {
                  if (created == true) {
                    setState(() {}); // Refresh the list
                  }
                });
              },
            ),
            ListTile(
              leading: const Icon(Icons.account_balance),
              title: Text(AppLocalizations.of(context)!.financialCommitments),
              onTap: () {
                Navigator.of(context).pop(); // Close drawer
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => FinancialCommitmentsPage(
                      currentUser: widget.userData,
                    ),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.people),
              title: Text(AppLocalizations.of(context)!.friends),
              onTap: () {
                Navigator.of(context).pop(); // Close drawer
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => FriendsPage(
                      currentUser: widget.userData,
                    ),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.mail),
              title: Text(AppLocalizations.of(context)!.invitations),
              onTap: () {
                Navigator.of(context).pop(); // Close drawer
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => InvitationsPage(
                      currentUser: widget.userData,
                    ),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.notifications),
              title: Text(AppLocalizations.of(context)!.notifications),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => NotificationsPage(
                      currentUser: widget.userData,
                    ),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.settings),
              title: Text(AppLocalizations.of(context)!.settings),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => SettingsPage(
                      currentUser: widget.userData,
                    ),
                  ),
                );
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout),
              title: Text(AppLocalizations.of(context)!.logout),
              onTap: () async {
                Navigator.pop(context); // Close drawer

                // Show confirmation dialog
                final shouldLogout = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: Text(AppLocalizations.of(context)!.logout),
                    content: Text('${AppLocalizations.of(context)!.logout}?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: Text(AppLocalizations.of(context)!.cancel),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: Text(
                          AppLocalizations.of(context)!.logout,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),
                    ],
                  ),
                );

                if (shouldLogout == true) {
                  try {
                    // Show loading indicator
                    showDialog(
                      context: context,
                      barrierDismissible: false,
                      builder: (context) => WillPopScope(
                        onWillPop: () async => false,
                        child: const Center(
                          child: CircularProgressIndicator(),
                        ),
                      ),
                    );

                    // Sign out from Firebase
                    await FirebaseAuth.instance.signOut();

                    // Close loading dialog
                    if (mounted && Navigator.canPop(context)) {
                      Navigator.pop(context);
                    }
                  } catch (e) {
                    // Close loading dialog if it's still showing
                    if (mounted && Navigator.canPop(context)) {
                      Navigator.pop(context);
                    }

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
                }
              },
            ),
          ],
        ),
      ),
      body: _currentIndex == 0
          ? FutureBuilder<List<AssociationModel>>(
              future: _loadUserAssociations(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Text('Error: ${snapshot.error}'),
                  );
                }

                final associations = snapshot.data ?? [];

                if (associations.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.group_off,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          AppLocalizations.of(context)!.noAssociations,
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 8),
                        ElevatedButton(
                          onPressed: () {
                            Navigator.of(context)
                                .push(
                              MaterialPageRoute(
                                builder: (context) => CreateAssociationPage(
                                  userData: widget.userData,
                                ),
                              ),
                            )
                                .then((created) {
                              if (created == true) {
                                setState(() {}); // Refresh the list
                              }
                            });
                          },
                          child: Text(
                              AppLocalizations.of(context)!.createAssociation),
                        ),
                      ],
                    ),
                  );
                }

                return ListView(
                  children: [
                    _buildPaymentSummary(),
                    ...associations.map(
                        (association) => _buildAssociationCard(association)),
                  ],
                );
              },
            )
          : ProfilePage(currentUser: widget.userData),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.dashboard),
            label: AppLocalizations.of(context)!.appTitle,
          ),
          NavigationDestination(
            icon: const Icon(Icons.person),
            label: AppLocalizations.of(context)!.profile,
          ),
        ],
      ),
      floatingActionButton: null,
    );
  }
}
