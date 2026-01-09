import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'package:mobis_mes_mobile/const/colors.dart';
import 'package:mobis_mes_mobile/screen/login.dart';
import 'package:mobis_mes_mobile/service/mobis_web_api.dart';
import 'package:mobis_mes_mobile/component/auth_session.dart';

class LogOutPage extends StatefulWidget {
  const LogOutPage({super.key});

  @override
  State<LogOutPage> createState() => _LogOutPageState();
}

class _LogOutPageState extends State<LogOutPage> {
  final _storage = const FlutterSecureStorage();

  String _empId = '';
  String _empName = '';
  bool _isLoading = false;

  // back confirm 중복 방지
  bool _confirmingBack = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadProfile());
  }

  Future<void> _loadProfile() async {
    final id = await _storage.read(key: 'UserId') ?? '';
    final name = await _storage.read(key: 'UserName') ?? '';
    if (!mounted) return;
    setState(() {
      _empId = id;
      _empName = name;
    });
  }

  Future<void> _navigateToLogin() async {
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => Login()),
          (route) => false,
    );
  }

  Future<void> _doServerLogout() async {
    setState(() => _isLoading = true);
    try {
      final result = await MobisWebApi.requestLogout();
      if (!mounted) return;
      setState(() => _isLoading = false);

      if (result.success) {
        // 서버가 정상 처리했을 때: 로컬 사용자 정보 정리 후 로그인 화면
        await _storage.delete(key: 'UserId');
        await _storage.delete(key: 'UserName');
        await _navigateToLogin();
        return;
      }

      // 서버 응답 실패(예: 401 포함) => 안내 및 강제 로그아웃 선택지
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (dCtx) => AlertDialog(
          title: const Text('Logout failed'),
          content: Text(result.error ?? 'Unknown error'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dCtx).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(dCtx).pop();
                await _forceLocalSignOut();
              },
              child: const Text('Force sign out'),
            ),
          ],
        ),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);

      // 네트워크 오류 등: 강제 로그아웃 옵션 제공
      await showDialog<void>(
        context: context,
        builder: (dCtx) => AlertDialog(
          title: const Text('Network error'),
          content: const Text('Failed to contact the server.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dCtx).pop(),
              child: const Text('OK'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(dCtx).pop();
                await _forceLocalSignOut();
              },
              child: const Text('Force sign out'),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _forceLocalSignOut() async {
    await AuthSession.clearLocalTokens();
    await _navigateToLogin();
  }

  // 뒤로가기 처리: Stay면 팝업만 닫고, Leave면 팝업 닫고 페이지 pop
  Future<void> _confirmBack() async {
    if (!mounted) return;
    if (_confirmingBack) return;
    _confirmingBack = true;

    try {
      final leave = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (dCtx) => AlertDialog(
          title: const Text('Leave this page?'),
          content: const Text('You have not signed out yet. Do you want to leave?'),
          actions: [
            TextButton(
              // Modified by Scott Kim. 01/09/2026. dialog context로 닫도록 변경.
              onPressed: () => Navigator.of(dCtx).pop(false),
              child: const Text('Stay'),
            ),
            TextButton(
              onPressed: () => Navigator.of(dCtx).pop(true),
              child: const Text('Leave'),
            ),
          ],
        ),
      ) ??
          false;

      // Stay => 아무것도 안 함 (팝업만 닫힘)
      if (!leave) return;

      // Leave => 페이지 pop
      if (!mounted) return;
      Navigator.of(context).pop();
    } finally {
      _confirmingBack = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (didPop) return;
        if (_isLoading) return; // 로그아웃 진행 중이면 뒤로가기 막기
        await _confirmBack();
      },
      child: Scaffold(
        appBar: AppBar(
          centerTitle: true,
          backgroundColor: BACKGROUND_COLOR,
          titleTextStyle: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w500,
            fontSize: 24,
          ),
          title: const Text('Sign out'),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              children: <Widget>[
                const SizedBox(height: 40),
                Text('EmpId: $_empId', style: const TextStyle(height: 2.4, fontSize: 18)),
                Text('EmpName: $_empName', style: const TextStyle(height: 2.0, fontSize: 18)),
                const SizedBox(height: 30),
                SizedBox(
                  height: 50,
                  width: 180,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      backgroundColor: LOGOUT_BUTTON_BACK_COLOR,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                    ),
                    onPressed: _isLoading ? null : _doServerLogout,
                    child: _isLoading
                        ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 3),
                    )
                        : const Text(
                      'Sign out',
                      style: TextStyle(color: LOGOUT_BUTTON_TEXT_COLOR, fontSize: 20),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: _isLoading ? null : _forceLocalSignOut,
                  child: const Text('Force sign out (local only)'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
