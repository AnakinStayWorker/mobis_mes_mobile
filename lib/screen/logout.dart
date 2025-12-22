import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'package:mobis_mes_mobile/const/colors.dart';
import 'package:mobis_mes_mobile/screen/footer.dart';
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
    } catch (e) {
      setState(() => _isLoading = false);
      // 네트워크 오류 등: 강제 로그아웃 옵션 제공
      if (!mounted) return;
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
    // 서버 상황과 무관하게 로컬 자격 제거
    await AuthSession.clearLocalTokens();
    await _navigateToLogin();
  }

  // 뒤로가기 처리: 사용자가 실수로 들어왔을 수 있으니 확인
  Future<void> _confirmBack() async {
    if (!mounted) return;
    final leave = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Leave this page?'),
        content:
        const Text('You have not signed out yet. Do you want to leave?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Stay'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Leave'),
          ),
        ],
      ),
    ) ??
        false;
    if (leave && mounted) Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (didPop) return;
        await _confirmBack();
      },
      child: Scaffold(
        appBar: AppBar(
          centerTitle: true,
          backgroundColor: BACKGROUND_COLOR,
          titleTextStyle: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.w500, fontSize: 24),
          title: const Text('Sign out'),
        ),
        bottomNavigationBar: const BottomAppBar(
          color: Colors.transparent,
          elevation: 0,
          child: Center(child: Footer()),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              children: <Widget>[
                const SizedBox(height: 40),
                Text('EmpId: $_empId',
                    style: const TextStyle(height: 2.4, fontSize: 18)),
                Text('EmpName: $_empName',
                    style: const TextStyle(height: 2.0, fontSize: 18)),
                const SizedBox(height: 30),
                SizedBox(
                  height: 50,
                  width: 180,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      backgroundColor: LOGOUT_BUTTON_BACK_COLOR,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(25),
                      ),
                    ),
                    onPressed: _isLoading ? null : _doServerLogout,
                    child: _isLoading
                        ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 3),
                    )
                        : const Text('Sign out',
                        style: TextStyle(
                            color: LOGOUT_BUTTON_TEXT_COLOR, fontSize: 20)),
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
