class Trip {
  final String? id;
  final String userId;
  final String? driverId;
  final String originAddress;
  final String destinationAddress;
  final double? originLat;
  final double? originLng;
  final double? destinationLat;
  final double? destinationLng;
  final String? postalCode;
  final String? delegation;
  final String status; // pending, accepted, in_progress, completed, cancelled
  final double? fare;
  final double? distanceKm;
  final DateTime? createdAt;
  final DateTime? arrivedAt;
  final DateTime? completedAt;
  final String? paymentMethod; // 'efectivo' o 'tarjeta'
  final String? nameDriver;
  final String? photoDriver;
  final double? totalFinal; // Ganancia del conductor (80%)
  final bool? isReview; // Indica si el pasajero ya calificó el viaje
  final int? codigo; // Código de 5 dígitos para verificar el viaje (estilo Uber)

  Trip({
    this.id,
    required this.userId,
    this.driverId,
    required this.originAddress,
    required this.destinationAddress,
    this.originLat,
    this.originLng,
    this.destinationLat,
    this.destinationLng,
    this.postalCode,
    this.delegation,
    this.status = 'pending',
    this.fare,
    this.distanceKm,
    this.createdAt,
    this.arrivedAt,
    this.completedAt,
    this.paymentMethod,
    this.nameDriver,
    this.photoDriver,
    this.totalFinal,
    this.isReview,
    this.codigo,
  });

  factory Trip.fromJson(Map<String, dynamic> json) {
    return Trip(
      id: json['id']?.toString(),
      userId: json['user_id']?.toString() ?? '',
      driverId: json['driver_id']?.toString(),
      originAddress: json['origin_address']?.toString() ?? '',
      destinationAddress: json['destination_address']?.toString() ?? '',
      originLat: json['origin_lat'] != null ? (json['origin_lat'] as num).toDouble() : null,
      originLng: json['origin_lng'] != null ? (json['origin_lng'] as num).toDouble() : null,
      destinationLat: json['destination_lat'] != null ? (json['destination_lat'] as num).toDouble() : null,
      destinationLng: json['destination_lng'] != null ? (json['destination_lng'] as num).toDouble() : null,
      postalCode: json['postal_code']?.toString(),
      delegation: json['delegation']?.toString(),
      status: json['status']?.toString() ?? 'pending',
      fare: json['fare'] != null ? (json['fare'] as num).toDouble() : null,
      distanceKm: json['distance_km'] != null ? (json['distance_km'] as num).toDouble() : null,
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'].toString()) : null,
      arrivedAt: json['arrived_at'] != null ? DateTime.tryParse(json['arrived_at'].toString()) : null,
      completedAt: json['completed_at'] != null ? DateTime.tryParse(json['completed_at'].toString()) : null,
      paymentMethod: (json['payment_method'] ?? json['metodo_pago'])?.toString(),
      nameDriver: json['name_driver']?.toString(),
      photoDriver: json['photo_driver']?.toString(),
      totalFinal: json['total_final'] != null ? (json['total_final'] as num).toDouble() : null,
      isReview: json['isReview'] == true || json['is_review'] == true,
      codigo: json['codigo'] != null ? num.tryParse(json['codigo'].toString())?.toInt() : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'user_id': userId,
      if (driverId != null) 'driver_id': driverId,
      'origin_address': originAddress,
      'destination_address': destinationAddress,
      if (originLat != null) 'origin_lat': originLat,
      if (originLng != null) 'origin_lng': originLng,
      if (destinationLat != null) 'destination_lat': destinationLat,
      if (destinationLng != null) 'destination_lng': destinationLng,
      if (postalCode != null) 'postal_code': postalCode,
      if (delegation != null) 'delegation': delegation,
      'status': status,
      if (fare != null) 'fare': fare,
      if (distanceKm != null) 'distance_km': distanceKm,
      if (createdAt != null) 'created_at': createdAt?.toIso8601String(),
      if (arrivedAt != null) 'arrived_at': arrivedAt?.toIso8601String(),
      if (completedAt != null) 'completed_at': completedAt?.toIso8601String(),
      if (paymentMethod != null) 'payment_method': paymentMethod,
      if (nameDriver != null) 'name_driver': nameDriver,
      if (photoDriver != null) 'photo_driver': photoDriver,
      if (totalFinal != null) 'total_final': totalFinal,
      if (isReview != null) 'isReview': isReview,
      if (codigo != null) 'codigo': codigo,
    };
  }

  Trip copyWith({
    String? id,
    String? userId,
    String? driverId,
    String? originAddress,
    String? destinationAddress,
    double? originLat,
    double? originLng,
    double? destinationLat,
    double? destinationLng,
    String? postalCode,
    String? delegation,
    String? status,
    double? fare,
    double? distanceKm,
    DateTime? createdAt,
    DateTime? arrivedAt,
    DateTime? completedAt,
    String? paymentMethod,
    String? nameDriver,
    String? photoDriver,
    double? totalFinal,
    bool? isReview,
    int? codigo,
  }) {
    return Trip(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      driverId: driverId ?? this.driverId,
      originAddress: originAddress ?? this.originAddress,
      destinationAddress: destinationAddress ?? this.destinationAddress,
      originLat: originLat ?? this.originLat,
      originLng: originLng ?? this.originLng,
      destinationLat: destinationLat ?? this.destinationLat,
      destinationLng: destinationLng ?? this.destinationLng,
      postalCode: postalCode ?? this.postalCode,
      delegation: delegation ?? this.delegation,
      status: status ?? this.status,
      fare: fare ?? this.fare,
      distanceKm: distanceKm ?? this.distanceKm,
      createdAt: createdAt ?? this.createdAt,
      arrivedAt: arrivedAt ?? this.arrivedAt,
      completedAt: completedAt ?? this.completedAt,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      nameDriver: nameDriver ?? this.nameDriver,
      photoDriver: photoDriver ?? this.photoDriver,
      totalFinal: totalFinal ?? this.totalFinal,
      isReview: isReview ?? this.isReview,
      codigo: codigo ?? this.codigo,
    );
  }
}
