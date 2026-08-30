// lib/features/schedule/presentation/bloc/schedule_event.dart
import 'package:equatable/equatable.dart';

import '../../domain/entities/appointment_entity.dart';

sealed class ScheduleEvent extends Equatable {
  const ScheduleEvent();
  @override
  List<Object?> get props => const [];
}

class LoadAppointmentsForDate extends ScheduleEvent {
  const LoadAppointmentsForDate(this.date, {this.esPersonal = false});
  final DateTime date;

  /// Decide cuanta informacion del dia se puede pedir: la agenda completa o
  /// solo los horarios ocupados.
  final bool esPersonal;

  @override
  List<Object?> get props => [date, esPersonal];
}

class BookNewAppointment extends ScheduleEvent {
  const BookNewAppointment(this.appointment);
  final AppointmentEntity appointment;
  @override
  List<Object?> get props => [appointment];
}

class CancelExistingAppointment extends ScheduleEvent {
  const CancelExistingAppointment(this.appointment, {this.esPersonal = false});
  final AppointmentEntity appointment;
  final bool esPersonal;
  @override
  List<Object?> get props => [appointment, esPersonal];
}

class RescheduleExistingAppointment extends ScheduleEvent {
  const RescheduleExistingAppointment(this.appointment, this.nuevaFecha);
  final AppointmentEntity appointment;
  final DateTime nuevaFecha;
  @override
  List<Object?> get props => [appointment, nuevaFecha];
}
