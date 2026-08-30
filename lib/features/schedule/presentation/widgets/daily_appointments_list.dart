// lib/features/schedule/presentation/widgets/daily_appointments_list.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_status.dart';
import '../../domain/entities/appointment_entity.dart';

/// Citas del dia seleccionado.
///
/// Cambio importante de privacidad: esta lista mostraba el nombre de todos los
/// ninos agendados y el de sus representantes a cualquiera que abriera
/// "Agendar cita", incluidos otros pacientes. Ahora el representante solo ve
/// las suyas, y el resto aparece como cupo reservado sin datos.
class DailyAppointmentsList extends StatelessWidget {
  const DailyAppointmentsList({
    super.key,
    required this.appointments,
    this.esPersonal = false,
  });

  final List<AppointmentEntity> appointments;
  final bool esPersonal;

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final correo = FirebaseAuth.instance.currentUser?.email;

    final visibles = appointments.where((a) => a.status != CitaStatus.cancelada).toList()
      ..sort((a, b) => a.appointmentDateTime.compareTo(b.appointmentDateTime));

    bool esMia(AppointmentEntity a) =>
        (a.representativeId.isNotEmpty && a.representativeId == uid) ||
        (a.email.isNotEmpty && a.email == correo);

    final mias = esPersonal ? visibles : visibles.where(esMia).toList();
    final ajenas = esPersonal ? 0 : visibles.length - mias.length;

    return Card(
      margin: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.list_alt, color: AppColors.primary, size: 19),
                const SizedBox(width: 8),
                Text(
                  esPersonal ? 'Citas del dia' : 'Mis citas de este dia',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.primary),
                ),
              ],
            ),
            const Divider(height: 20),
            Expanded(
              child: mias.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 8),
                        child: Text(
                          ajenas > 0
                              ? 'No tienes citas este dia.\n$ajenas ${ajenas == 1 ? 'cupo ocupado' : 'cupos ocupados'} por otros pacientes.'
                              : 'No hay citas agendadas\npara esta fecha.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
                        ),
                      ),
                    )
                  : ListView.separated(
                      itemCount: mias.length,
                      separatorBuilder: (_, __) => const Divider(height: 12),
                      itemBuilder: (context, i) {
                        final a = mias[i];
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                          leading: Container(
                            width: 9,
                            height: 9,
                            margin: const EdgeInsets.only(top: 6),
                            decoration: BoxDecoration(color: a.status.color, shape: BoxShape.circle),
                          ),
                          title: Text(
                            a.patientName.isEmpty ? 'Sin nombre' : a.patientName,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            esPersonal && a.representativeName.isNotEmpty
                                ? 'Rep.: ${a.representativeName}'
                                : a.motivo.isNotEmpty
                                    ? a.motivo
                                    : a.status.label,
                            style: const TextStyle(fontSize: 11),
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Lo que contesto el representante al
                              // recordatorio de la vispera. Le ahorra a la
                              // secretaria la llamada de la manana para saber
                              // quien viene.
                              if (a.confirmoAsistencia)
                                const Tooltip(
                                  message: 'Confirmo que asistira',
                                  child: Icon(Icons.check_circle,
                                      size: 16, color: AppColors.success),
                                )
                              else if (a.pidioReprogramar)
                                const Tooltip(
                                  message: 'Pidio reprogramar',
                                  child: Icon(Icons.event_repeat,
                                      size: 16, color: AppColors.warning),
                                ),
                              const SizedBox(width: 6),
                              Text(
                                DateFormat('h:mm a').format(a.appointmentDateTime),
                                style: const TextStyle(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
            if (!esPersonal && ajenas > 0 && mias.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  '$ajenas ${ajenas == 1 ? 'cupo mas ocupado' : 'cupos mas ocupados'} este dia.',
                  style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
