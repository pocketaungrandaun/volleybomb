-- VOLLEYBOMB LANDING v9.8 / AUTO-INICIO CANCELAVEL NO X (SOLARA)
-- Execute no VolleyBomb. Ao clicar X, para o script e cancela a fila de teleportes.
-- Ao iniciar uma versao nova, limpa a fila antiga antes de registrar o novo auto-inicio.
-- Nao depende de URL externa ou arquivo salvo do script no executor.

local CORE = [=[-- VOLLEYBOMB LANDING v9.8
-- Previsao conservadora: rejeita pontos incoerentes e ignora props ocultos.
-- Chao final / sem texto sobre indicador / Dive v8.0 intacto / FPS / Auto-Inicio
-- Preferencias salvas automaticamente (arquivo se disponivel).

local P=game:GetService('Players')
local R=game:GetService('ReplicatedStorage')
local Run=game:GetService('RunService')
local U=game:GetService('UserInputService')
local CAS=game:GetService('ContextActionService')
local T=game:GetService('TweenService')
local W=game:GetService('Workspace')
local Http=game:GetService('HttpService')
local me=P.LocalPlayer
local C={Main=true,Practice=true,LockOn=false,SmartDive=false,
    Radius=3.1,MainColor=Color3.fromRGB(75,255,150),
    PracticeColor=Color3.fromRGB(85,200,255),
    DiveLead=0.55,MinLead=0.15,MaxLead=1.5,
    MinSpeed=52,MinFall=5,MaxError=1.2,
    DiveReach=24,DiveSpeed=100,DiveCooldown=1.2,
    ChaseRange=85,ChaseWindow=3.5,StopDistance=11,
    AimDelay=0.06,InputDelay=0.065,LockSpeed=9,
    SafetyLead=0.08, MinNativeLead=0.24,
    -- Espera por bola futura: independente do ajuste de antecipacao.
    -- Defesa manual imediata: nao espera o tempo de queda.
    MaxEarlyWait=5.2, EmergencyWindow=0.020,
    SteerDive=true, -- direcao do dive baseada no marcador congelado
    SpikeDirection=false,SpikeKey='X',
    FPSBoost=true}
local env=_G
if type(getgenv)=='function' then
    local ok,e=pcall(getgenv)
    if ok and type(e)=='table' then env=e end
end
-- Preferencias estaveis: alternancias, tempo interno e posicoes da UI.
local saveFile='VolleyBombLanding_settings.json'
local savedKeys={'LockOn','SmartDive',
    'DiveLead','SpikeDirection','SpikeKey','FPSBoost'}
local uiPrefs={}
local saveLocation='sessao'
local hasV65Preferences=false

local function loadSettings(data)
    if type(data)~='table' then return end
    if data.Version=='6.5' or data.Version=='6.6' or data.Version=='6.7' or data.Version=='6.8' or data.Version=='6.9' or data.Version=='7.0' or data.Version=='7.1' or data.Version=='7.2' or data.Version=='7.3' or data.Version=='7.4' or data.Version=='7.5' or data.Version=='7.6' or data.Version=='7.7' or data.Version=='7.8' or data.Version=='7.9' or data.Version=='8.0' or data.Version=='8.1' or data.Version=='8.2' or data.Version=='8.3' or data.Version=='8.4' or data.Version=='8.5' or data.Version=='8.6' or data.Version=='8.8' or data.Version=='8.9' or data.Version=='9.0' or data.Version=='9.1' or data.Version=='9.2' or data.Version=='9.3' or data.Version=='9.4' or data.Version=='9.5' or data.Version=='9.6' or data.Version=='9.7' or data.Version=='9.8' then hasV65Preferences=true end
    for _,key in ipairs(savedKeys) do
        local value=data[key]
        if key=='DiveLead' then
            if type(value)=='number' and value==value then
                C[key]=math.clamp(value,C.MinLead,C.MaxLead)
            end
        elseif key=='SpikeKey' then
            -- Teclas de letra; evitar E, movimento e teclas de camera.
            if type(value)=='string' and value:match('^[A-Z]$')
                and not string.find('WASDE',value,1,true) then
                C.SpikeKey=value
            end
        elseif type(value)=='boolean' then
            C[key]=value
        end
    end
    if type(data.UI)=='table' then
        for _,key in ipairs({'IconX','IconY','PanelX','PanelY'}) do
            local v=data.UI[key]
            if type(v)=='number' and v==v and math.abs(v)<100000 then
                uiPrefs[key]=v
            end
        end
    end
end

-- Preferencia da sessao e arquivo do executor, se ele tiver readfile.
loadSettings(env.VolleyBombLandingSettings)
if type(readfile)=='function' then
    pcall(function()
        if type(isfile)~='function' or isfile(saveFile) then
            loadSettings(Http:JSONDecode(readfile(saveFile)))
        end
    end)
end

local old=env.VolleyBombLanding
if type(old)=='table' then
    -- O script que ainda esta aberto tem valores mais recentes.
    loadSettings(old.Config)
    if type(old.UI)=='table' then loadSettings({UI=old.UI}) end
    if type(old.Stop)=='function' then pcall(old.Stop,'replace') end
end
-- Indicadores sempre automaticos: preferencia antiga de Main/Practice nao se aplica.
C.Main=true
C.Practice=true
-- v8.0: E passa intacto; velocidade/frenagem com vetor congelado, sem curvas.
C.SteerDive=true

local function saveSettings()
    local data={Version='9.8',UI={}}
    for _,key in ipairs(savedKeys) do data[key]=C[key] end
    for _,key in ipairs({'IconX','IconY','PanelX','PanelY'}) do
        data.UI[key]=uiPrefs[key]
    end
    env.VolleyBombLandingSettings=data
    saveLocation='sessao'
    if type(writefile)=='function' then
        local ok=pcall(function()
            writefile(saveFile,Http:JSONEncode(data))
        end)
        if ok and type(readfile)=='function' then saveLocation='arquivo' end
    end
    return saveLocation
end

local event=R:WaitForChild('Packages'):WaitForChild('Net'):WaitForChild('RE/BallState')
local folder=Instance.new('Folder')
folder.Name='VolleyLanding85'
folder.Parent=W
local links,states,markers={},{},{}
local zones={Main={},Practice={}}
local owned={Main={},Practice={}}
local areaAttempt={Main=false,Practice=false}
local stopped=false
local rotHum,rotOriginal=nil,nil
local aimTarget,pending=nil,nil
local diveAnimations={}
local lastPhysicalPress=-math.huge
local lastNativeStart=-math.huge
local learnedDiveProfile={}
local profileSample=nil
local diveAnimating=false
local lastDecision='Aguardando E'
local aimUntil,blockMoveUntil=0,0
local lastDive,lastID=-math.huge,nil
local sample=nil
local measuredSpeed=nil
local ping=0.08
local lastPing=0
local renderKey='VolleyLanding85_Render'
local spikeActionKey='VolleyLanding85_Spike'
local actionKey='VolleyLanding85_E'
local inputBound=false
local refreshSmart
local steerTarget=nil
local steerDirection=nil -- Vetor fixo durante o impulso, sem curvas bruscas
local steerUntil=0
local steerActive=false
local lastSteerDistance=nil
local steerPathLength=0 -- comprimento da linha congelada na hora do E
local steerAnimationSeen=false
local steerArmedAt=0
local steerStarted=false       -- somente apos o jogo realmente iniciar o dive
local steerDetectedAt=0
local steerStartSource=''
local steerStartPosition=nil
local activePressAt=0
local liveTracks={Main={Samples={},Next=0},Practice={Samples={},Next=0}}

local function make(class,properties,parent)
    local o=Instance.new(class)
    for k,v in pairs(properties) do o[k]=v end
    o.Parent=parent
    return o
end
-- =====================================
-- FPS TURBO v9.8: preservacao de arenas e limpeza local conservadora.
-- NUNCA retira pecas do Workspace: mantem colisao fisica e restaura visual
-- no OFF / X. Remove texturas do mapa, decoro do lobby e pequenos detritos
-- visuais identificados fora da quadra, sem esconder estruturas de jogo.
-- =====================================
local FPS={Enabled=false,Generation=0,Revision=0,
    Originals={},
    Detached={},HiddenOriginals={},
    Seen={},
    LobbyBounds=nil,LobbyFloorY=nil,
    GetMode=nil,IsArenaPoint=nil,Processed=0,Hidden=0}
local fpsSetEnabled,fpsRestore

do
local playerModelCache=setmetatable({}, {__mode='k'})
local strongNameCache,lobbyNameCache={},{}
local strongPatterns={
    'leaderboard','leader board','leaderboards','topwins','topplayers',
    'rankboard','rankings','topdonat','top donor','trophy',
    'fountain','water fountain','waterfall','waterjet',
    'roulette','roleta','spinwheel','luckywheel','prizewheel',
    'palmtree','pinetree','foliage','vegetation','tree_',
    '_tree','decoration','decorative'
}
local lobbyPatterns={
    'leader','scoreboard','score board','statistic','statistics',
    'leaderstat','statboard','statsboard','recordboard','records',
    'skill','ability','abilit','abilities','trainer',
    'skillpack','skill pack','packstand','gamepass',
    'bundle','premium','shopstand','shopnpc','storestand',
    'roulette','roleta','spinner','wheel','jackpot',
    'prize','lottery','spin','eventnpc','event npc',
    'seasonal','eventshop','event shop','merchant',
    'vendor','questgiver','waterjet','waterfall',
    'fountain','decor','statue','bench','furniture',
    'flower','grassdecor','crate','woodbox'
}

local function fpsChange(inst,prop,value)
    if not inst or not inst.Parent then return end
    local ok,old=pcall(function() return inst[prop] end)
    if not ok or old==value then return end
    if pcall(function() inst[prop]=value end) then
        local saved=FPS.Originals[inst]
        if not saved then saved={} FPS.Originals[inst]=saved end
        if saved[prop]==nil then saved[prop]=old end
    end
end

local function fpsName(name)
    return string.lower(tostring(name or ''))
end
local function fpsLobbyName(name)
    local n=fpsName(name)
    return n=='lobby' or n=='hub' or n=='waitingroom'
        or n=='waiting area' or n=='lobbymap' or n=='lobbyprops'
        or n=='lobbydecor' or n=='lobbydecoration'
        or n=='mainlobby' or n=='main lobby' or n=='lobbyarea'
        or n=='lobby area' or n=='spawnlobby' or n=='lobby island'
end
local function fpsArenaName(name)
    local n=fpsName(name)
    return n=='main' or n=='practice' or n=='arena'
        or n=='court' or n=='match' or n=='gameplay'
        or n=='volleyballcourt' or n=='practicecourt'
end
local function fpsCriticalName(name)
    local n=fpsName(name)
    return n:find('teleport',1,true) or n:find('queue',1,true)
        or n:find('matchmaking',1,true) or n:find('portal',1,true)
        or n:find('spawn',1,true) or n:find('trigger',1,true)
        or n:find('checkpoint',1,true) or n:find('collider',1,true)
        or n:find('hitbox',1,true) or n:find('indicator',1,true)
end
-- Alvos com nomes especificos podem ser reconhecidos mesmo se a
-- organizacao do mapa variar entre servidores.
local function fpsStrongDecorName(name)
    local n=fpsName(name)
    if strongNameCache[n]~=nil then return strongNameCache[n] end
    local yes=false
    for _,word in ipairs(strongPatterns) do
        if n:find(word,1,true) then yes=true break end
    end
    if not yes then
        yes=n=='tree' or n=='trees' or n=='bush' or n=='bushes'
            or n=='plant' or n=='plants' or n=='leaf' or n=='leaves'
            or n=='branch' or n=='branches' or n=='trunk' or n=='palm'
            or n=='fountain' or n=='leaderboard' or n=='wheel'
            or n:match('^tree%d+$')~=nil
    end
    strongNameCache[n]=not not yes
    return not not yes
end
local function fpsLobbyObjectName(name)
    local n=fpsName(name)
    if lobbyNameCache[n]~=nil then return lobbyNameCache[n] end
    local yes=fpsStrongDecorName(n)
    if not yes then
        for _,word in ipairs(lobbyPatterns) do
            if n:find(word,1,true) then yes=true break end
        end
    end
    if not yes then
        yes=n=='npc' or n=='npcs' or n=='event' or n=='stats'
            or n=='packs' or n=='pack' or n=='box' or n=='boxes'
            or n=='chest' or n=='tree' or n=='trees'
            or n=='signboard' or n=='board' or n=='display'
            or n=='props' or n=='water' or n=='particle'
    end
    lobbyNameCache[n]=not not yes
    return not not yes
end

local function fpsIsPlayerCharacter(model)
    local cached=playerModelCache[model]
    if cached~=nil then return cached end
    local yes=P:GetPlayerFromCharacter(model)~=nil
    playerModelCache[model]=yes
    return yes
end

-- Estas coordenadas sao apenas uma rede de seguranca para o layout
-- observado no log do usuario. Zonas recebidas do servidor e nomes da
-- quadra tem prioridade, mas protecao existe ANTES do primeiro BallState.
local fallbackArenas={
    -- Reservado ao terreno da quadra; a antiga area 85x100 invadia o lobby.
    {x=0,z=12,dx=38,dz=55},   -- Main (limites do jogo observados no BallState)
    {x=222,z=-6,dx=40,dz=55} -- Practice
}
local function fpsArenaContainer(inst)
    -- Nomes genericos (Main, Arena, Game) nao bastam: muitos objetos do
    -- lobby ficam debaixo destes containers no jogo.
    local node=inst
    local depth=0
    while node and node~=W and depth<18 do
        local n=fpsName(node.Name)
        if fpsLobbyName(n) then return false end
        if n:find('pvp',1,true) or n:find('ranked',1,true)
            or n:find('court',1,true)
            or n:find('volleyball',1,true)
            or n:find('playingfield',1,true) then
            return true
        end
        node=node.Parent
        depth=depth+1
    end
    return false
end
local function fpsExplicitLobby(inst)
    local node=inst
    local depth=0
    while node and node~=W and depth<18 do
        if fpsLobbyName(node.Name) then return true end
        node=node.Parent
        depth=depth+1
    end
    return false
end
local function fpsProtectedArena(part)
    if not part or not part:IsA('BasePart') then return false end
    if fpsArenaContainer(part) then return true end
    local p=part.Position
    -- As zonas reais recebidas do servidor tem prioridade sobre suposicoes.
    if FPS.IsArenaPoint and FPS.IsArenaPoint(p) then return true end
    -- Um container explicitamente chamado Lobby/Hub nunca deve ser
    -- confundido com a quadra apenas por estar perto da arena principal.
    if fpsExplicitLobby(part) then return false end
    -- Fallback estreito antes dos primeiros estados da bola.
    if p.Y>=8 and p.Y<=145 then
        for _,area in ipairs(fallbackArenas) do
            if math.abs(p.X-area.x)<=area.dx
                and math.abs(p.Z-area.z)<=area.dz then return true end
        end
    end
    return false
end

-- Piso do lobby: verde vivo e horizontal, como no mapa fornecido.
-- Usamos isso apenas para achar a ilha; o piso continua visivel.
local function fpsGreenFloor(part)
    if not part:IsA('BasePart') or not part.Anchored then return false end
    local s=part.Size
    if s.X<12 or s.Z<12 or s.X*s.Z<180 or s.Y>12 then return false end
    if math.abs(part.CFrame.UpVector.Y)<0.88 then return false end
    local c=part.Color
    return c.G>0.62 and c.R<0.55 and c.B<0.52
        and c.G>c.R*1.35 and c.G>c.B*1.45
end
local function fpsFindLobbyBounds(all)
    local root=me.Character and me.Character:FindFirstChild('HumanoidRootPart')
    local atLobby=FPS.GetMode and FPS.GetMode()=='Lobby'
    local seed,score=nil,-math.huge
    for _,inst in ipairs(all) do
        if fpsGreenFloor(inst) and not fpsProtectedArena(inst) then
            local s=inst.Size
            local area=s.X*s.Z
            local value=area
            if root and atLobby then
                local delta=root.Position-inst.Position
                local dist=Vector3.new(delta.X,0,delta.Z).Magnitude
                if dist<=135 and math.abs(delta.Y)<90 then
                    value=area*3/(1+dist/45)
                else
                    value=area*0.1
                end
            end
            local parent=inst.Parent
            if parent and fpsLobbyName(parent.Name) then value=value*4 end
            if value>score then score=value seed=inst end
        end
    end
    if not seed then return end
    local y=seed.Position.Y+seed.Size.Y*0.5
    local minX,maxX,minZ,maxZ=math.huge,-math.huge,math.huge,-math.huge
    for _,part in ipairs(all) do
        if fpsGreenFloor(part) and not fpsProtectedArena(part) then
            local delta=part.Position-seed.Position
            if math.abs(delta.X)<=125 and math.abs(delta.Z)<=125
                and math.abs(part.Position.Y+part.Size.Y*0.5-y)<=9 then
                local s=part.Size
                minX=math.min(minX,part.Position.X-s.X*0.5)
                maxX=math.max(maxX,part.Position.X+s.X*0.5)
                minZ=math.min(minZ,part.Position.Z-s.Z*0.5)
                maxZ=math.max(maxZ,part.Position.Z+s.Z*0.5)
            end
        end
    end
    if minX<=maxX and minZ<=maxZ then
        FPS.LobbyBounds={minX=minX,maxX=maxX,minZ=minZ,maxZ=maxZ}
        FPS.LobbyFloorY=y
    end
end
local function fpsWorldPart(inst)
    if not inst then return nil end
    if (inst:IsA('BillboardGui') or inst:IsA('SurfaceGui')) and inst.Adornee
        and inst.Adornee:IsA('BasePart') then
        return inst.Adornee
    end
    local node=inst
    while node and node~=W do
        if node:IsA('BasePart') then return node end
        if (node:IsA('BillboardGui') or node:IsA('SurfaceGui')) and node.Adornee
            and node.Adornee:IsA('BasePart') then
            return node.Adornee
        end
        node=node.Parent
    end
    return nil
end
local function fpsInsideLobby(inst)
    local b=FPS.LobbyBounds
    if not b then return false end
    local p=fpsWorldPart(inst)
    if not p or fpsProtectedArena(p) then return false end
    local pos=p.Position
    if FPS.LobbyFloorY and (pos.Y<FPS.LobbyFloorY-17
        or pos.Y>FPS.LobbyFloorY+105) then return false end
    if pos.X<b.minX-24 or pos.X>b.maxX+24
        or pos.Z<b.minZ-24 or pos.Z>b.maxZ+24 then return false end
    return not (FPS.IsArenaPoint and FPS.IsArenaPoint(pos))
end
local function fpsFloorPart(part)
    if not part or not part:IsA('BasePart') then return false end
    if part:IsA('SpawnLocation') then return true end
    local n=fpsName(part.Name)
    if n:find('floor',1,true) or n:find('ground',1,true)
        or n:find('baseplate',1,true) or n:find('bridge',1,true)
        or n:find('path',1,true) or n:find('stairs',1,true)
        or n:find('platform',1,true) then return true end
    local s=part.Size
    if s.X>30 and s.Z>30 and s.Y<=12 then return true end
    if FPS.LobbyFloorY and s.Y<=3.8 and s.X>=3 and s.Z>=3
        and math.abs(part.CFrame.UpVector.Y)>0.88
        and math.abs(part.Position.Y+s.Y*0.5-FPS.LobbyFloorY)<=4 then
        return true
    end
    return false
end

local function fpsLobbyDecor(inst)
    local node=inst
    local depth=0
    local named=false
    local strong=false
    local lobby=false
    local arena=fpsArenaContainer(inst)
    while node and node~=W and depth<24 do
        local n=fpsName(node.Name)
        if fpsCriticalName(n) then return false end
        if fpsLobbyName(n) then lobby=true end
        if fpsLobbyObjectName(n) then named=true end
        if fpsStrongDecorName(n) then strong=true end
        node=node.Parent
        depth=depth+1
    end
    -- Nunca esconder elementos da quadra ou do treino pela busca espacial.
    if arena then return false end
    local nearby=fpsInsideLobby(inst)
    if named and (lobby or nearby or (strong and not FPS.LobbyBounds)) then
        return true
    end
    -- Objetos com nomes genericos (Part, Mesh, Model, Handle) sao
    -- capturados pela ilha verde, sem esconder o piso ou as plataformas.
    if lobby or nearby then
        local part=fpsWorldPart(inst)
        if not part or fpsFloorPart(part) then return false end
        if part.Anchored then return true end
        -- Inclui NPCs do lobby, que geralmente possuem pecas nao ancoradas.
        local parent=part.Parent
        while parent and parent~=W do
            if parent:IsA('Model') and parent:FindFirstChildOfClass('Humanoid') then
                return not fpsIsPlayerCharacter(parent)
            end
            parent=parent.Parent
        end
    end
    return false
end


local function fpsCullWorldPart(part)
    if not part or not part:IsA('BasePart') or not part.Parent then return false end
    -- Protege antes de qualquer regra de proximidade: Main e Practice.
    if fpsProtectedArena(part) then return false end
    if fpsInsideLobby(part) then return true end
    local b=FPS.LobbyBounds
    if not b or not FPS.LobbyFloorY or not part.Anchored then return false end
    local p=part.Position
    local s=part.Size
    -- Fora da ilha, escondemos SOMENTE pequenos detritos / rochas do mar,
    -- e nunca superficies amplas ou partes de quadras sem nome.
    local insideNearby=p.X>=b.minX-75 and p.X<=b.maxX+75
        and p.Z>=b.minZ-75 and p.Z<=b.maxZ+75
    if not insideNearby or math.max(s.X,s.Z)>30 then return false end
    if p.Y<FPS.LobbyFloorY-34 or p.Y>FPS.LobbyFloorY+24 then return false end
    local belowIsland=p.Y+s.Y*0.5<FPS.LobbyFloorY-3
    local name=fpsName(part.Name)
    local debrisName=name:find('rock',1,true)
        or name:find('island',1,true)
        or name:find('debris',1,true)
        or name:find('chunk',1,true)
        or name:find('floating',1,true)
        or name:find('tree',1,true)
    return belowIsland or debrisName~=nil
end
local function fpsCullWorldInst(inst)
    local p=fpsWorldPart(inst)
    return p and fpsCullWorldPart(p) or false
end

local function fpsEssential(inst)
    if not inst or not inst.Parent then return true end
    if inst==folder or inst:IsDescendantOf(folder) then return true end
    local node=inst
    local depth=0
    local npc=false
    while node and node~=W and depth<24 do
        if node:IsA('Model') and node:FindFirstChildOfClass('Humanoid') then
            if fpsIsPlayerCharacter(node) then return true end
            npc=true
        end
        local n=fpsName(node.Name)
        if n=='bowling ball' or n=='default' or n=='ball'
            or n=='volleyball' or n=='balls' or n=='projectiles'
            or n=='indicators' or n=='ballshadow'
            or n=='ballindicator' or n=='hitmarker'
            or fpsCriticalName(n) then return true end
        node=node.Parent
        depth=depth+1
    end
    -- Bots de Practice sao preservados; NPCs de loja/evento no lobby nao.
    return npc and not fpsLobbyDecor(inst)
end

local function fpsHide(part)
    if not part or not part.Parent or FPS.HiddenOriginals[part]~=nil then return end
    local ok,old=pcall(function() return part.LocalTransparencyModifier end)
    if ok and pcall(function() part.LocalTransparencyModifier=1 end) then
        FPS.HiddenOriginals[part]=old
        FPS.Hidden=FPS.Hidden+1
    end
end
local function fpsDetach(inst)
    if not inst or not inst.Parent then return end
    if inst:IsA('Decal') or inst:IsA('Texture') then
        fpsChange(inst,'Transparency',1)
        fpsChange(inst,'Texture','')
    elseif inst:IsA('SurfaceAppearance') then
        for _,field in ipairs({'ColorMap','NormalMap','MetalnessMap','RoughnessMap'}) do
            fpsChange(inst,field,'')
        end
    end
end
local function fpsProcess(inst)
    if not FPS.Enabled or not inst or not inst.Parent then return end
    if not inst:IsDescendantOf(W) then return end
    if FPS.Seen[inst] then return end
    FPS.Seen[inst]=true

    local class=inst.ClassName
    local isPart=inst:IsA('BasePart')
    -- A quadra, e tambem texturas/meshes/guis descendentes dela,
    -- nao podem ser mexidos pelo FPS Turbo.
    local hostPart=fpsWorldPart(inst)
    if hostPart and fpsProtectedArena(hostPart) then return end
    local inLobby=isPart and fpsInsideLobby(inst)
    local cullWorld=isPart and fpsCullWorldPart(inst)
    local essential=fpsEssential(inst)
    if essential then
        -- Piso, spawns e gatilhos continuam com colisao, mas ficam invisiveis.
        if isPart and cullWorld and inst.Anchored then
            local n=fpsName(inst.Name)
            if fpsFloorPart(inst) or fpsCriticalName(n) then fpsHide(inst) end
        end
        return
    end

    if class=='Decal' or class=='Texture' or class=='SurfaceAppearance' then
        fpsDetach(inst)
    elseif class=='SpecialMesh' then
        fpsChange(inst,'TextureId','')
    elseif isPart then
        local removeLobby=cullWorld or (not FPS.LobbyBounds and fpsLobbyDecor(inst))
        if removeLobby then
            fpsHide(inst) -- invisivel, mas continua com colisao
            if class=='MeshPart' then fpsChange(inst,'TextureID','') end
            fpsChange(inst,'MaterialVariant','')
            fpsChange(inst,'Material',Enum.Material.SmoothPlastic)
            FPS.Hidden=FPS.Hidden+1
        elseif inst.Anchored then
            if class=='MeshPart' then fpsChange(inst,'TextureID','') end
            fpsChange(inst,'MaterialVariant','')
            fpsChange(inst,'Material',Enum.Material.SmoothPlastic)
        end
    elseif class=='SurfaceGui' or class=='BillboardGui' then
        if fpsCullWorldInst(inst) or fpsLobbyDecor(inst) then fpsChange(inst,'Enabled',false) end
    elseif inst:IsA('GuiObject') then
        if fpsCullWorldInst(inst) or fpsLobbyDecor(inst) then fpsChange(inst,'Visible',false) end
    elseif class=='ProximityPrompt' then
        if fpsCullWorldInst(inst) or fpsLobbyDecor(inst) then fpsChange(inst,'Enabled',false) end
    elseif class=='ParticleEmitter' or class=='Beam' or class=='Trail'
        or class=='PointLight' or class=='SpotLight' or class=='SurfaceLight'
        or class=='Highlight' then
        if fpsCullWorldInst(inst) or fpsLobbyDecor(inst) then fpsChange(inst,'Enabled',false) end
    end
end

local function fpsScan(generation)
    local all=W:GetDescendants()
    fpsFindLobbyBounds(all)
    local began=os.clock()
    -- A primeira passada retira logo as pecas do lobby. O resto
    -- das texturas do mapa e processado depois, sem bloquear por muito tempo.
    for i,inst in ipairs(all) do
        if stopped or not FPS.Enabled or generation~=FPS.Generation then return end
        if inst:IsA('BasePart') and fpsInsideLobby(inst) then fpsProcess(inst) end
        if i%550==0 and os.clock()-began>0.018 then
            task.wait()
            began=os.clock()
        end
    end
    for i,inst in ipairs(all) do
        if stopped or not FPS.Enabled or generation~=FPS.Generation then return end
        fpsProcess(inst)
        if i%360==0 and os.clock()-began>0.014 then
            task.wait()
            began=os.clock()
        end
    end
    table.clear(all)
end
fpsRestore=function()
    -- Os objetos da v9.8 nunca sao desanexados. Restauracao de scripts
    -- anteriores ainda tenta reconstruir a hierarquia do pai para o filho.
    local pending=FPS.Detached
    for _=1,10 do
        local progress=false
        for inst,parent in pairs(pending) do
            if inst and parent and (parent==W or parent.Parent) then
                if pcall(function() inst.Parent=parent end) then
                    pending[inst]=nil
                    progress=true
                end
            end
        end
        if not progress then break end
    end
    FPS.Detached={}
    for inst,props in pairs(FPS.Originals) do
        if inst then
            for prop,old in pairs(props) do
                pcall(function() inst[prop]=old end)
            end
        end
    end
    for inst,old in pairs(FPS.HiddenOriginals) do
        if inst then
            pcall(function() inst.LocalTransparencyModifier=old end)
        end
    end
    FPS.HiddenOriginals={}
    FPS.Originals={}
    FPS.Seen={}
    FPS.Processed=0 FPS.Hidden=0
end
fpsSetEnabled=function(enabled)
    enabled=not not enabled
    if FPS.Enabled==enabled then return end
    FPS.Generation=FPS.Generation+1
    FPS.Enabled=enabled
    if enabled then
        local generation=FPS.Generation
        task.spawn(function() fpsScan(generation) end)
    else
        fpsRestore()
    end
end
links[#links+1]=W.DescendantAdded:Connect(function(inst)
    if FPS.Enabled then fpsProcess(inst) end
end)
end -- fps internals


local function character()
    local ch=me.Character
    if not ch then return nil end
    local root=ch:FindFirstChild('HumanoidRootPart')
    local hum=ch:FindFirstChildOfClass('Humanoid')
    if not root or not hum or hum.Health<=0 then return nil end
    return root,hum
end
local function horizontal(a,b)
    local d=Vector3.new(b.X-a.X,0,b.Z-a.Z)
    if d.Magnitude<0.01 then return nil,0 end
    return d.Unit,d.Magnitude
end
local function params()
    local exclude={folder}
    for _,n in ipairs({'Default','Bowling Ball','BallShadow'}) do
        local o=W:FindFirstChild(n)
        if o then table.insert(exclude,o) end
    end
    for _,pl in ipairs(P:GetPlayers()) do
        if pl.Character then table.insert(exclude,pl.Character) end
    end
    local p=RaycastParams.new()
    p.FilterType=Enum.RaycastFilterType.Exclude
    p.FilterDescendantsInstances=exclude
    p.RespectCanCollide=true
    p.IgnoreWater=true
    return p
end
local function radius(arena)
    local name=arena=='Main' and 'Bowling Ball' or 'Default'
    local b=W:FindFirstChild(name)
    if not b or not b:IsA('BasePart') then return 1.5 end
    return math.clamp(math.min(b.Size.X,b.Size.Y,b.Size.Z)*0.5,0.4,4)
end
-- Raycast usado na PREVISAO: ignora o cenario ocultado pelo FPS Turbo,
-- que ainda possui colisao por seguranca. Sem isso um bloco invisivel
-- pode virar uma parede ou um "chao" falso no calculo da bola.
local function predictionCast(origin,direction,p,castRadius)
    for _=1,9 do
        local ok,hit=pcall(function()
            if castRadius then return W:Spherecast(origin,castRadius,direction,p) end
            return W:Raycast(origin,direction,p)
        end)
        if not ok then return nil,false end
        if not hit then return nil,true end
        if hit.Instance and FPS.HiddenOriginals[hit.Instance]~=nil then
            local excluded=p.FilterDescendantsInstances
            excluded[#excluded+1]=hit.Instance
            p.FilterDescendantsInstances=excluded
        else
            return hit,true
        end
    end
    -- Depois de nove objetos ocultos, nao adivinhar colisao.
    return nil,false
end

local function marker(arena,color)
    local model=make('Model',{Name=arena..'Landing'},folder)
    local parts={}
    local function part(sz,cf,alpha,shape)
        local p=make('Part',{Size=sz,CFrame=cf,
            Shape=shape or Enum.PartType.Block,Anchored=true,
            CanCollide=false,CanTouch=false,CanQuery=false,
            CastShadow=false,Material=Enum.Material.Neon,
            Color=color,Transparency=1},model)
        table.insert(parts,{p,alpha})
        return p
    end
    for ring=1,2 do
        local rad=C.Radius*(ring==1 and 1 or 0.68)
        local count=ring==1 and 32 or 26
        local thickness=ring==1 and 0.38 or 0.2
        for i=1,count do
            local a=(i-0.5)*math.pi*2/count
            local tangent=Vector3.new(-math.sin(a),0,math.cos(a))
            local pos=Vector3.new(math.cos(a)*rad,0,math.sin(a)*rad)
            part(Vector3.new(2*rad*math.sin(math.pi/count)*1.08,0.09,thickness),
                CFrame.fromMatrix(pos,tangent,Vector3.yAxis),ring==1 and 0.06 or 0.3)
        end
    end
    part(Vector3.new(0.27,0.27,0.27),
        CFrame.new(0,0.08,0),0.08,Enum.PartType.Ball)
    -- Somente o indicador no chao: sem BillboardGui nem texto.
    model.WorldPivot=CFrame.new()
    return {Model=model,Parts=parts,Visible=false}
end
markers.Main=marker('Main',C.MainColor)
markers.Practice=marker('Practice',C.PracticeColor)
-- Modo automatico: o proprio BallState informa Arena='Main' ou 'Practice',
-- enquanto Zones informa onde fica cada quadra. O jogador precisa estar
-- na regiao da quadra para que o indicador correspondente apareca.
-- Sem quadra proxima ou sem estado verificavel, mantemos modo Lobby.
local currentMode='Lobby'
local modeCheckAt=-math.huge
local modeLastConfirmed=-math.huge
local function detectMode(force)
    local now=os.clock()
    if not force and now-modeCheckAt<0.12 then return currentMode end
    modeCheckAt=now
    local root=character()
    if not root then
        currentMode='Lobby'
        return currentMode
    end
    local chosen='Lobby'
    local bestDist=math.huge
    local pos=root.Position

    -- Primeiro: posicao em uma zona real enviada pelo servidor.
    -- Isso continua funcionando durante o intervalo entre bolas.
    for _,arena in ipairs({'Main','Practice'}) do
        for _,zone in ipairs(zones[arena]) do
            if typeof(zone)=='Instance' and zone:IsA('BasePart') and zone.Parent then
                local localPos=zone.CFrame:PointToObjectSpace(pos)
                if math.abs(localPos.Y)<=math.max(60,zone.Size.Y/2+15) then
                    local dx=math.max(0,math.abs(localPos.X)-zone.Size.X/2)
                    local dz=math.max(0,math.abs(localPos.Z)-zone.Size.Z/2)
                    local distance=math.sqrt(dx*dx+dz*dz)
                    -- Leve tolerancia para a borda da quadra.
                    if distance<bestDist and distance<=12 then
                        chosen=arena
                        bestDist=distance
                    end
                end
            end
        end
    end

    -- Se ainda nao recebemos Zones, reconhecer pela bola da arena,
    -- somente enquanto o BallState daquela arena estiver ativo.
    if chosen=='Lobby' then
        for _,arena in ipairs({'Main','Practice'}) do
            local s=states[arena]
            if s and W:GetServerTimeNow()<=s.EndTime+0.25 and #zones[arena]==0 then
                local ball=W:FindFirstChild(arena=='Main' and 'Bowling Ball' or 'Default')
                if ball and ball:IsA('BasePart') then
                    local delta=ball.Position-pos
                    local distance=Vector3.new(delta.X,0,delta.Z).Magnitude
                    if math.abs(delta.Y)<65 and distance<bestDist and distance<=115 then
                        chosen=arena
                        bestDist=distance
                    end
                end
            end
        end
    end

    -- Evita piscar 'Lobby' por um frame ao saltar ou cruzar a borda.
    if chosen~='Lobby' then
        modeLastConfirmed=now
    elseif currentMode~='Lobby' and now-modeLastConfirmed<0.35 then
        chosen=currentMode
    end
    currentMode=chosen
    return currentMode
end
-- FPS usa exatamente a mesma deteccao de area dos indicadores.
FPS.GetMode=detectMode
-- Impede que a limpeza por proximidade esconda quadras de Main/Practice.
FPS.IsArenaPoint=function(pos)
    for _,arena in ipairs({'Main','Practice'}) do
        for _,zone in ipairs(zones[arena]) do
            if typeof(zone)=='Instance' and zone:IsA('BasePart') and zone.Parent then
                local relative=zone.CFrame:PointToObjectSpace(pos)
                if math.abs(relative.X)<=zone.Size.X*0.5+5
                    and math.abs(relative.Z)<=zone.Size.Z*0.5+5
                    and math.abs(relative.Y)<=90 then return true end
            end
        end
    end
    return false
end

local function show(m,visible)
    if m.Visible==visible then return end
    m.Visible=visible
    for _,part in ipairs(m.Parts) do
        part[1].Transparency=visible and part[2] or 1
    end
end
local function frame(point,normal)
    local ref=math.abs(normal:Dot(Vector3.yAxis))>0.95 and Vector3.xAxis or Vector3.yAxis
    return CFrame.fromMatrix(point+normal*0.15,ref:Cross(normal).Unit,normal)
end
local function active(arena)
    local s=states[arena]
    if not s or W:GetServerTimeNow()>s.EndTime+0.08 then return nil end
    return s
end
-- Estados de habilidade podem continuar em movimento depois da fronteira
-- calculada para o trecho balistico original. O limite extra so vale
-- para estados marcados como habilidade; nao muda o dive nem a bola normal.
local function liveState(arena)
    local s=active(arena)
    if s then return s end
    s=states[arena]
    if not s or not s.Raw then return nil end
    local special=s.Raw.Tornado~=nil or s.Raw.Magnet~=nil
    if not special then return nil end
    if type(s.RawEndTime)~='number' or s.RawEndTime==math.huge then return nil end
    if W:GetServerTimeNow()>s.RawEndTime+0.60 then return nil end
    return s
end
local correctedState
local function updateMarkers()
    local mode=detectMode()
    for arena,m in pairs(markers) do
        local s=(arena==mode) and correctedState and correctedState(arena) or nil
        -- A parede e o teto NUNCA recebem indicador, mesmo na falta
        -- de uma previsao confiavel de onde a bola caira depois.
        if s and s.Point and s.Normal and s.Surface=='floor'
            and s.Normal.Y>=0.88 then
            m.Model:PivotTo(frame(s.Point,s.Normal))
            -- Foto do indicador presente na hora do E: dive nao muda.
            m.LastPoint=s.Point
            m.LastNormal=s.Normal
            m.LastVisibleAt=os.clock()
            show(m,true)
            -- Trajetoria apos ricochete: previsao ilustrativa, nao certeza.
            local alpha=s.Live and 0.5 or (s.BounceEstimated and 0.36 or 0)
            if m.LastAlpha~=alpha then
                m.LastAlpha=alpha
                for _,item in ipairs(m.Parts) do
                    item[1].Transparency=math.max(item[2],alpha)
                end
            end
        else
            show(m,false)
            m.LastAlpha=nil
            -- Quando ha estado de bola ativo mas a previsao foi rejeitada,
            -- nao deixar o E usar o ponto antigo nos 0.12s de tolerancia.
            if arena==mode and liveState(arena) then
                m.LastPoint=nil
                m.LastNormal=nil
                m.LastVisibleAt=nil
            end
        end
    end
end
local function position(s,t)
    return s.Origin+s.Velocity*t+s.Gravity*(t*t*0.5)
end
local function forecast(s,arena)
    if typeof(s.Origin)~='Vector3' or typeof(s.Velocity)~='Vector3'
        or typeof(s.Gravity)~='Vector3' or type(s.Time)~='number'
        or type(s.EndTime)~='number' then return nil end
    local duration=s.EndTime-s.Time
    if duration<=0 or duration>12 or duration~=duration
        or s.EndTime==math.huge then return nil end
    local endpoint=position(s,duration)
    local endVelocity=s.Velocity+s.Gravity*duration
    local ballRadius=radius(arena)
    -- BallState.Normal is the NEXT collision's surface normal (confirmed
    -- against the provided inspector logs). Prefer the server's collision
    -- plane over client casts. EndTime describes ball CENTER at impact.
    -- Move to the contact point only for rendering/collision prediction.
    -- Special movement states still fall back to live tracking below.
    local serverNormal=s.Normal
    if typeof(serverNormal)=='Vector3' and serverNormal.Magnitude>0.9
        and serverNormal.Magnitude<1.1
        and -endVelocity:Dot(serverNormal)>0.5
        and s.Tornado==nil and s.Magnet==nil then
        local n=serverNormal.Unit
        local kind=n.Y>=0.88 and 'floor'
            or (n.Y<=-0.72 and 'ceiling' or 'wall')
        if not (s.IgnoreWalls and kind=='wall') then
            return endpoint-n*ballRadius,n,0.03,endVelocity,
                s.EndTime,true,kind
        end
    end
    local p=params()

    -- BallState.EndTime is the game's forecast boundary. A cast that hits
    -- some unrelated part far BEFORE this time is not proof of a wall bounce.
    local segments=math.clamp(math.ceil(duration/0.08),2,110)
    local castRadius=math.max(0.35,ballRadius*0.89)
    local nearEnd=math.clamp(duration*0.10,0.075,0.16)
    for i=1,segments do
        local t0=duration*(i-1)/segments
        local t1=duration*i/segments
        local a,b=position(s,t0),position(s,t1)
        local motion=b-a
        local length=motion.Magnitude
        if length>0.025 then
            local hit,ok=predictionCast(a,motion,p,castRadius)
            if ok and hit then
                local fraction=math.clamp(hit.Distance/length,0,1)
                local hitT=t0+(t1-t0)*fraction
                local velocity=s.Velocity+s.Gravity*hitT
                local closeInTime=math.abs(duration-hitT)<=nearEnd
                local closeInSpace=(hit.Position-endpoint).Magnitude <= ballRadius+2.1
                if -velocity:Dot(hit.Normal)>0.3
                    and closeInTime and closeInSpace then
                    local kind=hit.Normal.Y>=0.88 and 'floor'
                        or (hit.Normal.Y<=-0.72 and 'ceiling' or 'wall')
                    if not (s.IgnoreWalls and kind=='wall') then
                        return hit.Position,hit.Normal,0.05,velocity,
                            s.Time+hitT,true,kind
                    end
                end
                -- The cast cannot be used as a trajectory oracle; do not
                -- label this early decorative collision as a real wall.
            end
        end
    end

    -- The endpoint is a hypothesis, not confirmed contact. Confirm that an
    -- actual collidable surface is at roughly a ball radius from the end.
    local best,err=nil,math.huge
    local directions={Vector3.xAxis,-Vector3.xAxis,Vector3.yAxis,
        -Vector3.yAxis,Vector3.zAxis,-Vector3.zAxis}
    if endVelocity.Magnitude>0.1 then
        table.insert(directions,endVelocity.Unit)
    end
    for _,dir in ipairs(directions) do
        local hit=predictionCast(endpoint,dir*math.max(ballRadius+1.5,3.5),p)
        if hit then
            local gap=math.abs((hit.Position-endpoint).Magnitude-ballRadius)
            if gap<err and gap<=0.60 and -endVelocity:Dot(hit.Normal)>0.5 then
                best,err=hit,gap
            end
        end
    end
    if best then
        local kind=best.Normal.Y>=0.88 and 'floor'
            or (best.Normal.Y<=-0.72 and 'ceiling' or 'wall')
        -- A stray vertical barrier from a thin decoration must be backed
        -- by a strongly plausible endpoint before we show it as a wall.
        if kind=='wall' and (err>0.25 or s.IgnoreWalls) then return nil end
        return best.Position,best.Normal,err,endVelocity,
            s.EndTime,true,kind
    end
    return nil
end

-- O servidor multiplica a velocidade por 0.6 apos qualquer colisao normal:
-- v_apos = 0.6 * (v_antes - 2 * (v_antes . normal) * normal).
-- Confirmado por 13 pares consecutivos de BallState Bounced (Main/Practice).
-- Nao recalibrar usando estimativas visuais: isso alterava um fator exato.
-- Para poderes/forcas especiais (Tornado/Magnet) usamos rastreamento visual.
local bounceModels={Main={Normal=0.60,Tangent=0.60},
    Practice={Normal=0.60,Tangent=0.60}}

local function bounceVelocity(velocity,normal,model)
    local along=velocity:Dot(normal)
    if along>=-0.3 then return nil end
    local tangent=velocity-normal*along
    return tangent*model.Tangent-normal*along*model.Normal
end

local function predictFloorAfterBounce(raw,arena,hitPoint,hitNormal,hitVelocity,startTime)
    if typeof(raw.Gravity)~='Vector3' then return nil end
    local model=bounceModels[arena]
    if not model then return nil end
    local r=radius(arena)
    local castRadius=math.max(0.35,r*0.89)
    local point=hitPoint+hitNormal*(r+0.13)
    local velocity=bounceVelocity(hitVelocity,hitNormal,model)
    if not velocity then return nil end
    local param=params()
    local total=0
    local bounceCount=1
    -- Limites impedem travamento em salas fechadas e casts muito caros.
    for _=1,115 do
        if total>4 or bounceCount>5 or velocity.Magnitude>320 then break end
        local dt=0.04
        local delta=velocity*dt+raw.Gravity*(0.5*dt*dt)
        if delta.Magnitude<0.025 then
            point=point+delta
            velocity=velocity+raw.Gravity*dt
            total=total+dt
        else
            local hit,ok=predictionCast(point,delta,param,castRadius)
            if not ok then return nil end
            if hit then
                local f=math.clamp(hit.Distance/delta.Magnitude,0,1)
                local elapsed=dt*f
                local incident=velocity+raw.Gravity*elapsed
                local n=hit.Normal
                -- Colisao do topo da quadra: superficie horizontal.
                if n.Y>=0.88 and incident.Y< -1.2 then
                    return hit.Position,n,startTime+total+elapsed,bounceCount
                end
                local reflected=bounceVelocity(incident,n,model)
                if not reflected then
                    -- Colisao rasante: nao inventar destino de pouso.
                    return nil
                end
                bounceCount=bounceCount+1
                point=hit.Position+n*(r+0.13)
                velocity=reflected
                total=total+math.max(elapsed,0.014)
            else
                point=point+delta
                velocity=velocity+raw.Gravity*dt
                total=total+dt
            end
        end
    end
    return nil
end
-- Trava de area: nunca aprende automaticamente a area adversaria.
local function zoneAt(list,point)
    local chosen,smallest=nil,math.huge
    for _,z in ipairs(list) do
        if z.Parent then
            local p=z.CFrame:PointToObjectSpace(point)
            if math.abs(p.X)<=z.Size.X/2+1 and math.abs(p.Z)<=z.Size.Z/2+1 then
                local size=z.Size.X*z.Size.Z
                if size<smallest then chosen,smallest=z,size end
            end
        end
    end
    return chosen
end
local function lockZone(arena,add)
    local root=character()
    if not root then return false end
    local z=zoneAt(zones[arena],root.Position)
    if not z then return false end
    if not add then table.clear(owned[arena]) end
    owned[arena][z]=true
    return true
end
local function floorAt(point)
    return W:Raycast(point+Vector3.new(0,2,0),Vector3.new(0,-9,0),params())
end
local function ownSide(s,root)
    local impact=zoneAt(s.Zones,s.Point)
    local mine=zoneAt(s.Zones,root.Position)
    -- Respeitar a zona travada. Estar fisicamente do outro lado da
    -- quadra nao deve redefinir a area amiga durante a jogada.
    if next(owned[s.Arena])~=nil then
        return impact~=nil and owned[s.Arena][impact]==true
    end
    if impact and mine then return impact==mine end
    if s.Arena~='Practice' then return false end
    local a=floorAt(root.Position)
    local b=floorAt(s.Point)
    return a~=nil and b~=nil and a.Instance==b.Instance
        and a.Normal.Y>0.9 and b.Normal.Y>0.9
end

local function abilityTagged(raw)
    if raw.Tornado~=nil or raw.Magnet~=nil then return true end
    for _,value in pairs(raw) do
        if type(value)=='string' then
            local str=string.lower(value)
            if string.find(str,'curve',1,true)
                or string.find(str,'tornado',1,true) then
                return true
            end
        end
    end
    return false
end

links[#links+1]=event.OnClientEvent:Connect(function(raw)
    if stopped or type(raw)~='table' then return end
    local arena=raw.Arena
    if not markers[arena] then return end
    if type(raw.Time)~='number' or type(raw.EndTime)~='number' then return end
    local oldState=states[arena]
    if oldState and raw.Time<oldState.Time then return end
    local point,normal,error,velocity,collisionTime,reliable,surface=forecast(raw,arena)
    -- Guardar a primeira colisao para aprender o rebote do servidor
    -- quando o proximo BallState chegar.
    local firstPoint,firstNormal,firstVelocity,firstSurface=point,normal,velocity,surface
    local estimated,bounces=false,0
    if (surface=='wall' or surface=='ceiling') and point and normal and velocity then
        local ground,groundNormal,groundTime,count=predictFloorAfterBounce(
            raw,arena,point,normal,velocity,collisionTime or raw.EndTime)
        if ground and groundNormal and groundNormal.Y>=0.88
            and count and count<=3 then
            point,normal,collisionTime=ground,groundNormal,groundTime
            surface='floor'
            error=2.0+count*1.15
            reliable=false
            estimated=true
            bounces=count
        else
            -- Nada de falso marcador na parede.
            point,normal,collisionTime,reliable,surface=nil,nil,nil,false,nil
        end
    elseif surface~='floor' then
        point,normal,collisionTime,reliable,surface=nil,nil,nil,false,nil
    end
    local zoneList={}
    if type(raw.Zones)=='table' then
        for _,z in pairs(raw.Zones) do
            if typeof(z)=='Instance' and z:IsA('BasePart') then
                table.insert(zoneList,z)
            end
        end
    end
    local previousZones=zones[arena]
    local changedZones=#previousZones~=#zoneList
    if not changedZones then
        local set={}
        for _,z in ipairs(previousZones) do set[z]=true end
        for _,z in ipairs(zoneList) do
            if not set[z] then changedZones=true break end
        end
    end
    -- Se a simulacao cair bem fora das zonas jogaveis, nao arrastar
    -- o circulo para uma quadra aleatoria. E preferivel omitir o erro.
    if point and surface=='floor' and #zoneList>0 then
        local inCourt=false
        for _,zone in ipairs(zoneList) do
            local localPoint=zone.CFrame:PointToObjectSpace(point)
            if math.abs(localPoint.X)<=zone.Size.X*0.5+7
                and math.abs(localPoint.Z)<=zone.Size.Z*0.5+7 then
                inCourt=true
                break
            end
        end
        if not inCourt then
            point,normal,collisionTime,reliable,surface=nil,nil,nil,false,nil
            estimated=false
        end
    end
    zones[arena]=zoneList
    if changedZones then FPS.Revision=FPS.Revision+1 end
    detectMode(true)
    -- Uma unica tentativa inicial por arena; area amiga identificada automaticamente.
    if C.SmartDive and not areaAttempt[arena] and #zoneList>0 then
        if lockZone(arena,true) then areaAttempt[arena]=true end
    end
    -- Um impacto real no piso ensina a altura da quadra para poderes
    -- cuja bola nao segue a trajetoria parabolica do BallState.
    if surface=='floor' and point and not estimated and normal and normal.Y>=0.88 then
        liveTracks[arena].FloorY=point.Y
    end
    states[arena]={Arena=arena,Raw=raw,Time=raw.Time,
        EndTime=collisionTime or raw.EndTime,
        RawEndTime=raw.EndTime,
        Point=point,Normal=normal,Error=error or math.huge,
        Reliable=reliable==true,Surface=surface,
        BounceEstimated=estimated,BounceCount=bounces,
        FirstImpactPoint=firstPoint,FirstImpactNormal=firstNormal,
        FirstIncoming=firstVelocity,FirstSurface=firstSurface,
        MotionUncertain=abilityTagged(raw),Live=false,
        ImpactSpeed=velocity and velocity.Magnitude or 0,
        FallSpeed=velocity and -velocity.Y or 0,Zones=zoneList}
    updateMarkers()
end)


-- Sample the visible ball itself. Curve/Tornado can deviate from the
-- ballistic state received from the server. When the path is changing,
-- stop claiming the old landing point is reliable.
local function updateBallMotion()
    local now=os.clock()
    for arena,track in pairs(liveTracks) do
        if now>=track.Next then
            track.Next=now+0.035
            local part=W:FindFirstChild(arena=='Main' and 'Bowling Ball' or 'Default')
            local s=liveState(arena)
            if part and part:IsA('BasePart') and s and s.Raw then
                local samples=track.Samples
                if track.RawTime~=s.Raw.Time then
                    local special=s.Raw.Tornado~=nil or s.Raw.Magnet~=nil
                    local last=samples[#samples]
                    local continuous=special and track.PreviousSpecial and last
                        and now-last.T<0.25 and (last.P-part.Position).Magnitude<20
                    if not continuous then table.clear(samples) end
                    track.RawTime=s.Raw.Time
                    track.PreviousSpecial=special
                    if not special then
                        track.UncertainUntil=nil
                        track.UncertainRawTime=nil
                    end
                end
                samples[#samples+1]={P=part.Position,T=now}
                while #samples>15 or (#samples>2 and now-samples[1].T>0.48) do
                    table.remove(samples,1)
                end
                if #samples>=4 then
                    local first,last=samples[1],samples[#samples]
                    local dt=last.T-first.T
                    -- A partir do fim do trecho que bate na parede, a
                    -- parabola original NAO deve mais representar a bola.
                    -- Aguardar o BallState seguinte sem apagar a previsao.
                    local pastKnownBounce=s.BounceEstimated and
                        W:GetServerTimeNow()>=s.RawEndTime-0.03
                    if dt>=0.095 and not pastKnownBounce then
                        local raw=s.Raw
                        local t0=math.clamp(W:GetServerTimeNow()-raw.Time-dt,0,12)
                        local t1=math.clamp(W:GetServerTimeNow()-raw.Time,0,12)
                        local expected=position(raw,t1)-position(raw,t0)
                        local observed=last.P-first.P
                        -- Difference between ACTUAL displacement and
                        -- ballistic displacement; cancels visual offsets.
                        local error=(observed-expected).Magnitude
                        local speed=observed.Magnitude/dt
                        local unstable=error>math.max(2.5,dt*13)
                            and speed>3
                        if unstable then
                            s.MotionUncertain=true
                            track.UncertainUntil=now+0.40
                            track.UncertainRawTime=s.Raw.Time
                        elseif track.UncertainUntil and now>track.UncertainUntil then
                            s.MotionUncertain=false
                        end
                    end
                end
            else
                table.clear(track.Samples)
                track.RawTime=nil
                track.PreviousSpecial=false
            end
        end
    end
end

-- Tornado/Curve/Magnet: o estado de rede pode ter velocidade zero ou
-- trajetoria alterada pela habilidade. A previsao normal nao serve.
-- Usar amostras recentes da bola visivel e projetar ate o solo, sem limitar
-- a 0.39 s. E uma ESTIMATIVA que se atualiza conforme a curva muda.
local function liveFloor(arena)
    local track=liveTracks[arena]
    local s=liveState(arena)
    if not track or not s or not s.Raw then return nil end
    local now=os.clock()
    -- Nao refazer raycasts em todos os Heartbeats; manter a ultima
    -- marcacao viva entre as leituras de movimento.
    if track.LastLiveCalc and track.LastLiveRawTime==s.Raw.Time
        and now-track.LastLiveCalc<0.085 then
        if track.LastLivePoint then
            return track.LastLivePoint,track.LastLiveNormal,
                math.max(0.04,(track.LastLiveDelay or 0.3)-(now-track.LastLiveCalc))
        end
        return nil
    end
    track.LastLiveCalc=now
    track.LastLiveRawTime=s.Raw.Time
    local q=track.Samples
    local last=q[#q]
    if not last or now-last.T>0.30 then return nil end
    local ballPos=last.P
    local p=params()
    local floorY=track.FloorY
    local groundHit=nil
    local function validGround(hit)
        return hit and hit.Normal.Y>=0.86
            and not (hit.Instance and FPS.HiddenOriginals[hit.Instance]~=nil)
    end
    -- Buscar o piso da arena, e NAO exigir que ele fique logo abaixo
    -- da bola: durante o tornado ela pode estar sobre mar/parede.
    local root=character()
    if root and (not track.FloorCheckedAt or now-track.FloorCheckedAt>0.55) then
        track.FloorCheckedAt=now
        local underPlayer=predictionCast(root.Position+Vector3.new(0,3,0),
            Vector3.new(0,-50,0),p)
        if validGround(underPlayer) and math.abs(root.Position.Y-underPlayer.Position.Y)<22 then
            floorY=underPlayer.Position.Y
            groundHit=underPlayer
        end
    end
    if not floorY then
        local underBall=predictionCast(ballPos+Vector3.new(0,3,0),
            Vector3.new(0,-200,0),p)
        if validGround(underBall) then
            floorY=underBall.Position.Y
            groundHit=underBall
        end
    end
    if not floorY then
        -- Fallback: altura do jogador em quadra. Nao confundir a
        -- altura da bola (que oscila no tornado) com a do piso.
        if root and detectMode() == arena then
            floorY=root.Position.Y-3
        end
    end
    if floorY then track.FloorY=floorY end

    -- A velocidade real e estimada a partir das ultimas amostras. O
    -- BallState do tornado pode informar Velocity=(0,0,0) mesmo
    -- enquanto a bola se move em uma curva no cliente.
    local v=Vector3.zero
    local acc=Vector3.zero
    local measured=false
    if #q>=2 then
        local prev=q[math.max(1,#q-4)]
        local dt=last.T-prev.T
        if dt>=0.022 then
            local estimate=(last.P-prev.P)/dt
            if estimate.Magnitude<320 then
                v=estimate
                measured=true
            end
        end
    end
    if #q>=5 then
        local first=q[math.max(1,#q-8)]
        local mid=q[math.max(2,#q-4)]
        local dt1=mid.T-first.T
        local dt2=last.T-mid.T
        if dt1>=0.035 and dt2>=0.035 then
            local v1=(mid.P-first.P)/dt1
            local v2=(last.P-mid.P)/dt2
            local a=(v2-v1)/math.max(0.04,(dt1+dt2)*0.5)
            local horizontal=Vector3.new(a.X,0,a.Z)
            if horizontal.Magnitude>80 then horizontal=horizontal.Unit*80 end
            acc=horizontal
            if v2.Magnitude<320 then v=v2; measured=true end
        end
    end
    local raw=s.Raw
    local gravity=raw.Gravity
    if typeof(gravity)~='Vector3' or gravity.Y>=-0.5 then
        gravity=Vector3.new(0,-10,0)
    end
    if not measured then
        if typeof(raw.Velocity)=='Vector3' and raw.Velocity.Magnitude>1 then
            v=raw.Velocity
        else
            -- Ainda sem velocidade confiavel: exibir o alvo do poder,
            -- se ele for espacial; senao usar a projeção vertical.
            v=Vector3.zero
        end
    end

    -- Sem amostras suficientes, a projecao de Tornado/Magnet a partir
    -- de Velocity=0 pode estar completamente errada. Nao inventar ponto.
    if not measured and #q<3 and typeof(raw.Target)~='Vector3' then
        return nil
    end
    local t=0.55
    if floorY then
        local h=ballPos.Y-(floorY+radius(arena))
        if h>0.05 then
            local d=v.Y*v.Y-2*gravity.Y*h
            if d>=0 then
                local solution=(-v.Y-math.sqrt(d))/gravity.Y
                if solution==solution and solution>=0 then
                    t=math.clamp(solution,0.04,6.0)
                end
            end
        else
            t=0.08
        end
    else
        local remaining=raw.EndTime-W:GetServerTimeNow()
        if type(remaining)=='number' and remaining>0 and remaining<6 then
            t=math.clamp(remaining,0.15,4.0)
        end
    end
    -- Manter o comportamento conservador enquanto a habilidade curva;
    -- o marcador atualiza a cada ~85ms, sem tentar adivinhar giros longos.
    local effectTime=math.min(t,0.65)
    local shift=Vector3.new(v.X*t+acc.X*0.5*effectTime*effectTime,
        0,v.Z*t+acc.Z*0.5*effectTime*effectTime)
    local guessed=ballPos+shift
    if not measured and typeof(raw.Target)=='Vector3' then
        local target=raw.Target
        if (Vector3.new(target.X-ballPos.X,0,target.Z-ballPos.Z)).Magnitude<180 then
            guessed=target
        end
    end

    -- A bola pode cruzar paredes, mas o ponto final de pouso deve
    -- permanecer numa zona de quadra conhecida, nao no mar.
    local chosen,minimum=nil,math.huge
    for _,z in ipairs(zones[arena]) do
        if typeof(z)=='Instance' and z:IsA('BasePart') and z.Parent then
            local lp=z.CFrame:PointToObjectSpace(guessed)
            local lx=math.clamp(lp.X,-math.max(1,z.Size.X*0.5-1),math.max(1,z.Size.X*0.5-1))
            local lz=math.clamp(lp.Z,-math.max(1,z.Size.Z*0.5-1),math.max(1,z.Size.Z*0.5-1))
            local clamped=z.CFrame:PointToWorldSpace(Vector3.new(lx,lp.Y,lz))
            local dx=clamped.X-guessed.X
            local dz=clamped.Z-guessed.Z
            local dist=dx*dx+dz*dz
            if dist<minimum then minimum,chosen=dist,clamped end
        end
    end
    if chosen and minimum>0 then
        -- v9.7 projetava pontos distantes para a borda da quadra;
        -- um circulo plausivel na tela podia estar dezenas de studs errado.
        if math.sqrt(minimum)>10 then return nil end
        guessed=Vector3.new(chosen.X,guessed.Y,chosen.Z)
    end
    local topY=math.max(ballPos.Y+25,(floorY or ballPos.Y)+90)
    local landing=predictionCast(Vector3.new(guessed.X,topY,guessed.Z),
        Vector3.new(0,-270,0),p)
    local finalPos,finalNormal
    if validGround(landing) and (not floorY
        or math.abs(landing.Position.Y-floorY)<13) then
        finalPos,finalNormal=landing.Position,landing.Normal
        floorY=landing.Position.Y
        track.FloorY=floorY
    elseif floorY and chosen and minimum<=9 then
        -- Fallback somente bem dentro da zona real (ate 3 studs da
        -- area): nao marcar mar, blocos ocultos ou solo inventado.
        finalPos=Vector3.new(guessed.X,floorY,guessed.Z)
        finalNormal=Vector3.yAxis
    else
        -- Sem altura de solo conhecida: guardar as amostras e esperar
        -- encontrar uma quadra, ao inves de marcar uma parede.
        return nil
    end
    -- Evitar que uma previsao antiga sobreviva ao fim da jogada.
    track.LastLivePoint=finalPos
    track.LastLiveNormal=finalNormal
    track.LastLiveDelay=t
    track.LastGroundPoint=finalPos
    track.LastGroundNormal=finalNormal
    track.LastGroundAt=now
    track.LastGroundRawTime=raw.Time
    return finalPos,finalNormal,t
end

correctedState=function(arena)
    local s=liveState(arena)
    if not s then return nil end
    local track=liveTracks[arena]
    local now=os.clock()
    local special=s.AbilitySpecial or (s.Raw and
        (s.Raw.Tornado~=nil or s.Raw.Magnet~=nil))
    if special then
        local point,normal,delay=liveFloor(arena)
        if point then
            return {Arena=arena,Time=s.Time,EndTime=W:GetServerTimeNow()+delay,
                Point=point,Normal=normal,Surface='floor',
                Zones=s.Zones,Error=2,ImpactSpeed=s.ImpactSpeed,
                FallSpeed=1,Reliable=false,Live=true}
        end
        -- So manter um ponto do MESMO BallState por poucos frames.
        if track.LastGroundPoint and track.LastGroundRawTime==s.Raw.Time
            and now-(track.LastGroundAt or -math.huge)<0.16 then
            return {Arena=arena,Time=s.Time,EndTime=W:GetServerTimeNow()+0.08,
                Point=track.LastGroundPoint,Normal=track.LastGroundNormal,
                Surface='floor',Zones=s.Zones,Error=3,
                ImpactSpeed=s.ImpactSpeed,FallSpeed=1,Reliable=false,Live=true}
        end
        return nil
    end
    -- Mudanca real nao explicada pelo BallState: o rastreamento visual
    -- nao consegue reconstruir a nova colisao com seguranca. Ocultar.
    if s.MotionUncertain or (track.UncertainUntil and
        now<track.UncertainUntil and track.UncertainRawTime==s.Raw.Time) then
        return nil
    end
    -- Nao insistir numa previsao calculada ANTES do rebote quando
    -- o servidor ja deveria ter enviado o proximo trecho.
    if s.BounceEstimated and type(s.RawEndTime)=='number'
        and W:GetServerTimeNow()>s.RawEndTime+0.07 then
        return nil
    end
    return s
end

-- v8.0: ShiftLock e exclusivo do Roblox. O inspector confirmou
-- que o dive segue o avatar com mouse LockCurrentPosition e LockCenter.
-- O script apenas LE esse estado; nunca tenta alterna-lo.
local function shiftLockAtivo()
    return U.MouseBehavior==Enum.MouseBehavior.LockCenter
end

local function restoreRotation()
    if rotHum and rotHum.Parent and rotOriginal~=nil then
        rotHum.AutoRotate=rotOriginal
    end
    rotHum,rotOriginal=nil,nil
end
local function keepRotation(hum)
    if rotHum~=hum then
        restoreRotation()
        rotHum,rotOriginal=hum,hum.AutoRotate
    end
    hum.AutoRotate=false
end
local function restoreCamera()
    -- Mantido para os callbacks existentes. Camera nunca e alterada.
    restoreRotation()
end
local function face(root,hum,target)
    local dir=horizontal(root.Position,target)
    if not dir then return end
    keepRotation(hum)
    root.CFrame=CFrame.lookAt(root.Position,root.Position+dir)
end

local function targetLock(root)
    local best,distance=nil,math.huge
    local mode=detectMode()
    for arena in pairs(markers) do
        if arena==mode then
            local s=active(arena)
            if s and s.Point and s.Surface=='floor'
                and s.Reliable and not s.MotionUncertain then
                local d=(s.Point-root.Position).Magnitude
                if d<distance then best,distance=s.Point,d end
            end
        end
    end
    return best
end
-- =====================================
-- CORTE DIRECIONAL: segure a tecla configurada durante um pulo.
-- Enquanto estiver no ar, a orientacao do avatar segue a CAMERA.
-- Ao clicar para cortar, trava o vetor horizontal ANTES do clique
-- e o mantem por alguns frames para a animacao registrar a direcao.
-- Nao modifica Camera.CFrame ou pacotes enviados ao servidor.
-- =====================================
local spikeHeld=false
local spikeJumped=false
local spikeJumpHum=nil
local spikeStateLink=nil
local spikeCaptureKey=false
local spikeKeyRefresh=nil
local spikeLockedDir=nil
local spikeLockedUntil=0
local spikeLastClick=-math.huge
local function clearSpikeLock()
    spikeLockedDir=nil
    spikeLockedUntil=0
end
local function directionFromCamera()
    local cam=W.CurrentCamera
    if not cam then return nil end
    local look=cam.CFrame.LookVector
    local flat=Vector3.new(look.X,0,look.Z)
    if flat.Magnitude<0.025 then return nil end
    return flat.Unit
end
local function isSpikeJump(hum)
    if not hum or hum.Health<=0 or not spikeJumped or spikeJumpHum~=hum then
        return false
    end
    return hum.FloorMaterial==Enum.Material.Air
end
local function attachSpikeJump(char)
    if spikeStateLink then spikeStateLink:Disconnect() spikeStateLink=nil end
    spikeJumped=false
    spikeJumpHum=nil
    clearSpikeLock()
    local hum=char:FindFirstChildOfClass('Humanoid') or char:WaitForChild('Humanoid',5)
    if stopped or not hum then return end
    spikeJumpHum=hum
    if hum:GetState()==Enum.HumanoidStateType.Jumping then spikeJumped=true end
    spikeStateLink=hum.StateChanged:Connect(function(_,newState)
        if newState==Enum.HumanoidStateType.Jumping then
            spikeJumped=true
        elseif newState==Enum.HumanoidStateType.Landed
            or newState==Enum.HumanoidStateType.Running
            or newState==Enum.HumanoidStateType.RunningNoPhysics
            or newState==Enum.HumanoidStateType.Dead
            or newState==Enum.HumanoidStateType.Seated then
            spikeJumped=false
        end
    end)
end
if me.Character then attachSpikeJump(me.Character) end
links[#links+1]=me.CharacterAdded:Connect(attachSpikeJump)

local function orientSpike(root,hum,dir)
    if not dir then return false end
    keepRotation(hum)
    root.CFrame=CFrame.lookAt(root.Position,root.Position+dir)
    return true
end
local function spikeAvailable()
    if stopped or not C.SpikeDirection or spikeCaptureKey then return false end
    if os.clock()-lastPhysicalPress<0.35 then return false end
    if C.SmartDive and steerActive and os.clock()<steerUntil then return false end
    local root,hum=character()
    return root~=nil and isSpikeJump(hum)
end
local function onSpikeClick()
    if not spikeAvailable() or not spikeHeld then return end
    local now=os.clock()
    if now-spikeLastClick<0.08 then return end
    local dir=directionFromCamera()
    if not dir then return end
    spikeLastClick=now
    spikeLockedDir=dir
    -- Apenas a janela curta em que a animacao determina o lado do corte.
    spikeLockedUntil=now+0.40
    local root,hum=character()
    if root and hum then orientSpike(root,hum,dir) end
end
local function updateSpikeFacing(root,hum)
    if not C.SpikeDirection then clearSpikeLock() return false end
    local now=os.clock()
    if now<spikeLockedUntil and spikeLockedDir then
        if hum.Health>0 and hum.FloorMaterial==Enum.Material.Air then
            return orientSpike(root,hum,spikeLockedDir)
        end
        clearSpikeLock()
        return false
    end
    if spikeLockedDir then clearSpikeLock() end
    -- Antes do clique, apontar o corpo continuamente para a camera;
    -- o clique captura essa direcao e nao a deixa variar depois.
    if spikeHeld and spikeAvailable() then
        return orientSpike(root,hum,directionFromCamera())
    end
    return false
end

-- Observacao da tecla: o proprio E continua reservado para Dive.
links[#links+1]=U.InputBegan:Connect(function(input,processed)
    if stopped then return end
    if spikeCaptureKey and input.UserInputType==Enum.UserInputType.Keyboard then
        local name=input.KeyCode.Name
        if name=='Escape' then
            spikeCaptureKey=false
            if spikeKeyRefresh then spikeKeyRefresh() end
            return
        end
        if name:match('^[A-Z]$') and not string.find('WASDE',name,1,true) then
            C.SpikeKey=name
            spikeHeld=false
            spikeCaptureKey=false
            clearSpikeLock()
            saveSettings()
            if spikeKeyRefresh then spikeKeyRefresh() end
        end
        return
    end
    if U:GetFocusedTextBox() then return end
    if input.UserInputType==Enum.UserInputType.Keyboard
        and input.KeyCode.Name==C.SpikeKey then
        spikeHeld=true
    elseif input.UserInputType==Enum.UserInputType.MouseButton1 and not processed then
        -- Fallback para jogos que usam UserInputService, sem engolir o clique.
        onSpikeClick()
    end
end)
links[#links+1]=U.InputEnded:Connect(function(input)
    if input.UserInputType==Enum.UserInputType.Keyboard
        and input.KeyCode.Name==C.SpikeKey then
        spikeHeld=false
    end
end)
-- CAS em prioridade alta para registrar a direcao antes da acao nativa,
-- sem consumir MouseButton1 ou interferir em ataques normais.
local spikeBindOK=pcall(function()
    CAS:BindActionAtPriority(spikeActionKey,function(_,state)
        if state==Enum.UserInputState.Begin then onSpikeClick() end
        return Enum.ContextActionResult.Pass
    end,false,9000,Enum.UserInputType.MouseButton1)
end)
if not spikeBindOK then
    warn('[VolleyBomb] Captura do corte por CAS indisponivel; usando InputBegan')
end

-- CAS observa E na prioridade 10000, mira antes da acao Dive (2000)
-- e deixa o E original continuar sem nenhum bloqueio.

local function samplePing()
    if os.clock()-lastPing<1 then return end
    lastPing=os.clock()
    local ok,p=pcall(function() return me:GetNetworkPing() end)
    if ok and type(p)=='number' and p>=0 and p<2 then ping=p end
end
local function learnDive()
    if not sample or os.clock()-sample.Start<0.33 then return end
    local root=character()
    if root then
        local delta=root.Position-sample.Position
        local speed=delta:Dot(sample.Direction)/(os.clock()-sample.Start)
        if speed>10 and speed<120 then
            measuredSpeed=measuredSpeed and measuredSpeed*0.6+speed*0.4 or speed
        end
    end
    sample=nil
end
local function diveSpeed()
    return math.clamp(measuredSpeed or C.DiveSpeed,15,100)
end
-- =====================================
-- DIVE INTELIGENTE V7.7: UM E, UM ALVO CONGELADO
-- Nenhuma espera pela bola, distancia ou angulo da camera.
-- Nao muda ShiftLock/MouseBehavior nem Camera.CFrame.
-- Nao manda E artificial. O jogo recebe o E original.
-- Apos detectar o impulso nativo, acompanha a linha reta ate o ponto capturado.
-- =====================================

-- Usa a posicao REAL DO INDICADOR que ja estava desenhado quando E
-- foi pressionado. Nao consulta BallState nem refaz a previsao.
-- 0.12s de tolerancia cobre o caso em que o indicador acabou de sumir
-- porque a bola atingiu o solo entre dois frames.
local function smartCandidate()
    local root=character()
    if not root then return nil end
    local nearest,chosen,chosenArena=math.huge,nil,nil
    local now=os.clock()
    local mode=detectMode(true)
    for _,arena in ipairs({'Main','Practice'}) do
        local m=markers[arena]
        if arena==mode and m and m.LastPoint and
            (m.Visible or (m.LastVisibleAt and now-m.LastVisibleAt<=0.12)) then
            local delta=m.LastPoint-root.Position
            local distance=Vector3.new(delta.X,0,delta.Z).Magnitude
            if distance<nearest then
                nearest,chosen,chosenArena=distance,m.LastPoint,arena
            end
        end
    end
    return chosen,chosenArena,nearest
end

local function stopSteering()
    steerActive=false
    steerStarted=false
    steerTarget=nil
    steerDirection=nil
    steerStartPosition=nil
    lastSteerDistance=nil
    steerPathLength=0
    steerAnimationSeen=false
end

-- Comeca em estado de espera pelo impulso nativo, nao pela bola.
-- Esta espera e apenas pelo movimento do dive REAL disparado pelo E.
local function aimAndDiveNatively()
    if stopped or not C.SmartDive then return end
    local now=os.clock()
    lastPhysicalPress=now
    stopSteering()
    local target,arena,dist=smartCandidate()
    local root,hum=character()
    if not root or not hum then return end
    restoreRotation()
    aimTarget=nil
    aimUntil=0

    -- Sem um indicador existente no instante do clique, E e nativo.
    if not target then
        lastDecision='E original: nenhum indicador naquele instante'
        return
    end
    local direction=horizontal(root.Position,target)
    if not direction then
        lastDecision='E original: ja esta no indicador'
        return
    end

    -- Snapshot imutavel; novos BallState/indicadores NAO mudam o destino.
    steerTarget=Vector3.new(target.X,target.Y,target.Z)
    steerDirection=direction
    steerStartPosition=root.Position
    steerPathLength=dist
    steerAnimationSeen=false
    steerArmedAt=now
    steerUntil=now+math.clamp(dist/108+0.70,0.85,C.ChaseWindow)
    steerStarted=false
    steerActive=true
    clearSpikeLock()
    lastDecision=string.format('E -> indicador %s salvo, %.1f studs',arena,dist)
    print(string.format('[VolleyBomb v8.0 Dive] E NATIVO | alvo=%s | distancia=%.1f | ponto=(%.1f,%.1f,%.1f) | shiftlock=%s',
        arena,dist,target.X,target.Y,target.Z,tostring(shiftLockAtivo())))
end

-- v8.0: retorna o controle de velocidade/frenagem da v7.7, MAS
-- nao muda a trajetoria depois do E. A direcao e uma linha reta
-- fixa do ponto inicial ate o indicador naquele instante.
-- NAO consulta bola/indicador novamente, nao gira camera ou avatar.
-- O E original inicia o movimento antes da primeira correcao fisica.
local wallCast=params()
local wallCastChar=me.Character
local lastWallFilter=0
local function obstacleAhead(root,dir)
    if me.Character~=wallCastChar or os.clock()-lastWallFilter>2 then
        wallCastChar=me.Character
        wallCast=params()
        lastWallFilter=os.clock()
    end
    -- Para antes de uma parede fisica; jamais tenta desviar por outro lado.
    -- O raio e horizontal e parte da altura do personagem.
    local ok,hit=pcall(function()
        return W:Raycast(root.Position+Vector3.new(0,0.75,0),dir*3.2,wallCast)
    end)
    return ok and hit and math.abs(hit.Normal.Y)<0.55 and hit.Distance<=2.8
end
local function steerPhysics()
    if stopped or not C.SmartDive or not steerActive or not steerDirection then return end
    local root,hum=character()
    if not root or not hum or root.Anchored
        or hum:GetState()==Enum.HumanoidStateType.Dead then
        stopSteering()
        return
    end
    local now=os.clock()
    if now>steerUntil then
        -- Sem inventar um impulso novo quando a janela termina.
        -- Solta o movimento; o jogo reassume a simulacao.
        lastDecision=steerStarted and 'Dive finalizado: limite de tempo' or 'E sem dive detectado'
        stopSteering()
        return
    end
    local velocity=root.AssemblyLinearVelocity
    local flat=Vector3.new(velocity.X,0,velocity.Z).Magnitude

    -- Nao empurrar avatar se o E original estiver em cooldown.
    if not steerStarted then
        if now-steerArmedAt>0.34 then
            lastDecision='E original nao iniciou dive (possivel cooldown)'
            stopSteering()
            return
        end
        if (flat>=52 and flat<=175) or (steerAnimationSeen and flat>=16) then
            steerStarted=true
            steerDetectedAt=now
            steerStartSource='impulso'
            lastDecision='Dive iniciado: linha reta para indicador salvo'
            print('[VolleyBomb v8.0 Dive] Movimento real detectado; direcao congelada')
        else
            return
        end
    end

    -- Progresso sobre A LINHA ORIGINAL, e nao distancia atual ate o
    -- indicador. Esse calculo impede curvas, retorno ou busca lateral.
    local offset=root.Position-steerStartPosition
    local delta=Vector3.new(offset.X,0,offset.Z)
    local progress=delta:Dot(steerDirection)
    local left=steerPathLength-progress

    if left<=1.9 then
        root.AssemblyLinearVelocity=Vector3.new(0,velocity.Y,0)
        lastDecision='Indicador salvo alcancado na linha original'
        stopSteering()
        return
    end

    -- Caso haja desvio por impacto/teleporte, NAO correr atras do alvo.
    -- Desliga a assistencia para nao mudar a rota original.
    local sideways=(delta-steerDirection*progress).Magnitude
    if sideways>7 then
        lastDecision='Trajetoria desviada: sem perseguir indicador'
        stopSteering()
        return
    end
    if obstacleAhead(root,steerDirection) then
        root.AssemblyLinearVelocity=Vector3.new(0,velocity.Y,0)
        lastDecision='Parede na linha do dive: sem atravessar ou desviar'
        stopSteering()
        return
    end

    -- MESMA curva de velocidade e frenagem da v7.7, so que projetada
    -- sempre na DIRECAO INICIAL. O personagem pode desacelerar/parar,
    -- mas o script nunca faz curva para corrigir a trajetoria.
    local speed=math.clamp((left-1.2)*13,26,118)
    local corrected=steerDirection*speed
    root.AssemblyLinearVelocity=Vector3.new(corrected.X,velocity.Y,corrected.Z)
end

-- PostSimulation acontece depois da fisica padrao, reduzindo disputa
-- com o impulso do jogo. Heartbeat e apenas um fallback.
local physicsOK,physicsConn=pcall(function()
    return Run.PostSimulation:Connect(steerPhysics)
end)
if physicsOK and physicsConn then
    links[#links+1]=physicsConn
else
    links[#links+1]=Run.Heartbeat:Connect(steerPhysics)
end

-- Fallback caso o ContextActionService nao aceite o bind.
-- InputBegan nao bloqueia o E do jogo em nenhuma circunstancia.
links[#links+1]=U.InputBegan:Connect(function(input)
    if stopped or input.KeyCode~=Enum.KeyCode.E or not C.SmartDive
        or inputBound or U:GetFocusedTextBox()~=nil then return end
    aimAndDiveNatively()
end)

-- Uma parede NAO e um ponto de queda. Aguardar o proximo BallState
-- somente quando o rebote estiver proximo e for possivel reproduzir E.
local function wallCandidate()
    local mode=detectMode()
    local root,hum=character()
    if not root or hum.FloorMaterial==Enum.Material.Air then return nil end
    local now=W:GetServerTimeNow()
    local result,best=nil,math.huge
    for arena in pairs(markers) do
        if arena==mode then
            local s=active(arena)
            if s and not s.MotionUncertain and s.Reliable and s.Surface=='wall' and s.Point then
                local untilWall=s.EndTime-now
                local _,dist=horizontal(root.Position,s.Point)
                if untilWall>0.02
                    and untilWall<=math.min(1.05,C.DiveLead+0.2)
                    and dist<=65 then
                    local score=untilWall+dist*0.005
                    if score<best then result,best=s,score end
                end
            end
        end
    end
    return result
end

-- Perfil medido depois de E; uma animacao so e insuficiente
-- para concluir que a defesa pegou a bola.
local function startProfile()
    local root=character()
    if not root then return end
    profileSample={Start=os.clock(),Position=root.Position,
        Direction=root.CFrame.LookVector,LastBin=-1}
end

local function measureProfile()
    if not profileSample then return end
    local root=character()
    if not root then profileSample=nil return end
    local elapsed=os.clock()-profileSample.Start
    local bin=math.floor(elapsed/0.05)
    if bin>profileSample.LastBin and bin>=1 and bin<=11 then
        profileSample.LastBin=bin
        local dir=Vector3.new(profileSample.Direction.X,0,
            profileSample.Direction.Z)
        if dir.Magnitude>0.01 then
            local delta=root.Position-profileSample.Position
            local dist=math.max(0,delta:Dot(dir.Unit))
            if dist>=0 and dist<=80 then
                local prior=learnedDiveProfile[bin]
                learnedDiveProfile[bin]=prior and
                    (prior*0.65+dist*0.35) or dist
            end
        end
    end
    if elapsed>=0.60 then profileSample=nil end
end

local function travelSeconds(dist)
    local travel=math.max(0,dist-2.2)
    -- Deslocamento real observado apos a animacao. Nao extrapolar o
    -- perfil apos o ultimo ponto e nao assumir que todo dive e igual.
    local previous=0
    for bin=1,11 do
        local d=learnedDiveProfile[bin]
        if d then
            if d>=travel then
                local fraction=0
                if d>previous+0.01 then
                    fraction=math.clamp((travel-previous)/(d-previous),0,1)
                end
                return math.clamp((bin-1+fraction)*0.05,0.035,0.54)
            end
            previous=math.max(previous,d)
        end
    end
    -- Perfil inicial observado pelo Inspector em 5 dives normais:
    -- ~5 studs em 0.04s, ~12 em 0.10s, ~20 em 0.20s.
    -- Depois a velocidade diminui bastante. Usa curva por trechos,
    -- em vez da antiga media de caminhada de 36 studs/s.
    if travel <= 5 then
        return math.max(0.025, 0.04 * travel/5)
    elseif travel <= 12 then
        return 0.04 + (travel-5)*0.060/7
    elseif travel <= 20 then
        return 0.10 + (travel-12)*0.105/8
    end
    return math.clamp(0.205+(travel-20)*0.055,0.205,0.48)
end

-- Estimativa da antecedencia ideal do comando, em segundos.
local function diveLeadFor(s,dist)
    local network=math.clamp(ping,0,0.16)
    -- Bolas mais rapidas exigem uma margem extra de atualizacao do alvo.
    local speedBonus=math.clamp((s.ImpactSpeed-38)*0.0013,0,0.065)
    -- Margem de antecipacao interna preservada (sem controle visual).
    local manual=math.clamp((C.DiveLead-0.15)*0.055,0,0.075)
    return math.clamp(travelSeconds(dist)+network
        +C.InputDelay+C.SafetyLead+speedBonus+manual,0.13,0.78)
end

-- Quando uma bola esta muito perto do solo, nao vale esperar
-- mais frames tentando otimizar um dive: o E sai imediatamente.
local function shouldLaunchNow(s,remaining,lead)
    local speedPad=math.clamp((s.ImpactSpeed-48)*0.0011,0,0.055)
    return remaining<=lead+C.EmergencyWindow+speedPad
        or remaining<=math.max(0.18,ping*0.5+0.12)
end

local function observedDive()
    lastNativeStart=os.clock()
    lastDive=os.clock()
    if steerActive and os.clock()-steerArmedAt<=0.34 then
        -- Animacao confirma que o E foi aceito; so movimenta apos
        -- a velocidade real do dive aparecer para evitar arranque falso.
        steerAnimationSeen=true
    end
    if pending then
        print('[VolleyBomb v8.0 Dive] Animacao do dive detectada: cancelar comando duplicado')
        pending=nil
    end
    startProfile()
    -- Assim que a animacao confirma o dive, nao mirar novamente.
    aimTarget=nil
    aimUntil=0
    restoreRotation()
end

local animationLink
local function attachAnimator()
    if animationLink then animationLink:Disconnect() animationLink=nil end
    local ch=me.Character
    if not ch then return end
    task.spawn(function()
        local hum=ch:WaitForChild('Humanoid',5)
        if not hum or stopped then return end
        local animator=hum:WaitForChild('Animator',5)
        if not animator or stopped then return end
        animationLink=animator.AnimationPlayed:Connect(function(track)
            local animation=track.Animation
            local id=animation and animation.AnimationId or ''
            if string.find(id,'125582828675515',1,true)
                and os.clock()-lastPhysicalPress<2 then
                observedDive()
            end
        end)
    end)
end
attachAnimator()
links[#links+1]=me.CharacterAdded:Connect(attachAnimator)

-- Nao agendar, reexecutar nem consumir o E. Comando nativo livre.
local function cancelSmart()
    pending=nil
    aimTarget=nil
    aimUntil=0
    stopSteering()
end

-- Explicacao por E nao elegivel: evitar diagnosticos cegos.
local function explainNoCandidate()
    local root=character()
    for arena in pairs(markers) do
        local s=active(arena)
        if s then
            local _,dist=nil,nil
            if root and s.Point then
                _,dist=horizontal(root.Position,s.Point)
            end
            local same=(root and s.Point) and ownSide(s,root) or false
            print(string.format(
                '[VolleyBomb v8.0 Dive] %s | tipo=%s | confiavel=%s | incerto=%s | dist=%s | minhaArea=%s | faltam=%.3fs',
                arena,tostring(s.Surface),tostring(s.Reliable),
                tostring(s.MotionUncertain),dist and string.format('%.1f',dist) or '?',
                tostring(same),s.EndTime-W:GetServerTimeNow()))
        end
    end
end

local function onSmartDive(_,inputState)
    if stopped or not C.SmartDive then
        return Enum.ContextActionResult.Pass
    end
    if inputState==Enum.UserInputState.Begin and not U:GetFocusedTextBox() then
        aimAndDiveNatively()
    end
    -- NUNCA Sink: este proprio E deve chegar na acao Dive nativa.
    return Enum.ContextActionResult.Pass
end

local function shouldBindSmart()
    return not stopped and C.SmartDive
end

local function updateEIntercept()
    local bind=shouldBindSmart()
    if bind and not inputBound then
        local ok,err=pcall(function()
            CAS:BindActionAtPriority(actionKey,onSmartDive,false,10000,Enum.KeyCode.E)
        end)
        inputBound=ok
        if ok then print('[VolleyBomb v8.0] E monitorado: Pass ao Dive nativo (prioridade 2000)') end
        if not ok then
            warn('[VolleyBomb] Nao foi possivel interceptar E: '..tostring(err))
        end
    elseif not bind and inputBound then
        CAS:UnbindAction(actionKey)
        inputBound=false
        print('[VolleyBomb v8.0] E assistido desconectado; E 100% nativo')
    end
end

-- Sem espera por queda: o proprio E original inicia o dive imediatamente.

links[#links+1]=Run.Heartbeat:Connect(function()
    if stopped then return end
    samplePing()
    learnDive()
    updateBallMotion()
    updateMarkers()
    measureProfile()
    updateEIntercept()
end)

Run:BindToRenderStep(renderKey,Enum.RenderPriority.Camera.Value+10,function()
    if stopped then return end
    local root,hum=character()
    if not root then restoreCamera() return end

    -- Durante o dive, o corte nao pode disputar a direcao.
    if steerActive then
        restoreRotation()
        return
    end
    -- O corte pode travar o lado durante um pulo sem tocar na camera.
    if updateSpikeFacing(root,hum) then return end

    -- Lock-on do menu continua funcionando em separado quando ativado.
    if C.LockOn and not C.SmartDive then
        local point=targetLock(root)
        if point and not shiftLockAtivo() then face(root,hum,point)
        else restoreRotation() end
    elseif os.clock()>aimUntil then
        restoreRotation()
    end
end)

-- Sem PreSimulation/PostSimulation modificando AssemblyLinearVelocity.
-- A direcao do E e lida pela rotina nativa do jogo.

-- =====================================
-- INTERFACE: ICONE AVATAR E PAINEL
-- =====================================
local holder=me:WaitForChild('PlayerGui')
if type(gethui)=='function' then
    local ok,p=pcall(gethui)
    if ok and typeof(p)=='Instance' then holder=p end
end
local gui=make('ScreenGui',{Name='VolleyBombLandingUI',IgnoreGuiInset=true,
    ResetOnSpawn=false,DisplayOrder=150,ZIndexBehavior=Enum.ZIndexBehavior.Sibling},holder)
local width,height,iconSize=264,240,46
local function viewport()
    local cam=W.CurrentCamera
    return cam and cam.ViewportSize or Vector2.new(1280,720)
end
local function bound(pos,size)
    local v=viewport()
    return Vector2.new(math.clamp(pos.X,5,math.max(5,v.X-size.X-5)),
        math.clamp(pos.Y,5,math.max(5,v.Y-size.Y-5)))
end
local v=viewport()
local iconStart=bound(Vector2.new(
    uiPrefs.IconX or (v.X-iconSize-17),
    uiPrefs.IconY or math.floor(v.Y*0.38)
),Vector2.new(iconSize,iconSize))
local icon=make('ImageButton',{Name='Avatar',Size=UDim2.fromOffset(iconSize,iconSize),
    Position=UDim2.fromOffset(iconStart.X,iconStart.Y),
    Image='rbxthumb://type=AvatarHeadShot&id='..me.UserId..'&w=150&h=150',
    ScaleType=Enum.ScaleType.Crop,BackgroundColor3=Color3.fromRGB(25,28,34),
    AutoButtonColor=false,BorderSizePixel=0,Active=true,ZIndex=10},gui)
make('UICorner',{CornerRadius=UDim.new(1,0)},icon)
make('UIStroke',{Color=Color3.fromRGB(85,245,155),Thickness=2},icon)
local dot=make('Frame',{Size=UDim2.fromOffset(9,9),
    Position=UDim2.new(1,-9,1,-9),BackgroundColor3=Color3.fromRGB(130,135,145),
    BorderSizePixel=0,ZIndex=11},icon)
make('UICorner',{CornerRadius=UDim.new(1,0)},dot)
task.spawn(function()
    local ok,url=pcall(function()
        return P:GetUserThumbnailAsync(me.UserId,Enum.ThumbnailType.HeadShot,
            Enum.ThumbnailSize.Size150x150)
    end)
    if ok and not stopped and icon.Parent then icon.Image=url end
end)
local panelStart=bound(Vector2.new(uiPrefs.PanelX or 20,uiPrefs.PanelY or 85),
    Vector2.new(width,height))
local panel=make('CanvasGroup',{Size=UDim2.fromOffset(width,height),
    Position=UDim2.fromOffset(panelStart.X,panelStart.Y),BackgroundColor3=Color3.fromRGB(20,22,27),
    BorderSizePixel=0,GroupTransparency=1,Visible=false,Active=true},gui)
make('UICorner',{CornerRadius=UDim.new(0,12)},panel)
make('UIStroke',{Color=Color3.fromRGB(55,59,68),Thickness=1},panel)
local scale=make('UIScale',{Scale=0.91},panel)
local header=make('Frame',{Size=UDim2.new(1,0,0,41),
    BackgroundTransparency=1,Active=true},panel)
make('TextLabel',{Text='VOLLEYBOMB',Font=Enum.Font.GothamBold,TextSize=12,
    BackgroundTransparency=1,TextXAlignment=Enum.TextXAlignment.Left,
    TextColor3=Color3.fromRGB(240,243,247),Position=UDim2.fromOffset(13,0),
    Size=UDim2.new(1,-90,1,0)},header)
local collapse=make('TextButton',{Text='−',Font=Enum.Font.GothamBold,TextSize=18,
    BackgroundTransparency=1,TextColor3=Color3.fromRGB(190,194,202),
    Position=UDim2.new(1,-62,0,5),Size=UDim2.fromOffset(27,30)},header)
local close=make('TextButton',{Text='×',Font=Enum.Font.Gotham,TextSize=20,
    BackgroundTransparency=1,TextColor3=Color3.fromRGB(190,194,202),
    Position=UDim2.new(1,-32,0,5),Size=UDim2.fromOffset(27,30)},header)
make('Frame',{BackgroundColor3=Color3.fromRGB(47,51,58),BorderSizePixel=0,
    Position=UDim2.fromOffset(12,42),Size=UDim2.new(1,-24,0,1)},panel)
local content=make('Frame',{BackgroundTransparency=1,Position=UDim2.fromOffset(12,50),
    Size=UDim2.new(1,-24,0,height-60)},panel)
local extras=make('ScrollingFrame',{BackgroundTransparency=1,BorderSizePixel=0,
    ScrollBarThickness=3,ScrollingDirection=Enum.ScrollingDirection.Y,
    CanvasSize=UDim2.fromOffset(0,346),Position=UDim2.fromOffset(12,50),
    Size=UDim2.new(1,-24,0,height-60),Visible=false},panel)
local extrasButton=make('TextButton',{Text='AJUSTES',
    Font=Enum.Font.GothamBold,TextSize=10,
    TextColor3=Color3.fromRGB(162,198,255),
    BackgroundTransparency=1,Position=UDim2.fromOffset(124,5),
    Size=UDim2.fromOffset(74,30)},header)
local extrasOpen=false
links[#links+1]=extrasButton.MouseButton1Click:Connect(function()
    extrasOpen=not extrasOpen
    content.Visible=not extrasOpen
    extras.Visible=extrasOpen
    extrasButton.Text=extrasOpen and 'VOLTAR' or 'AJUSTES'
end)
local function toggle(label,y,key,color,where)
    local b=make('TextButton',{Text='',AutoButtonColor=false,
        BackgroundColor3=Color3.fromRGB(33,36,42),BorderSizePixel=0,
        Position=UDim2.fromOffset(0,y),Size=UDim2.new(1,0,0,41)},where or content)
    make('UICorner',{CornerRadius=UDim.new(0,7)},b)
    local dot=make('Frame',{BackgroundColor3=color,BorderSizePixel=0,
        Position=UDim2.fromOffset(11,16),Size=UDim2.fromOffset(9,9)},b)
    make('UICorner',{CornerRadius=UDim.new(1,0)},dot)
    make('TextLabel',{Text=label,Font=Enum.Font.GothamMedium,TextSize=12,
        TextColor3=Color3.fromRGB(228,231,237),BackgroundTransparency=1,
        TextXAlignment=Enum.TextXAlignment.Left,Position=UDim2.fromOffset(28,0),
        Size=UDim2.new(1,-91,1,0)},b)
    local status=make('TextLabel',{Font=Enum.Font.GothamBold,TextSize=11,
        BackgroundTransparency=1,Position=UDim2.new(1,-54,0,0),
        Size=UDim2.fromOffset(49,41)},b)
    local function refresh()
        status.Text=C[key] and 'ON' or 'OFF'
        status.TextColor3=C[key] and Color3.fromRGB(100,243,156)
            or Color3.fromRGB(143,149,159)
    end
    links[#links+1]=b.MouseButton1Click:Connect(function()
        C[key]=not C[key]
        if key=='FPSBoost' then fpsSetEnabled(C.FPSBoost) end
        if key=='SpikeDirection' and not C[key] then
            spikeHeld=false
            clearSpikeLock()
            if not C.SmartDive then restoreRotation() end
        end
        if key=='SmartDive' then
            if not C.SmartDive then cancelSmart(false) end
            if C.SmartDive then
                -- O alvo agora e qualquer marcador visivel.
                -- Nao tentar travar a area para decidir se E funciona.
                stopSteering()
            else
                aimTarget=nil
                aimUntil=0
                if not C.LockOn then restoreRotation() end
            end
        elseif key=='LockOn' and not C.LockOn and not C.SmartDive then
            restoreRotation()
        end
        saveSettings()
        refresh()
        updateMarkers()
        if key=='SmartDive' then updateEIntercept() end
        end)
    refresh()
    return refresh
end
-- Apenas opcoes que precisam ser ligadas manualmente.
-- Lobby/Practice/Partida e os indicadores mudam automaticamente.
toggle('Lock-on (avatar)',0,'LockOn',Color3.fromRGB(190,160,255))
refreshSmart=toggle('Dive Inteligente',47,'SmartDive',Color3.fromRGB(255,190,90))
toggle('FPS Turbo',94,'FPSBoost',Color3.fromRGB(95,220,183))
-- Painel simplificado: os calculos de dive, tempo e protecao de area
-- continuam ativos internamente. O ajuste manual de antecedencia,
-- o botao de area e o estado textual do dive nao aparecem na interface.
-- A identificacao da zona amiga permanece automatica.
local stats=make('TextLabel',{Text='',Font=Enum.Font.Gotham,TextSize=10,
    TextColor3=Color3.fromRGB(160,169,181),BackgroundTransparency=1,
    TextXAlignment=Enum.TextXAlignment.Left,
    Position=UDim2.fromOffset(2,152),Size=UDim2.new(1,-4,0,18)},content)
local lastStats=0
local fpsEstimate=60
links[#links+1]=Run.RenderStepped:Connect(function(dt)
    if dt>0.001 and dt<1 then
        fpsEstimate=fpsEstimate*0.91+(1/dt)*0.09
    end
end)
links[#links+1]=Run.Heartbeat:Connect(function()
    if stopped or os.clock()-lastStats<0.6 then return end
    lastStats=os.clock()
    local mode=detectMode()
    local label=(mode=='Main' and 'PARTIDA') or (mode=='Practice' and 'PRACTICE') or 'LOBBY'
    stats.Text=string.format('%s • %.0f FPS • %.0f ms',label,fpsEstimate,ping*1000)
    dot.BackgroundColor3=(mode=='Main' and C.MainColor)
        or (mode=='Practice' and C.PracticeColor)
        or Color3.fromRGB(130,135,145)
end)

-- =====================================
-- AJUSTES: DIRECAO ASSISTIDA E SALVAMENTO
-- =====================================
-- Direcao assistida esta integrada ao Dive Inteligente; sem ajuste redundante.
toggle('Corte direcional',4,'SpikeDirection',Color3.fromRGB(255,170,105),extras)
local keyLabel=make('TextLabel',{
    Text='TECLA DO CORTE',Font=Enum.Font.GothamMedium,TextSize=10,
    TextColor3=Color3.fromRGB(173,183,196),BackgroundTransparency=1,
    TextXAlignment=Enum.TextXAlignment.Left,
    Position=UDim2.fromOffset(2,58),Size=UDim2.fromOffset(125,28)
},extras)
local keyButton=make('TextButton',{
    Text='',Font=Enum.Font.GothamBold,TextSize=11,
    TextColor3=Color3.fromRGB(245,247,252),
    BackgroundColor3=Color3.fromRGB(49,54,64),BorderSizePixel=0,
    Position=UDim2.new(1,-112,0,56),Size=UDim2.fromOffset(110,31)
},extras)
make('UICorner',{CornerRadius=UDim.new(0,7)},keyButton)
spikeKeyRefresh=function()
    keyButton.Text=spikeCaptureKey and 'APERTE TECLA' or ('TECLA: '..C.SpikeKey)
end
spikeKeyRefresh()
links[#links+1]=keyButton.MouseButton1Click:Connect(function()
    spikeCaptureKey=true
    spikeHeld=false
    clearSpikeLock()
    spikeKeyRefresh()
end)
make('TextLabel',{
    Text='Segure a tecla no ar e clique: o corpo fica apontado para o lado visto antes do clique. Camera livre.',
    Font=Enum.Font.Gotham,TextSize=10,
    TextColor3=Color3.fromRGB(156,166,178),BackgroundTransparency=1,
    TextXAlignment=Enum.TextXAlignment.Left,TextYAlignment=Enum.TextYAlignment.Top,
    TextWrapped=true,Position=UDim2.fromOffset(2,99),
    Size=UDim2.new(1,-6,0,51)
},extras)

-- Preferencias persistentes
local saveStatus=make('TextLabel',{
    Text='',Font=Enum.Font.Gotham,TextSize=11,
    TextColor3=Color3.fromRGB(165,175,186),
    BackgroundTransparency=1,TextXAlignment=Enum.TextXAlignment.Left,
    Position=UDim2.fromOffset(2,162),Size=UDim2.new(1,-8,0,46),
    TextWrapped=true
},extras)
local function refreshSaveStatus()
    if saveLocation=='arquivo' then
        saveStatus.Text='Configurações salvas automaticamente neste PC.'
    else
        saveStatus.Text='Configurações salvas na sessão. Arquivo indisponível neste executor.'
    end
end
make('TextLabel',{Text='FPS TURBO: esconde decorações do lobby e pequenos detritos do mar. Preserva todas as quadras, suas texturas de cor, jogadores e colisões.',
    Font=Enum.Font.Gotham,TextSize=10,
    TextColor3=Color3.fromRGB(157,165,176),BackgroundTransparency=1,
    TextXAlignment=Enum.TextXAlignment.Left,TextYAlignment=Enum.TextYAlignment.Top,
    TextWrapped=true,Position=UDim2.fromOffset(2,219),
    Size=UDim2.new(1,-4,0,65)},extras)

saveSettings()
refreshSaveStatus()
fpsSetEnabled(C.FPSBoost)

-- Arrastar sem teleportar: so altera a posicao se realmente mover.
local dragging=nil
local opened=false
local placed=false
local seq=0
local tweens={}
local function cancelTweens()
    for _,tw in ipairs(tweens) do tw:Cancel() end
    table.clear(tweens)
end
local function placeOnce()
    if placed then return end
    placed=true
    if uiPrefs.PanelX and uiPrefs.PanelY then return end
    local p=icon.AbsolutePosition
    local x=p.X>width+24 and p.X-width-12 or p.X+iconSize+12
    local safe=bound(Vector2.new(x,p.Y),Vector2.new(width,height))
    panel.Position=UDim2.fromOffset(safe.X,safe.Y)
end
local function openMenu(value)
    if stopped or value==opened then return end
    placeOnce()
    opened=value
    seq=seq+1
    local generation=seq
    cancelTweens()
    if value then panel.Visible=true end
    local info=TweenInfo.new(value and 0.2 or 0.16,Enum.EasingStyle.Quad,
        value and Enum.EasingDirection.Out or Enum.EasingDirection.In)
    local a=T:Create(panel,info,{GroupTransparency=value and 0 or 1})
    local b=T:Create(scale,info,{Scale=value and 1 or 0.91})
    tweens={a,b}
    a:Play()
    b:Play()
    a.Completed:Connect(function()
        if not stopped and generation==seq and not opened then panel.Visible=false end
    end)
end
local function beginDrag(input,kind,object,update)
    if dragging then return end
    local t=input.UserInputType
    if t~=Enum.UserInputType.MouseButton1 and t~=Enum.UserInputType.Touch then return end
    dragging={Input=input,Kind=kind,Object=object,
        Start=input.Position,Origin=object and object.AbsolutePosition or Vector2.zero,
        Moved=false,Update=update}
end
links[#links+1]=icon.InputBegan:Connect(function(input)
    beginDrag(input,'icon',icon)
end)
links[#links+1]=header.InputBegan:Connect(function(input)
    if input.Position.X>panel.AbsolutePosition.X+panel.AbsoluteSize.X-72 then return end
    beginDrag(input,'panel',panel)
end)
links[#links+1]=U.InputChanged:Connect(function(input)
    local d=dragging
    if not d then return end
    if d.Input.UserInputType==Enum.UserInputType.Touch then
        if input~=d.Input then return end
    elseif input.UserInputType~=Enum.UserInputType.MouseMovement then
        return
    end
    local delta=input.Position-d.Start
    if delta.Magnitude>7 then d.Moved=true end
    if not d.Moved then return end
    local size=d.Kind=='icon' and Vector2.new(iconSize,iconSize)
        or Vector2.new(width,height)
    local safe=bound(d.Origin+Vector2.new(delta.X,delta.Y),size)
    d.Object.Position=UDim2.fromOffset(safe.X,safe.Y)
end)
links[#links+1]=U.InputEnded:Connect(function(input)
    local d=dragging
    if not d then return end
    local released=(input==d.Input) or
        (d.Input.UserInputType==Enum.UserInputType.MouseButton1
            and input.UserInputType==Enum.UserInputType.MouseButton1)
    if not released then return end
    dragging=nil
    if d.Moved and (d.Kind=='icon' or d.Kind=='panel') then
        local px=d.Object.Position.X.Offset
        local py=d.Object.Position.Y.Offset
        if d.Kind=='icon' then
            uiPrefs.IconX,uiPrefs.IconY=px,py
        else
            uiPrefs.PanelX,uiPrefs.PanelY=px,py
        end
        saveSettings()
        refreshSaveStatus()
    end
    if d.Kind=='icon' and not d.Moved then openMenu(not opened) end
end)
links[#links+1]=collapse.MouseButton1Click:Connect(function()
    openMenu(false)
end)

local function stop(reason)
    if stopped then return end
    -- O X encerra o script *e* cancela a fila de teleportes. Ao substituir a
    -- versao, o encerramento interno NAO deve cancelar o novo auto-inicio.
    if reason~='replace' then
        local active=env.VolleyBombLanding
        if type(active)=='table' and active.Stop==stop
            and type(active.CancelTeleport)=='function' then
            pcall(active.CancelTeleport)
        end
    end
    -- Salvar ANTES de desativar as funcionalidades no encerramento.
    saveSettings()
    stopped=true
    pending,aimTarget=nil,nil
    spikeCaptureKey=false
    spikeHeld=false
    spikeJumped=false
    clearSpikeLock()
    if spikeStateLink then spikeStateLink:Disconnect() end
    if spikeBindOK then CAS:UnbindAction(spikeActionKey) end
    stopSteering()
    FPS.Generation=FPS.Generation+1
    FPS.Enabled=false
    fpsRestore()
    cancelTweens()
    restoreCamera()
    Run:UnbindFromRenderStep(renderKey)
    if animationLink then animationLink:Disconnect() end
    if inputBound then CAS:UnbindAction(actionKey) end
    for _,link in ipairs(links) do link:Disconnect() end
    gui:Destroy()
    folder:Destroy()
    if type(env.VolleyBombLanding)=='table'
        and env.VolleyBombLanding.Stop==stop then
        env.VolleyBombLanding=nil
    end
end
links[#links+1]=close.MouseButton1Click:Connect(stop)
env.VolleyBombLanding={Stop=stop,Config=C,UI=uiPrefs,Version='9.8'}
print('[VolleyBomb v9.8] Rebote 0.60 e normal do BallState; Dive v8.0 preservado. Corte: '..C.SpikeKey..'. FPS: '..(C.FPSBoost and 'TURBO' or 'OFF')..'. Config: '..saveLocation)
]=]

local RUNNER = [==[-- Executado no servidor atual e nos seguintes, sempre dentro do VolleyBomb.
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

    -- Primeiro inicia o script atual. Se a versao anterior estiver aberta,
    -- ela sai com motivo 'replace' e nao cancela esta proxima fila.
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
    if type(current)~='table' or current.Version~='9.7' then return end

    -- Funcao usada ao clicar X. O Solara remove TODA a fila de teleportes,
    -- inclusive scripts antigos. Nao existe cancelamento por item individual.
    current.CancelTeleport=function()
        local success,message=clearQueuedTeleports()
        if success then
            print('[VolleyBomb v9.8] X: Auto-inicio desligado e fila de teleportes limpa.')
        else
            warn('[VolleyBomb v9.8] Nao foi possivel cancelar o auto-inicio: '..tostring(message))
        end
        return success
    end

    -- Antes de registrar o unico carregamento atualizado, apaga as copias de
    -- versoes antigas que possam ter ficado pendentes no executor.
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
]==]

local compiled,err=loadstring(RUNNER)
if not compiled then error('[VolleyBomb v9.8] Erro de inicializacao: '..tostring(err)) end
local start=compiled()
start(nil,CORE,RUNNER)
