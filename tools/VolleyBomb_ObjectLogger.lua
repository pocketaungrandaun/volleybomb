local Players=game:GetService('Players')
local Workspace=game:GetService('Workspace')
local Input=game:GetService('UserInputService')
local Run=game:GetService('RunService')
local Http=game:GetService('HttpService')
local player=Players.LocalPlayer
if not player then return end
local env=_G
if type(getgenv)=='function' then
    local ok,res=pcall(getgenv)
    if ok and type(res)=='table' then env=res end
end
if type(env.VBObjectLogger)=='table' and type(env.VBObjectLogger.Close)=='function' then
    pcall(env.VBObjectLogger.Close)
end
local savedFile='VolleyBomb_FPS_Objetos.json'
local log={}
local history={}
local links={}
local enabled=true
local asModel=true
local stopped=false
local hover=nil
local hoverTime=0
local function make(class,props,parent)
    local o=Instance.new(class)
    for k,v in pairs(props) do o[k]=v end
    o.Parent=parent
    return o
end
local function rnd(n) return math.floor(n*1000+0.5)/1000 end
local function coords(v) return {x=rnd(v.X),y=rnd(v.Y),z=rnd(v.Z)} end
local function payload()
    return {schema=1,game='VolleyBomb',universe=game.GameId,placeId=game.PlaceId,
        count=#log,objects=log}
end
local function save()
    if type(writefile)~='function' then return false end
    return pcall(function() writefile(savedFile,Http:JSONEncode(payload())) end)
end
if type(readfile)=='function' then
    pcall(function()
        if type(isfile)~='function' or isfile(savedFile) then
            local data=Http:JSONDecode(readfile(savedFile))
            if type(data)=='table' and data.universe==game.GameId
                and type(data.objects)=='table' then
                for _,item in ipairs(data.objects) do
                    if type(item)=='table' then log[#log+1]=item end
                end
            end
        end
    end)
end
local function pathOf(obj)
    local names,trail={},{}
    local node=obj
    while node and node~=game and #trail<32 do
        local ordinal=0
        local parent=node.Parent
        if parent then
            for _,sibling in ipairs(parent:GetChildren()) do
                if sibling.Name==node.Name and sibling.ClassName==node.ClassName then
                    ordinal=ordinal+1
                end
                if sibling==node then break end
            end
        end
        ordinal=math.max(1,ordinal)
        table.insert(trail,1,{name=node.Name,class=node.ClassName,index=ordinal})
        table.insert(names,1,node.Name:gsub('/','%%2F')..'['..ordinal..']')
        if node==Workspace then break end
        node=parent
    end
    return table.concat(names,'/'),trail
end
local function isPlayerPart(obj)
    for _,p in ipairs(Players:GetPlayers()) do
        local ch=p.Character
        if ch and (obj==ch or obj:IsDescendantOf(ch)) then return true end
    end
    return false
end
local function candidate(part)
    if not part or not part:IsA('BasePart') or isPlayerPart(part) then return nil end
    if not asModel then return part end
    local parent=part.Parent
    while parent and parent~=Workspace do
        if parent:IsA('Model') and not isPlayerPart(parent) then
            local name=string.lower(parent.Name)
            if name~='map' and name~='lobby' and name~='main'
                and name~='practice' and name~='arena' and name~='court' then
                if #parent:GetDescendants()<=320 then
                    local ok,box,size=pcall(function() return parent:GetBoundingBox() end)
                    if ok and box and size and math.max(size.X,size.Y,size.Z)<=125 then
                        return parent
                    end
                end
            end
        end
        parent=parent.Parent
    end
    return part
end
local holder=player:WaitForChild('PlayerGui')
if type(gethui)=='function' then
    local ok,h=pcall(gethui)
    if ok and typeof(h)=='Instance' then holder=h end
end
local gui=make('ScreenGui',{Name='VB_ObjectLogger_UI',IgnoreGuiInset=true,
    ResetOnSpawn=false,DisplayOrder=600,ZIndexBehavior=Enum.ZIndexBehavior.Sibling},holder)
local panel=make('Frame',{Size=UDim2.fromOffset(360,248),
    Position=UDim2.new(1,-375,0,78),BackgroundColor3=Color3.fromRGB(21,24,32),
    BorderSizePixel=0,Active=true},gui)
make('UICorner',{CornerRadius=UDim.new(0,12)},panel)
make('UIStroke',{Color=Color3.fromRGB(65,72,85),Thickness=1},panel)
local title=make('TextLabel',{Text='FPS OBJECT LOGGER',
    Position=UDim2.fromOffset(14,12),Size=UDim2.fromOffset(290,23),
    BackgroundTransparency=1,TextXAlignment=Enum.TextXAlignment.Left,
    TextColor3=Color3.fromRGB(240,244,250),Font=Enum.Font.GothamBold,
    TextSize=15},panel)
make('TextLabel',{Text='Selecione e oculte objetos; colisão preservada',
    Position=UDim2.fromOffset(14,36),Size=UDim2.fromOffset(340,20),
    BackgroundTransparency=1,TextXAlignment=Enum.TextXAlignment.Left,
    TextColor3=Color3.fromRGB(145,157,172),Font=Enum.Font.Gotham,
    TextSize=11},panel)
local function button(label,x,y,w,color)
    local o=make('TextButton',{Text=label,Position=UDim2.fromOffset(x,y),
        Size=UDim2.fromOffset(w,30),BackgroundColor3=color or Color3.fromRGB(43,48,59),
        TextColor3=Color3.fromRGB(243,245,249),TextSize=12,
        Font=Enum.Font.GothamMedium,BorderSizePixel=0},panel)
    make('UICorner',{CornerRadius=UDim.new(0,7)},o)
    return o
end
local close=button('X',314,10,30,Color3.fromRGB(88,48,54))
local toggle=button('DELETAR: ON',14,64,159,Color3.fromRGB(52,108,82))
local mode=button('ALVO: MODELO',185,64,159)
local undo=button('DESFAZER',14,101,159)
local restore=button('RESTAURAR TUDO',185,101,159)
local copy=button('COPIAR LOG',14,138,330,Color3.fromRGB(44,90,141))
local targetLabel=make('TextLabel',{Text='Aponte e clique para ocultar',
    Position=UDim2.fromOffset(14,178),Size=UDim2.fromOffset(332,20),
    TextColor3=Color3.fromRGB(216,220,228),
    TextXAlignment=Enum.TextXAlignment.Left,TextTruncate=Enum.TextTruncate.AtEnd,
    Font=Enum.Font.Gotham,TextSize=12,BackgroundTransparency=1},panel)
local counter=make('TextLabel',{Text='',Position=UDim2.fromOffset(14,200),
    Size=UDim2.fromOffset(332,17),TextColor3=Color3.fromRGB(175,184,197),
    TextXAlignment=Enum.TextXAlignment.Left,Font=Enum.Font.Gotham,
    TextSize=11,BackgroundTransparency=1},panel)
local info=make('TextLabel',{Text='Log: '..savedFile,
    Position=UDim2.fromOffset(14,220),Size=UDim2.fromOffset(332,17),
    TextTruncate=Enum.TextTruncate.AtEnd,TextColor3=Color3.fromRGB(123,204,157),
    TextXAlignment=Enum.TextXAlignment.Left,Font=Enum.Font.Gotham,
    TextSize=10,BackgroundTransparency=1},panel)
local highlight=make('Highlight',{Name='VB_Inspector_Indicator',Enabled=false,
    FillColor=Color3.fromRGB(255,74,85),OutlineColor=Color3.fromRGB(255,160,161),
    FillTransparency=0.75,OutlineTransparency=0,
    DepthMode=Enum.HighlightDepthMode.AlwaysOnTop},Workspace)
local function report(text) if info.Parent then info.Text=text end end
local function refresh()
    counter.Text=string.format('%d objetos no log • %d nesta sessão',#log,#history)
    toggle.Text=enabled and 'DELETAR: ON' or 'DELETAR: OFF'
    toggle.BackgroundColor3=enabled and Color3.fromRGB(52,108,82)
        or Color3.fromRGB(59,63,70)
    mode.Text=asModel and 'ALVO: MODELO' or 'ALVO: PEÇA'
end
local function change(state,obj,property,value)
    local ok,old=pcall(function() return obj[property] end)
    if not ok or old==value then return end
    if pcall(function() obj[property]=value end) then
        state[#state+1]={instance=obj,property=property,old=old}
    end
end
local function hide(target)
    local state={}
    local descendants={target}
    if target:IsA('Model') then
        for _,node in ipairs(target:GetDescendants()) do descendants[#descendants+1]=node end
    end
    local count=0
    for _,node in ipairs(descendants) do
        if node:IsA('BasePart') then
            count=count+1
            change(state,node,'LocalTransparencyModifier',1)
        elseif node:IsA('Decal') or node:IsA('Texture') then
            change(state,node,'Transparency',1)
        elseif node:IsA('ParticleEmitter') or node:IsA('Trail')
            or node:IsA('Beam') or node:IsA('BillboardGui')
            or node:IsA('SurfaceGui') or node:IsA('ProximityPrompt')
            or node:IsA('PointLight') or node:IsA('SpotLight')
            or node:IsA('SurfaceLight') or node:IsA('Highlight') then
            change(state,node,'Enabled',false)
        end
    end
    return state,count
end
local function revert(state)
    for i=#state,1,-1 do
        local item=state[i]
        pcall(function() item.instance[item.property]=item.old end)
    end
end
local function rectHit(mouse)
    local p,z=panel.AbsolutePosition,panel.AbsoluteSize
    return mouse.X>=p.X and mouse.X<=p.X+z.X
        and mouse.Y>=p.Y and mouse.Y<=p.Y+z.Y
end
local function selection()
    local camera=Workspace.CurrentCamera
    if not camera then return nil,nil end
    local mouse=Input:GetMouseLocation()
    if rectHit(mouse) then return nil,nil end
    local ignore={}
    if player.Character then ignore[#ignore+1]=player.Character end
    for _,entry in ipairs(history) do
        if entry.target and entry.target.Parent then ignore[#ignore+1]=entry.target end
    end
    local options=RaycastParams.new()
    options.FilterType=Enum.RaycastFilterType.Exclude
    options.FilterDescendantsInstances=ignore
    options.IgnoreWater=true
    local ray=camera:ScreenPointToRay(mouse.X,mouse.Y)
    local result=Workspace:Raycast(ray.Origin,ray.Direction*1200,options)
    if not result then return nil,nil end
    return candidate(result.Instance),result.Instance
end
local function record(target,hit,count)
    local path,trail=pathOf(target)
    local hitPath=pathOf(hit)
    local pos,size
    if target:IsA('BasePart') then
        pos=coords(target.Position)
        size=coords(target.Size)
    else
        local ok,cf,sz=pcall(function() return target:GetBoundingBox() end)
        if ok then pos=coords(cf.Position) size=coords(sz) end
    end
    return {name=target.Name,class=target.ClassName,path=path,trail=trail,
        selectedPart=hitPath,position=pos,size=size,parts=count,
        universe=game.GameId,placeId=game.PlaceId,
        collectedAt=os.date('!%Y-%m-%dT%H:%M:%SZ')}
end
local function clickObject(target,hit)
    local changes,count=hide(target)
    if #changes==0 then report('Nada visual para ocultar') return end
    local entry=record(target,hit,count)
    log[#log+1]=entry
    history[#history+1]={target=target,changes=changes,entry=entry}
    save()
    refresh()
    report('Ocultado: '..target.Name..' | colisão mantida')
end
local function undoLast()
    local action=table.remove(history)
    if not action then report('Nada para desfazer') return end
    revert(action.changes)
    for i=#log,1,-1 do
        if log[i]==action.entry then table.remove(log,i) break end
    end
    save()
    refresh()
    report('Restaurado: '..action.target.Name)
end
local function restoreAll()
    for i=#history,1,-1 do
        local action=history[i]
        revert(action.changes)
        for j=#log,1,-1 do
            if log[j]==action.entry then table.remove(log,j) break end
        end
    end
    table.clear(history)
    save()
    refresh()
    report('Tudo restaurado nesta sessão')
end
local function exportLog()
    local result=Http:JSONEncode(payload())
    local clipboard=(type(setclipboard)=='function' and setclipboard)
        or (type(toclipboard)=='function' and toclipboard)
    if clipboard and pcall(clipboard,result) then
        report('Log copiado: '..#log..' objetos')
    else
        save()
        report('Copie o arquivo: '..savedFile)
    end
end
local function stop()
    if stopped then return end
    stopped=true
    enabled=false
    save()
    for i=#history,1,-1 do revert(history[i].changes) end
    for _,link in ipairs(links) do pcall(function() link:Disconnect() end) end
    highlight:Destroy()
    gui:Destroy()
    if env.VBObjectLogger and env.VBObjectLogger.Close==stop then
        env.VBObjectLogger=nil
    end
end
env.VBObjectLogger={Close=stop,CopyLog=exportLog,GetLog=function() return log end}
refresh()
links[#links+1]=toggle.MouseButton1Click:Connect(function()
    enabled=not enabled
    refresh()
    report(enabled and 'Clique nos objetos para ocultar' or 'Modo de deletar pausado')
end)
links[#links+1]=mode.MouseButton1Click:Connect(function()
    asModel=not asModel
    hover=nil
    highlight.Enabled=false
    refresh()
end)
links[#links+1]=undo.MouseButton1Click:Connect(undoLast)
links[#links+1]=restore.MouseButton1Click:Connect(restoreAll)
links[#links+1]=copy.MouseButton1Click:Connect(exportLog)
links[#links+1]=close.MouseButton1Click:Connect(stop)
links[#links+1]=Input.InputBegan:Connect(function(input,processed)
    if stopped or not enabled or processed
        or input.UserInputType~=Enum.UserInputType.MouseButton1 then return end
    local target,part=selection()
    if target and part then clickObject(target,part) end
end)
links[#links+1]=Run.RenderStepped:Connect(function()
    if stopped then return end
    if not enabled then highlight.Enabled=false return end
    if os.clock()-hoverTime<0.08 then return end
    hoverTime=os.clock()
    local target=selection()
    if target~=hover then
        hover=target
        highlight.Adornee=target
        highlight.Enabled=target~=nil
        targetLabel.Text=target and ('Alvo: '..target.Name..' ('..target.ClassName..')')
            or 'Aponte e clique para ocultar'
    end
end)
local dragging=false
local dragPos,framePos
links[#links+1]=title.InputBegan:Connect(function(input)
    if input.UserInputType==Enum.UserInputType.MouseButton1 then
        dragging=true
        dragPos=Input:GetMouseLocation()
        framePos=panel.Position
    end
end)
links[#links+1]=Input.InputChanged:Connect(function(input)
    if dragging and input.UserInputType==Enum.UserInputType.MouseMovement then
        local delta=Input:GetMouseLocation()-dragPos
        panel.Position=UDim2.new(framePos.X.Scale,framePos.X.Offset+delta.X,
            framePos.Y.Scale,framePos.Y.Offset+delta.Y)
    end
end)
links[#links+1]=Input.InputEnded:Connect(function(input)
    if input.UserInputType==Enum.UserInputType.MouseButton1 then dragging=false end
end)
