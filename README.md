# VolleyBomb Landing

Código organizado em módulos de desenvolvimento, com uma distribuição em arquivo único.

## Estrutura

- `src/00_contexto.lua`: serviços Roblox, configuração e estados compartilhados.
- `src/10_fps_turbo.lua`: otimização visual e restauração.
- `src/20_previsao.lua`: BallState, previsão, rebotes, Tornado e indicadores.
- `src/30_controles_comuns.lua`: câmera, rotação e alvos.
- `src/35_corte_direcional.lua`: corte direcional.
- `src/40_dive_inteligente.lua`: Dive Inteligente e movimento.
- `src/50_interface.lua`: menu, botões e opções.
- `src/60_encerramento.lua`: limpeza, encerramento e X.
- `src/70_auto_inicio.lua`: entrada no servidor e fila de teleporte.
- `src/modelo_lancador.lua.tpl`: modelo do script final.
- `tools/build.py`: gerador do `VolleyBombLanding.lua`.

Os arquivos de `src/` são **partes de um mesmo escopo Lua**, não módulos para executar individualmente. Essa estratégia mantém as dependências e o comportamento existentes: o gerador reúne as partes num único arquivo pronto para Solara.

## Carregar a versão experimental

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/pocketaungrandaun/volleybomb/refactor/modulos/VolleyBombLanding.lua"))()
```

A versão principal continua disponível em `main`.

## Montar e validar

```bash
python3 tools/build.py
python3 tools/build.py --check
```

A verificação automática do GitHub confirma que o arquivo final corresponde aos módulos. Ela **não** substitui testes dentro do Roblox.

## Alteração pontual incluída

Corrigida a comparação de versão na inicialização (`9.7` -> `9.8`), para que o cancelamento por X e o Auto-Início possam ser registrados na v9.8.
