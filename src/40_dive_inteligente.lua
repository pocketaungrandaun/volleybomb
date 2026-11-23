local function samplePing()
    if os.clock()-lastPing<1 then return end
    lastPing=os.clock()
    local ok,p=pcall(function() return me:GetNetworkPing() end)
    if ok and type(p)=='number' and p>=0 and p<2 then ping=p end
end
local function learnDive()
    if not sample or os.clock()-sample.Start<0.33 then return end
    local root=character()
    if root then
        local delta=root.Position-sample.Position
        local speed=delta:Dot(sample.Direction)/(os.clock()-sample.Start)
        if speed>10 and speed<120 then
            measuredSpeed=measuredSpeed and measuredSpeed*0.6+speed*0.4 or speed
        end
    end
    sample=nil
end
local function diveSpeed()
    return math.clamp(measuredSpeed or C.DiveSpeed,15,100)
end












local function smartCandidate()
    local root=character()
    if not root then return nil end
    local nearest,chosen,chosenArena=math.huge,nil,nil
    local now=os.clock()
    local mode=detectMode(true)
    for _,arena in ipairs({'Main','Practice'}) do
        local m=markers[arena]
        if arena==mode and m and m.LastPoint and
            (m.Visible or (m.LastVisibleAt and now-m.LastVisibleAt<=0.12)) then
            local delta=m.LastPoint-root.Position
            local distance=Vector3.new(delta.X,0,delta.Z).Magnitude
            if distance<nearest then
                nearest,chosen,chosenArena=distance,m.LastPoint,arena
            end
        end
    end
    return chosen,chosenArena,nearest
end

local function stopSteering()
    steerActive=false
    steerStarted=false
    steerTarget=nil
    steerDirection=nil
    steerStartPosition=nil
    lastSteerDistance=nil
    steerPathLength=0
    steerAnimationSeen=false
end



local function aimAndDiveNatively()
    if stopped or not C.SmartDive then return end
    local now=os.clock()
    lastPhysicalPress=now
    stopSteering()
    local target,arena,dist=smartCandidate()
    local root,hum=character()
    if not root or not hum then return end
    restoreRotation()
    aimTarget=nil
    aimUntil=0

    
    if not target then
        lastDecision='E original: nenhum indicador naquele instante'
        return
    end
    local direction=horizontal(root.Position,target)
    if not direction then
        lastDecision='E original: ja esta no indicador'
        return
    end

    
    steerTarget=Vector3.new(target.X,target.Y,target.Z)
    steerDirection=direction
    steerStartPosition=root.Position
    steerPathLength=dist
    steerAnimationSeen=false
    steerArmedAt=now
    steerUntil=now+math.clamp(dist/108+0.70,0.85,C.ChaseWindow)
    steerStarted=false
    steerActive=true
    clearSpikeLock()
    lastDecision=string.format('E -> indicador %s salvo, %.1f studs',arena,dist)
    print(string.format('[VolleyBomb v8.0 Dive] E NATIVO | alvo=%s | distancia=%.1f | ponto=(%.1f,%.1f,%.1f) | shiftlock=%s',
        arena,dist,target.X,target.Y,target.Z,tostring(shiftLockAtivo())))
end






local wallCast=params()
local wallCastChar=me.Character
local lastWallFilter=0
local function obstacleAhead(root,dir)
    if me.Character~=wallCastChar or os.clock()-lastWallFilter>2 then
        wallCastChar=me.Character
        wallCast=params()
        lastWallFilter=os.clock()
    end
    
    
    local ok,hit=pcall(function()
        return W:Raycast(root.Position+Vector3.new(0,0.75,0),dir*3.2,wallCast)
    end)
    return ok and hit and math.abs(hit.Normal.Y)<0.55 and hit.Distance<=2.8
end
local function steerPhysics()
    if stopped or not C.SmartDive or not steerActive or not steerDirection then return end
    local root,hum=character()
    if not root or not hum or root.Anchored
        or hum:GetState()==Enum.HumanoidStateType.Dead then
        stopSteering()
        return
    end
    local now=os.clock()
    if now>steerUntil then
        
        
        lastDecision=steerStarted and 'Dive finalizado: limite de tempo' or 'E sem dive detectado'
        stopSteering()
        return
    end
    local velocity=root.AssemblyLinearVelocity
    local flat=Vector3.new(velocity.X,0,velocity.Z).Magnitude

    
    if not steerStarted then
        if now-steerArmedAt>0.34 then
            lastDecision='E original nao iniciou dive (possivel cooldown)'
            stopSteering()
            return
        end
        if (flat>=52 and flat<=175) or (steerAnimationSeen and flat>=16) then
            steerStarted=true
            steerDetectedAt=now
            steerStartSource='impulso'
            lastDecision='Dive iniciado: linha reta para indicador salvo'
            print('[VolleyBomb v8.0 Dive] Movimento real detectado; direcao congelada')
        else
            return
        end
    end

    
    
    local offset=root.Position-steerStartPosition
    local delta=Vector3.new(offset.X,0,offset.Z)
    local progress=delta:Dot(steerDirection)
    local left=steerPathLength-progress

    if left<=1.9 then
        root.AssemblyLinearVelocity=Vector3.new(0,velocity.Y,0)
        lastDecision='Indicador salvo alcancado na linha original'
        stopSteering()
        return
    end

    
    
    local sideways=(delta-steerDirection*progress).Magnitude
    if sideways>7 then
        lastDecision='Trajetoria desviada: sem perseguir indicador'
        stopSteering()
        return
    end
    if obstacleAhead(root,steerDirection) then
        root.AssemblyLinearVelocity=Vector3.new(0,velocity.Y,0)
        lastDecision='Parede na linha do dive: sem atravessar ou desviar'
        stopSteering()
        return
    end

    
    
    
    local speed=math.clamp((left-1.2)*13,26,118)
    local corrected=steerDirection*speed
    root.AssemblyLinearVelocity=Vector3.new(corrected.X,velocity.Y,corrected.Z)
end



local physicsOK,physicsConn=pcall(function()
    return Run.PostSimulation:Connect(steerPhysics)
end)
if physicsOK and physicsConn then
    links[#links+1]=physicsConn
else
    links[#links+1]=Run.Heartbeat:Connect(steerPhysics)
end



links[#links+1]=U.InputBegan:Connect(function(input)
    if stopped or input.KeyCode~=Enum.KeyCode.E or not C.SmartDive
        or inputBound or U:GetFocusedTextBox()~=nil then return end
    aimAndDiveNatively()
end)



local function wallCandidate()
    local mode=detectMode()
    local root,hum=character()
    if not root or hum.FloorMaterial==Enum.Material.Air then return nil end
    local now=W:GetServerTimeNow()
    local result,best=nil,math.huge
    for arena in pairs(markers) do
        if arena==mode then
            local s=active(arena)
            if s and not s.MotionUncertain and s.Reliable and s.Surface=='wall' and s.Point then
                local untilWall=s.EndTime-now
                local _,dist=horizontal(root.Position,s.Point)
                if untilWall>0.02
                    and untilWall<=math.min(1.05,C.DiveLead+0.2)
                    and dist<=65 then
                    local score=untilWall+dist*0.005
                    if score<best then result,best=s,score end
                end
            end
        end
    end
    return result
end



local function startProfile()
    local root=character()
    if not root then return end
    profileSample={Start=os.clock(),Position=root.Position,
        Direction=root.CFrame.LookVector,LastBin=-1}
end

local function measureProfile()
    if not profileSample then return end
    local root=character()
    if not root then profileSample=nil return end
    local elapsed=os.clock()-profileSample.Start
    local bin=math.floor(elapsed/0.05)
    if bin>profileSample.LastBin and bin>=1 and bin<=11 then
        profileSample.LastBin=bin
        local dir=Vector3.new(profileSample.Direction.X,0,
            profileSample.Direction.Z)
        if dir.Magnitude>0.01 then
            local delta=root.Position-profileSample.Position
            local dist=math.max(0,delta:Dot(dir.Unit))
            if dist>=0 and dist<=80 then
                local prior=learnedDiveProfile[bin]
                learnedDiveProfile[bin]=prior and
                    (prior*0.65+dist*0.35) or dist
            end
        end
    end
    if elapsed>=0.60 then profileSample=nil end
end

local function travelSeconds(dist)
    local travel=math.max(0,dist-2.2)
    
    
    local previous=0
    for bin=1,11 do
        local d=learnedDiveProfile[bin]
        if d then
            if d>=travel then
                local fraction=0
                if d>previous+0.01 then
                    fraction=math.clamp((travel-previous)/(d-previous),0,1)
                end
                return math.clamp((bin-1+fraction)*0.05,0.035,0.54)
            end
            previous=math.max(previous,d)
        end
    end
    
    
    
    
    if travel <= 5 then
        return math.max(0.025, 0.04 * travel/5)
    elseif travel <= 12 then
        return 0.04 + (travel-5)*0.060/7
    elseif travel <= 20 then
        return 0.10 + (travel-12)*0.105/8
    end
    return math.clamp(0.205+(travel-20)*0.055,0.205,0.48)
end


local function diveLeadFor(s,dist)
    local network=math.clamp(ping,0,0.16)
    
    local speedBonus=math.clamp((s.ImpactSpeed-38)*0.0013,0,0.065)
    
    local manual=math.clamp((C.DiveLead-0.15)*0.055,0,0.075)
    return math.clamp(travelSeconds(dist)+network
        +C.InputDelay+C.SafetyLead+speedBonus+manual,0.13,0.78)
end



local function shouldLaunchNow(s,remaining,lead)
    local speedPad=math.clamp((s.ImpactSpeed-48)*0.0011,0,0.055)
    return remaining<=lead+C.EmergencyWindow+speedPad
        or remaining<=math.max(0.18,ping*0.5+0.12)
end

local function observedDive()
    lastNativeStart=os.clock()
    lastDive=os.clock()
    if steerActive and os.clock()-steerArmedAt<=0.34 then
        
        
        steerAnimationSeen=true
    end
    if pending then
        print('[VolleyBomb v8.0 Dive] Animacao do dive detectada: cancelar comando duplicado')
        pending=nil
    end
    startProfile()
    
    aimTarget=nil
    aimUntil=0
    restoreRotation()
end

local animationLink
local function attachAnimator()
    if animationLink then animationLink:Disconnect() animationLink=nil end
    local ch=me.Character
    if not ch then return end
    task.spawn(function()
        local hum=ch:WaitForChild('Humanoid',5)
        if not hum or stopped then return end
        local animator=hum:WaitForChild('Animator',5)
        if not animator or stopped then return end
        animationLink=animator.AnimationPlayed:Connect(function(track)
            local animation=track.Animation
            local id=animation and animation.AnimationId or ''
            if string.find(id,'125582828675515',1,true)
                and os.clock()-lastPhysicalPress<2 then
                observedDive()
            end
        end)
    end)
end
attachAnimator()
links[#links+1]=me.CharacterAdded:Connect(attachAnimator)


local function cancelSmart()
    pending=nil
    aimTarget=nil
    aimUntil=0
    stopSteering()
end


local function explainNoCandidate()
    local root=character()
    for arena in pairs(markers) do
        local s=active(arena)
        if s then
            local _,dist=nil,nil
            if root and s.Point then
                _,dist=horizontal(root.Position,s.Point)
            end
            local same=(root and s.Point) and ownSide(s,root) or false
            print(string.format(
                '[VolleyBomb v8.0 Dive] %s | tipo=%s | confiavel=%s | incerto=%s | dist=%s | minhaArea=%s | faltam=%.3fs',
                arena,tostring(s.Surface),tostring(s.Reliable),
                tostring(s.MotionUncertain),dist and string.format('%.1f',dist) or '?',
                tostring(same),s.EndTime-W:GetServerTimeNow()))
        end
    end
end

local function onSmartDive(_,inputState)
    if stopped or not C.SmartDive then
        return Enum.ContextActionResult.Pass
    end
    if inputState==Enum.UserInputState.Begin and not U:GetFocusedTextBox() then
        aimAndDiveNatively()
    end
    
    return Enum.ContextActionResult.Pass
end

local function shouldBindSmart()
    return not stopped and C.SmartDive
end

local function updateEIntercept()
    local bind=shouldBindSmart()
    if bind and not inputBound then
        local ok,err=pcall(function()
            CAS:BindActionAtPriority(actionKey,onSmartDive,false,10000,Enum.KeyCode.E)
        end)
        inputBound=ok
        if ok then print('[VolleyBomb v8.0] E monitorado: Pass ao Dive nativo (prioridade 2000)') end
        if not ok then
            warn('[VolleyBomb] Nao foi possivel interceptar E: '..tostring(err))
        end
    elseif not bind and inputBound then
        CAS:UnbindAction(actionKey)
        inputBound=false
        print('[VolleyBomb v8.0] E assistido desconectado; E 100% nativo')
    end
end



links[#links+1]=Run.Heartbeat:Connect(function()
    if stopped then return end
    samplePing()
    learnDive()
    updateBallMotion()
    updateMarkers()
    measureProfile()
    updateEIntercept()
end)

Run:BindToRenderStep(renderKey,Enum.RenderPriority.Camera.Value+10,function()
    if stopped then return end
    local root,hum=character()
    if not root then restoreCamera() return end

    
    if steerActive then
        restoreRotation()
        return
    end
    
    if updateSpikeFacing(root,hum) then return end

    
    if C.LockOn and not C.SmartDive then
        local point=targetLock(root)
        if point and not shiftLockAtivo() then face(root,hum,point)
        else restoreRotation() end
    elseif os.clock()>aimUntil then
        restoreRotation()
    end
end)







