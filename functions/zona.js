// functions/zona.js
//
// Conversiones de fecha en la zona horaria de la consulta.
//
// Viven aparte para poder probarlas: son la clase de codigo que parece obvio y
// falla en silencio. De hecho ya fallo una vez: las funciones corren en UTC y
// se sacaba la hora con getHours(), asi que una cita de las 8:00 se publicaba
// como ocupada a las 12:00 y la grilla no marcaba nada.

const ZONA = 'America/Caracas';

const _formato = new Intl.DateTimeFormat('en-CA', {
  timeZone: ZONA,
  year: 'numeric',
  month: '2-digit',
  day: '2-digit',
  hour: '2-digit',
  minute: '2-digit',
  hour12: false,
});

function partesEnZona(fecha) {
  const p = {};
  for (const parte of _formato.formatToParts(fecha)) {
    p[parte.type] = parte.value;
  }
  // A medianoche algunos entornos devuelven 24 en vez de 00.
  if (p.hour === '24') {
    p.hour = '00';
  }
  return p;
}

/// Clave del documento de disponibilidad: 2026-08-31.
function claveFecha(fecha) {
  const p = partesEnZona(fecha);
  return `${p.year}-${p.month}-${p.day}`;
}

/// Etiqueta del horario dentro del dia: 0830.
function claveHora(fecha) {
  const p = partesEnZona(fecha);
  return `${p.hour}${p.minute}`;
}

/// Desfase de la zona respecto de UTC, en minutos, para ese instante.
/// Se calcula en vez de escribirse a mano por si algun dia cambia.
function desfaseMinutos(fecha) {
  const p = partesEnZona(fecha);
  const comoSiFueraUtc = Date.UTC(+p.year, +p.month - 1, +p.day, +p.hour, +p.minute);
  const redondeado = Math.floor(fecha.getTime() / 60000) * 60000;
  return (comoSiFueraUtc - redondeado) / 60000;
}

/// Instantes de inicio y fin de un dia del calendario de la consulta.
function rangoDelDia(anio, mes, dia) {
  // Se tantea con el mediodia, que nunca cae en el borde de un cambio de hora.
  const tanteo = new Date(Date.UTC(anio, mes - 1, dia, 12));
  const desfase = desfaseMinutos(tanteo) * 60000;
  return {
    inicio: new Date(Date.UTC(anio, mes - 1, dia, 0, 0, 0, 0) - desfase),
    fin: new Date(Date.UTC(anio, mes - 1, dia, 23, 59, 59, 999) - desfase),
  };
}

module.exports = {ZONA, partesEnZona, claveFecha, claveHora, desfaseMinutos, rangoDelDia};
