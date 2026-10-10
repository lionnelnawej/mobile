import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';
import 'package:loyambo/kernel/controllers/manager_controller.dart';
import '/kernel/controllers/order_controller.dart';
import '/kernel/controllers/cart_controller.dart';
import '/kernel/controllers/printer_controller.dart';
import '/kernel/controllers/auth_controller.dart';
import '/kernel/models/order.dart';
import '/kernel/models/restaurant_table.dart';
import 'package:intl/intl.dart';
import '/kernel/models/product.dart';
import '/kernel/services/devise_book.dart';
import '/widgets/devise_totals.dart';

class OrdersScreen extends StatelessWidget {
  final Function()? onShowCart;
  const OrdersScreen({super.key, this.onShowCart});

  @override
  Widget build(BuildContext context) {
    final OrderController orderController = Get.find<OrderController>();
    final CartController cartController = Get.find<CartController>();
    final PrinterController printerController = Get.find<PrinterController>();
    bool isTablet = MediaQuery.of(context).size.width > 600;

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      body: Column(
        children: [
          _buildHeader(context, orderController),
          Expanded(
            child: Obx(() {
              final archive = orderController.showDone.value;
              final source = archive ? orderController.doneOrders : orderController.orders;
              if (!archive && orderController.isLoading.value) {
                return const Center(child: CircularProgressIndicator());
              }
              if (source.isEmpty) {
                return Center(
                  child: Text(
                    archive ? "Aucune commande encaissée" : "Aucune commande en cours",
                    style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold),
                  ),
                );
              }
              return Center(
                child: Container(
                  constraints: BoxConstraints(
                    maxWidth: isTablet ? 850 : double.infinity,
                  ),
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(20.0, 20.0, 20.0, 80.0),
                    itemCount: source.length,
                    itemBuilder: (context, index) {
                      final order = source[index];
                      return _buildOrderSummaryCard(
                        context,
                        order,
                        orderController,
                        cartController,
                        printerController,
                        archive: archive,
                      );
                    },
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 70),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, OrderController controller) {
    bool isTablet = MediaQuery.of(context).size.width > 600;
    return Container(
      padding: const EdgeInsets.only(top: 50, left: 20, right: 20, bottom: 20),
      decoration: const BoxDecoration(color: Colors.indigo),
      child: Center(
        child: Container(
          constraints: BoxConstraints(
            maxWidth: isTablet ? 850 : double.infinity,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(
                    Icons.receipt_long_rounded,
                    color: Colors.white,
                    size: 28,
                  ),
                  SizedBox(width: 15),
                  Text(
                    "Commandes",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
              Obx(() => Row(
                    children: [
                      _tab(controller, "En cours", false),
                      const SizedBox(width: 6),
                      _tab(controller, "Encaissées", true),
                    ],
                  )),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tab(OrderController controller, String label, bool done) {
    final selected = controller.showDone.value == done;
    return TextButton(
      onPressed: () {
        controller.showDone.value = done;
        if (done) controller.fetchDone();
      },
      style: TextButton.styleFrom(
        backgroundColor: selected ? Colors.white : Colors.white24,
        foregroundColor: selected ? Colors.black : Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      ),
      child: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildOrderSummaryCard(
    BuildContext context,
    Order order,
    OrderController controller,
    CartController cartController,
    PrinterController printerController, {
    bool archive = false,
  }) {
    final serverName = order.user?.name ?? 'Inconnu';
    final serverInitials = serverName.isNotEmpty
        ? serverName.split(' ').map((e) => e[0]).take(2).join().toUpperCase()
        : '?';
    
    return GestureDetector(
      onTap: () => showOrderDetails(
        context,
        order,
        controller,
        cartController,
        printerController,
        onShowCart,
        archive: archive,
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: order.statusService == "servie"
                ? Colors.green.withValues(alpha: 0.2)
                : Colors.indigo.withValues(alpha: 0.1),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: order.statusService == "servie"
                        ? Colors.green.withValues(alpha: 0.1)
                        : Colors.indigo.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.restaurant_rounded,
                    color: order.statusService == "servie"
                        ? Colors.green
                        : Colors.indigo,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              order.numeroFacture ?? "Table #${order.id}",
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 15,
                              ),
                            ),
                          ),
                          if (order.kitchenReady || order.barReady)
                            Container(
                              margin: const EdgeInsets.only(left: 6),
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFF16A34A),
                                borderRadius: BorderRadius.circular(99),
                              ),
                              child: const Text(
                                "Prête",
                                style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800),
                              ),
                            ),
                        ],
                      ),
                      Text(
                        "Table : ${order.table?.name ?? 'N/A'} • ${order.items.length} articles",
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      DeviseTotals(items: order.items, compact: true),
                      Text(
                        DateFormat('HH:mm').format(order.createdAt),
                        style: TextStyle(
                          color: Colors.grey.shade400,
                          fontSize: 9,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 10),
              child: Divider(height: 1, thickness: 0.5),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 12,
                      backgroundColor: Colors.indigo.withValues(alpha: 0.1),
                      child: Text(
                        serverInitials,
                        style: const TextStyle(
                          fontSize: 8,
                          fontWeight: FontWeight.w900,
                          color: Colors.indigo,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      serverName,
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: (archive || order.status == 'payée')
                        ? Colors.green.withValues(alpha: 0.1)
                        : order.statusService == "servie"
                        ? Colors.green.withValues(alpha: 0.1)
                        : Colors.orange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        (archive || order.status == 'payée' || order.statusService == "servie")
                            ? Icons.check_circle_rounded
                            : Icons.timer_rounded,
                        size: 12,
                        color: (archive || order.status == 'payée' || order.statusService == "servie")
                            ? Colors.green
                            : Colors.orange.shade800,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        (archive || order.status == 'payée')
                            ? "PAYÉ"
                            : (order.statusService == "servie" ? "SERVIE" : "EN COURS"),
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                          color: (archive || order.status == 'payée' || order.statusService == "servie")
                              ? Colors.green
                              : Colors.orange.shade800,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static void showOrderDetails(
    BuildContext context,
    Order order,
    OrderController controller,
    CartController cartController,
    PrinterController printerController,
    Function()? onShowCart, {
    bool archive = false,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width > 600
            ? 600
            : double.infinity,
      ),
      builder: (context) => Obx(() {
        final live = archive
            ? order
            : controller.orders.firstWhereOrNull((o) => o.id == order.id);
        if (!archive && live == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!context.mounted) return;
            final route = ModalRoute.of(context);
            if (route?.isCurrent == true) Navigator.of(context).pop();
          });
        }
        final shown = live ?? order;

        final currentUser = Get.find<AuthController>().currentUser.value;
        final userRole = currentUser?.role;
        final canModify = !archive && (currentUser?.canModifyOrder ?? false);
        final canBonus = !archive && shown.status == 'en_attente' && (currentUser?.canGrantBonus ?? false);
        final isInspector = userRole == 'caissier';
        final canPay = isInspector && !archive && (currentUser?.allows('creer-paiements') ?? false);

        return DraggableScrollableSheet(
          initialChildSize: 0.9,
          maxChildSize: 0.9,
          minChildSize: 0.5,
          builder: (_, scrollController) => Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
            ),
            child: SafeArea(
              child: Column(
                children: [
                  const SizedBox(height: 15),
                  Container(
                    width: 40,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(5),
                    ),
                  ),
                  Expanded(
                    child: ListView(
                      controller: scrollController,
                      padding: const EdgeInsets.all(25),
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Détails Commande",
                                  style: TextStyle(
                                    color: Colors.indigo.shade900,
                                    fontSize: 22,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                Text(
                                  "#${shown.numeroFacture} • Table ${shown.table?.name ?? 'N/A'}",
                                  style: const TextStyle(
                                    color: Colors.grey,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            IconButton(
                              onPressed: () => Navigator.pop(context),
                              icon: const Icon(Icons.close_rounded, size: 30),
                            ),
                          ],
                        ),
                        const Divider(height: 30),
                        ..._groupedLines(shown, canModify, controller),
                        const Divider(height: 30),
                        const Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            "TOTAL À PAYER",
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                              color: Colors.grey,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        DeviseTotals(
                          items: shown.items,
                          showButtons: true,
                        ),
                        const SizedBox(height: 25),
                        if (!archive) Row(
                          children: [
                            Expanded(
                              child: _buildCompactAction(
                                Icons.swap_horiz_rounded,
                                "Transférer Table",
                                () => _showChangeTableModal(
                                  context,
                                  shown,
                                  controller,
                                  cartController,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildCompactAction(
                                Icons.call_merge_rounded,
                                "Fusionner Factures",
                                () => _showMergeModal(
                                  context,
                                  shown,
                                  controller,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildCompactAction(
                                Icons.content_copy_rounded,
                                "Dupliquer facture",
                                () => _duplicateOrder(
                                  shown,
                                  cartController,
                                  context,
                                  onShowCart,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (!archive) const SizedBox(height: 12),
                        if (canModify) _buildDetailAction(
                          Icons.edit_note_rounded,
                          "Modifier la commande",
                          "Ajouter ou retirer des produits",
                          () => _showAddItemsModal(
                            context,
                            shown,
                            controller,
                            cartController,
                          ),
                        ),
                        if (canBonus) _buildDetailAction(
                          Icons.card_giftcard_rounded,
                          "Bonus",
                          "Offrir un produit à prix 0",
                          () => _showAddItemsModal(
                            context,
                            shown,
                            controller,
                            cartController,
                            bonus: true,
                          ),
                        ),
                        if (!archive) _buildDetailAction(
                          Icons.check_circle_outline_rounded,
                          "Tout marquer comme servi",
                          "Valider la livraison de tous les articles",
                          () => controller.servingItem(shown.id),
                        ),

                        const SizedBox(height: 15),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _buildBottomActionIcon(
                              icon: Icons.print_rounded,
                              label: "IMPRIMER",
                              color: Colors.indigo,
                              onTap: () => printerController.printOrderTicket(
                                shown,
                              ),
                            ),
                            const SizedBox(width: 15.0),
                            _buildBottomActionIcon(
                              icon: Icons.restaurant_menu_rounded,
                              label: "CUISINE",
                              color: Colors.indigo,
                              onTap: () => printerController.printCuisineTicket(
                                shown,
                              ),
                            ),
                            if (canPay) ...[
                              const SizedBox(width: 15.0),
                              _buildBottomActionIcon(
                                icon: Icons.payments_rounded,
                                label: "ENCAISSER",
                                color: Colors.green,
                                onTap: () => _showEncaissementModal(
                                  context,
                                  shown,
                                  controller,
                                ),
                                isLoading: controller.isActionLoading.value,
                              ),
                            ],
                          ],
                        ),
                        if (!archive &&
                            Get.find<AuthController>().currentUser.value?.canCancelOrder == true &&
                            shown.status == 'en_attente') ...[
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            height: 52,
                            child: OutlinedButton.icon(
                              onPressed: controller.isActionLoading.value
                                  ? null
                                  : () => _confirmDeleteOrder(context, shown, controller),
                              icon: const Icon(Icons.delete_outline_rounded),
                              label: const Text(
                                "SUPPRIMER LA COMMANDE",
                                style: TextStyle(fontWeight: FontWeight.w900),
                              ),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.red,
                                side: const BorderSide(color: Colors.red),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }),
    );
  }

  static Future<void> _confirmDeleteOrder(
    BuildContext context,
    Order order,
    OrderController controller,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text("Supprimer la commande"),
        content: Text(
          "Annuler ${order.numeroFacture ?? 'cette commande'} ? Cette action retire la commande en attente.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text("Annuler"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text("Supprimer", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final ok = await controller.deleteOrder(order.id);
    if (ok && context.mounted) Navigator.pop(context);
  }

  static void _duplicateOrder(
    Order order,
    CartController cartController,
    BuildContext context,
    Function()? onShowCart,
  ) {
    // 1. Préparer les données du panier de manière atomique (plus performant)
    final itemsToCopy = order.items.map((item) => Product(
      id: item.id,
      name: item.name,
      category: item.category,
      price: item.price,
      image: item.image,
      stockActuel: item.stockActuel,
      quantified: item.quantified,
      quantity: item.quantity,
      categoryType: item.categoryType,
      currency: item.currency,
    )).toList();

    cartController.cart.assignAll(itemsToCopy);
    cartController.selectedTable.value = order.table;
    
    // Assigner le serveur si on est en mode Manager pour conserver l'attribution
    if (Get.isRegistered<ManagerController>()) {
      Get.find<ManagerController>().selectedServer.value = order.user;
    }
    
    // 2. Déclencher l'affichage du panier par-dessus
    // On utilise un délai pour laisser le temps aux observables GetX de se propager
    Future.delayed(const Duration(milliseconds: 300), () {
      if (onShowCart != null) {
        onShowCart();
      } else {
        // Fallback global via le controller si la fonction n'est pas passée localement
        cartController.showCart();
      }
    });

    EasyLoading.showSuccess("Facture dupliquée");
  }

  static void _showEncaissementModal(
    BuildContext context,
    Order order,
    OrderController controller,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      builder: (context) => _EncaissementSheet(order: order, controller: controller),
    );
  }

  static Widget _paymentMethodCard({
    required IconData icon,
    required String label,
    required String value,
    required String selected,
    required VoidCallback onTap,
  }) {
    bool isSelected = selected == value;
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 15),
          decoration: BoxDecoration(
            color: isSelected
                ? Colors.indigo.withValues(alpha: 0.05)
                : Colors.white,
            borderRadius: BorderRadius.circular(15),
            border: Border.all(
              color: isSelected ? Colors.indigo : Colors.grey.shade200,
              width: 2,
            ),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                color: isSelected ? Colors.indigo : Colors.grey,
                size: 24,
              ),
              const SizedBox(height: 6),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? Colors.indigo : Colors.grey,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Widget _buildBottomActionIcon({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback? onTap,
    bool isLoading = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(15),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: isLoading
                  ? SizedBox(
                      height: 28,
                      width: 28,
                      child: CircularProgressIndicator(
                        color: color,
                        strokeWidth: 2,
                      ),
                    )
                  : Icon(icon, color: color, size: 28),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Widget _qtyActionBtn(IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: Colors.indigo.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: Colors.indigo, size: 18),
      ),
    );
  }

  static Widget _buildDetailAction(
    IconData icon,
    String title,
    String subtitle,
    VoidCallback onTap,
  ) {
    return ListTile(
      onTap: onTap,
      contentPadding: EdgeInsets.zero,
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.indigo.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: Colors.indigo),
      ),
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
      ),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 11)),
      trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
    );
  }

  static Widget _buildCompactAction(
    IconData icon,
    String title,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(15),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: Colors.indigo.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: Colors.indigo.withValues(alpha: 0.08)),
        ),
        child: Column(
          children: [
            Icon(icon, color: Colors.indigo, size: 20),
            const SizedBox(height: 6),
            Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 9,
                color: Colors.indigo,
              ),
            ),
          ],
        ),
      ),
    );
  }

  static void _showAddItemsModal(
    BuildContext context,
    Order order,
    OrderController controller,
    CartController cartController, {
    bool bonus = false,
  }) {
    final searchController = TextEditingController();
    final selectedCategory = "Tout".obs;
    final filteredProducts = <Product>[].obs;

    void filter() {
      filteredProducts.assignAll(
        cartController.allProducts.where((p) {
          final matchesQuery = p.name.toLowerCase().contains(
            searchController.text.toLowerCase(),
          );
          final matchesCat =
              selectedCategory.value == "Tout" ||
              p.category == selectedCategory.value;
          return matchesQuery && matchesCat;
        }).toList(),
      );
    }

    filter();
    searchController.addListener(filter);
    ever(selectedCategory, (_) => filter());
    final stockWatch = ever(cartController.allProducts, (_) => filter());

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    bonus ? "Bonus" : "Modifier la commande",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: Colors.indigo,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: TextField(
                controller: searchController,
                decoration: InputDecoration(
                  hintText: "Rechercher un produit...",
                  prefixIcon: const Icon(Icons.search),
                  filled: true,
                  fillColor: Colors.grey.shade100,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 15),
            SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children:
                    ["Tout", ...cartController.categories.map((c) => c.libelle)]
                        .map(
                          (cat) => Obx(() {
                            final isSelected = selectedCategory.value == cat;
                            return Padding(
                              padding: const EdgeInsets.only(right: 10),
                              child: ChoiceChip(
                                label: Text(cat),
                                selected: isSelected,
                                onSelected: (val) =>
                                    selectedCategory.value = cat,
                                selectedColor: Colors.indigo,
                                labelStyle: TextStyle(
                                  color: isSelected
                                      ? Colors.white
                                      : Colors.indigo,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            );
                          }),
                        )
                        .toList(),
              ),
            ),
            const SizedBox(height: 15),
            Expanded(
              child: Obx(
                () => ListView.builder(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: filteredProducts.length,
                  itemBuilder: (context, index) {
                    final product = filteredProducts[index];
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(vertical: 5),
                      leading: Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: Colors.indigo.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.restaurant_menu,
                          color: Colors.indigo,
                        ),
                      ),
                      title: Row(
                        children: [
                          Expanded(
                            child: Text(
                              product.name,
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                          if (product.tracksStock)
                            Text(
                              '${product.availableStock}',
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                color: product.isOutOfStock
                                    ? Colors.red.shade700
                                    : Colors.indigo,
                              ),
                            ),
                        ],
                      ),
                      subtitle: Text(
                        "${DeviseBook.instance.formatMoney(product.price)} ${DeviseBook.instance.symbolOf(product.currency)} • ${product.category}",
                      ),
                      trailing: Obx(() {
                        final isLoading = controller.isActionLoading.value;

                        final blocked = product.isOutOfStock;
                        return IconButton(
                          icon: Icon(
                            blocked ? Icons.block_rounded : Icons.add_circle,
                            color: isLoading
                                ? Colors.grey
                                : blocked
                                    ? Colors.red.shade400
                                    : Colors.indigo,
                            size: 30,
                          ),
                          onPressed: isLoading
                              ? null
                              : () => bonus
                                  ? controller.grantBonus(order.id, product)
                                  : controller.addProductToOrder(
                                  order.id,
                                  product,
                                ),
                        );
                      }),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    ).whenComplete(stockWatch.dispose);
  }

  static List<Widget> _groupedLines(
    Order order,
    bool canModify,
    OrderController controller,
  ) {
    final groups = order.groups;
    final split = groups.length > 1;
    final widgets = <Widget>[];
    groups.forEach((label, items) {
      if (split) {
        widgets.add(Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 8),
          child: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w900, color: Colors.indigo, fontSize: 13),
          ),
        ));
      }
      for (final item in items) {
        widgets.add(Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            children: [
              Row(
                children: [
                  if (canModify && !item.isBonus)
                    _qtyActionBtn(
                      Icons.remove_rounded,
                      () => controller.decreaseProductQuantity(order.id, item.id),
                    ),
                  Container(
                    width: 40,
                    alignment: Alignment.center,
                    child: Text(
                      "${item.quantity}",
                      style: const TextStyle(fontWeight: FontWeight.w900, color: Colors.indigo, fontSize: 15),
                    ),
                  ),
                  if (canModify && !item.isBonus)
                    _qtyActionBtn(
                      Icons.add_rounded,
                      () => controller.addProductToOrder(order.id, item),
                    ),
                ],
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Text(
                  item.isBonus ? "${item.name}  ·  BONUS" : item.name,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                ),
              ),
              Text(
                "${DeviseBook.instance.formatMoney(item.quantity * item.price)} ${DeviseBook.instance.symbolOf(item.currency)}",
                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
              ),
            ],
          ),
        ));
      }
      if (split) {
        final sub = <Product>[...items];
        widgets.add(Align(
          alignment: Alignment.centerRight,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              "Sous-total",
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.grey.shade600),
            ),
          ),
        ));
        widgets.add(DeviseTotals(items: sub, showButtons: false));
        widgets.add(const SizedBox(height: 8));
      }
    });
    return widgets;
  }

  static void _showChangeTableModal(
    BuildContext context,
    Order order,
    OrderController controller,
    CartController cartController,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width > 600
            ? 500
            : double.infinity,
      ),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      builder: (context) {
        RestaurantTable? current;
        for (final t in cartController.tables) {
          if (t.id == order.table?.id) current = t;
        }
        final placeId = order.table?.emplacementId ?? current?.emplacementId;
        final targets = cartController.tables.where((t) {
          if (t.id == order.table?.id) return false;
          if (placeId == null) return false;
          return t.emplacementId == placeId;
        }).toList();
        final height = MediaQuery.sizeOf(context).height * 0.7;
        return SafeArea(
        child: SizedBox(
          height: height,
          width: double.infinity,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(25, 25, 25, 8),
                child: Text(
                  "Transférer vers une table",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: Colors.indigo,
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 25),
                child: Text(
                  "Tables du même emplacement",
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: targets.isEmpty
                    ? const Center(child: Text("Aucune autre table dans cet emplacement."))
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 25),
                        itemCount: targets.length,
                        separatorBuilder: (context, index) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final table = targets[index];
                          return InkWell(
                            onTap: () {
                              controller.changeTable(
                                order.id,
                                order.table?.id ?? 0,
                                table.id,
                              );
                              Navigator.pop(context);
                            },
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(15),
                                border: Border.all(color: Colors.indigo.withValues(alpha: 0.15), width: 2),
                              ),
                              child: Text(
                                "Table ${table.name}",
                                style: const TextStyle(fontWeight: FontWeight.w800, color: Colors.indigo),
                              ),
                            ),
                          );
                        },
                      ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      );
      },
    );
  }

  static void _showMergeModal(
    BuildContext context,
    Order sourceOrder,
    OrderController controller,
  ) {
    final sameTableOrders = controller.orders
        .where((o) => o.id != sourceOrder.id && o.status == 'en_attente')
        .toList();
    final selectedOrderIds = <int>[sourceOrder.id].obs;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width > 600
            ? 500
            : double.infinity,
      ),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      builder: (context) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.75,
          child: Obx(
            () => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 25),
                  child: Text(
                    "Fusionner Factures",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: Colors.indigo,
                    ),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 25),
                  child: Text(
                    "Sélectionnez les commandes à regrouper",
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ),
                const SizedBox(height: 20),
                if (sameTableOrders.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(25),
                    child: Center(
                      child: Text(
                        "Aucune autre commande en cours.",
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                  )
                else
                  Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: sameTableOrders.length,
                      itemBuilder: (context, index) {
                        final targetOrder = sameTableOrders[index];
                        final isSelected = selectedOrderIds.contains(
                          targetOrder.id,
                        );
                        return CheckboxListTile(
                          value: isSelected,
                          activeColor: Colors.indigo,
                          onChanged: (val) {
                            if (val == true) {
                              selectedOrderIds.add(targetOrder.id);
                            } else {
                              selectedOrderIds.remove(targetOrder.id);
                            }
                          },
                          title: Text(
                            "Table ${targetOrder.table?.name ?? '—'} · ${targetOrder.numeroFacture ?? "#${targetOrder.id}"}",
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(
                            "${DeviseBook.instance.formatMoney(targetOrder.totalAmount)} • ${targetOrder.items.length} articles",
                          ),
                          secondary: const Icon(
                            Icons.receipt_long_rounded,
                            color: Colors.indigo,
                          ),
                        );
                      },
                    ),
                  ),
                const SizedBox(height: 20),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 25),
                  child: ElevatedButton(
                    onPressed: selectedOrderIds.length < 2
                        ? null
                        : () {
                            controller.mergeOrders(
                              selectedOrderIds.toList(),
                              sourceOrder.table?.id ?? 0,
                            );
                            Navigator.pop(context);
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.indigo,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 55),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                    ),
                    child: const Text(
                      "VALIDER LA FUSION",
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EncaissementSheet extends StatefulWidget {
  final Order order;
  final OrderController controller;

  const _EncaissementSheet({required this.order, required this.controller});

  @override
  State<_EncaissementSheet> createState() => _EncaissementSheetState();
}

class _EncaissementSheetState extends State<_EncaissementSheet> {
  final _remise = _RemiseDraft();
  String _method = 'cash';
  String _devise = 'native';
  late final bool _canRemise;

  @override
  void initState() {
    super.initState();
    _canRemise = Get.find<AuthController>().currentUser.value?.canGrantRemise == true;
  }

  @override
  void dispose() {
    _remise.dispose();
    super.dispose();
  }

  void _applyRemise() {
    final native = _orderNative(widget.order);
    setState(() => _remise.error = _remiseError(_remise, native));
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
          child: Container(
            padding: const EdgeInsets.all(25),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      "Encaissement",
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.indigo),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                const Text(
                  "Le montant est calculé automatiquement. Il n'est pas modifiable.",
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 25),
                const Text(
                  "MONTANT À PERCEVOIR",
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Colors.grey),
                ),
                const SizedBox(height: 10),
                DeviseTotals(
                  items: widget.order.items,
                  showButtons: true,
                  onModeChanged: (mode) => _devise = mode,
                  discountPercent: _remise.type == 'pourcent' ? _remise.value : 0,
                  discountAmount: _remise.type == 'montant' ? _remise.value : 0,
                  discountCurrency: _remise.devise,
                ),
                if (_canRemise) _cashierRemise(widget.order, _remise, _applyRemise),
                const SizedBox(height: 25),
                const Text(
                  "MODE DE PAIEMENT",
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Colors.grey),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    OrdersScreen._paymentMethodCard(
                      icon: Icons.payments_rounded,
                      label: "CASH",
                      value: "cash",
                      selected: _method,
                      onTap: () => setState(() => _method = 'cash'),
                    ),
                    const SizedBox(width: 12),
                    OrdersScreen._paymentMethodCard(
                      icon: Icons.smartphone_rounded,
                      label: "MOBILE MONEY",
                      value: "m-pesa",
                      selected: _method,
                      onTap: () => setState(() => _method = 'm-pesa'),
                    ),
                  ],
                ),
                const SizedBox(height: 35),
                ElevatedButton(
                  onPressed: _remise.error != null
                      ? null
                      : () async {
                          final etsId = Get.find<AuthController>().currentUser.value?.etsId ?? 0;
                          final success = await widget.controller.encaissement(
                            widget.order.id,
                            etsId,
                            _method,
                            devise: _devise,
                            remise: _canRemise ? _remise.value : 0,
                            remiseType: _remise.type,
                            remiseDevise: _remise.devise,
                          );
                          if (success && context.mounted) {
                            final navigator = Navigator.of(context);
                            navigator.pop();
                            if (navigator.canPop()) navigator.pop();
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    minimumSize: const Size(double.infinity, 60),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                    elevation: 0,
                  ),
                  child: const Text(
                    "VALIDER L'ENCAISSEMENT",
                    style: TextStyle(fontWeight: FontWeight.w900, color: Colors.white),
                  ),
                ),
                const SizedBox(height: 15),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RemiseDraft {
  String type = 'pourcent';
  double value = 0;
  String devise = 'FC';
  String? error;
  final controller = TextEditingController();

  void dispose() => controller.dispose();
}

Map<String, double> _orderNative(Order order) {
  return DeviseBook.instance.nativeTotals(
    order.items.map((item) => (devise: item.currency, amount: item.price * item.quantity)),
  );
}

String? _remiseError(_RemiseDraft remise, Map<String, double> native) {
  if (remise.value <= 0) return null;
  if (remise.type == 'pourcent') {
    if (remise.value > 100) return 'La remise ne peut pas dépasser 100 %.';
    return null;
  }
  final code = DeviseBook.instance.normalize(remise.devise);
  final max = native[code] ?? 0;
  if (max <= 0) return "Cette commande n'a pas de montant en $code.";
  if (remise.value - max > 0.009) return 'La remise dépasse le total en $code.';
  return null;
}

Widget _cashierRemise(
  Order order,
  _RemiseDraft remise,
  VoidCallback onChanged,
) {
  final native = _orderNative(order);
  final codes = native.keys.toList();
  if (codes.isNotEmpty && !codes.contains(DeviseBook.instance.normalize(remise.devise))) {
    remise.devise = codes.first;
  }

  void apply() => onChanged();

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const SizedBox(height: 18),
      const Text(
        'REMISE',
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Colors.grey),
      ),
      const SizedBox(height: 8),
      Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () {
                remise.type = 'pourcent';
                apply();
              },
              style: OutlinedButton.styleFrom(
                backgroundColor: remise.type == 'pourcent' ? Colors.indigo : Colors.white,
                foregroundColor: remise.type == 'pourcent' ? Colors.white : Colors.indigo,
              ),
              child: const Text('%'),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: OutlinedButton(
              onPressed: () {
                remise.type = 'montant';
                apply();
              },
              style: OutlinedButton.styleFrom(
                backgroundColor: remise.type == 'montant' ? Colors.indigo : Colors.white,
                foregroundColor: remise.type == 'montant' ? Colors.white : Colors.indigo,
              ),
              child: const Text('Montant'),
            ),
          ),
        ],
      ),
      const SizedBox(height: 8),
      TextField(
        controller: remise.controller,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(
          hintText: remise.type == 'pourcent' ? 'Pourcentage' : 'Montant',
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
        onChanged: (text) {
          remise.value = double.tryParse(text.replaceAll(',', '.')) ?? 0;
          apply();
        },
      ),
      if (remise.type == 'montant' && codes.isNotEmpty) ...[
        const SizedBox(height: 8),
        DropdownButton<String>(
          value: codes.contains(remise.devise) ? remise.devise : codes.first,
          isExpanded: true,
          items: [
            for (final code in codes) DropdownMenuItem(value: code, child: Text(code)),
          ],
          onChanged: (code) {
            if (code == null) return;
            remise.devise = code;
            apply();
          },
        ),
      ],
      if (remise.error != null)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(
            remise.error!,
            style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w700),
          ),
        ),
    ],
  );
}



