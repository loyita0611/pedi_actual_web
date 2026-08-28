import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SettingsPanelWidget extends StatefulWidget {
  const SettingsPanelWidget({super.key});

  @override
  State<SettingsPanelWidget> createState() => _SettingsPanelWidgetState();
}

class _SettingsPanelWidgetState extends State<SettingsPanelWidget> {
  bool _notificationsEnabled = true;
  final User? currentUser = FirebaseAuth.instance.currentUser;

  @override
  void initState() {
    super.initState();
    _loadNotificationState();
  }

  Future<void> _loadNotificationState() async {
    if (currentUser != null) {
      final doc = await FirebaseFirestore.instance.collection('users').doc(currentUser!.uid).get();
      if (!mounted) return; // Validación de seguridad para initState / async
      if (doc.exists && doc.data()!.containsKey('notificationsEnabled')) {
        setState(() => _notificationsEnabled = doc['notificationsEnabled']);
      }
    }
  }

  Future<void> _toggleNotifications(bool value) async {
    setState(() => _notificationsEnabled = value);
    if (currentUser != null) {
      await FirebaseFirestore.instance.collection('users').doc(currentUser!.uid).set({
        'notificationsEnabled': value,
      }, SetOptions(merge: true));
    }
  }

  Future<void> _sendPasswordReset() async {
    if (currentUser?.email != null) {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: currentUser!.email!);
      
      if (!mounted) return; // Validación de seguridad post-await
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Correo de reseteo enviado.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        const Text('Configuración de Cuenta', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
        const Divider(),
        SwitchListTile(
          title: const Text('Notificaciones Activas'),
          subtitle: const Text('Recibir alertas de nuevas citas y pagos.'),
          value: _notificationsEnabled,
          onChanged: _toggleNotifications,
        ),
        ListTile(
          leading: const Icon(Icons.lock_reset),
          title: const Text('Cambiar Contraseña'),
          subtitle: Text('Se enviará un enlace a ${currentUser?.email ?? ''}'),
          trailing: const Icon(Icons.arrow_forward_ios, size: 16),
          onTap: _sendPasswordReset,
        ),
        ListTile(
          leading: const Icon(Icons.email),
          title: const Text('Cambiar Correo Electrónico'),
          trailing: const Icon(Icons.arrow_forward_ios, size: 16),
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Función de actualización de correo en desarrollo.')),
            );
          },
        ),
      ],
    );
  }
}