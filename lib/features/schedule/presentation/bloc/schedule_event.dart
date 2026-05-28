// lib/features/schedule/presentation/bloc/schedule_event.dart

import 'package:equatable/equatable.dart';
import '../../domain/entities/appointment_entity.dart';

abstract class ScheduleEvent extends Equatable {
  const ScheduleEvent();

  @override
  List<Object?> get props => [];
}

// Evento cuando el usuario selecciona una fecha diferente en el calendario
class LoadAppointmentsForDate extends ScheduleEvent {
  final DateTime date;

  const LoadAppointmentsForDate(this.date);

  @override
  List<Object?> get props => [date];
}

// Evento cuando se agenda una nueva cita desde el formulario modal
class BookNewAppointment extends ScheduleEvent {
  final AppointmentEntity appointment;

  const BookNewAppointment(this.appointment);

  @override
  List<Object?> get props => [appointment];
}