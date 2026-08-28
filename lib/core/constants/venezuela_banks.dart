// lib/core/constants/venezuela_banks.dart

/// Lista oficial de bancos emisores. Vive aqui y no dentro de un widget para
/// que el formulario del paciente y el de la secretaria usen exactamente la misma.
const List<String> kBancosVenezuela = <String>[
  'Banco de Venezuela (BDV)',
  'Banesco',
  'Banco Mercantil',
  'BBVA Provincial',
  'Banco Nacional de Credito (BNC)',
  'Bancamiga',
  'Banplus',
  'Bancaribe',
  'Banco Plaza',
  'Banco Exterior',
  'Banco del Tesoro',
  'Banco Bicentenario',
  'Banco Activo',
  'Banco Caroni',
  'Banco Sofitasa',
  'Venezolano de Credito',
  '100% Banco',
  'Mi Banco',
  'Bancrecer',
  'Banco de Exportacion y Comercio',
];

/// Normaliza un banco guardado antes de esta version para que siga
/// seleccionandose en el desplegable en vez de aparecer vacio.
String? normalizarBanco(String? guardado) {
  if (guardado == null || guardado.trim().isEmpty) return null;
  final limpio = guardado.trim();
  for (final banco in kBancosVenezuela) {
    if (banco.toLowerCase() == limpio.toLowerCase()) return banco;
  }
  const equivalencias = <String, String>{
    'banco de venezuela': 'Banco de Venezuela (BDV)',
    'mercantil': 'Banco Mercantil',
    'provincial': 'BBVA Provincial',
    'bnc': 'Banco Nacional de Credito (BNC)',
    'banco nacional de credito': 'Banco Nacional de Credito (BNC)',
    'banco nacional de crédito': 'Banco Nacional de Credito (BNC)',
  };
  return equivalencias[limpio.toLowerCase()];
}
