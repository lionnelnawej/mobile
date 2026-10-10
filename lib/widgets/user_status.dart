import 'package:loyambo/screens/auth/login.dart';

import '/constants/styles.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:loyambo/kernel/controllers/auth_controller.dart';

class UserStatus extends StatelessWidget {
  final String? name; // Optional, will use AuthController if not provided

  const UserStatus({
    super.key,
    this.name,
  });

  @override
  Widget build(BuildContext context) {
    final AuthController authController = Get.find<AuthController>();

    return Obx(() {
      final user = authController.currentUser.value;
      final displayName = name ?? user?.name ?? "Utilisateur";
      final displayRole = user?.role ?? "Serveur";

      return PopupMenuButton<int>(
        elevation: 10,
        offset: const Offset(0, 52),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20.0),
        ),
        color: const Color(0xFFF0F0F0),
        surfaceTintColor: Colors.white,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20.0),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                height: 28.0,
                width: 28.0,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.orange,
                      Colors.orange.shade800,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    displayName.isNotEmpty ? displayName.substring(0, 1).toUpperCase() : "?",
                    style: const TextStyle(
                      fontFamily: "Staatliches",
                      color: Colors.white,
                      fontSize: 14.0,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 18,
                color: Colors.white.withOpacity(0.7),
              ),
            ],
          ),
        ),
        onSelected: (value) {
          if (value == 2) {
            _showConfirmationDialog(
              context: context,
              title: "Déconnexion",
              description: "Voulez-vous vraiment quitter votre session de service ?",
              icon: Icons.logout_rounded,
              color: Colors.redAccent,
              onConfirm: () {
                authController.logout();
                Get.offAll(() => const LoginScreen());
              },
            ); // Use your login route name
          }
        },
        itemBuilder: (context) => [
          PopupMenuItem<int>(
            enabled: false,
            child: Container(
              width: 240,
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.05),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.person_outline, size: 14, color: primaryColor),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        "Profil utilisateur",
                        style: TextStyle(
                          color: Colors.indigo,
                          fontSize: 14.0,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ],
                  ),
                  Divider(color: Colors.grey.shade300, height: 24),
                  _buildInfoRow(Icons.person_outline, "Nom", displayName),
                  _buildInfoRow(Icons.badge_outlined, "Role", displayRole),
                ],
              ),
            ),
          ),
          const PopupMenuDivider(height: 1),
          const PopupMenuItem<int>(
            value: 2,
            child: Row(
              children: [
                Icon(Icons.power_settings_new_rounded, size: 20, color: Colors.redAccent),
                SizedBox(width: 12),
                Text(
                  'Déconnexion',
                  style: TextStyle(
                    color: Colors.redAccent,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                    fontFamily: "Ubuntu",
                  ),
                )
              ],
            ),
          ),
        ],
      );
    });
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(icon, size: 18, color: Colors.black45),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label.toUpperCase(),
                  style: TextStyle(
                    color: Colors.black.withOpacity(0.4),
                    fontSize: 8,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.black87,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    fontFamily: "Ubuntu",
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showConfirmationDialog({
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
}
