import 'package:flutter/material.dart';
import 'package:loyambo/kernel/services/http_manager.dart';

class PresenceScreen extends StatefulWidget {
  const PresenceScreen({super.key});

  @override
  State<PresenceScreen> createState() => _PresenceScreenState();
}

class _PresenceScreenState extends State<PresenceScreen> {
  List<Map<String, dynamic>> _serveurs = [];
  bool _open = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final data = await HttpManager.instance.dayRoster();
    if (!mounted) return;
    final list = (data?['serveurs'] as List? ?? [])
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
    setState(() {
      _serveurs = list;
      _open = data?['ouverte'] == true;
      _loading = false;
    });
  }

  Future<void> _toggle(Map<String, dynamic> serveur) async {
    final present = serveur['present'] == true;
    final online = serveur['online'] == true;
    if (present && online) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Ce serveur est connecté. Il doit se déconnecter avant d'être retiré.")),
      );
      return;
    }
    final error = await HttpManager.instance.toggleRoster(serveur['id'] as int, !present);
    if (!mounted) return;
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
      return;
    }
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Présence journalière"),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (!_open)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 12),
                    child: Text("Aucune journée n'est ouverte."),
                  ),
                for (final serveur in _serveurs)
                  Card(
                    child: ListTile(
                      title: Text(serveur['name']?.toString() ?? ''),
                      subtitle: Text(serveur['online'] == true ? "Connecté" : "Hors ligne"),
                      trailing: Switch(
                        value: serveur['present'] == true,
                        onChanged: (serveur['present'] == true && serveur['online'] == true) || !_open
                            ? null
                            : (_) => _toggle(serveur),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}
