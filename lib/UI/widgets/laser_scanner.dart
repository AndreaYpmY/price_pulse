import 'dart:io';
import 'package:flutter/material.dart';
import '../utility/app_localizations.dart';

class LaserScanner extends StatefulWidget {
  final File imageFile;

  const LaserScanner({
    super.key,
    required this.imageFile,
  });

  @override
  State<LaserScanner> createState() => _LaserScannerState();
}

class _LaserScannerState extends State<LaserScanner> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();

    // Creo controller che scandisce tempo dell'animazione, 1.5 secondi per corsa
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true); // Avanti e indietro all'infinito finché Gemini elabora

    // Rendo movimento fluido in partenza e in frenata
    _animation = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    // libero risorse del Ticker quando il widget viene rimosso
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final loc = AppLocalizations.of(context)!;
    final laserColor = theme.colorScheme.primary;
    const double boxHeight = 240;

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        height: boxHeight,
        width: double.infinity,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // 1. Foto appena scattata o scelta dalla galleria
            Image.file(widget.imageFile, fit: BoxFit.cover),

            // 2. Velo scuro semitrasparente per far risaltare il raggio laser
            Container(color: Colors.black.withValues(alpha: 0.35)),

            // 3. Barra laser animata che scorre verticalmente sopra l'immagine
            AnimatedBuilder(animation: _animation,
              builder: (context, child) {
                final topPosition = _animation.value * (boxHeight - 6);
                return Positioned(
                  top: topPosition,
                  left: 0,
                  right: 0,
                  child: Container(
                    height: 4,
                    decoration: BoxDecoration(
                      color: laserColor,
                      boxShadow: [
                        BoxShadow(
                          color: laserColor.withValues(alpha: 0.85),
                          blurRadius: 14,
                          spreadRadius: 3,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),

            // 4. Informazioni in basso ("Analisi prezzo con Gemini AI...")
            Positioned(
              bottom: 14,
              left: 16,
              right: 16,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.72),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: laserColor,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Flexible(
                        child: Text(
                          loc.translate('analyzing_ai'),
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
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
}