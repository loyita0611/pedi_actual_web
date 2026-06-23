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

    // 2. Manejador para Registrar Nueva Cita Pediátrica (Actualización Optimista)
    on<BookNewAppointment>((event, emit) async {
      final DateTime currentDate = event.appointment.appointmentDateTime;
      final currentState = state;

      // Guardamos el estado anterior por seguridad en caso de error
      List<AppointmentEntity> oldAppointments = []; 
      if (currentState is ScheduleLoaded) {
        oldAppointments = currentState.appointments;
      }

      emit(AppointmentBookingInProgress()); 
      
      try {
        // 1. Enviamos la petición de guardado a Firestore y esperamos la confirmación del servidor
        await bookAppointment(event.appointment);
        
        // 2. 🚀 SOLUCIÓN: En lugar de re-consultar a Firebase (que puede devolver datos de caché viejos),
        // creamos una nueva lista local combinando las citas anteriores con la nueva entidad insertada.
        final List<AppointmentEntity> localUpdatedAppointments = List.from(oldAppointments)
          ..add(event.appointment);

        // 3. Emitimos directamente el nuevo estado con los datos actualizados localmente en tiempo real
        emit(ScheduleLoaded(appointments: localUpdatedAppointments, selectedDate: currentDate));
        
      } catch (e) {
        // Si la inserción en Firebase falla por red o permisos, revertimos la UI al estado previo seguro
        emit(ScheduleLoaded(appointments: oldAppointments, selectedDate: currentDate));
        emit(ScheduleError('Error al guardar la cita: ${e.toString()}'));
      }
    });
  }
}