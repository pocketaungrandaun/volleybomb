from pathlib import Path

root=Path(__file__).resolve().parent.parent
fps=(root/'src/10_fps_turbo.lua').read_text(encoding='utf-8')
process=fps.split('local function fpsProcess(inst)',1)[1].split('local function fpsLoadingHide()',1)[0]
decor=fps.split('local function fpsDecorOnly(inst,part)',1)[1].split('local fpsManualPlace=',1)[0]

assert process.index('fpsProtectBallVisual(inst)') < process.index('fpsIsManualSelection(inst)')
assert process.index('fpsRestoreMatchObject(inst)') < process.index('fpsIsManualSelection(inst)')
assert 'if part.Anchored then return true' not in decor
assert 'if not named then return false end' in decor
assert 'fpsMatchProtected(inst)' in decor
assert 'zone.CFrame:ToObjectSpace(part.CFrame)' in fps
assert 'for _,inst in ipairs(toRestore) do' in fps
assert 'for inst in pairs(FPS.HiddenOriginals) do' in fps
assert 'fpsHideTerrainWater()' in fps
assert 'fpsReplayCache(generation)' in fps
assert 'fpsManualTargets={' in fps
assert 'fpsLoadingShow()' in fps

ball=fps.split('local function fpsNormalizeBall(inst)',1)[1].split('local function fpsProtectedArena(part)',1)[0]
assert "fpsSetBallLook(inst,'Enabled',false)" not in ball
print('OK: protecao da arena e da bola precede remocao e cache')
