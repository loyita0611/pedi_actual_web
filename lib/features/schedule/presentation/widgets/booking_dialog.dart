// lib/features/schedule/presentation/widgets/booking_dialog.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
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
  int _currentStep = 1; // 1: Datos Médicos, 2: Mostrar Datos Clínica + BCV, 3: Formulario "Pagado"
  final _formKey = GlobalKey<FormState>();
  final _paymentFormKey = GlobalKey<FormState>();
  bool _isSaving = false; // Variable de control para el estado de carga interno

  // --- CONTROLADORES ORIGINALES ---
  final _patientNameController = TextEditingController();
  final _addressController = TextEditingController();
  final _representativeNameController = TextEditingController();
  final _emailController = TextEditingController();
  
  // --- CONTROLADOR DE MOTIVO DE CONSULTA ---
  final _reasonController = TextEditingController(); 
  
  // --- CONTROLADORES DE PAGO ---
  String? _selectedOriginBank; 
  final _senderIdController = TextEditingController();   
  final _amountPaidController = TextEditingController(); 
  final _referenceController = TextEditingController();  

  DateTime? _selectedBirthDate;
  String _selectedPaymentMethod = 'Pago Móvil';
  
  // --- VARIABLES PARA LA PASARELA BCV ---
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
  }

  Future<void> _fetchBCVTasa() async {
    try {
      final response = await http.get(Uri.parse('https://ve.dolarapi.com/v1/dolares/oficial'))
          .timeout(const Duration(seconds: 5));
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
    _amountPaidController.dispose();
    _referenceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    String titleText = 'Nueva Cita Pediátrica - ${widget.timeString}';
    IconData headerIcon = Icons.child_care;

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
          Expanded(
            child: Text(
              titleText,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
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
                      Text(
                        "Procesando registro y enviando correo...", 
                        style: TextStyle(color: Colors.teal, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              )
            : SingleChildScrollView(
                child: _buildCurrentStepContent(),
              ),
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
          child: Text(
            _currentStep == 1 
                ? 'Continuar al Pago' 
                : _currentStep == 2 
                    ? 'Ya pagué' 
                    : 'Registrar Pago'
          ),
        ),
      ],
    );
  }

  Widget _buildCurrentStepContent() {
    switch (_currentStep) {
      case 1:
        return _buildMedicalForm();
      case 2:
        return _buildClinicPaymentInstructions();
      case 3:
        return _buildRegisterPaymentForm();
      default:
        return _buildMedicalForm();
    }
  }

  // --- PASO 1: FORMULARIO MÉDICO COMPLETO ---
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
          const SizedBox(height: 16),
          TextFormField(
            controller: _reasonController,
            maxLines: 3, 
            decoration: const InputDecoration(
              labelText: 'Motivo de la Consulta',
              alignLabelWithHint: true, 
              prefixIcon: Padding(
                padding: EdgeInsets.only(bottom: 40), 
                child: Icon(Icons.medical_information_outlined),
              ),
              border: OutlineInputBorder(),
            ),
            validator: (value) => value!.isEmpty ? 'Por favor ingresa el motivo de la consulta' : null,
          ),
        ],
      ),
    );
  }

  // --- PASO 2: SELECCIÓN DE MÉTODO Y DATOS ---
  Widget _buildClinicPaymentInstructions() {
    double totalEnBs = _montoUSD * _tasaBCV;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(),
        const SizedBox(height: 8),
        const Text('Selecciona tu método de pago:', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          initialValue: _selectedPaymentMethod,
          decoration: const InputDecoration(border: OutlineInputBorder()),
          items: ['Pago Móvil', 'Transferencia Bancaria'].map((method) {
            return DropdownMenuItem(value: method, child: Text(method));
          }).toList(),
          onChanged: (value) {
            setState(() { _selectedPaymentMethod = value!; });
          },
        ),
        const SizedBox(height: 20),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.teal.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.teal.withValues(alpha: 0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _selectedPaymentMethod == 'Pago Móvil' 
                    ? 'Datos para Realizar Pago Móvil:' 
                    : 'Datos para Transferencia Bancaria:',
                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.teal, fontSize: 14),
              ),
              const SizedBox(height: 10),
              if (_selectedPaymentMethod == 'Pago Móvil') ...[
                const Text('• Banco: BNC (0191)', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                const Text('• Teléfono Destino: 0412-5555555', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                const Text('• Cédula: V-12.345.678', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
              ] else ...[
                const Text('• Banco: BNC', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                const Text('• Cuenta Corriente:\n  0191-0000-0000-0000-0000', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                const Text('• Nombre: PediaActual C.A.', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                const Text('• RIF: J-55555555-0', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
              ],
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 10),
                child: Divider(color: Colors.teal, thickness: 0.5),
              ),
              _isLoadingTasa 
                ? const Center(child: Padding(
                    padding: EdgeInsets.all(8.0),
                    child: CircularProgressIndicator(color: Colors.teal),
                  ))
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Costo de consulta: \$$_montoUSD USD', style: const TextStyle(fontSize: 13, color: Colors.black54)),
                      Text('Tasa Oficial BCV: ${_tasaBCV.toStringAsFixed(2)} Bs.', style: const TextStyle(fontSize: 13, color: Colors.blueGrey, fontStyle: FontStyle.italic)),
                      const SizedBox(height: 6),
                      Text(
                        'TOTAL A PAGAR: ${totalEnBs.toStringAsFixed(2)} Bs.',
                        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.redAccent),
                      ),
                    ],
                  ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          '*Nota: Realice el pago desde su banco y luego presione el botón "Ya pagué".',
          style: TextStyle(color: Colors.grey, fontSize: 11, fontStyle: FontStyle.italic),
        ),
      ],
    );
  }

  // --- PASO 3: DETALLES DEL PAGO REALIZADO ---
  Widget _buildRegisterPaymentForm() {
    return Form(
      key: _paymentFormKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Divider(),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: _selectedOriginBank,
            decoration: const InputDecoration(
              labelText: 'Banco Emisor (Desde dónde pagó)',
              prefixIcon: Icon(Icons.account_balance_outlined),
              border: OutlineInputBorder(),
            ),
            items: _bancosVenezuela.map((banco) {
              return DropdownMenuItem<String>(
                value: banco,
                child: Text(banco),
              );
            }).toList(),
            onChanged: (value) {
              setState(() { _selectedOriginBank = value; });
            },
            validator: (value) => value == null ? 'Por favor selecciona el banco emisor' : null,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _senderIdController,
            decoration: const InputDecoration(
              labelText: 'Cédula de Identidad del Titular',
              prefixIcon: Icon(Icons.badge_outlined),
              border: OutlineInputBorder(),
            ),
            validator: (value) => value!.isEmpty ? 'Por favor ingresa la cédula' : null,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _amountPaidController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Monto Transferido (Bs.)',
              prefixIcon: Icon(Icons.monetization_on_outlined),
              border: OutlineInputBorder(),
            ),
            validator: (value) => value!.isEmpty ? 'Por favor ingresa el monto exacto' : null,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _referenceController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Número de Referencia Bancaria (Últimos 6 dígitos)',
              prefixIcon: Icon(Icons.numbers_outlined),
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

  // --- CONTROLADOR DE FLUJO ASÍNCRONO OPTIMIZADO Y CONFIGURADO ---
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

        final String correoPaciente = _emailController.text.trim();
        final String nombrePaciente = _patientNameController.text.trim();
        final String fechaCitaStr = "${widget.appointmentDateTime.day}/${widget.appointmentDateTime.month}/${widget.appointmentDateTime.year}";
        final String horaCitaStr = widget.timeString;
        const String numeroDoctora = "+58 412-5555555"; 

        try {
          // 1. Intentar guardar en Firestore con Timeout controlado
          DocumentReference docRef = await FirebaseFirestore.instance.collection('pagos').add({
            'nombrePaciente': nombrePaciente,
            'emailPaciente': correoPaciente,
            'fechaCita': fechaCitaStr,
            'horaCita': horaCitaStr,
            'telefonoDoctora': numeroDoctora,
            'bancoEmisor': _selectedOriginBank,
            'cedulaTitular': _senderIdController.text.trim(),
            'montoBs': _amountPaidController.text.trim(),
            'referencia': _referenceController.text.trim(),
            'metodoPago': _selectedPaymentMethod,
            'fechaRegistro': FieldValue.serverTimestamp(),
            'estado': 'pending',
          }).timeout(const Duration(seconds: 6));
          
          debugPrint("¡Respaldo de pago guardado en Firestore ID: ${docRef.id}!");

          // 2. Enviar correo usando tus IDs correctos de EmailJS 🚀
          final urlCorreo = Uri.parse('https://api.emailjs.com/api/v1.0/email/send');
          final response = await http.post(
            urlCorreo,
            headers: {'Content-Type': 'application/json'},
            body: json.encode({
              'service_id': 'service_vfquxn8',  // Integrado
              'template_id': 'template_brfi9f5', // Integrado
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
          } else {
            debugPrint("¡Correo enviado exitosamente al paciente!");
          }

          // 3. Éxito -> Confirmamos y cerramos la vista controladamente
          widget.onConfirmBooking(newAppointment);

          if (mounted) {
            Navigator.of(context).pop(); 
          }

        } catch (e) {
          debugPrint("🚨 Error detectado durante el agendamiento: $e");
          
          // Mantiene la vista abierta ante un fallo de red para que el usuario pueda reintentar sin perder sus datos
          if (mounted) {
            setState(() { _isSaving = false; });
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Hubo un problema de conexión: $e. Inténtalo de nuevo.'),
                backgroundColor: Colors.redAccent,
              ),
            );
          }
        }
      }
    }
  } 
}