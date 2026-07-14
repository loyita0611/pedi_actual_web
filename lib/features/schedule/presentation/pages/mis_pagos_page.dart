// lib/features/schedule/presentation/pages/mis_pagos_page.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../domain/entities/appointment_entity.dart'; 
import '../../data/models/appointment_model.dart'; 

class MisPagosPage extends StatefulWidget {
  const MisPagosPage({super.key});

  @override
  State<MisPagosPage> createState() => _MisPagosPageState();
}

class _MisPagosPageState extends State<MisPagosPage> {
  // Capturamos el correo electrónico de la sesión activa del representante
  final String? _currentUserEmail = FirebaseAuth.instance.currentUser?.email;

  @override
  Widget build(BuildContext context) {
    // Si no hay sesión detectada (entorno de pruebas local), usamos el de tu captura
    final String emailAConsultar = _currentUserEmail ?? 'jorg@gmail.com';

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7F6),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 🔹 ENCABEZADO PRINCIPAL DEL PANEL
            const Text(
              'Historial de Transacciones',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF4594A4)),
            ),
            const SizedBox(height: 4),
            Text(
              'Consulta el estado de cuenta de tus pagos registrados bajo el correo: $emailAConsultar',
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
            const SizedBox(height: 24),

            // 🔹 ESCUCHA EN TIEMPO REAL DESDE LA COLECCIÓN 'CITAS'
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('citas')
                    .where('email', isEqualTo: emailAConsultar)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator(color: Color(0xFF4594A4)));
                  }

                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return _buildEmptyState();
                  }

                  // Mapeamos los documentos de Firebase a objetos de tipo AppointmentEntity
                  List<AppointmentEntity> misTransacciones = snapshot.data!.docs.map((doc) {
                    return AppointmentModel.fromJson(doc.data() as Map<String, dynamic>, doc.id);
                  }).toList();

                  // Ordenamos cronológicamente: las citas más recientes primero
                  misTransacciones.sort((a, b) => b.appointmentDateTime.compareTo(a.appointmentDateTime));

                  // Cálculos dinámicos para las tarjetas superiores
                  int enVerificacion = misTransacciones.where((c) => c.pagoEstado == 'pendiente_verificacion').length;
                  int confirmados = misTransacciones.where((c) => c.pagoEstado == 'pagado' || c.pagoEstado == 'aprobado').length;

                  return Column(
                    children: [
                      // 1. INDICADORES SUPERIORES (KPIs)
                      _buildSummaryCards(enVerificacion, confirmados),
                      const SizedBox(height: 24),

                      // 2. TABLA INTERACTIVA DE DATOS
                      Expanded(
                        child: Card(
                          elevation: 1,
                          shadowColor: Colors.black.withValues(alpha: 0.05),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            child: SingleChildScrollView(
                              scrollDirection: Axis.vertical,
                              child: Theme(
                                data: Theme.of(context).copyWith(dividerColor: Colors.grey[200]),
                                child: DataTable(
                                  headingRowColor: WidgetStateProperty.all(const Color(0xFF4594A4).withValues(alpha: 0.04)),
                                  dataRowMinHeight: 52,
                                  dataRowMaxHeight: 52,
                                  columns: const [
                                    DataColumn(label: Text('Fecha Cita', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF4594A4)))),
                                    DataColumn(label: Text('Paciente', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF4594A4)))),
                                    DataColumn(label: Text('Método', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF4594A4)))),
                                    DataColumn(label: Text('Referencia', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF4594A4)))),
                                    DataColumn(label: Text('Monto', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF4594A4)))),
                                    DataColumn(label: Text('Estatus Pago', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF4594A4)))),
                                  ],
                                  rows: misTransacciones.map((cita) => _buildDataRow(cita)).toList(),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // WIDGET: Constructor de las tarjetas superiores de estatus
  Widget _buildSummaryCards(int pendientes, int aprobados) {
    return Row(
      children: [
        _buildKPICard(
          title: 'Pagos por Verificar',
          value: '$pendientes',
          icon: Icons.history_toggle_off_rounded,
          color: Colors.amber[700]!,
          backgroundColor: Colors.amber[50]!,
        ),
        const SizedBox(width: 16),
        _buildKPICard(
          title: 'Pagos Confirmados',
          value: '$aprobados',
          icon: Icons.check_circle_rounded,
          color: Colors.green[700]!,
          backgroundColor: Colors.green[50]!,
        ),
      ],
    );
  }

  Widget _buildKPICard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required Color backgroundColor,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: color.withValues(alpha: 0.1),
              radius: 24,
              child: Icon(icon, size: 28, color: color),
            ),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(title, style: TextStyle(fontSize: 13, color: Colors.grey[700], fontWeight: FontWeight.w500)),
                const SizedBox(height: 2),
                Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color)),
              ],
            )
          ],
        ),
      ),
    );
  }

  // WIDGET: Mapeo y renderizado de la fila de la tabla
  DataRow _buildDataRow(AppointmentEntity cita) {
    final fechaStr = "${cita.appointmentDateTime.day}/${cita.appointmentDateTime.month}/${cita.appointmentDateTime.year}";
    
    return DataRow(cells: [
      DataCell(Text(fechaStr, style: const TextStyle(fontWeight: FontWeight.w500))),
      DataCell(Text(cita.patientName)),
      DataCell(Text(cita.pagoMetodo ?? 'Pago Móvil')),
      DataCell(Text(cita.pagoReferencia ?? 'N/A')),
      DataCell(Text(cita.pagoMonto != null ? "${cita.pagoMonto!.toStringAsFixed(2)} Bs." : '0.00 Bs.')),
      DataCell(_buildStatusBadge(cita)), // Enlace directo pasando la cita completa
    ]);
  }

  // WIDGET: Badge ovalado de estatus con botón condicional para reclamos
  Widget _buildStatusBadge(AppointmentEntity cita) {
    final estado = cita.pagoEstado ?? 'pendiente_verificacion';
    
    Color bgColor;
    Color textColor;
    String label;

    switch (estado) {
      case 'pagado':
      case 'aprobado':
        bgColor = Colors.green[50]!;
        textColor = Colors.green[700]!;
        label = 'Confirmado';
        break;
      case 'rechazado':
        bgColor = Colors.red[50]!;
        textColor = Colors.red[700]!;
        label = 'Rechazado';
        break;
      default:
        bgColor = Colors.amber[50]!;
        textColor = Colors.amber[700]!;
        label = 'Por Verificar';
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            label,
            style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 11),
          ),
        ),
        // 🚀 ACCIÓN RECHAZADO: El botón de consulta médica/soporte solo nace si el estado es 'rechazado'
        if (estado == 'rechazado') ...[
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.chat_bubble_outline_rounded, color: Colors.redAccent, size: 18),
            tooltip: 'Consultar motivo del rechazo',
            onPressed: () {
              // Preparación del string base para el canal de soporte (WhatsApp/Email)
              final mensajeSoporte = "Hola PediActual, tengo una duda con el pago rechazado del paciente ${cita.patientName}. Referencia: ${cita.pagoReferencia}.";
              debugPrint(mensajeSoporte); // Imprime el log del reclamo en la terminal de VS Code
              
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Abriendo consulta para el paciente: ${cita.patientName}'),
                  backgroundColor: Colors.redAccent,
                ),
              );
            },
          ),
        ],
      ],
    );
  }

  // WIDGET: Vista amigable por si la base de datos está vacía para este correo
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.account_balance_wallet_outlined, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          const Text('Sin transacciones reportadas', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey)),
          const SizedBox(height: 4),
          const Text('Tus reportes bancarios se reflejarán aquí al agendar una cita.', style: TextStyle(fontSize: 13, color: Colors.grey)),
        ],
      ),
    );
  }
}