import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../theme/app_theme.dart';
import '../services/ad_service.dart';

class AdDetailDialog extends StatelessWidget {
  final int? adId;
  final String? imageUrl;
  final String? title;
  final String? description;
  final String? numeroContacto;
  final String? whatsapp;
  final int? visitas;
  final int? clicksContacto;

  const AdDetailDialog({
    super.key,
    this.adId,
    this.imageUrl,
    this.title,
    this.description,
    this.numeroContacto,
    this.whatsapp,
    this.visitas,
    this.clicksContacto,
  });

  static Future<void> show(
    BuildContext context, {
    int? adId,
    String? imageUrl,
    String? title,
    String? description,
    String? numeroContacto,
    String? whatsapp,
    int? visitas,
    int? clicksContacto,
  }) {
    return showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Cerrar anuncio',
      barrierColor: Colors.black.withValues(alpha: 0.65),
      transitionDuration: const Duration(milliseconds: 350),
      pageBuilder: (context, anim1, anim2) {
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: AdDetailDialog(
            adId: adId,
            imageUrl: imageUrl,
            title: title,
            description: description,
            numeroContacto: numeroContacto,
            whatsapp: whatsapp,
            visitas: visitas,
            clicksContacto: clicksContacto,
          ),
        );
      },
      transitionBuilder: (context, anim, secondaryAnim, child) {
        final curvedValue = Curves.easeOutBack.transform(anim.value);
        return Transform.scale(
          scale: curvedValue.clamp(0.0, 1.0),
          child: Opacity(
            opacity: anim.value.clamp(0.0, 1.0),
            child: child,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool hasPhone = numeroContacto != null && numeroContacto!.trim().isNotEmpty;
    final bool hasWhatsapp = whatsapp != null && whatsapp!.trim().isNotEmpty;

    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        constraints: const BoxConstraints(maxWidth: 420),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          // Resplandor exterior animable
          boxShadow: [
            BoxShadow(
              color: AppColors.electricGreen.withValues(alpha: 0.45),
              blurRadius: 30,
              spreadRadius: 2,
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.35),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          clipBehavior: Clip.antiAlias,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. Imagen del anuncio con botón de cerrar flotante
                Stack(
                  children: [
                    if (imageUrl != null && imageUrl!.isNotEmpty)
                      Image.network(
                        imageUrl!,
                        height: 220,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          height: 180,
                          color: Colors.grey[200],
                          child: const Icon(Icons.broken_image_rounded, size: 50, color: Colors.grey),
                        ),
                      )
                    else
                      Container(
                        height: 140,
                        color: AppColors.appBlack,
                        child: const Center(
                          child: Icon(Icons.campaign_rounded, size: 60, color: AppColors.electricGreen),
                        ),
                      ),

                    // Botón flotante para cerrar
                    Positioned(
                      top: 12,
                      right: 12,
                      child: GestureDetector(
                        onTap: () => Navigator.of(context).pop(),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.65),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.3),
                              width: 1,
                            ),
                          ),
                          child: const Icon(
                            Icons.close_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                    ),

                    // Etiqueta distintiva tipo 'badge'
                    Positioned(
                      top: 14,
                      left: 14,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: AppColors.electricGreen,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.2),
                              blurRadius: 6,
                            ),
                          ],
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.verified_rounded, size: 14, color: Colors.black),
                            SizedBox(width: 4),
                            Text(
                              'Anuncio Oficial',
                              style: TextStyle(
                                color: Colors.black,
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),

                // 2. Contenido (Título + Descripción + Acciones)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (title != null && title!.isNotEmpty) ...[
                        Text(
                          title!,
                          style: const TextStyle(
                            fontFamily: 'Google Sans',
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            color: AppColors.appBlack,
                            letterSpacing: -0.3,
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 10),
                      ],

                      if (description != null && description!.isNotEmpty) ...[
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxHeight: 180),
                          child: SingleChildScrollView(
                            child: Text(
                              description!,
                              style: TextStyle(
                                fontSize: 14.5,
                                color: Colors.grey[800],
                                height: 1.45,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),
                      ],

                      // Botones de Contacto (Llamar / WhatsApp) si no son nulos
                      if (hasPhone || hasWhatsapp) ...[
                        Row(
                          children: [
                            if (hasPhone)
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: () {
                                    if (adId != null && adId! > 0) {
                                      AdService.recordContactClick(adId!);
                                    }
                                    AdService.makePhoneCall(numeroContacto!);
                                  },
                                  icon: const Icon(Icons.phone_rounded, size: 18, color: Colors.white),
                                  label: const Text(
                                    'Llamar',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.black,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 13),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    elevation: 0,
                                  ),
                                ),
                              ),
                            if (hasPhone && hasWhatsapp)
                              const SizedBox(width: 10),
                            if (hasWhatsapp)
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: () {
                                    if (adId != null && adId! > 0) {
                                      AdService.recordContactClick(adId!);
                                    }
                                    AdService.openWhatsApp(whatsapp!);
                                  },
                                  icon: const Icon(Icons.chat_bubble_rounded, size: 18, color: Colors.white),
                                  label: const Text(
                                    'WhatsApp',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF25D366), // Verde oficial WhatsApp
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 13),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    elevation: 0,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 12),
                      ],

                      // Botón para cerrar
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: () => Navigator.of(context).pop(),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: Colors.grey[300]!),
                            foregroundColor: Colors.black87,
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: const Text(
                            'Cerrar',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    )
    .animate()
    .shimmer(duration: 1200.ms, color: Colors.white.withValues(alpha: 0.35))
    .scale(duration: 350.ms, curve: Curves.easeOutBack);
  }
}
