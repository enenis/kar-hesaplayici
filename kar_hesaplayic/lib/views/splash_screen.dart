import 'package:flutter/material.dart';
import '../core/constants/app_colors.dart';
import 'home_screen.dart';

/// Uygulama açılışında görünen marka ekranı. Native (Android/iOS) açılış
/// arka planı zaten marka rengiyle (teal) ayarlı olduğundan, bu widget
/// devreye girdiğinde kullanıcı çıplak beyaz bir ekran görmez — akıcı bir
/// geçiş sağlanır.
///
/// DÜZELTME (bug fix): Önceki sürümde başlık, üstteki Spacer(flex:3) ve
/// alttaki Spacer(flex:4) + spinner + imza yüzünden ekranın dikey TAM
/// ortasında değil, hafif yukarısında görünüyordu. Artık bir `Stack` ile
/// başlık kesin olarak ekranın merkezine, "enenis software" imzası ise
/// kesin olarak alt kenara (Positioned) sabitleniyor — Column'daki
/// esnek Spacer dengesine bağlı kalmıyor.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fadeIn;

  // Kullanıcı geri bildirimi: önceki 2.0 saniye "çok kısa" hissettiriyordu.
  // Metni rahatça okumaya yetecek şekilde hafifçe uzatıldı.
  static const Duration _splashDuration = Duration(milliseconds: 2500);

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..forward();
    _fadeIn = CurvedAnimation(parent: _controller, curve: Curves.easeOut);

    Future.delayed(_splashDuration, () {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 400),
          pageBuilder: (_, animation, __) => const HomeScreen(),
          transitionsBuilder: (_, animation, __, child) =>
              FadeTransition(opacity: animation, child: child),
        ),
      );
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary,
      body: FadeTransition(
        opacity: _fadeIn,
        child: SafeArea(
          child: Stack(
            children: [
              // --- Ekranın TAM ortası: amblem + "Kâr Hesaplayıcı" ---
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 88,
                        height: 88,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.4),
                            width: 1.5,
                          ),
                        ),
                        child: const Icon(
                          Icons.trending_up_rounded,
                          color: Colors.white,
                          size: 44,
                        ),
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'Kâr Hesaplayıcı',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 30,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'E-Ticaret & Freelancer Kâr Hesaplayıcı',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.85),
                          fontSize: 13,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // --- Ekranın KESİN alt kenarı: "enenis software" imzası ---
              Positioned(
                left: 0,
                right: 0,
                bottom: 28,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        valueColor: AlwaysStoppedAnimation(Colors.white70),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'enenis software',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.75),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
