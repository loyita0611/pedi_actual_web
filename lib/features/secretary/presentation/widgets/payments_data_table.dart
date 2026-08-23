// lib/features/secretary/presentation/widgets/payments_data_table.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class PaymentsDataTable extends StatelessWidget {
  const PaymentsDataTable({super.key});

  Future<void> _updatePaymentStatus(String paymentId, String status) async {
    await FirebaseFirestore.instance.collection('pagos').doc(paymentId).update({
      'status': status,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  void _showPaymentHistory(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.8,
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text('Historial General de Pagos', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const Divider(),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                // En el historial general quitamos el orderBy o usamos uno simple si ya tiene índice
                stream: FirebaseFirestore.instance.collection('pagos').snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                  final docs = snapshot.data!.docs;
                  return ListView.builder(
                    itemCount: docs.length,
                    itemBuilder: (context, index) {
                      final data = docs[index].data() as Map<String, dynamic>;
                      final monto = data['pagoMonto'] ?? 0.0;
                      final banco = data['pagoBanco'] ?? 'N/A';
                      return ListTile(
                        title: Text(data['patientName'] ?? 'Sin nombre'),
                        subtitle: Text('Banco: $banco | Estado: ${data['status']}'),
                        trailing: Text('$monto Bs.'),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Align(
          alignment: Alignment.topRight,
          child: ElevatedButton.icon(
            icon: const Icon(Icons.history),
            label: const Text('Ver Historial'),
            onPressed: () => _showPaymentHistory(context),
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            // 🚀 SOLUCIÓN: Quitamos el .orderBy() para evitar que Firestore bloquee la vista por falta de índice
            stream: FirebaseFirestore.instance
                .collection('pagos')
                .where('status', isEqualTo: 'pending')
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const Center(child: Text('No hay pagos pendientes de verificación.'));
              }

              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columns: const [
                    DataColumn(label: Text('Fecha')),
                    DataColumn(label: Text('Paciente')),
                    DataColumn(label: Text('Banco / Ref')),
                    DataColumn(label: Text('Monto (Bs.)')),
                    DataColumn(label: Text('Acciones')),
                  ],
                  rows: snapshot.data!.docs.map((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    
                    String dateStr = 'N/A';
                    if (data['date'] != null && data['date'] is Timestamp) {
                      dateStr = (data['date'] as Timestamp).toDate().toString().substring(0, 10);
                    }
                    
                    final monto = data['pagoMonto'] ?? 0.0;
                    final banco = data['pagoBanco'] ?? '';
                    final ref = data['pagoReferencia'] ?? '';

                    return DataRow(cells: [
                      DataCell(Text(dateStr)),
                      DataCell(Text(data['patientName'] ?? '')),
                      DataCell(Text('$banco (Ref: $ref)')),
                      DataCell(Text('$monto Bs.')),
                      DataCell(Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.check, color: Colors.green),
                            tooltip: 'Aprobar Pago',
                            onPressed: () => _updatePaymentStatus(doc.id, 'approved'),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, color: Colors.red),
                            tooltip: 'Rechazar Pago',
                            onPressed: () => _updatePaymentStatus(doc.id, 'rejected'),
                          ),
                        ],
                      )),
                    ]);
                  }).toList(),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}