// lib/features/orders/data/medical_order_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../domain/medical_order.dart';

/// Lectura y resolucion de las indicaciones medicas.
///
/// Viven como subcoleccion de la cita (`citas/{citaId}/ordenes`) para que
/// borrar o mover una cita se lleve consigo sus indicaciones, y se consultan en
/// grupo para la bandeja global de la secretaria.
class MedicalOrderService {
  MedicalOrderService({FirebaseFirestore? firestore, FirebaseAuth? auth})
      : _db = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _db;
  final FirebaseAuth _auth;

  CollectionReference<Map<String, dynamic>> _ordenesDe(String citaId) =>
      _db.collection('citas').doc(citaId).collection('ordenes');

  // ------------------------------------------------------------- consultas

  /// Indicaciones de una cita concreta, mas antiguas primero.
  Stream<List<MedicalOrder>> observarDeCita(String citaId) {
    if (citaId.isEmpty) return Stream.value(const <MedicalOrder>[]);
    return _ordenesDe(citaId).snapshots().map((s) {
      final lista = s.docs.map(MedicalOrder.fromDoc).toList()
        ..sort((a, b) => (a.creadaEn ?? DateTime(2000)).compareTo(b.creadaEn ?? DateTime(2000)));
      return lista;
    });
  }

  /// Bandeja global: todo lo que sigue pendiente, en toda la clinica.
  /// Esta es la pantalla que la secretaria realmente va a usar a diario;
  /// sin ella tendria que entrar paciente por paciente para saber que le falta.
  Stream<List<MedicalOrder>> observarPendientes({int limite = 200}) {
    return _db
        .collectionGroup('ordenes')
        .where('estado', isEqualTo: EstadoOrden.pendiente.key)
        .limit(limite)
        .snapshots()
        .map((s) {
      final lista = s.docs.map(MedicalOrder.fromDoc).toList();
      // Se ordena en memoria para no depender de un indice compuesto adicional:
      // primero lo vencido, luego por fecha sugerida, y al final lo que no tiene.
      lista.sort((a, b) {
        final fa = a.fechaSugerida;
        final fb = b.fechaSugerida;
        if (fa == null && fb == null) {
          return (a.creadaEn ?? DateTime(2000)).compareTo(b.creadaEn ?? DateTime(2000));
        }
        if (fa == null) return 1;
        if (fb == null) return -1;
        return fa.compareTo(fb);
      });
      return lista;
    });
  }

  /// Cuantas indicaciones sin resolver tiene cada cita de una lista.
  /// Se usa para pintar el contador naranja en la columna del historial.
  Future<Map<String, int>> contarPendientesPorCita(List<String> citaIds) async {
    final resultado = <String, int>{};
    // Firestore no permite una consulta de grupo filtrada por muchos padres,
    // asi que se piden en paralelo. Son pocas citas por paciente.
    await Future.wait(citaIds.map((id) async {
      try {
        final snap = await _ordenesDe(id)
            .where('estado', isEqualTo: EstadoOrden.pendiente.key)
            .count()
            .get();
        resultado[id] = snap.count ?? 0;
      } catch (_) {
        resultado[id] = 0;
      }
    }));
    return resultado;
  }

  // -------------------------------------------------------------- escritura

  /// Crea una indicacion. Mientras el panel de la doctora no exista, la
  /// secretaria puede crearlas ella misma y el circuito queda probado completo.
  Future<String> crear({
    required String citaId,
    required String patientId,
    required String patientName,
    required String representativeId,
    required TipoOrden tipo,
    required String descripcion,
    DateTime? fechaSugerida,
    String creadaPorNombre = '',
  }) async {
    final ref = _ordenesDe(citaId).doc();
    final orden = MedicalOrder(
      id: ref.id,
      citaId: citaId,
      patientId: patientId,
      patientName: patientName,
      representativeId: representativeId,
      tipo: tipo,
      descripcion: descripcion.trim(),
      estado: EstadoOrden.pendiente,
      fechaSugerida: fechaSugerida,
      creadaPor: _auth.currentUser?.uid ?? '',
      creadaPorNombre: creadaPorNombre,
    );
    await ref.set({
      ...orden.toJson(),
      'creadaEn': FieldValue.serverTimestamp(),
    });
    return ref.id;
  }

  /// Marca la orden como resuelta adjuntando el archivo subido.
  Future<void> resolverConArchivo({
    required MedicalOrder orden,
    required String url,
    required String nombre,
    required String ruta,
  }) async {
    await _ordenesDe(orden.citaId).doc(orden.id).update({
      'estado': EstadoOrden.hecha.key,
      'adjuntoUrl': url,
      'adjuntoNombre': nombre,
      'adjuntoRuta': ruta,
      'resueltaPor': _auth.currentUser?.uid ?? '',
      'resueltaEn': FieldValue.serverTimestamp(),
    });
  }

  /// Marca la orden de control como resuelta enlazando la cita creada.
  Future<void> resolverConCita({
    required MedicalOrder orden,
    required String citaGeneradaId,
  }) async {
    await _ordenesDe(orden.citaId).doc(orden.id).update({
      'estado': EstadoOrden.hecha.key,
      'citaGeneradaId': citaGeneradaId,
      'resueltaPor': _auth.currentUser?.uid ?? '',
      'resueltaEn': FieldValue.serverTimestamp(),
    });
  }

  Future<void> marcarHecha(MedicalOrder orden, {String? nota}) async {
    await _ordenesDe(orden.citaId).doc(orden.id).update({
      'estado': EstadoOrden.hecha.key,
      if (nota != null && nota.trim().isNotEmpty) 'notaSecretaria': nota.trim(),
      'resueltaPor': _auth.currentUser?.uid ?? '',
      'resueltaEn': FieldValue.serverTimestamp(),
    });
  }

  Future<void> omitir(MedicalOrder orden, String motivo) async {
    await _ordenesDe(orden.citaId).doc(orden.id).update({
      'estado': EstadoOrden.omitida.key,
      'notaSecretaria': motivo.trim(),
      'resueltaPor': _auth.currentUser?.uid ?? '',
      'resueltaEn': FieldValue.serverTimestamp(),
    });
  }

  Future<void> reabrir(MedicalOrder orden) async {
    await _ordenesDe(orden.citaId).doc(orden.id).update({
      'estado': EstadoOrden.pendiente.key,
      'resueltaPor': '',
      'resueltaEn': null,
    });
  }

  Future<void> eliminar(MedicalOrder orden) async {
    await _ordenesDe(orden.citaId).doc(orden.id).delete();
  }
}
