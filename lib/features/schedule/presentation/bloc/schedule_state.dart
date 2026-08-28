// lib/features/schedule/presentation/bloc/schedule_state.dart
import 'package:equatable/equatable.dart';

import '../../domain/entities/appointment_entity.dart';

sealed class ScheduleState extends Equatable {
  const ScheduleState();
  @override
  List<Object?> get props => const [];
}

class ScheduleInitial extends ScheduleState {
  const ScheduleInitial();
}

class ScheduleLoading extends ScheduleState {
  const ScheduleLoading();
}

class ScheduleLoaded extends ScheduleState {
  const ScheduleLoaded({
    required this.appointments,
    required this.selectedDate,
    this.mensajeExito,
  });

  final List<AppointmentEntity> appointments;
  final DateTime selectedDate;

  /// Aviso puntual para mostrar una sola vez (se limpia al recargar).
  /// Antes existia un estado `AppointmentBookedSuccess` que la pantalla
  /// escuchaba pero que el bloc no emitia nunca, asi que el mensaje
  /// "Cita registrada con exito" no aparecia jamas.
  final String? mensajeExito;

  ScheduleLoaded sinMensaje() =>
      ScheduleLoaded(appointments: appointments, selectedDate: selectedDate);

  @override
  List<Object?> get props => [appointments, selectedDate, mensajeExito];
}

class ScheduleWorking extends ScheduleState {
  const ScheduleWorking(this.mensaje);
  final String mensaje;
  @override
  List<Object?> get props => [mensaje];
}

class ScheduleError extends ScheduleState {
  const ScheduleError(this.message, {this.previo});
  final String message;

  /// Estado anterior, para poder volver a pintar la grilla en vez de dejar
  /// la pantalla en blanco con un volcado de error.
  final ScheduleLoaded? previo;

  @override
  List<Object?> get props => [message, previo];
}
