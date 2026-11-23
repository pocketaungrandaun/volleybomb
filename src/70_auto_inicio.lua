
return function(expectedUniverse, core, runner)
    if not game:IsLoaded() then game.Loaded:Wait() end
    local universe = game.GameId
    if type(universe) ~= 'number' or universe == 0 then
        warn('[VolleyBomb v9.8] Nao foi possivel reconhecer o universo do jogo.')
        return
    end
    if expectedUniverse and expectedUniverse ~= universe then
        warn('[VolleyBomb v9.8] Outro jogo detectado. Autoexecucao ignorada.')
        return
    end
    local replicated = game:GetService('ReplicatedStorage')
    local packages = replicated:FindFirstChild('Packages')
        or replicated:WaitForChild('Packages', 25)
    local net = packages and (packages:FindFirstChild('Net')
        or packages:WaitForChild('Net', 25))
    local ballState = net and (net:FindFirstChild('RE/BallState')
        or net:WaitForChild('RE/BallState', 25))
    if not ballState or not ballState:IsA('RemoteEvent') then
        warn('[VolleyBomb v9.8] Estrutura do VolleyBomb nao encontrada; nada sera carregado.')
        return
    end

    local environ = _G
    if type(getgenv)=='function' then
        local ok,e=pcall(getgenv)
        if ok and type(e)=='table' then environ=e end
    end

    local function getTeleportQueue()
        if type(queue_on_teleport)=='function' then return queue_on_teleport end
        if type(queueonteleport)=='function' then return queueonteleport end
        if type(queue_on_tp)=='function' then return queue_on_tp end
        if type(queueteleport)=='function' then return queueteleport end
        if type(syn)=='table' and type(syn.queue_on_teleport)=='function' then
            return syn.queue_on_teleport
        end
        return nil
    end
    local function getTeleportClear()
        if type(clearqueueonteleport)=='function' then return clearqueueonteleport end
        if type(clearteleportqueue)=='function' then return clearteleportqueue end
        if type(clear_teleport_queue)=='function' then return clear_teleport_queue end
        if type(clear_tp_queue)=='function' then return clear_tp_queue end
        if type(cleartpqueue)=='function' then return cleartpqueue end
        if type(syn)=='table' then
            if type(syn.clearqueueonteleport)=='function' then
                return syn.clearqueueonteleport
            end
            if type(syn.clear_teleport_queue)=='function' then
                return syn.clear_teleport_queue
            end
        end
        return nil
    end
    local function clearQueuedTeleports()
        local clear=getTeleportClear()
        if not clear then return false,'Executor nao oferece funcao para limpar fila.' end
        local ok,err=pcall(clear)
        if ok then
            environ.VolleyBombLandingTeleportQueued=nil
            return true
        end
        return false,tostring(err)
    end

    
    
    local compiled,err=loadstring(core)
    if not compiled then
        warn('[VolleyBomb v9.8] Erro ao ler codigo principal: '..tostring(err))
        return
    end
    local ok,runtimeErr=pcall(compiled)
    if not ok then
        warn('[VolleyBomb v9.8] Erro na execucao: '..tostring(runtimeErr))
        return
    end

    local current=environ.VolleyBombLanding
    if type(current)~='table' or current.Version~='9.8' then return end

    
    
    current.CancelTeleport=function()
        local success,message=clearQueuedTeleports()
        if success then
            print('[VolleyBomb v9.8] X: Auto-inicio desligado e fila de teleportes limpa.')
        else
            warn('[VolleyBomb v9.8] Nao foi possivel cancelar o auto-inicio: '..tostring(message))
        end
        return success
    end

    
    
    local cleared,why=clearQueuedTeleports()
    if not cleared then
        warn('[VolleyBomb v9.8] Nao deu para limpar copias antigas: '..tostring(why))
    end

    local queue=getTeleportQueue()
    if not queue then
        warn('[VolleyBomb v9.8] Executor nao tem queue_on_teleport. Auto-inicio indisponivel.')
        return
    end

    local queuedCode=string.format([=[
local expectedUniverse = %d
local core = %q
local runner = %q
local compiler, errorMessage = loadstring(runner)
if not compiler then
    warn('[VolleyBomb v9.8] Erro no auto-inicio: '..tostring(errorMessage))
else
    local success, launch = pcall(compiler)
    if success and type(launch)=='function' then
        launch(expectedUniverse, core, runner)
    else
        warn('[VolleyBomb v9.8] Auto-inicio indisponivel: '..tostring(launch))
    end
end
]=], universe, core, runner)
    local registered,queueErr=pcall(queue,queuedCode)
    if registered then
        environ.VolleyBombLandingTeleportQueued=
            tostring(universe)..'/'..tostring(game.JobId)..'/v9.8'
        print('[VolleyBomb v9.8] Auto-inicio preparado. X cancela o proximo servidor.')
    else
        warn('[VolleyBomb v9.8] Falha ao preparar proximo servidor: '..tostring(queueErr))
    end
end
