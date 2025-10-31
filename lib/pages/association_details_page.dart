import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import '../models/association_model.dart';
import '../models/user_model.dart';
import '../models/payment_status.dart';
import '../models/currency.dart';
import '../services/firestore_service.dart';
import '../providers/language_provider.dart';
import '../providers/currency_provider.dart';
import '../widgets/user_details_dialog.dart';

class AssociationDetailsPage extends StatefulWidget {
  final AssociationModel association;
  final UserModel currentUser;

  const AssociationDetailsPage({
    super.key,
    required this.association,
    required this.currentUser,
  });

  @override
  State<AssociationDetailsPage> createState() => _AssociationDetailsPageState();
}

class _AssociationDetailsPageState extends State<AssociationDetailsPage> {
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

  bool get isAdmin => widget.association.adminId == widget.currentUser.uid;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.association.name),
          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
          bottom: TabBar(
            tabs: [
              Tab(text: AppLocalizations.of(context)!.details),
              Tab(text: AppLocalizations.of(context)!.members),
              Tab(text: AppLocalizations.of(context)!.payments),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildInfoCard(),
                  const SizedBox(height: 16),
                  _buildStatusCard(),
                  const SizedBox(height: 16),
                  _buildPaymentInformation(),
                  const SizedBox(height: 16),
                  if (isAdmin) ...[
                    const SizedBox(height: 16),
                    _buildAdminActions(),
                  ],
                ],
              ),
            ),
            _buildMembersTab(),
            _buildPaymentsTab(),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppLocalizations.of(context)!.associationInformation,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const Divider(),
            _buildInfoRow(
              AppLocalizations.of(context)!.monthlyContribution,
              _formatAmount(widget.association.monthlyContribution),
            ),
            _buildInfoRow(
              AppLocalizations.of(context)!.numberOfMembers,
              widget.association.numberOfMembers.toString(),
            ),
            _buildInfoRow(
              AppLocalizations.of(context)!.startDate,
              DateFormat('MMMM yyyy').format(widget.association.startDate),
            ),
            _buildInfoRow(
              AppLocalizations.of(context)!.endDate,
              DateFormat('MMMM yyyy').format(widget.association.endDate),
            ),
            _buildInfoRow(
              AppLocalizations.of(context)!.totalAmount,
              _formatAmount(widget.association.totalAmountPerUser),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppLocalizations.of(context)!.status,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const Divider(),
            _buildInfoRow(
              AppLocalizations.of(context)!.drawStatus,
              widget.association.isDrawComplete
                  ? AppLocalizations.of(context)!.completed
                  : AppLocalizations.of(context)!.pending,
            ),
            if (widget.association.isDrawComplete &&
                widget.association.payoutMonths
                    .containsKey(widget.currentUser.uid)) ...[
              _buildInfoRow(
                AppLocalizations.of(context)!.yourPayoutMonth,
                '${AppLocalizations.of(context)!.month} ${widget.association.payoutMonths[widget.currentUser.uid]}',
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAdminActions() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppLocalizations.of(context)!.adminActions,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const Divider(),
            if (!widget.association.isDrawComplete)
              ElevatedButton.icon(
                onPressed: _performDraw,
                icon: const Icon(Icons.shuffle),
                label: Text(AppLocalizations.of(context)!.performDraw),
              ),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: _showInviteMemberDialog,
              icon: const Icon(Icons.person_add),
              label: Text(AppLocalizations.of(context)!.inviteMembers),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMembersTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestoreService.getMembersStream(widget.association.id),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Text(
                '${AppLocalizations.of(context)!.error}: ${snapshot.error}'),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final members = snapshot.data?.docs.map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              return UserModel.fromMap({
                'uid': doc.id,
                ...data,
              });
            }).toList() ??
            [];

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: members.length,
          itemBuilder: (context, index) {
            final member = members[index];
            final isMemberAdmin = member.uid == widget.association.adminId;

            return Card(
              margin: const EdgeInsets.only(bottom: 16),
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: InkWell(
                onTap: () => _showUserDetails(member),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  member.fullName,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '@${member.username}',
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (isMemberAdmin)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).primaryColor,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    AppLocalizations.of(context)!.admin,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              if (isAdmin && !isMemberAdmin) ...[
                                const SizedBox(width: 8),
                                PopupMenuButton<String>(
                                  icon: const Icon(Icons.more_vert),
                                  onSelected: (value) {
                                    if (value == 'reminder') {
                                      _sendPaymentReminder(member);
                                    } else if (value == 'swap') {
                                      _showSwapMonthDialog(member);
                                    }
                                  },
                                  itemBuilder: (context) => [
                                    PopupMenuItem(
                                      value: 'reminder',
                                      child: Text(AppLocalizations.of(context)!
                                          .sendReminder),
                                    ),
                                    PopupMenuItem(
                                      value: 'swap',
                                      child: Text(AppLocalizations.of(context)!
                                          .swapMonth),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      if (widget.association.isDrawComplete &&
                          widget.association.payoutMonths
                              .containsKey(member.uid)) ...[
                        Text(
                          '${AppLocalizations.of(context)!.payoutMonth}: ${widget.association.payoutMonths[member.uid]}',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _sendPaymentReminder(UserModel member) async {
    try {
      await _firestoreService.sendPaymentReminder(
        widget.association.id,
        member.uid,
        '', // Empty message since it's formatted in the service
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.reminderSent),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print('Error sending reminder: $e');
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

  Widget _buildPaymentsTab() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _loadPayments(),
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

        final payments = snapshot.data ?? [];
        return ListView.builder(
          itemCount: payments.length,
          itemBuilder: (context, index) {
            final payment = payments[index];
            final dueDate = DateTime.parse(payment['dueDate']);
            final isPast = dueDate.isBefore(DateTime.now());
            final status = _getPaymentStatus(payment, widget.currentUser.uid);

            return ListTile(
              title:
                  Text('${AppLocalizations.of(context)!.month} ${index + 1}'),
              subtitle: Text(DateFormat('MMMM yyyy').format(dueDate)),
              trailing: _buildPaymentStatus(status),
              onTap: () => _showPaymentDetails(payment),
            );
          },
        );
      },
    );
  }

  Widget _buildInfoRow(String label, String value) {
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
            value,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentStatus(PaymentStatus status) {
    Color color;
    IconData icon;

    switch (status) {
      case PaymentStatus.completed:
        color = Colors.green;
        icon = Icons.check_circle;
        break;
      case PaymentStatus.partial:
        color = Colors.orange;
        icon = Icons.pending;
        break;
      case PaymentStatus.late:
        color = Colors.red;
        icon = Icons.warning;
        break;
      case PaymentStatus.pending:
      default:
        color = Colors.grey;
        icon = Icons.schedule;
        break;
    }

    return Icon(icon, color: color);
  }

  Future<List<Map<String, dynamic>>> _loadPayments() async {
    try {
      final payments =
          await _firestoreService.getAssociationPayments(widget.association.id);
      return payments;
    } catch (e) {
      print('Error loading payments: $e');
      return [];
    }
  }

  PaymentStatus _getPaymentStatus(Map<String, dynamic> payment, String userId) {
    final payments = payment['payments'] as Map<String, dynamic>?;
    if (payments == null || !payments.containsKey(userId)) {
      final dueDate = DateTime.parse(payment['dueDate']);
      return dueDate.isBefore(DateTime.now())
          ? PaymentStatus.late
          : PaymentStatus.pending;
    }

    return PaymentStatus.values.firstWhere(
      (status) => status.toString() == payments[userId]['status'],
      orElse: () => PaymentStatus.pending,
    );
  }

  void _showPaymentDetails(Map<String, dynamic> payment) async {
    final dueDate = DateTime.parse(payment['dueDate']);
    final month = payment['month'] as int;
    final payments = payment['payments'] as Map<String, dynamic>? ?? {};
    final currentUserStatus =
        _getPaymentStatus(payment, widget.currentUser.uid);
    final isCurrentMonth = month ==
        DateTime.now().difference(widget.association.startDate).inDays ~/ 30 +
            1;

    if (!mounted) return;

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${AppLocalizations.of(context)!.month} $month'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AppLocalizations.of(context)!.paymentInformation,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const Divider(),
                      _buildInfoRow(
                        AppLocalizations.of(context)!.amountDue,
                        _formatAmount(widget.association.monthlyContribution),
                      ),
                      _buildInfoRow(
                        AppLocalizations.of(context)!.dueDate,
                        DateFormat('MMM d, yyyy').format(dueDate),
                      ),
                      _buildInfoRow(
                        AppLocalizations.of(context)!.status,
                        currentUserStatus
                            .toString()
                            .split('.')
                            .last
                            .toUpperCase(),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                AppLocalizations.of(context)!.membersStatus,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: widget.association.memberIds.length,
                  itemBuilder: (context, index) {
                    final memberId = widget.association.memberIds[index];
                    return FutureBuilder<UserModel?>(
                      future: _firestoreService.getUser(memberId),
                      builder: (context, userSnapshot) {
                        if (userSnapshot.connectionState ==
                            ConnectionState.waiting) {
                          return ListTile(
                            leading: const CircularProgressIndicator(),
                            title: Text(AppLocalizations.of(context)!.loading),
                          );
                        }

                        if (userSnapshot.hasError ||
                            userSnapshot.data == null) {
                          return ListTile(
                            leading: const Icon(Icons.error),
                            title: Text(AppLocalizations.of(context)!.error),
                          );
                        }

                        final member = userSnapshot.data!;
                        final memberPayment = payments[memberId];
                        final status = _getPaymentStatus(payment, memberId);
                        final isAdmin = memberId == widget.association.adminId;
                        final payoutMonth =
                            widget.association.payoutMonths[memberId];

                        return ListTile(
                          leading: CircleAvatar(
                            child: Text(member.fullName[0].toUpperCase()),
                          ),
                          title: Text(member.fullName),
                          subtitle: memberPayment != null
                              ? Text(
                                  '${_formatAmount(memberPayment['amount'])} - ${DateFormat('MMM d').format(DateTime.parse(memberPayment['timestamp']))}')
                              : null,
                          trailing: _buildPaymentStatus(status),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppLocalizations.of(context)!.close),
          ),
          if (isCurrentMonth)
            ElevatedButton(
              onPressed: () => _updatePayment(month),
              child: Text(AppLocalizations.of(context)!.updatePayment),
            ),
        ],
      ),
    );
  }

  Future<void> _updatePayment(int month) async {
    final amount = await showDialog<double>(
      context: context,
      builder: (context) => PaymentUpdateDialog(
        monthlyContribution: widget.association.monthlyContribution,
      ),
    );

    if (amount == null || !mounted) return;

    try {
      await _firestoreService.updatePaymentStatus(
        associationId: widget.association.id,
        userId: widget.currentUser.uid,
        month: month,
        amount: amount,
        status: amount >= widget.association.monthlyContribution
            ? PaymentStatus.completed
            : PaymentStatus.partial,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.paymentUpdated),
            backgroundColor: Colors.green,
          ),
        );
        // Refresh the payments tab
        setState(() {});
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

  Future<void> _performDraw() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.performDraw),
        content: Text(AppLocalizations.of(context)!.performDrawConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(AppLocalizations.of(context)!.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(AppLocalizations.of(context)!.confirm),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _firestoreService.performDraw(widget.association.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(AppLocalizations.of(context)!.drawCompleted),
              backgroundColor: Colors.green,
            ),
          );
          setState(() {}); // Refresh the UI
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

  Future<void> _showInviteMemberDialog() async {
    final usernameController = TextEditingController();

    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.inviteMembers),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${widget.association.numberOfMembers - widget.association.memberIds.length} ${AppLocalizations.of(context)!.availableSpots}',
            ),
            const SizedBox(height: 16),
            TextField(
              controller: usernameController,
              decoration: InputDecoration(
                labelText: AppLocalizations.of(context)!.enterUsername,
                border: const OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppLocalizations.of(context)!.cancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, usernameController.text),
            child: Text(AppLocalizations.of(context)!.invite),
          ),
        ],
      ),
    );

    if (result != null) {
      try {
        await _firestoreService.inviteMember(
          widget.association.id,
          result,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(AppLocalizations.of(context)!.invitationSent),
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

  Future<void> _cancelInvitation(Map<String, dynamic> invitation) async {
    try {
      await _firestoreService.declineInvitation(
        invitation['associationId'],
        invitation['userId'],
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.invitationCancelled),
            backgroundColor: Colors.orange,
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

  Future<void> _removeMember(String memberId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.removeMember),
        content: Text(AppLocalizations.of(context)!.removeMemberConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(AppLocalizations.of(context)!.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              AppLocalizations.of(context)!.remove,
              style: const TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final batch = FirebaseFirestore.instance.batch();

        // Remove member from association
        final memberIds = List<String>.from(widget.association.memberIds);
        memberIds.remove(memberId);
        batch.update(
          FirebaseFirestore.instance
              .collection('associations')
              .doc(widget.association.id),
          {'memberIds': memberIds},
        );

        // Remove association from member's associations list
        batch.update(
          FirebaseFirestore.instance.collection('users').doc(memberId),
          {
            'associations': FieldValue.arrayRemove([widget.association.id])
          },
        );

        await batch.commit();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(AppLocalizations.of(context)!.memberRemoved),
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

  void _showSwapMonthDialog(UserModel selectedMember) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.swapMonth),
        content: SizedBox(
          width: double.maxFinite,
          child: FutureBuilder<List<UserModel>>(
            future:
                _firestoreService.getAssociationMembers(widget.association.id),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Text(AppLocalizations.of(context)!.errorLoadingMembers);
              }

              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final members = snapshot.data ?? [];
              final otherMembers =
                  members.where((m) => m.uid != selectedMember.uid).toList();

              if (otherMembers.isEmpty) {
                return Text(AppLocalizations.of(context)!.noOtherMembers);
              }

              return ListView.builder(
                shrinkWrap: true,
                itemCount: otherMembers.length,
                itemBuilder: (context, index) {
                  final member = otherMembers[index];
                  final memberMonth =
                      widget.association.payoutMonths[member.uid];
                  final selectedMonth =
                      widget.association.payoutMonths[selectedMember.uid];

                  return ListTile(
                    title: Text(member.fullName),
                    subtitle: Text(
                      '${AppLocalizations.of(context)!.currentMonth}: ${memberMonth ?? 'Not set'}',
                    ),
                    onTap: () async {
                      try {
                        await _firestoreService.swapMemberMonths(
                          associationId: widget.association.id,
                          member1Id: selectedMember.uid,
                          member2Id: member.uid,
                        );
                        if (mounted) {
                          Navigator.of(context).pop();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                  AppLocalizations.of(context)!.monthsSwapped),
                              backgroundColor: Colors.green,
                            ),
                          );
                        }
                      } catch (e) {
                        if (mounted) {
                          Navigator.of(context).pop();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(AppLocalizations.of(context)!
                                  .errorSwappingMonths),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      }
                    },
                  );
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(AppLocalizations.of(context)!.cancel),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentInformation() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  AppLocalizations.of(context)!.paymentInformation,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                if (isAdmin)
                  IconButton(
                    icon: const Icon(Icons.edit),
                    onPressed: _showEditPaymentInfoDialog,
                  ),
              ],
            ),
            const Divider(),
            if (widget.association.bankAccountNumber != null) ...[
              _buildInfoRow(
                AppLocalizations.of(context)!.bankAccount,
                widget.association.bankAccountNumber!,
              ),
            ],
            if (widget.association.cliqName != null) ...[
              _buildInfoRow(
                AppLocalizations.of(context)!.cliqName,
                widget.association.cliqName!,
              ),
            ],
            if (widget.association.cliqNumber != null) ...[
              _buildInfoRow(
                AppLocalizations.of(context)!.cliqNumber,
                widget.association.cliqNumber!,
              ),
            ],
            if (widget.association.bankAccountNumber == null &&
                widget.association.cliqName == null &&
                widget.association.cliqNumber == null)
              Text(
                AppLocalizations.of(context)!.noPaymentInfo,
                style: TextStyle(color: Colors.grey[600]),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _showEditPaymentInfoDialog() async {
    final bankController =
        TextEditingController(text: widget.association.bankAccountNumber);
    final cliqNameController =
        TextEditingController(text: widget.association.cliqName);
    final cliqNumberController =
        TextEditingController(text: widget.association.cliqNumber);

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.editPaymentInfo),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: bankController,
              decoration: InputDecoration(
                labelText: AppLocalizations.of(context)!.bankAccount,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: cliqNameController,
              decoration: InputDecoration(
                labelText: AppLocalizations.of(context)!.cliqName,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: cliqNumberController,
              decoration: InputDecoration(
                labelText: AppLocalizations.of(context)!.cliqNumber,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppLocalizations.of(context)!.cancel),
          ),
          TextButton(
            onPressed: () async {
              try {
                final bankAccount = bankController.text.trim();
                final cliqName = cliqNameController.text.trim();
                final cliqNumber = cliqNumberController.text.trim();

                await _firestoreService.updatePaymentInfo(
                  widget.association.id,
                  bankAccountNumber:
                      bankAccount.isNotEmpty ? bankAccount : null,
                  cliqName: cliqName.isNotEmpty ? cliqName : null,
                  cliqNumber: cliqNumber.isNotEmpty ? cliqNumber : null,
                );

                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                          AppLocalizations.of(context)!.paymentInfoUpdated),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
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
            child: Text(AppLocalizations.of(context)!.save),
          ),
        ],
      ),
    );
  }

  void _showUserDetails(UserModel user) {
    showDialog(
      context: context,
      builder: (context) => UserDetailsDialog(
        currentUser: widget.currentUser,
        targetUser: user,
        associationId: widget.association.id,
        isAdmin: widget.association.isAdmin,
      ),
    );
  }
}

class PaymentUpdateDialog extends StatefulWidget {
  final double monthlyContribution;

  const PaymentUpdateDialog({
    super.key,
    required this.monthlyContribution,
  });

  @override
  State<PaymentUpdateDialog> createState() => _PaymentUpdateDialogState();
}

class _PaymentUpdateDialogState extends State<PaymentUpdateDialog> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
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

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currencyProvider = Provider.of<CurrencyProvider>(context);
    return AlertDialog(
      title: Text(AppLocalizations.of(context)!.updatePayment),
      content: Form(
        key: _formKey,
        child: TextFormField(
          controller: _amountController,
          decoration: InputDecoration(
            labelText: AppLocalizations.of(context)!.amount,
            border: const OutlineInputBorder(),
            prefixText: '${currencyProvider.currentCurrency.symbol} ',
          ),
          keyboardType: TextInputType.number,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return AppLocalizations.of(context)!.error;
            }
            final amount = double.tryParse(value);
            if (amount == null) {
              return AppLocalizations.of(context)!.error;
            }
            if (amount > widget.monthlyContribution) {
              return AppLocalizations.of(context)!.amountTooHigh;
            }
            return null;
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(AppLocalizations.of(context)!.cancel),
        ),
        ElevatedButton(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              Navigator.pop(
                context,
                double.parse(_amountController.text),
              );
            }
          },
          child: Text(AppLocalizations.of(context)!.confirm),
        ),
      ],
    );
  }
}
