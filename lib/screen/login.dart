import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'package:mobis_mes_mobile/const/colors.dart';
import 'package:mobis_mes_mobile/screen/main_menu.dart';
import 'package:mobis_mes_mobile/screen/footer.dart';
import 'package:mobis_mes_mobile/screen/download_new_version.dart';

import 'package:mobis_mes_mobile/service/mobis_web_api.dart';
import 'package:mobis_mes_mobile/model/mobis_auth_models.dart';
import 'package:mobis_mes_mobile/model/version_check_info.dart';

class Login extends StatefulWidget {
  @override
  State<Login> createState() => _LoginState();
}

class _LoginState extends State<Login> {
  final _controllerEmpId = TextEditingController();
  final _controllerPassword = TextEditingController();
  bool _isLoggingIn = false;

  PackageInfo _packageInfo = PackageInfo(
    appName: 'Unknown',
    packageName: 'Unknown',
    version: 'Unknown',
    buildNumber: 'Unknown',
    buildSignature: 'Unknown',
    installerStore: 'Unknown',
  );

  @override
  void initState() {
    super.initState();
    _initPackageInfo();
  }

  Future<void> _initPackageInfo() async {
    final info = await PackageInfo.fromPlatform();
    if (!mounted) return;
    setState(() => _packageInfo = info);
  }

  Future<void> _showDialog(BuildContext context, String title, String message, Color backColor) {
    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: backColor,
          title: Text(title),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [Text(message)],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK')),
          ],
        );
      },
    );
  }

  Future<void> _onLoginPressed() async {
    final id = _controllerEmpId.text.trim();
    final pw = _controllerPassword.text;

    if (id.isEmpty || pw.isEmpty) {
      _showDialog(context, 'Validation', 'Please enter Employee ID and Password.', Colors.pinkAccent);
      return;
    }

    setState(() => _isLoggingIn = true);
    final MobisLoginResult res = await MobisWebApi.requestLogin(userId: id, password: pw);
    setState(() => _isLoggingIn = false);

    if (res.isSuccess) {
      // VerChkRet == 'Y'면 안내(선택 업데이트)
      final vflag = MobisWebApi.lastLoginVerChkRet;
      final vmsg  = MobisWebApi.lastLoginRetMsg ?? '';
      if (vflag == 'Y' && vmsg.isNotEmpty) {
        await _showDialog(context, 'Notice', vmsg, Colors.white);
      }
      if (!mounted) return;
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => MainMenuView()));
    } else {
      final msg = res.error ?? 'Sign in failed.';
      _showDialog(context, 'Sign in Failed', msg, Colors.pinkAccent);
    }
  }

  /// AuthController.VersionCheck
  Future<void> _onVersionCheck() async {
    final VersionCheckInfoResponse vc = await MobisWebApi.versionCheck();
    final ver = vc.versionInfo;

    if (vc.resultCode == '00' && ver != null) {
      final code = ver.verChkRet.toUpperCase(); // 'Y' | 'N' | 'U' | 'B' | 'E'
      if (code == 'Y') {
        if (!mounted) return;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => DownloadNewVersion(
              versionChkResponse: vc,
              currentVer: _packageInfo.version,
            ),
          ),
        );
      } else if (code == 'N') {
        _showDialog(context, 'Version Check', 'You are using the latest version (${_packageInfo.version}).', Colors.white);
      } else {
        _showDialog(context, 'Version Check', ver.retMsg.isNotEmpty ? ver.retMsg : vc.resultMessage, Colors.pinkAccent);
      }
    } else if (vc.resultCode == '426' && ver != null) {
      // Forced update => Immediate update screen
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => DownloadNewVersion(
            versionChkResponse: vc,
            currentVer: _packageInfo.version,
          ),
        ),
      );
    } else {
      _showDialog(context, 'Version Check Failed', vc.resultMessage, Colors.pinkAccent);
    }
  }

  /// AuthController.Ping
  Future<void> _onApiAccessTest() async {
    final r = await MobisWebApi.ping(echo: "ApiCallTestByUser");
    if (r.success) {
      _showDialog(context, "Success", "You can access the Mobis Backend Web API.", Colors.white);
    } else {
      _showDialog(
        context,
        "Failed",
        "Failed to connect to the Mobis Backend Web API.\n${r.error ?? ''}",
        Colors.pinkAccent,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("MES Mobile - Sign in"),
        backgroundColor: BACKGROUND_COLOR,
        titleTextStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500, fontSize: 24),
        automaticallyImplyLeading: false,
        centerTitle: true,
      ),
      bottomNavigationBar: const BottomAppBar(
        color: Colors.transparent,
        elevation: 0,
        child: Center(child: Footer()),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: <Widget>[
            const SizedBox(height: 30),
            Center(
              child: SizedBox(width: 200, height: 150, child: Image.asset('asset/images/mobis_logo.png')),
            ),
            const SizedBox(height: 50),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 15),
              child: TextField(
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'Employee ID',
                  hintText: 'Enter valid employee id',
                ),
                controller: _controllerEmpId,
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 15.0, right: 15.0, top: 15),
              child: TextField(
                obscureText: true,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'Password',
                  hintText: 'Enter secure password',
                ),
                controller: _controllerPassword,
              ),
            ),
            const SizedBox(height: 30),

            SizedBox(
              height: 50,
              width: 250,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  backgroundColor: LOGIN_BUTTON_BACK_COLOR,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                ),
                onPressed: _isLoggingIn ? null : _onLoginPressed,
                child: _isLoggingIn
                    ? const SizedBox(width: 26, height: 26, child: CircularProgressIndicator(strokeWidth: 3))
                    : const Text('Sign in', style: TextStyle(color: OUTLINE_BUTTON_TEXT_COLOR, fontSize: 25)),
              ),
            ),

            const SizedBox(height: 30),

            ElevatedButton(
              onPressed: _onVersionCheck,
              child: const Text('Version check', style: TextStyle(color: Colors.blue, fontSize: 15)),
            ),

            const SizedBox(height: 30),

            TextButton.icon(
              onPressed: _onApiAccessTest,
              icon: const Icon(Icons.network_ping),
              label: const Text('API Access Test', style: TextStyle(color: Colors.cyan, fontSize: 14)),
            ),
          ],
        ),
      ),
    );
  }
}
