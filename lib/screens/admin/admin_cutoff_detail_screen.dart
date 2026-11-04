import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'admin_cutoff_dates_screen.dart';

class AdminCutoffDetailScreen extends StatefulWidget {
  final CutoffDateModel cutoff;
  final int index;

  const AdminCutoffDetailScreen({
    super.key,
    required this.cutoff,
    required this.index,
  });

  @override
  State<AdminCutoffDetailScreen> createState() => _AdminCutoffDetailScreenState();
}

class _AdminCutoffDetailScreenState extends State<AdminCutoffDetailScreen> {
  late CutoffDateModel _cutoff;
  bool _isUpdating = false;

  @override
  void initState() {
    super.initState();
    _cutoff = widget.cutoff;
  }

  Future<void> _confirmPayment(CutoffDriverItem driver) async {
    if (_cutoff.id == null) return;
    setState(() => _isUpdating = true);
    
    try {
      await Supabase.instance.client
          .from('cortes_conductores')
          .update({'estatus_pago': 'pagado'})
          .eq('corte_id', _cutoff.id!)
          .eq('conductor_id', driver.id);

      if (mounted) {
        setState(() {
          _cutoff.pendingDrivers.removeWhere((d) => d.id == driver.id);
          _cutoff.paidDrivers.add(CutoffDriverItem(
            id: driver.id,
            name: driver.name,
            totalRevenue: driver.totalRevenue,
            amountDue: driver.amountDue,
            isPaid: true,
          ));
          _isUpdating = false;
        });
        Navigator.pop(context); // Close bottom sheet
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pago confirmado con éxito')));
      }
    } catch(e) {
      debugPrint('Error confirmando pago: $e');
      if (mounted) {
        setState(() => _isUpdating = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al confirmar: $e')));
      }
    }
  }

  void _showDriverPaymentDetails(BuildContext context, CutoffDriverItem driver) {
    final double ingresos2Dias = driver.totalRevenue;
    final double aPagar = driver.amountDue;
    final bool isPaid = driver.isPaid;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
              ),
              child: SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 5,
                        decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: Colors.grey.shade200,
                          child: Icon(Icons.person, color: Colors.grey.shade700),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(driver.name, style: const TextStyle(fontFamily: 'Google Sans', fontSize: 18, fontWeight: FontWeight.bold)),
                              Text(
                                isPaid ? 'Pago Realizado' : 'Pago Pendiente',
                                style: TextStyle(color: isPaid ? Colors.green.shade600 : Colors.orange.shade700, fontWeight: FontWeight.w600, fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        children: [
                          _buildDetailRow('Ingresos generados (2 días)', '\$${ingresos2Dias.toStringAsFixed(2)}'),
                          const Divider(height: 32),
                          _buildDetailRow('Monto correspondiente (20%)', '\$${aPagar.toStringAsFixed(2)}', isHighlight: true),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    if (!isPaid) ...[
                      SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: ElevatedButton(
                          onPressed: _isUpdating ? null : () async {
                            setModalState(() => _isUpdating = true);
                            await _confirmPayment(driver);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF050505),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                          ),
                          child: _isUpdating
                              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))
                              : const Text('Confirmar Pago', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: isPaid 
                          ? ElevatedButton(
                              onPressed: () => Navigator.pop(context),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.black,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                              ),
                              child: const Text('Cerrar', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                            )
                          : TextButton(
                              onPressed: () => Navigator.pop(context),
                              style: TextButton.styleFrom(
                                foregroundColor: Colors.black54,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                              ),
                              child: const Text('Cerrar', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                            ),
                    )
                  ],
                ),
              ),
            );
          }
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value, {bool isHighlight = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: isHighlight ? Colors.black : Colors.black54,
            fontWeight: isHighlight ? FontWeight.bold : FontWeight.w500,
            fontSize: isHighlight ? 16 : 14,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontFamily: 'Google Sans',
            color: isHighlight ? Colors.black : Colors.black87,
            fontWeight: FontWeight.bold,
            fontSize: isHighlight ? 18 : 14,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat("dd 'de' MMMM", 'es_MX');
    
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.index == 0 ? 'Corte de Hoy' : 'Corte de 2 Días',
              style: const TextStyle(fontFamily: 'Google Sans', fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Text(
              dateFormat.format(_cutoff.date),
              style: const TextStyle(fontSize: 13, color: Colors.black54, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        children: [
          // Summary Header
          Row(
            children: [
              Expanded(
                child: _buildSummaryCard(
                  'Pagados', 
                  _cutoff.paidDrivers.length, 
                  _cutoff.paidDrivers.fold(0.0, (sum, d) => sum + d.amountDue),
                  Colors.green
                )
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildSummaryCard(
                  'Pendientes', 
                  _cutoff.pendingDrivers.length, 
                  _cutoff.pendingDrivers.fold(0.0, (sum, d) => sum + d.amountDue),
                  Colors.orange
                )
              ),
            ],
          ).animate().fade(duration: 400.ms).slideY(begin: 0.1, end: 0),
          
          const SizedBox(height: 32),
          
          _buildDriverSection(context, 'Conductores Pendientes', _cutoff.pendingDrivers, false),
          const SizedBox(height: 24),
          _buildDriverSection(context, 'Conductores Pagados', _cutoff.paidDrivers, true),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(String title, int count, double amount, MaterialColor color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 4)),
        ],
        border: Border.all(color: color.shade100),
      ),
      child: Column(
        children: [
          Text(count.toString(), style: TextStyle(fontFamily: 'Google Sans', fontSize: 28, fontWeight: FontWeight.bold, color: color.shade700)),
          const SizedBox(height: 4),
          Text(title, style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.black54)),
          const SizedBox(height: 4),
          Text('\$${amount.toStringAsFixed(2)}', style: TextStyle(fontFamily: 'Google Sans', fontSize: 16, fontWeight: FontWeight.bold, color: color.shade600)),
        ],
      ),
    );
  }

  Widget _buildDriverSection(BuildContext context, String title, List<CutoffDriverItem> drivers, bool isPaid) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4.0, bottom: 12),
          child: Text(
            title,
            style: const TextStyle(fontFamily: 'Google Sans', fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
          ),
        ),
        if (drivers.isEmpty)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
            child: const Center(child: Text('Ningún conductor en esta lista', style: TextStyle(color: Colors.black45))),
          )
        else
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 8, offset: const Offset(0, 2))],
            ),
            child: Material(
              color: Colors.transparent,
              child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: drivers.length,
              separatorBuilder: (_, _) => const Divider(height: 1, indent: 20, endIndent: 20),
              itemBuilder: (context, idx) {
                final driver = drivers[idx];
                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                  leading: CircleAvatar(
                    backgroundColor: isPaid ? Colors.green.shade50 : Colors.orange.shade50,
                    child: Icon(Icons.person, color: isPaid ? Colors.green.shade600 : Colors.orange.shade600),
                  ),
                  title: Text(driver.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                  subtitle: Text(
                    'Ingresos: \$${driver.totalRevenue.toStringAsFixed(2)} • A pagar: \$${driver.amountDue.toStringAsFixed(2)}',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                  trailing: const Icon(Icons.chevron_right, color: Colors.black26),
                  onTap: () => _showDriverPaymentDetails(context, driver),
                );
              },
            ),
            ),
          ),
      ],
    ).animate().fade(duration: 400.ms, delay: 100.ms).slideY(begin: 0.1, end: 0);
  }
}
