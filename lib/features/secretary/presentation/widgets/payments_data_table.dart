import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class PaymentsDataTable extends StatelessWidget {
  const PaymentsDataTable({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Verificación y Validación de Pagos',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF4594A4))),
          const SizedBox(height: 16),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('citas').snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return const Center(child: Text('Error al cargar pagos'));
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text('No hay registros de pagos.'));
                }

                // Filtrar localmente citas que tengan pagoEstado definido y no sea vacío
                final docs = snapshot.data!.docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  return data.containsKey('pagoEstado') && data['pagoEstado'] != null;
                }).toList();

                if (docs.isEmpty) {
                  return const Center(child: Text('No hay pagos pendientes o registrados.'));
                }

                return SingleChildScrollView(
                  scrollDirection: Axis.vertical,
                  child: SizedBox(
                    width: double.infinity,
                    child: DataTable(
                      headingRowColor: WidgetStateProperty.all(const Color(0xFFF4F7F6)),
                      columns: const [
                        DataColumn(label: Text('Paciente', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Referencia / Fecha', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Estado', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Comprobante', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Acciones', style: TextStyle(fontWeight: FontWeight.bold))),
                      ],
                      rows: docs.map((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        final patientName = data['patientName'] ?? 'Desconocido';
                        final pagoEstado = data['pagoEstado'] ?? 'Pendiente';
                        final date = (data['appointmentDateTime'] as Timestamp?)?.toDate();
                        final dateString = date != null ? '${date.day}/${date.month}/${date.year}' : 'N/A';

                        Color statusColor = Colors.orange;
                        if (pagoEstado == 'verificado') statusColor = Colors.green;
                        if (pagoEstado == 'rechazado') statusColor = Colors.red;

                        return DataRow(cells: [
                          DataCell(Text(patientName)),
                          DataCell(Text('Ref #00${doc.id.substring(0, 4).toUpperCase()} - $dateString')),
                          DataCell(
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                              child: Text(pagoEstado.toString().toUpperCase(), style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 12)),
                            ),
                          ),
                          DataCell(
                            IconButton(
                              icon: const Icon(Icons.receipt_long, color: Color(0xFF4594A4)),
                              onPressed: () {
                                showDialog(
                                  context: context,
                                  builder: (_) => AlertDialog(
                                    title: const Text('Comprobante Adjunto'),
                                    content: Container(
                                      width: 300,
                                      height: 300,
                                      color: Colors.grey.shade200,
                                      child: const Center(child: Icon(Icons.image, size: 80, color: Colors.grey)),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                          DataCell(
                            Row(
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.check_circle_outline, color: Colors.green),
                                  tooltip: 'Verificar Pago',
                                  onPressed: () {
                                    FirebaseFirestore.instance.collection('citas').doc(doc.id).update({'pagoEstado': 'verificado'});
                                  },
                                ),
                                IconButton(
                                  icon: const Icon(Icons.cancel_outlined, color: Colors.redAccent),
                                  tooltip: 'Rechazar Pago',
                                  onPressed: () {
                                    FirebaseFirestore.instance.collection('citas').doc(doc.id).update({'pagoEstado': 'rechazado'});
                                  },
                                ),
                              ],
                            ),
                          ),
                        ]);
                      }).toList(),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}