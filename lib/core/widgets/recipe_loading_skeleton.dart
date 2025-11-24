import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

class RecipeLoadingSkeleton extends StatelessWidget {
  const RecipeLoadingSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // Koyu modda daha koyu gri, açık modda açık gri
    final baseColor = isDark ? Colors.grey[800]! : Colors.grey[300]!;
    final highlightColor = isDark ? Colors.grey[700]! : Colors.grey[100]!;

    return ListView.builder(
      itemCount: 5, // 5 tane sahte kart göster
      padding: const EdgeInsets.all(16),
      itemBuilder: (context, index) {
        return Shimmer.fromColors(
          baseColor: baseColor,
          highlightColor: highlightColor,
          child: Container(
            margin: const EdgeInsets.only(bottom: 16),
            height: 140,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                // Sol taraf (Yüzde yuvarlağı gibi)
                Container(
                  width: 80,
                  margin: const EdgeInsets.all(16),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                ),
                // Sağ taraf (Yazılar)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Başlık
                        Container(width: 150, height: 20, color: Colors.white),
                        const SizedBox(height: 10),
                        // Alt satır 1
                        Container(width: 100, height: 14, color: Colors.white),
                        const SizedBox(height: 10),
                        // Alt satır 2
                        Container(width: 80, height: 14, color: Colors.white),
                      ],
                    ),
                  ),
                )
              ],
            ),
          ),
        );
      },
    );
  }
}