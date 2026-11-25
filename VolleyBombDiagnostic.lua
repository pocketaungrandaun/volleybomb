-- VolleyBomb Diagnostic v1.0
-- Independent telemetry collector. It does not change ball physics, UI, or game state.
-- F7: save a full report to VolleyBomb_Diagnostic.json
-- F6: save and stop. Also auto-saves after 120 seconds.
-- All information stays local. No HTTP uploads or external destinations.

local Players=game:GetService("Players")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local Workspace=game:GetService("Workspace")
local RunService=game:GetService("RunService")
local UserInputService=game:GetService("UserInputService")
local HttpService=game:GetService("HttpService")
local StarterGui=game:GetService("StarterGui")
local LocalPlayer=Players.LocalPlayer
local env=_G
if type(getgenv)=="function" then
    local ok,value=pcall(getgenv)
    if ok and type(value)=="table" then env=value end
end
if type(env.VolleyBombDiagnostic)=="table" and type(env.VolleyBombDiagnostic.Stop)=="function" then
    pcall(env.VolleyBombDiagnostic.Stop,false)
end

local FILE="VolleyBomb_Diagnostic.json"
local LIMITS={
    records=3200, ballSamples=4600, performance=300,
    collisions=650, metadata=1400, modules=650,
    sourceSnippets=10, snippetBytes=22000
}
local start=os.clock()
local live=true
local conns={}
local counters={}
local tracked={}
local lastBall={}
local ready=false
local result={
    format="VolleyBombDiagnostic/1.0",
    note="Client-accessible data only. No server-side source or hidden server state.",
    startedAt=os.date("!%Y-%m-%dT%H:%M:%SZ"),
    environment={
        placeId=game.PlaceId,universeId=game.GameId,
        workspaceGravity=Workspace.Gravity,
        samplesPerSecond=20,
        note="Player names and chat messages are not intentionally collected"
    },
    capabilities={},
    discovered={objects={},modules={},remotes={},loadedModules={},scriptSources={}},
    remoteCounts={},
    packets={},
    ballSamples={},
    collisions={},
    performance={},
    snapshots={},
    notes={},
    limits=LIMITS
}
local function clock()
    return math.floor((os.clock()-start)*1000+0.5)/1000
end
local function serverTime()
    local ok,v=pcall(function() return Workspace:GetServerTimeNow() end)
    return ok and v or nil
end
local function safeName(obj)
    if typeof(obj)~="Instance" then return tostring(obj) end
    local ok,p=pcall(function() return obj:GetFullName() end)
    return ok and p or (obj.ClassName..":"..obj.Name)
end
local function add(where,entry,maxCount)
    if #where<maxCount then
        where[#where+1]=entry
        return true
    end
    return false
end
local function number(v)
    if type(v)~="number" or v~=v or v==math.huge or v==-math.huge then return nil end
    return math.floor(v*1000+0.5)/1000
end
local function vec(v)
    if typeof(v)=="Vector2" then return {number(v.X),number(v.Y)} end
    return {number(v.X),number(v.Y),number(v.Z)}
end
local function clean(value,depth,budget,seen)
    budget=budget or {n=0}
    seen=seen or {}
    if budget.n>350 then return "[truncated: size limit]" end
    budget.n=budget.n+1
    depth=depth or 0
    if depth>5 then return "[truncated: depth limit]" end
    local kind=typeof(value)
    if value==nil then return nil end
    if kind=="number" then return number(value) end
    if kind=="string" then
        return #value>900 and value:sub(1,900).." [truncated]" or value
    end
    if kind=="boolean" then return value end
    if kind=="Vector3" or kind=="Vector2" then return vec(value) end
    if kind=="CFrame" then return {pos=vec(value.Position),look=vec(value.LookVector)} end
    if kind=="Color3" then return {r=number(value.R),g=number(value.G),b=number(value.B)} end
    if kind=="EnumItem" then return tostring(value) end
    if kind=="Instance" then return {ref=safeName(value),class=value.ClassName} end
    if kind=="UDim2" or kind=="NumberRange" or kind=="PhysicalProperties" then
        return tostring(value)
    end
    if kind=="table" then
        if seen[value] then return "[circular]" end
        seen[value]=true
        local resultTable={}
        local count=0
        for k,v in pairs(value) do
            count=count+1
            if count>85 then
                resultTable.__truncated=true
                break
            end
            local key=(type(k)=="string" or type(k)=="number") and tostring(k) or tostring(typeof(k))
            resultTable[key]=clean(v,depth+1,budget,seen)
        end
        seen[value]=nil
        return resultTable
    end
    return tostring(kind)
end
local function try(object,prop)
    local ok,value=pcall(function() return object[prop] end)
    return ok and value or nil
end
local function propertyData(instance)
    local obj={
        path=safeName(instance),class=instance.ClassName,name=instance.Name,
        attributes=clean(instance:GetAttributes())
    }
    if instance:IsA("BasePart") then
        obj.position=vec(instance.Position)
        obj.size=vec(instance.Size)
        obj.orientation=vec(instance.Orientation)
        obj.anchored=instance.Anchored
        obj.canCollide=instance.CanCollide
        obj.canTouch=instance.CanTouch
        obj.canQuery=instance.CanQuery
        obj.material=tostring(instance.Material)
        obj.collisionGroup=instance.CollisionGroup
        obj.transparency=number(instance.Transparency)
        local phys=instance.CustomPhysicalProperties
        if phys then
            obj.physicalProperties={
                density=number(phys.Density),friction=number(phys.Friction),
                elasticity=number(phys.Elasticity),
                frictionWeight=number(phys.FrictionWeight),
                elasticityWeight=number(phys.ElasticityWeight)
            }
        end
    elseif instance:IsA("ValueBase") then
        obj.value=clean(try(instance,"Value"))
    elseif instance:IsA("RemoteEvent") or instance:IsA("RemoteFunction") then
        obj.remote=true
    end
    return obj
end
local function notification(msg)
    print("[VolleyBomb Diagnostic] "..msg)
    pcall(function()
        StarterGui:SetCore("SendNotification",{
            Title="VolleyBomb Diagnostic",Text=msg,Duration=6
        })
    end)
end
local function attach(signal,callback)
    local ok,c=pcall(function() return signal:Connect(callback) end)
    if ok and c then conns[#conns+1]=c end
    return ok
end

local function snapshot(reason)
    if #result.snapshots>=30 then return end
    local snap={
        at=clock(),reason=reason,serverTime=serverTime(),
        gravity=number(Workspace.Gravity),balls={},
        visiblePlayers=0
    }
    for _,player in ipairs(Players:GetPlayers()) do
        local char=player.Character
        local root=char and char:FindFirstChild("HumanoidRootPart")
        if root then snap.visiblePlayers=snap.visiblePlayers+1 end
    end
    for _,name in ipairs({"Bowling Ball","Default"}) do
        local ball=Workspace:FindFirstChild(name)
        if ball and ball:IsA("BasePart") then
            snap.balls[name]=propertyData(ball)
            snap.balls[name].velocity=vec(ball.AssemblyLinearVelocity)
            snap.balls[name].angularVelocity=vec(ball.AssemblyAngularVelocity)
        end
    end
    result.snapshots[#result.snapshots+1]=snap
end

local packetKeys={
    "Arena","Time","EndTime","Origin","Velocity","Gravity",
    "Normal","Bounced","Zones","Multipliers","Target",
    "IgnoreWalls","Tornado","Magnet","Collision"
}
local function forecast(packet)
    if type(packet)~="table" then return nil end
    local o,v,g=packet.Origin,packet.Velocity,packet.Gravity
    local t,e=packet.Time,packet.EndTime
    if typeof(o)~="Vector3" or typeof(v)~="Vector3"
        or typeof(g)~="Vector3" or type(t)~="number"
        or type(e)~="number" then return nil end
    local dt=e-t
    if dt<0 or dt>20 then return nil end
    local predicted=o+v*dt+g*(dt*dt*0.5)
    local hitNormal=packet.Normal
    return {
        dt=number(dt),point=vec(predicted),
        surfaceNormal=typeof(hitNormal)=="Vector3" and vec(hitNormal) or nil,
        surface=typeof(hitNormal)=="Vector3" and
            (hitNormal.Y>0.88 and "floor"
                or (hitNormal.Y< -0.72 and "ceiling" or "wall")) or "unknown",
        bounced=clean(packet.Bounced)
    }
end

local function addPacket(name,...)
    counters[name]=(counters[name] or 0)+1
    result.remoteCounts[name]=counters[name]
    if #result.packets>=LIMITS.records then return end
    local args={...}
    local entry={at=clock(),serverTime=serverTime(),event=name,
        argc=select("#",...),args={}}
    for i=1,math.min(select("#",...),6) do
        entry.args[i]=clean(args[i])
    end
    local raw=args[1]
    if type(raw)=="table" and string.find(string.lower(name),"ballstate",1,true) then
        entry.ballForecast=forecast(raw)
        entry.ballFields={}
        for _,k in ipairs(packetKeys) do
            entry.ballFields[k]=clean(raw[k])
        end
    end
    add(result.packets,entry,LIMITS.records)
end

local function relevantPath(path)
    local p=string.lower(path)
    return p:find("ball",1,true)~=nil
        or p:find("court",1,true)~=nil
        or p:find("arena",1,true)~=nil
        or p:find("volley",1,true)~=nil
        or p:find("physics",1,true)~=nil
        or p:find("trajectory",1,true)~=nil
        or p:find("bounce",1,true)~=nil
        or p:find("collision",1,true)~=nil
        or p:find("serve",1,true)~=nil
        or p:find("match",1,true)~=nil
        or p:find("zone",1,true)~=nil
        or p:find("gravity",1,true)~=nil
        or p:find("projectile",1,true)~=nil
end
local function scanTree(root,tag)
    local ok,desc=pcall(function() return root:GetDescendants() end)
    if not ok then return end
    local count=0
    for _,obj in ipairs(desc) do
        count=count+1
        if count>16000 then break end
        local path=safeName(obj)
        if obj:IsA("ModuleScript") then
            add(result.discovered.modules,{
                path=path,tag=tag,candidate=relevantPath(path),
                attributes=clean(obj:GetAttributes())
            },LIMITS.modules)
        elseif obj:IsA("RemoteEvent") or obj:IsA("RemoteFunction") then
            add(result.discovered.remotes,{
                path=path,tag=tag,class=obj.ClassName
            },LIMITS.metadata)
        elseif relevantPath(path) and (obj:IsA("BasePart") or
            obj:IsA("ValueBase") or obj:IsA("Folder") or
            obj:IsA("Configuration") or obj:IsA("Model")) then
            add(result.discovered.objects,propertyData(obj),LIMITS.metadata)
        end
    end
    result.notes[#result.notes+1]={
        stage="scan",where=tag,inspected=count,
        truncated=count>16000,at=clock()
    }
end

-- We only inspect code from executors that explicitly expose decompile().
-- Never require unknown modules: requiring them could run unintended code.
local function scanModuleCode()
    local found=0
    result.capabilities.decompile=type(decompile)=="function"
    result.capabilities.getloadedmodules=type(getloadedmodules)=="function"
    if type(getloadedmodules)=="function" then
        local ok,loaded=pcall(getloadedmodules)
        if ok and type(loaded)=="table" then
            for _,m in ipairs(loaded) do
                if typeof(m)=="Instance" and m:IsA("ModuleScript") then
                    add(result.discovered.loadedModules,
                        safeName(m),LIMITS.modules)
                end
            end
        end
    end
    if type(decompile)~="function" then return end
    local candidates={}
    local ok,desc=pcall(function() return ReplicatedStorage:GetDescendants() end)
    if ok then
        for _,obj in ipairs(desc) do
            if obj:IsA("ModuleScript") and relevantPath(safeName(obj)) then
                candidates[#candidates+1]=obj
            end
        end
    end
    table.sort(candidates,function(a,b)
        local function weight(o)
            local n=string.lower(o.Name)
            if n:find("ball",1,true) then return 1 end
            if n:find("physics",1,true) or n:find("trajectory",1,true) then return 2 end
            if n:find("bounce",1,true) or n:find("collision",1,true) then return 3 end
            return 4
        end
        return weight(a)<weight(b)
    end)
    for i=1,math.min(#candidates,LIMITS.sourceSnippets) do
        if not live then return end
        local module=candidates[i]
        local good,code=pcall(decompile,module)
        if good and type(code)=="string" then
            found=found+1
            result.discovered.scriptSources[#result.discovered.scriptSources+1]={
                path=safeName(module),source=code:sub(1,LIMITS.snippetBytes),
                truncated=#code>LIMITS.snippetBytes
            }
        end
        task.wait()
    end
    result.notes[#result.notes+1]={stage="decompile",success=found,
        considered=math.min(#candidates,LIMITS.sourceSnippets)}
end

local function scanNetworking()
    local packages=ReplicatedStorage:FindFirstChild("Packages")
        or ReplicatedStorage:WaitForChild("Packages",12)
    local net=packages and (packages:FindFirstChild("Net")
        or packages:WaitForChild("Net",12))
    if not net then
        result.notes[#result.notes+1]={stage="network",error="Packages/Net not found"}
        return
    end
    local count=0
    for _,obj in ipairs(net:GetDescendants()) do
        if obj:IsA("RemoteEvent") and count<170 then
            local low=string.lower(obj.Name)
            -- Exclude chat, typing, messaging and telemetry.
            if not low:find("chat",1,true) and
                not low:find("message",1,true) and
                not low:find("typing",1,true) and
                not low:find("analytics",1,true) then
                count=count+1
                local name=safeName(obj)
                attach(obj.OnClientEvent,function(...)
                    if live then addPacket(name,...) end
                end)
            end
        end
    end
    result.notes[#result.notes+1]={stage="network",remoteListeners=count}
end

local function collisionTrace(name,ball,old,nowPos)
    if not old then return end
    local movement=nowPos-old.p
    local dt=os.clock()-old.t
    if dt<=0.005 or movement.Magnitude<0.2 or movement.Magnitude>220 then return end
    local rayparams=RaycastParams.new()
    rayparams.FilterType=Enum.RaycastFilterType.Exclude
    local exclude={ball}
    for _,p in ipairs(Players:GetPlayers()) do
        if p.Character then exclude[#exclude+1]=p.Character end
    end
    local markerFolder=Workspace:FindFirstChild("VolleyLanding85")
    if markerFolder then exclude[#exclude+1]=markerFolder end
    rayparams.FilterDescendantsInstances=exclude
    rayparams.RespectCanCollide=true
    rayparams.IgnoreWater=true
    local hit
    local ok=pcall(function()
        hit=Workspace:Spherecast(old.p,
            math.max(0.3,math.min(ball.Size.X,ball.Size.Y,ball.Size.Z)*0.42),
            movement,rayparams)
    end)
    if not ok or not hit then return end
    add(result.collisions,{
        at=clock(),ball=name,kind="swept_hit",
        hit=propertyData(hit.Instance),position=vec(hit.Position),
        normal=vec(hit.Normal),distance=number(hit.Distance),
        dt=number(dt),start=vec(old.p),finish=vec(nowPos)
    },LIMITS.collisions)
end
local function sampleBall(name)
    local ball=Workspace:FindFirstChild(name)
    if not ball or not ball:IsA("BasePart") then
        lastBall[name]=nil
        return
    end
    local p=ball.Position
    local v=ball.AssemblyLinearVelocity
    local t=os.clock()
    local prev=lastBall[name]
    if prev and (p-prev.p).Magnitude>10 and
        (t-prev.t)<0.25 then
        add(result.collisions,{
            at=clock(),ball=name,kind="fast_displacement",
            distance=number((p-prev.p).Magnitude),
            from=vec(prev.p),to=vec(p),elapsed=number(t-prev.t)
        },LIMITS.collisions)
    end
    if prev and prev.v.Magnitude>4 and v.Magnitude>4 and
        (v-prev.v).Magnitude>14 then
        add(result.collisions,{
            at=clock(),ball=name,kind="velocity_change",
            from=vec(prev.v),to=vec(v),
            diff=number((v-prev.v).Magnitude),
            position=vec(p)
        },LIMITS.collisions)
    end
    if prev then collisionTrace(name,ball,prev,p) end
    add(result.ballSamples,{
        at=clock(),serverTime=serverTime(),ball=name,
        position=vec(p),velocity=vec(v),
        angularVelocity=vec(ball.AssemblyAngularVelocity),
        anchored=ball.Anchored,canCollide=ball.CanCollide,
        approxMeasuredVelocity=prev and
            ((t-prev.t)>0.002 and
                vec((p-prev.p)/(t-prev.t)) or nil) or nil
    },LIMITS.ballSamples)
    lastBall[name]={p=p,v=v,t=t}
end

local frames=0
local accumulatedDt=0
local maxDt=0
local lastSample=0
local lastPerf=0
local lastSnap=0

local function save()
    result.generatedAt=os.date("!%Y-%m-%dT%H:%M:%SZ")
    result.elapsed=clock()
    result.counts={
        packets=#result.packets,ballSamples=#result.ballSamples,
        collisions=#result.collisions,performance=#result.performance,
        objects=#result.discovered.objects,
        modules=#result.discovered.modules,
        remotes=#result.discovered.remotes,
        scriptSources=#result.discovered.scriptSources
    }
    local ok,json=pcall(function() return HttpService:JSONEncode(result) end)
    if not ok then
        notification("Falha ao preparar JSON: "..tostring(json))
        return false
    end
    if type(writefile)=="function" then
        local success,err=pcall(writefile,FILE,json)
        if success then
            notification("Salvo: "..FILE.." ("..tostring(#json).." bytes)")
            return true
        end
        result.notes[#result.notes+1]={stage="save",error=tostring(err)}
    end
    if type(setclipboard)=="function" then
        local success=pcall(setclipboard,json)
        if success then
            notification("Sem arquivo: dados copiados para a area de transferencia")
            return true
        end
    end
    notification("Executor sem writefile ou setclipboard. Nao foi possivel salvar.")
    return false
end
local function stop(doSave)
    if not live then return end
    if doSave~=false then save() end
    live=false
    for _,conn in ipairs(conns) do pcall(function() conn:Disconnect() end) end
    table.clear(conns)
    if env.VolleyBombDiagnostic and env.VolleyBombDiagnostic.Stop==stop then
        env.VolleyBombDiagnostic=nil
    end
    notification("Coleta encerrada.")
end
env.VolleyBombDiagnostic={Save=save,Stop=stop,Data=result}

attach(UserInputService.InputBegan,function(input)
    if not live then return end
    if input.KeyCode==Enum.KeyCode.F7 then
        save()
    elseif input.KeyCode==Enum.KeyCode.F6 then
        stop(true)
    end
end)

attach(RunService.Heartbeat,function(dt)
    if not live then return end
    frames=frames+1
    accumulatedDt=accumulatedDt+dt
    maxDt=math.max(maxDt,dt)
    local now=os.clock()
    if now-lastSample>=0.05 then
        lastSample=now
        sampleBall("Bowling Ball")
        sampleBall("Default")
    end
    if now-lastPerf>=1 then
        lastPerf=now
        local ping
        pcall(function() ping=LocalPlayer:GetNetworkPing()*1000 end)
        add(result.performance,{
            at=clock(),fps=number(frames/math.max(accumulatedDt,0.0001)),
            maxFrameMs=number(maxDt*1000),pingMs=number(ping),
            networkServerTime=serverTime()
        },LIMITS.performance)
        frames=0
        accumulatedDt=0
        maxDt=0
    end
    if now-lastSnap>=12 then
        lastSnap=now
        snapshot("periodic")
    end
end)

task.spawn(function()
    scanTree(ReplicatedStorage,"ReplicatedStorage")
    local scripts=LocalPlayer and LocalPlayer:FindFirstChild("PlayerScripts")
    if scripts then scanTree(scripts,"PlayerScripts") end
    scanTree(Workspace,"Workspace")
    snapshot("initial")
    scanNetworking()
    ready=true
    notification("Coletando tudo. Jogue normalmente. F7 salva / F6 salva e encerra.")
    task.spawn(scanModuleCode)
end)
task.delay(120,function()
    if live then
        save()
        notification("Salvamento automatico feito. F6 encerra a coleta.")
    end
end)
print("[VolleyBomb Diagnostic] Relatorio: "..FILE.." | F7 salvar | F6 encerrar")
