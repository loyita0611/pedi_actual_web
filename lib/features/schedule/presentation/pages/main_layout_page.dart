// lib/features/schedule/presentation/pages/main_layout_page.dart

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pedia_actual/features/schedule/presentation/pages/schedule_page.dart';
import 'package:pedia_actual/features/schedule/presentation/bloc/schedule_bloc.dart';
import 'package:pedia_actual/features/schedule/presentation/bloc/schedule_event.dart';
import '../../../../injection_container.dart' as di;

// Enumerado para los 3 tipos de usuario requeridos
enum UserRole { doctor, secretary, patient }

// Modelo simple de usuario para la sesión actual
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
  int _selectedIndex = 0;
  late final CurrentUser _user;

  // 👤 SIMULACIÓN DE USUARIO LOGUEADO
  // Cambia el rol aquí para probar cómo muta la barra lateral automáticamente:
  // - UserRole.doctor
  // - UserRole.secretary
  // - UserRole.patient
  // final CurrentUser _user = CurrentUser(
  //   name: 'Dra. Marian Rosales',
  //   role: UserRole.doctor, 
  // );

  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _user = widget.currentUser;
    _pages = [
      BlocProvider(
        create: (_) => di.sl<ScheduleBloc>()..add(LoadAppointmentsForDate(DateTime.now())),
        child: const SchedulePage(),
      ),
      const Center(child: Text('Módulo de Pacientes', style: TextStyle(fontSize: 24))),
      const Center(child: Text('Módulo de Consultas / Historial', style: TextStyle(fontSize: 24))),
      const Center(child: Text('Módulo de Pagos', style: TextStyle(fontSize: 24))),
      const Center(child: Text('Módulo de Estadísticas y Reportes', style: TextStyle(fontSize: 24))),
      const Center(child: Text('Módulo de Configuración de la Vista de Paciente', style: TextStyle(fontSize: 24))),
      const Center(child: Text('Contacto e Información', style: TextStyle(fontSize: 24))),
    ];
  }

  @override
  Widget build(BuildContext context) {
    const Color sidebarColor = Color(0xFF4594A4);

    return Scaffold(
      body: Row(
        children: [
          // --- BARRA LATERAL IZQUIERDA (SIDEBAR) ---
          Container(
            width: 260,
            color: sidebarColor,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Logo de la Aplicación
                const Padding(
                  padding: EdgeInsets.only(top: 40, left: 24, bottom: 20),
                  child: Row(
                    children: [
                      Text('pedi', style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w300)),
                      Text('actual', style: TextStyle(color: Color(0xFFEAA171), fontSize: 28, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),

                // Tarjeta de Usuario Dinámica (Muestra el nombre del usuario logueado)
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

                // --- MENÚ DINÁMICO FILTRADO POR ROL ---
                Expanded(
                  child: ListView(
                    padding: EdgeInsets.zero,
                    children: _buildMenuByRole(),
                  ),
                ),

                const Divider(color: Colors.white30, height: 1),

                // Opciones fijas del fondo
                _buildSidebarItem(icon: Icons.settings_outlined, title: 'Configuración', pageIndex: -1, isClickable: true),
                _buildSidebarItem(icon: Icons.logout, title: 'Salir', pageIndex: -2, isClickable: true),
                const SizedBox(height: 20),
              ],
            ),
          ),

          // --- CONTENIDO DINÁMICO A LA DERECHA ---
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

  // --- FILTRADO DE VISTAS SEGÚN EL ROL ACTIVO ---
  List<Widget> _buildMenuByRole() {
    final List<Widget> menuItems = [];

    switch (_user.role) {
      case UserRole.doctor:
        // El Doctor tiene acceso absoluto a todo el sistema
        menuItems.addAll([
          _buildSidebarItem(icon: Icons.calendar_month, title: 'Agenda', pageIndex: 0),
          _buildSidebarItem(icon: Icons.people_outline, title: 'Pacientes', pageIndex: 1),
          _buildSidebarItem(icon: Icons.medical_services_outlined, title: 'Consultas', pageIndex: 2),
          _buildSidebarItem(icon: Icons.pie_chart_outline, title: 'Estadísticas', pageIndex: 4),
        ]);
        break;

      case UserRole.secretary:
        // La Secretaria agenda, ve la agenda diaria y gestiona la vista del paciente
        menuItems.addAll([
          _buildSidebarItem(icon: Icons.calendar_month, title: 'Agenda General', pageIndex: 0),
          _buildSidebarItem(icon: Icons.dashboard_customize_outlined, title: 'Info Vista Paciente', pageIndex: 5),
        ]);
        break;

      case UserRole.patient:
        // El Paciente solo agenda, consulta disponibilidad, paga y ve contactos
        menuItems.addAll([
          _buildSidebarItem(icon: Icons.edit_calendar_outlined, title: 'Agendar Cita', pageIndex: 0),
          _buildSidebarItem(icon: Icons.payment_outlined, title: 'Mis Pagos', pageIndex: 3),
          _buildSidebarItem(icon: Icons.contact_phone_outlined, title: 'Contacto', pageIndex: 6),
        ]);
        break;
    }

    return menuItems;
  }

  // Mapea de forma segura el índice seleccionado a la página real para evitar desfases visuales
  Widget _getFilteredPage() {
    if (_selectedIndex >= 0 && _selectedIndex < _pages.length) {
      return _pages[_selectedIndex];
    }
    return _pages[0]; // Vista por defecto
  }

  // --- WIDGET AUXILIAR PARA CADA ÍTEM DEL MENÚ ---
  Widget _buildSidebarItem({
    required IconData icon,
    required String title,
    required int pageIndex,
    bool isClickable = true,
  }) {
    final bool isActive = _selectedIndex == pageIndex;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: InkWell(
        onTap: () {
          if (!isClickable || pageIndex < 0) return;
          setState(() {
            _selectedIndex = pageIndex;
          });
        },
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          decoration: BoxDecoration(
            color: isActive ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                color: isActive ? const Color(0xFF4594A4) : Colors.white,
                size: 22,
              ),
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
}