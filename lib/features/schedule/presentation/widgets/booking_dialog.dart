// lib/features/schedule/presentation/widgets/booking_dialog.dart
import 'package:flutter/material.dart';
import '../../domain/entities/appointment_entity.dart';

class BookingDialog extends StatefulWidget {
  final String timeString;
  final DateTime appointmentDateTime;
  final Function(AppointmentEntity) onConfirmBooking;

  const BookingDialog({
    super.key,
    required this.timeString,
    required this.appointmentDateTime,
    required this.onConfirmBooking,
  });

  @override
  State<BookingDialog> createState() => _BookingDialogState();
}

class _BookingDialogState extends State<BookingDialog> {
  int _currentStep = 1;
  final _formKey = GlobalKey<FormState>();
  final _paymentFormKey = GlobalKey<FormState>();

  final _patientNameController = TextEditingController();
  final _addressController = TextEditingController();
  final _representativeNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _referenceController = TextEditingController();
  final _phoneOrBankController = TextEditingController();

  DateTime? _selectedBirthDate;
  String _selectedPaymentMethod = 'Pago Móvil';

  @override
  void dispose() {
    _patientNameController.dispose();
    _addressController.dispose();
    _representativeNameController.dispose();
    _emailController.dispose();
    _referenceController.dispose();
    _phoneOrBankController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Icon(_currentStep == 1 ? Icons.child_care : Icons.payment, color: Colors.teal),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _currentStep == 1
                  ? 'Nueva Cita Pediátrica - ${widget.timeString}'
                  : 'Pasarela de Pago - Total: \$40',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 500,
        child: SingleChildScrollView(
          child: _currentStep == 1 ? _buildMedicalForm() : _buildPaymentForm(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            if (_currentStep == 2) {
              setState(() { _currentStep = 1; });
            } else {
              Navigator.pop(context);
            }
          },
          child: Text(_currentStep == 2 ? 'Atrás' : 'Cancelar', style: const TextStyle(color: Colors.grey)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
          onPressed: _handleNavigationAndSubmit,
          child: Text(_currentStep == 1 ? 'Continuar al Pago' : 'Confirmar y Pagar'),
        ),
      ],
    );
  }

  Widget _buildMedicalForm() {
    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Divider(),
          const SizedBox(height: 8),
          TextFormField(
            controller: _patientNameController,
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
                setState(() { _selectedBirthDate = picked; });
              }
            },
            child: InputDecorator(
              decoration: InputDecoration(
                labelText: 'Fecha de Nacimiento',
                prefixIcon: const Icon(Icons.cake_outlined, color: Colors.teal),
                border: const OutlineInputBorder(),
                errorText: _selectedBirthDate == null ? 'Selecciona la fecha' : null,
              ),
              child: Text(
                _selectedBirthDate == null
                    ? ''
                    : '${_selectedBirthDate!.day}/${_selectedBirthDate!.month}/${_selectedBirthDate!.year}',
              ),
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _addressController,
            decoration: const InputDecoration(
              labelText: 'Dirección de Habitación',
              prefixIcon: Icon(Icons.home_outlined),
              border: OutlineInputBorder(),
            ),
            validator: (value) => value!.isEmpty ? 'Por favor ingresa la dirección' : null,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _representativeNameController,
            decoration: const InputDecoration(
              labelText: 'Nombre y Apellido del Representante',
              prefixIcon: Icon(Icons.assignment_ind_outlined),
              border: OutlineInputBorder(),
            ),
            validator: (value) => value!.isEmpty ? 'Por favor ingresa el nombre del representante' : null,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _emailController,
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
    );
  }

  Widget _buildPaymentForm() {
    return Form(
      key: _paymentFormKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Selecciona tu método de pago:', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            //value: _selectedPaymentMethod,
            decoration: const InputDecoration(border: OutlineInputBorder()),
            items: ['Pago Móvil', 'Transferencia Bancaria'].map((method) {
              return DropdownMenuItem(value: method, child: Text(method));
            }).toList(),
            onChanged: (value) {
              setState(() { _selectedPaymentMethod = value!; });
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _phoneOrBankController,
            decoration: InputDecoration(
              labelText: _selectedPaymentMethod == 'Pago Móvil' ? 'Teléfono Emisor del Pago' : 'Banco de Origen',
              prefixIcon: Icon(_selectedPaymentMethod == 'Pago Móvil' ? Icons.phone : Icons.account_balance),
              border: const OutlineInputBorder(),
            ),
            validator: (value) => value!.isEmpty ? 'Campo requerido' : null,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _referenceController,
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
    );
  }

  void _handleNavigationAndSubmit() {
    if (_currentStep == 1) {
      if (_formKey.currentState!.validate() && _selectedBirthDate != null) {
        setState(() { _currentStep = 2; });
      }
    } else {
      if (_paymentFormKey.currentState!.validate()) {
        final newAppointment = AppointmentEntity(
          id: '',
          patientName: _patientNameController.text.trim(),
          patientBirthDate: _selectedBirthDate!,
          address: _addressController.text.trim(),
          representativeName: _representativeNameController.text.trim(),
          email: _emailController.text.trim(),
          appointmentDateTime: widget.appointmentDateTime,
          status: 'pending',
        );
        widget.onConfirmBooking(newAppointment);
        Navigator.pop(context);
      }
    }
  }
}