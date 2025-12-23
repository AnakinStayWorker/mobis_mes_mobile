import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'package:mobis_mes_mobile/component/app_drawer.dart';
import 'package:mobis_mes_mobile/component/auth_session.dart';

import 'package:mobis_mes_mobile/screen/logout.dart';
import 'package:mobis_mes_mobile/screen/inventory_check.dart';
import 'package:mobis_mes_mobile/screen/footer.dart';

import 'package:mobis_mes_mobile/screen/monitor_part.dart';

import 'package:mobis_mes_mobile/service/mobis_web_api.dart';
import 'package:mobis_mes_mobile/const/colors.dart';

class MainMenuView extends StatefulWidget {
  const MainMenuView({super.key});

  @override
  State<MainMenuView> createState() => _MainMenuViewState();
}

class _MainMenuViewState extends State<MainMenuView> {
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _preflightSession();
    });
  }

  Future<void> _initPackageInfo() async {
    final info = await PackageInfo.fromPlatform();
    if (!mounted) return;
    setState(() {
      _packageInfo = info;
    });
  }

  Future<void> _preflightSession() async {
    try {
      final res = await MobisWebApi.checkSessionAlive();
      if (!mounted) return;
      if (await AuthSession.handle401IfNeeded(context, res.resultCode)) {
        return;
      }
    } catch (_) {}
  }

  Future<void> _confirmSignOut() async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Sign out'),
        content: const Text('Do you want to sign out?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Sign out')),
        ],
      ),
    ) ??
        false;

    if (shouldLogout && mounted) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => LogOutPage()));
    }
  }

  Widget _menuButton({
    required String text,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      width: 300,
      height: 50,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          textStyle: const TextStyle(fontSize: 20, fontWeight: FontWeight.w500),
        ),
        onPressed: onPressed,
        child: Text(text),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (didPop) return;
        await _confirmSignOut();
      },
      child: Scaffold(
        appBar: AppBar(
          centerTitle: true,
          title: Text("MES Mobile - ${_packageInfo.version}"),
          backgroundColor: BACKGROUND_COLOR,
          titleTextStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500, fontSize: 24),
          actions: [
            IconButton(
              tooltip: 'Sign out',
              icon: const Icon(Icons.logout),
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => LogOutPage()));
              },
            ),
          ],
        ),
        drawer: const AppDrawer(current: AppPage.home),
        bottomNavigationBar: const BottomAppBar(
          color: Colors.transparent,
          elevation: 0,
          child: Center(child: Footer()),
        ),
        body: Center(
          child: Column(
            children: [
              const SizedBox(height: 60),

              // Monitor Part
              _menuButton(
                text: "Monitor Part",
                onPressed: () async {
                  final ok = await AuthSession.ensureAliveOrLogin(context);
                  if (!ok) return;

                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const MonitorPartPage()),
                  );
                },
              ),

              const SizedBox(height: 25),

              _menuButton(
                text: "Inventory Check",
                onPressed: () async {
                  final ok = await AuthSession.ensureAliveOrLogin(context);
                  if (!ok) return;

                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const InventoryCheckPage()),
                  );
                },
              ),

              const SizedBox(height: 60),
            ],
          ),
        ),
      ),
    );
  }
}
