import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class UploadPrescriptionWidget extends StatefulWidget {
  const UploadPrescriptionWidget({super.key});

  @override
  State<UploadPrescriptionWidget> createState() =>
      _UploadPrescriptionWidgetState();
}

class _UploadPrescriptionWidgetState extends State<UploadPrescriptionWidget> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Recetas y Documentos por Paciente',
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF4594A4)),
            ),
            const SizedBox(height: 8),
            const Text(
              'Selecciona un paciente para subir o consultar recetas y documentos médicos.',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 16),
            TextField(
              onChanged: (value) {
                setState(() {
                  _searchQuery = value.toLowerCase();
                });
              },
              decoration: InputDecoration(
                hintText: 'Buscar paciente por nombre...',
                prefixIcon: const Icon(Icons.search),
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                filled: true,
                fillColor: Colors.grey.shade100,
              ),
            ),
            const SizedBox(height: 24),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('users')
                    .where('role', isEqualTo: 'patient')
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (snapshot.hasError) {
                    return const Center(
                        child: Text('Error al cargar pacientes.'));
                  }

                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.people_outline,
                              size: 64, color: Colors.grey),
                          SizedBox(height: 16),
                          Text('No hay pacientes registrados.',
                              style:
                                  TextStyle(fontSize: 16, color: Colors.grey)),
                        ],
                      ),
                    );
                  }

                  final docs = snapshot.data!.docs;

                  final filteredDocs = docs.where((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    final name =
                        (data['name'] ?? '').toString().toLowerCase();
                    return name.contains(_searchQuery);
                  }).toList();

                  if (filteredDocs.isEmpty) {
                    return const Center(
                        child: Text('No se encontraron pacientes.'));
                  }

                  return ListView.separated(
                    itemCount: filteredDocs.length,
                    separatorBuilder: (_, __) => const Divider(),
                    itemBuilder: (context, index) {
                      final data = filteredDocs[index].data()
                          as Map<String, dynamic>;
                      final patientId = filteredDocs[index].id;
                      final name = data['name'] ?? 'Desconocido';
                      final email = data['email'] ?? '';

                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor:
                              const Color(0xFFEAA171).withValues(alpha: 0.2),
                          child: Text(
                            name.toString().isNotEmpty
                                ? name.toString()[0].toUpperCase()
                                : '?',
                            style: const TextStyle(
                                color: Color(0xFFEAA171),
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                        title: Text(name,
                            style:
                                const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(email),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Ver recetas existentes
                            IconButton(
                              icon: const Icon(Icons.folder_open,
                                  color: Color(0xFF4594A4)),
                              tooltip: 'Ver recetas',
                              onPressed: () {
                                _showPatientPrescriptions(
                                    context, patientId, name);
                              },
                            ),
                            // Subir nueva receta
                            IconButton(
                              icon: const Icon(Icons.upload_file,
                                  color: Color(0xFFEAA171)),
                              tooltip: 'Subir receta',
                              onPressed: () {
                                _showUploadDialog(
                                    context, patientId, name);
                              },
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

  void _showPatientPrescriptions(
      BuildContext context, String patientId, String patientName) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Recetas de $patientName'),
        content: SizedBox(
          width: 500,
          height: 300,
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .doc(patientId)
                .collection('recetas')
                .orderBy('fechaSubida', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.description_outlined,
                          size: 48, color: Colors.grey),
                      SizedBox(height: 12),
                      Text('No hay recetas registradas para este paciente.',
                          style: TextStyle(color: Colors.grey)),
                    ],
                  ),
                );
              }

              return ListView.builder(
                itemCount: snapshot.data!.docs.length,
                itemBuilder: (context, index) {
                  final receta = snapshot.data!.docs[index].data()
                      as Map<String, dynamic>;
                  final descripcion =
                      receta['descripcion'] ?? 'Sin descripción';
                  final fecha =
                      (receta['fechaSubida'] as Timestamp?)?.toDate();
                  final fechaStr = fecha != null
                      ? '${fecha.day}/${fecha.month}/${fecha.year}'
                      : 'N/A';

                  return ListTile(
                    leading: const Icon(Icons.receipt_long,
                        color: Color(0xFF4594A4)),
                    title: Text(descripcion),
                    subtitle: Text('Fecha: $fechaStr'),
                  );
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  void _showUploadDialog(
      BuildContext context, String patientId, String patientName) {
    final descripcionController = TextEditingController();
    final notasController = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Subir Receta — $patientName'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: descripcionController,
              decoration: const InputDecoration(
                labelText: 'Descripción / Nombre del medicamento',
                prefixIcon: Icon(Icons.medication),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: notasController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Notas adicionales (dosis, frecuencia, etc.)',
                prefixIcon: Icon(Icons.notes),
                alignLabelWithHint: true,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4594A4),
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              if (descripcionController.text.isNotEmpty) {
                await FirebaseFirestore.instance
                    .collection('users')
                    .doc(patientId)
                    .collection('recetas')
                    .add({
                  'descripcion': descripcionController.text,
                  'notas': notasController.text,
                  'fechaSubida': FieldValue.serverTimestamp(),
                  'creadoPor': 'secretaria',
                });
                if (dialogContext.mounted) {
                  Navigator.pop(dialogContext);
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    SnackBar(
                        content: Text(
                            'Receta guardada para $patientName')),
                  );
                }
              }
            },
            child: const Text('Guardar Receta'),
          ),
        ],
      ),
    );
  }
}