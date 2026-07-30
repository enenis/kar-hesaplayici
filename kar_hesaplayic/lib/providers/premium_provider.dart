import 'package:flutter/foundation.dart';
import '../core/services/iap_service.dart';

class PremiumProvider extends ChangeNotifier {
  bool _isPro = false;
  bool get isPro => _isPro;

  PremiumProvider() {
    _init();
  }

  Future<void> _init() async {
    _isPro = await IapService.instance.isProUser();
    notifyListeners();
    IapService.instance.proStatusStream.listen((status) {
      _isPro = status;
      notifyListeners();
    });
  }

  /// Geliştirme/test amaçlı manuel geçiş (üretimde kaldırılabilir).
  void debugTogglePro() {
    _isPro = !_isPro;
    notifyListeners();
  }
}
