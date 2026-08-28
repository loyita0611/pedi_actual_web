// lib/features/secretary/presentation/widgets/appointment_actions_menu.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/config/clinic_config.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_status.dart';
import '../../../../core/services/email_service.dart';
import '../../../../core/widgets/async_states.dart';
import '../../../../injection_container.dart' as di;
import '../../../schedule/domain/entities/appointment_entity.dart';
import '../../../schedule/domain/repositories/appointment_repository.dart';
import '../../../schedule/presentation/widgets/slot_picker_dialog.dart';

/// Menu de acciones sobre una cita, para la secretaria.
///
/// Incluye reprogramar, que antes solo existia en el panel del paciente: quien
/// atiende el telefono era justamente la unica que no podia mover una cita.
class AppointmentActionsMenu extends StatelessWidget {
  const AppointmentActionsMenu({super.key, required this.cita});

  final AppointmentEntity cita;

  Future<void> _cambiarEstado(BuildContext context, CitaStatus estado) async {
    try {
      await di.sl<AppointmentRepository>().updateStatus(cita.id, estado);
      if (context.mounted) mostrarAviso(context, 'Cita marcada como ${estado.label.toLowerCase()}.');
    } catch (e) {
      if (context.mounted) mostrarAviso(context, 'No se pudo actualizar: $e', esError: true);
    }
  }

  Future<void> _reprogramar(BuildContext context) async {
    final nueva = await SlotPickerDialog.mostrar(
      context,
      fechaInicial: cita.appointmentDateTime,
      titulo: 'Reprogramar cita de ${cita.patientName}',
    );
    if (nueva == null || !context.mounted) return;

    try {
      await di.sl<AppointmentRepository>().rescheduleAppointment(cita.id, nueva);
      if (cita.email.isNotEmpty) {
        await di.sl<EmailService>().reprogramacion(
              correo: cita.email,
              paciente: cita.patientName,
              fecha: DateFormat('d/MM/y').format(nueva),
              hora: DateFormat('h:mm a').format(nueva),
              telefonoClinica: ClinicConfigService.actual.telefonoClinica,
            );
      }
      if (context.mounted) {
        mostrarAviso(
          context,
          'Reprogramada para el ${DateFormat("d 'de' MMMM 'a las' h:mm a", 'es').format(nueva)}.',
          esExito: true,
        );
      }
    } catch (e) {
      if (context.mounted) mostrarAviso(context, 'No se pudo reprogramar: $e', esError: true);
    }
  }

  Future<void> _cancelar(BuildContext context) async {
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text('Cancelar cita', style: TextStyle(fontSize: 17)),
        content: Text('Se cancelara la cita de ${cita.patientName} y el horario quedara libre.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Volver', style: TextStyle(color: AppColors.textMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Cancelar cita'),
          ),
        ],
      ),
    );
    if (confirmado != true || !context.mounted) return;

    try {
      await di.sl<AppointmentRepository>().cancelAppointment(cita.id);
      if (cita.email.isNotEmpty) {
        await di.sl<EmailService>().cancelacion(
              correo: cita.email,
              paciente: cita.patientName,
              fecha: DateFormat('d/MM/y').format(cita.appointmentDateTime),
              hora: DateFormat('h:mm a').format(cita.appointmentDateTime),
              telefonoClinica: ClinicConfigService.actual.telefonoClinica,
            );
      }
      if (context.mounted) mostrarAviso(context, 'Cita cancelada.');
    } catch (e) {
      if (context.mounted) mostrarAviso(context, 'No se pudo cancelar: $e', esError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert, color: AppColors.textMuted),
      tooltip: 'Acciones',
      onSelected: (valor) {
        switch (valor) {
          case 'reprogramar':
            _reprogramar(context);
          case 'cancelar':
            _cancelar(context);
          default:
            _cambiarEstado(context, CitaStatus.fromRaw(valor));
        }
      },
      itemBuilder: (context) => [
        for (final e in [
          CitaStatus.confirmada,
          CitaStatus.enSala,
          CitaStatus.atendida,
          CitaStatus.noAsistio,
        ])
          PopupMenuItem(
            value: e.key,
            child: Row(
              children: [
                Container(width: 9, height: 9, decoration: BoxDecoration(color: e.color, shape: BoxShape.circle)),
                const SizedBox(width: 10),
                Text(e.label),
              ],
            ),
          ),
        const PopupMenuDivider(),
        const PopupMenuItem(
          value: 'reprogramar',
          child: Row(children: [
            Icon(Icons.event_repeat, size: 18, color: AppColors.textSecondary),
            SizedBox(width: 10),
            Text('Reprogramar'),
          ]),
        ),
        const PopupMenuItem(
          value: 'cancelar',
          child: Row(children: [
            Icon(Icons.cancel_outlined, size: 18, color: AppColors.danger),
            SizedBox(width: 10),
            Text('Cancelar cita', style: TextStyle(color: AppColors.danger)),
          ]),
        ),
      ],
    );
  }
}
