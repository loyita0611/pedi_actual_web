// lib/features/schedule/presentation/widgets/booking_dialog.dart
import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
  final _phoneController = TextEditingController(); // 🚀 AQUÍ VA EL CONTROLADOR DEL TELÉFONO
  final _reasonController = TextEditingController(); 
  
  String? _selectedOriginBank; 
  final _senderIdController = TextEditingController(); 
  final _pagoTelefonoController = TextEditingController(); 
  final _amountPaidController = TextEditingController(); 
  final _referenceController = TextEditingController();   

  DateTime? _selectedBirthDate;
  String _selectedPaymentMethod = 'Pago Móvil';
  
  double _tasaBCV = 0.0;
  bool _isLoadingTasa = true;
  final double _montoUSD = 40.0;

  String? _selectedPatientId;
  bool _isCreatingNewPatient = false;
  final String? userId = FirebaseAuth.instance.currentUser?.uid;

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

    _currentDateTime = widget.appointmentDateTime;
    _currentTimeString = widget.timeString;

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      if (currentUser.displayName != null && currentUser.displayName!.isNotEmpty) {
        _representativeNameController.text = currentUser.displayName!;
      }
      if (currentUser.email != null && currentUser.email!.isNotEmpty) {
        _emailController.text = currentUser.email!;
      }
    }

    if (widget.appointment != null && widget.appointment!.id.isNotEmpty) {
      _patientNameController.text = widget.appointment!.patientName;
      _addressController.text = widget.appointment!.address;
      _representativeNameController.text = widget.appointment!.representativeName;
      _emailController.text = widget.appointment!.email;
      _phoneController.text = widget.appointment!.phone; // 🚀 CARGAMOS EL TELÉFONO SI ES EDICIÓN
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
    _phoneController.dispose(); // 🚀 NO OLVIDAR DESHACERSE DEL CONTROLADOR
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
        ? 'Modificar Cita' 
        : 'Agendar Cita Pediátrica';
    IconData headerIcon = Icons.assignment_outlined;

    if (_currentStep == 2) {
      titleText = 'Pasarela de Pago - Total: \$$_montoUSD';
      headerIcon = Icons.payment;
    } else if (_currentStep == 3) {
      titleText = 'Registrar Pago';
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
                      Text("Procesando cita y verificando pago...", style: TextStyle(color: Colors.teal, fontWeight: FontWeight.bold)),
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
          child: Text(_currentStep == 1 ? 'Continuar al Pago' : _currentStep == 2 ? 'Ya pagué' : 'Confirmar Cita'),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Divider(),
          const SizedBox(height: 8),

          TextFormField(
            controller: _representativeNameController,
            decoration: const InputDecoration(
              labelText: 'Nombre y Apellido del Representante', 
              prefixIcon: Icon(Icons.assignment_ind_outlined), 
              border: OutlineInputBorder()
            ),
            validator: (value) => value!.isEmpty ? 'Requerido' : null,
          ),
          const SizedBox(height: 16),
          
          // 🚀 CAMPO DE TELÉFONO PARA EL REPRESENTANTE/CONTACTO
          TextFormField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: 'Teléfono de Contacto', 
              prefixIcon: Icon(Icons.phone), 
              border: OutlineInputBorder()
            ),
            validator: (value) => value!.isEmpty ? 'Requerido' : null,
          ),
          const SizedBox(height: 16),

          if (userId != null) ...[
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('patients')
                  .where('representativeId', isEqualTo: userId)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final patients = snapshot.data?.docs ?? [];
                
                if (patients.isEmpty && !_isCreatingNewPatient) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    setState(() => _isCreatingNewPatient = true);
                  });
                }

                return Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        isExpanded: true,
                        initialValue: _selectedPatientId,
                        decoration: const InputDecoration(
                          labelText: 'Seleccionar Niño/a',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.child_care, color: Colors.teal),
                        ),
                        hint: const Text('Elija un paciente registrado...'),
                        items: patients.map((doc) {
                          final data = doc.data() as Map<String, dynamic>;
                          return DropdownMenuItem(
                            value: doc.id,
                            child: Text(data['patientName'] ?? 'Sin nombre'),
                          );
                        }).toList(),
                        onChanged: _isCreatingNewPatient ? null : (value) {
                          setState(() {
                            _selectedPatientId = value;
                            final selectedDoc = patients.firstWhere((doc) => doc.id == value);
                            final data = selectedDoc.data() as Map<String, dynamic>;
                            
                            _patientNameController.text = data['patientName'] ?? '';
                            _addressController.text = data['address'] ?? '';
                            if (data['patientBirthDate'] != null) {
                              _selectedBirthDate = (data['patientBirthDate'] as Timestamp).toDate();
                            }
                            if (data['representativeName'] != null && data['representativeName'].toString().isNotEmpty) {
                              _representativeNameController.text = data['representativeName'];
                            }
                            if (data['email'] != null && data['email'].toString().isNotEmpty) {
                              _emailController.text = data['email'];
                            }
                            // 🚀 AUTOCOMPLETAMOS EL TELÉFONO
                            if (data['phone'] != null && data['phone'].toString().isNotEmpty) {
                              _phoneController.text = data['phone'];
                            }
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      tooltip: _isCreatingNewPatient ? 'Seleccionar existente' : 'Añadir nuevo hijo/a',
                      icon: Icon(_isCreatingNewPatient ? Icons.list : Icons.person_add, color: Colors.teal, size: 30),
                      onPressed: () {
                        setState(() {
                          _isCreatingNewPatient = !_isCreatingNewPatient;
                          if (_isCreatingNewPatient) {
                            _selectedPatientId = null;
                            _patientNameController.clear();
                            _addressController.clear();
                            _selectedBirthDate = null;
                          }
                        });
                      },
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 16),
          ],

          if (_isCreatingNewPatient) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(border: Border.all(color: Colors.teal.shade200), borderRadius: BorderRadius.circular(8), color: Colors.teal.shade50),
              child: Column(
                children: [
                  const Text('Datos del Nuevo Paciente', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.teal)),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _patientNameController,
                    decoration: const InputDecoration(labelText: 'Nombre y Apellido del Niño/a', prefixIcon: Icon(Icons.person_outline), border: OutlineInputBorder(), isDense: true),
                    validator: (value) => value!.isEmpty ? 'Requerido' : null,
                  ),
                  const SizedBox(height: 12),
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
                      decoration: InputDecoration(labelText: 'Fecha de Nacimiento', prefixIcon: const Icon(Icons.cake_outlined, color: Colors.teal), border: const OutlineInputBorder(), isDense: true, errorText: _selectedBirthDate == null ? 'Requerido' : null),
                      child: Text(_selectedBirthDate == null ? '' : '${_selectedBirthDate!.day}/${_selectedBirthDate!.month}/${_selectedBirthDate!.year}'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _addressController,
                    decoration: const InputDecoration(labelText: 'Dirección de Habitación', prefixIcon: Icon(Icons.home_outlined), border: OutlineInputBorder(), isDense: true),
                    validator: (value) => value!.isEmpty ? 'Requerido' : null,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          TextFormField(
            controller: _reasonController,
            maxLines: 2, 
            decoration: const InputDecoration(labelText: 'Motivo de la Consulta (Opcional)', border: OutlineInputBorder(), prefixIcon: Icon(Icons.medical_services_outlined)),
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
      if (!_isCreatingNewPatient && _selectedPatientId == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Por favor seleccione un paciente o cree uno nuevo.')));
        return;
      }
      if (_formKey.currentState!.validate() && _selectedBirthDate != null) {
        setState(() { _currentStep = 2; });
      } else if (_selectedBirthDate == null && _isCreatingNewPatient) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('La fecha de nacimiento es requerida')));
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
          phone: _phoneController.text.trim(), // 🚀 AQUÍ RESOLVEMOS EL ERROR 4
          appointmentDateTime: _currentDateTime, 
          status: 'pending',
          
          pagoReferencia: _referenceController.text.trim(),
          pagoMonto: double.tryParse(_amountPaidController.text.trim()) ?? 0.0,
          pagoBanco: _selectedOriginBank,
          pagoMetodo: _selectedPaymentMethod,
          pagoEstado: 'pending', 
          pagoCedula: _senderIdController.text.trim(),       
          pagoTelefono: _pagoTelefonoController.text.trim(), 
        );

        widget.onConfirmBooking(updatedAppointment);

        final String correoPaciente = _emailController.text.trim();
        final String nombrePaciente = _patientNameController.text.trim();
        final String fechaCitaStr = "${_currentDateTime.day}/${_currentDateTime.month}/${_currentDateTime.year}";
        final String horaCitaStr = _currentTimeString;
        const String numeroDoctora = "+58 412-5555555"; 

        try {
          final urlCorreo = Uri.parse('https://api.emailjs.com/api/v1.0/email/send');
          await http.post(
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

          if (mounted) Navigator.of(context).pop(); 
        } catch (e) {
          debugPrint("Error EmailJS: $e");
          if (mounted) Navigator.of(context).pop(); 
        }
      }
    }
  } 
}