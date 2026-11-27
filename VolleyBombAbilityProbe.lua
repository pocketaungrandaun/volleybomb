-- VolleyBomb Ability Probe 1.0
-- Independente do VolleyBombLanding.lua. Nao modifica gameplay.
-- F6 = nova leitura de icones/modulos. F7 = salvar relatorio agora.
-- Captura dados disponiveis ao cliente. Nunca le estado privado do servidor.
return (function()
local Players=game:GetService('Players')
local R=game:GetService('ReplicatedStorage')
local W=game:GetService('Workspace')
local Run=game:GetService('RunService')
local U=game:GetService('UserInputService')
local Http=game:GetService('HttpService')
local me=Players.LocalPlayer
local env=type(getgenv)=='function' and getgenv() or _G
if type(env.VolleyBombAbilityProbe)=='table'
    and type(env.VolleyBombAbilityProbe.Stop)=='function' then
    pcall(env.VolleyBombAbilityProbe.Stop)
end
local names={'Adrenaline','Frozen','Superspike','Magnet','Curveball',
    'Forcefield','Moonball','Portal','Shockwave','TornadoBall','Guardian'}
local aliases={}
for _,name in ipairs(names) do
    aliases[name:lower():gsub('[^%w]','')]=name
end
aliases.super='Superspike'
aliases.tornado='TornadoBall'
aliases.superstrike='Superspike'
local report={
    format='VolleyBombAbilityProbe/1.0',
    startedAt=os.date('!%Y-%m-%dT%H:%M:%SZ'),
    placeId=game.PlaceId,
    gameId=game.GameId,
    observation='client replication only: server-owned cooldowns may be hidden',
    images={},abilityInfo={},abilityModules={},events={},
    playerSnapshots={},hoverSamples={},remoteNames={},
    files={},errors={},notes={}
}
local connections={}
local previous=0
local lastMouse=''
local running=true
local scans=0
local eventLimit=130
local lastSave=0
local iconNumbers={}
local filePrefix='VolleyBomb_AbilityProbe'
local folder='VolleyBomb_AbilityIcons'
local activeGui=nil
local message=nil
local sampleTime=0
local snapshotTime=0
local stopTime=os.clock()+150

local function errorLog(why)
    if #report.errors<40 then
        report.errors[#report.errors+1]=tostring(why):sub(1,230)
    end
end
local function normName(value)
    if typeof(value)=='Instance' then value=value.Name end
    if type(value)~='string' then return nil end
    return aliases[value:lower():gsub('[^%w]','')]
end
local function compact(value,depth)
    if depth==nil then depth=0 end
    if depth>4 then return tostring(value):sub(1,90) end
    local typ=typeof(value)
    if typ=='Instance' then
        return {class=value.ClassName,path=value:GetFullName()}
    elseif typ=='Vector3' then
        return {x=value.X,y=value.Y,z=value.Z}
    elseif typ=='Color3' then
        return {r=value.R,g=value.G,b=value.B}
    elseif typ=='EnumItem' then
        return tostring(value)
    elseif typ=='string' then
        return value:sub(1,350)
    elseif typ=='number' or typ=='boolean' then
        return value
    elseif typ=='table' then
        local out={}
        local n=0
        for k,v in pairs(value) do
            n=n+1
            if n>38 then out['_truncated']=true break end
            local key=type(k)=='string' and k or tostring(k)
            out[key]=compact(v,depth+1)
        end
        return out
    end
    return tostring(value):sub(1,100)
end

local function iconCandidate(skill,id,source,extra)
    if not skill or not id or type(id)~='string' then return end
    if id=='' then return end
    local entry={asset=id,source=source}
    if extra then entry.extra=extra end
    local list=report.images[skill]
    if not list then list={} report.images[skill]=list end
    for _,existing in ipairs(list) do
        if existing.asset==id and existing.source==source then return end
    end
    if #list<35 then list[#list+1]=entry end
    local number=id:match('rbxassetid://(%d+)')
        or id:match('^https?://www%.roblox%.com/asset/%?id=(%d+)')
        or id:match('^%d+$')
    if number then iconNumbers[skill]=iconNumbers[skill] or {} iconNumbers[skill][number]=true end
end

local function findValueImages(data,skill,source,depth)
    if type(data)~='table' or depth>5 then return end
    local processed=0
    for k,v in pairs(data) do
        processed=processed+1
        if processed>130 then break end
        local key=tostring(k)
        local field=key:lower()
        local named=normName(key)
        if named and type(v)=='table' then
            findValueImages(v,named,source..'.'..key,depth+1)
        elseif type(v)=='table' then
            findValueImages(v,skill,source..'.'..key,depth+1)
        elseif skill and (field:find('icon') or field:find('image')
            or field:find('texture') or field:find('thumbnail')) then
            if type(v)=='string' then iconCandidate(skill,v,source..'.'..key)
            elseif type(v)=='number' then
                iconCandidate(skill,'rbxassetid://'..tostring(math.floor(v)),source..'.'..key)
            end
        end
    end
end

local function sourceModuleInfo()
    local dataFolder=R:FindFirstChild('Data')
    local infoFolder=dataFolder and dataFolder:FindFirstChild('Info')
    local dataModule=infoFolder and infoFolder:FindFirstChild('Abilities')
    if dataModule and dataModule:IsA('ModuleScript') then
        local ok,data=pcall(require,dataModule)
        if ok and type(data)=='table' then
            report.abilityInfo.metadata={
                module=dataModule:GetFullName(),
                keys={},records={}
            }
            local top=report.abilityInfo.metadata
            for k,v in pairs(data) do
                local key=tostring(k)
                if #top.keys<80 then top.keys[#top.keys+1]=key end
                local skill=normName(key)
                if skill then
                    top.records[skill]=compact(v)
                elseif type(v)=='table' then
                    local found=0
                    for name,entry in pairs(v) do
                        local candidate=normName(name)
                        if candidate and found<22 then
                            top.records[candidate]=compact(entry)
                            found=found+1
                        end
                    end
                end
            end
            findValueImages(data,nil,'ReplicatedStorage.Data.Info.Abilities',0)
        else
            errorLog('Data.Info.Abilities require: '..tostring(data))
        end
    else
        errorLog('ReplicatedStorage.Data.Info.Abilities not visible')
    end

    local shared=R:FindFirstChild('Shared')
    local modules=shared and shared:FindFirstChild('Modules')
    local abilityFolder=modules and modules:FindFirstChild('Abilities')
    if not abilityFolder then
        errorLog('ReplicatedStorage.Shared.Modules.Abilities absent')
        return
    end
    for _,module in ipairs(abilityFolder:GetChildren()) do
        if module:IsA('ModuleScript') then
            local ability=normName(module.Name)
            if ability then
                local ok,tableData=pcall(require,module)
                local item={module=module:GetFullName(),loaded=ok}
                if ok and type(tableData)=='table' then
                    item.duration=compact(tableData.Duration)
                    item.cooldown=compact(tableData.Cooldown)
                    local cd=tonumber(tableData.Cooldown)
                    local duration=tonumber(tableData.Duration) or 0
                    if cd and cd>=0 and cd<500 and duration>=0 and duration<200 then
                        item.durationPlusCooldown=cd+duration
                    end
                    item.members={}
                    for k,v in pairs(tableData) do
                        if #item.members<65 then
                            item.members[#item.members+1]=tostring(k)..' ['..type(v)..']'
                        end
                    end
                    findValueImages(tableData,ability,module:GetFullName(),0)
                else
                    item.error=tostring(tableData):sub(1,220)
                end
                -- Optional decompile collects only cooldown-related lines.
                -- No private server sources are accessible from clients.
                if type(decompile)=='function' then
                    local success,code=pcall(decompile,module)
                    if success and type(code)=='string' then
                        local lines={}
                        local count=0
                        for line in code:gmatch('[^\r\n]+') do
                            count=count+1
                            if line:find('Cooldown',1,true)
                                or line:find('Duration',1,true)
                                or line:find('ServerTimeNow',1,true)
                                or line:find('OnRoundChange',1,true)
                                or line:find('Guard(',1,true)
                                or line:find('Net:Connect(',1,true) then
                                if #lines<35 then
                                    lines[#lines+1]=tostring(count)..': '..line:sub(1,330)
                                end
                            end
                            if count>1600 then break end
                        end
                        item.cooldownSourceLines=lines
                    else
                        item.decompileError=tostring(code):sub(1,100)
                    end
                end
                report.abilityModules[ability]=item
            end
        end
    end
end

local function guiIconSource()
    local found=0
    local zones={
        {object=me:FindFirstChildOfClass('PlayerGui'),tag='PlayerGui'},
        {object=R:FindFirstChild('Assets'),tag='ReplicatedStorage.Assets'}
    }
    for _,zone in ipairs(zones) do
        if zone.object then
            local nodes=zone.object:GetDescendants()
            local maxCount=math.min(#nodes,9000)
            for j=1,maxCount do
                local inst=nodes[j]
                if inst:IsA('ImageLabel') or inst:IsA('ImageButton') then
                    local id=inst.Image
                    if id~='' then
                        local current=inst
                        local known=nil
                        for _=1,5 do
                            if not current or current==zone.object then break end
                            local name=normName(current.Name)
                            if name then known=name break end
                            current=current.Parent
                        end
                        if known then
                            iconCandidate(known,id,inst:GetFullName())
                            found=found+1
                        end
                    end
                end
            end
            -- Search exact skill text even if the UI layout is generic.
            for j=1,maxCount do
                local node=nodes[j]
                if node:IsA('TextLabel') or node:IsA('TextButton') then
                    local key=normName(node.Text)
                    if key then
                        local p=node.Parent
                        for _=1,2 do
                            if not p or p==zone.object then break end
                            for _,child in ipairs(p:GetDescendants()) do
                                if (child:IsA('ImageLabel') or child:IsA('ImageButton'))
                                    and child.Image~='' then
                                    iconCandidate(key,child.Image,
                                        'label-neighbor:'..child:GetFullName(),
                                        'matches label '..node:GetFullName())
                                    found=found+1
                                end
                            end
                            p=p.Parent
                        end
                    end
                end
            end
        end
    end
    report.imageScan={at=os.clock(),nodesWithSkillImages=found}
end

local interestingAttr={'ability','cooldown','skill','power','equipped','passive',
    'team','round','replion','loadout','class','stamina','ready'}
local function playerData(pl)
    local data={playerName=pl.Name,displayName=pl.DisplayName,
        attributes={},valueObjects={},team=pl.Team and pl.Team.Name or nil}
    local function inspect(inst,tag)
        if not inst then return end
        for k,v in pairs(inst:GetAttributes()) do
            local low=k:lower()
            for _,needle in ipairs(interestingAttr) do
                if low:find(needle,1,true) then
                    data.attributes[tag..'.'..k]=compact(v)
                    break
                end
            end
        end
        local list=inst:GetDescendants()
        local n=0
        for _,node in ipairs(list) do
            if n>180 then break end
            if node:IsA('ValueBase') then
                for _,needle in ipairs(interestingAttr) do
                    if node.Name:lower():find(needle,1,true) then
                        local ok,v=pcall(function() return node.Value end)
                        if ok then
                            n=n+1
                            data.valueObjects[node:GetFullName()]=compact(v)
                        end
                        break
                    end
                end
            end
        end
    end
    inspect(pl,'Player')
    inspect(pl.Character,'Character')
    for _,child in ipairs(pl:GetChildren()) do
        if child:IsA('Folder') and
            (child.Name:lower():find('data') or child.Name:lower():find('stats')
            or child.Name:lower():find('loadout')) then
            inspect(child,child.Name)
        end
    end
    return data
end

local function playerFromPart(part)
    if not part then return nil end
    local node=part
    for _=1,14 do
        if not node or node==W then return nil end
        if node:IsA('Model') then
            local pl=Players:GetPlayerFromCharacter(node)
            if pl then return pl end
        end
        node=node.Parent
    end
    return nil
end

local function hoverData()
    local camera=W.CurrentCamera
    if not camera then return {error='no camera'} end
    local mouse=me:GetMouse()
    local cursor=U:GetMouseLocation()
    local rb=camera:ViewportPointToRay(cursor.X,cursor.Y)
    local p=RaycastParams.new()
    p.FilterType=Enum.RaycastFilterType.Exclude
    local exclude={me.Character}
    p.FilterDescendantsInstances=exclude
    local hit=W:Raycast(rb.Origin,rb.Direction*1400,p)
    local native=mouse.Target
    local nearby={}
    for _,pl in ipairs(Players:GetPlayers()) do
        if pl~=me and pl.Character then
            local root=pl.Character:FindFirstChild('HumanoidRootPart')
            if root then
                local projected,onScreen=camera:WorldToViewportPoint(root.Position)
                local delta=(Vector2.new(projected.X,projected.Y)-cursor).Magnitude
                if onScreen and delta<140 then
                    nearby[#nearby+1]={player=pl.Name,deltaPixels=math.floor(delta),
                        distance=math.floor((root.Position-rb.Origin).Magnitude),
                        visible=true}
                end
            end
        end
    end
    table.sort(nearby,function(a,b) return a.deltaPixels<b.deltaPixels end)
    while #nearby>5 do table.remove(nearby) end
    return {
        at=os.clock(),mouseLocation={x=math.floor(cursor.X),y=math.floor(cursor.Y)},
        behavior=tostring(U.MouseBehavior),
        targetNative=native and native:GetFullName() or nil,
        playerNative=playerFromPart(native) and playerFromPart(native).Name or nil,
        targetRaycast=hit and hit.Instance:GetFullName() or nil,
        playerRaycast=hit and playerFromPart(hit.Instance)
            and playerFromPart(hit.Instance).Name or nil,
        nearPlayers=nearby,
        inRound=me:GetAttribute('InRound'),
        cameraType=tostring(camera.CameraType)
    }
end

local function snapshot()
    local data={at=os.clock(),
        inRound=me:GetAttribute('InRound'),
        players={},hover=hoverData()}
    for _,pl in ipairs(Players:GetPlayers()) do
        if #data.players<25 then data.players[#data.players+1]=playerData(pl) end
    end
    report.playerSnapshots[#report.playerSnapshots+1]=data
    if #report.playerSnapshots>12 then table.remove(report.playerSnapshots,1) end
end

local function eventArgs(...)
    local args=table.pack(...)
    local data={}
    for i=1,math.min(args.n,4) do data[i]=compact(args[i]) end
    return data
end

local function watchEvents()
    local net=R:FindFirstChild('Packages') and R.Packages:FindFirstChild('Net')
    if not net then errorLog('ReplicatedStorage.Packages.Net absent') return end
    for _,remote in ipairs(net:GetChildren()) do
        if remote:IsA('RemoteEvent') then
            report.remoteNames[#report.remoteNames+1]=remote.Name
            local n=remote.Name:lower()
            if n:find('ability') or n:find('cooldown') or n:find('skill')
                or n:find('notify') or n:find('roundnotification')
                or n:find('equip') or n:find('magnet') then
                connections[#connections+1]=remote.OnClientEvent:Connect(function(...)
                    if not running or #report.events>=eventLimit then return end
                    report.events[#report.events+1]={
                        at=os.clock(),remote=remote.Name,
                        args=eventArgs(...)
                    }
                end)
            end
        end
    end
end

local function httpRequest(url)
    local fn=type(request)=='function' and request
        or (type(http_request)=='function' and http_request)
    if not fn and type(syn)=='table' and type(syn.request)=='function' then
        fn=syn.request
    end
    if not fn then return nil,'executor request unavailable' end
    local ok,res=pcall(fn,{Url=url,Method='GET',
        Headers={Accept='image/png,image/webp,image/jpeg,*/*'}})
    if not ok or type(res)~='table' then return nil,tostring(res) end
    if res.Success==false or (tonumber(res.StatusCode) or 200)>=400 then
        return nil,'HTTP '..tostring(res.StatusCode)
    end
    local body=res.Body
    if type(body)~='string' then return nil,'empty response body' end
    return body,nil
end
local function fileType(data)
    if data:sub(1,8)=='\137PNG\r\n\26\n' then return 'png' end
    if data:sub(1,3)=='\255\216\255' then return 'jpg' end
    if data:sub(1,4)=='RIFF' and data:sub(9,12)=='WEBP' then return 'webp' end
    return nil
end
local function exportImages()
    if type(writefile)~='function' then
        report.notes[#report.notes+1]='writefile unavailable; images exported as asset references only'
        return
    end
    if type(makefolder)=='function' then pcall(makefolder,folder) end
    local files={}
    local count=0
    for _,skill in ipairs(names) do
        local seen=iconNumbers[skill]
        if seen then
            for id in pairs(seen) do
                count=count+1
                if count>55 then break end
                local body,err=httpRequest('https://assetdelivery.roblox.com/v1/asset/?id='..id)
                local extension=body and fileType(body) or nil
                if extension then
                    local name=folder..'/'..skill..'_'..id..'.'..extension
                    local ok,werr=pcall(writefile,name,body)
                    files[#files+1]={ability=skill,assetId=id,file=name,
                        bytes=#body,format=extension,saved=ok,
                        error=not ok and tostring(werr) or nil}
                else
                    files[#files+1]={ability=skill,assetId=id,saved=false,
                        reason=err or 'Asset Delivery returned non-image, maybe JSON/redirect'}
                end
            end
        end
        if count>55 then break end
    end
    report.files=files
end

local function status(text)
    if message then message.Text='Ability Probe  |  '..text end
    print('[VB Ability Probe] '..text)
end
local function save(exportPNG)
    if not running then return end
    snapshot()
    if exportPNG then
        status('salvando relatorio e PNGs originais se disponiveis...')
        exportImages()
    end
    report.savedAt=os.date('!%Y-%m-%dT%H:%M:%SZ')
    local ok,json=pcall(Http.JSONEncode,Http,report)
    if not ok then errorLog('JSONEncode: '..tostring(json)) return end
    local filename=filePrefix..'_LATEST.json'
    if type(writefile)=='function' then
        local success,err=pcall(writefile,filename,json)
        if success then
            status('SALVO '..filename..' | F6 escanear | F7 salvar')
        else
            errorLog('writefile: '..tostring(err))
            status('writefile falhou: '..tostring(err))
        end
    elseif type(setclipboard)=='function' then
        pcall(setclipboard,json)
        status('relatorio copiado para area de transferencia')
    else
        status('sem writefile; dados no output? env.VolleyBombAbilityProbe.Report')
    end
end

local function scan()
    scans=scans+1
    local ok,err=pcall(sourceModuleInfo)
    if not ok then errorLog('scan modules: '..tostring(err)) end
    local ok2,err2=pcall(guiIconSource)
    if not ok2 then errorLog('scan images: '..tostring(err2)) end
    report.scans=scans
    status('leitura '..scans..' | F6 repetir | F7 salvar PNG/JSON')
end

local function buildGUI()
    local gui=Instance.new('ScreenGui')
    gui.Name='VolleyBombAbilityProbeGUI'
    gui.ResetOnSpawn=false
    gui.IgnoreGuiInset=true
    gui.DisplayOrder=800
    gui.Parent=me:WaitForChild('PlayerGui')
    local panel=Instance.new('TextLabel')
    panel.Name='Status'
    panel.Size=UDim2.fromOffset(420,27)
    panel.AnchorPoint=Vector2.new(1,0)
    panel.Position=UDim2.new(1,-12,0,12)
    panel.BackgroundColor3=Color3.fromRGB(26,24,34)
    panel.BackgroundTransparency=0.25
    panel.TextColor3=Color3.fromRGB(255,255,255)
    panel.Font=Enum.Font.GothamMedium
    panel.TextSize=12
    panel.Text='Ability Probe | F6 reler | F7 salvar'
    panel.Parent=gui
    local corner=Instance.new('UICorner')
    corner.CornerRadius=UDim.new(0,7)
    corner.Parent=panel
    activeGui=gui
    message=panel
end

local function stop()
    if not running then return end
    pcall(save,false)
    running=false
    for _,connection in ipairs(connections) do
        pcall(function() connection:Disconnect() end)
    end
    if activeGui then activeGui:Destroy() end
    if env.VolleyBombAbilityProbe and env.VolleyBombAbilityProbe.Report==report then
        env.VolleyBombAbilityProbe=nil
    end
end

env.VolleyBombAbilityProbe={Stop=stop,Save=save,Scan=scan,Report=report}

buildGUI()
watchEvents()
scan()
snapshot()
connections[#connections+1]=U.InputBegan:Connect(function(input,processed)
    if processed or U:GetFocusedTextBox() then return end
    if input.KeyCode==Enum.KeyCode.F6 then
        task.spawn(scan)
    elseif input.KeyCode==Enum.KeyCode.F7 then
        task.spawn(function() save(true) end)
    end
end)
connections[#connections+1]=Run.Heartbeat:Connect(function()
    if not running then return end
    local now=os.clock()
    if now>=stopTime then
        stop()
        return
    end
    if now-sampleTime>0.25 then
        sampleTime=now
        local sample=hoverData()
        local key=tostring(sample.playerNative)..'/'..
            tostring(sample.playerRaycast)..'/'..tostring(sample.inRound)
        if sample.playerNative or sample.playerRaycast
            or #sample.nearPlayers>0 then
            if key~=lastMouse or now-previous>2 then
                previous=now
                lastMouse=key
                report.hoverSamples[#report.hoverSamples+1]=sample
                if #report.hoverSamples>100 then
                    table.remove(report.hoverSamples,1)
                end
            end
        end
    end
    if now-snapshotTime>15 then
        snapshotTime=now
        snapshot()
        if now-lastSave>20 then
            lastSave=now
            save(false)
        end
    end
end)
status('pronto. Passe o mouse nos jogadores e use habilidades; F7 salva JSON/PNG')
return env.VolleyBombAbilityProbe
end)()
