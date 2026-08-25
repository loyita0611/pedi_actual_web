import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class PatientDirectoryWidget extends StatefulWidget {
  const PatientDirectoryWidget({super.key});

  @override
  State<PatientDirectoryWidget> createState() => _PatientDirectoryWidgetState();
}

class _PatientDirectoryWidgetState extends State<PatientDirectoryWidget> {
  String _searchQuery = '';

  void _showNewPatientDialog(BuildContext context) {
    final repController = TextEditingController();
    final idController = TextEditingController();
    final emailController = TextEditingController();
    final phoneController = TextEditingController();
    final patientController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Nuevo Paciente'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: patientController, decoration: const InputDecoration(labelText: 'Nombre del Paciente')),
              TextField(controller: repController, decoration: const InputDecoration(labelText: 'Nombre del Representante')),
              TextField(controller: idController, decoration: const InputDecoration(labelText: 'Cédula del Representante')),
              TextField(controller: emailController, decoration: const InputDecoration(labelText: 'Correo Electrónico')),
              TextField(controller: phoneController, decoration: const InputDecoration(labelText: 'Teléfono / Celular')),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () async {
              await FirebaseFirestore.instance.collection('patients').add({
                'patientName': patientController.text,
                'representativeName': repController.text,
                'idDocument': idController.text,
                'email': emailController.text,
                'phone': phoneController.text,
                'createdAt': FieldValue.serverTimestamp(),
              });
              if (!context.mounted) return;
              Navigator.pop(context);
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  void _showPatientHistory(BuildContext context, String patientId, String patientName) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.85,
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Historial Clínico y de Pagos: $patientName', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF4594A4))),
            const Divider(),
            const SizedBox(height: 16),
            const Text('Línea de Tiempo', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Expanded(
              child: FutureBuilder<List<dynamic>>(
                future: Future.wait([
                  FirebaseFirestore.instance.collection('citas').where('patientName', isEqualTo: patientName).get(),
                  FirebaseFirestore.instance.collection('pagos').where('patientName', isEqualTo: patientName).get(),
                ]),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                  if (snapshot.hasError) return const Center(child: Text('Error al cargar historial.'));
                  
                  final citasDocs = (snapshot.data![0] as QuerySnapshot).docs;
                  final pagosDocs = (snapshot.data![1] as QuerySnapshot).docs;
                  
                  if (citasDocs.isEmpty && pagosDocs.isEmpty) {
                    return const Center(child: Text('No hay historial de citas ni pagos para este paciente.'));
                  }

                  // Unificar todo en una lista de mapas para el timeline
                  List<Map<String, dynamic>> timelineEvents = [];
                  
                  for (var doc in citasDocs) {
                    final data = doc.data() as Map<String, dynamic>;
                    timelineEvents.add({
                      'type': 'cita',
                      'date': (data['appointmentDateTime'] as Timestamp?)?.toDate() ?? DateTime.now(),
                      'data': data,
                    });
                  }
                  
                  for (var doc in pagosDocs) {
                    final data = doc.data() as Map<String, dynamic>;
                    timelineEvents.add({
                      'type': 'pago',
                      'date': (data['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
                      'data': data,
                    });
                  }
                  
                  // Ordenar descendente (más reciente primero)
                  timelineEvents.sort((a, b) => (b['date'] as DateTime).compareTo(a['date'] as DateTime));

                  return ListView.builder(
                    itemCount: timelineEvents.length,
                    itemBuilder: (context, index) {
                      final event = timelineEvents[index];
                      final isCita = event['type'] == 'cita';
                      final data = event['data'];
                      final date = event['date'] as DateTime;
                      final dateStr = DateFormat('dd/MM/yyyy hh:mm a').format(date);
                      
                      Color iconColor = isCita ? Colors.blue : Colors.green;
                      IconData iconData = isCita ? Icons.medical_services : Icons.attach_money;
                      
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16.0),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Column(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(color: iconColor.withValues(alpha: 0.1), shape: BoxShape.circle),
                                  child: Icon(iconData, color: iconColor, size: 20),
                                ),
                                if (index != timelineEvents.length - 1)
                                  Container(width: 2, height: 60, color: Colors.grey.shade300),
                              ],
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Card(
                                elevation: 0,
                                color: Colors.grey.shade50,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  side: BorderSide(color: Colors.grey.shade200),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(12.0),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(dateStr, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)),
                                      const SizedBox(height: 6),
                                      if (isCita) ...[
                                        Text('Cita Médica — Estado: ${data['status']}'),
                                        Text('Pago Asociado: ${data['pagoEstado'] ?? 'Pendiente'}', style: const TextStyle(fontSize: 12, color: Colors.black54)),
                                      ] else ...[
                                        Text('Registro de Pago — Banco: ${data['pagoBanco']}'),
                                        Text('Monto: ${data['pagoMonto']} Bs. | Ref: ${data['pagoReferencia'] ?? 'N/A'}', style: const TextStyle(fontSize: 12, color: Colors.black54)),
                                        Text('Estado del pago: ${data['status']}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: data['status'] == 'approved' ? Colors.green : Colors.orange)),
                                      ]
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Directorio de Pacientes', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF4594A4))),
              ElevatedButton.icon(
                icon: const Icon(Icons.add),
                label: const Text('Nuevo Paciente'),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4594A4), foregroundColor: Colors.white),
                onPressed: () => _showNewPatientDialog(context),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: TextField(
            decoration: InputDecoration(
              labelText: 'Buscar paciente por nombre...',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onChanged: (val) {
              setState(() {
                _searchQuery = val.toLowerCase();
              });
            },
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('patients').orderBy('patientName').snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const Center(child: Text('No hay pacientes registrados.'));
              
              var docs = snapshot.data!.docs;
              if (_searchQuery.isNotEmpty) {
                docs = docs.where((doc) {
                  final name = ((doc.data() as Map<String, dynamic>)['patientName'] ?? '').toString().toLowerCase();
                  return name.contains(_searchQuery);
                }).toList();
              }

              return ListView.builder(
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  final data = docs[index].data() as Map<String, dynamic>;
                  return Card(
                    elevation: 1,
                    margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: const Color(0xFF4594A4).withValues(alpha: 0.1),
                        child: const Icon(Icons.person, color: Color(0xFF4594A4)),
                      ),
                      title: Text(data['patientName'] ?? 'Sin nombre', style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text('Representante: ${data['representativeName'] ?? 'N/A'} | Cel: ${data['phone'] ?? 'N/A'}'),
                      trailing: ElevatedButton.icon(
                        icon: const Icon(Icons.history, size: 18),
                        label: const Text('Historial Clínico'),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: const Color(0xFF4594A4)),
                        onPressed: () => _showPatientHistory(context, docs[index].id, data['patientName'] ?? ''),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
