import 'package:flutter/material.dart';

enum AppointmentStatus { pending, confirmed, inConsultation, completed, cancelled }

class StatusChip extends StatelessWidget {
  final AppointmentStatus status;

  const StatusChip({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final (Color labelColor, Color bgColor, String text) = switch (status) {
      AppointmentStatus.pending => (const Color(0xFFD97706), const Color(0xFFFEF3C7), 'Pendiente'),
      AppointmentStatus.confirmed => (const Color(0xFF2563EB), const Color(0xFFDBEAFE), 'Confirmada'),
      AppointmentStatus.inConsultation => (const Color(0xFF7C3AED), const Color(0xFFEDE9FE), 'En Consulta'),
      AppointmentStatus.completed => (const Color(0xFF059669), const Color(0xFFD1FAE5), 'Completada'),
      AppointmentStatus.cancelled => (const Color(0xFFDC2626), const Color(0xFFFEE2E2), 'Cancelada'),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: labelColor,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }
}