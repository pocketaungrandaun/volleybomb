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


toggle('Lock-on (avatar)',0,'LockOn',Color3.fromRGB(190,160,255))
refreshSmart=toggle('Dive Inteligente',47,'SmartDive',Color3.fromRGB(255,190,90))
toggle('FPS Turbo',94,'FPSBoost',Color3.fromRGB(95,220,183))




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

