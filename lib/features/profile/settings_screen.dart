import 'package:flutter/material.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Ayarlar")),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.notifications_outlined),
            title: const Text("Bildirim Ayarları"),
            trailing: Switch(value: true, onChanged: (val) {}),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.language),
            title: const Text("Dil Seçeneği"),
            subtitle: const Text("Türkçe"),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {},
          ),
          const Divider(),
          const ListTile(
            leading: Icon(Icons.info_outline),
            title: Text("Uygulama Hakkında"),
            subtitle: Text("v1.0.0"),
          ),
        ],
      ),
    );
  }
}