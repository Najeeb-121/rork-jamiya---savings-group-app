class CountryCode {
  final String name;
  final String code;
  final String flag;
  final String dialCode;

  const CountryCode({
    required this.name,
    required this.code,
    required this.flag,
    required this.dialCode,
  });

  static const List<CountryCode> countries = [
    CountryCode(
      name: 'Jordan',
      code: 'JO',
      flag: '🇯🇴',
      dialCode: '+962',
    ),
    CountryCode(
      name: 'Saudi Arabia',
      code: 'SA',
      flag: '🇸🇦',
      dialCode: '+966',
    ),
    CountryCode(
      name: 'UAE',
      code: 'AE',
      flag: '🇦🇪',
      dialCode: '+971',
    ),
  ];
}
