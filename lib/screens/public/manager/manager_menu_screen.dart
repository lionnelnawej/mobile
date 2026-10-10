import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';
import 'package:loyambo/kernel/controllers/auth_controller.dart';
import 'package:loyambo/kernel/controllers/manager_controller.dart';
import 'package:loyambo/screens/auth/login.dart';
import 'package:loyambo/widgets/user_status.dart';

class ManagerMenuScreen extends StatelessWidget {
  const ManagerMenuScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final AuthController authController = Get.find<AuthController>();
    final ManagerController managerController = Get.find<ManagerController>();
    final currentUser = authController.currentUser.value;

    final List<Map<String, dynamic>> menus = [
      {'title': 'Dashboard', 'icon': Icons.dashboard_outlined},
      {'title': 'Ventes', 'icon': Icons.shopping_bag_outlined},
      {'title': 'Revenus', 'icon': Icons.account_balance_wallet_outlined},
      {'title': 'Factures', 'icon': Icons.description_outlined, 'count': managerController.dashboardCounts['facs']},
      {'title': 'Produits', 'icon': Icons.inventory_2_outlined},
      {'title': 'Serveurs', 'icon': Icons.people_outline, 'count': managerController.dashboardCounts['users']},
      {'title': 'Inventaires', 'icon': Icons.inventory_outlined},
      {'title': 'Rapports', 'icon': Icons.analytics_outlined},
      {'title': 'Fiche stock', 'icon': Icons.bar_chart},
      {'title': 'Catégories', 'icon': Icons.category_outlined},
      {'title': 'Emplacements', 'icon': Icons.share_location},
      {'title': 'Tables', 'icon': Icons.table_bar_outlined},
      {'title': 'Reservations', 'icon': Icons.bedroom_child},
      {'title': 'Paramètres', 'icon': Icons.settings_outlined},
      {'title': 'Profil', 'icon': Icons.person_outline},
      {'title': 'Déconnexion', 'icon': Icons.logout_rounded},

    ];


    void showConfirmationDialog({
      required BuildContext context,
      required String title,
      required String description,
      required IconData icon,
      required Color color,
      required VoidCallback onConfirm,
    }) {
      Get.dialog(
        Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 40),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 400),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 24, offset: const Offset(0, 10))],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
                    child: Icon(icon, color: color, size: 28)
                ),
                const SizedBox(height: 18),
                Text(title, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700, color: Colors.black87, fontFamily: 'Ubuntu')),
                const SizedBox(height: 8),
                Text(description, textAlign: TextAlign.center, style: const TextStyle(fontSize: 13, color: Colors.grey, fontFamily: 'Ubuntu', height: 1.4)),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(child: TextButton(onPressed: () => Get.back(), child: const Text('ANNULER', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w700, fontFamily: 'Ubuntu')))),
                    const SizedBox(width: 12),
                    Expanded(
                        child: ElevatedButton(
                            onPressed: () {
                              Get.back();
                              onConfirm();
                            },
                            style: ElevatedButton.styleFrom(
                                backgroundColor: color,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                elevation: 0
                            ),
                            child: const Text('CONFIRMER', style: TextStyle(fontWeight: FontWeight.w800, fontFamily: 'Ubuntu'))
                        )
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      body: Column(
        children: [
          _buildHeader(context),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                _buildUserSection(currentUser),
                const SizedBox(height: 10),
                _buildMenuGrid(menus),
              ],
            ),
          ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(top: 50, left: 20, right: 20, bottom: 20),
      decoration: const BoxDecoration(color: Colors.indigo),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            "Menu",
            style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900),
          ),
          UserStatus(),
        ],
      ),
    );
  }

  Widget _buildUserSection(dynamic user) {
    final name = user?.name ?? 'Manager';
    final initials = name.isNotEmpty ? name.split(' ').map((e) => e[0]).take(2).join().toUpperCase() : 'M';
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          CircleAvatar(
            radius: 25,
            backgroundColor: Colors.indigo.withValues(alpha: 0.1),
            child: Text(initials, style: const TextStyle(fontWeight: FontWeight.w900, color: Colors.indigo)),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                Text(user?.email ?? 'manager@loyambo.com', style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: Colors.orange.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
            child:  Text(user?.role, style: TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: Colors.orange)),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuGrid(List<Map<String, dynamic>> items) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.5),
        border: Border(
          top: BorderSide(color: Colors.indigo.shade50, width: 0.5),
        ),
      ),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: EdgeInsets.zero,
        itemCount: items.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 4,
          childAspectRatio: 1.0,
        ),
        itemBuilder: (context, index) {
          final item = items[index];
          bool hasRightBorder = (index + 1) % 4 != 0;

          return Container(
            decoration: BoxDecoration(
              border: Border(
                right: hasRightBorder ? BorderSide(color: Colors.indigo.shade50, width: 0.5) : BorderSide.none,
                bottom: BorderSide(color: Colors.indigo.shade50, width: 0.5),
              ),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => item['action'] != null ? item['action']() : EasyLoading.showInfo(item['title']),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Icon(item['icon'] as IconData, color: Colors.indigo.shade400, size: 22),
                        if (item['count'] != null && item['count'] > 0)
                          Positioned(
                            right: -8,
                            top: -8,
                            child: Container(
                              padding: const EdgeInsets.all(3),
                              decoration: const BoxDecoration(color: Colors.redAccent, shape: BoxShape.circle),
                              constraints: const BoxConstraints(minWidth: 14, minHeight: 14),
                              child: Text(
                                "${item['count']}",
                                style: const TextStyle(color: Colors.white, fontSize: 7, fontWeight: FontWeight.bold),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      item['title'] as String,
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: Colors.grey.shade700),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
