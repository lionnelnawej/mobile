import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:loyambo/kernel/services/http_manager.dart';

class StaffReportScreen extends StatelessWidget {
  const StaffReportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFFF4F5F7),
      body: StaffReportBody(),
    );
  }
}

class StaffReportBody extends StatefulWidget {
  const StaffReportBody({super.key});

  @override
  State<StaffReportBody> createState() => _StaffReportBodyState();
}

class _StaffReportBodyState extends State<StaffReportBody> {
  Map<String, dynamic>? _data;
  bool _loading = true;
  bool _sending = false;
  final _tickets = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _tickets.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final data = await HttpManager.instance.staffReport();
    if (!mounted) return;
    setState(() {
      _data = data;
      _loading = false;
    });
  }

  Future<void> _submit() async {
    final count = int.tryParse(_tickets.text.trim());
    if (count == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Indiquez le nombre de bons physiques.")),
      );
      return;
    }
    setState(() => _sending = true);
    final error = await HttpManager.instance.submitStaffReport(count);
    if (!mounted) return;
    setState(() => _sending = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(error ?? "Rapport enregistré.")),
    );
    if (error == null) _load();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    final data = _data;
    if (data == null) {
      return const Center(child: Text("Rapport indisponible pour le moment."));
    }
    final showMoney = data['show_money'] == true;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 110),
      children: [
        const Text(
          "Mon rapport",
          style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: Colors.indigo),
        ),
        const SizedBox(height: 6),
        Text(
          data['journee']?.toString() ?? "Journée en cours",
          style: const TextStyle(color: Colors.black54, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 18),
        _card("Commandes traitées", "${data['commandes'] ?? 0}"),
        if (showMoney) ...[
          const SizedBox(height: 12),
          _card("Total encaissé", (data['totaux_label'] ?? '').toString().isEmpty ? "0" : data['totaux_label'].toString()),
        ],
        const SizedBox(height: 12),
        _card("Bons sortis par le logiciel", "${data['tickets_systeme'] ?? 0}"),
        const SizedBox(height: 22),
        const Text(
          "Bons physiques",
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _tickets,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: const InputDecoration(
            filled: true,
            fillColor: Colors.white,
            hintText: "Nombre de bons que vous avez en main",
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: _sending ? null : _submit,
          style: FilledButton.styleFrom(
            backgroundColor: Colors.indigo,
            minimumSize: const Size.fromHeight(52),
          ),
          child: Text(_sending ? "Envoi..." : "Faire mon rapport"),
        ),
        if (data['deja_envoye'] == true)
          const Padding(
            padding: EdgeInsets.only(top: 12),
            child: Text(
              "Un rapport a déjà été envoyé pour cette journée. Un nouvel envoi le remplace.",
              style: TextStyle(color: Colors.black54),
            ),
          ),
      ],
    );
  }

  Widget _card(String label, String value) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Colors.black54, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }
}
