import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:loyambo/kernel/controllers/auth_controller.dart';
import 'package:loyambo/kernel/controllers/printer_controller.dart';
import 'package:loyambo/kernel/models/order.dart';
import 'package:loyambo/kernel/services/chime.dart';
import 'package:loyambo/kernel/services/http_manager.dart';
import 'package:loyambo/screens/auth/login.dart';
import 'package:loyambo/screens/public/serve/staff_report_screen.dart';

class StationScreen extends StatefulWidget {
  final String service;

  const StationScreen({super.key, required this.service});

  @override
  State<StationScreen> createState() => _StationScreenState();
}

class _StationScreenState extends State<StationScreen> {
  List<Map<String, dynamic>> _tickets = [];
  List<Order> _done = [];
  int _tab = 0;
  bool _loading = true;
  Timer? _timer;
  final Set<int> _sending = {};
  final Set<int> _knownIds = {};
  bool _primed = false;

  bool get _isBar => widget.service == 'bar';

  @override
  void initState() {
    super.initState();
    if (!Get.isRegistered<PrinterController>()) {
      Get.put(PrinterController());
    }
    _load();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) => _load(silent: true));
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent && mounted) setState(() => _loading = true);
    final tickets = await HttpManager.instance.getStationTickets(widget.service);
    if (tickets == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    final ids = tickets.map((ticket) => int.tryParse('${ticket['id']}')).whereType<int>().toSet();
    if (_primed && ids.difference(_knownIds).isNotEmpty) {
      Chime.play();
    }
    _knownIds
      ..clear()
      ..addAll(ids);
    _primed = true;
    if (!mounted) return;
    setState(() {
      _tickets = tickets;
      _loading = false;
    });
  }

  Future<void> _ready(int id) async {
    setState(() => _sending.add(id));
    final ok = await HttpManager.instance.markStationReady(id, widget.service);
    if (!mounted) return;
    setState(() {
      _sending.remove(id);
      if (ok) _tickets.removeWhere((ticket) => ticket['id'] == id);
    });
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("La commande n'a pas pu être marquée prête")),
      );
    }
  }

  Future<void> _loadDone() async {
    final list = await HttpManager.instance.getDoneOrders();
    if (!mounted || list == null) return;
    setState(() => _done = list);
  }

  Widget _doneBody() {
    if (_done.isEmpty) {
      return const Center(child: Text("Aucune commande marquée prête", style: TextStyle(fontWeight: FontWeight.w700)));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _done.length,
      itemBuilder: (context, index) {
        final order = _done[index];
        return Card(
          child: ListTile(
            onTap: () => _showReadyDetail(order),
            title: Text(order.numeroFacture ?? "#${order.id}"),
            subtitle: Text("${order.table?.name ?? ''}  ${order.user?.name ?? ''}".trim()),
            trailing: const Icon(Icons.chevron_right),
          ),
        );
      },
    );
  }

  void _showReadyDetail(Order order) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                order.numeroFacture ?? "#${order.id}",
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 4),
              Text("Table ${order.table?.name ?? '—'}"),
              if ((order.user?.name ?? '').isNotEmpty) Text("Serveur ${order.user!.name}"),
              const Divider(height: 24),
              ConstrainedBox(
                constraints: BoxConstraints(maxHeight: MediaQuery.of(sheetContext).size.height * 0.45),
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final item in order.items)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text("${item.quantity}  ${item.name}", style: const TextStyle(fontWeight: FontWeight.w700)),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => Get.find<PrinterController>().printOrderTicket(order),
                  icon: const Icon(Icons.print),
                  label: const Text("Réimprimer"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = _isBar ? 'Bar' : 'Cuisine';
    return Scaffold(
      backgroundColor: const Color(0xFFF3E6C8),
      appBar: AppBar(
        backgroundColor: const Color(0xFF7C2D12),
        foregroundColor: Colors.white,
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
        actions: [
          IconButton(onPressed: () => _load(), icon: const Icon(Icons.refresh)),
          IconButton(
            onPressed: () {
              Get.find<AuthController>().logout();
              Get.offAll(() => const LoginScreen());
            },
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (index) {
          setState(() => _tab = index);
          if (index == 1) _loadDone();
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.sticky_note_2_outlined), label: "En cours"),
          NavigationDestination(icon: Icon(Icons.history), label: "Historique"),
          NavigationDestination(icon: Icon(Icons.bar_chart), label: "Rapport"),
        ],
      ),
      body: _tab == 2
          ? const StaffReportBody()
          : _tab == 1
              ? _doneBody()
              : _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF7C2D12)))
          : _tickets.isEmpty
              ? const Center(
                  child: Text(
                    "Aucune commande à préparer",
                    style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF7C2D12)),
                  ),
                )
              : GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 280,
                    mainAxisExtent: 250,
                    crossAxisSpacing: 14,
                    mainAxisSpacing: 14,
                  ),
                  itemCount: _tickets.length,
                  itemBuilder: (context, index) {
                    final ticket = _tickets[index];
                    final tilt = index.isEven ? -0.02 : 0.02;
                    return Transform.rotate(
                      angle: tilt,
                      child: _Note(
                        ticket: ticket,
                        busy: _sending.contains(ticket['id']),
                        onReady: () => _ready(ticket['id'] as int),
                      ),
                    );
                  },
                ),
    );
  }
}

class _Note extends StatelessWidget {
  final Map<String, dynamic> ticket;
  final bool busy;
  final VoidCallback onReady;

  const _Note({required this.ticket, required this.busy, required this.onReady});

  @override
  Widget build(BuildContext context) {
    final items = (ticket['items'] as List? ?? []);
    return Material(
      color: const Color(0xFFFFF4B8),
      elevation: 3,
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    ticket['numero']?.toString() ?? '#${ticket['id']}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                  ),
                ),
                Text(ticket['heure']?.toString() ?? '', style: const TextStyle(fontWeight: FontWeight.w700)),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              ticket['lieu']?.toString() ?? '',
              style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF7C2D12)),
            ),
            if ((ticket['serveur']?.toString() ?? '').isNotEmpty)
              Text(ticket['serveur'].toString(), style: const TextStyle(fontSize: 12, color: Colors.black54)),
            const Divider(height: 16),
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  for (final item in items)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        "${item['qte']}  ${item['nom']}",
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                ],
              ),
            ),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(backgroundColor: const Color(0xFF15803D)),
                onPressed: busy ? null : onReady,
                child: busy
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text("Prêt"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
