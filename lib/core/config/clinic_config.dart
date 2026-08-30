// lib/core/config/clinic_config.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Toda la configuracion operativa de la clinica en un solo lugar.
///
/// Antes el horario vivia en tres archivos con tres valores distintos (la
/// grilla generaba de 8 a 17, el ayudante traia 16 por defecto, el selector de
/// reprogramacion terminaba en 16:30 y la pagina de contacto prometia hasta las
/// 18) y la tarifa y los datos bancarios estaban escritos dentro de un widget.
/// Ahora se lee de `configuracion/clinica` y, si el documento no existe, se usa
/// este valor por defecto sin romper nada.
@immutable
class ClinicConfig {
  const ClinicConfig({
    required this.horaInicio,
    required this.horaFin,
    required this.minutosPorCita,
    required this.diasHabiles,
    required this.almuerzoInicio,
    required this.almuerzoFin,
    required this.tarifaUsd,
    required this.bancoReceptor,
    required this.telefonoPagoMovil,
    required this.cedulaReceptor,
    required this.numeroCuenta,
    required this.rif,
    required this.telefonoClinica,
    required this.direccion,
    required this.feriados,
  });

  /// Hora a la que abre la consulta (24h).
  final int horaInicio;

  /// Ultima hora en la que se puede agendar (24h, exclusiva).
  final int horaFin;
  final int minutosPorCita;

  /// 1 = lunes ... 7 = domingo, igual que DateTime.weekday.
  final List<int> diasHabiles;
  final int almuerzoInicio;
  final int almuerzoFin;

  final double tarifaUsd;
  final String bancoReceptor;
  final String telefonoPagoMovil;
  final String cedulaReceptor;
  final String numeroCuenta;
  final String rif;
  final String telefonoClinica;
  final String direccion;

  /// Fechas bloqueadas en formato yyyy-MM-dd.
  final List<String> feriados;

  static const ClinicConfig fallback = ClinicConfig(
    horaInicio: 8,
    horaFin: 17,
    minutosPorCita: 30,
    diasHabiles: [1, 2, 3, 4, 5],
    almuerzoInicio: 12,
    almuerzoFin: 13,
    tarifaUsd: 40.0,
    bancoReceptor: 'Banco Nacional de Credito (BNC)',
    telefonoPagoMovil: '0412-5555555',
    cedulaReceptor: 'V-12.345.678',
    numeroCuenta: '0191-0000-0000-0000-0000',
    rif: 'J-55555555-0',
    telefonoClinica: '+58 412-5555555',
    direccion: 'Av. Los Leones, Centro Profesional PediaActual, Piso 2. Barquisimeto.',
    feriados: <String>[],
  );

  /// Primer dia habil desde [desde] inclusive.
  ///
  /// Existe por un fallo concreto: los selectores de fecha abrian en "hoy" con
  /// un `selectableDayPredicate` que rechaza los dias no habiles, y Flutter
  /// tiene un assert que exige que la fecha inicial sea seleccionable. Abrir la
  /// agenda un domingo tumbaba el dialogo y dejaba la pantalla en blanco.
  DateTime proximoDiaHabil(DateTime desde) {
    var d = DateTime(desde.year, desde.month, desde.day);
    // El tope evita un bucle infinito si la configuracion queda sin dias
    // habiles o con un feriado por delante muy largo.
    for (var i = 0; i < 366; i++) {
      if (esDiaHabil(d)) {
        return d;
      }
      d = d.add(const Duration(days: 1));
    }
    return DateTime(desde.year, desde.month, desde.day);
  }

  bool esDiaHabil(DateTime dia) {
    if (!diasHabiles.contains(dia.weekday)) return false;
    return !feriados.contains(claveFecha(dia));
  }

  static String claveFecha(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  factory ClinicConfig.fromMap(Map<String, dynamic> m) {
    List<int> dias() {
      final raw = m['diasHabiles'];
      if (raw is List && raw.isNotEmpty) {
        return raw.map((e) => int.tryParse(e.toString()) ?? 0).where((e) => e >= 1 && e <= 7).toList();
      }
      return fallback.diasHabiles;
    }

    return ClinicConfig(
      horaInicio: (m['horaInicio'] as num?)?.toInt() ?? fallback.horaInicio,
      horaFin: (m['horaFin'] as num?)?.toInt() ?? fallback.horaFin,
      minutosPorCita: (m['minutosPorCita'] as num?)?.toInt() ?? fallback.minutosPorCita,
      diasHabiles: dias(),
      almuerzoInicio: (m['almuerzoInicio'] as num?)?.toInt() ?? fallback.almuerzoInicio,
      almuerzoFin: (m['almuerzoFin'] as num?)?.toInt() ?? fallback.almuerzoFin,
      tarifaUsd: (m['tarifaUsd'] as num?)?.toDouble() ?? fallback.tarifaUsd,
      bancoReceptor: m['bancoReceptor'] as String? ?? fallback.bancoReceptor,
      telefonoPagoMovil: m['telefonoPagoMovil'] as String? ?? fallback.telefonoPagoMovil,
      cedulaReceptor: m['cedulaReceptor'] as String? ?? fallback.cedulaReceptor,
      numeroCuenta: m['numeroCuenta'] as String? ?? fallback.numeroCuenta,
      rif: m['rif'] as String? ?? fallback.rif,
      telefonoClinica: m['telefonoClinica'] as String? ?? fallback.telefonoClinica,
      direccion: m['direccion'] as String? ?? fallback.direccion,
      feriados: (m['feriados'] as List?)?.map((e) => e.toString()).toList() ?? const <String>[],
    );
  }

  Map<String, dynamic> toMap() => {
        'horaInicio': horaInicio,
        'horaFin': horaFin,
        'minutosPorCita': minutosPorCita,
        'diasHabiles': diasHabiles,
        'almuerzoInicio': almuerzoInicio,
        'almuerzoFin': almuerzoFin,
        'tarifaUsd': tarifaUsd,
        'bancoReceptor': bancoReceptor,
        'telefonoPagoMovil': telefonoPagoMovil,
        'cedulaReceptor': cedulaReceptor,
        'numeroCuenta': numeroCuenta,
        'rif': rif,
        'telefonoClinica': telefonoClinica,
        'direccion': direccion,
        'feriados': feriados,
      };
}

/// Cache en memoria para no golpear Firestore en cada rebuild de la grilla.
class ClinicConfigService {
  ClinicConfigService({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;
  static ClinicConfig _cache = ClinicConfig.fallback;
  static bool _cargado = false;

  /// Ultima configuracion conocida. Siempre devuelve algo usable.
  static ClinicConfig get actual => _cache;

  DocumentReference<Map<String, dynamic>> get _ref =>
      _db.collection('configuracion').doc('clinica');

  Future<ClinicConfig> cargar({bool forzar = false}) async {
    if (_cargado && !forzar) return _cache;
    try {
      final snap = await _ref.get();
      if (snap.exists && snap.data() != null) {
        _cache = ClinicConfig.fromMap(snap.data()!);
      }
      _cargado = true;
    } catch (e) {
      debugPrint('ClinicConfig: no se pudo leer, se usa el valor por defecto. $e');
    }
    return _cache;
  }

  Stream<ClinicConfig> observar() => _ref.snapshots().map((snap) {
        if (snap.exists && snap.data() != null) {
          _cache = ClinicConfig.fromMap(snap.data()!);
          _cargado = true;
        }
        return _cache;
      });

  Future<void> guardar(ClinicConfig config) async {
    await _ref.set(config.toMap(), SetOptions(merge: true));
    _cache = config;
    _cargado = true;
  }
}
