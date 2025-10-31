import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import '../models/association_model.dart';
import '../models/user_model.dart';
import '../services/firestore_service.dart';

class ManageAdminsPage extends StatefulWidget {
  final AssociationModel association;
  final UserModel currentUser;

  const ManageAdminsPage({
    super.key,
    required this.association,
    required this.currentUser,
  });

  @override
  State<ManageAdminsPage> createState() => _ManageAdminsPageState();
}

class _ManageAdminsPageState extends State<ManageAdminsPage> {
  final _firestoreService = FirestoreService();
  late List<UserModel> _members;
  late Map<String, bool> _adminStatus;

  @override
  void initState() {
    super.initState();
    _loadMembers();
  }

  Future<void> _loadMembers() async {
    try {
      final members =
          await _firestoreService.getAssociationMembers(widget.association.id);
      setState(() {
        _members = members;
        _adminStatus = {
          for (var member in members)
            member.uid: widget.association.coAdmins.contains(member.uid),
        };
      });
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

  Future<void> _toggleAdminStatus(UserModel member) async {
    try {
      if (_adminStatus[member.uid] == true) {
        await _firestoreService.removeCoAdmin(
            widget.association.id, member.uid);
      } else {
        await _firestoreService.addCoAdmin(widget.association.id, member.uid);
      }

      setState(() {
        _adminStatus[member.uid] = !_adminStatus[member.uid]!;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _adminStatus[member.uid]!
                  ? '${member.fullName} is now a co-admin'
                  : '${member.fullName} is no longer a co-admin',
            ),
            backgroundColor: Colors.green,
          ),
        );
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.manageAdmins),
      ),
      body: _members == null
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: _members.length,
              itemBuilder: (context, index) {
                final member = _members[index];
                final isMainAdmin = member.uid == widget.association.adminId;
                final isCurrentUser = member.uid == widget.currentUser.uid;

                return ListTile(
                  leading: CircleAvatar(
                    child: Text(member.fullName[0].toUpperCase()),
                  ),
                  title: Text(member.fullName),
                  subtitle: isMainAdmin
                      ? Text(AppLocalizations.of(context)!.admin)
                      : null,
                  trailing: isMainAdmin
                      ? const Icon(Icons.admin_panel_settings)
                      : Checkbox(
                          value: _adminStatus[member.uid] ?? false,
                          onChanged: isCurrentUser
                              ? null
                              : (value) => _toggleAdminStatus(member),
                        ),
                );
              },
            ),
    );
  }
}
