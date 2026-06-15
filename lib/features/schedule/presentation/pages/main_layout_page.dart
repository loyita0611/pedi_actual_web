// lib/features/schedule/presentation/pages/main_layout_page.dart

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pedia_actual/features/schedule/presentation/pages/schedule_page.dart';
import 'package:pedia_actual/features/schedule/presentation/bloc/schedule_bloc.dart';
import 'package:pedia_actual/features/schedule/presentation/bloc/schedule_event.dart';
import '../../../../injection_container.dart' as di;

// Enumerado para los 3 tipos de usuario
enum UserRole { doctor, secretary, patient }

// Modelo de usuario para la sesión
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
  late int _selectedIndex; // Quitamos el = 0 fijo para hacerlo dinámico
  late final CurrentUser _user;
  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _user = widget.currentUser;

    // 🚀 REDIRECCIÓN AL INICIAR SESIÓN SEGÚN EL ROL:
    // Si es Paciente, abre directo en la Cartelera Informativa (Índice 7). 
    // Si es Doctor o Secretaria, abre en la Agenda (Índice 0).
    if (_user.role == UserRole.patient) {
      _selectedIndex = 7;
    } else {
      _selectedIndex = 0;
    }

    _pages = [
      // 📅 ÍNDICE 0: Agendar Cita / Agenda
      BlocProvider(
        create: (_) => di.sl<ScheduleBloc>()..add(LoadAppointmentsForDate(DateTime.now())),
        child: const SchedulePage(),
      ),
      /* 1 */ const Center(child: Text('Módulo de Pacientes', style: TextStyle(fontSize: 24))),
      /* 2 */ const Center(child: Text('Módulo de Consultas / Historial', style: TextStyle(fontSize: 24))),
      /* 3 */ const Center(child: Text('Módulo de Pagos', style: TextStyle(fontSize: 24))),
      /* 4 */ const Center(child: Text('Módulo de Estadísticas y Reportes', style: TextStyle(fontSize: 24))),
      /* 5 */ const Center(child: Text('Módulo de Configuración de la Vista de Paciente', style: TextStyle(fontSize: 24))),
      
      // 📱 ÍNDICE 6: Pantalla exclusiva de Contacto
      _buildOnlyContactPage(),

      // 📢 ÍNDICE 7: Pantalla exclusiva de Información / Propaganda
      _buildPatientInfoPage(),
    ];
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
                _buildSidebarItem(icon: Icons.settings_outlined, title: 'Configuración', pageIndex: -1),
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
          _buildSidebarItem(icon: Icons.calendar_month, title: 'Agenda General', pageIndex: 0),
          _buildSidebarItem(icon: Icons.dashboard_customize_outlined, title: 'Info Vista Paciente', pageIndex: 5),
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

  Widget _getFilteredPage() {
    if (_selectedIndex >= 0 && _selectedIndex < _pages.length) {
      return _pages[_selectedIndex];
    }
    return _pages[0];
  }

  Widget _buildSidebarItem({required IconData icon, required String title, required int pageIndex}) {
    final bool isActive = _selectedIndex == pageIndex;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: InkWell(
        onTap: () {
          if (pageIndex < 0) return;
          setState(() => _selectedIndex = pageIndex);
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

  // --- 📱 PANTALLA DE CONTACTO (ÍNDICE 6) ---
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

  // --- 📢 PANTALLA DE INFORMACIÓN / CARTELERA (ÍNDICE 7) ---
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
}