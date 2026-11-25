-- VolleyBomb AutoPlayer v1.0 - defesa experimental
-- Script separado: nao altera VolleyBombLanding.lua.
-- F6: liga/desliga. F7: encerra completamente.
-- Usa Ball + BallController originais para prever a queda e rebater.
-- Sem teleporte, sem fila automatica, sem saque ou ataque estrategico.

local Players=game:GetService('Players')
local ReplicatedStorage=game:GetService('ReplicatedStorage')
local RunService=game:GetService('RunService')
local UserInputService=game:GetService('UserInputService')
local Workspace=game:GetService('Workspace')
local VirtualUser=game:GetService('VirtualUser')
local player=Players.LocalPlayer
local env=_G
if type(getgenv)=='function' then
    local ok,value=pcall(getgenv)
    if ok and type(value)=='table' then env=value end
end
if type(env.VolleyBombAutoPlayer)=='table' and type(env.VolleyBombAutoPlayer.Stop)=='function' then
    pcall(env.VolleyBombAutoPlayer.Stop)
end

local config={
    Enabled=true,
    AutoMove=true,
    AutoHit=true,
    AutoDive=true,
    AntiIdle=true,
    Main=true,
    Practice=true,
    MaxChaseDistance=50,
    MaxForecastSeconds=3.6,
    WalkStopDistance=3.9,
    DiveMaxDistance=28,
    DiveCooldown=1.4,
    HitCooldown=0.32,
    DecisionInterval=0.10,
}
local okBall,Ball=pcall(function()
    return require(ReplicatedStorage:WaitForChild('Shared',12)
        :WaitForChild('Modules',12):WaitForChild('Ball',12))
end)
local okController,Controller=pcall(function()
    return require(ReplicatedStorage:WaitForChild('Shared',12)
        :WaitForChild('Controllers',12):WaitForChild('BallController',12))
end)
if not okBall or type(Ball)~='table' or type(Ball.At)~='function'
    or type(Ball.Bounce)~='function' or type(Ball.ZoneAt)~='function'
    or not okController or type(Controller)~='table' then
    warn('[VolleyBomb AutoPlayer] Modulos locais Ball/BallController indisponiveis.')
    return
end

local links={}
local stopped=false
local status='INICIANDO'
local activeArena=nil
local destination=nil
local arrival=nil
local movement=nil
local movementPausedUntil=0
local lastDecision=0
local lastHit=0
local lastDive=-math.huge
local lastState=nil
local lastStateArena=nil
local cachedPrediction=nil
local diveCapability='nao testado'
local ui,indicator

local function character()
    local ch=player.Character
    if not ch then return end
    local root=ch:FindFirstChild('HumanoidRootPart')
    local hum=ch:FindFirstChildOfClass('Humanoid')
    if not root or not hum or hum.Health<=0 or root.Anchored then return end
    return root,hum
end

local function flatDelta(a,b)
    local v=Vector3.new(b.X-a.X,0,b.Z-a.Z)
    if v.Magnitude<0.05 then return nil,0 end
    return v.Unit,v.Magnitude
end

local function validZone(z)
    return typeof(z)=='Instance' and z:IsA('BasePart') and z.Parent~=nil
end

local function zoneAt(zones,point,margin)
    if type(zones)~='table' then return nil end
    local chosen,best=nil,math.huge
    for _,part in pairs(zones) do
        if validZone(part) then
            local p=part.CFrame:PointToObjectSpace(point)
            local dx=math.abs(p.X)-part.Size.X*0.5
            local dz=math.abs(p.Z)-part.Size.Z*0.5
            if dx<=(margin or 0) and dz<=(margin or 0) then
                local area=part.Size.X*part.Size.Z
                if area<best then
                    chosen,best=part,area
                end
            end
        end
    end
    return chosen
end

local function chosenArena(root)
    local entries=Controller._balls
    if type(entries)~='table' then return nil end
    local attr=player:GetAttribute('InRound')
    if (attr=='Main' or attr=='Practice') and config[attr] then
        local item=entries[attr]
        if item and type(item.State)=='table'
            and zoneAt(item.Zones or item.State.Zones,root.Position,3) then
            return attr,item
        end
    end
    for _,arena in ipairs({'Main','Practice'}) do
        local item=entries[arena]
        if config[arena] and item and type(item.State)=='table'
            and zoneAt(item.Zones or item.State.Zones,root.Position,2) then
            return arena,item
        end
    end
    return nil
end

local function forecast(state,now)
    if type(state)~='table' or state.Dead or state.Magnet or state.Tornado
        or state.Frozen then return nil end
    local current=state
    for _=1,5 do
        if type(current.EndTime)~='number'
            or type(current.Time)~='number'
            or current.EndTime~=current.EndTime
            or current.EndTime==math.huge
            or current.EndTime<=current.Time+0.015
            or current.EndTime<=now-0.03
            or current.EndTime>now+config.MaxForecastSeconds then
            return nil
        end
        local ok,p=pcall(Ball.At,current,current.EndTime)
        if not ok or typeof(p)~='Vector3' then return nil end
        if current.Reflect then
            local success,nextState=pcall(Ball.Bounce,current)
            if not success or type(nextState)~='table'
                or type(nextState.EndTime)~='number'
                or nextState.EndTime<=current.EndTime+0.015 then
                return nil
            end
            current=nextState
        else
            if typeof(current.Normal)~='Vector3'
                or current.Normal.Y<0.88 then return nil end
            local good,ground=pcall(Ball.Ground,p)
            if not good or typeof(ground)~='Vector3'
                or math.abs(p.Y-ground.Y)>7 then return nil end
            return {Point=ground,Time=current.EndTime,State=current}
        end
    end
    return nil
end

local function predictionFor(state,arena,now)
    if lastState~=state or lastStateArena~=arena then
        lastState=state
        lastStateArena=arena
        cachedPrediction=forecast(state,now)
    end
    local p=cachedPrediction
    if not p or p.Time<now-0.04 then return nil end
    return p
end

local function isOwnCourt(item,root,target)
    local zones=item.Zones or item.State.Zones
    local ours=zoneAt(zones,root.Position,2.5)
    local theirs=zoneAt(zones,target,0.4)
    if not ours or not theirs then return false end
    -- Restrito a propria zona. Evita correr para a quadra do adversario
    -- ou roubar a bola do colega no modo Duos.
    return ours==theirs
end

local function obstacle(root,dir,dist)
    local ray=RaycastParams.new()
    ray.FilterType=Enum.RaycastFilterType.Exclude
    local exclude={}
    if player.Character then table.insert(exclude,player.Character) end
    if ui then table.insert(exclude,ui) end
    ray.FilterDescendantsInstances=exclude
    local ok,hit=pcall(function()
        return Workspace:Raycast(root.Position+Vector3.new(0,0.5,0),
            dir*math.min(dist,3.5),ray)
    end)
    return ok and hit and math.abs(hit.Normal.Y)<0.6 and hit.Distance<3.3
end

-- Aciona o dive pelo controle normal do cliente. Nao invoca remotes
-- desconhecidos nem falsifica pacotes do servidor.
local function sendDiveKey()
    local okVim,VirtualInputManager=pcall(function()
        return game:GetService('VirtualInputManager')
    end)
    if okVim and VirtualInputManager then
        local ok=pcall(function()
            VirtualInputManager:SendKeyEvent(true,Enum.KeyCode.E,false,game)
        end)
        if ok then
            task.delay(0.075,function()
                pcall(function()
                    VirtualInputManager:SendKeyEvent(false,Enum.KeyCode.E,false,game)
                end)
            end)
            diveCapability='VirtualInputManager'
            return true
        end
    end
    local press=(type(keypress)=='function' and keypress)
        or (type(env.keypress)=='function' and env.keypress)
    local release=(type(keyrelease)=='function' and keyrelease)
        or (type(env.keyrelease)=='function' and env.keyrelease)
    if press and release then
        local ok=pcall(press,0x45)
        if ok then
            task.delay(0.075,function() pcall(release,0x45) end)
            diveCapability='keypress'
            return true
        end
    end
    diveCapability='sem simulacao E (executor)'
    return false
end

local function autoSwing(item,root,now)
    if not config.AutoHit or now-lastHit<config.HitCooldown then return end
    local state=item.State
    if not state or state.Dead or state.Server or state.Magnet then return end
    if type(state.Time)~='number' or type(state.EndTime)~='number'
        or now>state.EndTime+0.05 then return end
    local ok,p=pcall(Ball.At,state,now)
    if not ok or typeof(p)~='Vector3' then return end
    local zones=item.Zones or state.Zones
    if not zoneAt(zones,p,0.6)
        or not isOwnCourt(item,root,p) then return end
    local reach=(Ball.Ranges and Ball.Ranges.Bump or 7)+
        (Ball.Radius or 1.5)
    if (p-root.Position).Magnitude>reach+0.1 then return end
    if type(Controller.Swing)~='function' then return end
    lastHit=now
    local success,err=pcall(function() Controller:Swing() end)
    if not success then
        warn('[VolleyBomb AutoPlayer] Swing falhou: '..tostring(err))
    else
        status='REBATENDO'
    end
end

local function tryAutoDive(root,hum,point,dist,remaining,now)
    if not config.AutoDive or now-lastDive<config.DiveCooldown then
        return false
    end
    if remaining<0.08 or remaining>0.55
        or dist<9 or dist>config.DiveMaxDistance then return false end
    local walkSpeed=math.max(8,hum.WalkSpeed)
    local walkingReach=walkSpeed*math.max(0,remaining-0.10)+7.8
    if dist<=walkingReach+1.5 then return false end
    local lead=math.clamp(dist/100+0.19,0.26,0.52)
    if remaining>lead then return false end
    local dir=flatDelta(root.Position,point)
    if not dir or obstacle(root,dir,math.min(dist,3)) then return false end
    -- Caso o Smart Dive principal esteja ativo, ele vai corrigir o E.
    -- Caso nao esteja, mira para o local previsto antes do dive nativo.
    local main=env.VolleyBombLanding
    local mainDive=type(main)=='table'
        and type(main.Config)=='table' and main.Config.SmartDive==true
    if not mainDive then
        root.CFrame=CFrame.lookAt(root.Position,root.Position+dir)
    end
    if sendDiveKey() then
        lastDive=now
        movementPausedUntil=os.clock()+0.82
        movement=nil
        destination=nil
        status='MERGULHANDO'
        return true
    end
    return false
end

local function decide()
    if stopped or not config.Enabled then
        movement=nil
        return
    end
    local root,hum=character()
    if not root then
        movement=nil
        status='SEM PERSONAGEM'
        return
    end
    local arena,item=chosenArena(root)
    activeArena=arena
    if not item or not item.State then
        movement=nil
        status='AGUARDANDO PARTIDA'
        return
    end
    local now=Workspace:GetServerTimeNow()
    local state=item.State
    autoSwing(item,root,now)
    if now<movementPausedUntil then
        movement=nil
        return
    end
    if state.Server or state.Dead or state.Magnet or state.Tornado then
        movement=nil
        status='AGUARDANDO BOLA'
        return
    end
    local predicted=predictionFor(state,arena,now)
    if not predicted or not isOwnCourt(item,root,predicted.Point) then
        movement=nil
        status='SEM BOLA NA SUA ZONA'
        return
    end
    local dir,dist=flatDelta(root.Position,predicted.Point)
    local remaining=predicted.Time-now
    destination=predicted.Point
    arrival=predicted.Time
    if not dir then
        movement=nil
        return
    end
    if dist>config.MaxChaseDistance or remaining<0.02 then
        movement=nil
        status='FORA DE ALCANCE'
        return
    end
    if tryAutoDive(root,hum,predicted.Point,dist,remaining,now) then
        return
    end
    if config.AutoMove and dist>config.WalkStopDistance
        and not obstacle(root,dir,math.min(dist,3)) then
        movement=dir
        status='POSICIONANDO ('..arena..')'
    else
        movement=nil
        status='PRONTO PARA RECEBER'
    end
end

local function createUI()
    local parent=player:WaitForChild('PlayerGui')
    if type(gethui)=='function' then
        local ok,holder=pcall(gethui)
        if ok and typeof(holder)=='Instance' then parent=holder end
    end
    ui=Instance.new('ScreenGui')
    ui.Name='VolleyBombAutoPlayerUI'
    ui.IgnoreGuiInset=true
    ui.ResetOnSpawn=false
    ui.DisplayOrder=250
    ui.Parent=parent
    local panel=Instance.new('Frame')
    panel.Name='Status'
    panel.AnchorPoint=Vector2.new(1,0)
    panel.Position=UDim2.new(1,-14,0,18)
    panel.Size=UDim2.fromOffset(244,74)
    panel.BackgroundColor3=Color3.fromRGB(27,30,35)
    panel.BackgroundTransparency=0.23
    panel.BorderSizePixel=0
    panel.Parent=ui
    local corner=Instance.new('UICorner')
    corner.CornerRadius=UDim.new(0,10)
    corner.Parent=panel
    local title=Instance.new('TextLabel')
    title.BackgroundTransparency=1
    title.Position=UDim2.fromOffset(10,6)
    title.Size=UDim2.fromOffset(226,25)
    title.Font=Enum.Font.GothamBold
    title.TextSize=13
    title.TextXAlignment=Enum.TextXAlignment.Left
    title.TextColor3=Color3.fromRGB(236,247,240)
    title.Text='AUTOPLAYER • DEFESA'
    title.Parent=panel
    indicator=Instance.new('TextLabel')
    indicator.BackgroundTransparency=1
    indicator.Position=UDim2.fromOffset(10,30)
    indicator.Size=UDim2.fromOffset(226,36)
    indicator.Font=Enum.Font.GothamMedium
    indicator.TextSize=11
    indicator.TextWrapped=true
    indicator.TextXAlignment=Enum.TextXAlignment.Left
    indicator.TextYAlignment=Enum.TextYAlignment.Top
    indicator.TextColor3=Color3.fromRGB(185,236,208)
    indicator.Parent=panel
end
createUI()

local function updateStatus()
    if not indicator then return end
    indicator.Text=config.Enabled
        and (status..'\nF6: PAUSAR   F7: ENCERRAR')
        or 'PAUSADO\nF6: ATIVAR   F7: ENCERRAR'
    indicator.TextColor3=config.Enabled
        and Color3.fromRGB(185,236,208)
        or Color3.fromRGB(255,211,157)
end

local function stop()
    if stopped then return end
    stopped=true
    config.Enabled=false
    movement=nil
    for _,c in ipairs(links) do pcall(function() c:Disconnect() end) end
    if ui then ui:Destroy() ui=nil end
    if type(env.VolleyBombAutoPlayer)=='table'
        and env.VolleyBombAutoPlayer.Version=='1.0' then
        env.VolleyBombAutoPlayer=nil
    end
    print('[VolleyBomb AutoPlayer] Encerrado.')
end

links[#links+1]=UserInputService.InputBegan:Connect(function(input,processed)
    if processed or UserInputService:GetFocusedTextBox() then return end
    if input.KeyCode==Enum.KeyCode.F6 then
        config.Enabled=not config.Enabled
        movement=nil
        status=config.Enabled and 'RETOMANDO' or 'PAUSADO'
        updateStatus()
    elseif input.KeyCode==Enum.KeyCode.F7 then
        stop()
    end
end)

-- Posicionamento por Humanoid:Move, nao teleporte nem escrita de CFrame.
-- Apos o controle padrao do PlayerModule para nao ser sobrescrito.
local renderName='VolleyBombAutoDefense_'..tostring(player.UserId)
RunService:BindToRenderStep(renderName,Enum.RenderPriority.Input.Value+4,function()
    if stopped or not config.Enabled or not movement
        or os.clock()<movementPausedUntil then return end
    local root,hum=character()
    if not root then return end
    hum:Move(movement,false)
end)

local rawStop=stop
stop=function()
    if stopped then return end
    RunService:UnbindFromRenderStep(renderName)
    rawStop()
end

-- O jogo pode reduzir FPS/minimizar em segundo plano, portanto nao
-- prometemos que a automacao continue com o cliente suspenso.
links[#links+1]=RunService.Heartbeat:Connect(function()
    if stopped then return end
    local now=os.clock()
    if now-lastDecision>=config.DecisionInterval then
        lastDecision=now
        local ok,err=pcall(decide)
        if not ok then
            movement=nil
            status='ERRO (VER CONSOLE)'
            warn('[VolleyBomb AutoPlayer] '..tostring(err))
        end
    end
end)

links[#links+1]=player.Idled:Connect(function()
    if stopped or not config.Enabled or not config.AntiIdle then return end
    pcall(function()
        VirtualUser:CaptureController()
        VirtualUser:ClickButton2(Vector2.zero)
    end)
end)

local lastUI=0
links[#links+1]=RunService.Heartbeat:Connect(function()
    if stopped then return end
    if os.clock()-lastUI>0.45 then
        lastUI=os.clock()
        updateStatus()
    end
end)

env.VolleyBombAutoPlayer={
    Stop=function() stop() end,
    Config=config,
    Version='1.0',
    Status=function() return status end,
    DiveCapability=function() return diveCapability end,
}
print('[VolleyBomb AutoPlayer v1.0] Defesa ON. F6 pausa/ativa; F7 encerra. '..
    'Teste primeiro em ambiente privado. Saque/ataque automaticos ainda nao incluidos.')
updateStatus()
