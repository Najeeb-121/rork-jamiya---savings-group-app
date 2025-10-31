import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import '../models/user_model.dart';
import '../models/notification_preferences.dart';
import '../services/firestore_service.dart';
import 'package:provider/provider.dart';
import '../providers/language_provider.dart';
import '../providers/theme_provider.dart';
import '../providers/currency_provider.dart';
import '../models/currency.dart';

class SettingsPage extends StatefulWidget {
  final UserModel currentUser;

  const SettingsPage({
    super.key,
    required this.currentUser,
  });

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _firestoreService = FirestoreService();
  late NotificationPreferences _preferences;
  bool _isLoading = true;
  String _selectedLanguage = 'en';
  Currency _selectedCurrency = Currency.JOD;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadAppSettings();
  }

  Future<void> _loadPreferences() async {
    try {
      final preferences = await _firestoreService
          .getNotificationPreferences(widget.currentUser.uid);
      if (preferences != null) {
        setState(() {
          _preferences = preferences;
          _isLoading = false;
        });
      } else {
        setState(() {
          _preferences = NotificationPreferences(
            userId: widget.currentUser.uid,
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
        setState(() {
          _preferences = NotificationPreferences(
            userId: widget.currentUser.uid,
            lastUpdated: DateTime.now(),
          );
          _isLoading = false;
        });
      }
    }
  }

  void _loadAppSettings() {
    setState(() {
      _selectedLanguage = Provider.of<LanguageProvider>(context, listen: false)
          .currentLocale
          .languageCode;
      _selectedCurrency =
          Provider.of<CurrencyProvider>(context, listen: false).currentCurrency;
    });
  }

  Future<void> _updatePreference(String key, dynamic value) async {
    try {
      await _firestoreService.updateUserPreferences(
        userId: widget.currentUser.uid,
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

  Future<void> _updateLanguage(String language) async {
    try {
      await Provider.of<LanguageProvider>(context, listen: false)
          .changeLanguage(language);
      setState(() {
        _selectedLanguage = language;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  Future<void> _updateCurrency(Currency currency) async {
    try {
      Provider.of<CurrencyProvider>(context, listen: false)
          .setCurrency(currency);
      setState(() {
        _selectedCurrency = currency;
      });
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
        title: Text(AppLocalizations.of(context)!.settings),
      ),
      body: ListView(
        children: [
          // App Settings Section
          ListTile(
            title: Text(
              AppLocalizations.of(context)!.appSettings,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          Consumer<ThemeProvider>(
            builder: (context, themeProvider, child) {
              return SwitchListTile(
                title: Text(AppLocalizations.of(context)!.darkMode),
                value: themeProvider.isDarkMode,
                onChanged: (value) {
                  themeProvider.toggleTheme();
                },
              );
            },
          ),
          ListTile(
            title: Text(AppLocalizations.of(context)!.language),
            trailing: DropdownButton<String>(
              value: _selectedLanguage,
              items: [
                DropdownMenuItem(
                  value: 'en',
                  child: Text(AppLocalizations.of(context)!.english),
                ),
                DropdownMenuItem(
                  value: 'ar',
                  child: Text(AppLocalizations.of(context)!.arabic),
                ),
              ],
              onChanged: (value) {
                if (value != null) {
                  _updateLanguage(value);
                }
              },
            ),
          ),
          ListTile(
            title: Text(AppLocalizations.of(context)!.currency),
            trailing: DropdownButton<Currency>(
              value: _selectedCurrency,
              items: [
                DropdownMenuItem(
                  value: Currency.JOD,
                  child: Text(
                      '${AppLocalizations.of(context)!.jordanianDinar} (JOD)'),
                ),
                DropdownMenuItem(
                  value: Currency.SAR,
                  child:
                      Text('${AppLocalizations.of(context)!.saudiRiyal} (SAR)'),
                ),
                DropdownMenuItem(
                  value: Currency.AED,
                  child: Text(
                      '${AppLocalizations.of(context)!.emiratiDirham} (AED)'),
                ),
              ],
              onChanged: (value) {
                if (value != null) {
                  _updateCurrency(value);
                }
              },
            ),
          ),
          const Divider(),

          // Notification Settings Section
          ListTile(
            title: Text(
              AppLocalizations.of(context)!.notificationSettings,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
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
