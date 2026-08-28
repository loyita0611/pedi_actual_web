// lib/core/utils/search_utils.dart

const Map<String, String> _acentos = <String, String>{
  'á': 'a', 'à': 'a', 'ä': 'a', 'â': 'a', 'ã': 'a',
  'é': 'e', 'è': 'e', 'ë': 'e', 'ê': 'e',
  'í': 'i', 'ì': 'i', 'ï': 'i', 'î': 'i',
  'ó': 'o', 'ò': 'o', 'ö': 'o', 'ô': 'o', 'õ': 'o',
  'ú': 'u', 'ù': 'u', 'ü': 'u', 'û': 'u',
  'ñ': 'n', 'ç': 'c',
};

/// Firestore no sabe buscar ignorando mayusculas ni tildes: sus consultas de
/// rango son sensibles a ambas. Por eso cada paciente guarda, ademas del
/// nombre real, una version normalizada en `nombreBusqueda` y las busquedas
/// van contra ese campo.
String normalizarTexto(String valor) {
  var texto = valor.trim().toLowerCase();
  _acentos.forEach((acentuada, plana) => texto = texto.replaceAll(acentuada, plana));
  return texto.replaceAll(RegExp(r'\s+'), ' ');
}

/// Cota superior de una busqueda por prefijo. U+F8FF es el ultimo caracter
/// del area de uso privado, asi que el rango "jua" .. "jua"+U+F8FF atrapa a
/// "juan", "juana" y "juan carlos".
String cotaSuperior(String consulta) => '$consulta';
