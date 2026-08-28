// lib/features/schedule/presentation/widgets/time_slot_helper.dart
import '../../../../core/config/clinic_config.dart';
import '../../../../core/constants/app_status.dart';
import '../../domain/entities/appointment_entity.dart';

enum MotivoBloqueo { libre, ocupado, pasado, almuerzo, fueraDeJornada }

class TimeSlotModel {
  const TimeSlotModel({
    required this.timeString,
    required this.dateTime,
    required this.motivo,
    this.appointment,
  });

  final String timeString;
  final DateTime dateTime;
  final MotivoBloqueo motivo;

  /// Solo se rellena para el personal de la clinica. En la vista del paciente
  /// va en null a proposito: antes el tooltip de cada bloque ocupado mostraba
  /// el nombre del nino que tenia la cita.
  final AppointmentEntity? appointment;

  bool get disponible => motivo == MotivoBloqueo.libre;
  bool get isOccupied => motivo == MotivoBloqueo.ocupado;

  String get etiquetaBloqueo => switch (motivo) {
        MotivoBloqueo.libre => 'Horario disponible',
        MotivoBloqueo.ocupado => 'Horario reservado',
        MotivoBloqueo.pasado => 'Esta hora ya paso',
        MotivoBloqueo.almuerzo => 'Horario de almuerzo',
        MotivoBloqueo.fueraDeJornada => 'Fuera de la jornada',
      };
}

class TimeSlotHelper {
  /// Genera los bloques del dia segun la configuracion de la clinica.
  ///
  /// Antes el horario estaba escrito en tres sitios distintos con tres valores
  /// distintos, no habia pausa de almuerzo, se generaban bloques los siete dias
  /// de la semana y las horas ya vencidas seguian clicables.
  static List<TimeSlotModel> generateSlotsForDate({
    required DateTime selectedDate,
    required List<AppointmentEntity> bookedAppointments,
    ClinicConfig? config,
    bool exponerDatosDelPaciente = false,
  }) {
    final cfg = config ?? ClinicConfigService.actual;
    if (!cfg.esDiaHabil(selectedDate)) return const <TimeSlotModel>[];

    final ahora = DateTime.now();
    final slots = <TimeSlotModel>[];

    var actual = DateTime(selectedDate.year, selectedDate.month, selectedDate.day, cfg.horaInicio);
    final limite = DateTime(selectedDate.year, selectedDate.month, selectedDate.day, cfg.horaFin);

    while (actual.isBefore(limite)) {
      final bloque = DateTime(actual.year, actual.month, actual.day, actual.hour, actual.minute);

      AppointmentEntity? ocupante;
      for (final cita in bookedAppointments) {
        final c = cita.appointmentDateTime;
        if (c.hour == bloque.hour &&
            c.minute == bloque.minute &&
            c.day == bloque.day &&
            c.month == bloque.month &&
            c.year == bloque.year &&
            cita.status != CitaStatus.cancelada) {
          ocupante = cita;
          break;
        }
      }

      final motivo = ocupante != null
          ? MotivoBloqueo.ocupado
          : (bloque.hour >= cfg.almuerzoInicio && bloque.hour < cfg.almuerzoFin)
              ? MotivoBloqueo.almuerzo
              : bloque.isBefore(ahora)
                  ? MotivoBloqueo.pasado
                  : MotivoBloqueo.libre;

      slots.add(TimeSlotModel(
        timeString: formatoAmPm(bloque),
        dateTime: bloque,
        motivo: motivo,
        appointment: exponerDatosDelPaciente ? ocupante : null,
      ));

      actual = actual.add(Duration(minutes: cfg.minutosPorCita));
    }

    return slots;
  }

  static String formatoAmPm(DateTime dt) {
    final amPm = dt.hour >= 12 ? 'PM' : 'AM';
    final h = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    return '${h.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')} $amPm';
  }
}
