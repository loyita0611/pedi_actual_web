// lib/features/schedule/presentation/widgets/daily_appointments_list.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../domain/entities/appointment_entity.dart';

class DailyAppointmentsList extends StatelessWidget {
  final List<AppointmentEntity> appointments;

  const DailyAppointmentsList({super.key, required this.appointments});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.list_alt, color: Colors.teal),
                SizedBox(width: 8),
                Text(
                  'Citas del Día',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.teal),
                ),
              ],
            ),
            const Divider(),
            Expanded(
              child: appointments.isEmpty
                  ? const Center(
                      child: Text(
                        'No hay citas agendadas\npara esta fecha.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey),
                      ),
                    )
                  : ListView.builder(
                      itemCount: appointments.length,
                      itemBuilder: (context, index) {
                        final app = appointments[index];
                        final String timeFormatted = DateFormat('hh:mm a').format(app.appointmentDateTime);
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.circle, color: Colors.amber, size: 12),
                          title: Text(
                            app.patientName,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text('Representante: ${app.representativeName}', style: const TextStyle(fontSize: 11)),
                          trailing: Text(
                            timeFormatted,
                            style: const TextStyle(color: Colors.teal, fontWeight: FontWeight.bold, fontSize: 12),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}