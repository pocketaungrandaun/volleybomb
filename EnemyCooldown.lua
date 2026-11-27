-- VolleyBomb Enemy CD: client-side public event tracker.
-- Cooldowns are approximate, derived from replicated ability modules.
return function(ctx)
    local P,R,Run,W=ctx.Players,ctx.ReplicatedStorage,ctx.RunService,ctx.Workspace
    local me,C,links=ctx.LocalPlayer,ctx.Config,ctx.Links
    local make,detectMode=ctx.Make,ctx.DetectMode
    local items,values={},{}
    local rows={}
    local hud=nil
    local lastMagnet=nil
    local nextRefresh=0

    local function playing()
        local state=me:GetAttribute('InRound')
        return state=='Main' or (state==nil and detectMode()=='Main')
    end

    local function isEnemy(pl)
        if not pl or pl==me or not playing() then return false end
        if me.Team and pl.Team and not me.Neutral and not pl.Neutral
            and me.Team==pl.Team then return false end
        return true
    end

    local function moduleDuration(name)
        local found=values[name]
        if found~=nil then return found or nil end
        local shared=R:FindFirstChild('Shared')
        local modules=shared and shared:FindFirstChild('Modules')
        local folder=modules and modules:FindFirstChild('Abilities')
        local mod=folder and folder:FindFirstChild(name)
        local length=nil
        if mod and mod:IsA('ModuleScript') then
            local ok,data=pcall(require,mod)
            if ok and type(data)=='table' then
                local cd=tonumber(data.Cooldown)
                local active=tonumber(data.Duration) or 0
                if cd and cd>0 and cd<600 and active>=0 and active<120 then
                    -- Public skill modules frequently gate on Duration+Cooldown.
                    length=cd+active
                end
            end
        end
        values[name]=length or false
        return length
    end

    local function findPlayer(text)
        local query=string.lower(text)
        local match=nil
        for _,pl in ipairs(P:GetPlayers()) do
            if string.lower(pl.Name)==query then return pl end
            if string.lower(pl.DisplayName)==query then
                if match then return nil end
                match=pl
            end
        end
        return match
    end

    local function record(pl,skill)
        if not isEnemy(pl) or type(skill)~='string'
            or not skill:match('^[%w_]+$') or #skill>32 then return end
        local now=W:GetServerTimeNow()
        local id=tostring(pl.UserId)..':'..skill
        local current=items[id]
        if current and now-current.Start<1.25 then return end
        local seconds=moduleDuration(skill)
        items[id]={Player=pl,Skill=skill,Start=now,
            Ready=seconds and now+seconds or nil,
            Expire=now+(seconds or 7.5)}
        nextRefresh=0
    end

    local function notice(kind,message)
        if type(message)~='string' then return end
        if kind=='Master' and message:find('Shuffling',1,true) then
            table.clear(items)
            lastMagnet=nil
            nextRefresh=0
            return
        end
        if kind~='Sub' then return end
        local clean=message:gsub('<[^>]*>','')
        local who,skill=clean:match('^(.+) used ([%w_]+) ability$')
        if not who then return end
        local pl=findPlayer(who)
        if pl then record(pl,skill) end
    end

    local function observe(raw)
        if type(raw)~='table' or raw.Arena~='Main' then return end
        local magnet=raw.Magnet
        if typeof(magnet)=='Instance' and magnet:IsA('Player') then
            if lastMagnet~=magnet then
                lastMagnet=magnet
                record(magnet,'Magnet')
            end
        else
            lastMagnet=nil
        end
    end

    local function update()
        if ctx.IsStopped() or not hud or not hud.Parent then return end
        if not C.EnemyCD or not playing() then
            hud.Visible=false
            return
        end
        local now=W:GetServerTimeNow()
        local visible={}
        for id,item in pairs(items) do
            if now>=item.Expire or not item.Player.Parent then
                items[id]=nil
            else
                visible[#visible+1]=item
            end
        end
        table.sort(visible,function(a,b) return a.Start>b.Start end)
        local count=math.min(2,#visible)
        hud.Visible=count>0
        for i,row in ipairs(rows) do
            local skill=visible[i]
            row.Frame.Visible=skill~=nil
            if skill then
                local who=skill.Player.DisplayName
                if #who>10 then who=who:sub(1,9)..'…' end
                local name=who..' · '..skill.Skill
                local left=skill.Ready and math.max(0,skill.Ready-now)
                local time=left and ('~'..tostring(math.ceil(left))..'s') or 'CD ?'
                if row.Name.Text~=name then row.Name.Text=name end
                if row.Timer.Text~=time then row.Timer.Text=time end
            end
        end
        hud.Size=UDim2.fromOffset(210,count*26+7)
        hud.Position=UDim2.new(0,14,1,-21-count*26)
    end

    local function mount(parent)
        hud=make('Frame',{
            Name='EnemyCooldownHUD',
            Size=UDim2.fromOffset(210,59),
            Position=UDim2.new(0,14,1,-73),
            BackgroundColor3=Color3.fromRGB(23,21,29),
            BackgroundTransparency=0.52,
            BorderSizePixel=0,Visible=false,ZIndex=46
        },parent)
        make('UICorner',{CornerRadius=UDim.new(0,8)},hud)
        for i=1,2 do
            local row=make('Frame',{
                Position=UDim2.fromOffset(6,5+(i-1)*26),
                Size=UDim2.fromOffset(198,23),
                BackgroundTransparency=1,Visible=false,ZIndex=47
            },hud)
            local name=make('TextLabel',{
                Size=UDim2.fromOffset(151,23),
                BackgroundTransparency=1,
                Font=Enum.Font.GothamMedium,TextSize=11,
                TextColor3=Color3.fromRGB(224,219,233),
                TextXAlignment=Enum.TextXAlignment.Left,
                TextTruncate=Enum.TextTruncate.AtEnd,
                Text='',ZIndex=48
            },row)
            local timer=make('TextLabel',{
                Position=UDim2.fromOffset(153,0),
                Size=UDim2.fromOffset(45,23),
                BackgroundTransparency=1,
                Font=Enum.Font.GothamBold,TextSize=11,
                TextColor3=Color3.fromRGB(188,162,227),
                TextXAlignment=Enum.TextXAlignment.Right,
                Text='',ZIndex=48
            },row)
            rows[i]={Frame=row,Name=name,Timer=timer}
        end
        links[#links+1]=Run.Heartbeat:Connect(function()
            if ctx.IsStopped() or not hud or not hud.Parent
                or os.clock()<nextRefresh then return end
            nextRefresh=os.clock()+0.20
            update()
        end)
    end

    return {Mount=mount,Notice=notice,Observe=observe}
end
