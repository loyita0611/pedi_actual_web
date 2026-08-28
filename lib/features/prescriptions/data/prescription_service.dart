// lib/features/prescriptions/data/prescription_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:equatable/equatable.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../core/services/storage_service.dart';

class Prescription extends Equatable {
  const Prescription({
    required this.id,
    required this.patientId,
    required this.patientName,
    required this.fileName,
    required this.fileUrl,
    this.representativeId = '',
    this.filePath = '',
    this.sizeBytes = 0,
    this.citaId,
    this.ordenId,
    this.descripcion,
    this.createdAt,
  });

  final String id;
  final String patientId;
  final String patientName;

  /// Necesario para que las reglas de Firestore dejen que el representante
  /// lea las recetas de sus propios hijos y solo esas.
  final String representativeId;

  final String fileName;
  final String fileUrl;
  final String filePath;
  final int sizeBytes;
  final String? citaId;
  final String? ordenId;
  final String? descripcion;
  final DateTime? createdAt;

  factory Prescription.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? const <String, dynamic>{};
    return Prescription(
      id: doc.id,
      patientId: d['patientId'] as String? ?? '',
      patientName: d['patientName'] as String? ?? '',
      representativeId: d['representativeId'] as String? ?? '',
      fileName: d['fileName'] as String? ?? 'Receta.pdf',
      fileUrl: d['fileUrl'] as String? ?? '',
      filePath: d['filePath'] as String? ?? '',
      sizeBytes: (d['sizeBytes'] as num?)?.toInt() ?? 0,
      citaId: d['citaId'] as String?,
      ordenId: d['ordenId'] as String?,
      descripcion: d['descripcion'] as String?,
      createdAt: d['createdAt'] is Timestamp ? (d['createdAt'] as Timestamp).toDate() : null,
    );
  }

  String get tamanoLegible => StorageService.tamanoLegible(sizeBytes);

  @override
  List<Object?> get props => [id, patientId, fileUrl, createdAt];
}

class PrescriptionService {
  PrescriptionService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    StorageService? storage,
  })  : _db = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance,
        _storage = storage ?? StorageService();

  final FirebaseFirestore _db;
  final FirebaseAuth _auth;
  final StorageService _storage;

  CollectionReference<Map<String, dynamic>> get _col => _db.collection('prescriptions');

  /// Recetas de un paciente. Sin `orderBy` en la consulta: se ordena en memoria
  /// para no depender de un indice compuesto, que era justo lo que hacia que la
  /// pantalla mostrara "No hay documentos" cuando en realidad fallaba.
  Stream<List<Prescription>> observarDePaciente(String patientId) {
    if (patientId.isEmpty) return Stream.value(const <Prescription>[]);
    return _col.where('patientId', isEqualTo: patientId).snapshots().map(_ordenar);
  }

  /// Todas las recetas de los hijos del representante conectado.
  Stream<List<Prescription>> observarDeRepresentante(String uid) {
    if (uid.isEmpty) return Stream.value(const <Prescription>[]);
    return _col.where('representativeId', isEqualTo: uid).snapshots().map(_ordenar);
  }

  List<Prescription> _ordenar(QuerySnapshot<Map<String, dynamic>> s) {
    final lista = s.docs.map(Prescription.fromDoc).toList()
      ..sort((a, b) => (b.createdAt ?? DateTime(2000)).compareTo(a.createdAt ?? DateTime(2000)));
    return lista;
  }

  /// Sube el PDF y deja el registro enlazado al paciente y, si viene, a la cita.
  Future<Prescription> subir({
    required String patientId,
    required String patientName,
    required String representativeId,
    required PlatformFile archivo,
    String? citaId,
    String? ordenId,
    String? descripcion,
  }) async {
    final subido = await _storage.subirReceta(patientId: patientId, archivo: archivo);
    final ref = _col.doc();

    await ref.set({
      'patientId': patientId,
      'patientName': patientName,
      'representativeId': representativeId,
      'fileName': subido.nombre,
      'fileUrl': subido.url,
      'filePath': subido.ruta,
      'sizeBytes': subido.bytes,
      'citaId': citaId,
      'ordenId': ordenId,
      'descripcion': descripcion,
      'uploadedBy': _auth.currentUser?.uid ?? '',
      'createdAt': FieldValue.serverTimestamp(),
    });

    return Prescription(
      id: ref.id,
      patientId: patientId,
      patientName: patientName,
      representativeId: representativeId,
      fileName: subido.nombre,
      fileUrl: subido.url,
      filePath: subido.ruta,
      sizeBytes: subido.bytes,
      citaId: citaId,
      ordenId: ordenId,
      descripcion: descripcion,
      createdAt: DateTime.now(),
    );
  }

  Future<void> eliminar(Prescription receta) async {
    await _storage.borrar(ruta: receta.filePath, url: receta.fileUrl);
    await _col.doc(receta.id).delete();
  }
}
