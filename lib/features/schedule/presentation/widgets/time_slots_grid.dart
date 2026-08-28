// lib/features/schedule/presentation/widgets/time_slots_grid.dart
import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../domain/entities/appointment_entity.dart';
import 'time_slot_helper.dart';

class TimeSlotsGrid extends StatelessWidget {
  const TimeSlotsGrid({
    super.key,
    required this.selectedDate,
    required this.appointments,
    required this.crossAxisCount,
    required this.onSlotSelected,
    this.exponerDatosDelPaciente = false,
  });

  final DateTime selectedDate;
  final List<AppointmentEntity> appointments;
  final int crossAxisCount;
  final void Function(String timeString, DateTime dateTime) onSlotSelected;

  /// true solo para secretaria y doctora.
  final bool exponerDatosDelPaciente;

  @override
  Widget build(BuildContext context) {
    final slots = TimeSlotHelper.generateSlotsForDate(
      selectedDate: selectedDate,
      bookedAppointments: appointments,
      exponerDatosDelPaciente: exponerDatosDelPaciente,
    );

    if (slots.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'La consulta no atiende este dia.\nElige otra fecha en el calendario.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textMuted, fontSize: 14),
          ),
        ),
      );
    }

    return GridView.builder(
      itemCount: slots.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 2.4,
      ),
      itemBuilder: (context, index) => _Slot(
        slot: slots[index],
        onTap: onSlotSelected,
        exponerDatos: exponerDatosDelPaciente,
      ),
    );
  }
}

class _Slot extends StatelessWidget {
  const _Slot({required this.slot, required this.onTap, required this.exponerDatos});

  final TimeSlotModel slot;
  final void Function(String, DateTime) onTap;
  final bool exponerDatos;

  @override
  Widget build(BuildContext context) {
    final libre = slot.disponible;

    // El tooltip solo nombra al paciente para el personal de la clinica.
    final tooltip = libre
        ? 'Horario disponible'
        : exponerDatos && slot.appointment != null
            ? '${slot.appointment!.patientName}\n${slot.timeString}'
            : slot.etiquetaBloqueo;

    final Color fondo;
    final Color borde;
    final Color texto;
    if (libre) {
      fondo = AppColors.primarySoft;
      borde = AppColors.primary;
      texto = AppColors.primaryDark;
    } else if (slot.isOccupied) {
      fondo = const Color(0xFFF0F2F2);
      borde = AppColors.textMuted.withValues(alpha: 0.5);
      texto = AppColors.textMuted;
    } else {
      fondo = const Color(0xFFF7F9F9);
      borde = AppColors.border;
      texto = AppColors.textMuted.withValues(alpha: 0.75);
    }

    return Tooltip(
      message: tooltip,
      preferBelow: false,
      child: Material(
        color: fondo,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: libre ? () => onTap(slot.timeString, slot.dateTime) : null,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(color: borde),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    slot.timeString,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: texto,
                      decoration: slot.isOccupied ? TextDecoration.lineThrough : null,
                    ),
                  ),
                  if (!libre)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        slot.motivo == MotivoBloqueo.ocupado ? 'Reservado' : slot.etiquetaBloqueo,
                        style: TextStyle(fontSize: 10, color: texto),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
