import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import '../models/user_model.dart';
import '../models/country_code.dart';
import '../services/firestore_service.dart';
import '../services/phone_auth_service.dart';
import '../providers/language_provider.dart';
import 'dashboard_page.dart';
import 'sign_up_page.dart';
import '../services/user_service.dart';

class SignInPage extends StatefulWidget {
  const SignInPage({super.key});

  @override
  State<SignInPage> createState() => _SignInPageState();
}

class _SignInPageState extends State<SignInPage> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _codeController = TextEditingController();
  final _firestoreService = FirestoreService();
  final _phoneAuthService = PhoneAuthService();
  final _userService = UserService();
  bool _isLoading = false;
  bool _isCodeSent = false;
  String? _verificationId;
  CountryCode _selectedCountry = CountryCode.countries[0]; // Default to Jordan

  @override
  void initState() {
    super.initState();
    // Check if user is already signed in
    _checkCurrentUser();
  }

  Future<void> _checkCurrentUser() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      await _signInUser(currentUser);
    }
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _verifyPhoneNumber() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // Use the phone number directly with the country code
      String phoneNumber =
          '${_selectedCountry.dialCode}${_phoneController.text.trim()}';

      await _phoneAuthService.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        onCodeSent: (verificationId) {
          setState(() {
            _isLoading = false;
            _isCodeSent = true;
            _verificationId = verificationId;
          });
        },
        onError: (error) {
          setState(() {
            _isLoading = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(error)),
          );
        },
      );
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  Future<void> _signInWithPhoneNumber() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final userCredential = await _phoneAuthService.signInWithPhoneNumber(
        _codeController.text,
      );

      if (userCredential != null) {
        final user = userCredential.user;
        if (user != null) {
          await _signInUser(user);
        }
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  Future<void> _signInUser(User user) async {
    try {
      UserModel? userData = await _userService.getUserData(user.uid);

      if (!mounted) return;

      if (userData == null) {
        // User doesn't exist, navigate to sign up
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (context) => const SignUpPage(),
          ),
          (route) => false,
        );
      } else {
        // User exists, navigate to dashboard
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (context) => DashboardPage(userData: userData),
          ),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    }
  }

  void _showCountryCodePicker() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Country'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: CountryCode.countries.length,
            itemBuilder: (context, index) {
              final country = CountryCode.countries[index];
              return ListTile(
                leading: Text(country.flag),
                title: Text(country.name),
                subtitle: Text(country.dialCode),
                onTap: () {
                  setState(() {
                    _selectedCountry = country;
                  });
                  Navigator.pop(context);
                },
              );
            },
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final languageProvider =
        Provider.of<LanguageProvider>(context, listen: false);
    final isArabic = languageProvider.currentLocale.languageCode == 'ar';

    return WillPopScope(
      onWillPop: () async {
        // Prevent going back if loading
        return !_isLoading;
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(AppLocalizations.of(context)!.signIn),
          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    InkWell(
                      onTap: _isLoading ? null : _showCountryCodePicker,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 16,
                        ),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(_selectedCountry.flag),
                            const SizedBox(width: 8),
                            Text(_selectedCountry.dialCode),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextFormField(
                        controller: _phoneController,
                        enabled: !_isLoading,
                        decoration: InputDecoration(
                          labelText: AppLocalizations.of(context)!.phoneNumber,
                          border: const OutlineInputBorder(),
                          hintText: '798533596',
                        ),
                        keyboardType: TextInputType.phone,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter a phone number';
                          }
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (_isCodeSent) ...[
                  TextFormField(
                    controller: _codeController,
                    enabled: !_isLoading,
                    decoration: InputDecoration(
                      labelText: 'Verification Code',
                      border: const OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter the verification code';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                ],
                ElevatedButton(
                  onPressed: _isLoading
                      ? null
                      : _isCodeSent
                          ? _signInWithPhoneNumber
                          : _verifyPhoneNumber,
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 50),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator()
                      : Text(_isCodeSent
                          ? AppLocalizations.of(context)!.signIn
                          : 'Send Verification Code'),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: _isLoading
                      ? null
                      : () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const SignUpPage(),
                            ),
                          );
                        },
                  child: Text(AppLocalizations.of(context)!.dontHaveAccount),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
