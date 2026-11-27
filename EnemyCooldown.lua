-- VolleyBomb Enemy CD v9.46: show only while hovering another character.
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
    local imageCache={}
    local durationCache={}
    local ui=nil
    local abilityImage=nil
    local fallbackLetter=nil
    local playerLabel=nil
    local abilityLabel=nil
    local cdLabel=nil
    local lastMagnet=nil
    local nextUpdate=0
    local nextImageScan=0

    local function canonical(value)
        if typeof(value)=='Instance' then value=value.Name end
        if type(value)~='string' then return nil end
        local short=string.lower(value):gsub('[^%w]','')
        local key=aliases[short] or short
        if displayNames[key] then return key end
        return nil
    end

    local function modInfo(key)
        if durationCache[key] then
            return durationCache[key].Duration,durationCache[key].Image
        end
        local shared=R:FindFirstChild('Shared')
        local modules=shared and shared:FindFirstChild('Modules')
        local folder=modules and modules:FindFirstChild('Abilities')
        local mod=nil
        if folder then
            for _,child in ipairs(folder:GetChildren()) do
                if child:IsA('ModuleScript') and canonical(child.Name)==key then
                    mod=child
                    break
                end
            end
        end
        local info={Duration=nil,Image=nil}
        if mod then
            local ok,data=pcall(require,mod)
            if ok and type(data)=='table' then
                local cd=tonumber(data.Cooldown)
                local duration=tonumber(data.Duration) or 0
                if cd and cd>0 and cd<=300
                    and duration>=0 and duration<=60 then
                    -- The visible game may use a different server rule.
                    info.Duration=cd+duration
                end
                for _,field in ipairs({
                    'Icon','IconId','Image','ImageId','Texture','TextureId'
                }) do
                    local candidate=data[field]
                    if type(candidate)=='number' and candidate>0 then
                        info.Image='rbxassetid://'..tostring(candidate)
                        break
                    elseif type(candidate)=='string' and candidate~='' then
                        if candidate:match('^rbxassetid://%d+$')
                            or candidate:match('^rbxasset://') then
                            info.Image=candidate
                            break
                        elseif candidate:match('^%d+$') then
                            info.Image='rbxassetid://'..candidate
                            break
                        end
                    end
                end
            end
        end
        durationCache[key]=info
        return info.Duration,info.Image
    end

    local function iconFromShop(key)
        local gui=me:FindFirstChildOfClass('PlayerGui')
        if not gui then return nil end
        -- Game UI images use Roblox assets; they can be reused as-is.
        -- The screenshot is a reference, not an uploaded Roblox decal.
        local nodes=gui:GetDescendants()
        local best=nil
        for _,node in ipairs(nodes) do
            if (node:IsA('ImageLabel') or node:IsA('ImageButton'))
                and node.Image~='' then
                local match=nil
                local parent=node
                for _=1,3 do
                    if not parent or parent==gui then break end
                    if canonical(parent.Name)==key then match=true break end
                    parent=parent.Parent
                end
                if match then
                    best=node.Image
                    break
                end
            end
        end
        if best then return best end
        -- If the shop names cards generically, find an exact skill
        -- label and its neighboring ImageLabel.
        for _,node in ipairs(nodes) do
            if (node:IsA('TextLabel') or node:IsA('TextButton'))
                and canonical(node.Text)==key then
                local parent=node.Parent
                for _=1,2 do
                    if not parent or parent==gui then break end
                    for _,child in ipairs(parent:GetChildren()) do
                        if (child:IsA('ImageLabel') or child:IsA('ImageButton'))
                            and child.Image~='' then
                            return child.Image
                        end
                        if child:IsA('Frame') then
                            for _,icon in ipairs(child:GetChildren()) do
                                if (icon:IsA('ImageLabel')
                                    or icon:IsA('ImageButton'))
                                    and icon.Image~='' then
                                    return icon.Image
                                end
                            end
                        end
                    end
                    parent=parent.Parent
                end
            end
        end
        return nil
    end

    local function iconFor(key)
        if not key then return nil end
        if imageCache[key] then return imageCache[key] end
        local _,moduleImage=modInfo(key)
        if moduleImage then
            imageCache[key]=moduleImage
            return moduleImage
        end
        if os.clock()>=nextImageScan then
            nextImageScan=os.clock()+2.5
            local shopImage=iconFromShop(key)
            if shopImage then
                imageCache[key]=shopImage
                return shopImage
            end
        end
        return nil
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
            table.clear(statuses)
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

    local function hoveredPlayer()
        local hit=mouse.Target
        if not hit or not hit.Parent then return nil end
        local node=hit
        for _=1,15 do
            if not node or node==W then return nil end
            if node:IsA('Model') and node:FindFirstChildOfClass('Humanoid') then
                local pl=P:GetPlayerFromCharacter(node)
                if pl and pl~=me then return pl end
            end
            node=node.Parent
        end
        return nil
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
                or 'PRONTO'
        elseif skill=='guardian' or skill=='shockwave' then
            countdown='PASSIVA'
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
        links[#links+1]=Run.Heartbeat:Connect(function()
            if ctx.IsStopped() or not ui or not ui.Parent
                or os.clock()<nextUpdate then return end
            nextUpdate=os.clock()+0.08
            update()
        end)
    end
    return {Mount=mount,Notice=notice,Observe=observe}
end
