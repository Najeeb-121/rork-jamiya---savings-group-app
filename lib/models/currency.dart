enum Currency {
  JOD('JD', 1.0),
  SAR('SR', 5.2956),
  AED('AED', 5.1813);

  final String symbol;
  final double conversionRate;

  const Currency(this.symbol, this.conversionRate);
}
