import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import '../../../widgets/user_status.dart' show UserStatus;
import '/kernel/controllers/order_controller.dart';
import '/kernel/controllers/cart_controller.dart';
import '/kernel/controllers/printer_controller.dart';
import '/kernel/controllers/auth_controller.dart';
import '/kernel/controllers/manager_controller.dart';
import '/kernel/services/devise_book.dart';
import '/screens/public/serve/orders_screen.dart';

class ManagerHomeScreen extends StatelessWidget {
  final VoidCallback onTakeOrder;
  final VoidCallback onShowCart;

  const ManagerHomeScreen({
    super.key, 
    required this.onTakeOrder,
    required this.onShowCart,
  });

  @override
  Widget build(BuildContext context) {
    final OrderController orderController = Get.find<OrderController>();
    final CartController cartController = Get.find<CartController>();
    final PrinterController printerController = Get.find<PrinterController>();
    final AuthController authController = Get.find<AuthController>();
    final ManagerController managerController = Get.find<ManagerController>();

    bool isTablet = MediaQuery.of(context).size.width > 600;

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: RefreshIndicator(
        onRefresh: () => managerController.refreshManagerData(),
        color: Colors.indigo,
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          slivers: [
            _buildSliverHeader(authController, isTablet),
            SliverToBoxAdapter(
              child: Center(
                child: Container(
                  constraints: BoxConstraints(
                    maxWidth: isTablet ? 800 : double.infinity,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 60),
                      _buildDashboardCounters(managerController),
                      const SizedBox(height: 25),
                      _buildPendingOrdersHeader(orderController),
                      const SizedBox(height: 12),
                      Obx(() {
                        if (managerController.isLoading.value &&
                            orderController.orders.isEmpty) {
                          return _buildHorizontalOrdersSkeleton();
                        }
                        return _buildHorizontalOrders(
                          context,
                          orderController,
                          cartController,
                          printerController,
                        );
                      }),
                      const SizedBox(height: 120),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDashboardCounters(ManagerController controller) {
    return Obx(() {
      final counts = controller.dashboardCounts;
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          children: [
            _buildStatCard(
              "Ventes de la journée.",
              "${DeviseBook.instance.formatMoney(double.tryParse(counts['sells']?.toString() ?? '0') ?? 0)}",
              Icons.auto_graph_rounded,
              Colors.teal,
              isLarge: true,
            ),
            const SizedBox(height: 10),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: EdgeInsets.zero,
              crossAxisCount: 2,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 2.2,
              children: [
                _buildStatCard(
                  "Factures",
                  "${counts['facs'] ?? 0}",
                  Icons.receipt_long_rounded,
                  Colors.indigo,
                ),
                _buildStatCard(
                  "En cours",
                  "${counts['pendings'] ?? 0}",
                  Icons.timer_rounded,
                  Colors.orange,
                ),
                _buildStatCard(
                  "Annulées",
                  "${counts['cancelled'] ?? 0}",
                  Icons.info_outline,
                  Colors.redAccent,
                ),
                _buildStatCard(
                  "Serveurs",
                  "${counts['users'] ?? 0}",
                  Icons.badge_outlined,
                  Colors.blueGrey,
                ),
              ],
            ),
          ],
        ),
      );
    });
  }

  Widget _buildStatCard(
    String label,
    String value,
    IconData icon,
    Color color, {
    bool isLarge = false,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: isLarge ? 16 : 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.1), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: isLarge ? 20 : 16),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    color: Colors.black87,
                    fontSize: isLarge ? 20 : 15,
                    fontWeight: FontWeight.w900,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  label,
                  style: TextStyle(
                    color: Colors.grey.shade500,
                    fontSize: isLarge ? 10 : 8,
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSliverHeader(AuthController authController, bool isTablet) {
    return SliverToBoxAdapter(
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            height: 220,
            width: double.infinity,
            decoration: const BoxDecoration(color: Colors.indigo),
            child: Stack(
              children: [
                Positioned(
                  top: -20,
                  right: -20,
                  child: Container(
                    width: 150,
                    height: 150,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                Positioned(
                  bottom: 40,
                  left: -30,
                  child: Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 50, left: 20, right: 20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      SvgPicture.asset(
                        'assets/images/loyambo-light.svg',
                        height: 45,
                      ),
                      const UserStatus(),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            bottom: -50,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 15),
                padding: const EdgeInsets.all(22),
                constraints: BoxConstraints(
                  maxWidth: isTablet ? 800 : double.infinity,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(15.0),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.02),
                      blurRadius: 2,
                      offset: const Offset(0, 2),
                    ),
                  ],
                  border: Border.all(color: Colors.indigo.shade50, width: 1),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.waving_hand_rounded,
                        color: Colors.orange.shade800,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 18),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Bienvenu, ${authController.currentUser.value?.name?.capitalizeFirst ?? 'Manager'} !",
                            style: const TextStyle(
                              color: Colors.black87,
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.5,
                            ),
                          ),
                          Text(
                            "Votre session manager est active.",
                            style: TextStyle(
                              color: Colors.grey.shade500,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    _buildDayActionButton(),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDayActionButton() {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Colors.indigoAccent, Colors.indigo],
        ),
        shape: BoxShape.circle,
      ),
      child: const Icon(Icons.flash_on_rounded, color: Colors.white, size: 18),
    );
  }

  Widget _buildPendingOrdersHeader(OrderController controller) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              const Text(
                "Commandes en attente",
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                  color: Colors.indigo,
                ),
              ),
              const SizedBox(width: 8),
              Obx(
                () => Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade800.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    "${controller.orders.length}",
                    style: TextStyle(
                      color: Colors.orange.shade900,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const Icon(
            Icons.arrow_forward_ios_rounded,
            size: 12,
            color: Colors.indigo,
          ),
        ],
      ),
    );
  }

  Widget _buildHorizontalOrders(
    BuildContext context,
    OrderController controller,
    CartController cartController,
    PrinterController printerController,
  ) {
    return Obx(() {
      if (controller.orders.isEmpty) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Container(
            height: 80,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.indigo.shade50),
            ),
            child: Center(
              child: Text(
                "Aucune commande active",
                style: TextStyle(
                  color: Colors.grey.shade400,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        );
      }
      return SizedBox(
        height: 140,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          itemCount: controller.orders.length,
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          physics: const BouncingScrollPhysics(),
          itemBuilder: (context, index) {
            final order = controller.orders[index];
            final serverName = order.user?.name ?? 'Inconnu';
            final serverInitials = serverName.isNotEmpty
                ? serverName
                      .split(' ')
                      .map((e) => e[0])
                      .take(2)
                      .join()
                      .toUpperCase()
                : '?';

            return GestureDetector(
              onTap: () => OrdersScreen.showOrderDetails(
                context,
                order,
                controller,
                cartController,
                printerController,
                onShowCart,
              ),
              child: Container(
                width: 260,
                margin: const EdgeInsets.only(right: 14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                  border: Border.all(color: Colors.indigo.shade50),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            order.numeroFacture ?? "# ${order.id}",
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 13,
                              color: Colors.indigo,
                            ),
                          ),
                          Text(
                            DeviseBook.instance.nativeTotals(order.items.map((item) => (devise: item.currency, amount: item.price * item.quantity))).entries.map((e) => "${DeviseBook.instance.formatMoney(e.value)} ${DeviseBook.instance.symbolOf(e.key)}").join(" · "),
                            style: TextStyle(
                              color: Colors.orange.shade800,
                              fontWeight: FontWeight.w900,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "Table ${order.table?.name ?? 'N/A'} • ${order.items.length} Articles",
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const Divider(height: 16, thickness: 0.5),
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 14,
                            backgroundColor: Colors.indigo.withOpacity(0.1),
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
                          Expanded(
                            child: Text(
                              serverName,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 11,
                                color: Colors.black87,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const Icon(
                            Icons.arrow_forward_ios_rounded,
                            size: 10,
                            color: Colors.grey,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      );
    });
  }

  Widget _buildHorizontalOrdersSkeleton() {
    return SizedBox(
      height: 120,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: 3,
        itemBuilder: (context, index) => Container(
          width: 240,
          margin: const EdgeInsets.only(right: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.grey.shade100),
          ),
        ),
      ),
    );
  }
}
