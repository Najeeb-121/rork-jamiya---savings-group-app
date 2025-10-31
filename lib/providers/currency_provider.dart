import 'package:flutter/material.dart';
import '../models/currency.dart';

class CurrencyProvider extends ChangeNotifier {
  Currency _currentCurrency = Currency.JOD;

  Currency get currentCurrency => _currentCurrency;

  void setCurrency(Currency currency) {
    if (_currentCurrency != currency) {
      _currentCurrency = currency;
      notifyListeners();
    }
  }

  // Convert amount from JOD to selected currency
  double convertFromJOD(double amount) {
    return amount * _currentCurrency.conversionRate;
  }

  // Convert amount from selected currency to JOD
  double convertToJOD(double amount) {
    return amount / _currentCurrency.conversionRate;
  }

  // Format amount with currency symbol
  String formatAmount(double amount) {
    return '${amount.toStringAsFixed(2)} ${_currentCurrency.symbol}';
  }
}
