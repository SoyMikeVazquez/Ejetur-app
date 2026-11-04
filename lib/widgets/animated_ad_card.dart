import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class AnimatedAdCard extends StatefulWidget {
  final String? imageUrl;
  final String? title;
  final String? description;
  final double width;
  final double height;
  final VoidCallback? onTap;

  const AnimatedAdCard({
    super.key,
    this.imageUrl,
    this.title,
    this.description,
    this.width = 295,
    this.height = 185,
    this.onTap,
  });

  @override
  State<AnimatedAdCard> createState() => _AnimatedAdCardState();
}

class _AnimatedAdCardState extends State<AnimatedAdCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final double t = _controller.value;
          final double glowAlpha = 0.25 + 0.15 * math.sin(t * 2 * math.pi);

          return Container(
            width: widget.width,
            height: widget.height,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(26),
              // Borde animado con degradado rotativo llamativo
              gradient: SweepGradient(
                startAngle: 0.0,
                endAngle: math.pi * 2,
                transform: GradientRotation(t * 2 * math.pi),
                colors: [
                  AppColors.electricGreen,
                  Colors.white.withValues(alpha: 0.1),
                  AppColors.electricGreen.withValues(alpha: 0.9),
                  Colors.white.withValues(alpha: 0.1),
                  AppColors.electricGreen,
                ],
                stops: const [0.0, 0.25, 0.5, 0.75, 1.0],
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.electricGreen.withValues(alpha: glowAlpha),
                  blurRadius: 10,
                  spreadRadius: 1,
                ),
              ],
            ),
            padding: const EdgeInsets.all(2.2), // Grosor del borde animado
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.appBlack,
                borderRadius: BorderRadius.circular(24),
                image: widget.imageUrl != null && widget.imageUrl!.isNotEmpty
                    ? DecorationImage(
                        image: NetworkImage(widget.imageUrl!),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                children: [
                  // 1. Degradado: transparente arriba y oscuro abajo para máxima visibilidad
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.50),
                            Colors.black.withValues(alpha: 0.90),
                          ],
                          stops: const [0.0, 0.38, 0.70, 1.0],
                        ),
                      ),
                    ),
                  ),

                  // 2. Textos en negritas y pegados a la parte inferior
                  Positioned(
                    left: 14,
                    right: 14,
                    bottom: 10,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (widget.title != null && widget.title!.isNotEmpty)
                          Text(
                            widget.title!,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.2,
                              shadows: [
                                Shadow(
                                  color: Colors.black,
                                  blurRadius: 4,
                                  offset: Offset(0, 1),
                                ),
                              ],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        if (widget.description != null &&
                            widget.description!.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            widget.description!,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12.5,
                              fontWeight: FontWeight.bold,
                              height: 1.2,
                              shadows: [
                                Shadow(
                                  color: Colors.black,
                                  blurRadius: 4,
                                  offset: Offset(0, 1),
                                ),
                              ],
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                        const SizedBox(height: 6),
                        // Botón "Más información" (negro con letras amarillas)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
                          decoration: BoxDecoration(
                            color: Colors.black,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: const Color(0xFF050505),
                              width: 1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.5),
                                blurRadius: 4,
                                offset: const Offset(0, 1),
                              ),
                            ],
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Más información',
                                style: TextStyle(
                                  color: Color(0xFF050505),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.2,
                                ),
                              ),
                              SizedBox(width: 4),
                              Icon(
                                Icons.arrow_forward_ios_rounded,
                                size: 9,
                                color: Color(0xFF050505),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
