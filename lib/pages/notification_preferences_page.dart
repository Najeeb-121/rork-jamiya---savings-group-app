import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import '../models/notification_preferences.dart';
import '../services/firestore_service.dart';

class NotificationPreferencesPage extends StatefulWidget {
  final String userId;

  const NotificationPreferencesPage({
    super.key,
    required this.userId,
  });

  @override
  State<NotificationPreferencesPage> createState() =>
      _NotificationPreferencesPageState();
}

class _NotificationPreferencesPageState
    extends State<NotificationPreferencesPage> {
  final _firestoreService = FirestoreService();
  late NotificationPreferences _preferences;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    try {
      final preferences =
          await _firestoreService.getNotificationPreferences(widget.userId);
      if (preferences != null) {
        setState(() {
          _preferences = preferences;
          _isLoading = false;
        });
      } else {
        // Create default preferences if none exist
        setState(() {
          _preferences = NotificationPreferences(
            userId: widget.userId,
            lastUpdated: DateTime.now(),
          );
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${AppLocalizations.of(context)!.error}: $e'),
            backgroundColor: Colors.red,
          ),
        );
        // Set default preferences even if there's an error
        setState(() {
          _preferences = NotificationPreferences(
            userId: widget.userId,
            lastUpdated: DateTime.now(),
          );
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _updatePreference(String key, dynamic value) async {
    try {
      await _firestoreService.updateUserPreferences(
        userId: widget.userId,
        preferences: {key: value},
      );
      setState(() {
        _preferences = _preferences.copyWith(
          paymentReminders:
              key == 'paymentReminders' ? value : _preferences.paymentReminders,
          reminderDaysBefore: key == 'reminderDaysBefore'
              ? value
              : _preferences.reminderDaysBefore,
          adminNotifications: key == 'adminNotifications'
              ? value
              : _preferences.adminNotifications,
          friendRequests:
              key == 'friendRequests' ? value : _preferences.friendRequests,
          associationInvites: key == 'associationInvites'
              ? value
              : _preferences.associationInvites,
          lastUpdated: DateTime.now(),
        );
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(AppLocalizations.of(context)!.preferencesUpdated)),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.notifications),
      ),
      body: ListView(
        children: [
          SwitchListTile(
            title: Text(AppLocalizations.of(context)!.paymentReminders),
            subtitle: Text(
                '${AppLocalizations.of(context)!.remindMe} ${_preferences.reminderDaysBefore} ${AppLocalizations.of(context)!.daysBeforePayment}'),
            value: _preferences.paymentReminders,
            onChanged: (value) => _updatePreference('paymentReminders', value),
          ),
          ListTile(
            title: Text(AppLocalizations.of(context)!.reminderDaysBefore),
            trailing: DropdownButton<int>(
              value: _preferences.reminderDaysBefore,
              items: [1, 2, 3, 5, 7].map((days) {
                return DropdownMenuItem<int>(
                  value: days,
                  child: Text('$days ${AppLocalizations.of(context)!.days}'),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  _updatePreference('reminderDaysBefore', value);
                }
              },
            ),
          ),
          SwitchListTile(
            title: Text(AppLocalizations.of(context)!.adminNotifications),
            value: _preferences.adminNotifications,
            onChanged: (value) =>
                _updatePreference('adminNotifications', value),
          ),
          SwitchListTile(
            title: Text(AppLocalizations.of(context)!.friendRequests),
            value: _preferences.friendRequests,
            onChanged: (value) => _updatePreference('friendRequests', value),
          ),
          SwitchListTile(
            title: Text(AppLocalizations.of(context)!.associationInvites),
            value: _preferences.associationInvites,
            onChanged: (value) =>
                _updatePreference('associationInvites', value),
          ),
        ],
      ),
    );
  }
}
