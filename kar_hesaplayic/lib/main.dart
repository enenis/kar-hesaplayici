import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'core/constants/app_theme.dart';
import 'core/services/admob_service.dart';
import 'core/services/iap_service.dart';
import 'providers/calculator_provider.dart';
import 'providers/premium_provider.dart';
import 'views/splash_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Türkçe tarih/sayı formatlaması (para birimi gösterimi için)
  // kullanılmadan önce locale verisinin yüklenmesi gerekir. Bu çok hızlı
  // (yerel, ağ gerektirmeyen) bir işlem olduğu için burada await edilmesi
  // güvenlidir — açılışı geciktirmez.
  await initializeDateFormatting('tr_TR', null);

  // KRİTİK DÜZELTME: AdMob/IAP başlatma ARTIK await EDİLMİYOR.
  //
  // Önceki sürümde `await AdMobService.instance.initialize()` burada
  // bekleniyordu. Bu çağrı internete/Google sunucularına gidiyor; yavaş
  // veya kopuk bir bağlantıda SDK'nın kendi iç zaman aşımına kadar (gözlemle
  // ~15 saniyeye kadar) bu satırda TAKILI KALIYORDU — ve bu satır runApp()'tan
  // ÖNCE olduğu için kullanıcı bu süre boyunca (native açılış temasının rengi
  // nedeniyle) yeşil/boş bir ekranda bekliyordu.
  //
  // Çözüm: `_initAdsAndIapInBackground()` çağrısının başına `await`
  // KONULMUYOR ("fire-and-forget" / unawaited). Böylece runApp() ve
  // dolayısıyla SplashScreen ANINDA çizilir; AdMob/IAP ise arka planda,
  // kendi hızında, kullanıcıyı hiç bloklamadan başlatılır. Reklamlar birkaç
  // saniye sonra "geç" hazır olsa bile bu, açılış deneyimini artık etkilemez
  // — ilgili servisler (admob_service.dart) zaten "reklam hazır değilse
  // engellemeden devam et" mantığıyla yazıldı.
  if (!kIsWeb) {
    // ignore: unawaited_futures
    _initAdsAndIapInBackground();
  }

  runApp(const KarHesaplayiciApp());
}

/// AdMob ve IAP servislerini arka planda, uygulamanın açılışını
/// ETKİLEMEDEN başlatır. Kasıtlı olarak `await` EDİLMEDEN çağrılır.
Future<void> _initAdsAndIapInBackground() async {
  try {
    await AdMobService.instance.initialize();
  } catch (e) {
    debugPrint('AdMob başlatılamadı (uygulama etkilenmez): $e');
  }
  try {
    await IapService.instance.initialize();
  } catch (e) {
    debugPrint('IAP servisi başlatılamadı (uygulama etkilenmez): $e');
  }
}

class KarHesaplayiciApp extends StatelessWidget {
  const KarHesaplayiciApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => CalculatorProvider()..loadSavedCalculations()),
        ChangeNotifierProvider(create: (_) => PremiumProvider()),
      ],
      child: MaterialApp(
        title: 'Kâr / Komisyon / Desi Hesaplayıcı',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: ThemeMode.system,
        // Aşırı büyük sistem font ayarlarında layout taşmasını önlemek için sınırlama.
        builder: (context, child) {
          final mq = MediaQuery.of(context);
          return MediaQuery(
            data: mq.copyWith(
              textScaler: mq.textScaler.clamp(minScaleFactor: 0.85, maxScaleFactor: 1.3),
            ),
            child: child!,
          );
        },
        home: const SplashScreen(),
      ),
    );
  }
}
