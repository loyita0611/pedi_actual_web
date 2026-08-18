import 'package:flutter/material.dart';
import 'package:pedia_actual/features/secretary/presentation/widgets/appointment_calendar_widget.dart';
import 'package:pedia_actual/features/secretary/presentation/widgets/payments_data_table.dart';
import 'package:pedia_actual/features/secretary/presentation/widgets/create_appointment_dialog.dart';
import 'package:pedia_actual/features/secretary/presentation/widgets/daily_dashboard_widget.dart';

class SecretaryDashboardScreen extends StatefulWidget {
  const SecretaryDashboardScreen({super.key});

  @override
  State<SecretaryDashboardScreen> createState() => _SecretaryDashboardScreenState();
}

class _SecretaryDashboardScreenState extends State<SecretaryDashboardScreen> {
  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: const Color(0xFFF4F7F6),
        body: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Panel de Control — Secretaría',
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF4594A4)),
                  ),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.add),
                    label: const Text('Nueva Cita Asistida'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFEAA171),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    ),
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (_) => const CreateAppointmentDialog(),
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 24),
              
              // Menú Horizontal (Tabs)
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4)),
                  ],
                ),
                child: const TabBar(
                  labelColor: Color(0xFF4594A4),
                  unselectedLabelColor: Colors.grey,
                  indicatorColor: Color(0xFFEAA171),
                  indicatorWeight: 4,
                  tabs: [
                    Tab(icon: Icon(Icons.calendar_today), text: 'Citas de Hoy'),
                    Tab(icon: Icon(Icons.calendar_month), text: 'Agenda General'),
                    Tab(icon: Icon(Icons.payments_outlined), text: 'Pagos'),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              
              // Contenido de las Pestañas
              const Expanded(
                child: TabBarView(
                  children: [
                    DailyDashboardWidget(),
                    AppointmentCalendarWidget(),
                    PaymentsDataTable(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}