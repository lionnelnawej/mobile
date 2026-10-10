import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'package:loyambo/kernel/controllers/auth_controller.dart';
import 'package:loyambo/kernel/services/http_manager.dart';
import 'package:loyambo/screens/public/day_open_screen.dart';
import 'package:loyambo/screens/public/serve_screen.dart';
import 'package:loyambo/screens/public/station_screen.dart';

Future<void> openHomeForRole(String? role) async {
  if (role == 'cuisinier' || role == 'barman') {
    Get.offAll(() => StationScreen(service: role == 'barman' ? 'bar' : 'cuisine'));
    return;
  }
  if (role == 'caissier') {
    final status = await HttpManager.instance.dayStatus();
    if (status == null || status['ouverte'] != true) {
      Get.offAll(() => const DayOpenScreen());
      return;
    }
  }
  Get.offAll(() => const ServeScreen());
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _autoOpening = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _openIfAlreadyLoggedIn());
  }

  Future<void> _openIfAlreadyLoggedIn() async {
    if (_autoOpening || !mounted) return;
    final authController = Get.put(AuthController());
    if (!authController.isLoggedIn.value || authController.currentUser.value == null) {
      return;
    }
    _autoOpening = true;
    try {
      // Session locale déjà valide : ne pas bloquer sur le logo.
      await openHomeForRole(authController.currentUser.value?.role);
    } catch (_) {
      _autoOpening = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final AuthController authController = Get.put(AuthController());
    final LayerLink layerLink = LayerLink();
    OverlayEntry? overlayEntry;

    bool isTablet = MediaQuery.of(context).size.width > 600;

    void hideOverlay() {
      overlayEntry?.remove();
      overlayEntry = null;
    }

    OverlayEntry createOverlayEntry() {
      RenderBox renderBox = context.findRenderObject() as RenderBox;
      var size = renderBox.size;

      return OverlayEntry(
        builder: (context) {
          return Positioned(
            width: size.width - 80,
            child: CompositedTransformFollower(
              link: layerLink,
              showWhenUnlinked: false,
              offset: const Offset(0, 50),
              child: Material(
                elevation: 8,
                borderRadius: BorderRadius.circular(12),
                color: Colors.white,
                child: Container(
                  constraints: const BoxConstraints(maxHeight: 200),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Obx(() {
                    final filtered = authController.filteredAccounts;
                    return ListView.separated(
                      padding: EdgeInsets.zero,
                      shrinkWrap: true,
                      itemCount: filtered.length,
                      separatorBuilder: (context, index) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final id = filtered[index];
                        return ListTile(
                          visualDensity: VisualDensity.compact,
                          leading: const Icon(Icons.history, size: 18, color: Colors.grey),
                          title: Text(id, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w500)),
                          trailing: IconButton(
                            icon: const Icon(Icons.close, size: 16, color: Colors.redAccent),
                            onPressed: () => authController.removeAccount(id),
                          ),
                          onTap: () {
                            authController.idController.text = id;
                            authController.idFocusNode.unfocus();
                          },
                        );
                      },
                    );
                  }),
                ),
              ),
            ),
          );
        },
      );
    }

    void updateOverlayState() {
      if (authController.idFocusNode.hasFocus) {
        if (authController.filteredAccounts.isEmpty) {
          hideOverlay();
        } else {
          if (overlayEntry == null) {
            overlayEntry = createOverlayEntry();
            Overlay.of(context).insert(overlayEntry!);
          } else {
            overlayEntry!.markNeedsBuild();
          }
        }
      } else {
        hideOverlay();
      }
    }

    authController.idFocusNode.addListener(updateOverlayState);
    authController.idController.addListener(updateOverlayState);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: Colors.indigo,
        body: Stack(
          children: [
            Positioned.fill(
              child: Image.asset('assets/images/bg-1.jpg', fit: BoxFit.cover),
            ),
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.indigo.withOpacity(0.1),
                      Colors.indigo.withOpacity(0.8),
                      Colors.indigo,
                    ],
                    stops: const [0.0, 0.6, 1.0],
                  ),
                ),
              ),
            ),
            SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return SingleChildScrollView(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(minHeight: constraints.maxHeight),
                      child: IntrinsicHeight(
                        child: Center(
                          child: Container(
                            constraints: BoxConstraints(maxWidth: isTablet ? 450 : double.infinity),
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: Column(
                              children: [
                                const Spacer(flex: 10),
                                Container(
                                  padding: const EdgeInsets.all(15),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(20),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.1),
                                        blurRadius: 10,
                                        offset: const Offset(0, 5),
                                      ),
                                    ],
                                  ),
                                  child: Image.asset('assets/images/loyambo.png', height: 80),
                                ),
                                const SizedBox(height: 20),
                                Obx(() => Text(
                                  authController.currentUser.value?.etablissement?.nom?.toUpperCase() ?? "LOYAMBO",
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 28,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 2,
                                  ),
                                )),
                                const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 10),
                                  child: Text(
                                    "Gestion intelligente pour Resto & Lounge Bar",
                                    textAlign: TextAlign.center,
                                    style: TextStyle(color: Colors.white70, fontSize: 14),
                                  ),
                                ),
                                const SizedBox(height: 30),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(20),
                                  child: BackdropFilter(
                                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                                    child: Container(
                                      padding: const EdgeInsets.all(20),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.20),
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(color: Colors.white.withOpacity(0.2)),
                                      ),
                                      child: Column(
                                        children: [
                                          CompositedTransformTarget(
                                            link: layerLink,
                                            child: TextField(
                                              controller: authController.idController,
                                              focusNode: authController.idFocusNode,
                                              style: const TextStyle(color: Colors.white),
                                              decoration: InputDecoration(
                                                labelText: "Identifiant",
                                                labelStyle: const TextStyle(color: Colors.white70),
                                                enabledBorder: const UnderlineInputBorder(
                                                  borderSide: BorderSide(color: Colors.white38),
                                                ),
                                                focusedBorder: UnderlineInputBorder(
                                                  borderSide: BorderSide(color: Colors.orange.shade700, width: 2.0),
                                                ),
                                                suffixIcon: Padding(
                                                  padding: const EdgeInsets.all(12.0),
                                                  child: SvgPicture.asset(
                                                    'assets/svgs/user-1.svg',
                                                    colorFilter: const ColorFilter.mode(Colors.white70, BlendMode.srcIn),
                                                    width: 20,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(height: 10),
                                          Obx(() => TextField(
                                            controller: authController.passwordController,
                                            obscureText: authController.isObscure.value,
                                            style: const TextStyle(color: Colors.white),
                                            decoration: InputDecoration(
                                              labelText: "Mot de passe",
                                              labelStyle: const TextStyle(color: Colors.white70),
                                              enabledBorder: const UnderlineInputBorder(
                                                borderSide: BorderSide(color: Colors.white38),
                                              ),
                                              focusedBorder: UnderlineInputBorder(
                                                borderSide: BorderSide(color: Colors.orange.shade700, width: 2.0),
                                              ),
                                              suffixIcon: IconButton(
                                                icon: SvgPicture.asset(
                                                  authController.isObscure.value
                                                      ? 'assets/svgs/eye-alt.svg'
                                                      : 'assets/svgs/eye-slash-alt.svg',
                                                  colorFilter: const ColorFilter.mode(Colors.white70, BlendMode.srcIn),
                                                  width: 20,
                                                ),
                                                onPressed: () => authController.toggleObscure(),
                                              ),
                                            ),
                                          )),
                                          const SizedBox(height: 30),
                                          SizedBox(
                                            width: double.infinity,
                                            height: 55,
                                            child: Obx(() => ElevatedButton(
                                              onPressed: authController.isLoading.value
                                                  ? null
                                                  : () async {
                                                      bool success = await authController.login();
                                                      if (success) {
                                                        await openHomeForRole(authController.currentUser.value?.role);
                                                      }
                                                    },
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: Colors.orange.shade800,
                                                foregroundColor: Colors.white,
                                                shape: RoundedRectangleBorder(
                                                  borderRadius: BorderRadius.circular(15),
                                                ),
                                                elevation: 5,
                                              ),
                                              child: authController.isLoading.value
                                                  ? const SizedBox(
                                                      height: 20,
                                                      width: 20,
                                                      child: CircularProgressIndicator(
                                                        color: Colors.white,
                                                        strokeWidth: 2,
                                                      ),
                                                    )
                                                  : const Text(
                                                      "SE CONNECTER",
                                                      style: TextStyle(
                                                        fontSize: 16,
                                                        fontWeight: FontWeight.bold,
                                                        letterSpacing: 1.2,
                                                      ),
                                                    ),
                                            )),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                const Spacer(flex: 5),
                                const Text(
                                  "Powered by InnovTech",
                                  style: TextStyle(color: Colors.white38, fontSize: 12),
                                ),
                                const SizedBox(height: 20),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
