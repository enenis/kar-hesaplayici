import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

enum AppCurrency { tl, usd, eur }

extension AppCurrencyX on AppCurrency {
  String get symbol {
    switch (this) {
      case AppCurrency.tl:
        return '₺';
      case AppCurrency.usd:
        return '\$';
      case AppCurrency.eur:
        return '€';
    }
  }

  String get code {
    switch (this) {
      case AppCurrency.tl:
        return 'TRY';
      case AppCurrency.usd:
        return 'USD';
      case AppCurrency.eur:
        return 'EUR';
    }
  }
}

class CurrencyFormatter {
  CurrencyFormatter._();

  static final NumberFormat _numberFormat = NumberFormat.decimalPattern('tr_TR')
    ..maximumFractionDigits = 2
    ..minimumFractionDigits = 2;

  static String format(double value, {AppCurrency currency = AppCurrency.tl}) {
    return '${currency.symbol}${_numberFormat.format(value)}';
  }

  static String percent(double value, {int decimals = 1}) {
    return '%${value.toStringAsFixed(decimals)}';
  }

  /// Binlik ayraçlı (Türkçe gruplu) alanlar için — `ThousandsSeparatorInputFormatter`
  /// kullanan tutar alanlarında (Alış Fiyatı, Kargo, vb.) metin her zaman
  /// "12.500" (nokta = binlik ayraç) veya "12.500,50" (virgül = ondalık)
  /// biçimindedir. Bu metod SADECE bu alanlar için kullanılmalıdır.
  static double parseGrouped(String input) {
    if (input.trim().isEmpty) return 0;
    final normalized = input.trim().replaceAll('.', '').replaceAll(',', '.');
    return double.tryParse(normalized) ?? 0;
  }

  /// Binlik ayraç KULLANMAYAN alanlar için (oranlar, döviz kuru, saat gibi
  /// serbest ondalık girişler). Kullanıcı ondalık ayırıcı olarak nokta ya da
  /// virgülden herhangi birini kullanabilir; TEK bir ayırıcı olduğu ve binlik
  /// gruplama YAPILMADIĞI varsayılır.
  /// Örn: "18.0" -> 18.0, "18,5" -> 18.5, "47.3863" -> 47.3863
  /// (Önceki hatalı davranış: "18.0" noktayı binlik ayraç sayıp 180'e
  /// dönüştürüyordu — bu metod bunu düzeltir.)
  static double parseDecimal(String input) {
    if (input.trim().isEmpty) return 0;
    final normalized = input.trim().replaceAll(',', '.');
    return double.tryParse(normalized) ?? 0;
  }

  /// Geriye dönük uyumluluk için: `parseGrouped` ile aynıdır. Yeni kod
  /// yazarken alanın binlik ayraç kullanıp kullanmadığına göre doğrudan
  /// `parseGrouped` veya `parseDecimal` kullanın.
  static double parse(String input) => parseGrouped(input);

  /// Bir `double` değeri, binlik ayraçlı alanların (Alış Fiyatı, Kargo vb.)
  /// beklediği metin biçimine çevirir — örn. 12500 -> "12.500",
  /// 12500.5 -> "12.500,5". Kayıtlı bir senaryo geri yüklenirken
  /// `TextEditingController.text`'i doldurmak için kullanılır; tam sayı
  /// değerlerde gereksiz ",00" eklemez.
  static String formatForGroupedField(double value) {
    final formatter = NumberFormat.decimalPattern('tr_TR')
      ..maximumFractionDigits = 2
      ..minimumFractionDigits = 0;
    return formatter.format(value);
  }
}

/// Kullanıcı yazarken canlı olarak binlik ayraç ekleyen input formatter.
/// Örn: "12500" -> "12.500", ondalık kısım (varsa) virgülle korunur: "12.500,50".
/// Türkçe sayı formatı kullanır: nokta binlik ayraç, virgül ondalık ayraçtır.
class ThousandsSeparatorInputFormatter extends TextInputFormatter {
  static final NumberFormat _integerFormat = NumberFormat.decimalPattern('tr_TR');

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    var digitsAndComma = newValue.text.replaceAll(RegExp(r'[^0-9,]'), '');

    // Birden fazla virgül girilmesini engelle.
    final firstCommaIndex = digitsAndComma.indexOf(',');
    if (firstCommaIndex != -1) {
      final beforeComma = digitsAndComma.substring(0, firstCommaIndex);
      var afterComma = digitsAndComma.substring(firstCommaIndex + 1).replaceAll(',', '');
      if (afterComma.length > 2) afterComma = afterComma.substring(0, 2); // max 2 ondalık
      digitsAndComma = '$beforeComma,$afterComma';
    }

    if (digitsAndComma.isEmpty) {
      return const TextEditingValue(text: '', selection: TextSelection.collapsed(offset: 0));
    }

    final parts = digitsAndComma.split(',');
    final integerPart = parts[0].isEmpty ? '0' : parts[0];
    final intValue = int.tryParse(integerPart) ?? 0;
    final formattedInteger = _integerFormat.format(intValue);

    final result = parts.length > 1 ? '$formattedInteger,${parts[1]}' : formattedInteger;

    return TextEditingValue(
      text: result,
      selection: TextSelection.collapsed(offset: result.length),
    );
  }
}
