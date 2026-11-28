-- VolleyBomb Enemy CD v9.48: previous-sighting ability history marked distinctly.
-- Read public announcements and available replicated ability metadata.
-- Any unconfirmed countdown is marked approximate (~) or unknown (?).
return function(ctx)
    local P,R,Run,W=ctx.Players,ctx.ReplicatedStorage,ctx.RunService,ctx.Workspace
    local me,C,links=ctx.LocalPlayer,ctx.Config,ctx.Links
    local make=ctx.Make
    local U=game:GetService('UserInputService')
    local mouse=me:GetMouse()

    local displayNames={
        adrenaline='Adrenaline',frozen='Frozen',
        superspike='Superspike',magnet='Magnet',
        curveball='Curveball',forcefield='Forcefield',
        moonball='Moonball',portal='Portal',
        shockwave='Shockwave',tornadoball='Tornado Ball',
        guardian='Guardian'
    }
    local accents={
        adrenaline=Color3.fromRGB(237,91,57),
        frozen=Color3.fromRGB(92,184,247),
        superspike=Color3.fromRGB(223,51,164),
        magnet=Color3.fromRGB(166,91,240),
        curveball=Color3.fromRGB(242,164,56),
        forcefield=Color3.fromRGB(82,178,234),
        moonball=Color3.fromRGB(150,117,214),
        portal=Color3.fromRGB(177,76,240),
        shockwave=Color3.fromRGB(245,165,47),
        tornadoball=Color3.fromRGB(71,183,158),
        guardian=Color3.fromRGB(226,184,70)
    }
    local aliases={super='superspike',superstrike='superspike',
        tornado='tornadoball',magnetic='magnet'}
    local keys={
        'EquippedAbility','SelectedAbility','CurrentAbility',
        'Ability','AbilityName','EquippedSkill','Skill','Power'
    }
    local statuses={}
    local H=game:GetService('HttpService')
    local HISTORY_FILE='VolleyBomb_EnemyCD_AbilityHistory.json'
    local MAX_AGE=14*86400
    local history={}
    -- IDs exatos: ReplicatedStorage.Data.Info.Abilities.<Skill>.Icon
    -- Obtidos nos relatorios do proprio jogo (sem imagens aproximadas).
    local icons={
        adrenaline='rbxassetid://97944922227782',
        frozen='rbxassetid://128928645067241',
        superspike='rbxassetid://79222800577374',
        magnet='rbxassetid://84541250301456',
        curveball='rbxassetid://84135124919799',
        forcefield='rbxassetid://85981316187333',
        moonball='rbxassetid://90742590592196',
        portal='rbxassetid://87889391982596',
        shockwave='rbxassetid://113239369966635',
        tornadoball='rbxassetid://117098264685504',
        guardian='rbxassetid://116764589545815'
    }
    local durationCache={}
    local ui=nil
    local abilityImage=nil
    local fallbackLetter=nil
    local playerLabel=nil
    local abilityLabel=nil
    local cdLabel=nil
    local lastMagnet=nil
    local nextUpdate=0

    local function canonical(value)
        if typeof(value)=='Instance' then value=value.Name end
        if type(value)~='string' then return nil end
        local short=string.lower(value):gsub('[^%w]','')
        local key=aliases[short] or short
        if displayNames[key] then return key end
        return nil
    end

    -- Historico local de habilidades OBSERVADAS. Nao prova o
    -- que outro jogador tem equipado na partida atual.
    local function loadHistory()
        if type(readfile)~='function' then return end
        local ok,raw=pcall(readfile,HISTORY_FILE)
        if not ok or type(raw)~='string' or #raw>180000 then return end
        local decoded,data=pcall(H.JSONDecode,H,raw)
        if not decoded or type(data)~='table' or data.Version~=1
            or type(data.Users)~='table' then return end
        local count=0
        local now=os.time()
        for id,entry in pairs(data.Users) do
            count=count+1
            if count>250 then break end
            if type(id)=='string' and id:match('^%d+
        local cached=durationCache[key]
        if cached~=nil then return cached or nil end
        local shared=R:FindFirstChild('Shared')
        local modules=shared and shared:FindFirstChild('Modules')
        local folder=modules and modules:FindFirstChild('Abilities')
        local seconds=nil
        if folder then
            for _,child in ipairs(folder:GetChildren()) do
                if child:IsA('ModuleScript') and canonical(child.Name)==key then
                    local ok,data=pcall(require,child)
                    if ok and type(data)=='table' then
                        local cd=tonumber(data.Cooldown)
                        local active=tonumber(data.Duration) or 0
                        if cd and cd>0 and cd<=300
                            and active>=0 and active<=120 then
                            seconds=cd+active
                        end
                    end
                    break
                end
            end
        end
        durationCache[key]=seconds or false
        return seconds
    end

    local function iconFor(key)
        return key and icons[key] or nil
    end

    local function abilityIn(node)
        if not node then return nil end
        for _,key in ipairs(keys) do
            local found=canonical(node:GetAttribute(key))
            if found then return found end
        end
        for _,key in ipairs(keys) do
            local obj=node:FindFirstChild(key)
            if obj and obj:IsA('ValueBase') then
                local ok,val=pcall(function() return obj.Value end)
                if ok then
                    local found=canonical(val)
                    if found then return found end
                end
            end
        end
        return nil
    end

    local function equipped(pl)
        local inPlayer=abilityIn(pl)
        if inPlayer then return inPlayer end
        local inChar=abilityIn(pl.Character)
        if inChar then return inChar end
        for _,name in ipairs({'Data','Stats','PlayerData','Loadout','Profile'}) do
            local child=pl:FindFirstChild(name)
            local found=abilityIn(child)
            if found then return found end
        end
        return nil
    end

    local function record(pl,key)
        if not pl or pl==me or not key then return end
        local now=W:GetServerTimeNow()
        local record=statuses[pl.UserId]
        if record and record.Skill==key and now-record.Used<1.0 then
            return
        end
        local seconds=modInfo(key)
        statuses[pl.UserId]={
            Player=pl,Skill=key,Used=now,
            Ready=seconds and now+seconds or nil
        }
        rememberHistory(pl,key)
    end

    local function playerNamed(text)
        text=string.lower(text)
        local match=nil
        for _,pl in ipairs(P:GetPlayers()) do
            if string.lower(pl.Name)==text then return pl end
            if string.lower(pl.DisplayName)==text then
                if match then return nil end
                match=pl
            end
        end
        return match
    end

    local function notice(kind,message)
        if type(message)~='string' then return end
        if kind=='Master' and message:find('Shuffling',1,true) then
            -- Round novo: guardamos a habilidade JA observada.
            -- O servidor pode reiniciar CDs; nao carregar timer antigo.
            for _,state in pairs(statuses) do
                state.Ready=nil
                state.RoundReset=true
            end
            lastMagnet=nil
            return
        end
        if kind~='Sub' then return end
        local clean=message:gsub('<[^>]*>','')
        local who,rawSkill=clean:match('^(.+) used (.+) ability[%.!]?$')
        if not who then
            who,rawSkill=clean:match('^(.+) activated ([%w_ ]+)[%.!]?$')
        end
        local key=canonical(rawSkill)
        if who and key then
            local pl=playerNamed(who)
            if pl then record(pl,key) end
        end
    end

    local function observe(raw)
        if type(raw)~='table' or raw.Arena~='Main' then return end
        local pl=raw.Magnet
        if typeof(pl)=='Instance' and pl:IsA('Player') then
            if lastMagnet~=pl then
                lastMagnet=pl
                record(pl,'magnet')
            end
        else
            lastMagnet=nil
        end
    end

    -- Alguns usos (inclusive passivas) geram efeitos replicados
    -- sem o texto "... used ... ability" da notificacao de rodada.
    -- So registra quando um jogador E uma habilidade conhecidos
    -- aparecem juntos no mesmo evento; nao inventa o dono.
    local function observeEffect(...)
        local who=nil
        local skill=nil
        local n=select('#',...)
        for i=1,math.min(n,6) do
            local arg=select(i,...)
            if type(arg)=='string' then
                skill=skill or canonical(arg)
            elseif typeof(arg)=='Instance' then
                if arg:IsA('Player') then
                    who=who or arg
                else
                    local node=arg
                    for _=1,8 do
                        if not node or node==W then break end
                        if node:IsA('Model') then
                            local player=P:GetPlayerFromCharacter(node)
                            if player then who=who or player break end
                        end
                        node=node.Parent
                    end
                end
            elseif type(arg)=='table' then
                for _,key in ipairs({'Ability','Skill','Name','Effect'}) do
                    skill=skill or canonical(arg[key])
                end
                local candidate=arg.Player or arg.Character
                if typeof(candidate)=='Instance' then
                    if candidate:IsA('Player') then
                        who=who or candidate
                    elseif candidate:IsA('Model') then
                        who=who or P:GetPlayerFromCharacter(candidate)
                    end
                end
            end
        end
        if who and skill then record(who,skill) end
    end

    local function hoveredPlayer()
        -- Primeiro tenta o alvo fisico (melhor para lobby).
        local node=mouse.Target
        for _=1,15 do
            if not node or node==W then break end
            if node:IsA('Model') then
                local pl=P:GetPlayerFromCharacter(node)
                if pl and pl~=me then return pl end
            end
            node=node.Parent
        end

        -- Publica/Practice: Reflectables.Part e outros planos de
        -- efeito atravessam o cursor, impedindo mouse.Target de
        -- reconhecer avatar. Projeta o corpo do jogador na tela,
        -- sem alterar CanQuery, camera, colisao ou partes do mapa.
        local camera=W.CurrentCamera
        if not camera then return nil end
        local loc=U:GetMouseLocation()
        local cursor=Vector2.new(loc.X,loc.Y)
        local best=nil
        local bestDist=math.huge
        for _,pl in ipairs(P:GetPlayers()) do
            if pl~=me and pl.Character then
                local ch=pl.Character
                local hum=ch:FindFirstChildOfClass('Humanoid')
                local root=ch:FindFirstChild('HumanoidRootPart')
                local head=ch:FindFirstChild('Head')
                if root and hum and hum.Health>0 then
                    local distance=(root.Position-camera.CFrame.Position).Magnitude
                    if distance<=220 and distance>2 then
                        local topPos=head and head.Position
                            or root.Position+Vector3.new(0,2.2,0)
                        local lower=root.Position-Vector3.new(0,2.5,0)
                        local top,inTop=camera:WorldToViewportPoint(topPos)
                        local bottom,inBottom=camera:WorldToViewportPoint(lower)
                        if inTop and inBottom and top.Z>0 and bottom.Z>0 then
                            local A=Vector2.new(top.X,top.Y)
                            local B=Vector2.new(bottom.X,bottom.Y)
                            local ab=B-A
                            local square=ab:Dot(ab)
                            local t=square>0.1
                                and math.clamp((cursor-A):Dot(ab)/square,0,1) or 0
                            local nearest=A+ab*t
                            local delta=(cursor-nearest).Magnitude
                            local halfWidth=math.clamp(12+680/distance,16,43)
                            if delta<=halfWidth and delta<bestDist then
                                bestDist=delta
                                best=pl
                            end
                        end
                    end
                end
            end
        end
        return best
    end

    local function update()
        if ctx.IsStopped() or not ui or not ui.Parent then return end
        if not C.EnemyCD then
            ui.Visible=false
            return
        end
        local pl=hoveredPlayer()
        if not pl then
            ui.Visible=false
            return
        end
        local skill=equipped(pl)
        local last=statuses[pl.UserId]
        if not skill and last and last.Player==pl then skill=last.Skill end
        local historical=false
        if not skill then
            local past=history[tostring(pl.UserId)]
            local age=past and (os.time()-past.At) or MAX_AGE+1
            if past and age>=0 and age<=MAX_AGE then
                skill=past.Skill
                historical=true
            end
        end

        local now=W:GetServerTimeNow()
        local countdown=historical and 'HIST. · CD ?' or 'CD ?'
        if historical then
            -- Historico nao tem cooldown atual confirmado.
        elseif skill and last and last.Player==pl and last.Skill==skill
            and last.Ready then
            local remaining=last.Ready-now
            countdown=remaining>0 and ('~'..math.ceil(remaining)..'s')
                or 'PRONTO*'
        elseif skill=='guardian' then
            countdown=(last and last.Player==pl and last.Skill=='guardian'
                and not last.RoundReset) and 'USADA' or '1 USO/JOGO'
        elseif skill=='shockwave' then
            countdown='CD ?'
        end

        playerLabel.Text=pl.DisplayName
        abilityLabel.Text=skill and displayNames[skill] or 'Habilidade ?'
        cdLabel.Text=countdown
        cdLabel.TextColor3=historical
            and Color3.fromRGB(181,175,193)
            or Color3.fromRGB(183,239,202)
        local asset=iconFor(skill)
        local hasIcon=asset~=nil
        abilityImage.Visible=hasIcon
        if hasIcon and abilityImage.Image~=asset then
            abilityImage.Image=asset
        end
        fallbackLetter.Visible=not hasIcon
        fallbackLetter.Text=skill and
            string.upper(displayNames[skill]:sub(1,1)) or '?'
        fallbackLetter.Parent.BackgroundColor3=
            accents[skill] or Color3.fromRGB(80,72,94)

        local camera=W.CurrentCamera
        local viewport=camera and camera.ViewportSize or Vector2.new(1280,720)
        local cursor=U:GetMouseLocation()
        local x=math.clamp(cursor.X+16,5,math.max(5,viewport.X-186))
        local y=math.clamp(cursor.Y+12,5,math.max(5,viewport.Y-70))
        ui.Position=UDim2.fromOffset(x,y)
        ui.Visible=true
    end

    local function mount(parent)
        ui=make('Frame',{
            Name='EnemyCooldownHover',
            Size=UDim2.fromOffset(182,64),
            Position=UDim2.fromOffset(0,0),
            BackgroundColor3=Color3.fromRGB(23,21,31),
            BackgroundTransparency=0.16,BorderSizePixel=0,
            Visible=false,ZIndex=48,Active=false
        },parent)
        make('UICorner',{CornerRadius=UDim.new(0,9)},ui)
        make('UIStroke',{
            Color=Color3.fromRGB(135,121,159),
            Thickness=1,Transparency=0.68
        },ui)
        local pictureFrame=make('Frame',{
            Position=UDim2.fromOffset(7,11),
            Size=UDim2.fromOffset(40,40),
            BackgroundColor3=Color3.fromRGB(80,72,94),
            BackgroundTransparency=0.08,BorderSizePixel=0,ZIndex=49
        },ui)
        make('UICorner',{CornerRadius=UDim.new(0,7)},pictureFrame)
        abilityImage=make('ImageLabel',{
            Size=UDim2.new(1,0,1,0),BackgroundTransparency=1,
            Image='',ScaleType=Enum.ScaleType.Fit,
            BorderSizePixel=0,Visible=false,ZIndex=50
        },pictureFrame)
        make('UICorner',{CornerRadius=UDim.new(0,7)},abilityImage)
        fallbackLetter=make('TextLabel',{
            Size=UDim2.new(1,0,1,0),BackgroundTransparency=1,
            Font=Enum.Font.GothamBold,TextSize=22,
            TextColor3=Color3.fromRGB(255,255,255),
            Text='?',ZIndex=50
        },pictureFrame)
        playerLabel=make('TextLabel',{
            Position=UDim2.fromOffset(54,7),
            Size=UDim2.fromOffset(118,17),BackgroundTransparency=1,
            Font=Enum.Font.GothamBold,TextSize=12,
            TextXAlignment=Enum.TextXAlignment.Left,
            TextColor3=Color3.fromRGB(246,242,253),
            TextTruncate=Enum.TextTruncate.AtEnd,Text='',ZIndex=50
        },ui)
        abilityLabel=make('TextLabel',{
            Position=UDim2.fromOffset(54,25),
            Size=UDim2.fromOffset(117,17),BackgroundTransparency=1,
            Font=Enum.Font.GothamMedium,TextSize=11,
            TextXAlignment=Enum.TextXAlignment.Left,
            TextColor3=Color3.fromRGB(207,193,234),
            TextTruncate=Enum.TextTruncate.AtEnd,Text='',ZIndex=50
        },ui)
        cdLabel=make('TextLabel',{
            Position=UDim2.fromOffset(54,43),
            Size=UDim2.fromOffset(117,15),BackgroundTransparency=1,
            Font=Enum.Font.GothamBold,TextSize=11,
            TextXAlignment=Enum.TextXAlignment.Left,
            TextColor3=Color3.fromRGB(183,239,202),
            Text='',ZIndex=50
        },ui)
        -- RE/AttachFX e RE/PassiveUsed podem revelar habilidades
        -- mesmo quando RoundNotification nao anuncia a ativacao.
        local packages=R:FindFirstChild('Packages')
        local net=packages and packages:FindFirstChild('Net')
        if net then
            for _,remoteName in ipairs({'RE/AttachFX','RE/PassiveUsed'}) do
                local remote=net:FindFirstChild(remoteName)
                if remote and remote:IsA('RemoteEvent') then
                    links[#links+1]=remote.OnClientEvent:Connect(function(...)
                        if not ctx.IsStopped() then observeEffect(...) end
                    end)
                end
            end
        end
        links[#links+1]=Run.Heartbeat:Connect(function()
            if ctx.IsStopped() or not ui or not ui.Parent
                or os.clock()<nextUpdate then return end
            nextUpdate=os.clock()+0.08
            update()
        end)
    end
    return {Mount=mount,Notice=notice,Observe=observe}
end
)
                and type(entry)=='table' then
                local name=canonical(entry.Skill)
                local ts=tonumber(entry.At)
                if name and ts and ts<=now and now-ts<=MAX_AGE then
                    history[id]={Skill=name,At=ts}
                end
            end
        end
    end
    local function saveHistory()
        if type(writefile)~='function' then return end
        local list={}
        for id,entry in pairs(history) do
            list[#list+1]={Id=id,Skill=entry.Skill,At=entry.At}
        end
        table.sort(list,function(a,b) return a.At>b.At end)
        local now=os.time()
        local out={Version=1,Users={}}
        for i,item in ipairs(list) do
            if i>200 then break end
            if item.At<=now and now-item.At<=MAX_AGE then
                out.Users[item.Id]={Skill=item.Skill,At=item.At}
            end
        end
        local ok,encoded=pcall(H.JSONEncode,H,out)
        if ok then pcall(writefile,HISTORY_FILE,encoded) end
    end
    local function rememberHistory(pl,name)
        local id=tostring(pl.UserId)
        local now=os.time()
        local prev=history[id]
        if not prev or prev.Skill~=name or now-prev.At>300 then
            history[id]={Skill=name,At=now}
            saveHistory()
        end
    end
    loadHistory()

    local function modInfo(key)
        local cached=durationCache[key]
        if cached~=nil then return cached or nil end
        local shared=R:FindFirstChild('Shared')
        local modules=shared and shared:FindFirstChild('Modules')
        local folder=modules and modules:FindFirstChild('Abilities')
        local seconds=nil
        if folder then
            for _,child in ipairs(folder:GetChildren()) do
                if child:IsA('ModuleScript') and canonical(child.Name)==key then
                    local ok,data=pcall(require,child)
                    if ok and type(data)=='table' then
                        local cd=tonumber(data.Cooldown)
                        local active=tonumber(data.Duration) or 0
                        if cd and cd>0 and cd<=300
                            and active>=0 and active<=120 then
                            seconds=cd+active
                        end
                    end
                    break
                end
            end
        end
        durationCache[key]=seconds or false
        return seconds
    end

    local function iconFor(key)
        return key and icons[key] or nil
    end

    local function abilityIn(node)
        if not node then return nil end
        for _,key in ipairs(keys) do
            local found=canonical(node:GetAttribute(key))
            if found then return found end
        end
        for _,key in ipairs(keys) do
            local obj=node:FindFirstChild(key)
            if obj and obj:IsA('ValueBase') then
                local ok,val=pcall(function() return obj.Value end)
                if ok then
                    local found=canonical(val)
                    if found then return found end
                end
            end
        end
        return nil
    end

    local function equipped(pl)
        local inPlayer=abilityIn(pl)
        if inPlayer then return inPlayer end
        local inChar=abilityIn(pl.Character)
        if inChar then return inChar end
        for _,name in ipairs({'Data','Stats','PlayerData','Loadout','Profile'}) do
            local child=pl:FindFirstChild(name)
            local found=abilityIn(child)
            if found then return found end
        end
        return nil
    end

    local function record(pl,key)
        if not pl or pl==me or not key then return end
        local now=W:GetServerTimeNow()
        local record=statuses[pl.UserId]
        if record and record.Skill==key and now-record.Used<1.0 then
            return
        end
        local seconds=modInfo(key)
        statuses[pl.UserId]={
            Player=pl,Skill=key,Used=now,
            Ready=seconds and now+seconds or nil
        }
    end

    local function playerNamed(text)
        text=string.lower(text)
        local match=nil
        for _,pl in ipairs(P:GetPlayers()) do
            if string.lower(pl.Name)==text then return pl end
            if string.lower(pl.DisplayName)==text then
                if match then return nil end
                match=pl
            end
        end
        return match
    end

    local function notice(kind,message)
        if type(message)~='string' then return end
        if kind=='Master' and message:find('Shuffling',1,true) then
            -- Round novo: guardamos a habilidade JA observada.
            -- O servidor pode reiniciar CDs; nao carregar timer antigo.
            for _,state in pairs(statuses) do
                state.Ready=nil
                state.RoundReset=true
            end
            lastMagnet=nil
            return
        end
        if kind~='Sub' then return end
        local clean=message:gsub('<[^>]*>','')
        local who,rawSkill=clean:match('^(.+) used (.+) ability[%.!]?$')
        if not who then
            who,rawSkill=clean:match('^(.+) activated ([%w_ ]+)[%.!]?$')
        end
        local key=canonical(rawSkill)
        if who and key then
            local pl=playerNamed(who)
            if pl then record(pl,key) end
        end
    end

    local function observe(raw)
        if type(raw)~='table' or raw.Arena~='Main' then return end
        local pl=raw.Magnet
        if typeof(pl)=='Instance' and pl:IsA('Player') then
            if lastMagnet~=pl then
                lastMagnet=pl
                record(pl,'magnet')
            end
        else
            lastMagnet=nil
        end
    end

    -- Alguns usos (inclusive passivas) geram efeitos replicados
    -- sem o texto "... used ... ability" da notificacao de rodada.
    -- So registra quando um jogador E uma habilidade conhecidos
    -- aparecem juntos no mesmo evento; nao inventa o dono.
    local function observeEffect(...)
        local who=nil
        local skill=nil
        local n=select('#',...)
        for i=1,math.min(n,6) do
            local arg=select(i,...)
            if type(arg)=='string' then
                skill=skill or canonical(arg)
            elseif typeof(arg)=='Instance' then
                if arg:IsA('Player') then
                    who=who or arg
                else
                    local node=arg
                    for _=1,8 do
                        if not node or node==W then break end
                        if node:IsA('Model') then
                            local player=P:GetPlayerFromCharacter(node)
                            if player then who=who or player break end
                        end
                        node=node.Parent
                    end
                end
            elseif type(arg)=='table' then
                for _,key in ipairs({'Ability','Skill','Name','Effect'}) do
                    skill=skill or canonical(arg[key])
                end
                local candidate=arg.Player or arg.Character
                if typeof(candidate)=='Instance' then
                    if candidate:IsA('Player') then
                        who=who or candidate
                    elseif candidate:IsA('Model') then
                        who=who or P:GetPlayerFromCharacter(candidate)
                    end
                end
            end
        end
        if who and skill then record(who,skill) end
    end

    local function hoveredPlayer()
        -- Primeiro tenta o alvo fisico (melhor para lobby).
        local node=mouse.Target
        for _=1,15 do
            if not node or node==W then break end
            if node:IsA('Model') then
                local pl=P:GetPlayerFromCharacter(node)
                if pl and pl~=me then return pl end
            end
            node=node.Parent
        end

        -- Publica/Practice: Reflectables.Part e outros planos de
        -- efeito atravessam o cursor, impedindo mouse.Target de
        -- reconhecer avatar. Projeta o corpo do jogador na tela,
        -- sem alterar CanQuery, camera, colisao ou partes do mapa.
        local camera=W.CurrentCamera
        if not camera then return nil end
        local loc=U:GetMouseLocation()
        local cursor=Vector2.new(loc.X,loc.Y)
        local best=nil
        local bestDist=math.huge
        for _,pl in ipairs(P:GetPlayers()) do
            if pl~=me and pl.Character then
                local ch=pl.Character
                local hum=ch:FindFirstChildOfClass('Humanoid')
                local root=ch:FindFirstChild('HumanoidRootPart')
                local head=ch:FindFirstChild('Head')
                if root and hum and hum.Health>0 then
                    local distance=(root.Position-camera.CFrame.Position).Magnitude
                    if distance<=220 and distance>2 then
                        local topPos=head and head.Position
                            or root.Position+Vector3.new(0,2.2,0)
                        local lower=root.Position-Vector3.new(0,2.5,0)
                        local top,inTop=camera:WorldToViewportPoint(topPos)
                        local bottom,inBottom=camera:WorldToViewportPoint(lower)
                        if inTop and inBottom and top.Z>0 and bottom.Z>0 then
                            local A=Vector2.new(top.X,top.Y)
                            local B=Vector2.new(bottom.X,bottom.Y)
                            local ab=B-A
                            local square=ab:Dot(ab)
                            local t=square>0.1
                                and math.clamp((cursor-A):Dot(ab)/square,0,1) or 0
                            local nearest=A+ab*t
                            local delta=(cursor-nearest).Magnitude
                            local halfWidth=math.clamp(12+680/distance,16,43)
                            if delta<=halfWidth and delta<bestDist then
                                bestDist=delta
                                best=pl
                            end
                        end
                    end
                end
            end
        end
        return best
    end

    local function update()
        if ctx.IsStopped() or not ui or not ui.Parent then return end
        if not C.EnemyCD then
            ui.Visible=false
            return
        end
        local pl=hoveredPlayer()
        if not pl then
            ui.Visible=false
            return
        end
        local skill=equipped(pl)
        local last=statuses[pl.UserId]
        if not skill and last and last.Player==pl then skill=last.Skill end

        local now=W:GetServerTimeNow()
        local countdown='CD ?'
        if skill and last and last.Player==pl and last.Skill==skill
            and last.Ready then
            local remaining=last.Ready-now
            countdown=remaining>0 and ('~'..math.ceil(remaining)..'s')
                or 'PRONTO*'
        elseif skill=='guardian' then
            countdown=(last and last.Player==pl and last.Skill=='guardian'
                and not last.RoundReset) and 'USADA' or '1 USO/JOGO'
        elseif skill=='shockwave' then
            countdown='CD ?'
        end

        playerLabel.Text=pl.DisplayName
        abilityLabel.Text=skill and displayNames[skill] or 'Habilidade ?'
        cdLabel.Text=countdown
        local asset=iconFor(skill)
        local hasIcon=asset~=nil
        abilityImage.Visible=hasIcon
        if hasIcon and abilityImage.Image~=asset then
            abilityImage.Image=asset
        end
        fallbackLetter.Visible=not hasIcon
        fallbackLetter.Text=skill and
            string.upper(displayNames[skill]:sub(1,1)) or '?'
        fallbackLetter.Parent.BackgroundColor3=
            accents[skill] or Color3.fromRGB(80,72,94)

        local camera=W.CurrentCamera
        local viewport=camera and camera.ViewportSize or Vector2.new(1280,720)
        local cursor=U:GetMouseLocation()
        local x=math.clamp(cursor.X+16,5,math.max(5,viewport.X-186))
        local y=math.clamp(cursor.Y+12,5,math.max(5,viewport.Y-70))
        ui.Position=UDim2.fromOffset(x,y)
        ui.Visible=true
    end

    local function mount(parent)
        ui=make('Frame',{
            Name='EnemyCooldownHover',
            Size=UDim2.fromOffset(182,64),
            Position=UDim2.fromOffset(0,0),
            BackgroundColor3=Color3.fromRGB(23,21,31),
            BackgroundTransparency=0.16,BorderSizePixel=0,
            Visible=false,ZIndex=48,Active=false
        },parent)
        make('UICorner',{CornerRadius=UDim.new(0,9)},ui)
        make('UIStroke',{
            Color=Color3.fromRGB(135,121,159),
            Thickness=1,Transparency=0.68
        },ui)
        local pictureFrame=make('Frame',{
            Position=UDim2.fromOffset(7,11),
            Size=UDim2.fromOffset(40,40),
            BackgroundColor3=Color3.fromRGB(80,72,94),
            BackgroundTransparency=0.08,BorderSizePixel=0,ZIndex=49
        },ui)
        make('UICorner',{CornerRadius=UDim.new(0,7)},pictureFrame)
        abilityImage=make('ImageLabel',{
            Size=UDim2.new(1,0,1,0),BackgroundTransparency=1,
            Image='',ScaleType=Enum.ScaleType.Fit,
            BorderSizePixel=0,Visible=false,ZIndex=50
        },pictureFrame)
        make('UICorner',{CornerRadius=UDim.new(0,7)},abilityImage)
        fallbackLetter=make('TextLabel',{
            Size=UDim2.new(1,0,1,0),BackgroundTransparency=1,
            Font=Enum.Font.GothamBold,TextSize=22,
            TextColor3=Color3.fromRGB(255,255,255),
            Text='?',ZIndex=50
        },pictureFrame)
        playerLabel=make('TextLabel',{
            Position=UDim2.fromOffset(54,7),
            Size=UDim2.fromOffset(118,17),BackgroundTransparency=1,
            Font=Enum.Font.GothamBold,TextSize=12,
            TextXAlignment=Enum.TextXAlignment.Left,
            TextColor3=Color3.fromRGB(246,242,253),
            TextTruncate=Enum.TextTruncate.AtEnd,Text='',ZIndex=50
        },ui)
        abilityLabel=make('TextLabel',{
            Position=UDim2.fromOffset(54,25),
            Size=UDim2.fromOffset(117,17),BackgroundTransparency=1,
            Font=Enum.Font.GothamMedium,TextSize=11,
            TextXAlignment=Enum.TextXAlignment.Left,
            TextColor3=Color3.fromRGB(207,193,234),
            TextTruncate=Enum.TextTruncate.AtEnd,Text='',ZIndex=50
        },ui)
        cdLabel=make('TextLabel',{
            Position=UDim2.fromOffset(54,43),
            Size=UDim2.fromOffset(117,15),BackgroundTransparency=1,
            Font=Enum.Font.GothamBold,TextSize=11,
            TextXAlignment=Enum.TextXAlignment.Left,
            TextColor3=Color3.fromRGB(183,239,202),
            Text='',ZIndex=50
        },ui)
        -- RE/AttachFX e RE/PassiveUsed podem revelar habilidades
        -- mesmo quando RoundNotification nao anuncia a ativacao.
        local packages=R:FindFirstChild('Packages')
        local net=packages and packages:FindFirstChild('Net')
        if net then
            for _,remoteName in ipairs({'RE/AttachFX','RE/PassiveUsed'}) do
                local remote=net:FindFirstChild(remoteName)
                if remote and remote:IsA('RemoteEvent') then
                    links[#links+1]=remote.OnClientEvent:Connect(function(...)
                        if not ctx.IsStopped() then observeEffect(...) end
                    end)
                end
            end
        end
        links[#links+1]=Run.Heartbeat:Connect(function()
            if ctx.IsStopped() or not ui or not ui.Parent
                or os.clock()<nextUpdate then return end
            nextUpdate=os.clock()+0.08
            update()
        end)
    end
    return {Mount=mount,Notice=notice,Observe=observe}
end
