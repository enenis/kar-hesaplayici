import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Anlık döviz kuru servisi.
///
/// Kaynak: https://open.er-api.com (ücretsiz, API anahtarı gerektirmez,
/// makul rate-limit'e sahiptir). İstek başarısız olursa (internet yok,
/// servis çöktü vb.) son başarılı çekilen kur `SharedPreferences`'tan,
/// o da yoksa sabit `_offlineFallbackRates` değerlerinden okunur.
/// Böylece uygulama her zaman "zero-server" prensibine sadık kalarak
/// offline çalışmaya devam eder.
class ExchangeRateService {
  ExchangeRateService._();
  static final ExchangeRateService instance = ExchangeRateService._();

  static const String _baseUrl = 'https://open.er-api.com/v6/latest/USD';
  static const String _prefsRatesKey = 'cached_exchange_rates';
  static const String _prefsTimestampKey = 'cached_exchange_rates_timestamp';

  /// TRY bazlı, hiçbir zaman internete çıkmadan çalışabilmesi için
  /// elle girilmiş kaba yaklaşık değerler. Yalnızca hem API hem de
  /// önbellek başarısız olduğunda son çare olarak kullanılır.
  static const Map<String, double> _offlineFallbackRatesToTry = {
    'USD': 34.0,
    'EUR': 37.0,
    'GBP': 43.0,
  };

  /// [base] para birimi cinsinden 1 birimin kaç TRY ettiğini döner.
  /// Örn: fetchRateToTry('USD') -> 34.21 gibi.
  Future<ExchangeRateResult> fetchRateToTry(String base) async {
    try {
      final response = await http
          .get(Uri.parse(_baseUrl))
          .timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final rates = data['rates'] as Map<String, dynamic>?;
        if (rates != null && rates['TRY'] != null) {
          final usdToTry = (rates['TRY'] as num).toDouble();
          final targetToUsd = base == 'USD'
              ? 1.0
              : (rates[base] != null ? 1.0 / (rates[base] as num).toDouble() : null);

          if (targetToUsd != null) {
            final rateToTry = usdToTry * targetToUsd;
            await _persistCache(rates.map((k, v) => MapEntry(k, (v as num).toDouble())));
            return ExchangeRateResult(
              rate: rateToTry,
              isLive: true,
              fetchedAt: DateTime.now(),
            );
          }
        }
      }
      return _fallback(base);
    } catch (_) {
      // İnternet yok, timeout, DNS hatası vb. -> sessizce fallback'e düş.
      return _fallback(base);
    }
  }

  Future<void> _persistCache(Map<String, double> usdRates) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsRatesKey, jsonEncode(usdRates));
    await prefs.setString(_prefsTimestampKey, DateTime.now().toIso8601String());
  }

  Future<ExchangeRateResult> _fallback(String base) async {
    final prefs = await SharedPreferences.getInstance();
    final cachedRaw = prefs.getString(_prefsRatesKey);
    final cachedTimestampRaw = prefs.getString(_prefsTimestampKey);

    if (cachedRaw != null) {
      try {
        final cached = (jsonDecode(cachedRaw) as Map<String, dynamic>)
            .map((k, v) => MapEntry(k, (v as num).toDouble()));
        final usdToTry = cached['TRY'];
        final targetToUsd =
            base == 'USD' ? 1.0 : (cached[base] != null ? 1.0 / cached[base]! : null);
        if (usdToTry != null && targetToUsd != null) {
          return ExchangeRateResult(
            rate: usdToTry * targetToUsd,
            isLive: false,
            fetchedAt: cachedTimestampRaw != null
                ? DateTime.tryParse(cachedTimestampRaw)
                : null,
          );
        }
      } catch (_) {
        // Bozuk önbellek -> alttaki sabit değerlere düş.
      }
    }

    return ExchangeRateResult(
      rate: _offlineFallbackRatesToTry[base] ?? 1.0,
      isLive: false,
      fetchedAt: null,
    );
  }
}

class ExchangeRateResult {
  final double rate;
  final bool isLive; // true: API'den az önce çekildi, false: önbellek/offline sabit
  final DateTime? fetchedAt;

  const ExchangeRateResult({
    required this.rate,
    required this.isLive,
    required this.fetchedAt,
  });
}
