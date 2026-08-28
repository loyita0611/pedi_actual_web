// lib/features/schedule/data/datasources/appointment_remote_data_source.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../../core/constants/app_status.dart';
import '../models/appointment_model.dart';

/// Se lanza cuando el horario dejo de estar libre entre que se pinto la grilla
/// y el momento de guardar.
class HorarioOcupadoException implements Exception {
  const HorarioOcupadoException();
  @override
  String toString() =>
      'Ese horario acaba de ser reservado por otra persona. Elige otro, por favor.';
}

abstract class AppointmentRemoteDataSource {
  Future<List<AppointmentModel>> getAppointmentsByDate(DateTime date);
  Future<List<AppointmentModel>> getAppointmentsByRepresentative(String uid);
  Future<List<AppointmentModel>> getAppointmentsByPatient(String patientId);

  /// Devuelve el id del documento de cita creado o actualizado.
  Future<String> bookAppointment(AppointmentModel appointment);

  Future<void> cancelAppointment(String appointmentId);
  Future<void> rescheduleAppointment(String appointmentId, DateTime nuevaFecha);
  Future<void> updateStatus(String appointmentId, CitaStatus status);
}

class AppointmentRemoteDataSourceImpl implements AppointmentRemoteDataSource {
  AppointmentRemoteDataSourceImpl({
    required this.firestore,
    FirebaseAuth? auth,
  }) : _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore firestore;
  final FirebaseAuth _auth;

  CollectionReference<Map<String, dynamic>> get _citas => firestore.collection('citas');
  CollectionReference<Map<String, dynamic>> get _patients => firestore.collection('patients');
  CollectionReference<Map<String, dynamic>> get _pagos => firestore.collection('pagos');

  // ------------------------------------------------------------- consultas

  @override
  Future<List<AppointmentModel>> getAppointmentsByDate(DateTime date) async {
    final inicio = DateTime(date.year, date.month, date.day);
    final fin = DateTime(date.year, date.month, date.day, 23, 59, 59, 999);

    final snap = await _citas
        .where('appointmentDateTime', isGreaterThanOrEqualTo: Timestamp.fromDate(inicio))
        .where('appointmentDateTime', isLessThanOrEqualTo: Timestamp.fromDate(fin))
        .get();

    return _mapear(snap);
  }

  @override
  Future<List<AppointmentModel>> getAppointmentsByRepresentative(String uid) async {
    final snap = await _citas
        .where('representativeId', isEqualTo: uid)
        .orderBy('appointmentDateTime', descending: true)
        .get();
    return _mapear(snap);
  }

  @override
  Future<List<AppointmentModel>> getAppointmentsByPatient(String patientId) async {
    final snap = await _citas
        .where('patientId', isEqualTo: patientId)
        .orderBy('appointmentDateTime', descending: true)
        .get();
    return _mapear(snap);
  }

  List<AppointmentModel> _mapear(QuerySnapshot<Map<String, dynamic>> snap) =>
      snap.docs.map((d) => AppointmentModel.fromJson(d.data(), d.id)).toList();

  // -------------------------------------------------------------- reservar

  /// Identificador determinista por horario: `2026-09-12_0830`.
  ///
  /// Es la pieza que impide la doble reserva. El cliente de Firestore no
  /// permite consultas por rango dentro de una transaccion, asi que en lugar de
  /// preguntar "hay algo a esta hora" se hace que la hora *sea* la llave del
  /// documento: dos personas guardando el mismo bloque chocan contra el mismo
  /// id y la transaccion resuelve el empate.
  static String idDeHorario(DateTime dt) {
    String dos(int n) => n.toString().padLeft(2, '0');
    return '${dt.year}-${dos(dt.month)}-${dos(dt.day)}_${dos(dt.hour)}${dos(dt.minute)}';
  }

  @override
  Future<String> bookAppointment(AppointmentModel appointment) async {
    final uid = _auth.currentUser?.uid ?? appointment.representativeId;
    final conDueno = AppointmentModel.fromEntity(
      appointment.copyWith(representativeId: appointment.representativeId.isNotEmpty
          ? appointment.representativeId
          : uid),
    );

    if (conDueno.id.isNotEmpty) {
      await _citas.doc(conDueno.id).set(conDueno.toJson(), SetOptions(merge: true));
      await _sincronizarPago(conDueno.id, conDueno);
      return conDueno.id;
    }

    // 1) Resolver el paciente ANTES de la transaccion.
    //    Antes se creaba un documento nuevo en `patients` en cada reserva,
    //    aunque el representante hubiera elegido un hijo ya existente; el
    //    directorio terminaba lleno de repetidos y el historial partido.
    final patientId = await _resolverPaciente(conDueno);

    // 2) Barrido previo contra citas antiguas, que tienen ids aleatorios y por
    //    lo tanto no chocan con el id determinista.
    await _verificarHorarioLibre(conDueno.appointmentDateTime);

    // 3) Escritura atomica.
    final citaRef = _citas.doc(idDeHorario(conDueno.appointmentDateTime));
    final pagoRef = _pagos.doc(conDueno.pagoId ?? _pagos.doc().id);

    final completa = AppointmentModel.fromEntity(
      conDueno.copyWith(patientId: patientId, pagoId: pagoRef.id),
    );

    await firestore.runTransaction((tx) async {
      final actual = await tx.get(citaRef);
      if (actual.exists) {
        final estado = CitaStatus.fromRaw(actual.data()?['status']);
        // Un horario cuya cita fue cancelada vuelve a estar disponible.
        if (estado != CitaStatus.cancelada) {
          throw const HorarioOcupadoException();
        }
      }

      tx.set(citaRef, {
        ...completa.toJson(),
        'createdAt': FieldValue.serverTimestamp(),
        'creadaPor': uid,
      });

      tx.set(pagoRef, completa.toPagoJson(citaRef.id));
    });

    return citaRef.id;
  }

  /// Devuelve el id del paciente, reutilizando el existente si lo hay.
  Future<String> _resolverPaciente(AppointmentModel cita) async {
    if (cita.patientId.isNotEmpty) {
      // Refresca los datos por si cambio la direccion o el telefono.
      await _patients.doc(cita.patientId).set(
            cita.toPatientJson()..remove('representativeId'),
            SetOptions(merge: true),
          );
      return cita.patientId;
    }

    // Segunda oportunidad: mismo representante y mismo nombre.
    if (cita.representativeId.isNotEmpty && cita.patientName.trim().isNotEmpty) {
      final existente = await _patients
          .where('representativeId', isEqualTo: cita.representativeId)
          .where('patientName', isEqualTo: cita.patientName.trim())
          .limit(1)
          .get();
      if (existente.docs.isNotEmpty) {
        final ref = existente.docs.first.reference;
        await ref.set(cita.toPatientJson(), SetOptions(merge: true));
        return ref.id;
      }
    }

    final nuevo = _patients.doc();
    await nuevo.set({
      ...cita.toPatientJson(),
      'createdAt': FieldValue.serverTimestamp(),
    });
    return nuevo.id;
  }

  Future<void> _verificarHorarioLibre(DateTime cuando) async {
    final snap = await _citas
        .where('appointmentDateTime', isEqualTo: Timestamp.fromDate(cuando))
        .limit(5)
        .get();

    final ocupado = snap.docs.any(
      (d) => CitaStatus.fromRaw(d.data()['status']) != CitaStatus.cancelada,
    );
    if (ocupado) throw const HorarioOcupadoException();
  }

  /// Mantiene el documento de `pagos` alineado cuando se edita una cita.
  Future<void> _sincronizarPago(String citaId, AppointmentModel cita) async {
    if (cita.pagoId == null || cita.pagoId!.isEmpty) return;
    await _pagos.doc(cita.pagoId!).set(
          cita.toPagoJson(citaId)..remove('date'),
          SetOptions(merge: true),
        );
  }

  // ------------------------------------------------------------- mutaciones

  @override
  Future<void> cancelAppointment(String appointmentId) async {
    await _citas.doc(appointmentId).update({
      'status': CitaStatus.cancelada.key,
      'canceladaEn': FieldValue.serverTimestamp(),
      'canceladaPor': _auth.currentUser?.uid,
    });
  }

  @override
  Future<void> rescheduleAppointment(String appointmentId, DateTime nuevaFecha) async {
    await _verificarHorarioLibre(nuevaFecha);
    await _citas.doc(appointmentId).update({
      'appointmentDateTime': Timestamp.fromDate(nuevaFecha),
      'fechaActualizacion': FieldValue.serverTimestamp(),
      'actualizadaPor': _auth.currentUser?.uid,
    });
  }

  @override
  Future<void> updateStatus(String appointmentId, CitaStatus status) async {
    await _citas.doc(appointmentId).update({
      'status': status.key,
      'fechaActualizacion': FieldValue.serverTimestamp(),
      'actualizadaPor': _auth.currentUser?.uid,
    });
  }
}
