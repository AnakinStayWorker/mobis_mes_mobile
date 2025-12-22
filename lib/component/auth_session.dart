import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:mobis_mes_mobile/screen/login.dart';
import 'package:mobis_mes_mobile/service/mobis_web_api.dart';

class AuthSession {
  static bool _isShowing = false;
  static const _storage = FlutterSecureStorage();

  static Future<void> clearLocalTokens() async {
    await _storage.delete(key: 'AccessToken');
    await _storage.delete(key: 'AccessTokenExp');
    await _storage.delete(key: 'RefreshToken');

    await _storage.delete(key: 'UserId');
    await _storage.delete(key: 'UserName');
  }

  static Future<void> showExpiredAndGoToLogin(BuildContext context) async {
    if (_isShowing) return;
    _isShowing = true;
    try {
      await clearLocalTokens();
      if (!context.mounted) return;
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dCtx) => AlertDialog(
          title: const Text('Session expired'),
          content: const Text('Please sign in again.'),
          actions: [
            TextButton(onPressed: () => Navigator.of(dCtx).pop(), child: const Text('OK')),
          ],
        ),
      );
      if (!context.mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => Login()),
            (route) => false,
      );
    } finally {
      _isShowing = false;
    }
  }

  static Future<bool> handle401IfNeeded(BuildContext context, String? resultCode) async {
    if (resultCode == '401') {
      await showExpiredAndGoToLogin(context);
      return true;
    }
    return false;
  }

  // 네비게이션 전에 호출: 살아있으면 true, 만료면 팝업 후 로그인으로 보내고 false
  static Future<bool> ensureAliveOrLogin(BuildContext context) async {
    try {
      final res = await MobisWebApi.checkSessionAlive(); // authedGet => refresh 시도 포함
      if (await handle401IfNeeded(context, res.resultCode)) return false;
      return true;
    } catch (_) {
      // 네트워크 오류 등은 네비게이션을 막지 않음
      return true;
    }
  }
}
