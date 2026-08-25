import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class AppointmentCalendarWidget extends StatefulWidget {
  const AppointmentCalendarWidget({super.key});

  @override
  State<AppointmentCalendarWidget> createState() => _AppointmentCalendarWidgetState();
}

class _AppointmentCalendarWidgetState extends State<AppointmentCalendarWidget> {
  DateTime _selectedDate = DateTime.now();
  bool _showOnlyConfirmed = false;

  void _changeDate(int days) {
    setState(() {
      _selectedDate = _selectedDate.add(Duration(days: days));
    });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2024),
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF4594A4), 
              onPrimary: Colors.white, 
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _updateStatus(String docId, String newStatus) async {
    await FirebaseFirestore.instance.collection('citas').doc(docId).update({
      'status': newStatus,
    });
  }

  @override
  Widget build(BuildContext context) {
    final startOfDay = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
    final endOfDay = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day, 23, 59, 59);

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
                    icon: const Icon(Icons.chevron_left, color: Color(0xFF4594A4)),
                    onPressed: () => _changeDate(-1),
                  ),
                  InkWell(
                    onTap: _pickDate,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8.0),
                      child: Text(
                        DateFormat('dd/MM/yyyy').format(_selectedDate),
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF4594A4)),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_right, color: Color(0xFF4594A4)),
                    onPressed: () => _changeDate(1),
                  ),
                ],
              ),
              Row(
                children: [
                  FilterChip(
                    label: const Text('Solo Confirmadas'),
                    selected: _showOnlyConfirmed,
                    selectedColor: const Color(0xFF4594A4).withValues(alpha: 0.2),
                    checkmarkColor: const Color(0xFF4594A4),
                    onSelected: (val) => setState(() => _showOnlyConfirmed = val),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.calendar_today, size: 18),
                    label: const Text('Seleccionar Fecha'),
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4594A4), foregroundColor: Colors.white),
                    onPressed: _pickDate,
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('citas')
                  .where('appointmentDateTime', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
                  .where('appointmentDateTime', isLessThanOrEqualTo: Timestamp.fromDate(endOfDay))
                  .orderBy('appointmentDateTime')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return const Center(child: Text('Error al cargar la agenda.'));
                }
                
                var docs = snapshot.data?.docs ?? [];
                
                if (_showOnlyConfirmed) {
                  docs = docs.where((doc) => (doc.data() as Map<String, dynamic>)['status'] == 'confirmed').toList();
                }

                if (docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.event_busy, size: 64, color: Colors.grey.shade300),
                        const SizedBox(height: 16),
                        Text('No hay citas para ${DateFormat('dd/MM/yyyy').format(_selectedDate)}', style: TextStyle(color: Colors.grey.shade600, fontSize: 16)),
                      ],
                    ),
                  );
                }

                return ListView.separated(
                  itemCount: docs.length,
                  separatorBuilder: (_, __) => Divider(height: 1, color: Colors.grey.shade200),
                  itemBuilder: (context, index) {
                    final data = docs[index].data() as Map<String, dynamic>;
                    final docId = docs[index].id;
                    final patientName = data['patientName'] ?? 'Desconocido';
                    final dt = (data['appointmentDateTime'] as Timestamp).toDate();
                    final timeStr = DateFormat('hh:mm a').format(dt);
                    final status = data['status'] ?? 'pending';

                    Color statusColor;
                    String statusText;
                    switch (status) {
                      case 'confirmed':
                        statusColor = Colors.blue;
                        statusText = 'Confirmada';
                        break;
                      case 'in_room':
                        statusColor = Colors.orange;
                        statusText = 'En Sala';
                        break;
                      case 'attended':
                        statusColor = Colors.green;
                        statusText = 'Atendida';
                        break;
                      case 'cancelled':
                        statusColor = Colors.red;
                        statusText = 'Cancelada';
                        break;
                      default:
                        statusColor = Colors.grey;
                        statusText = 'Pendiente';
                    }

                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                      leading: CircleAvatar(
                        backgroundColor: statusColor.withValues(alpha: 0.1),
                        child: Icon(Icons.person, color: statusColor),
                      ),
                      title: Text('Paciente: $patientName', style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text('$timeStr — Pediatría General'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: statusColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: statusColor.withValues(alpha: 0.5)),
                            ),
                            child: Text(
                              statusText,
                              style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 12),
                            ),
                          ),
                          const SizedBox(width: 8),
                          PopupMenuButton<String>(
                            icon: const Icon(Icons.more_vert, color: Colors.grey),
                            onSelected: (val) => _updateStatus(docId, val),
                            itemBuilder: (context) => [
                              const PopupMenuItem(value: 'confirmed', child: Text('Confirmar')),
                              const PopupMenuItem(value: 'in_room', child: Text('En Sala')),
                              const PopupMenuItem(value: 'attended', child: Text('Atendida')),
                              const PopupMenuItem(value: 'cancelled', child: Text('Cancelar Cita', style: TextStyle(color: Colors.red))),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          )
        ],
      ),
    );
  }
}