// lib/features/secretary/presentation/widgets/daily_dashboard_widget.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_status.dart';
import '../../../../core/widgets/async_states.dart';
import '../../../schedule/data/models/appointment_model.dart';
import '../../../schedule/domain/entities/appointment_entity.dart';
import 'appointment_actions_menu.dart';

/// Citas de hoy.
class DailyDashboardWidget extends StatelessWidget {
  const DailyDashboardWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final hoy = DateTime.now();
    final inicio = DateTime(hoy.year, hoy.month, hoy.day);
    final fin = DateTime(hoy.year, hoy.month, hoy.day, 23, 59, 59, 999);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Citas de hoy · ${DateFormat("EEEE d 'de' MMMM", 'es').format(hoy)}',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.primary),
          ),
          const SizedBox(height: 5),
          const Text(
            'Confirma la asistencia y revisa el estado de pago de cada paciente.',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13.5),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: ColeccionView<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('citas')
                  .where('appointmentDateTime', isGreaterThanOrEqualTo: Timestamp.fromDate(inicio))
                  .where('appointmentDateTime', isLessThanOrEqualTo: Timestamp.fromDate(fin))
                  .snapshots(),
              estaVacio: (s) => s.docs.isEmpty,
              vacio: const EstadoVacio(
                icono: Icons.event_available,
                titulo: 'No hay citas agendadas para hoy',
                detalle: 'Cuando alguien reserve, aparecera aqui al instante.',
              ),
              builder: (context, snap) {
                final citas = snap.docs
                    .map((d) => AppointmentModel.fromJson(d.data(), d.id))
                    .toList()
                  ..sort((a, b) => a.appointmentDateTime.compareTo(b.appointmentDateTime));

                return Column(
                  children: [
                    _Resumen(citas: citas),
                    const SizedBox(height: 16),
                    Expanded(
                      child: ListView.separated(
                        itemCount: citas.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, i) => _FilaCita(cita: citas[i]),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _Resumen extends StatelessWidget {
  const _Resumen({required this.citas});
  final List<AppointmentEntity> citas;

  @override
  Widget build(BuildContext context) {
    final atendidas = citas.where((c) => c.status == CitaStatus.atendida).length;
    final noAsistio = citas.where((c) => c.status == CitaStatus.noAsistio).length;
    final porCobrar = citas.where((c) => c.pagoEstado == PagoStatus.pendiente).length;

    return Row(
      children: [
        _dato('${citas.length}', 'agendadas', AppColors.primary),
        _dato('$atendidas', 'atendidas', AppColors.success),
        if (noAsistio > 0) _dato('$noAsistio', 'no asistieron', AppColors.accentDark),
        _dato('$porCobrar', 'pagos por verificar', AppColors.warning),
      ],
    );
  }

  Widget _dato(String valor, String etiqueta, Color color) => Expanded(
        child: Container(
          margin: const EdgeInsets.only(right: 10),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color.withValues(alpha: 0.22)),
          ),
          child: Row(
            children: [
              Text(valor,
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color)),
              const SizedBox(width: 9),
              Expanded(
                child: Text(etiqueta,
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              ),
            ],
          ),
        ),
      );
}

class _FilaCita extends StatelessWidget {
  const _FilaCita({required this.cita});
  final AppointmentEntity cita;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(vertical: 6),
      leading: CircleAvatar(
        backgroundColor: cita.status.background,
        child: Icon(Icons.person, color: cita.status.color),
      ),
      title: Text(cita.patientName.isEmpty ? 'Sin nombre' : cita.patientName,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5)),
      subtitle: Text(
        [
          DateFormat('h:mm a').format(cita.appointmentDateTime),
          if (cita.motivo.isNotEmpty) cita.motivo,
          if (cita.phone.isNotEmpty) cita.phone,
        ].join('  ·  '),
        style: const TextStyle(fontSize: 12.5),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          StatusPill.cita(cita.status, dense: true),
          const SizedBox(width: 8),
          StatusPill.pago(cita.pagoEstado, dense: true),
          const SizedBox(width: 6),
          AppointmentActionsMenu(cita: cita),
        ],
      ),
    );
  }
}
