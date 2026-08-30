// lib/features/schedule/presentation/pages/schedule_page.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../../core/config/clinic_config.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/async_states.dart';
import '../../domain/entities/appointment_entity.dart';
import '../bloc/schedule_bloc.dart';
import '../bloc/schedule_event.dart';
import '../bloc/schedule_state.dart';
import '../widgets/booking_dialog.dart';
import '../widgets/daily_appointments_list.dart';
import '../widgets/schedule_calendar.dart';
import '../widgets/time_slots_grid.dart';

class SchedulePage extends StatefulWidget {
  const SchedulePage({super.key, this.esPersonal = false});

  /// Secretaria y doctora ven los nombres de los pacientes; el representante no.
  final bool esPersonal;

  @override
  State<SchedulePage> createState() => _SchedulePageState();
}

class _SchedulePageState extends State<SchedulePage> {
  DateTime _dia = DateTime.now();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: BlocConsumer<ScheduleBloc, ScheduleState>(
        listener: (context, state) {
          if (state is ScheduleLoaded && state.mensajeExito != null) {
            mostrarAviso(context, state.mensajeExito!, esExito: true);
            _dia = state.selectedDate;
          }
          if (state is ScheduleError) {
            mostrarAviso(context, state.message, esError: true);
          }
        },
        builder: (context, state) {
          if (state is ScheduleInitial) {
            context.read<ScheduleBloc>().add(
                LoadAppointmentsForDate(_dia, esPersonal: widget.esPersonal));
            return const CargandoCentrado();
          }
          if (state is ScheduleWorking) return CargandoCentrado(mensaje: state.mensaje);
          if (state is ScheduleLoading) return const CargandoCentrado();

          // Un error ya no deja la pantalla en blanco con un volcado tecnico:
          // se vuelve a pintar la grilla anterior y el aviso sale arriba.
          final cargado = state is ScheduleLoaded
              ? state
              : state is ScheduleError
                  ? state.previo
                  : null;

          if (cargado == null) {
            return EstadoError(
              error: state is ScheduleError ? state.message : 'No se pudo cargar la agenda',
              onReintentar: () => context.read<ScheduleBloc>().add(
                  LoadAppointmentsForDate(_dia, esPersonal: widget.esPersonal)),
            );
          }

          return LayoutBuilder(
            builder: (context, c) =>
                c.maxWidth > 880 ? _escritorio(cargado) : _movil(cargado),
          );
        },
      ),
    );
  }

  Widget _escritorio(ScheduleLoaded state) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 330,
          child: Column(
            children: [
              Card(
                margin: const EdgeInsets.all(16),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: ScheduleCalendar(
                    focusedDay: _dia,
                    permitirPasado: widget.esPersonal,
                    onDaySelected: _cambiarDia,
                  ),
                ),
              ),
              Expanded(
                child: DailyAppointmentsList(
                  appointments: state.appointments,
                  esPersonal: widget.esPersonal,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _encabezado(state.selectedDate),
                const SizedBox(height: 16),
                Expanded(child: _grilla(state, 4)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _movil(ScheduleLoaded state) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: ScheduleCalendar(
                focusedDay: _dia,
                permitirPasado: widget.esPersonal,
                onDaySelected: _cambiarDia,
              ),
            ),
          ),
          const SizedBox(height: 20),
          _encabezado(state.selectedDate),
          const SizedBox(height: 14),
          SizedBox(height: 420, child: _grilla(state, 2)),
          const SizedBox(height: 20),
          SizedBox(
            height: 300,
            child: DailyAppointmentsList(
              appointments: state.appointments,
              esPersonal: widget.esPersonal,
            ),
          ),
        ],
      ),
    );
  }

  Widget _encabezado(DateTime dia) {
    final libres = ClinicConfigService.actual.esDiaHabil(dia);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          DateFormat("EEEE d 'de' MMMM 'de' y", 'es').format(dia),
          style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold, color: AppColors.primary),
        ),
        const SizedBox(height: 3),
        Text(
          libres ? 'Elige un horario disponible para agendar.' : 'La consulta no atiende este dia.',
          style: const TextStyle(fontSize: 13.5, color: AppColors.textSecondary),
        ),
      ],
    );
  }

  Widget _grilla(ScheduleLoaded state, int columnas) => TimeSlotsGrid(
        selectedDate: state.selectedDate,
        appointments: state.appointments,
        crossAxisCount: columnas,
        exponerDatosDelPaciente: widget.esPersonal,
        onSlotSelected: _abrirReserva,
      );

  void _cambiarDia(DateTime dia) {
    setState(() => _dia = dia);
    context
        .read<ScheduleBloc>()
        .add(LoadAppointmentsForDate(dia, esPersonal: widget.esPersonal));
  }

  Future<void> _abrirReserva(String hora, DateTime cuando) async {
    final bloc = context.read<ScheduleBloc>();

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => BookingDialog(
        timeString: hora,
        appointmentDateTime: cuando,
        onConfirmBooking: (cita) => _guardar(bloc, cita, hora),
      ),
    );
  }

  /// Cuanto se espera al bloc antes de dar la reserva por perdida.
  ///
  /// Firestore no lanza error cuando no hay red: encola la escritura y deja la
  /// promesa esperando, asi que sin este limite el bloc no emite nunca y el
  /// dialogo se queda en "Guardando..." para siempre.
  static const Duration _limiteReserva = Duration(seconds: 45);

  /// Devuelve true solo si Firestore confirmo el guardado, y lanza con el
  /// motivo cuando no. El correo se manda despues, nunca antes: asi el
  /// representante no recibe la confirmacion de una cita que no llego a
  /// existir.
  Future<bool> _guardar(ScheduleBloc bloc, AppointmentEntity cita, String hora) async {
    if (bloc.isClosed) {
      throw const ReservaFallida(
        'La agenda se cerro antes de guardar. Vuelve a abrir el horario.',
      );
    }

    // La suscripcion se abre antes de despachar el evento: al reves habria una
    // ventana en la que el bloc ya emitio y este future se queda esperando.
    final espera = bloc.stream
        .firstWhere((s) => s is ScheduleLoaded || s is ScheduleError)
        .timeout(_limiteReserva);

    bloc.add(BookNewAppointment(cita));

    final ScheduleState resultado;
    try {
      resultado = await espera;
    } on TimeoutException {
      throw const ReservaFallida(
        'El servidor no respondio a tiempo. Revisa tu conexion y confirma en '
        '"Mis citas" si la reserva quedo hecha antes de volver a intentarlo.',
      );
    } on StateError {
      // El bloc se cerro sin emitir (la pantalla se desmonto a mitad).
      throw const ReservaFallida(
        'La agenda se cerro antes de terminar de guardar. Vuelve a intentarlo.',
      );
    }

    // El motivo viaja hasta el dialogo: el SnackBar del listener sale por
    // detras de la barrera modal y el representante no lo ve.
    if (resultado is ScheduleError) {
      throw ReservaFallida(resultado.message);
    }

    // El correo de confirmacion lo dispara una funcion del servidor al ver la
    // cita nueva en Firestore. Asi no puede salir el aviso de una cita que no
    // llego a guardarse, y las credenciales del correo no viajan al navegador.
    return true;
  }
}
