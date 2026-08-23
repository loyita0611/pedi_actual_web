import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class UploadPrescriptionWidget extends StatelessWidget {
  const UploadPrescriptionWidget({super.key});

  Future<bool> _verifySecurityPin(BuildContext context) async {
    String enteredPin = '';
    
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Seguridad Requerida'),
        content: TextField(
          obscureText: true,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Ingrese PIN de Secretaría'),
          onChanged: (val) => enteredPin = val,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false), 
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              final doc = await FirebaseFirestore.instance.collection('settings').doc('security').get();
              final validPin = doc.data()?['secretariatPin'] ?? '1234';
              
              if (!dialogContext.mounted) return;
              
              if (enteredPin == validPin) {
                Navigator.pop(dialogContext, true);
              } else {
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  const SnackBar(content: Text('PIN Incorrecto')),
                );
              }
            },
            child: const Text('Verificar'),
          ),
        ],
      ),
    );

    return result ?? false;
  }

  void _onUploadPressed(BuildContext context) async {
    bool isAuthorized = await _verifySecurityPin(context);
    
    // Verificación de seguridad requerida por Flutter después del await
    if (!context.mounted) return;

    if (isAuthorized) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Acceso concedido. Abriendo selector...')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.security, size: 80, color: Colors.blueGrey),
          const SizedBox(height: 20),
          const Text('Área Segura de Recetas', style: TextStyle(fontSize: 22)),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            icon: const Icon(Icons.upload_file),
            label: const Text('Subir Nueva Receta'),
            style: ElevatedButton.styleFrom(padding: const EdgeInsets.all(16)),
            onPressed: () => _onUploadPressed(context),
          ),
        ],
      ),
    );
  }
}