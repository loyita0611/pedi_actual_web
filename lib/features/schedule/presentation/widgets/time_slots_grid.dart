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

        AppointmentEntity? realAppointment;
        if (slot.isOccupied) {
          realAppointment = appointments.firstWhere(
            (a) => a.appointmentDateTime.hour == slot.dateTime.hour && a.appointmentDateTime.minute == slot.dateTime.minute,
          );
        }

        return Tooltip(
          message: slot.isOccupied
              ? "Paciente: ${realAppointment?.patientName}\nAgendado para: ${slot.timeString}"
              : "Horario Disponible",
          preferBelow: false,
          child: InkWell(
            onTap: slot.isOccupied ? null : () => onSlotSelected(slot.timeString, slot.dateTime),
            borderRadius: BorderRadius.circular(8),
            child: Container(
              decoration: BoxDecoration(
                color: slot.isOccupied ? Colors.grey[300] : Colors.teal[50],
                border: Border.all(color: slot.isOccupied ? Colors.grey : Colors.teal),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Text(
                  slot.timeString,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: slot.isOccupied ? Colors.grey[600] : Colors.teal[900],
                    decoration: slot.isOccupied ? TextDecoration.lineThrough : null,
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