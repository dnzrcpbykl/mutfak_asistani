import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart'; // Animasyon paketi

class EmptyStateWidget extends StatelessWidget {
  final String message;
  final IconData icon;
  final String? subMessage;

  const EmptyStateWidget({
    super.key,
    required this.message,
    required this.icon,
    this.subMessage,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // İKON
          Container(
            padding: const EdgeInsets.all(30),
            decoration: BoxDecoration(
              color: colorScheme.primary.withAlpha((0.1 * 255).round()),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 80, color: colorScheme.primary.withAlpha((0.5 * 255).round())),
          )
          .animate() // Animasyon Başlangıcı
          .scale(duration: 600.ms, curve: Curves.elasticOut) // Büyüyerek gel
          .fade(duration: 600.ms), // Yavaşça görün

          const SizedBox(height: 24),

          // ANA MESAJ
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurface.withAlpha((0.8 * 255).round()),
            ),
          ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.2, end: 0), // Aşağıdan yukarı kay

          // ALT MESAJ (Varsa)
          if (subMessage != null) ...[
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                subMessage!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: colorScheme.onSurface.withAlpha((0.5 * 255).round()),
                ),
              ),
            ).animate().fadeIn(delay: 500.ms),
          ],
        ],
      ),
    );
  }
}