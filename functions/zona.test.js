// functions/zona.test.js
//
// Se ejecuta con:  TZ=UTC node --test functions/
//
// La variable TZ es parte de la prueba, no un detalle: las funciones corren en
// UTC y el fallo que origino este archivo solo aparece ahi. En una maquina
// configurada en hora de Venezuela todo pasaba y en produccion no marcaba
// ningun horario como ocupado.

const test = require('node:test');
const assert = require('node:assert');

const {claveFecha, claveHora, desfaseMinutos, rangoDelDia} = require('./zona');

// Venezuela esta en UTC-4, asi que las 8:00 de la manana alla son las 12:00 UTC.
const citaOchoAm = new Date(Date.UTC(2026, 7, 31, 12, 0));
const citaCuatroYMedia = new Date(Date.UTC(2026, 7, 31, 20, 30));

test('la hora publicada es la de la consulta, no la del servidor', () => {
  assert.strictEqual(claveHora(citaOchoAm), '0800');
  assert.strictEqual(claveHora(citaCuatroYMedia), '1630');
});

test('la fecha publicada es la de la consulta', () => {
  assert.strictEqual(claveFecha(citaOchoAm), '2026-08-31');
  // El ultimo bloque del dia no se pasa al siguiente.
  assert.strictEqual(claveFecha(citaCuatroYMedia), '2026-08-31');
});

test('el desfase se calcula, no se supone', () => {
  assert.strictEqual(desfaseMinutos(citaOchoAm), -240);
});

test('el dia va de medianoche a medianoche en hora de la consulta', () => {
  const {inicio, fin} = rangoDelDia(2026, 8, 31);
  assert.strictEqual(inicio.toISOString(), '2026-08-31T04:00:00.000Z');
  assert.strictEqual(fin.toISOString(), '2026-09-01T03:59:59.999Z');
});

test('una cita del dia cae dentro de su propio rango', () => {
  const {inicio, fin} = rangoDelDia(2026, 8, 31);
  for (const cita of [citaOchoAm, citaCuatroYMedia]) {
    assert.ok(cita >= inicio && cita <= fin, `${cita.toISOString()} quedo fuera`);
  }
});

test('la primera y la ultima cita posibles no se escapan del dia', () => {
  const {inicio, fin} = rangoDelDia(2026, 8, 31);
  // Medianoche y un minuto antes de la medianoche siguiente, hora de Venezuela.
  const primerInstante = new Date(Date.UTC(2026, 7, 31, 4, 0));
  const ultimoInstante = new Date(Date.UTC(2026, 8, 1, 3, 59));
  assert.ok(primerInstante >= inicio);
  assert.ok(ultimoInstante <= fin);
  assert.strictEqual(claveFecha(primerInstante), '2026-08-31');
  assert.strictEqual(claveFecha(ultimoInstante), '2026-08-31');
});
