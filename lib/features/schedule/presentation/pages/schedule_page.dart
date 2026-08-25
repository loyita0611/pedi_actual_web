// lib/features/schedule/presentation/pages/schedule_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/entities/appointment_entity.dart'; 
import 'package:pedia_actual/features/schedule/presentation/widgets/time_slots_grid.dart';
import '../bloc/schedule_bloc.dart';
import '../bloc/schedule_state.dart';
import '../bloc/schedule_event.dart';
import '../widgets/schedule_calendar.dart';
import '../widgets/daily_appointments_list.dart';
import '../widgets/booking_dialog.dart';

class SchedulePage extends StatefulWidget {
  const SchedulePage({super.key});

  @override
  State<SchedulePage> createState() => _SchedulePageState();
}

class _SchedulePageState extends State<SchedulePage> {
  DateTime _focusedDay = DateTime.now();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BlocConsumer<ScheduleBloc, ScheduleState>(
        listener: (context, state) {
          if (state is AppointmentBookingInProgress) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Guardando cita médica en la base de datos...'),
                duration: Duration(seconds: 1),
              ),
            );
          }
          if (state is AppointmentBookedSuccess) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('¡Cita registrada con éxito!'),
                backgroundColor: Colors.green,
              ),
            );
            // 🔄 Forzar recarga automática del día para que los botones cambien de color al instante
            context.read<ScheduleBloc>().add(LoadAppointmentsForDate(_focusedDay));
          }
        },
        builder: (context, state) {
          if (state is ScheduleInitial) {
            context.read<ScheduleBloc>().add(LoadAppointmentsForDate(_focusedDay));
            return const Center(child: CircularProgressIndicator());
          }
          if (state is ScheduleLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state is ScheduleError) {
            return Center(child: Text('Error: ${state.message}'));
          }
          if (state is ScheduleLoaded) {
            return LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth > 800) {
                  return _buildDesktopLayout(state);
                } else {
                  return _buildMobileLayout(state);
                }
              },
            );
          }
          return const Center(child: CircularProgressIndicator());
        },
      ),
    );
  }

  Widget _buildDesktopLayout(ScheduleLoaded state) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 320,
          child: Column(
            children: [
              Card(
                margin: const EdgeInsets.all(16),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: ScheduleCalendar(
                    focusedDay: _focusedDay,
                    onDaySelected: _onDaySelected,
                  ),
                ),
              ),
              Expanded(
                child: DailyAppointmentsList(
                  appointments: state.appointments,
                  onRefresh: () {
                    context.read<ScheduleBloc>().add(LoadAppointmentsForDate(state.selectedDate));
                  },
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Horarios para el ${state.selectedDate.day}/${state.selectedDate.month}/${state.selectedDate.year}',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.teal),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: TimeSlotsGrid(
                    selectedDate: state.selectedDate,
                    appointments: state.appointments,
                    crossAxisCount: 4,
                    onSlotSelected: _openBookingDialog,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMobileLayout(ScheduleLoaded state) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ScheduleCalendar(
              focusedDay: _focusedDay,
              onDaySelected: _onDaySelected,
            ),
            const SizedBox(height: 24),
            const Text(
              'Horarios disponibles:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 400,
              child: TimeSlotsGrid(
                selectedDate: state.selectedDate,
                appointments: state.appointments,
                crossAxisCount: 2,
                onSlotSelected: _openBookingDialog,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _onDaySelected(DateTime selectedDay) {
    setState(() {
      _focusedDay = selectedDay;
    });
    context.read<ScheduleBloc>().add(LoadAppointmentsForDate(selectedDay));
  }

  // 🚀 MÉTODO OPTIMIZADO Y REPARADO PARA SOPORTAR NUEVAS CITAS Y EDICIONES
  void _openBookingDialog(String timeString, DateTime appointmentDateTime) async {
    AppointmentEntity? appointmentParaEditar;
    final state = context.read<ScheduleBloc>().state;

    if (state is ScheduleLoaded) {
      // Buscamos si coincide con alguna cita guardada en el arreglo local
      for (var app in state.appointments) {
        if (app.appointmentDateTime.year == appointmentDateTime.year &&
            app.appointmentDateTime.month == appointmentDateTime.month &&
            app.appointmentDateTime.day == appointmentDateTime.day &&
            app.appointmentDateTime.hour == appointmentDateTime.hour &&
            app.appointmentDateTime.minute == appointmentDateTime.minute) {
          appointmentParaEditar = app;
          break;
        }
      }
    }

    // Si es una hora libre, le pasamos una entidad inicializada limpia pero con la fecha/hora seleccionada
    appointmentParaEditar ??= AppointmentEntity(
      id: '',
      patientName: '',
      patientBirthDate: DateTime.now().subtract(const Duration(days: 365)),
      address: '',
      phone:'',
      representativeName: '',
      email: '',
      appointmentDateTime: appointmentDateTime, // Arrastra la hora correcta cliqueada
      status: 'pending',
    );

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return BookingDialog(
          appointment: appointmentParaEditar, 
          timeString: timeString,
          appointmentDateTime: appointmentDateTime,
          onConfirmBooking: (updatedAppointment) {
            context.read<ScheduleBloc>().add(BookNewAppointment(updatedAppointment));
          },
        );
      },
    );
  }
}