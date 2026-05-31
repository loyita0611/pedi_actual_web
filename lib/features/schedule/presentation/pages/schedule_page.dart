// lib/features/schedule/presentation/pages/schedule_page.dart

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pedia_actual/features/schedule/domain/entities/appointment_entity.dart';
import 'package:pedia_actual/features/schedule/presentation/widgets/time_slot_helper.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart'; // Asegúrate de tener intl para formatear horas
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
        // Columna Izquierda: Calendario + Lista de lo Agendado
        SizedBox(
          width: 320,
          child: Column(
            children: [
              Card(
                margin: const EdgeInsets.all(16),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: _buildCalendar(),
                ),
              ),
              // PARTE 1: Lista de lo agendado del día actual debajo del calendario
              Expanded(
                child: Card(
                  margin: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.list_alt, color: Colors.teal),
                            SizedBox(width: 8),
                            Text(
                              'Citas del Día',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.teal),
                            ),
                          ],
                        ),
                        const Divider(),
                        Expanded(
                          child: state.appointments.isEmpty
                              ? const Center(
                                  child: Text(
                                    'No hay citas agendadas\npara esta fecha.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(color: Colors.grey),
                                  ),
                                )
                              : ListView.builder(
                                  itemCount: state.appointments.length,
                                  itemBuilder: (context, index) {
                                    final app = state.appointments[index];
                                    final String timeFormatted = DateFormat('hh:mm a').format(app.appointmentDateTime);
                                    return ListTile(
                                      contentPadding: EdgeInsets.zero,
                                      leading: const Icon(Icons.circle, color: Colors.amber, size: 12),
                                      title: Text(
                                        app.patientName,
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      subtitle: Text('Representante: ${app.representativeName}', style: const TextStyle(fontSize: 11)),
                                      trailing: Text(
                                        timeFormatted,
                                        style: const TextStyle(color: Colors.teal, fontWeight: FontWeight.bold, fontSize: 12),
                                      ),
                                    );
                                  },
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        // Columna Derecha: Cuadrícula de Horarios
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
      daysOfWeekStyle: DaysOfWeekStyle(
        weekdayStyle: const TextStyle(color: Colors.teal, fontWeight: FontWeight.bold, fontSize: 13),
        weekendStyle: TextStyle(color: Colors.red[400], fontWeight: FontWeight.bold, fontSize: 13),
        dowTextFormatter: (date, locale) {
          switch (date.weekday) {
            case DateTime.monday: return 'Lun';
            case DateTime.tuesday: return 'Mar';
            case DateTime.wednesday: return 'Mié';
            case DateTime.thursday: return 'Jue';
            case DateTime.friday: return 'Vie';
            case DateTime.saturday: return 'Sáb';
            case DateTime.sunday: return 'Dom';
            default: return '';
          }
        },
      ),
      calendarStyle: CalendarStyle(
        selectedDecoration: const BoxDecoration(color: Colors.teal, shape: BoxShape.circle),
        todayDecoration: BoxDecoration(color: Colors.teal[200], shape: BoxShape.circle),
        outsideDaysVisible: false,
        defaultTextStyle: const TextStyle(fontWeight: FontWeight.w500),
        weekendTextStyle: TextStyle(color: Colors.red[300], fontWeight: FontWeight.w500),
      ),
      headerStyle: const HeaderStyle(
        formatButtonVisible: false,
        titleCentered: true,
        titleTextStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.teal),
        leftChevronIcon: Icon(Icons.chevron_left, color: Colors.teal),
        rightChevronIcon: Icon(Icons.chevron_right, color: Colors.teal),
      ),
      selectedDayPredicate: (day) => isSameDay(_focusedDay, day),
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

        // Buscamos la entidad de la cita real si el slot está ocupado para extraer datos extras
        AppointmentEntity? realAppointment;
        if (slot.isOccupied) {
          realAppointment = state.appointments.firstWhere(
            (a) => a.appointmentDateTime.hour == slot.dateTime.hour && a.appointmentDateTime.minute == slot.dateTime.minute,
          );
        }

        // PARTE 2: Agregamos el Tooltip interactivo al pararse sobre la cita
        return Tooltip(
          message: slot.isOccupied 
              ? "Paciente: ${realAppointment?.patientName}\nAgendado para: ${slot.timeString}"
              : "Horario Disponible",
          preferBelow: false,
          child: InkWell(
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
          ),
        );
      },
    );
  }

  // --- FORMULARIO REGISTRO MEDICO CON PASO DE PAGO INCLUIDO ---
  void _showBookingDialog(String timeString, DateTime appointmentDateTime) {
    final formKey = GlobalKey<FormState>();
    final paymentFormKey = GlobalKey<FormState>();
    
    final patientNameController = TextEditingController();
    final addressController = TextEditingController();
    final representativeNameController = TextEditingController();
    final emailController = TextEditingController();
    
    // Controladores para pasarela de pago móvil/transferencia
    final referenceController = TextEditingController();
    final phoneOrBankController = TextEditingController();
    
    DateTime? selectedBirthDate;
    String selectedPaymentMethod = 'Pago Móvil'; // Método de pago por defecto

    final scheduleBloc = context.read<ScheduleBloc>();

    showDialog(
      context: context,
      builder: (dialogContext) {
        int currentStep = 1; // Control de pantalla: 1 = Datos, 2 = Pasarela de Pago

        return StatefulBuilder( 
          builder: (context, setModalState) {
            return AlertDialog(
              title: Row(
                children: [
                  Icon(currentStep == 1 ? Icons.child_care : Icons.payment, color: Colors.teal),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      currentStep == 1 
                          ? 'Nueva Cita Pediátrica - $timeString'
                          : 'Pasarela de Pago - Total: \$40',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: 500, 
                child: SingleChildScrollView(
                  child: currentStep == 1
                      ? Form(
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
                        )
                      : Form(
                          key: paymentFormKey,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Selecciona tu método de pago:', style: TextStyle(fontWeight: FontWeight.bold)),
                              const SizedBox(height: 8),
                              DropdownButtonFormField<String>(
                                value: selectedPaymentMethod,
                                decoration: const InputDecoration(border: OutlineInputBorder()),
                                items: ['Pago Móvil', 'Transferencia Bancaria'].map((method) {
                                  return DropdownMenuItem(value: method, child: Text(method));
                                }).toList(),
                                onChanged: (value) {
                                  setModalState(() {
                                    selectedPaymentMethod = value!;
                                  });
                                },
                              ),
                              const SizedBox(height: 16),
                              // Campos dinámicos según la elección de pago
                              TextFormField(
                                controller: phoneOrBankController,
                                keyboardType: TextInputType.text,
                                decoration: InputDecoration(
                                  labelText: selectedPaymentMethod == 'Pago Móvil' 
                                      ? 'Teléfono Emisor del Pago' 
                                      : 'Banco de Origen',
                                  prefixIcon: Icon(selectedPaymentMethod == 'Pago Móvil' ? Icons.phone : Icons.account_balance),
                                  border: const OutlineInputBorder(),
                                ),
                                validator: (value) => value!.isEmpty ? 'Campo requerido' : null,
                              ),
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: referenceController,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  labelText: 'Número de Referencia Bancaria (Últimos 4 o 6 dígitos)',
                                  prefixIcon: Icon(Icons.numbers),
                                  border: OutlineInputBorder(),
                                ),
                                validator: (value) => value!.isEmpty ? 'Por favor ingresa el número de referencia' : null,
                              ),
                              const SizedBox(height: 12),
                              const Text(
                                '*Nota: La cita quedará reservada en estado "Pendiente" hasta validar la transacción.',
                                style: TextStyle(color: Colors.grey, fontSize: 11, fontStyle: FontStyle.italic),
                              ),
                            ],
                          ),
                        ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    if (currentStep == 2) {
                      setModalState(() { currentStep = 1; });
                    } else {
                      Navigator.pop(dialogContext);
                    }
                  },
                  child: Text(currentStep == 2 ? 'Atrás' : 'Cancelar', style: const TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
                  onPressed: () {
                    if (currentStep == 1) {
                      // Validar datos médicos antes de pasar al pago
                      if (formKey.currentState!.validate() && selectedBirthDate != null) {
                        setModalState(() {
                          currentStep = 2; // Avanzamos a la pasarela de pago móvil
                        });
                      }
                    } else {
                      // Validar datos de pago y enviar definitivo a Firebase
                      if (paymentFormKey.currentState!.validate()) {
                        final newAppointment = AppointmentEntity(
                          id: '', 
                          patientName: patientNameController.text.trim(),
                          patientBirthDate: selectedBirthDate!,
                          address: addressController.text.trim(),
                          representativeName: representativeNameController.text.trim(),
                          email: emailController.text.trim(),
                          appointmentDateTime: appointmentDateTime, 
                          status: 'pending', // Queda guardado esperando verificación
                        );

                        // Enviamos al BLoC para guardar en Cloud Firestore
                        scheduleBloc.add(BookNewAppointment(newAppointment));
                        Navigator.pop(dialogContext);
                      }
                    }
                  },
                  child: Text(currentStep == 1 ? 'Continuar al Pago' : 'Confirmar y Pagar'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}