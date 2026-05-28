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
        // El listener reacciona a estados de "acción única" (como alertas, diálogos o navegaciones)
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
          }
        },
        // El builder se encarga puramente de renderizar los elementos visuales estables
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

          // Si está guardando, mantenemos la interfaz anterior visible pero bloqueada
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

  // --- DISEÑO PARA ESCRITORIO (Estilo NeoGaleno) ---
  Widget _buildDesktopLayout(ScheduleLoaded state) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Columna Izquierda: Selector de fecha / Mini Calendario
        SizedBox(
          width: 300,
          child: Card(
            margin: const EdgeInsets.all(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              key: const Key('calendar_desktop'),
              child: _buildCalendar(),
            ),
          ),
        ),
        // Columna Derecha: Grid de bloques de horarios disponibles
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
            // El calendario se posiciona arriba en móvil
            _buildCalendar(),
            const SizedBox(height: 24),
            Text(
              'Horarios disponibles:',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            // Ajustamos el grid a solo 2 columnas en pantallas pequeñas
            SizedBox(
              height: 400, // Altura fija simulada para el scroll interno
              child: _buildTimeSlotsGrid(state, crossAxisCount: 2),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCalendar() {
    return TableCalendar(
      // Configuración de idioma y rangos de fechas
      locale: 'es_ES', // Opcional: para poner los días en español (requiere inicializar intl)
      firstDay: DateTime.now().subtract(const Duration(days: 365)), // Un año atrás
      lastDay: DateTime.now().add(const Duration(days: 365)),      // Un año adelante
      focusedDay: _focusedDay,
      
      // Configuración de estilos visuales para que combine con Pediactual (Teal)
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
        formatButtonVisible: false, // Oculta el botón de "2 semanas" o "mes" para dejarlo simple
        titleCentered: true,
        titleTextStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
      ),

      // Lógica para saber qué día está marcado como seleccionado
      selectedDayPredicate: (day) {
        return isSameDay(_focusedDay, day);
      },

      // Lógica cuando el usuario hace clic en un día del calendario
      onDaySelected: (selectedDay, focusedDay) {
        if (!isSameDay(_focusedDay, selectedDay)) {
          setState(() {
            _focusedDay = selectedDay;
          });
          
          // ¡Crucial! Al cambiar el día, le avisamos al BLoC para que vaya a Firebase 
          // y traiga las citas de esta nueva fecha de inmediato.
          context.read<ScheduleBloc>().add(LoadAppointmentsForDate(selectedDay));
        }
      },
    );
  }

  // --- EL GRID DE HORARIOS (Crucial para la experiencia visual) ---
  Widget _buildTimeSlotsGrid(ScheduleLoaded state, {required int crossAxisCount}) {
    // ¡Aquí está la magia! Generamos los bloques en tiempo real combinando el día con Firestore
    final List<TimeSlotModel> calculatedSlots = TimeSlotHelper.generateSlotsForDate(
      selectedDate: state.selectedDate,
      bookedAppointments: state.appointments,
      startHour: 8,       // Puedes cambiarlo dinámicamente si el médico tiene otro horario
      endHour: 17,       // Hasta las 5:00 PM
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
          onPressed: slot.isOccupied 
            ? null // Queda completamente bloqueado si ya está ocupado
            : () => _showBookingDialog(slot.timeString, slot.dateTime),
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

  void _showBookingDialog(String timeString, DateTime appointmentDateTime) {
    final formKey = GlobalKey<FormState>();
    
    // Controladores para capturar el texto de los inputs
    final patientNameController = TextEditingController();
    final addressController = TextEditingController();
    final representativeNameController = TextEditingController();
    final emailController = TextEditingController();
    
    DateTime? selectedBirthDate;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder( // Nos permite manejar el estado del selector de fecha dentro del modal
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
                width: 500, // Ancho ideal para la versión Web de escritorio
                child: SingleChildScrollView(
                  child: Form(
                    key: formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Divider(),
                        const SizedBox(height: 8),
                        
                        // 1. Nombre del Paciente
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

                        // 2. Fecha de Nacimiento del Paciente
                        ListTile(
                          leading: const Icon(Icons.cake_outlined, color: Colors.teal),
                          title: Text(
                            selectedBirthDate == null
                                ? 'Fecha de Nacimiento'
                                : 'Nacido el: ${selectedBirthDate!.day}/${selectedBirthDate!.month}/${selectedBirthDate!.year}',
                          ),
                          subtitle: selectedBirthDate == null 
                              ? const Text('Selecciona la fecha', style: TextStyle(color: Colors.redHorizontal)) 
                              : null,
                          trailing: const Icon(Icons.arrow_drop_down),
                          shape: RoundedRectangleBorder(
                            side: const BorderSide(color: Colors.grey),
                            borderRadius: BorderRadius.circular(4),
                          ),
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
                        ),
                        const SizedBox(height: 16),

                        // 3. Dirección
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

                        // 4. Nombre del Representante
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

                        // 5. Correo Electrónico
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
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
                  onPressed: () {
                    // Validamos el formulario y que la fecha de nacimiento no esté vacía
                    if (formKey.currentState!.validate() && selectedBirthDate != null) {
                      
                      // Creamos la nueva entidad con los datos del formulario
                      final newAppointment = AppointmentEntity(
                        id: '', // Firestore generará el ID automáticamente al hacer el .add()
                        patientName: patientNameController.text.trim(),
                        patientBirthDate: selectedBirthDate!,
                        address: addressController.text.trim(),
                        representativeName: representativeNameController.text.trim(),
                        email: emailController.text.trim(),
                        appointmentDateTime: appointmentDateTime, // Pasado desde el Grid de horarios
                        status: 'pending',
                      );

                      // Disparamos el evento al BLoC para guardar en Firebase
                      context.read<ScheduleBloc>().add(BookNewAppointment(newAppointment));

                      Navigator.pop(context);
                      
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Procesando reserva médica...')),
                      );
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