// lib/core/services/bcv_service.dart
import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

@immutable
class TasaBcv {
  const TasaBcv({required this.valor, required this.fecha, required this.origen});

  final double valor;
  final DateTime fecha;

  /// 'api' cuando vino de dolarapi, 'respaldo' cuando salio de Firestore.
  final String origen;

  bool get esRespaldo => origen == 'respaldo';
}

class TasaNoDisponible implements Exception {
  const TasaNoDisponible();
  @override
  String toString() => 'No se pudo obtener la tasa del BCV.';
}

/// Consulta la tasa oficial con respaldo en Firestore.
///
/// El bug original: el `setState` que apagaba el indicador de carga estaba
/// dentro del `if (statusCode == 200)`, asi que cualquier 429 o 500 dejaba al
/// paciente con un spinner infinito; y si la peticion lanzaba excepcion la tasa
/// quedaba en 0 y se mostraba "TOTAL A PAGAR: 0.00 Bs.".
class BcvService {
  BcvService({http.Client? cliente, FirebaseFirestore? firestore})
      : _cliente = cliente ?? http.Client(),
        _db = firestore ?? FirebaseFirestore.instance;

  final http.Client _cliente;
  final FirebaseFirestore _db;

  static const _url = 'https://ve.dolarapi.com/v1/dolares/oficial';
  static const _timeout = Duration(seconds: 8);

  DocumentReference<Map<String, dynamic>> get _refRespaldo =>
      _db.collection('configuracion').doc('tasa_bcv');

  /// Nunca lanza por fallo de red: primero intenta la API, luego el respaldo.
  /// Solo lanza [TasaNoDisponible] si tampoco hay respaldo guardado.
  Future<TasaBcv> obtener() async {
    try {
      final res = await _cliente.get(Uri.parse(_url)).timeout(_timeout);
      if (res.statusCode == 200) {
        final data = json.decode(res.body) as Map<String, dynamic>;
        final valor = (data['promedio'] as num?)?.toDouble();
        if (valor != null && valor > 0) {
          final tasa = TasaBcv(valor: valor, fecha: DateTime.now(), origen: 'api');
          // Guardado del respaldo en segundo plano: no debe frenar la reserva.
          _guardarRespaldo(tasa).ignore();
          return tasa;
        }
      }
      debugPrint('BCV: respuesta inesperada ${res.statusCode}');
    } catch (e) {
      debugPrint('BCV: fallo la consulta ($e)');
    }
    return _leerRespaldo();
  }

  Future<TasaBcv> _leerRespaldo() async {
    try {
      final snap = await _refRespaldo.get();
      final valor = (snap.data()?['valor'] as num?)?.toDouble();
      if (snap.exists && valor != null && valor > 0) {
        final ts = snap.data()?['actualizadaEn'];
        return TasaBcv(
          valor: valor,
          fecha: ts is Timestamp ? ts.toDate() : DateTime.now(),
          origen: 'respaldo',
        );
      }
    } catch (e) {
      debugPrint('BCV: tampoco hay respaldo ($e)');
    }
    throw const TasaNoDisponible();
  }

  Future<void> _guardarRespaldo(TasaBcv tasa) async {
    try {
      await _refRespaldo.set({
        'valor': tasa.valor,
        'actualizadaEn': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      // El respaldo es una comodidad, no puede tumbar la reserva.
      debugPrint('BCV: no se pudo guardar el respaldo ($e)');
    }
  }
}
