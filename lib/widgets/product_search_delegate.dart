import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:loyambo/kernel/models/product.dart';
import 'package:loyambo/kernel/services/devise_book.dart';

class ProductSearchDelegate extends SearchDelegate {
  final List<Product> products;
  final List<String> categories;
  final Function(Product) onProductSelected;

  ProductSearchDelegate({
    required this.products,
    required this.categories,
    required this.onProductSelected,
  }) : super(
          searchFieldLabel: "Rechercher...",
          searchFieldStyle: const TextStyle(fontSize: 16, color: Colors.white, fontFamily: 'Ubuntu'),
        );

  final ValueNotifier<String> _selectedCategory = ValueNotifier<String>("Tout");

  @override
  ThemeData appBarTheme(BuildContext context) {
    return ThemeData(
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.indigo,
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.white),
      ),
      textSelectionTheme: const TextSelectionThemeData(
        cursorColor: Colors.white,
      ),
      inputDecorationTheme: InputDecorationTheme(
        hintStyle: const TextStyle(color: Colors.white70, fontSize: 14),
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
        prefixIconColor: Colors.white,
        focusedBorder: InputBorder.none
      ),
      textTheme: const TextTheme(
        titleLarge: TextStyle(color: Colors.white, fontSize: 16),
      ),
    );
  }

  @override
  List<Widget>? buildActions(BuildContext context) {
    return [
      if (query.isNotEmpty)
        IconButton(
          icon: const Icon(Icons.clear, color: Colors.white),
          onPressed: () => query = '',
        ),
    ];
  }

  @override
  Widget? buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
      onPressed: () => close(context, null),
    );
  }

  @override
  Widget buildResults(BuildContext context) => _buildSearchResults(context);

  @override
  Widget buildSuggestions(BuildContext context) => _buildSearchResults(context);

  Widget _buildSearchResults(BuildContext context) {
    return Container(
      color: Colors.grey.shade100,
      child: Column(
        children: [
          const SizedBox(height: 15),
          ValueListenableBuilder<String>(
            valueListenable: _selectedCategory,
            builder: (context, selected, _) {
              return SizedBox(
                height: 50,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 15),
                  itemCount: categories.length,
                  itemBuilder: (context, index) {
                    final cat = categories[index];
                    final isSelected = cat == selected;
                    return GestureDetector(
                      onTap: () => _selectedCategory.value = cat,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        decoration: BoxDecoration(
                          color: isSelected ? Colors.indigo : Colors.white,
                          borderRadius: BorderRadius.circular(15),
                          border: Border.all(color: isSelected ? Colors.indigo : Colors.indigo.shade100),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          cat,
                          style: TextStyle(
                            color: isSelected ? Colors.white : Colors.indigo.withOpacity(0.6),
                            fontWeight: isSelected ? FontWeight.w900 : FontWeight.w700,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          ),
          const SizedBox(height: 20),
          Expanded(
            child: ValueListenableBuilder<String>(
              valueListenable: _selectedCategory,
              builder: (context, selectedCat, _) {
                final filtered = products.where((p) {
                  final matchesQuery = p.name.toLowerCase().contains(query.toLowerCase());
                  final matchesCat = selectedCat == "Tout" || p.category == selectedCat;
                  return matchesQuery && matchesCat;
                }).toList();

                if (filtered.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.search_off_rounded, size: 80, color: Colors.grey),
                        SizedBox(height: 15),
                        Text("Aucun produit trouvé", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w500)),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  physics: const BouncingScrollPhysics(),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final product = filtered[index];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: Colors.indigo.shade50, width: 1),
                      ),
                      child: Material(
                        color: Colors.transparent,
                        borderRadius: BorderRadius.circular(18),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(18),
                          onTap: (){
                            close(context, null);
                            onProductSelected(product);
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(15),
                            child: Row(
                              children: [
                                Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    color: Colors.indigo.withOpacity(0.04),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: Colors.indigo.withOpacity(0.1)),
                                  ),
                                  child: const Icon(Icons.restaurant_menu_rounded, color: Colors.indigo, size: 22),
                                ),
                                const SizedBox(width: 15),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              product.name,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                                            ),
                                          ),
                                          if (product.tracksStock) ...[
                                            const SizedBox(width: 8),
                                            Text(
                                              '${product.availableStock}',
                                              style: TextStyle(
                                                fontWeight: FontWeight.w900,
                                                fontSize: 13,
                                                color: product.isOutOfStock ? Colors.red.shade700 : Colors.indigo,
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                      Text(
                                        [
                                          if (product.placeName != null && product.placeName!.isNotEmpty) product.placeName!,
                                          product.category.toUpperCase(),
                                        ].join(' · '),
                                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.grey.shade400, letterSpacing: 1),
                                      ),
                                      Text("${DeviseBook.instance.formatMoney(product.price)} ${DeviseBook.instance.symbolOf(product.currency)}", style: TextStyle(color: Colors.orange.shade800, fontWeight: FontWeight.w800, fontSize: 14.0)),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: Colors.indigo.withOpacity(0.08),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(CupertinoIcons.add, color: Colors.indigo, size: 20),
                                )
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
