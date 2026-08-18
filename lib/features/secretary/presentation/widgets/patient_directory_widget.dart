import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class PatientDirectoryWidget extends StatefulWidget {
  const PatientDirectoryWidget({super.key});

  @override
  State<PatientDirectoryWidget> createState() => _PatientDirectoryWidgetState();
}

class _PatientDirectoryWidgetState extends State<PatientDirectoryWidget> {
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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Directorio de Pacientes',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF4594A4)),
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    _showCreatePatientDialog(context);
                  },
                  icon: const Icon(Icons.person_add),
                  label: const Text('Nuevo Paciente'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4594A4),
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              onChanged: (value) {
                setState(() {
                  _searchQuery = value.toLowerCase();
                });
              },
              decoration: InputDecoration(
                hintText: 'Buscar por nombre, correo o teléfono...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
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
                    return const Center(child: Text('Error al cargar pacientes.'));
                  }

                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return const Center(child: Text('No hay pacientes registrados.'));
                  }

                  final docs = snapshot.data!.docs;

                  // Filtrado local según la búsqueda
                  final filteredDocs = docs.where((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    final name = (data['name'] ?? '').toString().toLowerCase();
                    final email = (data['email'] ?? '').toString().toLowerCase();
                    final phone = (data['phone'] ?? '').toString().toLowerCase();

                    return name.contains(_searchQuery) ||
                        email.contains(_searchQuery) ||
                        phone.contains(_searchQuery);
                  }).toList();

                  if (filteredDocs.isEmpty) {
                    return const Center(
                        child: Text('No se encontraron pacientes que coincidan con la búsqueda.'));
                  }

                  return ListView.separated(
                    itemCount: filteredDocs.length,
                    separatorBuilder: (context, index) => const Divider(),
                    itemBuilder: (context, index) {
                      final data = filteredDocs[index].data() as Map<String, dynamic>;
                      final name = data['name'] ?? 'Desconocido';
                      final phone = data['phone'] ?? 'No especificado';
                      final email = data['email'] ?? 'No especificado';

                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: const Color(0xFFEAA171).withValues(alpha: 0.2),
                          child: Text(
                              name.toString().isNotEmpty
                                  ? name.toString()[0].toUpperCase()
                                  : '?',
                              style: const TextStyle(
                                  color: Color(0xFFEAA171),
                                  fontWeight: FontWeight.bold)),
                        ),
                        title: Text(name,
                            style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('Tel: $phone • Correo: $email'),
                        trailing: IconButton(
                          icon: const Icon(Icons.edit_outlined, color: Colors.grey),
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text(
                                        'Editar datos del paciente (Próximamente)')));
                          },
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

  void _showCreatePatientDialog(BuildContext context) {
    final nameController = TextEditingController();
    final emailController = TextEditingController();
    final phoneController = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Registrar Nuevo Paciente'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
                controller: nameController,
                decoration:
                    const InputDecoration(labelText: 'Nombre Completo')),
            TextField(
                controller: emailController,
                decoration:
                    const InputDecoration(labelText: 'Correo Electrónico')),
            TextField(
                controller: phoneController,
                decoration: const InputDecoration(labelText: 'Teléfono')),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.isNotEmpty) {
                await FirebaseFirestore.instance.collection('users').add({
                  'name': nameController.text,
                  'email': emailController.text,
                  'phone': phoneController.text,
                  'role': 'patient',
                  'createdAt': FieldValue.serverTimestamp(),
                });
                if (dialogContext.mounted) {
                  Navigator.pop(dialogContext);
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                      const SnackBar(
                          content: Text('Paciente registrado exitosamente')));
                }
              }
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }
}
