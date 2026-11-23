local FPS={Enabled=false,Generation=0,Revision=0,
    Originals={},
    Detached={},HiddenOriginals={},
    Seen={},
    LobbyBounds=nil,LobbyFloorY=nil,LobbyOrigin=nil,
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
    if fpsExplicitLobby(part) then return false end
    if fpsArenaContainer(part) then return true end
    local p=part.Position
    if FPS.IsArenaPoint and FPS.IsArenaPoint(p) then return true end
    
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
    if root and atLobby and not fpsProtectedArena(root) then
        FPS.LobbyOrigin=root.Position
    end
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

    local pos=part.Position
    local b=FPS.LobbyBounds
    local origin=FPS.LobbyOrigin
    local floorY=FPS.LobbyFloorY
    if not floorY and origin then floorY=origin.Y-4 end
    if not floorY then return false end
    if pos.Y<floorY-65 or pos.Y>floorY+95 then return false end

    local near=false
    if b then
        near=pos.X>=b.minX-215 and pos.X<=b.maxX+215
            and pos.Z>=b.minZ-215 and pos.Z<=b.maxZ+215
    elseif origin then
        local dx,dz=pos.X-origin.X,pos.Z-origin.Z
        near=dx*dx+dz*dz<=235*235
    end
    if not near then return false end

    local name=fpsName(part.Name)
    local seaName=name:find('rock',1,true)
        or name:find('stone',1,true)
        or name:find('island',1,true)
        or name:find('debris',1,true)
        or name:find('chunk',1,true)
        or name:find('floating',1,true)
        or name:find('tree',1,true)
        or name:find('grass',1,true)
        or name:find('dirt',1,true)
    local node=part.Parent
    local depth=0
    while not seaName and node and node~=W and depth<5 do
        local n=fpsName(node.Name)
        seaName=n:find('rock',1,true) or n:find('stone',1,true)
            or n:find('island',1,true) or n:find('floating',1,true)
            or n:find('decor',1,true) or n:find('tree',1,true)
        node=node.Parent
        depth=depth+1
    end

    local size=part.Size
    local biggest=math.max(size.X,size.Y,size.Z)
    if biggest>80 then return false end
    local belowSea=pos.Y+size.Y*0.5<floorY-3
    local color=part.Color
    local gray=math.abs(color.R-color.G)<0.09
        and math.abs(color.G-color.B)<0.09
        and color.R>0.30 and color.R<0.91
    local grass=color.G>0.38 and color.G>color.R*1.35
        and color.G>color.B*1.35
    local brown=color.R>0.22 and color.R>color.B*1.45
        and color.G>color.B*1.25 and color.R>=color.G*0.75
    local sphere=(part:IsA('Part') and part.Shape==Enum.PartType.Ball)
        or name=='ball' or name=='orb' or name=='sphere'
    if not part.Anchored then
        return sphere and biggest<=18
    end
    return (seaName~=nil) or belowSea
        or (biggest<=65 and (gray or grass or brown))
        or biggest<=12
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
            or n=='volleyball' or n=='balls' or n=='projectiles' then
            if node==W:FindFirstChild('Bowling Ball')
                or node==W:FindFirstChild('Default') then
                return true
            end
            local world=fpsWorldPart(node)
            if world and fpsProtectedArena(world) then return true end
        elseif n=='indicators' or n=='ballshadow'
            or n=='ballindicator' or n=='hitmarker' then
            return true
        elseif fpsCriticalName(n) then
            return true
        end
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
local function fpsHideSpinText(inst)
    if not inst or not inst:IsA('TextLabel') then return false end
    local ok,content=pcall(function() return inst.Text end)
    if not ok or type(content)~='string' then return false end
    local normalized=fpsName(content):gsub('%s+',' ')
    if not (normalized:find('free spin',1,true)
        or normalized:find('freespin',1,true)
        or normalized:find('free spin in',1,true)) then return false end
    local node=inst.Parent
    while node and node~=W and not node:IsA('ScreenGui') do
        if node:IsA('BillboardGui') or node:IsA('SurfaceGui') then
            fpsChange(node,'Enabled',false)
            return true
        end
        node=node.Parent
    end
    local parent=inst.Parent
    if parent and (parent:IsA('Frame') or parent:IsA('CanvasGroup')) then
        fpsChange(parent,'Visible',false)
    else
        fpsChange(inst,'Visible',false)
    end
    return true
end

local function fpsProcess(inst)
    if not FPS.Enabled or not inst or not inst.Parent then return end
    if FPS.Seen[inst] then return end
    if inst:IsA('TextLabel') and fpsHideSpinText(inst) then
        FPS.Seen[inst]=true
        return
    end
    if not inst:IsDescendantOf(W) then return end
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

local function fpsLoadingHide()
    local loading=FPS.Loading
    FPS.Loading=nil
    if loading and loading.Gui then
        pcall(function() loading.Gui:Destroy() end)
    end
end

local function fpsLoadingShow()
    fpsLoadingHide()
    local holder=me:FindFirstChildOfClass('PlayerGui')
    if type(gethui)=='function' then
        local ok,ui=pcall(gethui)
        if ok and typeof(ui)=='Instance' then holder=ui end
    end
    if not holder then return end
    local gui=make('ScreenGui',{
        Name='VolleyBombFPSTurboLoading',ResetOnSpawn=false,
        IgnoreGuiInset=true,DisplayOrder=250,
        ZIndexBehavior=Enum.ZIndexBehavior.Sibling},holder)
    local overlay=make('Frame',{
        Size=UDim2.fromScale(1,1),BackgroundColor3=Color3.fromRGB(7,10,15),
        BackgroundTransparency=0.48,BorderSizePixel=0,Active=false,ZIndex=1},gui)
    local panel=make('Frame',{
        AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.fromScale(0.5,0.5),
        Size=UDim2.fromOffset(330,146),BackgroundColor3=Color3.fromRGB(18,21,28),
        BorderSizePixel=0,Active=false,ZIndex=2},overlay)
    make('UICorner',{CornerRadius=UDim.new(0,14)},panel)
    make('UIStroke',{Color=Color3.fromRGB(48,56,65),Thickness=1},panel)
    make('TextLabel',{
        Text='FPS TURBO',Font=Enum.Font.GothamBold,TextSize=15,
        TextColor3=Color3.fromRGB(104,234,181),TextXAlignment=Enum.TextXAlignment.Left,
        BackgroundTransparency=1,Position=UDim2.fromOffset(20,17),
        Size=UDim2.fromOffset(290,24),ZIndex=3},panel)
    local detail=make('TextLabel',{
        Text='Preparando otimização...',Font=Enum.Font.Gotham,
        TextColor3=Color3.fromRGB(204,210,219),TextSize=14,
        TextXAlignment=Enum.TextXAlignment.Left,BackgroundTransparency=1,
        Position=UDim2.fromOffset(20,54),Size=UDim2.fromOffset(290,23),
        ZIndex=3},panel)
    local track=make('Frame',{
        BackgroundColor3=Color3.fromRGB(49,54,63),
        BorderSizePixel=0,Position=UDim2.fromOffset(20,96),
        Size=UDim2.fromOffset(290,8),ZIndex=3},panel)
    make('UICorner',{CornerRadius=UDim.new(1,0)},track)
    local bar=make('Frame',{
        BackgroundColor3=Color3.fromRGB(104,234,181),
        BorderSizePixel=0,Size=UDim2.fromScale(0,1),ZIndex=4},track)
    make('UICorner',{CornerRadius=UDim.new(1,0)},bar)
    local percent=make('TextLabel',{
        Text='0%',Font=Enum.Font.Gotham,TextSize=12,
        TextColor3=Color3.fromRGB(142,153,168),
        TextXAlignment=Enum.TextXAlignment.Right,BackgroundTransparency=1,
        Position=UDim2.fromOffset(246,114),
        Size=UDim2.fromOffset(64,20),ZIndex=3},panel)
    FPS.Loading={Gui=gui,Bar=bar,Detail=detail,Percent=percent}
end

local function fpsLoadingProgress(generation,fraction,message)
    if not FPS.Enabled or FPS.Generation~=generation then return end
    local loading=FPS.Loading
    if not loading or not loading.Gui or not loading.Gui.Parent then return end
    local value=math.clamp(fraction,0,1)
    loading.Bar.Size=UDim2.fromScale(value,1)
    loading.Percent.Text=string.format('%d%%',math.floor(value*100+0.5))
    if message then loading.Detail.Text=message end
end

local function fpsScan(generation)
    fpsLoadingProgress(generation,0.03,'Analisando cenário...')
    local all=W:GetDescendants()
    fpsFindLobbyBounds(all)
    fpsLoadingProgress(generation,0.05,'Ocultando objetos do lobby...')
    local began=os.clock()
    local total=math.max(1,#all)

    for i,inst in ipairs(all) do
        if stopped or not FPS.Enabled or generation~=FPS.Generation then return end
        if inst:IsA('BasePart') and fpsInsideLobby(inst) then fpsProcess(inst) end
        if i%350==0 or i==#all then
            fpsLoadingProgress(generation,0.05+0.33*(i/total))
        end
        if i%550==0 and os.clock()-began>0.018 then
            task.wait()
            began=os.clock()
        end
    end
    fpsLoadingProgress(generation,0.38,'Removendo texturas e decorações...')
    for i,inst in ipairs(all) do
        if stopped or not FPS.Enabled or generation~=FPS.Generation then return end
        fpsProcess(inst)
        if i%300==0 or i==#all then
            fpsLoadingProgress(generation,0.38+0.56*(i/total))
        end
        if i%360==0 and os.clock()-began>0.014 then
            task.wait()
            began=os.clock()
        end
    end
    fpsLoadingProgress(generation,0.94,'Finalizando otimização...')
    local playerGui=me:FindFirstChildOfClass('PlayerGui')
    if playerGui and FPS.Enabled and generation==FPS.Generation then
        local uiObjects=playerGui:GetDescendants()
        local uiTotal=math.max(1,#uiObjects)
        for i,inst in ipairs(uiObjects) do
            if stopped or not FPS.Enabled or generation~=FPS.Generation then return end
            if inst:IsA('TextLabel') then fpsProcess(inst) end
            if i%100==0 or i==#uiObjects then
                fpsLoadingProgress(generation,0.94+0.06*(i/uiTotal))
            end
        end
    end
    table.clear(all)
    fpsLoadingProgress(generation,1,'Otimização concluída')
end
fpsRestore=function()
    fpsLoadingHide()
    
    
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
        fpsLoadingShow()
        task.spawn(function()
            local ok,err=pcall(fpsScan,generation)
            if not ok then warn('[VolleyBomb FPS Turbo] '..tostring(err)) end
            if FPS.Generation==generation then fpsLoadingHide() end
        end)
    else
        fpsRestore()
    end
end
links[#links+1]=W.DescendantAdded:Connect(function(inst)
    if FPS.Enabled then fpsProcess(inst) end
end)
local playerGui=me:FindFirstChildOfClass('PlayerGui')
if playerGui then
    links[#links+1]=playerGui.DescendantAdded:Connect(function(inst)
        if FPS.Enabled and inst:IsA('TextLabel') then fpsProcess(inst) end
    end)
end
end 


