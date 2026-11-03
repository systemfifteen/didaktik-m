(function () {
  'use strict';
  var host = document.getElementById('jsspeccy');
  var msg = document.getElementById('msg');
  var statusEl = document.getElementById('status');
  var screen = document.getElementById('screen');
  var crt = document.getElementById('crt');

  function fail(text) {
    msg.textContent = text;
    msg.hidden = false;
    statusEl.textContent = 'chyba';
  }

  try {
    var narrow = window.matchMedia('(max-width: 720px)').matches;
    var emu = JSSpeccy(host, {
      machine: 48,
      zoom: narrow ? 1 : 2,
      autoLoadTapes: true,
      tapeAutoLoadMode: 'default'
    });
    emu.onReady(function () { statusEl.textContent = 'ZX Spectrum 48K · pripravený'; });
  } catch (e) {
    fail('Emulátor sa nepodarilo spustiť: ' + e.message);
  }

  function applyCrt() { screen.classList.toggle('crt-on', crt.checked); }
  crt.addEventListener('change', applyCrt);
  applyCrt();
})();
