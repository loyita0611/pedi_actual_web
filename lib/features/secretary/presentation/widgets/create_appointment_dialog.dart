import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';

class CreateAppointmentDialog extends StatefulWidget {
  const CreateAppointmentDialog({super.key});

  @override
  State<CreateAppointmentDialog> createState() => _CreateAppointmentDialogState();
}

class _CreateAppointmentDialogState extends State<CreateAppointmentDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _repNameController = TextEditingController();
  
  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = const TimeOfDay(hour: 9, minute: 0);
  
  String? _selectedPatientId;

  Future<List<Map<String, dynamic>>> _getPatientSuggestions(String query) async {
    if (query.isEmpty) return [];
    
    final snapshot = await FirebaseFirestore.instance
        .collection('patients')
        .where('patientName', isGreaterThanOrEqualTo: query)
        .where('patientName', isLessThanOrEqualTo: '$query\uf8ff')
        .get();
        
    return snapshot.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Row(
        children: [
          Icon(Icons.person_add_alt_1, color: Color(0xFF4594A4)),
          SizedBox(width: 8),
          Text('Agendar Cita Asistida'),
        ],
      ),
      content: SizedBox(
        width: 500,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TypeAheadField<Map<String, dynamic>>(
                suggestionsCallback: (pattern) => _getPatientSuggestions(pattern),
                builder: (context, controller, focusNode) {
                  if (controller.text != _nameController.text) {
                     controller.text = _nameController.text;
                  }
                  
                  return TextFormField(
                    controller: controller,
                    focusNode: focusNode,
                    decoration: InputDecoration(
                      labelText: 'Nombre del Paciente (Buscar o Crear)',
                      prefixIcon: const Icon(Icons.person),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onChanged: (val) {
                       _nameController.text = val;
                       _selectedPatientId = null;
                    },
                    validator: (value) => value == null || value.isEmpty ? 'Requerido' : null,
                  );
                },
                itemBuilder: (context, suggestion) {
                  return ListTile(
                    title: Text(suggestion['patientName'] ?? ''),
                    subtitle: Text('Rep: ${suggestion['representativeName'] ?? ''} - Tel: ${suggestion['phone'] ?? ''}'),
                  );
                },
                onSelected: (suggestion) {
                  setState(() {
                    _selectedPatientId = suggestion['id'];
                    _nameController.text = suggestion['patientName'] ?? '';
                    _phoneController.text = suggestion['phone'] ?? '';
                    _repNameController.text = suggestion['representativeName'] ?? '';
                  });
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _repNameController,
                decoration: InputDecoration(
                  labelText: 'Nombre del Representante',
                  prefixIcon: const Icon(Icons.family_restroom),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
                validator: (value) => value == null || value.isEmpty ? 'Requerido' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _phoneController,
                decoration: InputDecoration(
                  labelText: 'Teléfono de Contacto',
                  prefixIcon: const Icon(Icons.phone),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
                validator: (value) => value == null || value.isEmpty ? 'Requerido' : null,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.calendar_month),
                      label: Text('${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}'),
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _selectedDate,
                          firstDate: DateTime.now().subtract(const Duration(days: 1)),
                          lastDate: DateTime.now().add(const Duration(days: 365)),
                        );
                        if (picked != null) setState(() => _selectedDate = picked);
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.access_time),
                      label: Text(_selectedTime.format(context)),
                      onPressed: () async {
                        final picked = await showTimePicker(
                          context: context,
                          initialTime: _selectedTime,
                        );
                        if (picked != null) setState(() => _selectedTime = picked);
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF4594A4),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          onPressed: () async {
            if (_formKey.currentState!.validate()) {
              final appointmentDateTime = DateTime(
                _selectedDate.year,
                _selectedDate.month,
                _selectedDate.day,
                _selectedTime.hour,
                _selectedTime.minute,
              );

              String finalPatientId = _selectedPatientId ?? '';
              if (finalPatientId.isEmpty) {
                final newPatient = await FirebaseFirestore.instance.collection('patients').add({
                  'patientName': _nameController.text,
                  'representativeName': _repNameController.text,
                  'phone': _phoneController.text,
                  'createdAt': FieldValue.serverTimestamp(),
                });
                finalPatientId = newPatient.id;
              }

              await FirebaseFirestore.instance.collection('citas').add({
                'patientId': finalPatientId,
                'patientName': _nameController.text,
                'representativeName': _repNameController.text,
                'phone': _phoneController.text,
                'appointmentDateTime': Timestamp.fromDate(appointmentDateTime),
                'status': 'confirmed',
                'pagoEstado': 'Pendiente',
                'createdAt': FieldValue.serverTimestamp(),
              });

              if (context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cita agendada exitosamente')));
              }
            }
          },
          child: const Text('Confirmar y Reservar'),
        ),
      ],
    );
  }
}
