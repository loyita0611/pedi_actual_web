// lib/features/schedule/presentation/widgets/time_slots_grid.dart
import 'package:flutter/material.dart';
import '../../domain/entities/appointment_entity.dart';
import 'time_slot_helper.dart'; // Ajusta este import según tu estructura real

class TimeSlotsGrid extends StatelessWidget {
  final DateTime selectedDate;
  final List<AppointmentEntity> appointments;
  final int crossAxisCount;
  final Function(String timeString, DateTime dateTime) onSlotSelected;

  const TimeSlotsGrid({
    super.key,
    required this.selectedDate,
    required this.appointments,
    required this.crossAxisCount,
    required this.onSlotSelected,
  });

  @override
  Widget build(BuildContext context) {
    final List<TimeSlotModel> calculatedSlots = TimeSlotHelper.generateSlotsForDate(
      selectedDate: selectedDate,
      bookedAppointments: appointments,
      startHour: 8,
      endHour: 17,
      intervalMinutes: 30,
    );

    if (calculatedSlots.isEmpty) {
      return const Center(child: Text('No hay horarios configurados para este día.'));
    }

    return GridView.builder(
      itemCount: calculatedSlots.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 2.5,
      ),
      itemBuilder: (context, index) {
        final slot = calculatedSlots[index];

        // 🌍 Comprobación de ocupación usando la hora local (.toLocal())
        final bool isCurrentlyOccupied = appointments.any((a) {
          final appLocal = a.appointmentDateTime.toLocal();
          final slotLocal = slot.dateTime.toLocal();
          return appLocal.hour == slotLocal.hour && appLocal.minute == slotLocal.minute;
        });

        AppointmentEntity? realAppointment;
        if (isCurrentlyOccupied) {
          // 🔥 SOLUCIÓN: Usamos un bucle for-in clásico para evitar el 'firstWhere' con 'orElse'.
          // Esto elimina por completo el TypeError de subtipos entre AppointmentEntity y AppointmentModel.
          for (final a in appointments) {
            final appLocal = a.appointmentDateTime.toLocal();
            final slotLocal = slot.dateTime.toLocal();
            if (appLocal.hour == slotLocal.hour && appLocal.minute == slotLocal.minute) {
              realAppointment = a;
              break; // Ya lo encontramos, salimos del bucle
            }
          }
        }

        return Tooltip(
          message: isCurrentlyOccupied
              ? "Paciente: ${realAppointment?.patientName}\nAgendado para: ${slot.timeString}"
              : "Horario Disponible",
          preferBelow: false,
          child: InkWell(
            onTap: isCurrentlyOccupied ? null : () => onSlotSelected(slot.timeString, slot.dateTime),
            borderRadius: BorderRadius.circular(8),
            child: Container(
              decoration: BoxDecoration(
                color: isCurrentlyOccupied ? Colors.grey[300] : Colors.teal[50],
                border: Border.all(color: isCurrentlyOccupied ? Colors.grey : Colors.teal),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Text(
                  slot.timeString,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isCurrentlyOccupied ? Colors.grey[600] : Colors.teal[900],
                    decoration: isCurrentlyOccupied ? TextDecoration.lineThrough : null,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}