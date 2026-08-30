// lib/features/schedule/presentation/bloc/schedule_bloc.dart
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/datasources/appointment_remote_data_source.dart' show HorarioOcupadoException;
import '../../domain/usecases/book_appointment.dart';
import '../../domain/usecases/cancel_appointment.dart';
import '../../domain/usecases/get_appointments_by_date.dart';
import '../../domain/usecases/reschedule_appointment.dart';
import 'schedule_event.dart';
import 'schedule_state.dart';

class ScheduleBloc extends Bloc<ScheduleEvent, ScheduleState> {
  ScheduleBloc({
    required this.getAppointmentsByDate,
    required this.bookAppointment,
    required this.cancelAppointment,
    required this.rescheduleAppointment,
  }) : super(const ScheduleInitial()) {
    on<LoadAppointmentsForDate>(_onLoad);
    on<BookNewAppointment>(_onBook);
    on<CancelExistingAppointment>(_onCancel);
    on<RescheduleExistingAppointment>(_onReschedule);
  }

  final GetAppointmentsByDate getAppointmentsByDate;
  final BookAppointment bookAppointment;
  final CancelAppointment cancelAppointment;
  final RescheduleAppointment rescheduleAppointment;

  DateTime _ultimaFecha = DateTime.now();

  /// Se recuerda del ultimo `LoadAppointmentsForDate` para que las recargas
  /// posteriores -tras reservar, cancelar o reprogramar- pidan lo mismo que
  /// pidio la pantalla y no mas de lo permitido.
  bool _esPersonal = false;

  ScheduleLoaded? get _cargadoActual => switch (state) {
        ScheduleLoaded s => s,
        ScheduleError e => e.previo,
        _ => null,
      };

  Future<void> _onLoad(LoadAppointmentsForDate event, Emitter<ScheduleState> emit) async {
    _ultimaFecha = event.date;
    _esPersonal = event.esPersonal;
    emit(const ScheduleLoading());
    try {
      final citas = await getAppointmentsByDate(event.date, esPersonal: _esPersonal);
      emit(ScheduleLoaded(appointments: citas, selectedDate: event.date));
    } catch (e) {
      emit(ScheduleError(_limpiar(e), previo: _cargadoActual));
    }
  }

  Future<void> _onBook(BookNewAppointment event, Emitter<ScheduleState> emit) async {
    final fecha = event.appointment.appointmentDateTime;
    emit(const ScheduleWorking('Guardando la cita...'));
    try {
      await bookAppointment(event.appointment);
      final citas = await getAppointmentsByDate(fecha, esPersonal: _esPersonal);
      emit(ScheduleLoaded(
        appointments: citas,
        selectedDate: fecha,
        mensajeExito: event.appointment.esNueva
            ? 'Cita registrada con exito.'
            : 'Cita actualizada con exito.',
      ));
    } catch (e) {
      emit(ScheduleError(_limpiar(e), previo: _cargadoActual));
      // Se recarga el dia para que la grilla refleje quien gano el horario.
      await _recargarSilencioso(fecha, emit);
    }
  }

  Future<void> _onCancel(CancelExistingAppointment event, Emitter<ScheduleState> emit) async {
    emit(const ScheduleWorking('Cancelando la cita...'));
    try {
      await cancelAppointment(event.appointment, esPersonal: event.esPersonal);
      final fecha = event.appointment.appointmentDateTime;
      final citas = await getAppointmentsByDate(fecha, esPersonal: _esPersonal);
      emit(ScheduleLoaded(
        appointments: citas,
        selectedDate: fecha,
        mensajeExito: 'La cita fue cancelada.',
      ));
    } catch (e) {
      emit(ScheduleError(_limpiar(e), previo: _cargadoActual));
    }
  }

  Future<void> _onReschedule(
      RescheduleExistingAppointment event, Emitter<ScheduleState> emit) async {
    emit(const ScheduleWorking('Reprogramando...'));
    try {
      await rescheduleAppointment(event.appointment, event.nuevaFecha);
      // Se carga el dia NUEVO, no el viejo: antes la cita parecia desaparecer
      // porque se recargaba la fecha de origen.
      final citas = await getAppointmentsByDate(event.nuevaFecha, esPersonal: _esPersonal);
      emit(ScheduleLoaded(
        appointments: citas,
        selectedDate: event.nuevaFecha,
        mensajeExito: 'Cita reprogramada con exito.',
      ));
    } catch (e) {
      emit(ScheduleError(_limpiar(e), previo: _cargadoActual));
    }
  }

  Future<void> _recargarSilencioso(DateTime fecha, Emitter<ScheduleState> emit) async {
    try {
      final citas = await getAppointmentsByDate(fecha, esPersonal: _esPersonal);
      emit(ScheduleLoaded(appointments: citas, selectedDate: fecha));
    } catch (_) {
      // Si tampoco se puede recargar, se deja el error ya emitido.
    }
  }

  DateTime get fechaActual => _ultimaFecha;

  /// Convierte la excepcion en algo que un padre pueda leer.
  static String _limpiar(Object e) {
    if (e is HorarioOcupadoException) return e.toString();
    if (e is CitaInvalidaException) return e.mensaje;
    final texto = e.toString();
    return texto.startsWith('Exception: ') ? texto.substring(11) : texto;
  }
}
