import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:loyambo/kernel/controllers/auth_controller.dart';
import 'package:loyambo/screens/auth/login.dart';
import 'package:loyambo/widgets/user_status.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final AuthController authController = Get.find<AuthController>();
    bool isTablet = MediaQuery.of(context).size.width > 600;

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      body: Obx(() {
        final user = authController.currentUser.value;
        if (user == null) return const Center(child: CircularProgressIndicator());

        return Column(
          children: [
            _buildHeader(context, user.name ?? "Utilisateur"),
            Expanded(
              child: Center(
                child: Container(
                  constraints: BoxConstraints(maxWidth: isTablet ? 800 : double.infinity),
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    physics: const BouncingScrollPhysics(),
                    children: [
                      const SizedBox(height: 30),
                      // Profil Card
                      Container(
                        padding: const EdgeInsets.all(25),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(25),
                          border: Border.all(color: Colors.indigo.shade50),
                        ),
                        child: Column(
                          children: [
                            Stack(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: const BoxDecoration(color: Colors.indigo, shape: BoxShape.circle),
                                  child: CircleAvatar(
                                    radius: 50,
                                    backgroundColor: Colors.white,
                                    child: Text(
                                      (user.name?.isNotEmpty ?? false) ? user.name!.substring(0, 1).toUpperCase() : "?",
                                      style: const TextStyle(fontSize: 32, color: Colors.indigo, fontWeight: FontWeight.w900),
                                    ),
                                  ),
                                ),
                                Positioned(
                                  bottom: 0,
                                  right: 0,
                                  child: Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle),
                                    child: const Icon(Icons.check, color: Colors.white, size: 15),
                                  ),
                                )
                              ],
                            ),
                            const SizedBox(height: 20),
                            Text(user.name ?? "Utilisateur", style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
                            const SizedBox(height: 5),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                              decoration: BoxDecoration(color: Colors.indigo.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
                              child: Text(
                                (user.role ?? "SERVEUR").toUpperCase(),
                                style: const TextStyle(color: Colors.indigo, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 30),
                      _buildInfoSection("INFORMATIONS PERSONNELLES", [
                        _infoTile(Icons.alternate_email_rounded, "Email", user.email ?? "Non renseigné"),
                        _infoTile(Icons.store_rounded, "Établissement", user.etablissement?.nom ?? "Loyambo"),
                        _infoTile(Icons.location_on_rounded, "Statut", user.status ?? "Actif"),
                      ]),
                      const SizedBox(height: 10),
                      ElevatedButton(
                        onPressed: () => _showConfirmationDialog(
                          context: context,
                          title: "Déconnexion",
                          description: "Voulez-vous vraiment quitter votre session de service ?",
                          icon: Icons.logout_rounded,
                          color: Colors.redAccent,
                          onConfirm: () {
                            authController.logout();
                            Get.offAll(() => const LoginScreen());
                          },
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red.shade100,
                          foregroundColor: Colors.red,
                          elevation: 0,
                          minimumSize: const Size(double.infinity, 60),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                        ),
                        child: const Text("DÉCONNEXION DU COMPTE", style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1)),
                      ),
                      const SizedBox(height: 150),
                    ],
                  ),
                ),
              ),
            )
          ],
        );
      }),
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

  Widget _buildHeader(BuildContext context, String userName) {
    bool isTablet = MediaQuery.of(context).size.width > 600;
    return Container(
      padding: const EdgeInsets.only(top: 50, left: 20, right: 20, bottom: 20),
      width: double.infinity,
      color: Colors.indigo,
      child: Center(
        child: Container(
          constraints: BoxConstraints(maxWidth: isTablet ? 800 : double.infinity),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: () => Get.back(),
                    icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                  ),
                  const Text("Mon Profil", style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900)),
                ],
              ),
              UserStatus(name: userName)
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 10, bottom: 10),
          child: Text(title, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Colors.grey.shade500, letterSpacing: 1.2)),
        ),
        ...children,
      ],
    );
  }

  Widget _infoTile(IconData icon, String label, String value) {
    return Container(
      margin: const EdgeInsets.only(bottom: 5),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: Colors.indigo.shade50
          )
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: Colors.indigo, size: 20),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(color: Colors.grey.shade400, fontSize: 10, fontWeight: FontWeight.bold)),
                Text(value, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
              ],
            ),
          )
        ],
      ),
    );
  }
}
