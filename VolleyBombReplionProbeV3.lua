-- VolleyBomb Replion Probe 3.1 (immediate autosave + visible save button)
-- Investiga se habilidade equipada dos OUTROS jogadores e replicada
-- ANTES do primeiro uso. Nao altera fisica, GUI do jogo ou remotes.
-- F6 = nova leitura, F7 = salvar relatorio.
return (function()
    local P=game:GetService('Players')
    local R=game:GetService('ReplicatedStorage')
    local W=game:GetService('Workspace')
    local U=game:GetService('UserInputService')
    local Run=game:GetService('RunService')
    local H=game:GetService('HttpService')
    local me=P.LocalPlayer
    local state={
        format='VolleyBombReplionProbe/3.1',
        replion={loaded=false,observations={},channels={},events={},errors={}},
        placeId=game.PlaceId,
        startedAt=os.date('!%Y-%m-%dT%H:%M:%SZ'),
        snapshots={},events={},packageModules={},
        errors={},notes={
            'Dados vistos pelo cliente apenas; ausencia de habilidade nao prova que o servidor nunca envia',
            'A leitura deve ocorrer ANTES da primeira habilidade ser usada na partida'
        }
    }
    local active=true
    local cn={}
    local OUTPUT='VolleyBomb_REPLION_V3_ONLY.json'
    local statusLabel=nil
    local panelGui=nil
    local saves=0
    local lastFileStatus=''
    -- Arquivo v3 criado ANTES de inicializar o Replion. Se o codigo
    -- falhar depois, teremos ao menos um JSON v3 com o erro de inicio.
    do
        local ok,json=pcall(H.JSONEncode,H,{
            format=state.format,
            startedAt=state.startedAt,
            stage='BOOTSTRAP',
            notes={'O diagnostico ainda nao terminou de inicializar'}
        })
        if ok and type(writefile)=='function' then
            local saved,why=pcall(writefile,OUTPUT,json)
            lastFileStatus=saved and 'BOOTSTRAP salvo'
                or ('Falha bootstrap: '..tostring(why))
        elseif type(writefile)~='function' then
            lastFileStatus='writefile indisponivel'
        end
        print('[VB Replion v3.1] '..lastFileStatus..' | '..OUTPUT)
    end
    local previous=type(getgenv)=='function' and getgenv() or _G
    -- Interrompe a instancia antiga, caso tenha permanecido rodando.
    for _,globalName in ipairs({'VBPreMatchProbe','VBReplionProbeV3'}) do
        local prior=previous[globalName]
        if type(prior)=='table' and type(prior.Stop)=='function' then
            pcall(prior.Stop)
        end
    end
    local icons={
        Adrenaline='97944922227782',Frozen='128928645067241',
        Superspike='79222800577374',Magnet='84541250301456',
        Curveball='84135124919799',Forcefield='85981316187333',
        Moonball='90742590592196',Portal='87889391982596',
        Shockwave='113239369966635',TornadoBall='117098264685504',
        Guardian='116764589545815'
    }
    local alias={}
    for k in pairs(icons) do alias[k:lower()]=k end
    alias.tornadoball='TornadoBall'
    alias.super='Superspike'
    local function skill(v)
        if typeof(v)=='Instance' then v=v.Name end
        if type(v)~='string' then return nil end
        return alias[v:lower():gsub('[^%w]','')]
    end
    local function iconId(v)
        if type(v)~='string' then return nil end
        local number=v:match('rbxassetid://(%d+)')
        if not number then return nil end
        for k,id in pairs(icons) do
            if id==number then return k end
        end
        return nil
    end
    local function err(msg)
        if #state.errors<28 then
            state.errors[#state.errors+1]=tostring(msg):sub(1,250)
        end
    end
    local function asPlayer(v)
        if typeof(v)=='Instance' and v:IsA('Player') then return v end
        if type(v)=='number' then return P:GetPlayerByUserId(v) end
        if type(v)~='string' then return nil end
        for _,pl in ipairs(P:GetPlayers()) do
            if v==pl.Name or v==tostring(pl.UserId) then return pl end
        end
        return nil
    end
    local function recordAttribute(node,tag,result)
        if not node then return end
        local ok,attributes=pcall(function() return node:GetAttributes() end)
        if ok then
            for k,v in pairs(attributes) do
                local key=k:lower()
                if key:find('ability') or key:find('skill') or
                    key:find('equip') or key:find('loadout') or
                    key:find('power') or key:find('cooldown') then
                    result[#result+1]={
                        path=tag..'.'..k,field=k,kind='Attribute',
                        value=tostring(v):sub(1,85),skill=skill(v)
                    }
                end
            end
        end
        if node:IsA('ValueBase') then
            local name=node.Name:lower()
            if name:find('ability') or name:find('skill') or
                name:find('equip') or name:find('loadout') or
                name:find('power') or name:find('cooldown') then
                local ok2,v=pcall(function() return node.Value end)
                if ok2 then
                    result[#result+1]={path=tag,field=node.Name,
                        kind=node.ClassName,value=tostring(v):sub(1,90),
                        skill=skill(v)}
                end
            end
        end
    end
    local function inspectNodeTree(node,owner,result,maxNodes)
        if not node then return end
        recordAttribute(node,owner..'/'..node.Name,result)
        local n=0
        for _,item in ipairs(node:GetDescendants()) do
            n=n+1
            if n>maxNodes then break end
            recordAttribute(item,owner..'/'..item:GetFullName(),result)
        end
    end
    local function playerScope(pl)
        local out={player=pl.Name,userId=pl.UserId,
            inRound=pl:GetAttribute('InRound'),publicValues={},
            matchIcons={},rosterIcons={},clientCache={}}
        inspectNodeTree(pl,'Players',out.publicValues,220)
        inspectNodeTree(pl.Character,'Character',out.publicValues,170)
        -- Alguns jogos criam os dados publicos em estruturas indexadas
        -- pelo UserId/nome do jogador, em vez de atributos de Player.
        for _,rootName in ipairs({'Data','PlayerData','PublicData',
            'Players','Profiles','ReplicatedData','PlayerProfiles'}) do
            local top=R:FindFirstChild(rootName)
            if top then
                for _,parent in ipairs({
                    top,top:FindFirstChild('Players'),top:FindFirstChild('Profiles')
                }) do
                    if parent then
                        local child=parent:FindFirstChild(pl.Name)
                            or parent:FindFirstChild(tostring(pl.UserId))
                        if child then
                            inspectNodeTree(child,'ReplicatedStorage/'..rootName,
                                out.publicValues,90)
                        end
                    end
                end
            end
        end
        if pl.Character then
            local n=0
            for _,desc in ipairs(pl.Character:GetDescendants()) do
                n=n+1
                if n>140 then break end
                if desc:IsA('ImageLabel') or desc:IsA('ImageButton') then
                    local ability=iconId(desc.Image)
                    if ability then out.matchIcons[#out.matchIcons+1]={
                        skill=ability,path=desc:GetFullName()} end
                end
            end
        end
        return out
    end
    local function rosterScan(rows)
        local gui=me:FindFirstChildOfClass('PlayerGui')
        if not gui then return end
        local elements=gui:GetDescendants()
        local n=0
        for _,item in ipairs(elements) do
            n=n+1
            if n>5000 then break end
            if item:IsA('TextLabel') or item:IsA('TextButton') then
                local text=item.Text:gsub('<[^>]+>','')
                local owner=asPlayer(text)
                if owner and owner~=me and rows[owner.UserId] then
                    local parent=item.Parent
                    -- Só a celula individual de jogador; nao a lista
                    -- inteira, que misturaria icones de outros players.
                    for _=1,2 do
                        if not parent or parent==gui then break end
                        local children=parent:GetDescendants()
                        if #children>55 then break end
                        for _,child in ipairs(children) do
                            if child:IsA('ImageLabel') or child:IsA('ImageButton') then
                                local ability=iconId(child.Image)
                                if ability then
                                    rows[owner.UserId].rosterIcons[#rows[owner.UserId].rosterIcons+1]={
                                        skill=ability,
                                        path=child:GetFullName(),
                                        associatedNamePath=item:GetFullName()
                                    }
                                end
                            end
                        end
                        parent=parent.Parent
                    end
                end
            end
        end
    end
    local function packages()
        local pkg=R:FindFirstChild('Packages')
        if not pkg then return end
        for _,v in ipairs(pkg:GetChildren()) do
            if v:IsA('ModuleScript') or v:IsA('Folder') then
                state.packageModules[#state.packageModules+1]={
                    name=v.Name,class=v.ClassName}
            end
        end
    end

    -- Replion pode guardar dados em tabelas por canal, nao em atributos
    -- de Player. Somente leitura de campos associados a habilidade.
    local replionClient=nil
    local observedReplions=setmetatable({},{__mode='k'})
    local replionCount=0
    local channelNames={
        'Data','PlayerData','Profile','Player','PublicData',
        'Players','PublicPlayers','Game','Match','Round',
        'GameState','Lobby','Profiles','PlayerProfile','Stats'
    }
    local function replionError(message)
        if #state.replion.errors<22 then
            state.replion.errors[#state.replion.errors+1]=tostring(message):sub(1,160)
        end
    end
    local function ownerFromPath(path)
        local stringPath=table.concat(path,'.')
        for _,pl in ipairs(P:GetPlayers()) do
            if stringPath:find(pl.Name,1,true)
                or stringPath:find(tostring(pl.UserId),1,true) then
                return pl.Name
            end
        end
        return nil
    end
    local function scanReplionTable(data,from,owner)
        local records={}
        if type(data)~='table' then return records,{} end
        local rootKeys={}
        for k in pairs(data) do
            if #rootKeys<65 then rootKeys[#rootKeys+1]=tostring(k):sub(1,75) end
        end
        local checked=0
        local seen={}
        local function walk(node,path,depth)
            if type(node)~='table' or seen[node] or depth>7
                or checked>=2200 or #records>120 then return end
            seen[node]=true
            for k,v in pairs(node) do
                checked=checked+1
                if checked>=2200 then break end
                local key=tostring(k)
                local nextPath={table.unpack(path)}
                nextPath[#nextPath+1]=key
                local lowered=key:lower()
                local valueType=type(v)
                local found=skill(v)
                local hasKey=lowered:find('ability',1,true)
                    or lowered:find('skill',1,true)
                    or lowered:find('equip',1,true)
                    or lowered:find('loadout',1,true)
                    or lowered:find('power',1,true)
                if (hasKey or found) and valueType~='function' then
                    if #records<120 then
                        local briefValue=nil
                        if valueType=='table' then
                            local keys={}
                            for childKey in pairs(v) do
                                if #keys<14 then keys[#keys+1]=tostring(childKey) end
                            end
                            briefValue={type='table',keys=keys}
                        elseif valueType=='string' or valueType=='number'
                            or valueType=='boolean' then
                            briefValue=tostring(v):sub(1,110)
                        else
                            briefValue=valueType
                        end
                        records[#records+1]={
                            path=table.concat(nextPath,'.'):sub(1,260),
                            owner=ownerFromPath(nextPath) or owner,
                            skill=found,value=briefValue
                        }
                    end
                end
                if valueType=='table' then walk(v,nextPath,depth+1) end
            end
        end
        walk(data,{from},0)
        return records,rootKeys
    end
    local function inspectReplion(replion,source)
        if type(replion)~='table' then return end
        local known=observedReplions[replion]
        if known then return end
        observedReplions[replion]=true
        replionCount=replionCount+1
        local key='replication'..tostring(replionCount)
        local obj={source=source,firstAt=os.clock(),fields={}}
        for _,field in ipairs({'Channel','Id','ID','Name','Tags'}) do
            local ok,value=pcall(function() return replion[field] end)
            if ok and (type(value)=='string' or type(value)=='number') then
                obj.fields[field]=tostring(value):sub(1,80)
            elseif ok and field=='Tags' and type(value)=='table' then
                local tags={}
                for k,v in pairs(value) do
                    if #tags>=18 then break end
                    if type(v)=='string' then
                        tags[#tags+1]=v:sub(1,80)
                    elseif type(k)=='string' then
                        tags[#tags+1]=k:sub(1,80)
                    end
                end
                obj.fields.Tags=tags
            end
        end
        local ok,data=pcall(function()
            if type(replion.Get)=='function' then
                return replion:Get()
            end
            return replion.Data
        end)
        if ok then
            local owner=obj.fields.Channel or obj.fields.Id or nil
            obj.matches,obj.rootKeys=scanReplionTable(data,source,owner)
            obj.dataType=type(data)
        else
            obj.error=tostring(data):sub(1,100)
        end
        state.replion.observations[key]=obj
        if type(replion.OnDataChange)=='function' then
            local worked,connection=pcall(function()
                return replion:OnDataChange(function(newData,path)
                    if not active or #state.replion.events>=100 then return end
                    local pieces={}
                    if type(path)=='table' then
                        for _,value in ipairs(path) do
                            pieces[#pieces+1]=tostring(value):sub(1,90)
                        end
                    end
                    local title=table.concat(pieces,'.')
                    local itemSkill=skill(newData)
                    local relevant=itemSkill
                        or title:lower():find('ability',1,true)
                        or title:lower():find('skill',1,true)
                        or title:lower():find('equip',1,true)
                        or title:lower():find('loadout',1,true)
                    if relevant then
                        state.replion.events[#state.replion.events+1]={
                            from=key,at=os.clock(),path=title:sub(1,230),
                            owner=ownerFromPath(pieces),
                            ability=itemSkill,
                            value=(type(newData)=='string' or
                                type(newData)=='number')
                                and tostring(newData):sub(1,120)
                                or type(newData)
                        }
                    end
                end)
            end)
            if worked and connection then
                cn[#cn+1]=connection
            end
        end
    end
    local function scanReplionChannels()
        if not replionClient then return end
        state.replion.scanCount=(state.replion.scanCount or 0)+1
        state.replion.lastScanAt=os.clock()
        if state.replion.scanCount==1 then
            print('[VB Replion v3.0] GetReplion channel scan iniciado')
        end
        for _,channel in ipairs(channelNames) do
            local ok,r=pcall(function()
                return replionClient:GetReplion(channel)
            end)
            if ok and r then
                state.replion.channels[channel]=true
                inspectReplion(r,'GetReplion:'..channel)
            end
        end
        -- Canais de jogador podem usar nomes, IDs ou prefixos.
        for _,pl in ipairs(P:GetPlayers()) do
            for _,channel in ipairs({
                pl.Name,tostring(pl.UserId),
                'Data/'..pl.UserId,'PlayerData/'..pl.UserId,
                'Player_'..pl.UserId
            }) do
                local ok,r=pcall(function()
                    return replionClient:GetReplion(channel)
                end)
                if ok and r then
                    state.replion.channels[channel]=true
                    inspectReplion(r,'GetReplion:'..channel)
                end
            end
        end
    end
    local function setupReplion()
        local pkg=R:FindFirstChild('Packages')
        local module=pkg and pkg:FindFirstChild('replion')
        if not module or not module:IsA('ModuleScript') then
            replionError('ReplicatedStorage.Packages.replion not found')
            return
        end
        local ok,export=pcall(require,module)
        if not ok then
            replionError('require replion: '..tostring(export))
            return
        end
        if type(export)~='table' then
            replionError('replion export is '..type(export))
            return
        end
        state.replion.loaded=true
        state.replion.moduleFields={}
        for k in pairs(export) do
            if #state.replion.moduleFields<40 then
                state.replion.moduleFields[#state.replion.moduleFields+1]=tostring(k)
            end
        end
        -- Neste jogo o ModuleScript retorna a API cliente DIRETAMENTE
        -- (GetReplion, OnReplionAdded, ...), sem campo .Client.
        -- Algumas versoes do pacote usam export.Client; suportar ambas.
        local clientApi=(type(export.Client)=='table' and export.Client)
            or export
        if type(clientApi.GetReplion)~='function'
            or type(clientApi.OnReplionAdded)~='function' then
            replionError('Replion API missing GetReplion/OnReplionAdded')
            return
        end
        replionClient=clientApi
        state.replion.apiMode=clientApi==export
            and 'direct ModuleScript return' or 'export.Client'
        print('[VB Replion v3.0] client API = '..state.replion.apiMode)
        state.replion.clientFields={}
        for k,v in pairs(replionClient) do
            if #state.replion.clientFields<65 then
                state.replion.clientFields[#state.replion.clientFields+1]={
                    field=tostring(k),kind=type(v)}
            end
            -- Alguns builds disponibilizam caches de replions atuais.
            -- Inspeciona apenas os objetos, sem modificar o cache.
            if type(v)=='table' and tostring(k):lower():find('replion') then
                local count=0
                for id,object in pairs(v) do
                    if count>=35 then break end
                    count=count+1
                    if type(object)=='table' and
                        (type(object.Get)=='function' or type(object.Data)=='table') then
                        inspectReplion(object,'Client.'..tostring(k)..'.'..tostring(id))
                    end
                end
            end
        end
        if type(replionClient.OnReplionAdded)=='function' then
            local worked,connection=pcall(function()
                return replionClient:OnReplionAdded(function(replica)
                    if active then inspectReplion(replica,'OnReplionAdded') end
                end)
            end)
            if worked and connection then
                cn[#cn+1]=connection
                state.replion.listenerConnected=true
            elseif not worked then
                replionError('OnReplionAdded: '..tostring(connection))
            end
        end
        scanReplionChannels()
    end

    local function gcInspect(byId)
        if type(getgc)~='function' then
            return {supported=false}
        end
        local result={supported=true,scanned=0,candidates={}}
        local ok,values=pcall(getgc,true)
        if not ok or type(values)~='table' then
            result.error=tostring(values):sub(1,100)
            return result
        end
        local n=0
        for _,item in ipairs(values) do
            if type(item)=='table' then
                n=n+1
                if n>3000 then break end
                local name,owner=nil,nil
                -- Precisamos de DADO POR JOGADOR. Metadados de
                -- todas as habilidades nao contam como equipadas.
                for k,v in pairs(item) do
                    if type(k)=='string' then
                        local normalized=k:lower()
                        if normalized=='userid' or normalized=='player'
                            or normalized=='owner' then
                            owner=owner or asPlayer(v)
                        elseif normalized=='equippedability'
                            or normalized=='abilityequipped'
                            or normalized=='selectedability'
                            or normalized=='currentability'
                            or normalized=='abilityname'
                            or normalized=='loadoutability' then
                            name=name or skill(v)
                        end
                    end
                end
                if owner and name and byId[owner.UserId]
                    and #result.candidates<40 then
                    result.candidates[#result.candidates+1]={
                        player=owner.Name,ability=name,
                        source='getgc: associated client table'
                    }
                    byId[owner.UserId].clientCache[#byId[owner.UserId].clientCache+1]=name
                end
            end
        end
        result.scanned=n
        return result
    end
    local function capture(reason)
        if not active then return end
        local result={reason=reason,at=os.clock(),
            selfRound=me:GetAttribute('InRound'),players={},gc={}}
        local byId={}
        for _,pl in ipairs(P:GetPlayers()) do
            if pl~=me then
                local data=playerScope(pl)
                result.players[#result.players+1]=data
                byId[pl.UserId]=data
            end
        end
        local ok,why=pcall(rosterScan,byId)
        if not ok then err('roster scan: '..tostring(why)) end
        if #state.snapshots==0 or reason=='F6' then
            local success,gc=pcall(gcInspect,byId)
            if success then result.gc=gc else err('GC: '..tostring(gc)) end
        end
        scanReplionChannels()
        state.snapshots[#state.snapshots+1]=result
        if #state.snapshots>9 then table.remove(state.snapshots,1) end
        print('[VB PreMatch] '..reason..': '..#result.players..' jogadores examinados')
    end
    local function sanitize(v)
        if typeof(v)=='Instance' then
            local pl=v:IsA('Player') and v or
                (v:IsA('Model') and P:GetPlayerFromCharacter(v))
            return pl and ('Player:'..pl.Name) or ('Instance:'..v.ClassName)
        end
        if type(v)=='string' then return v:sub(1,70) end
        if type(v)=='number' or type(v)=='boolean' then return v end
        if type(v)=='table' then
            local out={}
            local n=0
            for k,value in pairs(v) do
                n=n+1
                if n>12 then break end
                local key=tostring(k)
                if key:lower():find('ability') or key:lower():find('player')
                    or key:lower():find('equip') or
                    key:lower():find('skill') then
                    out[key]=sanitize(value)
                end
            end
            return out
        end
        return tostring(typeof(v))
    end
    local function watch()
        local packages=R:FindFirstChild('Packages')
        local net=packages and packages:FindFirstChild('Net')
        if not net then return end
        for _,name in ipairs({'RE/EquipAbility','RE/RoundNotification',
            'RE/AttachFX','RE/PassiveUsed'}) do
            local remote=net:FindFirstChild(name)
            if remote and remote:IsA('RemoteEvent') then
                cn[#cn+1]=remote.OnClientEvent:Connect(function(...)
                    if not active or #state.events>90 then return end
                    local args={...}
                    local result={}
                    for i=1,math.min(#args,4) do
                        result[i]=sanitize(args[i])
                    end
                    state.events[#state.events+1]={
                        at=os.clock(),remote=name,args=result
                    }
                end)
            end
        end
    end
    local function save()
        if not active then return end
        local captured,captureErr=pcall(capture,'SALVAR')
        if not captured then err('capture: '..tostring(captureErr)) end
        state.savedAt=os.date('!%Y-%m-%dT%H:%M:%SZ')
        state.saveAttempts=(state.saveAttempts or 0)+1
        local ok,encoded=pcall(H.JSONEncode,H,state)
        if not ok then
            err('JSON: '..tostring(encoded))
            warn('[VB Replion v3.1] erro ao gerar JSON: '..tostring(encoded))
            return
        end
        if type(writefile)=='function' then
            local saved,why=pcall(writefile,OUTPUT,encoded)
            if saved then
                saves=saves+1
                lastFileStatus='SALVO '..tostring(saves)..'x'
                print('[VB Replion v3.1] SALVO '..OUTPUT..
                    ' ('..tostring(#encoded)..' bytes)')
            else
                lastFileStatus='ERRO DE WRITEFILE'
                warn('[VB Replion v3.1] '..tostring(why))
            end
        elseif type(setclipboard)=='function' then
            local copied=pcall(setclipboard,encoded)
            lastFileStatus=copied and 'JSON COPIADO' or 'ERRO DE CLIPBOARD'
            print('[VB Replion v3.1] '..lastFileStatus)
        else
            lastFileStatus='SEM WRITEFILE OU CLIPBOARD'
            warn('[VB Replion v3.1] getgenv().VBReplionProbeV3.Report')
        end
        if statusLabel then
            statusLabel.Text='REPLION V3.1 | '..lastFileStatus
        end
    end
    local function showSaveButton()
        local pg=me:FindFirstChildOfClass('PlayerGui')
            or me:WaitForChild('PlayerGui',8)
        if not pg then return end
        local old=pg:FindFirstChild('VBReplionProbeV3HUD')
        if old then pcall(function() old:Destroy() end) end
        local gui=Instance.new('ScreenGui')
        gui.Name='VBReplionProbeV3HUD'
        gui.ResetOnSpawn=false
        gui.IgnoreGuiInset=true
        gui.DisplayOrder=250
        gui.Parent=pg
        panelGui=gui
        local button=Instance.new('TextButton')
        button.Name='SaveReport'
        button.AnchorPoint=Vector2.new(1,0)
        button.Position=UDim2.new(1,-12,0,48)
        button.Size=UDim2.fromOffset(275,38)
        button.BackgroundColor3=Color3.fromRGB(30,34,46)
        button.TextColor3=Color3.fromRGB(246,246,250)
        button.Font=Enum.Font.GothamMedium
        button.TextSize=12
        button.Text='REPLION V3.1 | SALVAR V3'
        button.AutoButtonColor=true
        button.Parent=gui
        local corner=Instance.new('UICorner')
        corner.CornerRadius=UDim.new(0,8)
        corner.Parent=button
        statusLabel=button
        cn[#cn+1]=button.MouseButton1Click:Connect(function()
            task.spawn(save)
        end)
    end
    local function stop()
        if not active then return end
        save()
        active=false
        for _,conn in ipairs(cn) do
            pcall(function()conn:Disconnect()end)
        end
        if panelGui then pcall(function() panelGui:Destroy() end) end
        if previous.VBReplionProbeV3
            and previous.VBReplionProbeV3.Report==state then
            previous.VBReplionProbeV3=nil
        end
    end
    previous.VBReplionProbeV3={Report=state,Scan=capture,Save=save,Stop=stop}
    packages()
    watch()
    setupReplion()
    if not state.replion.loaded then
        warn('[VB Replion v2.1] modulo Replion nao carregou; confira errors no JSON')
    end
    local startOK,startErr=pcall(capture,'EXECUCAO')
    if not startOK then err('startup capture: '..tostring(startErr)) end
    -- Salva IMEDIATAMENTE e disponibiliza botao na tela.
    save()
    local uiOK,uiErr=pcall(showSaveButton)
    if not uiOK then err('create button: '..tostring(uiErr)) end
    cn[#cn+1]=me:GetAttributeChangedSignal('InRound'):Connect(function()
        task.delay(0.2,function()
            if active then capture('TROCA DE ARENA') end
        end)
    end)
    cn[#cn+1]=U.InputBegan:Connect(function(input,processed)
        if input.KeyCode==Enum.KeyCode.F7 then
            task.spawn(save)
            return
        end
        if processed then return end
        if input.KeyCode==Enum.KeyCode.F6 then
            task.spawn(function()capture('F6')end)
        end
    end)
    local nextPoll=os.clock()+9
    cn[#cn+1]=Run.Heartbeat:Connect(function()
        if not active or os.clock()<nextPoll then return end
        nextPoll=os.clock()+13
        task.defer(function()
            if active then
                local ok,e=pcall(capture,'PERIODICA')
                if not ok then err('periodic capture: '..tostring(e)) end
                save()
            end
        end)
    end)
    print('[VB Replion v3.1] AUTO SAVE + BOTAO; F7 salva '..OUTPUT)
    return previous.VBReplionProbeV3
end)()
