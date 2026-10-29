import 'package:web/web.dart';

/// iPhone/iPad com app instalado na Home Screen (display-mode: standalone).
bool get isIosWebStandalonePwa {
  final ua = window.navigator.userAgent.toLowerCase();
  final isIos =
      ua.contains('iphone') || ua.contains('ipad') || ua.contains('ipod');
  if (!isIos) return false;
  return window.matchMedia('(display-mode: standalone)').matches;
}
