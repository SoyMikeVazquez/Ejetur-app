import 'package:fl_chart/fl_chart.dart';

class DashboardFinancialData {
  final double totalRevenue;
  final double platformCommission;
  final int totalTrips;
  final double cashTotal;
  final int cashTrips;
  final double cardTotal;
  final int cardTrips;
  final List<FlSpot> chartSpots;
  final double maxY;
  final double maxX;
  final bool isSingleDay;
  final List<String> xLabels;

  DashboardFinancialData({
    required this.totalRevenue,
    required this.platformCommission,
    required this.totalTrips,
    required this.cashTotal,
    required this.cashTrips,
    required this.cardTotal,
    required this.cardTrips,
    required this.chartSpots,
    required this.maxY,
    required this.maxX,
    required this.isSingleDay,
    required this.xLabels,
  });

  factory DashboardFinancialData.empty() {
    return DashboardFinancialData(
      totalRevenue: 0,
      platformCommission: 0,
      totalTrips: 0,
      cashTotal: 0,
      cashTrips: 0,
      cardTotal: 0,
      cardTrips: 0,
      chartSpots: [const FlSpot(0, 0)],
      maxY: 100,
      maxX: 7,
      isSingleDay: true,
      xLabels: [],
    );
  }
}

class DriverFullDetailData {
  final Map<String, dynamic> driverData;
  final List<Map<String, dynamic>> trips;
  final double averageRating;
  final int totalReviews;

  DriverFullDetailData({
    required this.driverData,
    required this.trips,
    required this.averageRating,
    required this.totalReviews,
  });
}
