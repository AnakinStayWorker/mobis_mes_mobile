import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'package:mobis_mes_mobile/const/colors.dart';
import 'package:mobis_mes_mobile/screen/main_menu.dart';
import 'package:mobis_mes_mobile/screen/inventory_check.dart';
import 'package:mobis_mes_mobile/screen/logout.dart';

enum AppPage { home, inventoryCheck }

class AppDrawer extends StatelessWidget {
  final AppPage current;
  const AppDrawer({super.key, required this.current});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, String>>(
      future: _loadUser(),
      builder: (context, snapshot) {
        final userId = snapshot.data?['id'] ?? '';
        final userName = snapshot.data?['name'] ?? '';

        return Drawer(
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              UserAccountsDrawerHeader(
                decoration: const BoxDecoration(color: BACKGROUND_COLOR),
                accountName: Text(userName, style: const TextStyle(fontWeight: FontWeight.bold)),
                accountEmail: Text(userId, style: const TextStyle(fontWeight: FontWeight.bold)),
                currentAccountPicture: const CircleAvatar(),
              ),

              // Home
              ListTile(
                leading: const Icon(Icons.home),
                title: const Text('Main Menu'),
                enabled: current != AppPage.home,
                onTap: current == AppPage.home
                    ? () => Navigator.pop(context)
                    : () {
                  Navigator.pop(context);
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (_) => const MainMenuView()),
                        (route) => false,
                  );
                },
              ),

              // Inventory Check
              ListTile(
                leading: const Icon(Icons.inventory_2),
                title: const Text('Inventory Check'),
                enabled: current != AppPage.inventoryCheck,
                onTap: current == AppPage.inventoryCheck
                    ? () => Navigator.pop(context)
                    : () {
                  Navigator.pop(context);
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (_) => const InventoryCheckPage()),
                  );
                },
              ),

              const Divider(),

              // Sign out
              ListTile(
                leading: const Icon(Icons.logout),
                title: const Text('Sign out'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => LogOutPage()));
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<Map<String, String>> _loadUser() async {
    const storage = FlutterSecureStorage();
    final id = await storage.read(key: 'UserId') ?? '';
    final name = await storage.read(key: 'UserName') ?? '';
    return {'id': id, 'name': name};
  }
}
