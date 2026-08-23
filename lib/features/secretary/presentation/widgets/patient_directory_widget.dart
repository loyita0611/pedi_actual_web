import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class PatientDirectoryWidget extends StatelessWidget {
  const PatientDirectoryWidget({super.key});

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
              TextField(controller: repController, decoration: const InputDecoration(labelText: 'Nombre Representante')),
              TextField(controller: idController, decoration: const InputDecoration(labelText: 'Cédula')),
              TextField(controller: emailController, decoration: const InputDecoration(labelText: 'Correo')),
              TextField(controller: phoneController, decoration: const InputDecoration(labelText: 'Teléfono')),
              TextField(controller: patientController, decoration: const InputDecoration(labelText: 'Nombre del Paciente')),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () async {
              await FirebaseFirestore.instance.collection('patients').add({
                'representativeName': repController.text,
                'idDocument': idController.text,
                'email': emailController.text,
                'phone': phoneController.text,
                'patientName': patientController.text,
                'createdAt': FieldValue.serverTimestamp(),
              });
              if (!context.mounted) return;
Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text('Guardar'),
          ),
        ],
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
              const Text('Directorio de Pacientes', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              ElevatedButton.icon(
                icon: const Icon(Icons.add),
                label: const Text('Nuevo Paciente'),
                onPressed: () => _showNewPatientDialog(context),
              ),
            ],
          ),
        ),
        // 5. AUTOCOMPLETE PARA BUSCAR PACIENTES AL AGENDAR (Puedes mover esto a tu diálogo de citas)
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Autocomplete<Map<String, dynamic>>(
            optionsBuilder: (TextEditingValue textEditingValue) async {
              if (textEditingValue.text.isEmpty) return const Iterable<Map<String, dynamic>>.empty();
              final snapshot = await FirebaseFirestore.instance
                  .collection('patients')
                  .where('patientName', isGreaterThanOrEqualTo: textEditingValue.text)
                  .where('patientName', isLessThanOrEqualTo: '${textEditingValue.text}\uf8ff')
                  .get();
              return snapshot.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList();
            },
            displayStringForOption: (option) => option['patientName'] ?? '',
            fieldViewBuilder: (context, controller, focusNode, onEditingComplete) {
              return TextField(
                controller: controller,
                focusNode: focusNode,
                decoration: const InputDecoration(
                  labelText: 'Buscar paciente para nueva cita...',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.search),
                ),
              );
            },
            onSelected: (selection) {
              // Lógica al seleccionar el paciente para la cita
              debugPrint('Paciente seleccionado ID: ${selection['id']}');
            },
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('patients').orderBy('patientName').snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
              return ListView.builder(
                itemCount: snapshot.data!.docs.length,
                itemBuilder: (context, index) {
                  final data = snapshot.data!.docs[index].data() as Map<String, dynamic>;
                  return Card(
                    child: ListTile(
                      title: Text(data['patientName'] ?? 'Sin nombre'),
                      subtitle: Text('Rep: ${data['representativeName']} | Cel: ${data['phone']}'),
                      trailing: ElevatedButton(
                        child: const Text('Historial Clínico'),
                        onPressed: () {
                          // Aquí llamas a getPatientHistoryStats() detallado en la respuesta anterior
                        },
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