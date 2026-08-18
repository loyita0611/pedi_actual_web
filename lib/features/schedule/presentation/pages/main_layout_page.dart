// lib/features/schedule/presentation/pages/main_layout_page.dart

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_auth/firebase_auth.dart'; 
import 'package:shared_preferences/shared_preferences.dart'; 
import 'package:pedia_actual/features/schedule/presentation/pages/schedule_page.dart';
import 'package:pedia_actual/features/schedule/presentation/pages/mis_pagos_page.dart'; 
import 'package:pedia_actual/features/schedule/presentation/bloc/schedule_bloc.dart';
import 'package:pedia_actual/features/schedule/presentation/bloc/schedule_event.dart';
import 'package:pedia_actual/features/secretary/presentation/pages/secretary_dashboard_page.dart';
import 'package:pedia_actual/features/secretary/presentation/widgets/patient_directory_widget.dart';
import 'package:pedia_actual/features/secretary/presentation/widgets/upload_prescription_widget.dart';
import '../../../../injection_container.dart' as di;

enum UserRole { doctor, secretary, patient }

class CurrentUser {
  final String name;
  final UserRole role;

  CurrentUser({required this.name, required this.role});
}

class MainLayoutPage extends StatefulWidget {
  final CurrentUser currentUser;

  const MainLayoutPage({super.key, required this.currentUser});

  @override
  State<MainLayoutPage> createState() => _MainLayoutPageState();
}

class _MainLayoutPageState extends State<MainLayoutPage> {
  late int _selectedIndex; 
  late final CurrentUser _user;

  @override
  void initState() {
    super.initState();
    _user = widget.currentUser;

    // Redirección inicial por defecto según el rol
    if (_user.role == UserRole.patient) {
      _selectedIndex = 7;
    } else if (_user.role == UserRole.secretary) {
      _selectedIndex = 5;
    } else {
      _selectedIndex = 0;
    }

    // 🚀 Cargamos la última pestaña guardada si existe
    _cargarPestanaGuardada();
  }

  // 🔹 Función protegida para evitar la pantalla en blanco
  Future<void> _cargarPestanaGuardada() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      int? savedIndex = prefs.getInt('selected_page_index');
      
      // FORZAR a la secretaria al panel de control si estaba en 0 (la antigua agenda)
      if (_user.role == UserRole.secretary && savedIndex == 0) {
        savedIndex = 5;
        await prefs.setInt('selected_page_index', 5);
      }

      if (savedIndex != null && mounted) {
        setState(() {
          _selectedIndex = savedIndex!;
        });
      }
    } catch (e) {
      debugPrint("Error leyendo la pestaña guardada: $e");
    }
  }

  Widget _getPageByIndex(int index) {
    switch (index) {
      case 0:
      
        return BlocProvider(
          create: (_) => di.sl<ScheduleBloc>()..add(LoadAppointmentsForDate(DateTime.now())),
          child: const SchedulePage(),
        );
      case 1:
        return const Scaffold(
          backgroundColor: Color(0xFFF4F7F6),
          body: Padding(
            padding: EdgeInsets.all(32.0),
            child: PatientDirectoryWidget(),
          ),
        );
      case 2:
        return const Center(child: Text('Módulo de Consultas / Historial', style: TextStyle(fontSize: 24)));
      case 3:
        return const MisPagosPage();
      case 4:
        return const Center(child: Text('Módulo de Estadísticas y Reportes', style: TextStyle(fontSize: 24)));
      case 5:
      
        return const SecretaryDashboardScreen();
      case 6:
        return _buildOnlyContactPage();
      case 7:
        return _buildPatientInfoPage();
      case 8: // 🔹 Nueva ruta para Configuración
        return _buildConfiguracionPage();
      case 9:
        return const Scaffold(
          backgroundColor: Color(0xFFF4F7F6),
          body: Padding(
            padding: EdgeInsets.all(32.0),
            child: UploadPrescriptionWidget(),
          ),
        );
      default:
        return BlocProvider(
          create: (_) => di.sl<ScheduleBloc>()..add(LoadAppointmentsForDate(DateTime.now())),
          child: const SchedulePage(),
        );
    }
  }

  Widget _getFilteredPage() {
    return _getPageByIndex(_selectedIndex);
  }

  @override
  Widget build(BuildContext context) {
    const Color sidebarColor = Color(0xFF4594A4);

    return Scaffold(
      body: Row(
        children: [
          // --- SIDEBAR IZQUIERDO ---
          Container(
            width: 260,
            color: sidebarColor,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 40, left: 24, bottom: 20),
                  child: Row(
                    children: [
                      Text('pedi', style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w300)),
                      Text('actual', style: TextStyle(color: Color(0xFFEAA171), fontSize: 28, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.account_circle, color: Color(0xFF4594A4), size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _user.name,
                            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87, fontSize: 13),
                            overflow: TextOverflow.ellipsis,
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
                    children: _buildMenuByRole(),
                  ),
                ),

                const Divider(color: Colors.white30, height: 1),
                // 🔹 Configuración ahora apunta al índice 8
                _buildSidebarItem(icon: Icons.settings_outlined, title: 'Configuración', pageIndex: 8),
                _buildSidebarItem(icon: Icons.logout, title: 'Salir', pageIndex: -2),
                const SizedBox(height: 20),
              ],
            ),
          ),

          // --- CONTENIDO DINÁMICO ---
          Expanded(
            child: Container(
              color: const Color(0xFFF4F7F6),
              child: _getFilteredPage(),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildMenuByRole() {
    final List<Widget> menuItems = [];
    switch (_user.role) {
      case UserRole.doctor:
        menuItems.addAll([
          _buildSidebarItem(icon: Icons.calendar_month, title: 'Agenda', pageIndex: 0),
          _buildSidebarItem(icon: Icons.people_outline, title: 'Pacientes', pageIndex: 1),
          _buildSidebarItem(icon: Icons.medical_services_outlined, title: 'Consultas', pageIndex: 2),
          _buildSidebarItem(icon: Icons.pie_chart_outline, title: 'Estadísticas', pageIndex: 4),
        ]);
        break;
      case UserRole.secretary:
        menuItems.addAll([
          _buildSidebarItem(icon: Icons.dashboard, title: 'Panel de Control', pageIndex: 5),
          _buildSidebarItem(icon: Icons.people_outline, title: 'Pacientes', pageIndex: 1),
          _buildSidebarItem(icon: Icons.upload_file, title: 'Recetas / Documentos', pageIndex: 9),
        ]);
        break;
      case UserRole.patient:
        menuItems.addAll([
          _buildSidebarItem(icon: Icons.edit_calendar_outlined, title: 'Agendar Cita', pageIndex: 0),
          _buildSidebarItem(icon: Icons.payment_outlined, title: 'Mis Pagos', pageIndex: 3),
          _buildSidebarItem(icon: Icons.info_outline, title: 'Información', pageIndex: 7), 
          _buildSidebarItem(icon: Icons.contact_phone_outlined, title: 'Contacto', pageIndex: 6),   
        ]);
        break;
    }
    return menuItems;
  }

  Widget _buildSidebarItem({required IconData icon, required String title, required int pageIndex}) {
    final bool isActive = _selectedIndex == pageIndex;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: InkWell(
        onTap: () async {
          // 🚪 SI PULSA SALIR (Muestra el diálogo de confirmación)
          if (pageIndex == -2) {
            _mostrarDialogoSalir();
            return;
          }

          if (pageIndex < 0) return;
          
          setState(() => _selectedIndex = pageIndex);

          // 🚀 GUARDAMOS la pestaña seleccionada en el navegador
          final prefs = await SharedPreferences.getInstance();
          await prefs.setInt('selected_page_index', pageIndex);
        },
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          decoration: BoxDecoration(
            color: isActive ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(icon, color: isActive ? const Color(0xFF4594A4) : Colors.white, size: 22),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: isActive ? const Color(0xFF4594A4) : Colors.white,
                    fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                    fontSize: 15,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 🔹 WIDGET: Diálogo elegante para confirmar cierre de sesión
  void _mostrarDialogoSalir() {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: const Row(
            children: [
              Icon(Icons.exit_to_app, color: Colors.redAccent),
              SizedBox(width: 8),
              Text('Cerrar Sesión', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            ],
          ),
          content: const Text('¿Estás seguro de que deseas salir de tu cuenta en PediActual?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancelar', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () async {
                Navigator.pop(dialogContext); // Cierra el diálogo
                final prefs = await SharedPreferences.getInstance();
                await prefs.remove('selected_page_index'); // Borra memoria de pestañas
                await FirebaseAuth.instance.signOut(); // Cierra sesión
              },
              child: const Text('Salir', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  Widget _buildOnlyContactPage() {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7F6),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Información de Contacto',
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Color(0xFF4594A4)),
            ),
            const SizedBox(height: 6),
            const Text(
              '¿Necesitas ayuda? Comunícate con nuestro personal administrativo.',
              style: TextStyle(fontSize: 14, color: Colors.black54),
            ),
            const SizedBox(height: 24),
            Card(
              elevation: 1,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.location_on_outlined, color: Color(0xFF4594A4)),
                      title: const Text('Ubicación de la Clínica', style: TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: const Text('Av. Los Leones, Centro Profesional PediaActual, Piso 2. Barquisimeto.'),
                    ),
                    ListTile(
                      leading: const Icon(Icons.phone_android_outlined, color: Color(0xFF4594A4)),
                      title: const Text('Teléfono / WhatsApp', style: TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: const Text('+58 (412) 555-5555'),
                    ),
                    ListTile(
                      leading: const Icon(Icons.access_time, color: Color(0xFF4594A4)),
                      title: const Text('Horario de Consultas', style: TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: const Text('Lunes a Viernes: 8:00 AM - 6:00 PM'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPatientInfoPage() {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7F6),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Cartelera Informativa',
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Color(0xFF4594A4)),
            ),
            const SizedBox(height: 6),
            const Text(
              'Entérate de las últimas novedades y jornadas médicas de PediaActual.',
              style: TextStyle(fontSize: 14, color: Colors.black54),
            ),
            const SizedBox(height: 24),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF4594A4).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF4594A4).withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: const BoxDecoration(color: Color(0xFF4594A4), shape: BoxShape.circle),
                    child: const Icon(Icons.campaign, color: Colors.white, size: 30),
                  ),
                  const SizedBox(width: 20),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '¡Jornada Especial de Niño Sano!',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
                        ),
                        SizedBox(height: 6),
                        Text(
                          'Este mes contamos con 10% de descuento en controles preventivos. Recuerda reportar tus pagos a tasa oficial BCV.',
                          style: TextStyle(fontSize: 14, color: Colors.black54, height: 1.4),
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

  // --- ⚙️ PANTALLA DE CONFIGURACIÓN (ÍNDICE 8) ---
  // --- ⚙️ PANTALLA DE CONFIGURACIÓN (CON LÓGICA DE FIREBASE) ---
  Widget _buildConfiguracionPage() {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7F6),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Configuración de la Cuenta',
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Color(0xFF4594A4)),
            ),
            const SizedBox(height: 6),
            const Text(
              'Administra tus preferencias, seguridad y notificaciones.',
              style: TextStyle(fontSize: 14, color: Colors.black54),
            ),
            const SizedBox(height: 24),
            
            // Sección de Seguridad
            const Text('Seguridad y Perfil', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
            const SizedBox(height: 12),
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade300)),
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.lock_outline, color: Color(0xFF4594A4)),
                    title: const Text('Cambiar Contraseña'),
                    trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                    onTap: () async {
                      // 🚀 Lógica para enviar correo de reseteo de clave
                      final userEmail = FirebaseAuth.instance.currentUser?.email;
                      if (userEmail != null) {
                        await FirebaseAuth.instance.sendPasswordResetEmail(email: userEmail);
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Se ha enviado un enlace de cambio de clave a $userEmail')),
                        );
                      }
                    },
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.email_outlined, color: Color(0xFF4594A4)),
                    title: const Text('Actualizar Correo Electrónico'),
                    trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                    onTap: () {
                      // Aviso de seguridad para actualización de correo
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text("Actualizar Correo"),
                          content: const Text("Para cambiar tu correo electrónico, por favor contacta con el administrador del sistema para garantizar la seguridad de tus datos."),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context), 
                              child: const Text("Cerrar")
                            )
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Sección de Notificaciones
            const Text('Preferencias', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
            const SizedBox(height: 12),
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade300)),
              child: SwitchListTile(
                activeThumbColor: const Color(0xFF4594A4),
                secondary: const Icon(Icons.notifications_active_outlined, color: Color(0xFF4594A4)),
                title: const Text('Notificaciones por Correo'),
                subtitle: const Text('Recibir recordatorios de tus citas programadas'),
                value: true, 
                onChanged: (bool value) {},
              ),
            ),
          ],
        ),
      ),
    );
  }
}