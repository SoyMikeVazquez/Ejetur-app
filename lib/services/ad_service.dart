import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class AdService {
  static final SupabaseClient _supabase = Supabase.instance.client;

  /// Registra una visualización / clic en el anuncio (+1 a 'visitas' o 'vistas')
  static Future<void> recordAdView(int adId) async {
    if (adId <= 0) return;
    try {
      final current = await _supabase.from('ads').select('visitas').eq('id', adId).maybeSingle();
      if (current != null) {
        final count = (current['visitas'] as num?)?.toInt() ?? 0;
        await _supabase.from('ads').update({'visitas': count + 1}).eq('id', adId);
      }
    } catch (e) {
      debugPrint('Error en recordAdView (visitas): $e');
      // Intento con columna alternativa 'vistas' en caso de que exista
      try {
        final current = await _supabase.from('ads').select('vistas').eq('id', adId).maybeSingle();
        if (current != null) {
          final count = (current['vistas'] as num?)?.toInt() ?? 0;
          await _supabase.from('ads').update({'vistas': count + 1}).eq('id', adId);
        }
      } catch (_) {}
    }
  }

  /// Registra un clic en botones de contacto (+1 a 'clicks_contacto')
  static Future<void> recordContactClick(int adId) async {
    if (adId <= 0) return;
    try {
      final current = await _supabase.from('ads').select('clicks_contacto').eq('id', adId).maybeSingle();
      if (current != null) {
        final count = (current['clicks_contacto'] as num?)?.toInt() ?? 0;
        await _supabase.from('ads').update({'clicks_contacto': count + 1}).eq('id', adId);
      }
    } catch (e) {
      debugPrint('Error en recordContactClick: $e');
    }
  }

  /// Abre la aplicación de teléfono para realizar la llamada
  static Future<void> makePhoneCall(String phone) async {
    final cleanPhone = phone.replaceAll(RegExp(r'[^0-9+]'), '');
    final uri = Uri(scheme: 'tel', path: cleanPhone);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint('Error al iniciar llamada: $e');
    }
  }

  /// Abre la conversación en WhatsApp
  static Future<void> openWhatsApp(String phone) async {
    String cleanNumber = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (cleanNumber.length == 10) {
      cleanNumber = '52$cleanNumber'; // Lada México por defecto si tiene 10 dígitos
    }
    final uri = Uri.parse('https://wa.me/$cleanNumber');
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('Error al abrir WhatsApp: $e');
    }
  }
}

