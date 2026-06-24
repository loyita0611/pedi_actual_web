// lib/features/schedule/presentation/widgets/booking_dialog.dart
import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../domain/entities/appointment_entity.dart';

class BookingDialog extends StatefulWidget {
  final AppointmentEntity? appointment; 
  final String timeString;
  final DateTime appointmentDateTime;
  final Function(AppointmentEntity) onConfirmBooking;

  const BookingDialog({
    super.key,
    this.appointment, 
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
  bool _isSaving = false; 

  late DateTime _currentDateTime;
  late String _currentTimeString;

  final _patientNameController = TextEditingController();
  final _addressController = TextEditingController();
  final _representativeNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _reasonController = TextEditingController(); 
  
  String? _selectedOriginBank; 
  final _senderIdController = TextEditingController(); // Usado para Cédula
  final _pagoTelefonoController = TextEditingController(); // Controlador para teléfono del pago
  final _amountPaidController = TextEditingController(); 
  final _referenceController = TextEditingController();   

  DateTime? _selectedBirthDate;
  String _selectedPaymentMethod = 'Pago Móvil';
  
  double _tasaBCV = 0.0;
  bool _isLoadingTasa = true;
  final double _montoUSD = 40.0;

  final List<String> _bancosVenezuela = [
    'Banco de Venezuela',
    'Banesco',
    'Mercantil',
    'Provincial',
    'BNC',
    'Bancamiga',
    'Banplus',
    'Banco Nacional de Crédito',
    'BFC Banco Fondo Común',
  ];

  @override
  void initState() {
    super.initState();
    _fetchBCVTasa();

    // Se mantiene fijo el horario seleccionado en la cuadrícula
    _currentDateTime = widget.appointmentDateTime;
    _currentTimeString = widget.timeString;

    if (widget.appointment != null && widget.appointment!.id.isNotEmpty) {
      _patientNameController.text = widget.appointment!.patientName;
      _addressController.text = widget.appointment!.address;
      _representativeNameController.text = widget.appointment!.representativeName;
      _emailController.text = widget.appointment!.email;
      _selectedBirthDate = widget.appointment!.patientBirthDate;
      _currentDateTime = widget.appointment!.appointmentDateTime;

      _referenceController.text = widget.appointment!.pagoReferencia ?? '';
      _selectedOriginBank = widget.appointment!.pagoBanco;
      _senderIdController.text = widget.appointment!.pagoCedula ?? '';      
      _pagoTelefonoController.text = widget.appointment!.pagoTelefono ?? '';  
      if (widget.appointment!.pagoMonto != null) {
        _amountPaidController.text = widget.appointment!.pagoMonto.toString();
      }
    }
  }

  Future<void> _fetchBCVTasa() async {
    try {
      final response = await http.get(Uri.parse('https://ve.dolarapi.com/v1/dolares/oficial')).timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _tasaBCV = (data['promedio'] as num).toDouble();
          _isLoadingTasa = false;
        });
      }
    } catch (e) {
      debugPrint("Error consultando DolarApi: $e");
      setState(() => _isLoadingTasa = false);
    }
  }

  @override
  void dispose() {
    _patientNameController.dispose();
    _addressController.dispose();
    _representativeNameController.dispose();
    _emailController.dispose();
    _reasonController.dispose(); 
    _senderIdController.dispose();
    _pagoTelefonoController.dispose(); 
    _amountPaidController.dispose();
    _referenceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
   
    String titleText = widget.appointment != null && widget.appointment!.id.isNotEmpty 
        ? 'Modificar formulario para la cita médica' 
        : 'Llenar formulario para la cita pediatríca';
    IconData headerIcon = Icons.assignment_outlined;

    if (_currentStep == 2) {
      titleText = 'Pasarela de Pago - Total: \$$_montoUSD';
      headerIcon = Icons.payment;
    } else if (_currentStep == 3) {
      titleText = 'Detalles del Pago Realizado';
      headerIcon = Icons.account_balance_wallet_outlined;
    }

    return AlertDialog(
      title: Row(
        children: [
          Icon(headerIcon, color: Colors.teal),
          const SizedBox(width: 8),
          Expanded(child: Text(titleText, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
        ],
      ),
      content: SizedBox(
        width: 500,
        child: _isSaving 
            ? const SizedBox(
                height: 200,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(color: Colors.teal),
                      SizedBox(height: 16),
                      Text("Procesando cambios en el servidor...", style: TextStyle(color: Colors.teal, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              )
            : SingleChildScrollView(child: _buildCurrentStepContent()),
      ),
      actions: _isSaving ? [] : [
        TextButton(
          onPressed: () {
            if (_currentStep > 1) {
              setState(() { _currentStep--; });
            } else {
              Navigator.pop(context);
            }
          },
          child: Text(_currentStep == 1 ? 'Cancelar' : 'Atrás', style: const TextStyle(color: Colors.grey)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
          onPressed: _handleNavigationAndSubmit,
          child: Text(_currentStep == 1 ? 'Continuar al Pago' : _currentStep == 2 ? 'Ya pagué' : 'Confirmar Cambios'),
        ),
      ],
    );
  }

  Widget _buildCurrentStepContent() {
    switch (_currentStep) {
      case 1: return _buildMedicalForm();
      case 2: return _buildClinicPaymentInstructions();
      case 3: return _buildRegisterPaymentForm();
      default: return _buildMedicalForm();
    }
  }

  Widget _buildMedicalForm() {
    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Divider(),
          const SizedBox(height: 8),
          
          // 🚀 SE ELIMINÓ EL DROPDOWN DE SELECCIÓN DE HORA DE AQUÍ

          TextFormField(
            controller: _patientNameController,
            decoration: const InputDecoration(labelText: 'Nombre y Apellido del Paciente (Niño/a)', prefixIcon: Icon(Icons.person_outline), border: OutlineInputBorder()),
            validator: (value) => value!.isEmpty ? 'Por favor ingresa el nombre del niño' : null,
          ),
          const SizedBox(height: 16),
          InkWell(
            onTap: () async {
              final DateTime? picked = await showDatePicker(
                context: context,
                initialDate: _selectedBirthDate ?? DateTime.now().subtract(const Duration(days: 365)),
                firstDate: DateTime(2010),
                lastDate: DateTime.now(),
              );
              if (picked != null) setState(() { _selectedBirthDate = picked; });
            },
            child: InputDecorator(
              decoration: InputDecoration(labelText: 'Fecha de Nacimiento', prefixIcon: const Icon(Icons.cake_outlined, color: Colors.teal), border: const OutlineInputBorder(), errorText: _selectedBirthDate == null ? 'Selecciona la fecha' : null),
              child: Text(_selectedBirthDate == null ? '' : '${_selectedBirthDate!.day}/${_selectedBirthDate!.month}/${_selectedBirthDate!.year}'),
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _addressController,
            decoration: const InputDecoration(labelText: 'Dirección de Habitación', prefixIcon: Icon(Icons.home_outlined), border: OutlineInputBorder()),
            validator: (value) => value!.isEmpty ? 'Por favor ingresa la dirección' : null,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _representativeNameController,
            decoration: const InputDecoration(labelText: 'Nombre y Apellido del Representante', prefixIcon: Icon(Icons.assignment_ind_outlined), border: OutlineInputBorder()),
            validator: (value) => value!.isEmpty ? 'Por favor ingresa el nombre del representante' : null,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(labelText: 'Correo Electrónico', prefixIcon: Icon(Icons.email_outlined), border: OutlineInputBorder()),
            validator: (value) {
              if (value!.isEmpty) return 'Por favor ingresa el correo';
              if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                return 'Ingresa un correo electrónico válido';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _reasonController,
            maxLines: 2, 
            decoration: const InputDecoration(labelText: 'Motivo de la Consulta', border: OutlineInputBorder()),
          ),
        ],
      ),
    );
  }

  Widget _buildClinicPaymentInstructions() {
    double totalEnBs = _montoUSD * _tasaBCV;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(),
        const SizedBox(height: 8),
        const Text('Método de pago:', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          initialValue: _selectedPaymentMethod,
          decoration: const InputDecoration(border: OutlineInputBorder()),
          items: ['Pago Móvil', 'Transferencia Bancaria'].map((method) => DropdownMenuItem(value: method, child: Text(method))).toList(),
          onChanged: (value) => setState(() { _selectedPaymentMethod = value!; }),
        ),
        const SizedBox(height: 20),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: Colors.teal.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.teal.withValues(alpha: 0.3))),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_selectedPaymentMethod == 'Pago Móvil' ? 'Datos para Realizar Pago Móvil:' : 'Datos para Transferencia Bancaria:', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.teal)),
              const SizedBox(height: 6),
              if (_selectedPaymentMethod == 'Pago Móvil') ...[
                const Text('• Banco: BNC (0191)\n• Teléfono: 0412-5555555\n• Cédula: V-12.345.678'),
              ] else ...[
                const Text('• Banco: BNC\n• Cuenta: 0191-0000-0000-0000-0000\n• RIF: J-55555555-0'),
              ],
              const Divider(color: Colors.teal),
              _isLoadingTasa 
                ? const Center(child: CircularProgressIndicator(color: Colors.teal))
                : Text('TOTAL A PAGAR: ${totalEnBs.toStringAsFixed(2)} Bs.', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.redAccent)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRegisterPaymentForm() {
    return Form(
      key: _paymentFormKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Divider(),
          DropdownButtonFormField<String>(
            initialValue: _selectedOriginBank,
            decoration: const InputDecoration(labelText: 'Banco Emisor', border: OutlineInputBorder()),
            items: _bancosVenezuela.map((banco) => DropdownMenuItem(value: banco, child: Text(banco))).toList(),
            onChanged: (value) => setState(() { _selectedOriginBank = value; }),
            validator: (value) => value == null ? 'Selecciona el banco' : null,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _referenceController,
            decoration: const InputDecoration(labelText: 'Referencia Bancaria (Últimos 6 dígitos)', border: OutlineInputBorder()),
            validator: (value) => value!.isEmpty ? 'Ingresa la referencia' : null,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _senderIdController,
            decoration: const InputDecoration(labelText: 'Cédula del Titular de la Cuenta', border: OutlineInputBorder()),
            validator: (value) => value!.isEmpty ? 'Ingresa la cédula' : null,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _pagoTelefonoController,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(labelText: 'Número de Teléfono del Pago', border: OutlineInputBorder()),
            validator: (value) => value!.isEmpty ? 'Ingresa el número de teléfono' : null,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _amountPaidController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Monto Transferido (Bs.)', border: OutlineInputBorder()),
            validator: (value) => value!.isEmpty ? 'Ingresa el monto' : null,
          ),
        ],
      ),
    );
  }

  void _handleNavigationAndSubmit() async {
    if (_currentStep == 1) {
      if (_formKey.currentState!.validate() && _selectedBirthDate != null) {
        setState(() { _currentStep = 2; });
      }
    } else if (_currentStep == 2) {
      setState(() { _currentStep = 3; });
    } else {
      if (_paymentFormKey.currentState!.validate()) {
        setState(() { _isSaving = true; }); 

        final updatedAppointment = AppointmentEntity(
          id: widget.appointment?.id ?? '', 
          patientName: _patientNameController.text.trim(),
          patientBirthDate: _selectedBirthDate!,
          address: _addressController.text.trim(),
          representativeName: _representativeNameController.text.trim(),
          email: _emailController.text.trim(),
          appointmentDateTime: _currentDateTime, 
          status: 'pending',
          
          pagoReferencia: _referenceController.text.trim(),
          pagoMonto: double.tryParse(_amountPaidController.text.trim()) ?? 0.0,
          pagoBanco: _selectedOriginBank,
          pagoMetodo: _selectedPaymentMethod,
          pagoEstado: 'pendiente_verificacion',
          pagoCedula: _senderIdController.text.trim(),       
          pagoTelefono: _pagoTelefonoController.text.trim(), 
        );

        final String correoPaciente = _emailController.text.trim();
        final String nombrePaciente = _patientNameController.text.trim();
        final String fechaCitaStr = "${_currentDateTime.day}/${_currentDateTime.month}/${_currentDateTime.year}";
        final String horaCitaStr = _currentTimeString;
        const String numeroDoctora = "+58 412-5555555"; 

        try {
          widget.onConfirmBooking(updatedAppointment);

          final urlCorreo = Uri.parse('https://api.emailjs.com/api/v1.0/email/send');
          final response = await http.post(
            urlCorreo,
            headers: {'Content-Type': 'application/json'},
            body: json.encode({
              'service_id': 'service_vfquxn8',  
              'template_id': 'template_brfi9f5', 
              'user_id': 'wC6RQuuJG9ZfdQxp9',
              'template_params': {
                'to_email': correoPaciente,
                'patient_name': nombrePaciente,
                'appointment_date': fechaCitaStr,
                'appointment_time': horaCitaStr,
                'doctor_phone': numeroDoctora,
              }
            }),
          ).timeout(const Duration(seconds: 5));

          if (response.statusCode != 200) {
            debugPrint("⚠️ EmailJS devolvió una respuesta no exitosa: ${response.body}");
          }

          if (mounted) {
            Navigator.of(context).pop(); 
          }

        } catch (e) {
          if (mounted) {
            setState(() { _isSaving = false; });
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.redAccent));
          }
        }
      }
    }
  } 
}