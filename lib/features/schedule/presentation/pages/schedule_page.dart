// lib/features/schedule/presentation/pages/schedule_page.dart

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pedia_actual/features/schedule/domain/entities/appointment_entity.dart';
import 'package:pedia_actual/features/schedule/presentation/widgets/time_slot_helper.dart';
import 'package:table_calendar/table_calendar.dart';
import '../bloc/schedule_bloc.dart';
import '../bloc/schedule_state.dart';
import '../bloc/schedule_event.dart';

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
      appBar: AppBar(
        title: const Text('Agenda Pediactual'),
        backgroundColor: Colors.teal,
      ),
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

  // --- DISEÑO PARA ESCRITORIO ---
  Widget _buildDesktopLayout(ScheduleLoaded state) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 300,
          child: Card(
            margin: const EdgeInsets.all(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: _buildCalendar(),
            ),
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
                Expanded(child: _buildTimeSlotsGrid(state, crossAxisCount: 4)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // --- DISEÑO PARA MÓVIL ---
  Widget _buildMobileLayout(ScheduleLoaded state) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildCalendar(),
            const SizedBox(height: 24),
            const Text(
              'Horarios disponibles:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 400,
              child: _buildTimeSlotsGrid(state, crossAxisCount: 2),
            ),
          ],
        ),
      ),
    );
  }

  // --- WIDGET CALENDARIO INTERACTIVO ---
  Widget _buildCalendar() {
    return TableCalendar(
      locale: 'es_ES',
      firstDay: DateTime.now().subtract(const Duration(days: 365)),
      lastDay: DateTime.now().add(const Duration(days: 365)),
      focusedDay: _focusedDay,
      calendarStyle: CalendarStyle(
        selectedDecoration: const BoxDecoration(
          color: Colors.teal,
          shape: BoxShape.circle,
        ),
        todayDecoration: BoxDecoration(
          color: Colors.teal[200],
          shape: BoxShape.circle,
        ),
        outsideDaysVisible: false,
      ),
      headerStyle: const HeaderStyle(
        formatButtonVisible: false,
        titleCentered: true,
        titleTextStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
      ),
      selectedDayPredicate: (day) {
        return isSameDay(_focusedDay, day);
      },
      onDaySelected: (selectedDay, focusedDay) {
        if (!isSameDay(_focusedDay, selectedDay)) {
          setState(() {
            _focusedDay = selectedDay;
          });
          context.read<ScheduleBloc>().add(LoadAppointmentsForDate(selectedDay));
        }
      },
    );
  }

  // --- GRID DE HORARIOS ---
  Widget _buildTimeSlotsGrid(ScheduleLoaded state, {required int crossAxisCount}) {
    final List<TimeSlotModel> calculatedSlots = TimeSlotHelper.generateSlotsForDate(
      selectedDate: state.selectedDate,
      bookedAppointments: state.appointments,
      startHour: 8,       
      endHour: 17,       
      intervalMinutes: 30,
    );

    if (calculatedSlots.isEmpty) {
      return const Center(child: Text('No hay horarios configurados para este día.'));
    }

    return GridView.builder(
      itemCount: calculatedSlots.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 2.5,
      ),
      itemBuilder: (context, index) {
        final slot = calculatedSlots[index];

        return InkWell(
          onTap: () {
            if (!slot.isOccupied) {
              _showBookingDialog(slot.timeString, slot.dateTime);
            }
          },
          borderRadius: BorderRadius.circular(8),
          child: Container(
            decoration: BoxDecoration(
              color: slot.isOccupied ? Colors.grey[300] : Colors.teal[50],
              border: Border.all(color: slot.isOccupied ? Colors.grey : Colors.teal),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center( 
              child: Text(
                slot.timeString,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: slot.isOccupied ? Colors.grey[600] : Colors.teal[900],
                  decoration: slot.isOccupied ? TextDecoration.lineThrough : null,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // --- FORMULARIO REGISTRO MEDICO EN MODAL ---
  void _showBookingDialog(String timeString, DateTime appointmentDateTime) {
    final formKey = GlobalKey<FormState>();
    final patientNameController = TextEditingController();
    final addressController = TextEditingController();
    final representativeNameController = TextEditingController();
    final emailController = TextEditingController();
    DateTime? selectedBirthDate;

    // 🚀 CAPTURAMOS EL BLOC ANTES DE ENTRAR AL MODAL
    // Guardamos la instancia del BLoC que sí vive en el contexto válido de SchedulePage
    final scheduleBloc = context.read<ScheduleBloc>();

    showDialog(
      context: context,
      builder: (dialogContext) { // Cambiamos el nombre a dialogContext para no confundir
        return StatefulBuilder( 
          builder: (context, setModalState) {
            return AlertDialog(
              title: Row(
                children: [
                  const Icon(Icons.child_care, color: Colors.teal),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Nueva Cita Pediátrica - $timeString',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: 500, 
                child: SingleChildScrollView(
                  child: Form(
                    key: formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Divider(),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: patientNameController,
                          decoration: const InputDecoration(
                            labelText: 'Nombre y Apellido del Paciente (Niño/a)',
                            prefixIcon: Icon(Icons.person_outline),
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) => value!.isEmpty ? 'Por favor ingresa el nombre del niño' : null,
                        ),
                        const SizedBox(height: 16),
                        InkWell(
                          onTap: () async {
                            final DateTime? picked = await showDatePicker(
                              context: context,
                              initialDate: DateTime.now().subtract(const Duration(days: 365)),
                              firstDate: DateTime(2010),
                              lastDate: DateTime.now(),
                            );
                            if (picked != null) {
                              setModalState(() {
                                selectedBirthDate = picked;
                              });
                            }
                          },
                          child: InputDecorator(
                            decoration: InputDecoration(
                              labelText: 'Fecha de Nacimiento',
                              prefixIcon: const Icon(Icons.cake_outlined, color: Colors.teal),
                              border: const OutlineInputBorder(),
                              errorText: selectedBirthDate == null ? 'Selecciona la fecha' : null,
                            ),
                            child: Text(
                              selectedBirthDate == null
                                  ? ''
                                  : '${selectedBirthDate!.day}/${selectedBirthDate!.month}/${selectedBirthDate!.year}',
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: addressController,
                          decoration: const InputDecoration(
                            labelText: 'Dirección de Habitación',
                            prefixIcon: Icon(Icons.home_outlined),
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) => value!.isEmpty ? 'Por favor ingresa la dirección' : null,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: representativeNameController,
                          decoration: const InputDecoration(
                            labelText: 'Nombre y Apellido del Representante',
                            prefixIcon: Icon(Icons.assignment_ind_outlined),
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) => value!.isEmpty ? 'Por favor ingresa el nombre del representante' : null,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: emailController,
                          keyboardType: TextInputType.emailAddress,
                          decoration: const InputDecoration(
                            labelText: 'Correo Electrónico',
                            prefixIcon: Icon(Icons.email_outlined),
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) {
                            if (value!.isEmpty) return 'Por favor ingresa el correo';
                            if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                              return 'Ingresa un correo electrónico válido';
                            }
                            return null;
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
                  onPressed: () {
                    if (formKey.currentState!.validate() && selectedBirthDate != null) {
                      final newAppointment = AppointmentEntity(
                        id: '', 
                        patientName: patientNameController.text.trim(),
                        patientBirthDate: selectedBirthDate!,
                        address: addressController.text.trim(),
                        representativeName: representativeNameController.text.trim(),
                        email: emailController.text.trim(),
                        appointmentDateTime: appointmentDateTime, 
                        status: 'pending',
                      );

                      // 🚀 CONEXIÓN DIRECTA: Usamos la referencia que aislamos arriba en vez del context.read
                      scheduleBloc.add(BookNewAppointment(newAppointment));
                      
                      // Cerramos usando el contexto del diálogo de forma segura
                      Navigator.pop(dialogContext);
                    }
                  },
                  child: const Text('Registrar Cita'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}