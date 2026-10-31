class Ad {
  final int id;
  final String? imagenAds;
  final String? tituloAds;
  final String? descripcionAds;
  final int visitas;
  final String? numeroContacto;
  final String? whatsapp;
  final int clicksContacto;

  Ad({
    required this.id,
    this.imagenAds,
    this.tituloAds,
    this.descripcionAds,
    this.visitas = 0,
    this.numeroContacto,
    this.whatsapp,
    this.clicksContacto = 0,
  });

  static String? parsePhone(dynamic val) {
    if (val == null) return null;
    if (val is num) return val.toInt().toString();
    final s = val.toString().trim();
    if (s.isEmpty) return null;
    // Remueve posibles puntos flotantes de tipos numeric en postgres (ej. 9671234567.0)
    return s.split('.').first;
  }

  factory Ad.fromJson(Map<String, dynamic> json) {
    return Ad(
      id: json['id'] is int ? json['id'] as int : int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      imagenAds: json['imagen_ads']?.toString(),
      tituloAds: json['titulo_ads']?.toString(),
      descripcionAds: json['descripcion_ads']?.toString(),
      visitas: (json['visitas'] ?? json['vistas'] as num?)?.toInt() ?? 0,
      numeroContacto: parsePhone(json['numero_contacto']),
      whatsapp: parsePhone(json['whatsapp']),
      clicksContacto: (json['clicks_contacto'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'imagen_ads': imagenAds,
      'titulo_ads': tituloAds,
      'descripcion_ads': descripcionAds,
      'visitas': visitas,
      'numero_contacto': numeroContacto != null ? num.tryParse(numeroContacto!) : null,
      'whatsapp': whatsapp != null ? num.tryParse(whatsapp!) : null,
      'clicks_contacto': clicksContacto,
    };
  }
}
