// lib/features/schedule/presentation/pages/ajustes_page.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/async_states.dart';

class AjustesPage extends StatelessWidget {
  const AjustesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final usuario = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Configuración',
                style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary)),
            const SizedBox(height: 6),
            Text('Sesion iniciada como ${usuario?.email ?? 'invitado'}',
                style: const TextStyle(
                    fontSize: 14, color: AppColors.textSecondary)),
            const SizedBox(height: 24),
            const Text('Seguridad',
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary)),
            const SizedBox(height: 10),
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.lock_outline,
                        color: AppColors.primary),
                    title: const Text('Cambiar contraseña'),
                    subtitle: const Text('Te enviamos un enlace a tu correo'),
                    trailing: const Icon(Icons.chevron_right,
                        color: AppColors.textMuted),
                    onTap: () async {
                      final correo = usuario?.email;
                      if (correo == null) {
                        mostrarAviso(
                            context, 'Tu cuenta no tiene correo asociado.',
                            esError: true);
                        return;
                      }
                      try {
                        await FirebaseAuth.instance
                            .sendPasswordResetEmail(email: correo);
                        if (context.mounted) {
                          mostrarAviso(context, 'Enlace enviado a $correo',
                              esExito: true);
                        }
                      } catch (e) {
                        if (context.mounted) {
                          mostrarAviso(
                              context, 'No se pudo enviar el enlace: $e',
                              esError: true);
                        }
                      }
                    },
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.email_outlined,
                        color: AppColors.primary),
                    title: const Text('Actualizar correo electronico'),
                    trailing: const Icon(Icons.chevron_right,
                        color: AppColors.textMuted),
                    onTap: () => showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        title: const Text('Actualizar correo',
                            style: TextStyle(fontSize: 17)),
                        content: const Text(
                          'Por seguridad, el cambio de correo lo hace el personal de la clinica. '
                          'Comunicate con secretaria para solicitarlo.',
                        ),
                        actions: [
                          TextButton(
                              onPressed: () => Navigator.pop(ctx),
                              child: const Text('Entendido')),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const Text('Preferencias',
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary)),
            const SizedBox(height: 10),
            Card(
              child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                stream: usuario == null
                    ? const Stream.empty()
                    : FirebaseFirestore.instance
                        .collection('users')
                        .doc(usuario.uid)
                        .snapshots(),
                builder: (context, snap) {
                  final activas =
                      snap.data?.data()?['notificationsEnabled'] as bool? ??
                          true;
                  return SwitchListTile(
                    activeThumbColor: AppColors.primary,
                    secondary: const Icon(Icons.notifications_active_outlined,
                        color: AppColors.primary),
                    title: const Text('Notificaciones por correo'),
                    subtitle:
                        const Text('Recordatorios de tus citas programadas'),
                    value: activas,
                    onChanged: usuario == null
                        ? null
                        : (valor) async {
                            try {
                              await FirebaseFirestore.instance
                                  .collection('users')
                                  .doc(usuario.uid)
                                  .set({'notificationsEnabled': valor},
                                      SetOptions(merge: true));
                            } catch (e) {
                              if (context.mounted) {
                                mostrarAviso(context, 'No se pudo guardar: $e',
                                    esError: true);
                              }
                            }
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
}
