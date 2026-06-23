// lib/features/schedule/presentation/widgets/daily_appointments_list.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../domain/entities/appointment_entity.dart';

class DailyAppointmentsList extends StatefulWidget {
  final List<AppointmentEntity> appointments;
  final VoidCallback? onRefresh; // 🔄 Callback para avisarle al padre que actualice la pantalla

  const DailyAppointmentsList({
    super.key, 
    required this.appointments,
    this.onRefresh, // 🔄 Lo recibimos aquí
  });

  @override
  State<DailyAppointmentsList> createState() => _DailyAppointmentsListState();
}

class _DailyAppointmentsListState extends State<DailyAppointmentsList> {

  // 🛠️ 1. Diálogo de Confirmación de Seguridad
  Future<void> _mostrarConfirmacionGuardar({
    required AppointmentEntity appointment,
    required String nuevaFechaStr,
    required String nuevaHoraStr,
  }) async {
    return showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.amber),
              SizedBox(width: 8),
              Text('¿Confirmar cambios?', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
          content: Text(
            '¿Estás seguro de reprogramar la cita de ${appointment.patientName} para el día $nuevaFechaStr a las $nuevaHoraStr?',
            style: const TextStyle(fontSize: 14),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext), 
              child: const Text('Cancelar', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
              ),
              onPressed: () {
                Navigator.pop(dialogContext); 
                _procesarReprogramacion(
                  appointment: appointment,
                  nuevaFechaStr: nuevaFechaStr,
                  nuevaHoraStr: nuevaHoraStr,
                );
              },
              child: const Text('Guardar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  // 🛠️ 2. Diálogo para elegir horarios (Detecta y bloquea ocupados)
  Future<void> _mostrarSelectorHorarios({
    required AppointmentEntity appointment,
    required String nuevaFechaStr,
    required List<String> horasOcupadas, 
  }) async {
    final List<String> horariosDisponibles = [
      "08:00 AM", "08:30 AM", "09:00 AM", "09:30 AM",
      "10:00 AM", "10:30 AM", "11:00 AM", "11:30 AM",
      "12:00 PM", "12:30 PM", "01:00 PM", "01:30 PM",
      "02:00 PM", "02:30 PM", "03:00 PM", "03:30 PM",
      "04:00 PM", "04:30 PM"
    ];

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: Text(
            'Horarios Disponibles ($nuevaFechaStr)',
            style: const TextStyle(color: Colors.teal, fontSize: 16, fontWeight: FontWeight.bold),
          ),
          content: SizedBox(
            width: 360,   
            height: 250,  
            child: GridView.builder(
              shrinkWrap: true,
              physics: const ClampingScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                childAspectRatio: 2.0, 
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemCount: horariosDisponibles.length,
              itemBuilder: (context, index) {
                final horaSlot = horariosDisponibles[index];
                final bool estaOcupado = horasOcupadas.any((h) => h.trim().toUpperCase() == horaSlot.trim().toUpperCase());
                
                return OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(
                      color: estaOcupado ? Colors.grey.shade300 : Colors.teal.shade300, 
                      width: 1.2
                    ),
                    backgroundColor: estaOcupado ? Colors.grey.shade100 : Colors.transparent,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: EdgeInsets.zero, 
                  ),
                  onPressed: estaOcupado ? null : () {
                    Navigator.pop(dialogContext); 
                    _mostrarConfirmacionGuardar(
                      appointment: appointment,
                      nuevaFechaStr: nuevaFechaStr,
                      nuevaHoraStr: horaSlot,
                    );
                  },
                  child: Text(
                    horaSlot,
                    style: TextStyle(
                      color: estaOcupado ? Colors.grey.shade400 : Colors.teal, 
                      fontWeight: FontWeight.bold, 
                      fontSize: 12.5,
                      decoration: estaOcupado ? TextDecoration.lineThrough : null, 
                    ),
                  ),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Volver', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  // 🛠️ 3. Lógica de guardado en la nube de Firestore y EmailJS
  Future<void> _procesarReprogramacion({
    required AppointmentEntity appointment,
    required String nuevaFechaStr,
    required String nuevaHoraStr,
  }) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) => const Center(child: CircularProgressIndicator(color: Colors.teal)),
    );

    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('pagos')
          .where('nombrePaciente', isEqualTo: appointment.patientName)
          .where('emailPaciente', isEqualTo: appointment.email)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        final docId = querySnapshot.docs.first.id;
        await FirebaseFirestore.instance.collection('pagos').doc(docId).update({
          'fechaCita': nuevaFechaStr,
          'horaCita': nuevaHoraStr,
          'fechaActualizacion': FieldValue.serverTimestamp(),
        });
      }

      final urlCorreo = Uri.parse('https://api.emailjs.com/api/v1.0/email/send');
      await http.post(
        urlCorreo,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'service_id': 'service_vfquxn8',      
          'template_id': 'template_brfi9f5',      
          'user_id': 'wC6RQuuJG9ZfdQxp9',        
          'template_params': {
            'to_email': appointment.email,
            'patient_name': appointment.patientName,
            'appointment_date': "$nuevaFechaStr (REPROGRAMADA)", 
            'appointment_time': "$nuevaHoraStr (NUEVO HORARIO)", 
            'doctor_phone': "+58 412-5555555",    
          }
        }),
      );

      if (!mounted) return;
      Navigator.pop(context); // Cierra el indicador de carga

      // 🔄 Ejecutamos la recarga global del padre si fue proveída
      if (widget.onRefresh != null) {
        widget.onRefresh!();
      } else {
        setState(() {}); 
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('¡Cita de ${appointment.patientName} actualizada con éxito!'),
          backgroundColor: Colors.teal,
        ),
      );

    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      debugPrint("Error executing rescheduling: $e");
    }
  }

  // 🛠️ 4. Gatillo al pulsar el lápiz
  Future<void> _reprogramarCita({
    required AppointmentEntity appointment,
  }) async {
    final DateTime? nuevaFecha = await showDatePicker(
      context: context,
      initialDate: appointment.appointmentDateTime,
      firstDate: DateTime.now().subtract(const Duration(days: 365)), 
      lastDate: DateTime(2027),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(primary: Colors.teal),
          ),
          child: child!,
        );
      },
    );

    if (nuevaFecha == null) return;

    final String nuevaFechaStr = "${nuevaFecha.day}/${nuevaFecha.month}/${nuevaFecha.year}";

    if (!mounted) return;
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) => const Center(child: CircularProgressIndicator(color: Colors.teal)),
    );

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('pagos')
          .where('fechaCita', isEqualTo: nuevaFechaStr)
          .get();

      final List<String> horasOcupadas = snapshot.docs.map((doc) {
        final data = doc.data();
        return (data['horaCita']?.toString() ?? '');
      }).where((hora) => hora.isNotEmpty).toList();

      if (!mounted) return;
      Navigator.pop(context); // Cierra el loading de forma segura

      await _mostrarSelectorHorarios(
        appointment: appointment,
        nuevaFechaStr: nuevaFechaStr,
        horasOcupadas: horasOcupadas,
      );

    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      debugPrint("Error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
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
              child: widget.appointments.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 32),
                      child: Center(
                        child: Text(
                          'No hay citas agendadas\npara esta fecha.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey),
                        ),
                      ),
                    )
                  : ListView.builder(
                      itemCount: widget.appointments.length,
                      itemBuilder: (context, index) {
                        final app = widget.appointments[index];
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
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                timeFormatted,
                                style: const TextStyle(color: Colors.teal, fontWeight: FontWeight.bold, fontSize: 12),
                              ),
                              const SizedBox(width: 4),
                              IconButton(
                                icon: const Icon(Icons.edit, color: Colors.grey, size: 18),
                                onPressed: () => _reprogramarCita(
                                  appointment: app,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}