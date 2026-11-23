




local CORE = [=[{{CORE}}]=]

local RUNNER = [==[{{RUNNER}}]==]

local compiled,err=loadstring(RUNNER)
if not compiled then error('[VolleyBomb v9.8] Erro de inicializacao: '..tostring(err)) end
local start=compiled()
start(nil,CORE,RUNNER)