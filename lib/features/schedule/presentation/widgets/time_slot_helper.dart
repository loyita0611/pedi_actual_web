// lib/features/schedule/presentation/utils/time_slot_helper.dart

import '../../domain/entities/appointment_entity.dart';

class TimeSlotModel {
  final String timeString; // Ej: "08:30 AM"
  final DateTime dateTime;  // El objeto DateTime completo para guardar en Firebase
  final bool isOccupied;   // Si ya está reservado

  TimeSlotModel({
    required this.timeString,
    required this.dateTime,
    required this.isOccupied,
  });
}

class TimeSlotHelper {
  // Genera la lista de bloques cruzándola con las citas ocupadas
  static List<TimeSlotModel> generateSlotsForDate({
    required DateTime selectedDate,
    required List<AppointmentEntity> bookedAppointments,
    int startHour = 8,  // Jornada comienza a las 8:00 AM
    int endHour = 16,  // Jornada termina a las 4:00 PM (16:00)
    int intervalMinutes = 30, // Citas cada 30 min
  }) {
    final List<TimeSlotModel> slots = [];
    
    // Definimos el punto de partida: las 8:00 AM del día seleccionado
    DateTime currentSlot = DateTime(
      selectedDate.year,
      selectedDate.month,
      selectedDate.day,
      startHour,
      0,
    );

    // Definimos la hora límite para dejar de generar bloques
    final DateTime limitTime = DateTime(
      selectedDate.year,
      selectedDate.month,
      selectedDate.day,
      endHour,
      0,
    );

    // Bucle para ir sumando los intervalos (ej: de 30 en 30 minutos)
    while (currentSlot.isBefore(limitTime)) {
      // 1. Formatear la hora legible para el usuario de manera manual o con intl
      final String timeString = _formatToAmPm(currentSlot);

      // 2. Comprobar si ya existe una cita en Firebase para este bloque exacto de hora y fecha
      // Nota: Comparamos año, mes, día, hora y minuto.
      final bool occupied = bookedAppointments.any((appointment) =>
          appointment.appointmentDateTime.year == currentSlot.year &&
          appointment.appointmentDateTime.month == currentSlot.month &&
          appointment.appointmentDateTime.day == currentSlot.day &&
          appointment.appointmentDateTime.hour == currentSlot.hour &&
          appointment.appointmentDateTime.minute == currentSlot.minute &&
          appointment.status != 'cancelled'); // Ignoramos las canceladas

      // 3. Añadir el bloque procesado a nuestra lista
      slots.add(TimeSlotModel(
        timeString: timeString,
        dateTime: currentSlot,
        isOccupied: occupied,
      ));

      // 4. Avanzar el reloj para el próximo bloque (sumar 30 minutos)
      currentSlot = currentSlot.add(Duration(minutes: intervalMinutes));
    }

    return slots;
  }

  // Función auxiliar rápida para formatear a formato 12 horas (AM/PM) sin paquetes externos
  static String _formatToAmPm(DateTime dt) {
    final int hour = dt.hour;
    final int minute = dt.minute;
    final String amPm = hour >= 12 ? 'PM' : 'AM';
    final int displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    final String displayMinute = minute < 10 ? '0$minute' : '$minute';
    final String displayHourStr = displayHour < 10 ? '0$displayHour' : '$displayHour';
    
    return '$displayHourStr:$displayMinute $amPm';
  }
}