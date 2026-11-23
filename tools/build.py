#!/usr/bin/env python3
from pathlib import Path
import argparse
import re
import sys

ROOT = Path(__file__).resolve().parent.parent
PARTES = [
    'src/00_contexto.lua',
    'src/10_fps_turbo.lua',
    'src/20_previsao.lua',
    'src/30_controles_comuns.lua',
    'src/35_corte_direcional.lua',
    'src/40_dive_inteligente.lua',
    'src/50_interface.lua',
    'src/60_encerramento.lua'
]
TEMPLATE = ROOT / 'src' / 'modelo_lancador.lua.tpl'
RUNNER = ROOT / 'src' / '70_auto_inicio.lua'
DESTINO = ROOT / 'VolleyBombLanding.lua'

def montar():
    base = TEMPLATE.read_text(encoding='utf-8')
    assert base.count('{{CORE}}') == 1 and base.count('{{RUNNER}}') == 1
    core = ''.join((ROOT / caminho).read_text(encoding='utf-8') for caminho in PARTES)
    runner = RUNNER.read_text(encoding='utf-8')
    assert ']=]' not in core, 'CORE ultrapassou o delimitador Lua'
    assert ']==]' not in runner, 'RUNNER ultrapassou o delimitador Lua'
    versao = re.search(r"Version='([^']+)'", core)
    guarda = re.search(r"current\.Version~='([^']+)'", runner)
    if not versao or not guarda or versao.group(1) != guarda.group(1):
        raise ValueError('Versao do CORE e guarda do auto-inicio nao coincidem')
    return base.replace('{{CORE}}', core).replace('{{RUNNER}}', runner)

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--check', action='store_true', help='Confere se o script final foi gerado')
    args = parser.parse_args()
    resultado = montar()
    if args.check:
        if not DESTINO.exists() or DESTINO.read_text(encoding='utf-8') != resultado:
            print('O script gerado esta desatualizado. Rode python3 tools/build.py.', file=sys.stderr)
            raise SystemExit(1)
        print('OK: script final igual a soma dos modulos')
    else:
        DESTINO.write_text(resultado, encoding='utf-8')
        print(f'Gerado: {DESTINO} ({len(resultado)} caracteres)')

if __name__ == '__main__':
    main()
