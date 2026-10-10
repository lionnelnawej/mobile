import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:loyambo/kernel/controllers/cart_controller.dart';
import 'package:loyambo/kernel/controllers/order_controller.dart';
import 'package:loyambo/kernel/controllers/printer_controller.dart';
import 'package:loyambo/kernel/models/product.dart';
import 'package:loyambo/screens/public/serve/home_screen.dart';
import 'package:loyambo/widgets/cart_item_tile.dart';
import 'package:loyambo/widgets/devise_totals.dart';

import 'serve/orders_screen.dart';
import 'serve/settings_screen.dart';
import 'serve/staff_report_screen.dart';

class ServeScreen extends StatefulWidget {
  const ServeScreen({super.key});

  @override
  State<ServeScreen> createState() => _ServeScreenState();
}

class _ServeScreenState extends State<ServeScreen> {
  final CartController cartController = Get.put(CartController());
  final OrderController orderController = Get.put(OrderController());
  final PrinterController printerController = Get.put(PrinterController());

  int _activeIndex = 0;
  final PageController _pageController = PageController();

  final TextStyle sectionTitleStyle = const TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w900,
    color: Colors.indigo,
    letterSpacing: -0.8,
  );

  @override
  void initState() {
    super.initState();
    // Enregistrer le callback pour afficher le panier via le controlleur
    cartController.onShowCartRequested = _showCart;
  }

  void _onProductTap(Product product) {
    if (cartController.tableMatchesProduct(cartController.selectedTable.value, product)) {
      cartController.addToCart(product);
    } else {
      _showTableSelectionModal(product);
    }
  }

  void _showTableSelectionModal(Product product) {
    final groups = cartController.tablesForProduct(product);
    final placeLabel = (product.placeName ?? '').trim();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      useSafeArea: true,
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width > 600
            ? 500
            : double.infinity,
      ),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      builder: (context) {
        return SafeArea(
          child: Container(
            padding: const EdgeInsets.all(25),
            height: MediaQuery.of(context).size.height * 0.7,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      placeLabel.isEmpty ? "Sélection Table" : "Tables $placeLabel",
                      style: sectionTitleStyle,
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(
                        Icons.close_rounded,
                        color: Colors.indigo,
                        size: 28,
                      ),
                    ),
                  ],
                ),
                const Divider(height: 30, thickness: 1),
                Expanded(
                  child: groups.isEmpty
                      ? const Center(
                          child: Text(
                            "Aucune table pour cet emplacement",
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                        )
                      : ListView(
                    physics: const BouncingScrollPhysics(),
                    children: groups.entries.map((entry) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Text(
                              entry.key.toUpperCase(),
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 12,
                                color: Colors.indigo.withOpacity(0.4),
                                letterSpacing: 1.5,
                              ),
                            ),
                          ),
                          Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            children: entry.value.map((table) {
                              return InkWell(
                                onTap: () {
                                  cartController.selectTable(table);
                                  cartController.addToCart(product);
                                  Navigator.pop(context);
                                },
                                borderRadius: BorderRadius.circular(15),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 22,
                                    vertical: 16,
                                  ),
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                      color: Colors.indigo.withOpacity(0.15),
                                      width: 2,
                                    ),
                                    borderRadius: BorderRadius.circular(15),
                                    color: Colors.white,
                                  ),
                                  child: Text(
                                    table.name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      color: Colors.indigo,
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 25),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showCart() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      useSafeArea: true,
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width > 600
            ? 600
            : double.infinity,
      ),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      builder: (context) {
        return SafeArea(
          child: Obx(() {
            return Container(
              padding: const EdgeInsets.all(25),
              height: MediaQuery.of(context).size.height * 0.85,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Ma Commande", style: sectionTitleStyle),
                          if (cartController.selectedTable.value != null)
                            Container(
                              margin: const EdgeInsets.only(top: 6),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.orange.shade50,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: Colors.orange.shade200,
                                ),
                              ),
                              child: Text(
                                "TABLE: ${cartController.selectedTable.value!.name}${cartController.selectedTable.value!.location != null ? ' • ${cartController.selectedTable.value!.location!.toUpperCase()}' : ''}",
                                style: TextStyle(
                                  color: Colors.orange.shade900,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                        ],
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(
                          Icons.close_rounded,
                          color: Colors.indigo,
                          size: 28,
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 40, thickness: 1),
                  if (cartController.cart.isEmpty)
                    const Expanded(
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.shopping_basket_outlined,
                              size: 80,
                              color: Colors.grey,
                            ),
                            SizedBox(height: 15),
                            Text(
                              "Votre panier attend d'être rempli",
                              style: TextStyle(
                                color: Colors.grey,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    Expanded(
                      child: ListView.builder(
                        physics: const BouncingScrollPhysics(),
                        itemCount: cartController.cart.length,
                        itemBuilder: (context, index) {
                          final item = cartController.cart[index];
                          return CartItemTile(
                            item: item,
                            onAdd: () => cartController.addToCart(item),
                            onRemove: () => cartController.removeFromCart(item),
                          );
                        },
                      ),
                    ),
                  if (cartController.cart.isNotEmpty) ...[
                    const Divider(height: 40, thickness: 1),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 25),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Total à payer",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: DeviseTotals(items: cartController.cart.toList()),
                          ),
                        ],
                      ),
                    ),
                    ElevatedButton(
                      onPressed: () async {
                        final ok = await cartController.validateOrder();
                        if (ok && context.mounted) Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.indigo,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 60),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                      child: const Text(
                        "VALIDER LA COMMANDE",
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 15,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (cartController.selectedTable.value != null) ...[
                    OutlinedButton(
                      onPressed: () {
                        cartController.cancelOrder();
                        Navigator.pop(context);
                      },
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.red, width: 2),
                        minimumSize: const Size(double.infinity, 60),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                      child: const Text(
                        "ANNULER LA COMMANDE",
                        style: TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.w900,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            );
          }),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    bool isTablet = MediaQuery.of(context).size.width > 600;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: Colors.grey.shade200,
        extendBody: true,
        body: PageView(
          controller: _pageController,
          physics: const NeverScrollableScrollPhysics(),
          onPageChanged: (index) => setState(() => _activeIndex = index),
          children: [
            HomeScreen(onProductTap: _onProductTap),
            OrdersScreen(onShowCart: _showCart),
            const SettingsScreen(),
            const StaffReportScreen(),
          ],
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
        floatingActionButton: Obx(() {
          return FloatingActionButton(
            onPressed: _showCart,
            backgroundColor: Colors.orange.shade800,
            shape: const CircleBorder(),
            elevation: 3,
            child: Badge(
              backgroundColor: Colors.indigo,
              label: Text(
                "${cartController.cartCount}",
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 10,
                ),
              ),
              isLabelVisible: cartController.cartCount > 0,
              padding: const EdgeInsets.all(4),
              child: const Icon(
                CupertinoIcons.shopping_cart,
                color: Colors.white,
                size: 26,
              ),
            ),
          );
        }),
        bottomNavigationBar: _buildBottomBar(isTablet),
      ),
    );
  }

  Widget _buildBottomBar(bool isTablet) {
    return BottomAppBar(
      padding: EdgeInsets.zero,
      height: 70,
      color: Colors.white,
      shape: const CircularNotchedRectangle(),
      notchMargin: 10,
      elevation: 20,
      child: Center(
        child: Container(
          constraints: BoxConstraints(
            maxWidth: isTablet ? 800 : double.infinity,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(0, CupertinoIcons.square_grid_2x2, 'nav_home'.tr),
              Obx(
                () => _buildNavItem(
                  1,
                  Icons.receipt_long_rounded,
                  'nav_orders'.tr,
                  badgeCount: orderController.orders.length,
                ),
              ),
              const SizedBox(width: 70),
              _buildNavItem(2, CupertinoIcons.gear_big, 'nav_settings'.tr),
              _buildNavItem(3, Icons.bar_chart_rounded, 'Rapport'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(
    int index,
    IconData icon,
    String label, {
    int badgeCount = 0,
  }) {
    bool isActive = _activeIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          _pageController.jumpToPage(index);
        },
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Badge(
              label: Text(
                "$badgeCount",
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 10,
                ),
              ),
              isLabelVisible: badgeCount > 0,
              backgroundColor: Colors.redAccent,
              child: Icon(
                icon,
                color: isActive ? Colors.indigo : Colors.grey.shade500,
                size: 24,
              ),
            ),
            Text(
              label,
              maxLines: 1,
              style: TextStyle(
                color: isActive ? Colors.indigo : Colors.grey.shade500,
                fontSize: 10,
                fontWeight: isActive ? FontWeight.w900 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
