import 'package:flutter/material.dart';
import 'status_chip.dart';

class AppointmentCalendarWidget extends StatefulWidget {
  const AppointmentCalendarWidget({super.key});

  @override
  State<AppointmentCalendarWidget> createState() => _AppointmentCalendarWidgetState();
}

class _AppointmentCalendarWidgetState extends State<AppointmentCalendarWidget> {
  DateTime _selectedDate = DateTime.now();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left),
                    onPressed: () => setState(() => _selectedDate = _selectedDate.subtract(const Duration(days: 1))),
                  ),
                  Text(
                    '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF4594A4)),
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_right),
                    onPressed: () => setState(() => _selectedDate = _selectedDate.add(const Duration(days: 1))),
                  ),
                ],
              ),
              ElevatedButton.icon(
                icon: const Icon(Icons.calendar_month, size: 18),
                label: const Text('Seleccionar Fecha'),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4594A4), foregroundColor: Colors.white),
                onPressed: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _selectedDate,
                    firstDate: DateTime(2024),
                    lastDate: DateTime(2030),
                  );
                  if (picked != null) setState(() => _selectedDate = picked);
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ListView.separated(
              itemCount: 4,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFFEAA171),
                    child: Icon(Icons.person, color: Colors.white),
                  ),
                  title: const Text('Paciente: Gabriel Godoy', style: TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: const Text('Dr. Silva — 09:30 AM (Pediatría General)'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const StatusChip(status: AppointmentStatus.confirmed),
                      const SizedBox(width: 8),
                      PopupMenuButton<String>(
                        onSelected: (value) {},
                        itemBuilder: (context) => [
                          const PopupMenuItem(value: 'reschedule', child: Text('Reagendar')),
                          const PopupMenuItem(value: 'cancel', child: Text('Cancelar Cita')),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          )
        ],
      ),
    );
  }
}