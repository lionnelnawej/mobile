import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:loyambo/kernel/controllers/cart_controller.dart';
import 'package:loyambo/kernel/controllers/order_controller.dart';
import 'package:loyambo/kernel/controllers/printer_controller.dart';
import 'package:loyambo/kernel/controllers/manager_controller.dart';
import 'package:loyambo/kernel/models/product.dart';
import 'package:loyambo/screens/public/manager/manager_home_screen.dart';
import 'package:loyambo/screens/public/manager/manager_menu_screen.dart';
import 'package:loyambo/screens/public/serve/orders_screen.dart';
import 'package:loyambo/screens/public/serve/settings_screen.dart';
import 'package:loyambo/widgets/cart_item_tile.dart';
import 'package:loyambo/widgets/devise_totals.dart';
import 'package:loyambo/widgets/product_card.dart';

class ManagerScreen extends StatefulWidget {
  const ManagerScreen({super.key});

  @override
  State<ManagerScreen> createState() => _ManagerScreenState();
}

class _ManagerScreenState extends State<ManagerScreen> {
  final CartController cartController = Get.put(CartController());
  final OrderController orderController = Get.put(OrderController());
  final PrinterController printerController = Get.put(PrinterController());
  final ManagerController managerController = Get.put(ManagerController());

  int _activeIndex = 0;
  final PageController _pageController = PageController();

  @override
  void initState() {
    super.initState();
    // Enregistrer le callback pour afficher le panier
    cartController.onShowCartRequested = _showCart;
  }

  void _onTakeOrder() {
    var server = Get.find<ManagerController>().selectedServer.value;
    if(server != null){
      _showCart();
    }
    else{
      _showServerSelectionModal();
    }
  }

  void _showServerSelectionModal() {
    managerController.fetchServers();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(25),
          height: MediaQuery.of(context).size.height * 0.7,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Sélection Serveur",
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: Colors.indigo,
                ),
              ),
              const Text(
                "Choisissez un serveur pour débuter la vente",
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 20.0),
              Expanded(
                child: Obx(() {
                  if (managerController.servers.isEmpty) {
                    return const Center(
                      child: Text(
                        "Aucun serveur disponible",
                        style: TextStyle(color: Colors.grey),
                      ),
                    );
                  }

                  return GridView.builder(
                    gridDelegate:
                        const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 200,
                          crossAxisSpacing: 15,
                          mainAxisSpacing: 15,
                          childAspectRatio: 1.1,
                        ),
                    itemCount: managerController.servers.length,
                    itemBuilder: (context, index) {
                      final server = managerController.servers[index];
                      final initials = server.name != null
                          ? server.name!
                                .split(' ')
                                .map((e) => e[0])
                                .take(2)
                                .join()
                                .toUpperCase()
                          : '?';

                      return InkWell(
                        onTap: () {
                          Get.back();
                          Get.find<ManagerController>().selectedServer.value =
                              server;
                          _showProductSelectionModal();
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: Colors.indigo.withOpacity(0.1),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.02),
                                blurRadius: 10,
                              ),
                            ],
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              CircleAvatar(
                                radius: 25,
                                backgroundColor: Colors.indigo.withOpacity(0.1),
                                child: Text(
                                  initials,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                    color: Colors.indigo,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 10),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                ),
                                child: Column(
                                  children: [
                                    Text(
                                      server.name ?? 'Inconnu',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 13,
                                      ),
                                      textAlign: TextAlign.center,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      server.email ?? '',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w500,
                                        fontSize: 9,
                                        color: Colors.grey.shade600,
                                      ),
                                      textAlign: TextAlign.center,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                }),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showTableSelectionModal([Product? product]) {
    final groups = cartController.tablesForProduct(product);
    final placeLabel = (product?.placeName ?? '').trim();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      builder: (context) {
        return Container(
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
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: Colors.indigo,
                    ),
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
                                if (product != null) {
                                  cartController.addToCart(product);
                                }
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
        );
      },
    );
  }

  void _onProductTap(Product product) {
    if (cartController.tableMatchesProduct(cartController.selectedTable.value, product)) {
      cartController.addToCart(product);
    } else {
      _showTableSelectionModal(product);
    }
  }

  void _showProductSelectionModal() {
    final RxString selectedCategory = "Tout".obs;
    final TextEditingController searchCtrl = TextEditingController();
    final RxList<Product> filteredList = <Product>[].obs;

    filteredList.assignAll(cartController.allProducts);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      builder: (context) {
        return SafeArea(
          child: Container(
            padding: const EdgeInsets.only(top: 25),
            height: MediaQuery.of(context).size.height * 0.9,
            child: Stack(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 25),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "order_take".tr,
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              color: Colors.indigo,
                            ),
                          ),
                          IconButton(
                            onPressed: () => Get.back(),
                            icon: const Icon(Icons.close_rounded),
                          ),
                        ],
                      ),
                    ),
                    Obx(() {
                      if (cartController.selectedTable.value != null) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 25,
                            vertical: 5,
                          ),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.orange.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: Colors.orange.withOpacity(0.2),
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
                        );
                      }
                      return const SizedBox.shrink();
                    }),
                    const SizedBox(height: 10),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 25),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 15),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: TextField(
                          controller: searchCtrl,
                          onChanged: (val) {
                            filteredList.assignAll(
                              cartController.allProducts.where(
                                (p) =>
                                    p.name.toLowerCase().contains(
                                      val.toLowerCase(),
                                    ) &&
                                    (selectedCategory.value == "Tout" ||
                                        p.category == selectedCategory.value),
                              ),
                            );
                          },
                          decoration: InputDecoration(
                            icon: const Icon(Icons.search, size: 20),
                            hintText: "order_search".tr,
                            border: InputBorder.none,
                            hintStyle: TextStyle(fontSize: 13),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      height: 50,
                      child: Obx(() {
                        final String currentCat = selectedCategory.value;
                        return ListView.builder(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 25),
                          itemCount: cartController.categories.length + 1,
                          itemBuilder: (context, index) {
                            final cat = index == 0
                                ? "Tout"
                                : cartController.categories[index - 1].libelle;
                            final isSelected = cat == currentCat;
                            return GestureDetector(
                              onTap: () {
                                selectedCategory.value = cat;
                                filteredList.assignAll(
                                  cartController.allProducts.where(
                                    (p) =>
                                        p.name.toLowerCase().contains(
                                          searchCtrl.text.toLowerCase(),
                                        ) &&
                                        (cat == "Tout" || p.category == cat),
                                  ),
                                );
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                margin: const EdgeInsets.only(right: 10),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                ),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? Colors.indigo
                                      : Colors.indigo.withOpacity(0.05),
                                  borderRadius: BorderRadius.circular(15),
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  cat,
                                  style: TextStyle(
                                    color: isSelected
                                        ? Colors.white
                                        : Colors.indigo,
                                    fontWeight: isSelected
                                        ? FontWeight.w900
                                        : FontWeight.w700,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            );
                          },
                        );
                      }),
                    ),
                    const SizedBox(height: 15),
                    Expanded(
                      child: Obx(() {
                        filteredList.length;
                        final query = searchCtrl.text.toLowerCase();
                        final cat = selectedCategory.value;
                        final places = cartController.placeCatalogs
                            .where((place) => place.id != 0)
                            .toList();
                        bool matches(Product product) {
                          return product.name.toLowerCase().contains(query) &&
                              (cat == "Tout" || product.category == cat);
                        }
                        if (places.isEmpty) {
                          return GridView.builder(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 25,
                              vertical: 10,
                            ),
                            gridDelegate:
                                const SliverGridDelegateWithMaxCrossAxisExtent(
                                  maxCrossAxisExtent: 120,
                                  crossAxisSpacing: 12,
                                  mainAxisSpacing: 12,
                                  childAspectRatio: 0.85,
                                ),
                            itemCount: filteredList.length,
                            itemBuilder: (context, index) {
                              final product = filteredList[index];
                              return ProductCard(
                                product: product,
                                onTap: () => _onProductTap(product),
                              );
                            },
                          );
                        }
                        return ListView(
                          padding: const EdgeInsets.only(bottom: 100),
                          children: [
                            for (final place in places)
                              if (place.products.any(matches)) ...[
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(25, 8, 25, 8),
                                  child: Text(
                                    place.name,
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w900,
                                      color: Colors.indigo,
                                    ),
                                  ),
                                ),
                                GridView.builder(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  padding: const EdgeInsets.symmetric(horizontal: 25),
                                  gridDelegate:
                                      const SliverGridDelegateWithMaxCrossAxisExtent(
                                        maxCrossAxisExtent: 120,
                                        crossAxisSpacing: 12,
                                        mainAxisSpacing: 12,
                                        childAspectRatio: 0.85,
                                      ),
                                  itemCount: place.products.where(matches).length,
                                  itemBuilder: (context, index) {
                                    final product = place.products.where(matches).elementAt(index);
                                    return ProductCard(
                                      product: product,
                                      onTap: () => _onProductTap(product),
                                    );
                                  },
                                ),
                                const SizedBox(height: 16),
                              ],
                          ],
                        );
                      }),
                    ),
                    const SizedBox(height: 100),
                  ],
                ),
                Positioned(
                  bottom: 20,
                  left: 25,
                  right: 25,
                  child: Obx(() {
                    final count = cartController.cartCount;
                    return ElevatedButton(
                      onPressed: () {
                        Get.back();
                        _showCart();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange.shade800,
                        minimumSize: const Size(double.infinity, 60),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                        elevation: 10,
                        shadowColor: Colors.orange.withOpacity(0.4),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            CupertinoIcons.shopping_cart,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 15),
                          Text(
                            "VOIR LE PANIER ($count)",
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
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
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      builder: (context) {
        return SafeArea(
          top: false,
          child: Obx(() {
            final items = cartController.cart;

            return Container(
              padding: const EdgeInsets.all(25),
              height: MediaQuery.of(context).size.height * 0.85,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "Validation Commande",
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: Colors.indigo,
                        ),
                      ),

                      GestureDetector(
                        onTap: (){
                          Navigator.pop(context);
                          _showProductSelectionModal();
                        },
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Colors.indigoAccent, Colors.indigo],
                            ),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.add, color: Colors.white, size: 18),
                        ),
                      )
                    ],
                  ),
                  if (cartController.selectedTable.value != null)
                    Row(
                      children: [
                        Container(
                          margin: const EdgeInsets.only(top: 6),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.orange.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: Colors.orange.withOpacity(0.2),
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
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () => _showTableSelectionModal(),
                          child: Container(
                            margin: const EdgeInsets.only(top: 6),
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.orange.withOpacity(0.1),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.orange.withOpacity(0.2),
                              ),
                            ),
                            child: Icon(
                              Icons.edit,
                              color: Colors.orange.shade900,
                              size: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  const Divider(height: 40),
                  if (items.isEmpty)
                    const Expanded(child: Center(child: Text("Panier vide")))
                  else
                    Expanded(
                      child: ListView.builder(
                        itemCount: items.length,
                        itemBuilder: (context, index) {
                          final item = items[index];
                          return CartItemTile(
                            item: item,
                            onAdd: () => cartController.addToCart(item),
                            onRemove: () => cartController.removeFromCart(item),
                          );
                        },
                      ),
                    ),
                  if (items.isNotEmpty) ...[
                    const Divider(height: 40),
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
                            child: DeviseTotals(items: items.toList()),
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
                        minimumSize: const Size(double.infinity, 60),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                      child: const Text(
                        "CONFIRMER LA VENTE",
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      ),
                    ),

                    if (cartController.selectedTable.value != null ||  Get.find<ManagerController>().selectedServer.value != null) ...[
                      SizedBox(height: 10.0,),
                      OutlinedButton(
                        onPressed: () {
                          cartController.cancelOrder();
                          cartController.selectedTable.value = null;
                          Get.find<ManagerController>().selectedServer.value = null;
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
            ManagerHomeScreen(onTakeOrder: _onTakeOrder, onShowCart: _showCart),
            OrdersScreen(onShowCart: _showCart,),
            const SettingsScreen(),
            const ManagerMenuScreen(),
          ],
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
        floatingActionButton: Obx(() {
          final count = cartController.cartCount;
          return FloatingActionButton(
            onPressed: _onTakeOrder,
            backgroundColor: Colors.orange.shade800,
            shape: const CircleBorder(),
            elevation: 3,
            child: Badge(
              backgroundColor: Colors.indigo,
              label: Text(
                "$count",
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 10,
                ),
              ),
              isLabelVisible: count > 0,
              padding: const EdgeInsets.all(4),
              child: Icon(
                count > 0 ? Icons.shopping_cart_checkout : Icons.add,
                color: Colors.white,
                size: 26,
              ),
            ),
          );
        }),
        bottomNavigationBar: _buildBottomBar(),
      ),
    );
  }

  Widget _buildBottomBar() {
    return BottomAppBar(
      padding: EdgeInsets.zero,
      height: 70,
      color: Colors.white,
      shape: const CircularNotchedRectangle(),
      notchMargin: 10,
      elevation: 20,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildNavItem(0, Icons.grid_view_rounded, 'Accueil'),
          Obx(
            () => _buildNavItem(
              1,
              Icons.receipt_long_rounded,
              'Commandes',
              badgeCount: orderController.orders.length,
            ),
          ),
          const SizedBox(width: 70),
          _buildNavItem(2, CupertinoIcons.gear_big, 'Paramètres'),
          _buildNavItem(3, Icons.menu_rounded, 'Menu'),
        ],
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
        onTap: () => _pageController.jumpToPage(index),
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
