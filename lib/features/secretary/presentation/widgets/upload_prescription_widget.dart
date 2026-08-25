import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_typeahead/flutter_typeahead.dart';

class UploadPrescriptionWidget extends StatefulWidget {
  const UploadPrescriptionWidget({super.key});

  @override
  State<UploadPrescriptionWidget> createState() => _UploadPrescriptionWidgetState();
}

class _UploadPrescriptionWidgetState extends State<UploadPrescriptionWidget> {
  bool _isUnlocked = false;
  bool _isSendingOtp = false;
  String _generatedOtp = '';
  final _otpController = TextEditingController();

  // Search Patient
  final _patientSearchController = TextEditingController();
  String? _selectedPatientId;
  String? _selectedPatientName;

  bool _isUploading = false;

  Future<void> _requestOtp() async {
    setState(() => _isSendingOtp = true);
    
    // Generate 6 digit PIN
    _generatedOtp = (Random().nextInt(900000) + 100000).toString();
    
    try {
      final urlCorreo = Uri.parse('https://api.emailjs.com/api/v1.0/email/send');
      await http.post(
        urlCorreo,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'service_id': 'service_vfquxn8',  
          'template_id': 'template_brfi9f5', // Usamos el template existente
          'user_id': 'wC6RQuuJG9ZfdQxp9',
          'template_params': {
            'to_email': 'secretaria.pediaactual@gmail.com', // Correo destino de prueba o de admin
            'patient_name': 'Secretaría (OTP: $_generatedOtp)',
            'appointment_date': 'Autorización de Recetas',
            'appointment_time': 'Requerida',
            'doctor_phone': 'No comparta este PIN: $_generatedOtp',
          }
        }),
      ).timeout(const Duration(seconds: 10));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('PIN enviado al correo administrativo.')));
      }
    } catch (e) {
      debugPrint("Error EmailJS: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error al enviar PIN.')));
      }
    } finally {
      if (mounted) {
        setState(() => _isSendingOtp = false);
      }
    }
  }

  void _verifyOtp() {
    if (_otpController.text.trim() == _generatedOtp && _generatedOtp.isNotEmpty) {
      setState(() => _isUnlocked = true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('PIN Incorrecto')));
    }
  }

  Future<List<Map<String, dynamic>>> _getPatientSuggestions(String query) async {
    if (query.isEmpty) return [];
    final snapshot = await FirebaseFirestore.instance
        .collection('patients')
        .where('patientName', isGreaterThanOrEqualTo: query)
        .where('patientName', isLessThanOrEqualTo: '$query\uf8ff')
        .get();
    return snapshot.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList();
  }

  Future<void> _pickAndUploadFile() async {
    if (_selectedPatientId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Seleccione un paciente primero')));
      return;
    }

    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'png', 'jpeg'],
    );

    if (result.isNotEmpty) {
      final platformFile = result.first;
      final fileName = platformFile.name;

      setState(() => _isUploading = true);
      try {
        // Use readAsBytes() — the v12 replacement for the deprecated .bytes + withData
        final fileBytes = await platformFile.readAsBytes();

        final storageRef = FirebaseStorage.instance.ref()
            .child('prescriptions/$_selectedPatientId/${DateTime.now().millisecondsSinceEpoch}_$fileName');

        final uploadTask = storageRef.putData(fileBytes);
        final snap = await uploadTask;
        final downloadUrl = await snap.ref.getDownloadURL();

        await FirebaseFirestore.instance.collection('prescriptions').add({
          'patientId': _selectedPatientId,
          'patientName': _selectedPatientName,
          'fileName': fileName,
          'fileUrl': downloadUrl,
          'createdAt': FieldValue.serverTimestamp(),
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Documento subido con éxito')));
        }
      } catch (e) {
        debugPrint('Error uploading file: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error al subir documento')));
        }
      } finally {
        if (mounted) {
          setState(() => _isUploading = false);
        }
      }
    }
  }
  
  Future<void> _deletePrescription(String docId, String fileUrl) async {
    try {
      await FirebaseStorage.instance.refFromURL(fileUrl).delete();
      await FirebaseFirestore.instance.collection('prescriptions').doc(docId).delete();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Documento eliminado')));
      }
    } catch (e) {
      debugPrint('Error deleting file: $e');
    }
  }

  Widget _buildLockedScreen() {
    return Center(
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.security, size: 80, color: Color(0xFF4594A4)),
                const SizedBox(height: 24),
                const Text('Área Segura de Recetas y Documentos', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                const SizedBox(height: 16),
                const Text('Para acceder a esta sección, requiere validación por PIN de 6 dígitos que será enviado al correo administrativo.', textAlign: TextAlign.center),
                const SizedBox(height: 24),
                if (_generatedOtp.isEmpty)
                  ElevatedButton.icon(
                    icon: _isSendingOtp ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.email),
                    label: Text(_isSendingOtp ? 'Enviando...' : 'Solicitar PIN'),
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4594A4), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12)),
                    onPressed: _isSendingOtp ? null : _requestOtp,
                  )
                else ...[
                  TextField(
                    controller: _otpController,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    decoration: const InputDecoration(
                      labelText: 'Ingrese el PIN recibido',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.lock),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _verifyOtp,
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4594A4), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12)),
                    child: const Text('Verificar y Desbloquear'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildUnlockedScreen() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Gestión de Recetas y Documentos', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF4594A4))),
        const SizedBox(height: 8),
        const Text('Busque un paciente para visualizar y subir sus récipes o estudios médicos.'),
        const SizedBox(height: 24),
        TypeAheadField<Map<String, dynamic>>(
          suggestionsCallback: (pattern) => _getPatientSuggestions(pattern),
          builder: (context, controller, focusNode) {
            return TextField(
              controller: controller,
              focusNode: focusNode,
              decoration: InputDecoration(
                labelText: 'Buscar Paciente',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            );
          },
          itemBuilder: (context, suggestion) {
            return ListTile(title: Text(suggestion['patientName'] ?? ''), subtitle: Text('Rep: ${suggestion['representativeName'] ?? ''}'));
          },
          onSelected: (suggestion) {
            setState(() {
              _selectedPatientId = suggestion['id'];
              _selectedPatientName = suggestion['patientName'];
              _patientSearchController.text = _selectedPatientName ?? '';
            });
          },
        ),
        const SizedBox(height: 24),
        if (_selectedPatientId != null) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Archivos de $_selectedPatientName', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ElevatedButton.icon(
                icon: _isUploading ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.upload_file),
                label: Text(_isUploading ? 'Subiendo...' : 'Subir Documento'),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4594A4), foregroundColor: Colors.white),
                onPressed: _isUploading ? null : _pickAndUploadFile,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('prescriptions').where('patientId', isEqualTo: _selectedPatientId).orderBy('createdAt', descending: true).snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const Center(child: Text('No hay documentos subidos para este paciente.'));
                
                final docs = snapshot.data!.docs;
                return ListView.builder(
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final data = docs[index].data() as Map<String, dynamic>;
                    return Card(
                      child: ListTile(
                        leading: const Icon(Icons.picture_as_pdf, color: Colors.redAccent),
                        title: Text(data['fileName'] ?? 'Documento'),
                        subtitle: Text(data['createdAt'] != null ? (data['createdAt'] as Timestamp).toDate().toString().substring(0, 16) : ''),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () => _deletePrescription(docs[index].id, data['fileUrl']),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          )
        ] else
          const Expanded(child: Center(child: Text('Busque y seleccione un paciente para ver sus documentos', style: TextStyle(color: Colors.grey, fontSize: 16)))),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return _isUnlocked ? _buildUnlockedScreen() : _buildLockedScreen();
  }
}
