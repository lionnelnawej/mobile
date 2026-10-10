import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:loyambo/kernel/controllers/auth_controller.dart';
import 'package:loyambo/kernel/controllers/printer_controller.dart';
import 'package:loyambo/kernel/services/http_manager.dart';
import 'package:loyambo/screens/public/day_open_screen.dart';
import 'package:loyambo/screens/public/serve/presence_screen.dart';
import 'package:loyambo/screens/public/serve/profile_screen.dart';
import 'package:loyambo/widgets/user_status.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final PrinterController printerController = Get.find<PrinterController>();

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                _buildSectionTitle("settings_printer".tr),
                const SizedBox(height: 10),
                Obx(() => Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: Colors.indigo.shade50
                    )
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: printerController.isConnected.value ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.print_rounded,
                              color: printerController.isConnected.value ? Colors.green : Colors.red,
                            ),
                          ),
                          const SizedBox(width: 15),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  printerController.isConnected.value ? "settings_printer_on".tr : "settings_printer_off".tr,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                ),
                                Text(
                                  printerController.isConnected.value 
                                    ? (printerController.selectedDevice.value?.name ?? "settings_printer_ready".tr)
                                    : "settings_printer_none".tr,
                                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                          if (printerController.isConnected.value)
                            IconButton(
                              icon: const Icon(Icons.link_off, color: Colors.red),
                              onPressed: () => printerController.disconnect(),
                            )
                        ],
                      ),
                      const Divider(height: 30),
                      ElevatedButton.icon(
                        onPressed: () => _showDevicePicker(context, printerController),
                        icon: const Icon(Icons.bluetooth_searching_rounded),
                        label: Text(printerController.isConnected.value ? "settings_printer_change".tr : "settings_printer_connect".tr),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.indigo,
                          foregroundColor: Colors.white,
                          minimumSize: const Size(double.infinity, 50),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 0,
                        ),
                      ),
                    ],
                  ),
                )),
                const SizedBox(height: 30),
                _buildSectionTitle("settings_system".tr),
                const SizedBox(height: 10),
                _buildSettingsTile(
                  Icons.language_rounded,
                  "settings_language".tr,
                  Get.locale?.languageCode == 'en' ? "settings_english".tr : "settings_french".tr,
                  onTap: () => _chooseLanguage(context),
                ),
                if (Get.find<AuthController>().currentUser.value?.allows('ouvrir-journee') == true)
                  _buildSettingsTile(
                    Icons.groups_rounded,
                    "Présence journalière",
                    "Ajouter ou retirer un serveur pour aujourd'hui",
                    onTap: () => Get.to(() => const PresenceScreen()),
                  ),
                if (Get.find<AuthController>().currentUser.value?.allows('cloturer-journee') == true)
                  _buildSettingsTile(
                    Icons.lock_clock_rounded,
                    "Clôturer la journée",
                    "Bloqué s'il reste une commande ouverte",
                    onTap: () => _closeDay(context),
                  ),
                _buildSettingsTile(
                  Icons.person_outline,
                  "Mon profil",
                  "Compte et déconnexion",
                  onTap: () => Get.to(() => const ProfileScreen()),
                ),
                _buildSettingsTile(Icons.notifications_active_rounded, "settings_notifications".tr, "settings_notifications_on".tr),
              ],
            ),
          ),
          const SizedBox(height: 70),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.only(top: 50, left: 20, right: 20, bottom: 20),
      width: double.infinity,
      color: Colors.indigo,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              const Icon(Icons.settings_suggest_rounded, color: Colors.white, size: 28),
              const SizedBox(width: 15),
              Text("settings_title".tr, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900)),
            ],
          ),
          const UserStatus()
        ],
      ),
    );
  }

  void _showDevicePicker(BuildContext context, PrinterController controller) {
    controller.getDevices();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
      builder: (context) => Container(
        padding: const EdgeInsets.all(25),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("settings_pick_printer".tr, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.indigo)),
                IconButton(
                  onPressed: () => controller.getDevices(),
                  icon: const Icon(Icons.refresh_rounded, color: Colors.indigo),
                )
              ],
            ),
            const SizedBox(height: 10),
            Text("settings_printer_hint".tr, 
              style: const TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 20),
            Obx(() => controller.isScanning.value 
              ? const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()))
              : controller.devices.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          Text("settings_no_device".tr),
                          TextButton(onPressed: () => controller.getDevices(), child: Text("settings_retry".tr))
                        ],
                      ),
                    )
                  )
                : ConstrainedBox(
                    constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.4),
                    child: ListView(
                      shrinkWrap: true,
                      children: controller.devices.map((device) => ListTile(
                        leading: const Icon(Icons.print_rounded, color: Colors.indigo),
                        title: Text(device.name ?? "settings_unknown".tr),
                        subtitle: Text(device.address ?? ""),
                        trailing: controller.selectedDevice.value?.address == device.address 
                          ? const Icon(Icons.check_circle, color: Colors.green) 
                          : null,
                        onTap: () {
                          controller.selectedDevice.value = device;
                          controller.connect();
                          Navigator.pop(context);
                        },
                      )).toList(),
                    ),
                  )
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 10),
      child: Text(
        title,
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Colors.grey.shade600, letterSpacing: 1.2),
      ),
    );
  }

  void _chooseLanguage(BuildContext context) {
    final current = Get.locale?.languageCode ?? 'fr';
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 16),
              Text("settings_language_title".tr, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.indigo)),
              ListTile(
                title: Text("settings_french".tr),
                trailing: current == 'fr' ? const Icon(Icons.check_rounded, color: Colors.indigo) : null,
                onTap: () => _setLocale('fr'),
              ),
              ListTile(
                title: Text("settings_english".tr),
                trailing: current == 'en' ? const Icon(Icons.check_rounded, color: Colors.indigo) : null,
                onTap: () => _setLocale('en'),
              ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }

  Future<void> _closeDay(BuildContext context, {bool confirmed = false}) async {
    if (!confirmed) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text("Clôturer la journée"),
          content: const Text("Les commandes encore ouvertes empêchent la clôture. Les serveurs sans rapport devront être forcés."),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Annuler")),
            TextButton(onPressed: () => Navigator.pop(context, true), child: const Text("Clôturer")),
          ],
        ),
      );
      if (confirm != true) return;
    }
    EasyLoading.show(status: "Clôture...");
    final response = await HttpManager.instance.closeDay();
    if (response != null && response['status'] == 'success') {
      EasyLoading.showSuccess("Journée clôturée");
      Get.offAll(() => const DayOpenScreen());
      return;
    }
    EasyLoading.dismiss();
    if (!context.mounted) return;
    if (response?['code'] == 'rapports') {
      final serveurs = response?['serveurs'];
      final forced = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.white,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        builder: (context) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: _ForceReportSheet(
            servers: serveurs is List ? serveurs : const [],
          ),
        ),
      );
      if (forced == true && context.mounted) {
        await _closeDay(context, confirmed: true);
      }
      return;
    }
    final commandes = response?['commandes'];
    final lines = commandes is List
        ? commandes.map((cmd) => "${cmd['numero']} · ${cmd['lieu']} · ${cmd['serveur']}").join('\n')
        : (response?['message'] ?? response?['errors'] ?? "Clôture impossible").toString();
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Commandes non clôturées"),
        content: SingleChildScrollView(child: Text(lines)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Fermer")),
        ],
      ),
    );
  }

  void _setLocale(String code) {
    Get.updateLocale(Locale(code));
    GetStorage().write('locale', code);
    Get.back();
  }

  Widget _buildSettingsTile(IconData icon, String title, String subtitle, {VoidCallback? onTap}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: Colors.indigo.shade50
        )
      ),
      child: ListTile(
        leading: Icon(icon, color: Colors.indigo),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: onTap,
      ),
    );
  }
}

class _ForceReportSheet extends StatefulWidget {
  final List servers;

  const _ForceReportSheet({required this.servers});

  @override
  State<_ForceReportSheet> createState() => _ForceReportSheetState();
}

class _CashLine {
  final String code;
  final String symbol;
  final TextEditingController controller;

  _CashLine({required this.code, required this.symbol, required this.controller});
}

class _ForceReportSheetState extends State<_ForceReportSheet> {
  late final List<List<_CashLine>> _cash;
  late final List<TextEditingController> _tickets;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _cash = widget.servers.map((server) {
      final raw = server is Map ? server['montants'] : null;
      final lines = raw is List && raw.isNotEmpty
          ? raw.map((item) => Map<String, dynamic>.from(item as Map)).toList()
          : [
              {'code': 'FC', 'symbol': 'FC', 'montant': 0},
            ];
      return lines.map((item) {
        return _CashLine(
          code: '${item['code'] ?? 'FC'}',
          symbol: '${item['symbol'] ?? item['code'] ?? 'FC'}',
          controller: TextEditingController(text: _amountText(item['montant'])),
        );
      }).toList();
    }).toList();
    _tickets = widget.servers
        .map((server) => TextEditingController(text: '${server['tickets_emis'] ?? 0}'))
        .toList();
  }

  String _amountText(dynamic value) {
    final amount = double.tryParse('$value') ?? 0;
    if (amount == amount.roundToDouble()) return '${amount.toInt()}';
    return '$amount';
  }

  @override
  void dispose() {
    for (final lines in _cash) {
      for (final line in lines) {
        line.controller.dispose();
      }
    }
    for (final field in _tickets) {
      field.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    for (var i = 0; i < widget.servers.length; i++) {
      final server = widget.servers[i] as Map;
      final especes = <String, double>{};
      for (final line in _cash[i]) {
        final cash = double.tryParse(line.controller.text.replaceAll(' ', '').replaceAll(',', '.').trim());
        if (cash == null || cash < 0) {
          setState(() => _saving = false);
          EasyLoading.showError("Indiquez le total espèces ${line.symbol} de ${server['name']}");
          return;
        }
        especes[line.code] = cash;
      }
      final tickets = int.tryParse(_tickets[i].text.trim());
      if (tickets == null) {
        setState(() => _saving = false);
        EasyLoading.showError("Indiquez les tickets de ${server['name']}");
        return;
      }
      final response = await HttpManager.instance.saveCashReport(
        serveurId: int.parse('${server['id']}'),
        especes: especes,
        ticketsServeur: tickets,
        ticketsEmis: int.tryParse('${server['tickets_emis']}') ?? 0,
        valeurTheorique: double.tryParse('${server['valeur_theorique']}') ?? 0,
      );
      if (response == null || response['status'] != 'success') {
        setState(() => _saving = false);
        final error = response?['errors'] ?? response?['message'] ?? "Rapport non enregistré";
        EasyLoading.showError(error.toString());
        return;
      }
    }
    if (!mounted) return;
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.85,
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(width: 42, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(4))),
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 16, 20, 4),
              child: Text("Forcer le rapport", style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.indigo)),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                "Ces serveurs n'ont pas remis leur rapport. Saisissez les espèces dans chaque devise, puis les tickets. La journée se clôture ensuite.",
                style: TextStyle(color: Colors.black54),
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(20),
                itemCount: widget.servers.length,
                itemBuilder: (context, index) {
                  final server = widget.servers[index] as Map;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.indigo.shade100),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${server['name']}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                        const SizedBox(height: 6),
                        Text("Encaissé : ${server['total_label'] ?? server['valeur_theorique']}"),
                        Text("Tickets système : ${server['tickets_emis'] ?? 0}"),
                        const SizedBox(height: 10),
                        ..._cash[index].map((line) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: TextField(
                            controller: line.controller,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: InputDecoration(
                              labelText: "Total espèces ${line.symbol}",
                              border: const OutlineInputBorder(),
                            ),
                          ),
                        )),
                        TextField(
                          controller: _tickets[index],
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: "Tickets remis par le serveur", border: OutlineInputBorder()),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saving ? null : _save,
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14)),
                  child: Text(_saving ? "Enregistrement..." : "Forcer le rapport et clôturer"),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
