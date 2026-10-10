import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';
import 'package:loyambo/kernel/controllers/auth_controller.dart';
import 'package:loyambo/kernel/services/http_manager.dart';
import 'package:loyambo/screens/auth/login.dart';
import 'package:loyambo/screens/public/serve_screen.dart';

class DayOpenScreen extends StatefulWidget {
  const DayOpenScreen({super.key});

  @override
  State<DayOpenScreen> createState() => _DayOpenScreenState();
}

class _DayOpenScreenState extends State<DayOpenScreen> {
  final _rate = TextEditingController();
  final Set<int> _selected = {};
  List<Map<String, dynamic>> _serveurs = [];
  bool _loading = true;
  bool _confirmed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _rate.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final status = await HttpManager.instance.dayStatus();
    if (!mounted) return;
    if (status != null && status['ouverte'] == true) {
      Get.offAll(() => const ServeScreen());
      return;
    }
    final taux = status?['taux'];
    if (taux is num && taux > 0) {
      _rate.text = taux == taux.roundToDouble() ? '${taux.toInt()}' : '$taux';
    }
    final list = status?['serveurs'];
    setState(() {
      _serveurs = list is List
          ? list.map((item) => Map<String, dynamic>.from(item as Map)).toList()
          : [];
      _loading = false;
    });
  }

  Future<void> _open() async {
    final rate = double.tryParse(_rate.text.replaceAll(',', '.').trim());
    if (rate == null || rate <= 0) {
      EasyLoading.showError("Indiquez le taux de 1 dollar en FC");
      return;
    }
    if (!_confirmed) {
      EasyLoading.showError("Confirmez le taux avant d'ouvrir");
      return;
    }
    EasyLoading.show(status: "Ouverture...");
    final response = await HttpManager.instance.startDay(rate, _selected.toList());
    if (response != null && response['status'] == 'success') {
      EasyLoading.showSuccess("Journée ouverte");
      Get.offAll(() => const ServeScreen());
      return;
    }
    final errors = response?['errors'];
    EasyLoading.showError(errors is List ? errors.join('\n') : (errors?.toString() ?? "Ouverture impossible"));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F6FC),
      appBar: AppBar(
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        title: const Text("Ouvrir la journée"),
        actions: [
          IconButton(
            onPressed: () {
              Get.find<AuthController>().logout();
              Get.offAll(() => const LoginScreen());
            },
            icon: const Icon(Icons.logout_rounded),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                const Text(
                  "Le taux de la dernière journée est déjà rempli. Changez-le seulement s'il a changé, confirmez-le, puis cochez les serveurs qui travaillent aujourd'hui.",
                  style: TextStyle(fontSize: 15, height: 1.4),
                ),
                const SizedBox(height: 18),
                TextField(
                  controller: _rate,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
                  decoration: InputDecoration(
                    labelText: "1 \$ =",
                    suffixText: "FC",
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onChanged: (_) => setState(() => _confirmed = false),
                ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _confirmed,
                  activeColor: Colors.indigo,
                  onChanged: (value) => setState(() => _confirmed = value ?? false),
                  title: const Text("Je confirme ce taux"),
                ),
                const SizedBox(height: 8),
                const Text("Serveurs autorisés", style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                const SizedBox(height: 4),
                const Text(
                  "Un serveur non coché ne pourra pas travailler.",
                  style: TextStyle(color: Colors.black54),
                ),
                const SizedBox(height: 8),
                if (_serveurs.isEmpty)
                  const Text("Aucun serveur enregistré")
                else
                  ..._serveurs.map((srv) {
                    final id = int.tryParse('${srv['id']}') ?? 0;
                    return CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      value: _selected.contains(id),
                      activeColor: Colors.indigo,
                      title: Text('${srv['name']}'),
                      onChanged: (value) {
                        setState(() {
                          if (value == true) {
                            _selected.add(id);
                          } else {
                            _selected.remove(id);
                          }
                        });
                      },
                    );
                  }),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _confirmed ? _open : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.indigo,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 52),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text("Ouvrir la journée"),
                ),
              ],
            ),
    );
  }
}
