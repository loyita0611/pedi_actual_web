// lib/features/schedule/presentation/bloc/schedule_state.dart

import 'package:equatable/equatable.dart';
import '../../domain/entities/appointment_entity.dart';

abstract class ScheduleState extends Equatable {
  const ScheduleState();
  
  @override
  List<Object?> get props => [];
}

// Estado inicial antes de cargar cualquier dato
class ScheduleInitial extends ScheduleState {}

// Estado de carga (Loading spinner en la pantalla)
class ScheduleLoading extends ScheduleState {}

// ¡El estado clave! Cuando las citas del día ya están listas
class ScheduleLoaded extends ScheduleState {
  final List<AppointmentEntity> appointments;
  final DateTime selectedDate;

  const ScheduleLoaded({required this.appointments, required this.selectedDate});

  @override
  List<Object?> get props => [appointments, selectedDate];
}

// Estado temporal cuando se está procesando una nueva reserva
class AppointmentBookingInProgress extends ScheduleState {}

// Estado de éxito al agendar
class AppointmentBookedSuccess extends ScheduleState {}

// Manejo de errores de Firebase o de red
class ScheduleError extends ScheduleState {
  final String message;

  const ScheduleError(this.message);

  @override
  List<Object?> get props => [message];
}