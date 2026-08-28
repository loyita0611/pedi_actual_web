// lib/features/schedule/presentation/pages/main_layout_page.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../injection_container.dart' as di;
import '../../../prescriptions/presentation/pages/my_prescriptions_page.dart';
import '../../../secretary/presentation/pages/secretary_dashboard_page.dart';
import '../../../secretary/presentation/widgets/patient_directory_widget.dart';
import '../../../secretary/presentation/widgets/upload_prescription_widget.dart';
import '../bloc/schedule_bloc.dart';
import '../bloc/schedule_event.dart';
import 'ajustes_page.dart';
import 'contacto_page.dart';
import 'mis_citas_page.dart';
import 'mis_pagos_page.dart';
import 'schedule_page.dart';

enum UserRole { doctor, secretary, patient }

class CurrentUser {
  const CurrentUser({required this.name, required this.role});
  final String name;
  final UserRole role;
}

/// Secciones de la aplicacion.
///
/// Antes esto era un `switch` sobre numeros sueltos y `_getPageByIndex`
/// devolvia cualquier pantalla a cualquier rol. Como el indice se restauraba
/// desde SharedPreferences (que es global del navegador), un paciente que
/// usara la computadora de la secretaria aterrizaba en el Panel de Control.
enum AppSection {
  agenda('agenda'),
  misCitas('mis_citas'),
  misPagos('mis_pagos'),
  misRecetas('mis_recetas'),
  informacion('informacion'),
  contacto('contacto'),
  panelSecretaria('panel_secretaria'),
  pacientes('pacientes'),
  recetas('recetas'),
  ajustes('ajustes');

  const AppSection(this.clave);
  final String clave;

  static AppSection? porClave(String? clave) {
    if (clave == null) return null;
    for (final s in AppSection.values) {
      if (s.clave == clave) return s;
    }
    return null;
  }
}

/// Lo que cada rol puede abrir. Es la lista blanca que faltaba.
const Map<UserRole, List<AppSection>> kSeccionesPorRol = {
  UserRole.patient: [
    AppSection.agenda,
    AppSection.misCitas,
    AppSection.misPagos,
    AppSection.misRecetas,
    AppSection.informacion,
    AppSection.contacto,
    AppSection.ajustes,
  ],
  UserRole.secretary: [
    AppSection.panelSecretaria,
    AppSection.agenda,
    AppSection.pacientes,
    AppSection.recetas,
    AppSection.ajustes,
  ],
  UserRole.doctor: [
    AppSection.agenda,
    AppSection.pacientes,
    AppSection.recetas,
    AppSection.ajustes,
  ],
};

class MainLayoutPage extends StatefulWidget {
  const MainLayoutPage({super.key, required this.currentUser});
  final CurrentUser currentUser;

  @override
  State<MainLayoutPage> createState() => _MainLayoutPageState();
}

class _MainLayoutPageState extends State<MainLayoutPage> {
  late AppSection _seccion;

  List<AppSection> get _permitidas => kSeccionesPorRol[widget.currentUser.role]!;

  @override
  void initState() {
    super.initState();
    _seccion = _permitidas.first;
    _restaurar();
  }

  /// Restaura la ultima pantalla, pero solo si el rol actual puede verla y solo
  /// si la guardo este mismo rol.
  Future<void> _restaurar() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getString('selected_page_role') != widget.currentUser.role.name) return;

      final guardada = AppSection.porClave(prefs.getString('selected_page_index'));
      if (guardada != null && _permitidas.contains(guardada) && mounted) {
        setState(() => _seccion = guardada);
      }
    } catch (_) {
      // Si falla, se queda en la seccion por defecto del rol.
    }
  }

  Future<void> _ir(AppSection destino) async {
    if (!_permitidas.contains(destino)) return;
    setState(() => _seccion = destino);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('selected_page_index', destino.clave);
      await prefs.setString('selected_page_role', widget.currentUser.role.name);
    } catch (_) {}
  }

  Future<void> _salir() async {
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Row(
          children: [
            Icon(Icons.exit_to_app, color: AppColors.danger),
            SizedBox(width: 10),
            Text('Cerrar sesion', style: TextStyle(fontSize: 17)),
          ],
        ),
        content: const Text('Deseas salir de tu cuenta en PediActual?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar', style: TextStyle(color: AppColors.textMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Salir'),
          ),
        ],
      ),
    );
    if (confirmado != true) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('selected_page_index');
    await prefs.remove('selected_page_role');
    await FirebaseAuth.instance.signOut();
  }

  Widget _pantalla() {
    final esPersonal = widget.currentUser.role != UserRole.patient;

    return switch (_seccion) {
      AppSection.agenda => BlocProvider(
          create: (_) => di.sl<ScheduleBloc>()..add(LoadAppointmentsForDate(DateTime.now())),
          child: SchedulePage(esPersonal: esPersonal),
        ),
      AppSection.misCitas => const MisCitasPage(),
      AppSection.misPagos => const MisPagosPage(),
      AppSection.misRecetas => const MyPrescriptionsPage(),
      AppSection.informacion => const CarteleraPage(),
      AppSection.contacto => const ContactoPage(),
      AppSection.panelSecretaria => const SecretaryDashboardScreen(),
      AppSection.pacientes => const Scaffold(
          backgroundColor: AppColors.background,
          body: Padding(padding: EdgeInsets.all(32), child: PatientDirectoryWidget()),
        ),
      AppSection.recetas => const Scaffold(
          backgroundColor: AppColors.background,
          body: Padding(padding: EdgeInsets.all(32), child: UploadPrescriptionWidget()),
        ),
      AppSection.ajustes => const AjustesPage(),
    };
  }

  @override
  Widget build(BuildContext context) {
    // Sin esto el menu lateral ocupaba 260 px fijos y en un telefono de 375
    // quedaban 115 para el contenido.
    return LayoutBuilder(
      builder: (context, c) {
        final anchoCompleto = c.maxWidth >= 900;
        if (anchoCompleto) {
          return Scaffold(
            body: Row(
              children: [
                SizedBox(width: 260, child: _menu()),
                Expanded(child: ColoredBox(color: AppColors.background, child: _pantalla())),
              ],
            ),
          );
        }
        return Scaffold(
          appBar: AppBar(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            title: const Row(
              children: [
                Text('pedi', style: TextStyle(fontWeight: FontWeight.w300, fontSize: 22)),
                Text('actual',
                    style: TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 22, color: AppColors.accent)),
              ],
            ),
          ),
          drawer: Drawer(child: _menu(enDrawer: true)),
          backgroundColor: AppColors.background,
          body: _pantalla(),
        );
      },
    );
  }

  Widget _menu({bool enDrawer = false}) {
    return ColoredBox(
      color: AppColors.primary,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: enDrawer ? 40 : 40),
          const Padding(
            padding: EdgeInsets.only(left: 24, bottom: 18),
            child: Row(
              children: [
                Text('pedi',
                    style: TextStyle(color: Colors.white, fontSize: 27, fontWeight: FontWeight.w300)),
                Text('actual',
                    style: TextStyle(
                        color: AppColors.accent, fontSize: 27, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
              child: Row(
                children: [
                  const Icon(Icons.account_circle, color: AppColors.primary, size: 20),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.currentUser.name,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, color: AppColors.textPrimary, fontSize: 13),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          switch (widget.currentUser.role) {
                            UserRole.doctor => 'Doctora',
                            UserRole.secretary => 'Secretaria',
                            UserRole.patient => 'Representante',
                          },
                          style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                for (final s in _permitidas)
                  if (s != AppSection.ajustes)
                    _item(s, cerrarDrawer: enDrawer),
              ],
            ),
          ),
          const Divider(color: Colors.white24, height: 1),
          _item(AppSection.ajustes, cerrarDrawer: enDrawer),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: InkWell(
              onTap: _salir,
              borderRadius: BorderRadius.circular(8),
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                child: Row(
                  children: [
                    Icon(Icons.logout, color: Colors.white, size: 21),
                    SizedBox(width: 16),
                    Text('Salir',
                        style: TextStyle(
                            color: Colors.white, fontWeight: FontWeight.w500, fontSize: 15)),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 18),
        ],
      ),
    );
  }

  Widget _item(AppSection s, {required bool cerrarDrawer}) {
    final (icono, titulo) = _etiqueta(s);
    final activo = _seccion == s;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      child: InkWell(
        onTap: () {
          _ir(s);
          if (cerrarDrawer) Navigator.maybePop(context);
        },
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          decoration: BoxDecoration(
            color: activo ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(icono, color: activo ? AppColors.primary : Colors.white, size: 21),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  titulo,
                  style: TextStyle(
                    color: activo ? AppColors.primary : Colors.white,
                    fontWeight: activo ? FontWeight.bold : FontWeight.w500,
                    fontSize: 14.5,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  (IconData, String) _etiqueta(AppSection s) => switch (s) {
        AppSection.agenda => (
            Icons.edit_calendar_outlined,
            widget.currentUser.role == UserRole.patient ? 'Agendar cita' : 'Agenda'
          ),
        AppSection.misCitas => (Icons.event_note_outlined, 'Mis citas'),
        AppSection.misPagos => (Icons.payment_outlined, 'Mis pagos'),
        AppSection.misRecetas => (Icons.medication_outlined, 'Mis recetas'),
        AppSection.informacion => (Icons.info_outline, 'Informacion'),
        AppSection.contacto => (Icons.contact_phone_outlined, 'Contacto'),
        AppSection.panelSecretaria => (Icons.dashboard_outlined, 'Panel de control'),
        AppSection.pacientes => (Icons.people_outline, 'Pacientes'),
        AppSection.recetas => (Icons.upload_file, 'Recetas y documentos'),
        AppSection.ajustes => (Icons.settings_outlined, 'Configuracion'),
      };
}
