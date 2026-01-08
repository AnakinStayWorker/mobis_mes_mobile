import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:mobis_mes_mobile/screen/login.dart';
import 'package:mobis_mes_mobile/service/mobis_web_api.dart';

class AuthSession {
  static bool _isShowing = false;
  static const _storage = FlutterSecureStorage();

  static Future<void> clearLocalTokens() async {
    // tokens
    await _storage.delete(key: 'AccessToken');
    await _storage.delete(key: 'AccessTokenExp');
    await _storage.delete(key: 'RefreshToken');

    // user/profile (MobisWebApi.requestLogin()에서 저장하는 값들)
    await _storage.delete(key: 'UserId');
    await _storage.delete(key: 'UserName');
    await _storage.delete(key: 'Email');
    await _storage.delete(key: 'Department');
    await _storage.delete(key: 'DepartmentName');
    await _storage.delete(key: 'UserType');
  }

  /// 인증 실패(401/403/426) 처리 후 Login으로 이동
  static Future<bool> handleAuthFailureIfNeeded(
      BuildContext context,
      String? resultCode, {
        String? message,
      }) async {
    final code = (resultCode ?? '').trim();
    if (code.isEmpty || code == '00') return false;

    final is401 = code == '401';
    final is403 = code == '403';
    final is426 = code == '426';

    if (!(is401 || is403 || is426)) return false;

    if (_isShowing) return true; // 이미 처리중이면 중복 방지
    _isShowing = true;

    try {
      await clearLocalTokens();
      if (!context.mounted) return true;

      String title;
      String body;

      if (is401) {
        title = 'Session expired';
        body = (message != null && message.trim().isNotEmpty)
            ? message
            : 'Please sign in again.';
      } else if (is403) {
        title = 'Access blocked';
        body = (message != null && message.trim().isNotEmpty)
            ? message
            : 'This device or user is blocked.\nPlease contact the administrator.';
      } else {
        // 426
        title = 'Update required';
        body = (message != null && message.trim().isNotEmpty)
            ? message
            : 'A newer version is required.\nPlease update the app.';
      }

      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dCtx) => AlertDialog(
          title: Text(title),
          content: Text(body),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dCtx).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );

      if (!context.mounted) return true;

      // 스택 정리 후 로그인으로
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => Login()),
            (route) => false,
      );

      return true;
    } finally {
      _isShowing = false;
    }
  }

  /// 기존 호출부 호환을 위해 유지 (401만 체크)
  static Future<bool> handle401IfNeeded(BuildContext context, String? resultCode) async {
    return handleAuthFailureIfNeeded(context, resultCode);
  }

  /// 네비게이션 전에 호출: 살아있으면 true, 만료/차단/업데이트면 false
  static Future<bool> ensureAliveOrLogin(BuildContext context) async {
    try {
      final res = await MobisWebApi.checkSessionAlive(); // authedGet => refresh 시도 포함

      if (await handleAuthFailureIfNeeded(
        context,
        res.resultCode,
        message: res.resultMessage,
      )) {
        return false;
      }
      return true;
    } catch (_) {
      // 네트워크 오류 등은 네비게이션을 막지 않음(기존 정책 유지)
      return true;
    }
  }
}
