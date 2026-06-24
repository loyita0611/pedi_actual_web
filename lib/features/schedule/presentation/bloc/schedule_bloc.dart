// lib/features/schedule/presentation/bloc/schedule_bloc.dart

import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/usecases/get_appointments_by_date.dart';
import '../../domain/usecases/book_appointment.dart'; 
import '../../domain/entities/appointment_entity.dart';
import 'schedule_event.dart';
import 'schedule_state.dart';

class ScheduleBloc extends Bloc<ScheduleEvent, ScheduleState> {
  final GetAppointmentsByDate getAppointmentsByDate;
  final BookAppointment bookAppointment; 

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

    // 2. Manejador para Registrar Nueva Cita Pediátrica (Sincronizado de Verdad)
    on<BookNewAppointment>((event, emit) async {
      final DateTime currentDate = event.appointment.appointmentDateTime;

      emit(AppointmentBookingInProgress()); 
      
      try {
        // 1. Enviamos la petición de guardado a Firestore y esperamos la confirmación real del servidor
        await bookAppointment(event.appointment);
        
        // 2. 🚀 CONSULTA REAL: Traemos la lista actualizada directamente de la base de datos.
        // Al esperar el 'await' de arriba, garantizamos que Firestore ya tiene el cambio reflejado.
        final List<AppointmentEntity> updatedAppointments = await getAppointmentsByDate(currentDate);

        // 3. Emitimos el estado con los datos frescos y reales
        emit(ScheduleLoaded(appointments: updatedAppointments, selectedDate: currentDate));
        
      } catch (e) {
        // Si falla, emitimos el error
        emit(ScheduleError('Error al guardar la cita: ${e.toString()}'));
      }
    });
  }
}