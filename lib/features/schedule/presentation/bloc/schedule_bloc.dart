// lib/features/schedule/presentation/bloc/schedule_bloc.dart

import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/usecases/get_appointments_by_date.dart';
import '../../domain/usecases/book_appointment.dart'; // Importamos el nuevo caso de uso
import 'schedule_event.dart';
import 'schedule_state.dart';

class ScheduleBloc extends Bloc<ScheduleEvent, ScheduleState> {
  final GetAppointmentsByDate getAppointmentsByDate;
  final BookAppointment bookAppointment; // Inyectamos el caso de uso para agendar

  ScheduleBloc({
    required this.getAppointmentsByDate,
    required this.bookAppointment,
  }) : super(ScheduleInitial()) {
    
    // 1. Manejador para Cargar Citas de una Fecha
    on<LoadAppointmentsForDate>((event, emit) async {
      emit(ScheduleLoading());
      try {
        final appointments = await getAppointmentsByDate(event.date);
        emit(ScheduleLoaded(appointments: appointments, selectedDate: event.date));
      } catch (e) {
        emit(ScheduleError(e.toString()));
      }
    });

    // 2. Manejador para Registrar Nueva Cita Pediátrica
    on<BookNewAppointment>((event, emit) async {
      // Guardamos una referencia de la fecha actual que se estaba viendo para poder recargarla después
      final DateTime currentDate = event.appointment.appointmentDateTime;

      emit(AppointmentBookingInProgress()); // Estado de "Guardando..." para bloquear botones o mostrar barra
      
      try {
        // Llamamos al caso de uso (que se comunica con Repository e implementa Firestore)
        await bookAppointment(event.appointment);
        
        emit(AppointmentBookedSuccess()); // Emitimos éxito temporalmente

        // ¡Estrategia clave! Volvemos a disparar automáticamente la carga de citas del día.
        // Esto hace que el grid de horarios se actualice solo y pinte el nuevo turno en gris de inmediato.
        add(LoadAppointmentsForDate(currentDate));
        
      } catch (e) {
        emit(ScheduleError('Error al guardar la cita: ${e.toString()}'));
      }
    });
  }
}