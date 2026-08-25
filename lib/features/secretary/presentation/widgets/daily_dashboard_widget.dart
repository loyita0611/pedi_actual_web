import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class DailyDashboardWidget extends StatelessWidget {
  const DailyDashboardWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day, 0, 0, 0);
    final endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59);

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Gestión de Citas de Hoy',
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF4594A4)),
            ),
            const SizedBox(height: 8),
            const Text(
                'Confirma la asistencia y el estado de pago de los pacientes agendados para el día de hoy.',
                style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 24),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('citas')
                    .where('appointmentDateTime',
                        isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
                    .where('appointmentDateTime',
                        isLessThanOrEqualTo: Timestamp.fromDate(endOfDay))
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (snapshot.hasError) {
                    return Center(
                        child: Text('Error al cargar citas: ${snapshot.error}'));
                  }

                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.event_available,
                              size: 64, color: Colors.grey),
                          SizedBox(height: 16),
                          Text('No hay citas agendadas para hoy.',
                              style:
                                  TextStyle(fontSize: 16, color: Colors.grey)),
                        ],
                      ),
                    );
                  }

                  final docs = snapshot.data!.docs;

                  return ListView.separated(
                    itemCount: docs.length,
                    separatorBuilder: (context, index) => const Divider(),
                    itemBuilder: (context, index) {
                      final data =
                          docs[index].data() as Map<String, dynamic>;
                      final docId = docs[index].id;
                      final patientName =
                          data['patientName'] ?? 'Desconocido';
                      final status = data['status'] ?? 'pending';
                      final appointmentDt =
                          (data['appointmentDateTime'] as Timestamp?)
                              ?.toDate();
                      final timeStr = appointmentDt != null
                          ? DateFormat('hh:mm a').format(appointmentDt)
                          : 'N/A';
                      final pagoEstado = data['pagoEstado'] ?? 'Pendiente';

                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor:
                              _getStatusColor(status).withValues(alpha: 0.15),
                          child: Icon(Icons.person,
                              color: _getStatusColor(status)),
                        ),
                        title: Text(patientName,
                            style:
                                const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('Hora: $timeStr'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _buildStatusChip(status),
                            const SizedBox(width: 12),
                            _buildPaymentChip(pagoEstado),
                            const SizedBox(width: 12),
                            PopupMenuButton<String>(
                              icon: const Icon(Icons.more_vert),
                              onSelected: (value) {
                                FirebaseFirestore.instance
                                    .collection('citas')
                                    .doc(docId)
                                    .update({'status': value});
                              },
                              itemBuilder: (context) => [
                                const PopupMenuItem(
                                    value: 'confirmed',
                                    child: Text('✅ Confirmar Asistencia')),
                                const PopupMenuItem(
                                    value: 'in_room',
                                    child: Text('🏥 Marcar en Sala')),
                                const PopupMenuItem(
                                    value: 'attended',
                                    child: Text('✔️ Atendido')),
                                const PopupMenuItem(
                                    value: 'cancelled',
                                    child: Text('❌ Cancelar Cita')),
                              ],
                            ),
                          ],
                        ),
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

  Color _getStatusColor(String status) {
    switch (status) {
      case 'confirmed':
        return Colors.blue;
      case 'in_room':
        return Colors.orange;
      case 'attended':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Widget _buildStatusChip(String status) {
    String label;
    switch (status) {
      case 'confirmed':
        label = 'Confirmada';
        break;
      case 'in_room':
        label = 'En Sala';
        break;
      case 'attended':
        label = 'Atendido';
        break;
      case 'cancelled':
        label = 'Cancelada';
        break;
      default:
        label = 'Pendiente';
    }
    return Chip(
      label: Text(label,
          style: const TextStyle(color: Colors.white, fontSize: 12)),
      backgroundColor: _getStatusColor(status),
    );
  }

  Widget _buildPaymentChip(String payment) {
    final isVerified = payment == 'verificado';
    final isRejected = payment == 'rechazado';
    Color bgColor = Colors.red.shade100;
    Color textColor = Colors.red.shade800;
    String label = 'Pendiente';

    if (isVerified) {
      bgColor = Colors.green.shade100;
      textColor = Colors.green.shade800;
      label = 'Pagado';
    } else if (isRejected) {
      bgColor = Colors.red.shade100;
      textColor = Colors.red.shade800;
      label = 'Rechazado';
    }

    return Chip(
      label: Text(label, style: TextStyle(color: textColor, fontSize: 12)),
      backgroundColor: bgColor,
    );
  }
}
