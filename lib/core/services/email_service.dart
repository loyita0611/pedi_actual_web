// lib/core/services/email_service.dart
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Envio de correos por EmailJS.
///
/// Nota de seguridad importante: estas credenciales viajan dentro del bundle de
/// Flutter Web, asi que cualquiera puede leerlas con las herramientas del
/// navegador y enviar correos con la cuenta de la clinica. Lo correcto es mover
/// este envio a una Cloud Function y dejar aqui solo la llamada. Se centraliza
/// aqui para que ese cambio sea un solo archivo el dia que se haga.
class EmailService {
  EmailService({http.Client? cliente}) : _cliente = cliente ?? http.Client();

  final http.Client _cliente;

  static const _endpoint = 'https://api.emailjs.com/api/v1.0/email/send';
  static const _serviceId = 'service_vfquxn8';
  static const _templateId = 'template_brfi9f5';
  static const _userId = 'wC6RQuuJG9ZfdQxp9';

  Future<bool> _enviar(Map<String, dynamic> params) async {
    if (params['to_email'] == null || params['to_email'].toString().trim().isEmpty) {
      debugPrint('EmailService: sin destinatario, no se envia.');
      return false;
    }
    try {
      final res = await _cliente
          .post(
            Uri.parse(_endpoint),
            headers: const {'Content-Type': 'application/json'},
            body: json.encode({
              'service_id': _serviceId,
              'template_id': _templateId,
              'user_id': _userId,
              'template_params': params,
            }),
          )
          .timeout(const Duration(seconds: 8));
      return res.statusCode == 200;
    } catch (e) {
      debugPrint('EmailService: fallo el envio ($e)');
      return false;
    }
  }

  Future<bool> confirmacionCita({
    required String correo,
    required String paciente,
    required String fecha,
    required String hora,
    required String telefonoClinica,
  }) =>
      _enviar({
        'to_email': correo,
        'patient_name': paciente,
        'appointment_date': fecha,
        'appointment_time': hora,
        'doctor_phone': telefonoClinica,
      });

  Future<bool> reprogramacion({
    required String correo,
    required String paciente,
    required String fecha,
    required String hora,
    required String telefonoClinica,
  }) =>
      _enviar({
        'to_email': correo,
        'patient_name': paciente,
        'appointment_date': '$fecha (REPROGRAMADA)',
        'appointment_time': '$hora (NUEVO HORARIO)',
        'doctor_phone': telefonoClinica,
      });

  Future<bool> cancelacion({
    required String correo,
    required String paciente,
    required String fecha,
    required String hora,
    required String telefonoClinica,
  }) =>
      _enviar({
        'to_email': correo,
        'patient_name': paciente,
        'appointment_date': '$fecha (CITA CANCELADA)',
        'appointment_time': hora,
        'doctor_phone': telefonoClinica,
      });

  Future<bool> pagoVerificado({
    required String correo,
    required String paciente,
    required String fecha,
    required String hora,
    required String telefonoClinica,
  }) =>
      _enviar({
        'to_email': correo,
        'patient_name': paciente,
        'appointment_date': '$fecha (PAGO VERIFICADO)',
        'appointment_time': hora,
        'doctor_phone': telefonoClinica,
      });

  Future<bool> pagoRechazado({
    required String correo,
    required String paciente,
    required String motivo,
    required String telefonoClinica,
  }) =>
      _enviar({
        'to_email': correo,
        'patient_name': paciente,
        'appointment_date': 'PAGO RECHAZADO',
        'appointment_time': motivo,
        'doctor_phone': telefonoClinica,
      });
}
