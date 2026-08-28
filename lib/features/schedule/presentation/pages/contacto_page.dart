// lib/features/schedule/presentation/pages/contacto_page.dart
import 'package:flutter/material.dart';

import '../../../../core/config/clinic_config.dart';
import '../../../../core/constants/app_colors.dart';

class ContactoPage extends StatefulWidget {
  const ContactoPage({super.key});

  @override
  State<ContactoPage> createState() => _ContactoPageState();
}

class _ContactoPageState extends State<ContactoPage> {
  // El stream se crea una sola vez: dentro de build() se volvia a suscribir
  // en cada reconstruccion del widget.
  late final Stream<ClinicConfig> _config = ClinicConfigService().observar();

  @override
  Widget build(BuildContext context) {
    // Los datos ya no estan escritos en el widget: salen de la misma
    // configuracion que usa la pasarela de pago, asi que el horario que se le
    // promete al paciente coincide con el que genera la grilla.
    return StreamBuilder<ClinicConfig>(
      stream: _config,
      initialData: ClinicConfigService.actual,
      builder: (context, snap) {
        final c = snap.data ?? ClinicConfig.fallback;
        const dias = ['Lun', 'Mar', 'Mie', 'Jue', 'Vie', 'Sab', 'Dom'];
        final habiles = c.diasHabiles.map((d) => dias[d - 1]).join(', ');

        String hora(int h) {
          final ampm = h >= 12 ? 'PM' : 'AM';
          final hh = h > 12 ? h - 12 : (h == 0 ? 12 : h);
          return '$hh:00 $ampm';
        }

        return Scaffold(
          backgroundColor: AppColors.background,
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Contacto',
                    style: TextStyle(
                        fontSize: 26, fontWeight: FontWeight.bold, color: AppColors.primary)),
                const SizedBox(height: 6),
                const Text('Comunicate con nuestro personal administrativo.',
                    style: TextStyle(fontSize: 14, color: AppColors.textSecondary)),
                const SizedBox(height: 24),
                Card(
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.location_on_outlined, color: AppColors.primary),
                        title: const Text('Ubicacion',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5)),
                        subtitle: Text(c.direccion),
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.phone_android_outlined, color: AppColors.primary),
                        title: const Text('Telefono / WhatsApp',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5)),
                        subtitle: SelectableText(c.telefonoClinica),
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.access_time, color: AppColors.primary),
                        title: const Text('Horario de consultas',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5)),
                        subtitle: Text(
                          '$habiles: ${hora(c.horaInicio)} - ${hora(c.horaFin)}\n'
                          'Almuerzo: ${hora(c.almuerzoInicio)} - ${hora(c.almuerzoFin)}',
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class CarteleraPage extends StatelessWidget {
  const CarteleraPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Cartelera informativa',
                style:
                    TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: AppColors.primary)),
            const SizedBox(height: 6),
            const Text('Novedades y jornadas medicas de PediActual.',
                style: TextStyle(fontSize: 14, color: AppColors.textSecondary)),
            const SizedBox(height: 24),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.primarySoft,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration:
                        const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                    child: const Icon(Icons.campaign, color: Colors.white, size: 28),
                  ),
                  const SizedBox(width: 20),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Jornada especial de nino sano',
                            style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary)),
                        SizedBox(height: 6),
                        Text(
                          'Este mes contamos con 10% de descuento en controles preventivos. '
                          'Recuerda reportar tus pagos a tasa oficial BCV.',
                          style: TextStyle(
                              fontSize: 14, color: AppColors.textSecondary, height: 1.4),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
