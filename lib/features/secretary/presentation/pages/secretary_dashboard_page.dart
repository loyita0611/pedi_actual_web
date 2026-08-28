// lib/features/secretary/presentation/pages/secretary_dashboard_page.dart
import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../widgets/appointment_calendar_widget.dart';
import '../widgets/create_appointment_dialog.dart';
import '../widgets/daily_dashboard_widget.dart';
import '../widgets/payments_data_table.dart';
import '../widgets/pending_orders_widget.dart';

class SecretaryDashboardScreen extends StatelessWidget {
  const SecretaryDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      // Cuarta pestana: la bandeja de indicaciones pendientes.
      length: 4,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Panel de Control',
                            style: TextStyle(
                                fontSize: 28, fontWeight: FontWeight.bold, color: AppColors.primary)),
                        SizedBox(height: 3),
                        Text('Secretaria',
                            style: TextStyle(fontSize: 14, color: AppColors.textSecondary)),
                      ],
                    ),
                  ),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.add),
                    label: const Text('Nueva cita asistida'),
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.accentDark),
                    onPressed: () => showDialog(
                      context: context,
                      builder: (_) => const CreateAppointmentDialog(),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Container(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: const TabBar(
                  labelColor: AppColors.primary,
                  unselectedLabelColor: AppColors.textMuted,
                  indicatorColor: AppColors.accent,
                  indicatorWeight: 3,
                  dividerColor: Colors.transparent,
                  tabs: [
                    Tab(icon: Icon(Icons.today), text: 'Citas de hoy'),
                    Tab(icon: Icon(Icons.pending_actions), text: 'Indicaciones'),
                    Tab(icon: Icon(Icons.calendar_month), text: 'Agenda general'),
                    Tab(icon: Icon(Icons.payments_outlined), text: 'Pagos'),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              const Expanded(
                child: TabBarView(
                  children: [
                    DailyDashboardWidget(),
                    PendingOrdersWidget(),
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
