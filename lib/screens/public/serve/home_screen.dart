import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'package:loyambo/kernel/controllers/auth_controller.dart';
import 'package:loyambo/kernel/controllers/cart_controller.dart';
import 'package:loyambo/kernel/models/product.dart';
import 'package:loyambo/widgets/product_card.dart';
import 'package:loyambo/widgets/product_search_delegate.dart';
import 'package:loyambo/widgets/user_status.dart';

class HomeScreen extends StatefulWidget {
  final Function(Product) onProductTap;
  const HomeScreen({super.key, required this.onProductTap});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final CartController cartController = Get.find<CartController>();
  final AuthController authController = Get.find<AuthController>();
  final ScrollController _scrollController = ScrollController();
  final RxString _selectedCategory = "Tout".obs;
  double _appBarOpacity = 0.0;

  final TextStyle sectionTitleStyle = const TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w900,
    color: Colors.indigo,
    letterSpacing: -0.8,
  );

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(() {
      if (mounted) {
        setState(() {
          _appBarOpacity = (_scrollController.offset / 150).clamp(0.0, 1.0);
        });
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _showSearch() {
    final List<String> categories = ["Tout", ...cartController.categories.map((c) => c.libelle)];
    showSearch(
      context: context,
      delegate: ProductSearchDelegate(
        products: cartController.allProducts,
        categories: categories,
        onProductSelected: (product) => widget.onProductTap(product),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    bool isTablet = MediaQuery.of(context).size.width > 600;

    return Stack(
      children: [
        Obx(() {
          final popularProducts = cartController.popularProducts;
          final filteredProducts = cartController.allProducts.where((p) => 
            _selectedCategory.value == "Tout" || p.category == _selectedCategory.value
          ).toList();

          return CustomScrollView(
            controller: _scrollController,
            physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
            slivers: [
              _buildSliverHeader(isTablet),
              SliverToBoxAdapter(
                child: Center(
                  child: Container(
                    constraints: BoxConstraints(maxWidth: isTablet ? 800 : double.infinity),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 50),
                        if (cartController.isLoading.value && popularProducts.isEmpty)...[
                          _buildTrendingSkeleton()
                        ],
                        if (popularProducts.isNotEmpty)...[
                          const SizedBox(height: 15),
                          _buildTrendingSection(popularProducts),
                        ],
                        if(!cartController.isLoading.value)...[
                          _buildAllProductsHeader(),
                        ]
                      ],
                    ),
                  ),
                ),
              ),
              if (cartController.isLoading.value && cartController.allProducts.isEmpty)
                _buildShimmerGrid(isTablet)
              else if (cartController.placeCatalogs.any((place) => place.id != 0))
                ..._buildPlaceSections(isTablet, filteredProducts)
              else if (filteredProducts.isEmpty)
                _buildEmptyState()
              else
                _buildProductGrid(isTablet, filteredProducts),
              const SliverToBoxAdapter(child: SizedBox(height: 160)),
            ],
          );
        }),
        _buildFloatingHeader(isTablet),
      ],
    );
  }

  Widget _buildEmptyState() {
    return SliverFillRemaining(
      hasScrollBody: false,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inventory_2_outlined, size: 80, color: Colors.grey.shade300),
            const SizedBox(height: 15),
            Text("home_no_product".tr, style: TextStyle(color: Colors.grey.shade400, fontWeight: FontWeight.w600)),
            TextButton(
              onPressed: () => cartController.refreshData(), 
              child: Text("home_refresh".tr, style: const TextStyle(fontWeight: FontWeight.bold))
            )
          ],
        ),
      ),
    );
  }

  Widget _buildTrendingSkeleton() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20),
          child: SizedBox(height: 30),
        ),
        const SizedBox(height: 20),
        SizedBox(
          height: 120,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 15),
            itemCount: 3,
            itemBuilder: (context, index) => const TrendingProductSkeleton(),
          ),
        ),
      ],
    );
  }

  Widget _buildShimmerGrid(bool isTablet) {
    final double screenWidth = MediaQuery.of(context).size.width;
    const double horizontalPadding = 25.0; 
    final double maxContentWidth = isTablet ? 800.0 : screenWidth;

    return SliverPadding(
      padding: EdgeInsets.symmetric(
        horizontal: screenWidth > maxContentWidth 
            ? (screenWidth - maxContentWidth) / 2 + horizontalPadding 
            : horizontalPadding,
        vertical: 10,
      ),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 120, // Plus petit pour forcer 3 colonnes sur mobile standard
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 0.85,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) => const ProductSkeleton(),
          childCount: 8,
        ),
      ),
    );
  }

  Widget _buildSliverHeader(bool isTablet) {
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
                  top: -20, right: -20,
                  child: Container(width: 150, height: 150, decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), shape: BoxShape.circle)),
                ),
                Positioned(
                  bottom: 40, left: -30,
                  child: Container(width: 100, height: 100, decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(20))),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 50, left: 20, right: 20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      SvgPicture.asset('assets/images/loyambo-light.svg', height: 45),
                      const UserStatus(),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            bottom: -50, left: 0, right: 0,
            child: Center(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 15),
                padding: const EdgeInsets.all(22),
                constraints: BoxConstraints(maxWidth: isTablet ? 800 : double.infinity),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(15.0),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 2, offset: const Offset(0, 2))
                  ],
                  border: Border.all(color: Colors.indigo.shade50, width: 1),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: Colors.orange.shade50, shape: BoxShape.circle),
                      child: Icon(Icons.waving_hand_rounded, color: Colors.orange.shade800, size: 24),
                    ),
                    const SizedBox(width: 18),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                           Text(
                            "Bienvenu, ${authController.currentUser.value?.name!.capitalizeFirst ?? ''} !",
                            style: const TextStyle(color: Colors.black87, fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: -0.5),
                          ),
                          Text(
                            "Votre session de service est active.",
                            style: TextStyle(color: Colors.grey.shade500, fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildTrendingSection(List<Product> popularProducts) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(color: Colors.orange.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                    child: const Icon(Icons.bolt_rounded, color: Colors.orange, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Text("home_popular".tr, style: sectionTitleStyle),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        SizedBox(
          height: 120,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 15),
            physics: const BouncingScrollPhysics(),
            itemCount: popularProducts.length,
            itemBuilder: (context, index) {
              return TrendingProductCard(
                product: popularProducts[index],
                onTap: () => widget.onProductTap(popularProducts[index]),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildAllProductsHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
         Row(
           mainAxisAlignment: MainAxisAlignment.spaceBetween,
           children: [
             Column(
               crossAxisAlignment: CrossAxisAlignment.start,
               children: [
                 Text("home_all_products".tr, style: sectionTitleStyle),
                 Text("home_tap_product".tr, style: const TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.w400)),
               ],
             ),
             _buildSearchIconButton(),
           ],
         ),
          const SizedBox(height: 15),
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _buildCategoryChip("Tout"),
                ...cartController.categories.map((c) => _buildCategoryChip(c.libelle)),
              ],
            ),
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }

  Widget _buildCategoryChip(String label) {
    return Obx(() {
      final isSelected = _selectedCategory.value == label;
      return GestureDetector(
        onTap: () => _selectedCategory.value = label,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.only(right: 10),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? Colors.indigo : Colors.indigo.withOpacity(0.05),
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: isSelected ? Colors.indigo : Colors.indigo.withOpacity(0.1)),
          ),
          alignment: Alignment.center,
            child: Text(
              label == "Tout" ? "cat_all".tr : label,
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.indigo,
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
        ),
      );
    });
  }

  List<Widget> _buildPlaceSections(bool isTablet, List<Product> filteredProducts) {
    final sections = <Widget>[];
    for (final place in cartController.placeCatalogs) {
      final products = filteredProducts.where((product) => product.placeId == place.id).toList();
      if (products.isEmpty) {
        continue;
      }
      if (place.name.isNotEmpty) {
        sections.add(SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(25, 18, 25, 0),
            child: Text(place.name, style: sectionTitleStyle.copyWith(fontSize: 18)),
          ),
        ));
      }
      sections.add(_buildProductGrid(isTablet, products));
    }
    if (sections.isEmpty) {
      sections.add(_buildEmptyState());
    }
    return sections;
  }

  Widget _buildProductGrid(bool isTablet, List<Product> products) {
    final double screenWidth = MediaQuery.of(context).size.width;
    const double horizontalPadding = 25.0; // Aligné sur le modal
    final double maxContentWidth = isTablet ? 800.0 : screenWidth;

    return SliverPadding(
      padding: EdgeInsets.symmetric(
        horizontal: screenWidth > maxContentWidth 
            ? (screenWidth - maxContentWidth) / 2 + horizontalPadding 
            : horizontalPadding,
        vertical: 10,
      ),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 120, // Identique au modal pour avoir 3 colonnes sur mobile standard
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 0.85, 
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final product = products[index];
            return ProductCard(
              product: product,
              onTap: () => widget.onProductTap(product),
            );
          },
          childCount: products.length,
        ),
      ),
    );
  }

  Widget _buildFloatingHeader(bool isTablet) {
    return Positioned(
      top: 0, left: 0, right: 0,
      child: Opacity(
        opacity: _appBarOpacity,
        child: Container(
          height: 105,
          decoration: BoxDecoration(
            color: Colors.indigo,
            border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.15), width: 1)),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 5))
            ],
          ),
          padding: const EdgeInsets.only(top: 45, left: 20, right: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              SvgPicture.asset('assets/images/loyambo-light.svg', height: 45),
              const UserStatus()
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchIconButton() {
    return Container(
      decoration: BoxDecoration(color: Colors.indigo.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
      child: IconButton(
        onPressed: _showSearch,
        icon: const Icon(Icons.search, color: Colors.indigo, size: 20),
        visualDensity: VisualDensity.compact,
      ),
    );
  }
}
