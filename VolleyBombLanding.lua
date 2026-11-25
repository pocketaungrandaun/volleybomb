




local CORE = [=[




local P=game:GetService('Players')
local R=game:GetService('ReplicatedStorage')
local Run=game:GetService('RunService')
local U=game:GetService('UserInputService')
local CAS=game:GetService('ContextActionService')
local T=game:GetService('TweenService')
local W=game:GetService('Workspace')
local Http=game:GetService('HttpService')
local me=P.LocalPlayer
local C={Main=true,Practice=true,SmartDive=false,
    Radius=3.1,MainColor=Color3.fromRGB(75,255,150),
    PracticeColor=Color3.fromRGB(85,200,255),
    DiveLead=0.55,MinLead=0.15,MaxLead=1.5,
    MinSpeed=52,MinFall=5,MaxError=1.2,
    DiveReach=24,DiveSpeed=100,DiveCooldown=1.2,
    ChaseRange=85,ChaseWindow=3.5,StopDistance=11,
    AimDelay=0.06,InputDelay=0.065,LockSpeed=9,
    SafetyLead=0.08, MinNativeLead=0.24,
    
    
    MaxEarlyWait=5.2, EmergencyWindow=0.020,
    SteerDive=true, 
    SpikeDirection=false,SpikeKey='X',
    FPSBoost=true,CameraServe=false,Indicator=true}
local env=_G
if type(getgenv)=='function' then
    local ok,e=pcall(getgenv)
    if ok and type(e)=='table' then env=e end
end

local saveFile='VolleyBombLanding_settings.json'
local savedKeys={'SmartDive',
    'DiveLead','SpikeDirection','SpikeKey','FPSBoost','CameraServe','Indicator'}
local uiPrefs={}
local saveLocation='sessao'
local hasV65Preferences=false

local function loadSettings(data)
    if type(data)~='table' then return end
    if data.Version=='6.5' or data.Version=='6.6' or data.Version=='6.7' or data.Version=='6.8' or data.Version=='6.9' or data.Version=='7.0' or data.Version=='7.1' or data.Version=='7.2' or data.Version=='7.3' or data.Version=='7.4' or data.Version=='7.5' or data.Version=='7.6' or data.Version=='7.7' or data.Version=='7.8' or data.Version=='7.9' or data.Version=='8.0' or data.Version=='8.1' or data.Version=='8.2' or data.Version=='8.3' or data.Version=='8.4' or data.Version=='8.5' or data.Version=='8.6' or data.Version=='8.8' or data.Version=='8.9' or data.Version=='9.0' or data.Version=='9.1' or data.Version=='9.2' or data.Version=='9.3' or data.Version=='9.4' or data.Version=='9.5' or data.Version=='9.6' or data.Version=='9.7' or data.Version=='9.8' or data.Version=='9.9' or data.Version=='9.10' or data.Version=='9.11' or data.Version=='9.12' or data.Version=='9.13' or data.Version=='9.14' or data.Version=='9.15' or data.Version=='9.16' or data.Version=='9.17' or data.Version=='9.18' or data.Version=='9.19' or data.Version=='9.20' or data.Version=='9.21' or data.Version=='9.22' or data.Version=='9.23' or data.Version=='9.24' or data.Version=='9.25' or data.Version=='9.26' or data.Version=='9.27' or data.Version=='9.28' or data.Version=='9.29' then hasV65Preferences=true end
    for _,key in ipairs(savedKeys) do
        local value=data[key]
        if key=='DiveLead' then
            if type(value)=='number' and value==value then
                C[key]=math.clamp(value,C.MinLead,C.MaxLead)
            end
        elseif key=='SpikeKey' then
            
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
    
    loadSettings(old.Config)
    if type(old.UI)=='table' then loadSettings({UI=old.UI}) end
    if type(old.Stop)=='function' then pcall(old.Stop,'replace') end
end

-- O AutoPlayer experimental usa Humanoid:Move num RenderStep mais tardio,
-- sobrescrevendo as direcoes do Smart Dive. Nao deixar os dois ativos.
do
    local auto=env.VolleyBombAutoPlayer
    if type(auto)=='table' and type(auto.Stop)=='function' then
        pcall(auto.Stop)
        warn('[VolleyBomb] AutoPlayer anterior encerrado para nao disputar WASD com Smart Dive.')
    end
end

C.Main=true
C.Practice=true

C.SteerDive=true

local function saveSettings()
    local data={Version='9.29',UI={}}
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
-- Usa os mesmos modulos que o proprio cliente do jogo utiliza.
-- O modulo Ball tem At, VelocityAt, Bounce, Launch e Ground.
local nativeBall=nil
local ballController=nil
do
    local ok,mod=pcall(function()
        return require(R:WaitForChild('Shared',8):WaitForChild('Modules',8):WaitForChild('Ball',8))
    end)
    if ok and type(mod)=='table' and type(mod.At)=='function'
        and type(mod.Bounce)=='function' and type(mod.Ground)=='function'
        and type(mod.VelocityAt)=='function' then
        nativeBall=mod
    else
        warn('[VolleyBomb] Fisica nativa indisponivel; previsoes com rebote serao ocultadas.')
    end
    local ok2,controller=pcall(function()
        return require(R:WaitForChild('Shared',8):WaitForChild('Controllers',8):WaitForChild('BallController',8))
    end)
    if ok2 and type(controller)=='table' then ballController=controller end
end
local function getTrackedBallPart(arena)
    local entry=ballController and ballController._balls
        and ballController._balls[arena]
    local part=entry and entry.Part
    if part and part:IsA('BasePart') and part.Parent then
        return part
    end
    local backup=W:FindFirstChild(arena=='Main' and 'Bowling Ball' or 'Default')
    if backup and backup:IsA('BasePart') then return backup end
    return nil
end
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
local lastDecision='Aguardando E'
local aimUntil=0
local lastDive=-math.huge
local ping=0.08
local lastPing=0
local renderKey='VolleyLanding85_Render'
local spikeActionKey='VolleyLanding85_Spike'
local actionKey='VolleyLanding85_E'
local inputBound=false
local refreshSmart
local steerTarget=nil
local steerDirection=nil 
local steerUntil=0
local steerActive=false
local steerArmedAt=0
local steerStarted=false
local steerDetectedAt=0
local steerStartPosition=nil
local liveTracks={Main={Samples={},Next=0},Practice={Samples={},Next=0}}

local function make(class,properties,parent)
    local o=Instance.new(class)
    for k,v in pairs(properties) do o[k]=v end
    o.Parent=parent
    return o
end






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




local fallbackArenas={
    
    {x=0,z=12,dx=38,dz=55},   
    {x=222,z=-6,dx=40,dz=55} 
}
local function fpsArenaContainer(inst)
    
    
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
    
    if FPS.IsArenaPoint and FPS.IsArenaPoint(p) then return true end
    
    
    if fpsExplicitLobby(part) then return false end
    
    if p.Y>=8 and p.Y<=145 then
        for _,area in ipairs(fallbackArenas) do
            if math.abs(p.X-area.x)<=area.dx
                and math.abs(p.Z-area.z)<=area.dz then return true end
        end
    end
    return false
end



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
    
    if arena then return false end
    local nearby=fpsInsideLobby(inst)
    if named and (lobby or nearby or (strong and not FPS.LobbyBounds)) then
        return true
    end
    
    
    if lobby or nearby then
        local part=fpsWorldPart(inst)
        if not part or fpsFloorPart(part) then return false end
        if part.Anchored then return true end
        
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
    
    if fpsProtectedArena(part) then return false end
    if fpsInsideLobby(part) then return true end
    local b=FPS.LobbyBounds
    if not b or not FPS.LobbyFloorY or not part.Anchored then return false end
    local p=part.Position
    local s=part.Size
    
    
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
    
    
    local hostPart=fpsWorldPart(inst)
    if hostPart and fpsProtectedArena(hostPart) then return end
    local inLobby=isPart and fpsInsideLobby(inst)
    local cullWorld=isPart and fpsCullWorldPart(inst)
    local essential=fpsEssential(inst)
    if essential then
        
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
            fpsHide(inst) 
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
end 


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
    
    model.WorldPivot=CFrame.new()
    return {Model=model,Parts=parts,Visible=false}
end
markers.Main=marker('Main',C.MainColor)
markers.Practice=marker('Practice',C.PracticeColor)




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
    -- O proprio jogo atribui InRound ao jogador nas partidas oficiais.
    -- Em Main, as zonas podem mudar entre rounds e a posicao sozinha
    -- pode ser classificada incorretamente como Lobby.
    local assigned=me:GetAttribute('InRound')
    if assigned=='Main' or assigned=='Practice' then
        currentMode=assigned
        modeLastConfirmed=now
        return currentMode
    end
    local chosen='Lobby'
    local bestDist=math.huge
    local pos=root.Position

    
    
    for _,arena in ipairs({'Main','Practice'}) do
        for _,zone in ipairs(zones[arena]) do
            if typeof(zone)=='Instance' and zone:IsA('BasePart') and zone.Parent then
                local localPos=zone.CFrame:PointToObjectSpace(pos)
                if math.abs(localPos.Y)<=math.max(60,zone.Size.Y/2+15) then
                    local dx=math.max(0,math.abs(localPos.X)-zone.Size.X/2)
                    local dz=math.max(0,math.abs(localPos.Z)-zone.Size.Z/2)
                    local distance=math.sqrt(dx*dx+dz*dz)
                    
                    if distance<bestDist and distance<=12 then
                        chosen=arena
                        bestDist=distance
                    end
                end
            end
        end
    end

    
    
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

    
    if chosen~='Lobby' then
        modeLastConfirmed=now
    elseif currentMode~='Lobby' and now-modeLastConfirmed<0.35 then
        chosen=currentMode
    end
    currentMode=chosen
    return currentMode
end

FPS.GetMode=detectMode

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

-- Mantem a previsao disponivel para Smart Dive mesmo com Indicator desligado.
local function updateIndicatorVisibility(m)
    local alpha=m.LastAlpha or 0
    for _,item in ipairs(m.Parts) do
        item[1].Transparency=(C.Indicator and m.Visible)
            and math.max(item[2],alpha) or 1
    end
end
local function show(m,visible)
    if m.Visible==visible then return end
    m.Visible=visible
    updateIndicatorVisibility(m)
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
        
        
        if s and s.Point and s.Normal and s.Surface=='floor'
            and s.Normal.Y>=0.88 then
            m.Model:PivotTo(frame(s.Point,s.Normal))
            
            m.LastPoint=s.Point
            m.LastNormal=s.Normal
            m.LastVisibleAt=os.clock()
            show(m,true)
            
            local alpha=s.Live and 0.5 or (s.BounceEstimated and not s.NativePrediction and 0.36 or 0)
            if m.LastAlpha~=alpha then
                m.LastAlpha=alpha
                for _,item in ipairs(m.Parts) do
                    item[1].Transparency=C.Indicator and math.max(item[2],alpha) or 1
                end
            end
        else
            -- Nao pisca por um unico frame sem estimativa.
            local grace=m.Visible and m.LastVisibleAt
                and os.clock()-m.LastVisibleAt<0.10 and arena==mode
            if not grace then
                show(m,false)
                m.LastAlpha=nil
            end
            
            
            if arena==mode and liveState(arena) then
                m.LastPoint=nil
                m.LastNormal=nil
                m.LastVisibleAt=nil
            end
        end
    end
end
-- Previsao a partir da fisica ORIGINAL (Ball.At + Ball.Bounce).
-- Nao reproduz rebotes com coeficientes estimados nem usa velocidade de Assembly.
local function nativeFloorForecast(raw)
    if not nativeBall or type(raw)~='table' or raw.Dead
        or raw.Tornado or raw.Magnet then return nil end
    if typeof(raw.Origin)~='Vector3' or typeof(raw.Velocity)~='Vector3'
        or typeof(raw.Gravity)~='Vector3'
        or type(raw.Time)~='number' or type(raw.EndTime)~='number'
        or raw.EndTime<=raw.Time+0.015
        or raw.EndTime==math.huge then return nil end
    local state=raw
    local now=W:GetServerTimeNow()
    local rebotes=0
    for _=1,7 do
        if type(state.EndTime)~='number' or type(state.Time)~='number'
            or state.EndTime~=state.EndTime or state.EndTime==math.huge
            or state.EndTime<=state.Time+0.001
            or state.EndTime>now+8 then return nil end
        local success,point=pcall(nativeBall.At,state,state.EndTime)
        if not success or typeof(point)~='Vector3' then return nil end
        if state.Reflect==true then
            if typeof(state.Normal)~='Vector3' or not state.Multipliers then
                return nil
            end
            local good,nextState=pcall(nativeBall.Bounce,state)
            if not good or type(nextState)~='table'
                or type(nextState.EndTime)~='number'
                or nextState.EndTime<=state.EndTime+0.01 then return nil end
            rebotes=rebotes+1
            state=nextState
        else
            if typeof(state.Normal)~='Vector3'
                or state.Normal.Y<0.88 then return nil end
            local groundOk,ground=pcall(nativeBall.Ground,point)
            if not groundOk or typeof(ground)~='Vector3'
                or math.abs(point.Y-ground.Y)>7 then return nil end
            local velocityOk,impactVelocity=pcall(nativeBall.VelocityAt,state,state.EndTime)
            if not velocityOk or typeof(impactVelocity)~='Vector3' then
                return nil
            end
            return ground,state.Normal,0.02,impactVelocity,
                state.EndTime,true,'floor',rebotes
        end
    end
    return nil
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
                
                
            end
        end
    end

    
    
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
        
        
        if kind=='wall' and (err>0.25 or s.IgnoreWalls) then return nil end
        return best.Position,best.Normal,err,endVelocity,
            s.EndTime,true,kind
    end
    return nil
end






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
                
                if n.Y>=0.88 and incident.Y< -1.2 then
                    return hit.Position,n,startTime+total+elapsed,bounceCount
                end
                local reflected=bounceVelocity(incident,n,model)
                if not reflected then
                    
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

    -- Em Main as zonas sao atualizadas entre rounds. A antiga tabela
    -- 'owned' pode apontar para Parts que ja nao pertencem a rodada.
    -- A referencia atual de s.Zones deve ter prioridade.
    if impact and mine then return impact==mine end
    if not impact then return false end
    if next(owned[s.Arena])~=nil then
        for zone in pairs(owned[s.Arena]) do
            if zone==impact and zone.Parent then return true end
        end
    end
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


-- Quick Look: usa o sacador fornecido diretamente pelo servidor em BallState.
-- Zero heuristica de proximidade, zero lock-on ou acompanhamento de bola.
local cameraServeBind='VolleyBombServeCamera_'..tostring(me.UserId)
local cameraSnapPlayer=nil
local cameraSnapUntil=0
local lastServeStateTime=-math.huge
local announcedServerName=nil
local announcedServerAt=-math.huge

local function cancelServeCamera()
    cameraSnapPlayer=nil
    cameraSnapUntil=0
end

local function mainMatchActive()
    -- InRound e usado pelo BallController original para definir a arena ativa.
    local assigned=me:GetAttribute('InRound')
    if assigned~=nil then return assigned=='Main' end
    return detectMode(true)=='Main'
end

local function announcedServer()
    if not announcedServerName or os.clock()-announcedServerAt>1.5 then
        return nil
    end
    local found=nil
    for _,player in ipairs(P:GetPlayers()) do
        if player.Name==announcedServerName
            or player.DisplayName==announcedServerName then
            if found then return nil end
            found=player
        end
    end
    return found
end

-- O jogo anuncia o nome de exibicao do sacador instantes antes do BallState.
-- Serve apenas de fallback quando BallState.Server nao e um Player.
local serveAnnouncement=R:WaitForChild('Packages'):WaitForChild('Net')
    :FindFirstChild('RE/RoundNotification')
if serveAnnouncement and serveAnnouncement:IsA('RemoteEvent') then
    links[#links+1]=serveAnnouncement.OnClientEvent:Connect(function(_,message)
        if stopped or not C.CameraServe or type(message)~='string' then return end
        local name=message:match('^(.+) is serving$')
        if name then
            announcedServerName=name
            announcedServerAt=os.clock()
        end
    end)
end

local function watchPublicServe(raw)
    if stopped or not C.CameraServe or raw.Arena~='Main'
        or raw.Dead or raw.Hits~=0
        or type(raw.Time)~='number'
        or type(raw.EndTime)~='number'
        or math.abs(raw.EndTime-raw.Time)>0.02
        or typeof(raw.Velocity)~='Vector3'
        or raw.Velocity.Magnitude>0.2 then
        -- Quando o saque comecou, nao vira a camera atrasado.
        -- O primeiro arremesso pode ainda ter Hits=0; Velocity/Hitter
        -- indicam que ja saiu da fase de preparo do sacador.
        if type(raw)=='table' and raw.Arena=='Main' and
            ((type(raw.Hits)=='number' and raw.Hits>0)
            or raw.Hitter~=nil
            or (raw.Server==nil and typeof(raw.Velocity)=='Vector3'
                and raw.Velocity.Magnitude>1)) then
            cancelServeCamera()
        end
        return
    end
    if raw.Time<=lastServeStateTime then return end
    lastServeStateTime=raw.Time
    local player=raw.Server
    if typeof(player)~='Instance' or not player:IsA('Player') then
        player=announcedServer()
    end
    if not player or player==me then return end
    -- Mantem pendente ate o cliente entrar em Main e a camera ficar livre.
    -- Nao espera um tempo fixo antes de virar a camera.
    cameraSnapPlayer=player
    cameraSnapUntil=os.clock()+3
end

-- Aplica um unico giro apos o controlador de camera nativo.
-- Nunca altera CameraType, CameraSubject nem segue o sacador.
Run:BindToRenderStep(cameraServeBind,Enum.RenderPriority.Camera.Value+15,function()
    local target=cameraSnapPlayer
    if stopped or not C.CameraServe or not target then return end
    if os.clock()>cameraSnapUntil then
        cancelServeCamera()
        return
    end
    if not mainMatchActive() then return end
    local cam=W.CurrentCamera
    if not cam or cam.CameraType~=Enum.CameraType.Custom then return end
    local char=target.Character
    local root=char and char:FindFirstChild('HumanoidRootPart')
    local hum=char and char:FindFirstChildOfClass('Humanoid')
    if not root or not hum or hum.Health<=0 then return end
    local eye=cam.CFrame.Position
    local aim=root.Position+Vector3.new(0,1.8,0)
    if (aim-eye).Magnitude>0.5 then
        cam.CFrame=CFrame.lookAt(eye,aim)
    end
    cancelServeCamera()
end)

links[#links+1]=event.OnClientEvent:Connect(function(raw)
    if stopped or type(raw)~='table' then return end
    local arena=raw.Arena
    if not markers[arena] then return end
    if type(raw.Time)~='number' or type(raw.EndTime)~='number' then return end
    local oldState=states[arena]
    if oldState and raw.Time<oldState.Time then return end
    watchPublicServe(raw)
    local point,normal,error,velocity,collisionTime,reliable,surface,bounces=
        nativeFloorForecast(raw)
    local nativePrediction=point~=nil
    bounces=bounces or 0
    if not nativePrediction then
        -- O fallback antigo so pode mostrar impacto DIRETO no piso.
        -- Nunca tenta imaginar a trajetoria apos bater na parede.
        if raw.Reflect~=true and raw.Tornado==nil and raw.Magnet==nil then
            point,normal,error,velocity,collisionTime,reliable,surface=forecast(raw,arena)
        end
        if surface~='floor' then
            point,normal,collisionTime,reliable,surface=nil,nil,nil,false,nil
        end
    end
    local firstPoint,firstNormal,firstVelocity,firstSurface=
        point,normal,velocity,surface
    local estimated=bounces>0
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
    
    if C.SmartDive and #zoneList>0
        and (changedZones or not areaAttempt[arena]) then
        -- Reaprende a zona da rodada, sem acumular Parts obsoletas.
        if lockZone(arena,false) then areaAttempt[arena]=true end
    end
    
    
    if surface=='floor' and point and not estimated and normal and normal.Y>=0.88 then
        liveTracks[arena].FloorY=point.Y
    end
    states[arena]={Arena=arena,Raw=raw,Time=raw.Time,
        EndTime=collisionTime or raw.EndTime,
        RawEndTime=raw.EndTime,
        Point=point,Normal=normal,Error=error or math.huge,
        Reliable=reliable==true,Surface=surface,
        BounceEstimated=estimated,NativePrediction=nativePrediction,BounceCount=bounces,
        FirstImpactPoint=firstPoint,FirstImpactNormal=firstNormal,
        FirstIncoming=firstVelocity,FirstSurface=firstSurface,
        MotionUncertain=abilityTagged(raw),Live=false,
        ImpactSpeed=velocity and velocity.Magnitude or 0,
        FallSpeed=velocity and -velocity.Y or 0,Zones=zoneList}
    updateMarkers()
end)





local function updateBallMotion()
    local now=os.clock()
    for arena,track in pairs(liveTracks) do
        if now>=track.Next then
            track.Next=now+0.035
            local part=getTrackedBallPart(arena)
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
                    
                    
                    
                    local pastKnownBounce=s.BounceEstimated and
                        W:GetServerTimeNow()>=s.RawEndTime-0.03
                    if dt>=0.095 and not pastKnownBounce then
                        local raw=s.Raw
                        local t0=math.clamp(W:GetServerTimeNow()-raw.Time-dt,0,12)
                        local t1=math.clamp(W:GetServerTimeNow()-raw.Time,0,12)
                        local expected=position(raw,t1)-position(raw,t0)
                        local observed=last.P-first.P
                        
                        
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





local function liveFloor(arena)
    local track=liveTracks[arena]
    local s=liveState(arena)
    if not track or not s or not s.Raw then return nil end
    local now=os.clock()
    
    
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
    if not last or now-last.T>0.14 then return nil end
    local ballPos=last.P
    local p=params()
    local floorY=track.FloorY
    local groundHit=nil
    local function validGround(hit)
        return hit and hit.Normal.Y>=0.86
            and not (hit.Instance and FPS.HiddenOriginals[hit.Instance]~=nil)
    end
    
    
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
        
        
        if root and detectMode() == arena then
            floorY=root.Position.Y-3
        end
    end
    if floorY then track.FloorY=floorY end

    
    
    
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
            
            
            v=Vector3.zero
        end
    end

    
    
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
        
        
        finalPos=Vector3.new(guessed.X,floorY,guessed.Z)
        finalNormal=Vector3.yAxis
    else
        
        
        return nil
    end
    
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
        
        if track.LastGroundPoint and track.LastGroundRawTime==s.Raw.Time
            and now-(track.LastGroundAt or -math.huge)<0.16 then
            return {Arena=arena,Time=s.Time,EndTime=W:GetServerTimeNow()+0.08,
                Point=track.LastGroundPoint,Normal=track.LastGroundNormal,
                Surface='floor',Zones=s.Zones,Error=3,
                ImpactSpeed=s.ImpactSpeed,FallSpeed=1,Reliable=false,Live=true}
        end
        return nil
    end
    
    
    if s.MotionUncertain or (track.UncertainUntil and
        now<track.UncertainUntil and track.UncertainRawTime==s.Raw.Time) then
        return nil
    end
    
    
    if s.BounceEstimated and not s.NativePrediction and type(s.RawEndTime)=='number'
        and W:GetServerTimeNow()>s.RawEndTime+0.07 then
        return nil
    end
    return s
end




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
    
    
    if spikeHeld and spikeAvailable() then
        return orientSpike(root,hum,directionFromCamera())
    end
    return false
end


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
        
        onSpikeClick()
    end
end)
links[#links+1]=U.InputEnded:Connect(function(input)
    if input.UserInputType==Enum.UserInputType.Keyboard
        and input.KeyCode.Name==C.SpikeKey then
        spikeHeld=false
    end
end)


local spikeBindOK=pcall(function()
    CAS:BindActionAtPriority(spikeActionKey,function(_,state)
        if state==Enum.UserInputState.Begin then onSpikeClick() end
        return Enum.ContextActionResult.Pass
    end,false,9000,Enum.UserInputType.MouseButton1)
end)
if not spikeBindOK then
    warn('[VolleyBomb] Captura do corte por CAS indisponivel; usando InputBegan')
end





-- Smart Dive v2: correcao REATIVA do dive nativo, sem auto mergulho.
-- E continua indo ao jogo; nenhuma tecla ou RemoteEvent faz o dive pela pessoa.
-- Ao detectar o impulso real, ajusta a direcao para o destino confiavel da bola.
local function samplePing()
    if os.clock()-lastPing<1 then return end
    lastPing=os.clock()
    local ok,p=pcall(function() return me:GetNetworkPing() end)
    if ok and type(p)=='number' and p>=0 and p<2 then ping=p end
end

local smartTriggerAt=-math.huge
local smartConfirmed=false
local smartAnimationSeen=false
local smartArena=nil
local smartLastTarget=nil
local smartLastFrame=0
local smartTimeout=0
local smartInputDebounce=-math.huge
local smartBurstSpeed=0
local smartLastPosition=nil
local smartCorrectionSteps=0
local smartMovementDir=nil
local smartMovementKeys=nil
local smartFacingForward=nil
local smartFacingRight=nil
local smartBodyRotation=nil
local smartBodyLook=nil
local smartDirectionalRender='VolleyLanding85_DiveDirectional'

local function stopSteering()
    steerActive=false
    steerStarted=false
    steerTarget=nil
    steerDirection=nil
    smartConfirmed=false
    smartAnimationSeen=false
    smartArena=nil
    smartLastTarget=nil
    smartLastFrame=0
    smartLastPosition=nil
    smartCorrectionSteps=0
    smartMovementDir=nil
    smartMovementKeys=nil
    smartFacingForward=nil
    smartFacingRight=nil
    smartBodyRotation=nil
    smartBodyLook=nil
    smartBurstSpeed=0
    restoreRotation()
end

local function safeDiveTarget(root)
    local arena=detectMode(true)
    if arena~='Main' and arena~='Practice' then
        return nil,'arena nao reconhecida'
    end
    local s=correctedState and correctedState(arena)
    if not s then return nil,'BallState sem alvo valido em '..arena end
    if s.Surface~='floor' or not s.Reliable
        or s.MotionUncertain or s.Live
        or typeof(s.Point)~='Vector3'
        or typeof(s.Normal)~='Vector3' or s.Normal.Y<0.88
        or type(s.EndTime)~='number' then
        return nil,'impacto nao confirmado no chao'
    end

    local timeLeft=s.EndTime-W:GetServerTimeNow()
    -- Os saques publicos podem ter trajetorias mais longas que Practice.
    if timeLeft < -0.045 or timeLeft>1.65 then
        return nil,string.format('tempo de impacto %.2fs',timeLeft)
    end
    local direction,dist=horizontal(root.Position,s.Point)
    if not direction or dist>43 then
        return nil,string.format('distancia %.1f studs',dist or 0)
    end

    -- So segue ponto validado do proprio lado. Se a zona anterior mudou,
    -- usa primeiramente a Part atual onde o personagem esta.
    if type(s.Zones)=='table' and #s.Zones>0 then
        if not ownSide(s,root) then
            return nil,'queda fora da zona atual'
        end
    elseif dist>25 then
        return nil,'sem zona e alvo distante'
    end
    return s,arena,direction,dist,timeLeft
end

-- Escolhe W, A, S, D ou diagonais a partir da direcao da camera.
-- Nunca gira o avatar na direcao da bola: o dive pode ser lateral ou para tras.
local function smartCameraAxes(root)
    local camera=W.CurrentCamera
    local look=camera and camera.CFrame.LookVector or root.CFrame.LookVector
    local forward=Vector3.new(look.X,0,look.Z)
    if forward.Magnitude<0.04 then
        local body=root.CFrame.LookVector
        forward=Vector3.new(body.X,0,body.Z)
    end
    if forward.Magnitude<0.04 then forward=Vector3.new(0,0,-1) end
    forward=forward.Unit
    local right=forward:Cross(Vector3.yAxis).Unit
    return forward,right
end
local function smartSelectWASD(direction)
    local forward,right=smartFacingForward,smartFacingRight
    if not forward or not right then return direction,'W' end

    -- Projeta o alvo nos eixos horizontais da camera.
    -- Nao usa mais setores de 22.5 graus, que classificavam
    -- uma bola na diagonal esquerda como somente W ou A.
    local front=direction:Dot(forward)
    local side=direction:Dot(right)
    local tiny=0.025 -- ignora apenas ruido quase em cima de um eixo
    local keys=''
    if front>tiny then
        keys='W'
    elseif front < -tiny then
        keys='S'
    end
    if side>tiny then
        keys=keys..'D'
    elseif side < -tiny then
        keys=keys..'A'
    end

    if keys=='' then
        keys=math.abs(front)>=math.abs(side)
            and (front>=0 and 'W' or 'S')
            or (side>=0 and 'D' or 'A')
    end

    -- O Humanoid aceita uma direcao analogica em coordenadas do mundo:
    -- utiliza a direcao EXATA do indicador e nao o vetor discretizado
    -- de 45 graus. Assim WA/WD/SA/SD sao escolhidos sem desviar do alvo.
    return direction,keys
end

-- A direcao de deslocamento NAO determina a direcao para onde o avatar olha.
-- Conserva a orientacao original durante o E, mesmo que o jogo reoriente
-- o HumanoidRootPart para a trajetoria do mergulho.
local function holdSmartFacing(root,hum)
    if not steerActive or not smartBodyRotation or not smartBodyLook
        or not root or not hum or hum.Health<=0 then return end
    keepRotation(hum)
    -- Evita reescrever CFrame quando a rotacao ja esta correta.
    if root.CFrame.LookVector:Dot(smartBodyLook)<0.9995 then
        root.CFrame=CFrame.new(root.Position)*smartBodyRotation
    end
end

local function beginSmartDive(origin)
    -- Somente E pode criar uma janela de correcao. Animacoes e WASD nao iniciam.
    if origin~='E' then return end
    if stopped or not C.SmartDive or spikeCaptureKey
        or U:GetFocusedTextBox() then return end
    local now=os.clock()
    lastPhysicalPress=now
    if now-smartInputDebounce<0.12 then return end
    smartInputDebounce=now
    if steerActive then stopSteering() end

    local root,hum=character()
    if not root or not hum or hum.Health<=0 or root.Anchored then return end
    local target,arena=safeDiveTarget(root)
    if not target then
        lastDecision='E sem assistencia: '..tostring(arena)
        warn('[VolleyBomb Smart Dive] '..lastDecision)
        return
    end

    -- Antes de E, fornece ao Humanoid uma direcao equivalente a WASD,
    -- relativa a camera. Mantem a orientacao do corpo, sem mirar a bola.
    smartFacingForward,smartFacingRight=smartCameraAxes(root)
    smartBodyRotation=root.CFrame.Rotation
    smartBodyLook=root.CFrame.LookVector
    local toBall=horizontal(root.Position,target.Point)
    smartMovementDir,smartMovementKeys=smartSelectWASD(toBall)
    keepRotation(hum)
    hum:Move(smartMovementDir,false)
    steerActive=true
    steerStarted=false
    steerTarget=target.Point
    steerStartPosition=root.Position
    steerArmedAt=now
    steerUntil=now+0.69
    smartTimeout=now+0.36
    smartTriggerAt=now
    smartAnimationSeen=false
    smartConfirmed=false
    smartArena=arena
    smartLastTarget=target.Point
    smartLastFrame=now
    smartLastPosition=root.Position
    smartCorrectionSteps=0
    smartBurstSpeed=0
    lastDecision='E -> dive direcional '..(smartMovementKeys or 'W')..' ('..arena..')'
    clearSpikeLock()
end

local function obstacleAhead(root,dir)
    local filters=params()
    local ok,hit=pcall(function()
        return W:Raycast(
            root.Position+Vector3.new(0,0.8,0),
            dir*3.1,filters)
    end)
    return ok and hit
        and math.abs(hit.Normal.Y)<0.6 and hit.Distance<=2.8
end

-- Um motor de mergulho pode usar Tween/CFrame, BodyVelocity ou LinearVelocity.
-- Alterar somente AssemblyLinearVelocity nao altera um Tween que escreve CFrame.
local function redirectNativeMover(root,desired)
    for _,mover in ipairs(root:GetChildren()) do
        if mover:IsA('BodyVelocity') and mover.MaxForce.Magnitude>0 then
            local vel=mover.Velocity
            mover.Velocity=Vector3.new(desired.X,vel.Y,desired.Z)
        elseif mover:IsA('LinearVelocity') and mover.Enabled
            and mover.VelocityConstraintMode==Enum.VelocityConstraintMode.Vector then
            local localVelocity=desired
            if mover.RelativeTo~=Enum.ActuatorRelativeTo.World then
                local att=mover.Attachment0
                if att then
                    localVelocity=att.WorldCFrame:VectorToObjectSpace(desired)
                end
            end
            mover.VectorVelocity=localVelocity
        end
    end
end

local function steerPhysics()
    if stopped or not C.SmartDive or not steerActive then return end
    local root,hum=character()
    if not root or not hum or hum.Health<=0 or root.Anchored then
        stopSteering()
        return
    end
    local now=os.clock()
    if now>steerUntil then
        stopSteering()
        return
    end

    local dt=math.clamp(now-smartLastFrame,1/120,1/25)
    smartLastFrame=now
    -- PostSimulation: desfaz o giro que a logica nativa do jogo pode
    -- ter aplicado ao corpo, sem mudar a trajetoria horizontal do dive.
    holdSmartFacing(root,hum)
    local position=root.Position
    local movement=smartLastPosition and (position-smartLastPosition)
        or Vector3.zero
    smartLastPosition=position
    local planarMovement=Vector3.new(movement.X,0,movement.Z)
    local measuredSpeed=planarMovement.Magnitude/dt
    local v=root.AssemblyLinearVelocity
    local planar=Vector3.new(v.X,0,v.Z)
    local speed=planar.Magnitude

    if not smartConfirmed then
        if now>smartTimeout then
            -- Cooldown / E nao aceito: nunca forcar um dive que nao aconteceu.
            stopSteering()
            return
        end
        local launched=(speed>=52 and speed<=180)
            or (measuredSpeed>=36 and measuredSpeed<=190)
        if launched or (smartAnimationSeen and now-smartTriggerAt>=0.045) then
            smartConfirmed=true
            steerStarted=true
            steerDetectedAt=now
            smartBurstSpeed=math.clamp(
                math.max(speed,measuredSpeed,62),55,112)
            steerUntil=math.min(now+0.56,steerArmedAt+0.80)
        else
            return
        end
    end

    -- Nunca perseguir uma bola apos terminar a janela do dive.
    if now>steerUntil or
        (hum.FloorMaterial~=Enum.Material.Air
            and now-steerDetectedAt>0.22
            and speed<20 and measuredSpeed<20) then
        stopSteering()
        return
    end

    local s,arena,direction,dist,remaining=safeDiveTarget(root)
    if not s or arena~=smartArena or dist<=2.5
        or remaining<0.01 then
        stopSteering()
        return
    end
    if smartLastTarget and
        (s.Point-smartLastTarget).Magnitude>16 then
        stopSteering()
        return
    end
    smartLastTarget=s.Point
    steerTarget=s.Point
    -- Reavalia WASD se a trajetoria mudar durante o mergulho.
    smartMovementDir,smartMovementKeys=smartSelectWASD(direction)
    if obstacleAhead(root,direction) then
        stopSteering()
        return
    end

    -- Usar o deslocamento observado tambem, pois a bola e o dive podem
    -- ser animados por CFrame enquanto AssemblyLinearVelocity fica em zero.
    local observed=measuredSpeed>=8 and planarMovement.Unit
        or (speed>=8 and planar.Unit or nil)
    local alignment=observed and observed:Dot(direction) or -1
    local projectedMiss=observed and
        (dist*math.sqrt(math.max(0,1-alignment*alignment))) or dist
    local needsCorrection=alignment<0.94 or projectedMiss>3.2
    if not needsCorrection then
        -- O dive original ja segue na direcao boa.
        return
    end

    local travelSpeed=math.clamp(
        math.max(speed,measuredSpeed,smartBurstSpeed,58),55,112)
    local desired=direction*travelSpeed

    -- Primeiro corrigimos motores fisicos que possam controlar o dash.
    redirectNativeMover(root,desired)
    root.AssemblyLinearVelocity=Vector3.new(desired.X,v.Y,desired.Z)

    -- Se o jogo move o personagem por Tween/CFrame, velocidade nao basta.
    -- Compensamos SOMENTE o deslocamento errado deste frame, limitado
    -- a poucos studs e apenas enquanto o dive original esta em andamento.
    local forwardStep=math.min(math.max(dist-2.5,0),travelSpeed*dt)
    local wantedDelta=direction*forwardStep
    local adjustment=wantedDelta-planarMovement
    if adjustment.Magnitude>0.08 then
        local maxAdjustment=math.min(3.0,dt*185)
        if adjustment.Magnitude>maxAdjustment then
            adjustment=adjustment.Unit*maxAdjustment
        end
        -- Evitar atravessar paredes ao corrigir a posicao.
        local hit=W:Raycast(position+Vector3.new(0,0.7,0),
            adjustment,params())
        if hit and math.abs(hit.Normal.Y)<0.65 then
            stopSteering()
            return
        end
        local correctedPosition=position+adjustment
        -- Translada ate a bola, mas conserva a rotacao guardada ANTES do E,
        -- nao a rotacao que o jogo possa ter imposto apos o dive.
        root.CFrame=CFrame.new(correctedPosition)*
            (smartBodyRotation or root.CFrame.Rotation)
        smartLastPosition=correctedPosition
        smartCorrectionSteps=smartCorrectionSteps+1
    end
end

local physicsOK,physicsConn=pcall(function()
    return Run.PostSimulation:Connect(steerPhysics)
end)
if physicsOK and physicsConn then
    links[#links+1]=physicsConn
else
    links[#links+1]=Run.Heartbeat:Connect(steerPhysics)
end

-- O PlayerModule pode sobrescrever Humanoid:Move no proximo frame.
-- Depois dos controles padrao, reaplica WASD apenas enquanto E esta ativo.
Run:BindToRenderStep(smartDirectionalRender,
    Enum.RenderPriority.Input.Value+2,function()
        if stopped or not C.SmartDive or not steerActive
            or not smartMovementDir then return end
        local now=os.clock()
        if now>smartTimeout and not smartConfirmed then return end
        if now-smartTriggerAt>0.10 and not smartConfirmed
            and not smartAnimationSeen then return end
        local root,hum=character()
        if not root or not hum or hum.Health<=0 or root.Anchored then return end
        hum:Move(smartMovementDir,false)
    end)

-- O dive continua 100% nativo. Capturar E nao bloqueia o jogo.
local function onSmartDive(_,inputState)
    if stopped or not C.SmartDive then return Enum.ContextActionResult.Pass end
    if inputState==Enum.UserInputState.Begin then
        beginSmartDive('E')
    end
    return Enum.ContextActionResult.Pass
end

local function updateEIntercept()
    local bind=not stopped and C.SmartDive
    if bind and not inputBound then
        local ok,err=pcall(function()
            CAS:BindActionAtPriority(actionKey,onSmartDive,false,
                10000,Enum.KeyCode.E)
        end)
        inputBound=ok
        if not ok then
            warn('[VolleyBomb] Nao foi possivel monitorar E: '..tostring(err))
        end
    elseif not bind and inputBound then
        CAS:UnbindAction(actionKey)
        inputBound=false
        stopSteering()
    end
end
links[#links+1]=U.InputBegan:Connect(function(input)
    if stopped or not C.SmartDive or inputBound
        or input.KeyCode~=Enum.KeyCode.E then return end
    beginSmartDive('E')
end)

-- A animacao do jogo confirma o dive mesmo quando o impulso muda com ping.
-- Nao inicia uma jogada automaticamente.
local animationLink
local function attachAnimator()
    if animationLink then animationLink:Disconnect() animationLink=nil end
    local ch=me.Character
    if not ch then return end
    task.spawn(function()
        local hum=ch:WaitForChild('Humanoid',5)
        if stopped or not hum then return end
        local animator=hum:WaitForChild('Animator',5)
        if stopped or not animator then return end
        animationLink=animator.AnimationPlayed:Connect(function(track)
            local anim=track.Animation
            local id=anim and anim.AnimationId or ''
            if not id:find('125582828675515',1,true) then return end
            lastNativeStart=os.clock()
            lastDive=lastNativeStart
            -- AnimationPlayed serve SOMENTE para confirmar o E ja pressionado.
            -- Nunca cria uma nova assistencia ao caminhar, pular ou clicar.
            if not C.SmartDive or not steerActive
                or os.clock()-smartTriggerAt>0.36 then return end
            smartAnimationSeen=true
            smartTimeout=math.min(os.clock()+0.16,steerArmedAt+0.42)
        end)
    end)
end
attachAnimator()
links[#links+1]=me.CharacterAdded:Connect(function()
    stopSteering()
    attachAnimator()
end)

local function cancelSmart()
    stopSteering()
    pending=nil
    aimTarget=nil
    aimUntil=0
end

links[#links+1]=Run.Heartbeat:Connect(function()
    if stopped then return end
    samplePing()
    updateBallMotion()
    updateMarkers()
    updateEIntercept()
end)

Run:BindToRenderStep(renderKey,Enum.RenderPriority.Camera.Value+10,function()
    if stopped then return end
    local root,hum=character()
    if not root then restoreCamera() return end

    
    if steerActive then
        -- Ultima etapa de renderizacao: alguns controladores giram o
        -- avatar DEPOIS da simulacao fisica; garante o dive lateral.
        holdSmartFacing(root,hum)
        return
    end
    
    if updateSpikeFacing(root,hum) then return end

    
    -- Lock-on removido: nao gira personagem/camera em direcao a bola.
    if os.clock()>aimUntil then
        restoreRotation()
    end
end)









local holder=me:WaitForChild('PlayerGui')
if type(gethui)=='function' then
    local ok,p=pcall(gethui)
    if ok and typeof(p)=='Instance' then holder=p end
end
local gui=make('ScreenGui',{
    Name='VolleyBombLandingUI',IgnoreGuiInset=true,
    ResetOnSpawn=false,DisplayOrder=150,
    ZIndexBehavior=Enum.ZIndexBehavior.Sibling
},holder)

-- Painel unico, sem escurecer o jogo. F8 mostra/oculta.
local theme={
    panel=Color3.fromRGB(77,75,74),
    card=Color3.fromRGB(108,105,103),
    text=Color3.fromRGB(250,249,247),
    secondary=Color3.fromRGB(226,221,216),
    muted=Color3.fromRGB(192,190,190),
    border=Color3.fromRGB(212,205,200),
    blue=Color3.fromRGB(43,184,246),
    inactive=Color3.fromRGB(123,119,117)
}
local width,height=600,255
local panel=make('CanvasGroup',{
    Name='GlassMenu',Size=UDim2.fromOffset(width,height),
    AnchorPoint=Vector2.new(0.5,0.5),
    Position=UDim2.fromScale(0.5,0.5),
    BackgroundColor3=theme.panel,BackgroundTransparency=0.61,
    BorderSizePixel=0,GroupTransparency=0,
    Visible=false,Active=true,ClipsDescendants=true
},gui)
make('UICorner',{CornerRadius=UDim.new(0,17)},panel)
make('UIStroke',{
    Color=theme.border,Transparency=0.56,Thickness=1
},panel)
local scale=make('UIScale',{Scale=1},panel)
local baseScale=1
local function updateScale()
    local camera=W.CurrentCamera
    if not camera then return end
    local vp=camera.ViewportSize
    baseScale=math.clamp(
        math.min((vp.X-24)/width,(vp.Y-24)/height),0.45,1)
    scale.Scale=baseScale
end
updateScale()

-- Faixa invisivel de arrastar; sem titulo, abas ou icones.
local dragHeader=make('Frame',{
    Name='DragArea',BackgroundTransparency=1,Active=true,
    Position=UDim2.fromOffset(14,1),
    Size=UDim2.fromOffset(width-28,22)
},panel)
-- Pequeno X para encerrar o script por completo.
local exitButton=make('TextButton',{
    Name='CloseScript',
    Text='×',Font=Enum.Font.GothamMedium,TextSize=17,
    TextColor3=Color3.fromRGB(235,229,226),
    BackgroundTransparency=1,AutoButtonColor=true,
    BorderSizePixel=0,
    Position=UDim2.fromOffset(width-27,3),
    Size=UDim2.fromOffset(22,21),
    ZIndex=20
},panel)
local function label(parent,title,x,y,w,h,fontSize,muted)
    return make('TextLabel',{
        Text=title,Font=Enum.Font.GothamMedium,
        TextSize=fontSize or 13,
        TextColor3=muted and theme.secondary or theme.text,
        TextStrokeColor3=Color3.fromRGB(23,23,25),
        TextStrokeTransparency=0.86,
        BackgroundTransparency=1,TextXAlignment=Enum.TextXAlignment.Left,
        TextYAlignment=Enum.TextYAlignment.Center,
        Position=UDim2.fromOffset(x,y),Size=UDim2.fromOffset(w,h)
    },parent)
end
local function card(x,y,w,h)
    local button=make('TextButton',{
        Text='',AutoButtonColor=false,
        BackgroundColor3=theme.card,BackgroundTransparency=0.63,
        BorderSizePixel=0,Position=UDim2.fromOffset(x,y),
        Size=UDim2.fromOffset(w,h)
    },panel)
    make('UICorner',{CornerRadius=UDim.new(0,12)},button)
    make('UIStroke',{
        Color=theme.border,Thickness=1,Transparency=0.79
    },button)
    return button
end
local function switch(parent,x,y,key)
    local button=make('TextButton',{
        Name='Switch_'..key,Text='',AutoButtonColor=false,
        Position=UDim2.fromOffset(x,y),
        Size=UDim2.fromOffset(46,25),
        BackgroundColor3=theme.inactive,BorderSizePixel=0,ZIndex=5
    },parent)
    make('UICorner',{CornerRadius=UDim.new(1,0)},button)
    local knob=make('Frame',{
        Size=UDim2.fromOffset(19,19),Position=UDim2.fromOffset(3,3),
        BackgroundColor3=Color3.fromRGB(253,253,252),
        BorderSizePixel=0,ZIndex=6
    },button)
    make('UICorner',{CornerRadius=UDim.new(1,0)},knob)
    local function refresh(animated)
        local active=C[key]==true
        local color=active and theme.blue or theme.inactive
        local pos=UDim2.fromOffset(active and 24 or 3,3)
        if animated then
            T:Create(button,TweenInfo.new(0.18,Enum.EasingStyle.Quad),
                {BackgroundColor3=color}):Play()
            T:Create(knob,TweenInfo.new(0.18,Enum.EasingStyle.Quad),
                {Position=pos}):Play()
        else
            button.BackgroundColor3=color
            knob.Position=pos
        end
    end
    refresh(false)
    return button,refresh
end

local function applyToggle(key)
    C[key]=not C[key]
    if key=='FPSBoost' then fpsSetEnabled(C.FPSBoost) end
    if key=='Indicator' then
        for _,indicator in pairs(markers) do
            updateIndicatorVisibility(indicator)
        end
    end
    if key=='CameraServe' and not C.CameraServe then
        cancelServeCamera()
    end
    if key=='SpikeDirection' and not C[key] then
        spikeHeld=false
        clearSpikeLock()
        if not C.SmartDive then restoreRotation() end
    end
    if key=='SmartDive' then
        if not C.SmartDive then cancelSmart(false) end
        if C.SmartDive then
            stopSteering()
        else
            aimTarget=nil
            aimUntil=0
            restoreRotation()
        end
    end
    saveSettings()
    updateMarkers()
    if key=='SmartDive' then updateEIntercept() end
end

local function feature(title,key,x,y,w,h)
    local tile=card(x,y,w,h)
    label(tile,title,16,math.floor((h-29)/2),w-90,29,15,false)
    local toggleButton,refresh=switch(tile,w-62,14,key)
    links[#links+1]=toggleButton.MouseButton1Click:Connect(function()
        applyToggle(key)
        refresh(true)
    end)
    links[#links+1]=tile.MouseButton1Click:Connect(function()
        applyToggle(key)
        refresh(true)
    end)
    return refresh
end


-- Menu apenas com nomes, sem descricoes.
refreshSmart=feature('Smart Dive','SmartDive',18,18,276,66)
feature('Optimizer','FPSBoost',306,18,276,66)
feature('Quick Look','CameraServe',18,94,276,66)
feature('Indicator','Indicator',306,94,276,66)

-- Fake Shift: clique no cartao e depois pressione uma tecla.
-- O interruptor a direita continua habilitando/desabilitando.
local fake=card(18,170,564,66)
label(fake,'Fake Shift',16,18,405,29,15,false)
local fakeKeyLetter=make('TextLabel',{
    Name='FakeShiftKey',Text=C.SpikeKey,
    Font=Enum.Font.GothamBold,TextSize=15,
    TextColor3=theme.text,BackgroundColor3=theme.card,
    BackgroundTransparency=0.38,BorderSizePixel=0,
    Position=UDim2.fromOffset(449,17),
    Size=UDim2.fromOffset(35,32)
},fake)
make('UICorner',{CornerRadius=UDim.new(0,8)},fakeKeyLetter)
local fakeSwitch,refreshFakeSwitch=switch(fake,502,20,'SpikeDirection')
links[#links+1]=fakeSwitch.MouseButton1Click:Connect(function()
    applyToggle('SpikeDirection')
    refreshFakeSwitch(true)
end)
spikeKeyRefresh=function()
    fakeKeyLetter.Text=C.SpikeKey
end
links[#links+1]=fake.MouseButton1Click:Connect(function()
    spikeCaptureKey=true
    spikeHeld=false
    clearSpikeLock()
end)

saveSettings()
fpsSetEnabled(C.FPSBoost)

local opened=false
local seq=0
local tweens={}
local function cancelTweens()
    for _,tw in ipairs(tweens) do pcall(function() tw:Cancel() end) end
    table.clear(tweens)
end
local function openMenu(value)
    if stopped or value==opened then return end
    opened=value
    seq=seq+1
    local generation=seq
    cancelTweens()
    if value then
        panel.Visible=true
        updateScale()
    else
        spikeCaptureKey=false
    end
    local transition=TweenInfo.new(value and 0.2 or 0.14,
        Enum.EasingStyle.Quad,
        value and Enum.EasingDirection.Out or Enum.EasingDirection.In)
    local fade=T:Create(panel,transition,
        {GroupTransparency=value and 0 or 1})
    tweens={fade}
    fade:Play()
    fade.Completed:Once(function()
        if not stopped and generation==seq and not opened then
            panel.Visible=false
        end
    end)
end

-- F8 substitui F9, sem avatar, titulo ou barra lateral.
local menuAction='VolleyBombLanding_MenuF8'
local lastMenuInput=-math.huge
local function toggleMenuFromKey()
    if stopped or U:GetFocusedTextBox() then return end
    local now=os.clock()
    if now-lastMenuInput<0.15 then return end
    lastMenuInput=now
    openMenu(not opened)
end
local menuBindOK=pcall(function()
    CAS:BindActionAtPriority(menuAction,function(_,state)
        if state==Enum.UserInputState.Begin then toggleMenuFromKey() end
        return Enum.ContextActionResult.Sink
    end,false,10000,Enum.KeyCode.F8)
end)
links[#links+1]=U.InputBegan:Connect(function(input)
    if input.KeyCode==Enum.KeyCode.F8 then toggleMenuFromKey() end
end)

-- Arrastar pela pequena faixa vazia no topo.
local dragging=nil
links[#links+1]=dragHeader.InputBegan:Connect(function(input)
    if input.UserInputType~=Enum.UserInputType.MouseButton1
        and input.UserInputType~=Enum.UserInputType.Touch then return end
    dragging={Input=input,Origin=input.Position,Position=panel.Position}
end)
links[#links+1]=U.InputChanged:Connect(function(input)
    if not dragging or not opened then return end
    if dragging.Input.UserInputType==Enum.UserInputType.Touch then
        if input~=dragging.Input then return end
    elseif input.UserInputType~=Enum.UserInputType.MouseMovement then
        return
    end
    local delta=input.Position-dragging.Origin
    local camera=W.CurrentCamera
    local vp=camera and camera.ViewportSize or Vector2.new(1280,720)
    local xLimit=math.max(0,vp.X*0.5-width*baseScale*0.5-9)
    local yLimit=math.max(0,vp.Y*0.5-height*baseScale*0.5-9)
    panel.Position=UDim2.new(0.5,
        math.clamp(dragging.Position.X.Offset+delta.X,-xLimit,xLimit),
        0.5,math.clamp(dragging.Position.Y.Offset+delta.Y,-yLimit,yLimit))
end)
links[#links+1]=U.InputEnded:Connect(function(input)
    if dragging and (input==dragging.Input or
        (dragging.Input.UserInputType==Enum.UserInputType.MouseButton1 and
        input.UserInputType==Enum.UserInputType.MouseButton1)) then
        dragging=nil
    end
end)

local function stop(reason)
    if stopped then return end
    
    
    if reason~='replace' then
        local active=env.VolleyBombLanding
        if type(active)=='table' and active.Stop==stop
            and type(active.CancelTeleport)=='function' then
            pcall(active.CancelTeleport)
        end
    end
    
    saveSettings()
    stopped=true
    cancelServeCamera()
    Run:UnbindFromRenderStep(cameraServeBind)
    Run:UnbindFromRenderStep(smartDirectionalRender)
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
    if menuBindOK then CAS:UnbindAction(menuAction) end
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
links[#links+1]=exitButton.MouseButton1Click:Connect(function()
    stop('close')
end)
env.VolleyBombLanding={Stop=stop,Config=C,UI=uiPrefs,Version='9.29'}
print('[VolleyBomb v9.29] Smart Dive v2.5: Main detectado pelo jogo, zonas renovadas e AutoPlayer desligado. Corte: '..C.SpikeKey..'. FPS: '..(C.FPSBoost and 'TURBO' or 'OFF')..'. Config: '..saveLocation)
]=]

local RUNNER = [==[
return function(expectedUniverse, core, runner)
    if not game:IsLoaded() then game.Loaded:Wait() end
    local universe = game.GameId
    if type(universe) ~= 'number' or universe == 0 then
        warn('[VolleyBomb v9.29] Nao foi possivel reconhecer o universo do jogo.')
        return
    end
    if expectedUniverse and expectedUniverse ~= universe then
        warn('[VolleyBomb v9.29] Outro jogo detectado. Autoexecucao ignorada.')
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
        warn('[VolleyBomb v9.29] Estrutura do VolleyBomb nao encontrada; nada sera carregado.')
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
        warn('[VolleyBomb v9.29] Erro ao ler codigo principal: '..tostring(err))
        return
    end
    local ok,runtimeErr=pcall(compiled)
    if not ok then
        warn('[VolleyBomb v9.29] Erro na execucao: '..tostring(runtimeErr))
        return
    end

    local current=environ.VolleyBombLanding
    if type(current)~='table' or current.Version~='9.29' then return end

    
    
    current.CancelTeleport=function()
        local success,message=clearQueuedTeleports()
        if success then
            print('[VolleyBomb v9.29] X: Auto-inicio desligado e fila de teleportes limpa.')
        else
            warn('[VolleyBomb v9.29] Nao foi possivel cancelar o auto-inicio: '..tostring(message))
        end
        return success
    end

    
    
    local cleared,why=clearQueuedTeleports()
    if not cleared then
        warn('[VolleyBomb v9.29] Nao deu para limpar copias antigas: '..tostring(why))
    end

    local queue=getTeleportQueue()
    if not queue then
        warn('[VolleyBomb v9.29] Executor nao tem queue_on_teleport. Auto-inicio indisponivel.')
        return
    end

    local queuedCode=string.format([=[
local expectedUniverse = %d
local core = %q
local runner = %q
local compiler, errorMessage = loadstring(runner)
if not compiler then
    warn('[VolleyBomb v9.29] Erro no auto-inicio: '..tostring(errorMessage))
else
    local success, launch = pcall(compiler)
    if success and type(launch)=='function' then
        launch(expectedUniverse, core, runner)
    else
        warn('[VolleyBomb v9.29] Auto-inicio indisponivel: '..tostring(launch))
    end
end
]=], universe, core, runner)
    local registered,queueErr=pcall(queue,queuedCode)
    if registered then
        environ.VolleyBombLandingTeleportQueued=
            tostring(universe)..'/'..tostring(game.JobId)..'/v9.29'
        print('[VolleyBomb v9.29] Auto-inicio preparado. X cancela o proximo servidor.')
    else
        warn('[VolleyBomb v9.29] Falha ao preparar proximo servidor: '..tostring(queueErr))
    end
end
]==]

local compiled,err=loadstring(RUNNER)
if not compiled then error('[VolleyBomb v9.29] Erro de inicializacao: '..tostring(err)) end
local start=compiled()
start(nil,CORE,RUNNER)