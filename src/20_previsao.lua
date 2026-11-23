local function character()
    local ch=me.Character
    if not ch then return nil end
    local root=ch:FindFirstChild('HumanoidRootPart')
    local hum=ch:FindFirstChildOfClass('Humanoid')
    if not root or not hum or hum.Health<=0 then return nil end
    return root,hum
end
local function horizontal(a,b)
    local d=Vector3.new(b.X-a.X,0,b.Z-a.Z)
    if d.Magnitude<0.01 then return nil,0 end
    return d.Unit,d.Magnitude
end
local function params()
    local exclude={folder}
    for _,n in ipairs({'Default','Bowling Ball','BallShadow'}) do
        local o=W:FindFirstChild(n)
        if o then table.insert(exclude,o) end
    end
    for _,pl in ipairs(P:GetPlayers()) do
        if pl.Character then table.insert(exclude,pl.Character) end
    end
    local p=RaycastParams.new()
    p.FilterType=Enum.RaycastFilterType.Exclude
    p.FilterDescendantsInstances=exclude
    p.RespectCanCollide=true
    p.IgnoreWater=true
    return p
end
local function radius(arena)
    local name=arena=='Main' and 'Bowling Ball' or 'Default'
    local b=W:FindFirstChild(name)
    if not b or not b:IsA('BasePart') then return 1.5 end
    return math.clamp(math.min(b.Size.X,b.Size.Y,b.Size.Z)*0.5,0.4,4)
end



local function predictionCast(origin,direction,p,castRadius)
    for _=1,9 do
        local ok,hit=pcall(function()
            if castRadius then return W:Spherecast(origin,castRadius,direction,p) end
            return W:Raycast(origin,direction,p)
        end)
        if not ok then return nil,false end
        if not hit then return nil,true end
        if hit.Instance and FPS.HiddenOriginals[hit.Instance]~=nil then
            local excluded=p.FilterDescendantsInstances
            excluded[#excluded+1]=hit.Instance
            p.FilterDescendantsInstances=excluded
        else
            return hit,true
        end
    end
    
    return nil,false
end

local function marker(arena,color)
    local model=make('Model',{Name=arena..'Landing'},folder)
    local parts={}
    local function part(sz,cf,alpha,shape)
        local p=make('Part',{Size=sz,CFrame=cf,
            Shape=shape or Enum.PartType.Block,Anchored=true,
            CanCollide=false,CanTouch=false,CanQuery=false,
            CastShadow=false,Material=Enum.Material.Neon,
            Color=color,Transparency=1},model)
        table.insert(parts,{p,alpha})
        return p
    end
    for ring=1,2 do
        local rad=C.Radius*(ring==1 and 1 or 0.68)
        local count=ring==1 and 32 or 26
        local thickness=ring==1 and 0.38 or 0.2
        for i=1,count do
            local a=(i-0.5)*math.pi*2/count
            local tangent=Vector3.new(-math.sin(a),0,math.cos(a))
            local pos=Vector3.new(math.cos(a)*rad,0,math.sin(a)*rad)
            part(Vector3.new(2*rad*math.sin(math.pi/count)*1.08,0.09,thickness),
                CFrame.fromMatrix(pos,tangent,Vector3.yAxis),ring==1 and 0.06 or 0.3)
        end
    end
    part(Vector3.new(0.27,0.27,0.27),
        CFrame.new(0,0.08,0),0.08,Enum.PartType.Ball)
    
    model.WorldPivot=CFrame.new()
    return {Model=model,Parts=parts,Visible=false}
end
markers.Main=marker('Main',C.MainColor)
markers.Practice=marker('Practice',C.PracticeColor)




local currentMode='Lobby'
local modeCheckAt=-math.huge
local modeLastConfirmed=-math.huge
local function detectMode(force)
    local now=os.clock()
    if not force and now-modeCheckAt<0.12 then return currentMode end
    modeCheckAt=now
    local root=character()
    if not root then
        currentMode='Lobby'
        return currentMode
    end
    local chosen='Lobby'
    local bestDist=math.huge
    local pos=root.Position

    
    
    for _,arena in ipairs({'Main','Practice'}) do
        for _,zone in ipairs(zones[arena]) do
            if typeof(zone)=='Instance' and zone:IsA('BasePart') and zone.Parent then
                local localPos=zone.CFrame:PointToObjectSpace(pos)
                if math.abs(localPos.Y)<=math.max(60,zone.Size.Y/2+15) then
                    local dx=math.max(0,math.abs(localPos.X)-zone.Size.X/2)
                    local dz=math.max(0,math.abs(localPos.Z)-zone.Size.Z/2)
                    local distance=math.sqrt(dx*dx+dz*dz)
                    
                    if distance<bestDist and distance<=12 then
                        chosen=arena
                        bestDist=distance
                    end
                end
            end
        end
    end

    
    
    if chosen=='Lobby' then
        for _,arena in ipairs({'Main','Practice'}) do
            local s=states[arena]
            if s and W:GetServerTimeNow()<=s.EndTime+0.25 and #zones[arena]==0 then
                local ball=W:FindFirstChild(arena=='Main' and 'Bowling Ball' or 'Default')
                if ball and ball:IsA('BasePart') then
                    local delta=ball.Position-pos
                    local distance=Vector3.new(delta.X,0,delta.Z).Magnitude
                    if math.abs(delta.Y)<65 and distance<bestDist and distance<=115 then
                        chosen=arena
                        bestDist=distance
                    end
                end
            end
        end
    end

    
    if chosen~='Lobby' then
        modeLastConfirmed=now
    elseif currentMode~='Lobby' and now-modeLastConfirmed<0.35 then
        chosen=currentMode
    end
    currentMode=chosen
    return currentMode
end

FPS.GetMode=detectMode

FPS.IsArenaPoint=function(pos)
    for _,arena in ipairs({'Main','Practice'}) do
        for _,zone in ipairs(zones[arena]) do
            if typeof(zone)=='Instance' and zone:IsA('BasePart') and zone.Parent then
                local relative=zone.CFrame:PointToObjectSpace(pos)
                if math.abs(relative.X)<=zone.Size.X*0.5+5
                    and math.abs(relative.Z)<=zone.Size.Z*0.5+5
                    and math.abs(relative.Y)<=90 then return true end
            end
        end
    end
    return false
end

local function show(m,visible)
    if m.Visible==visible then return end
    m.Visible=visible
    for _,part in ipairs(m.Parts) do
        part[1].Transparency=visible and part[2] or 1
    end
end
local function frame(point,normal)
    local ref=math.abs(normal:Dot(Vector3.yAxis))>0.95 and Vector3.xAxis or Vector3.yAxis
    return CFrame.fromMatrix(point+normal*0.15,ref:Cross(normal).Unit,normal)
end
local function active(arena)
    local s=states[arena]
    if not s or W:GetServerTimeNow()>s.EndTime+0.08 then return nil end
    return s
end



local function liveState(arena)
    local s=active(arena)
    if s then return s end
    s=states[arena]
    if not s or not s.Raw then return nil end
    local special=s.Raw.Tornado~=nil or s.Raw.Magnet~=nil
    if not special then return nil end
    if type(s.RawEndTime)~='number' or s.RawEndTime==math.huge then return nil end
    if W:GetServerTimeNow()>s.RawEndTime+0.60 then return nil end
    return s
end
local correctedState
local function updateMarkers()
    local mode=detectMode()
    for arena,m in pairs(markers) do
        local s=(arena==mode) and correctedState and correctedState(arena) or nil
        
        
        if s and s.Point and s.Normal and s.Surface=='floor'
            and s.Normal.Y>=0.88 then
            m.Model:PivotTo(frame(s.Point,s.Normal))
            
            m.LastPoint=s.Point
            m.LastNormal=s.Normal
            m.LastVisibleAt=os.clock()
            show(m,true)
            
            local alpha=s.Live and 0.5 or (s.BounceEstimated and 0.36 or 0)
            if m.LastAlpha~=alpha then
                m.LastAlpha=alpha
                for _,item in ipairs(m.Parts) do
                    item[1].Transparency=math.max(item[2],alpha)
                end
            end
        else
            show(m,false)
            m.LastAlpha=nil
            
            
            if arena==mode and liveState(arena) then
                m.LastPoint=nil
                m.LastNormal=nil
                m.LastVisibleAt=nil
            end
        end
    end
end
local function position(s,t)
    return s.Origin+s.Velocity*t+s.Gravity*(t*t*0.5)
end
local function forecast(s,arena)
    if typeof(s.Origin)~='Vector3' or typeof(s.Velocity)~='Vector3'
        or typeof(s.Gravity)~='Vector3' or type(s.Time)~='number'
        or type(s.EndTime)~='number' then return nil end
    local duration=s.EndTime-s.Time
    if duration<=0 or duration>12 or duration~=duration
        or s.EndTime==math.huge then return nil end
    local endpoint=position(s,duration)
    local endVelocity=s.Velocity+s.Gravity*duration
    local ballRadius=radius(arena)
    
    
    
    
    
    local serverNormal=s.Normal
    if typeof(serverNormal)=='Vector3' and serverNormal.Magnitude>0.9
        and serverNormal.Magnitude<1.1
        and -endVelocity:Dot(serverNormal)>0.5
        and s.Tornado==nil and s.Magnet==nil then
        local n=serverNormal.Unit
        local kind=n.Y>=0.88 and 'floor'
            or (n.Y<=-0.72 and 'ceiling' or 'wall')
        if not (s.IgnoreWalls and kind=='wall') then
            return endpoint-n*ballRadius,n,0.03,endVelocity,
                s.EndTime,true,kind
        end
    end
    local p=params()

    
    
    local segments=math.clamp(math.ceil(duration/0.08),2,110)
    local castRadius=math.max(0.35,ballRadius*0.89)
    local nearEnd=math.clamp(duration*0.10,0.075,0.16)
    for i=1,segments do
        local t0=duration*(i-1)/segments
        local t1=duration*i/segments
        local a,b=position(s,t0),position(s,t1)
        local motion=b-a
        local length=motion.Magnitude
        if length>0.025 then
            local hit,ok=predictionCast(a,motion,p,castRadius)
            if ok and hit then
                local fraction=math.clamp(hit.Distance/length,0,1)
                local hitT=t0+(t1-t0)*fraction
                local velocity=s.Velocity+s.Gravity*hitT
                local closeInTime=math.abs(duration-hitT)<=nearEnd
                local closeInSpace=(hit.Position-endpoint).Magnitude <= ballRadius+2.1
                if -velocity:Dot(hit.Normal)>0.3
                    and closeInTime and closeInSpace then
                    local kind=hit.Normal.Y>=0.88 and 'floor'
                        or (hit.Normal.Y<=-0.72 and 'ceiling' or 'wall')
                    if not (s.IgnoreWalls and kind=='wall') then
                        return hit.Position,hit.Normal,0.05,velocity,
                            s.Time+hitT,true,kind
                    end
                end
                
                
            end
        end
    end

    
    
    local best,err=nil,math.huge
    local directions={Vector3.xAxis,-Vector3.xAxis,Vector3.yAxis,
        -Vector3.yAxis,Vector3.zAxis,-Vector3.zAxis}
    if endVelocity.Magnitude>0.1 then
        table.insert(directions,endVelocity.Unit)
    end
    for _,dir in ipairs(directions) do
        local hit=predictionCast(endpoint,dir*math.max(ballRadius+1.5,3.5),p)
        if hit then
            local gap=math.abs((hit.Position-endpoint).Magnitude-ballRadius)
            if gap<err and gap<=0.60 and -endVelocity:Dot(hit.Normal)>0.5 then
                best,err=hit,gap
            end
        end
    end
    if best then
        local kind=best.Normal.Y>=0.88 and 'floor'
            or (best.Normal.Y<=-0.72 and 'ceiling' or 'wall')
        
        
        if kind=='wall' and (err>0.25 or s.IgnoreWalls) then return nil end
        return best.Position,best.Normal,err,endVelocity,
            s.EndTime,true,kind
    end
    return nil
end






local bounceModels={Main={Normal=0.60,Tangent=0.60},
    Practice={Normal=0.60,Tangent=0.60}}

local function bounceVelocity(velocity,normal,model)
    local along=velocity:Dot(normal)
    if along>=-0.3 then return nil end
    local tangent=velocity-normal*along
    return tangent*model.Tangent-normal*along*model.Normal
end

local function predictFloorAfterBounce(raw,arena,hitPoint,hitNormal,hitVelocity,startTime)
    if typeof(raw.Gravity)~='Vector3' then return nil end
    local model=bounceModels[arena]
    if not model then return nil end
    local r=radius(arena)
    local castRadius=math.max(0.35,r*0.89)
    local point=hitPoint+hitNormal*(r+0.13)
    local velocity=bounceVelocity(hitVelocity,hitNormal,model)
    if not velocity then return nil end
    local param=params()
    local total=0
    local bounceCount=1
    
    for _=1,115 do
        if total>4 or bounceCount>5 or velocity.Magnitude>320 then break end
        local dt=0.04
        local delta=velocity*dt+raw.Gravity*(0.5*dt*dt)
        if delta.Magnitude<0.025 then
            point=point+delta
            velocity=velocity+raw.Gravity*dt
            total=total+dt
        else
            local hit,ok=predictionCast(point,delta,param,castRadius)
            if not ok then return nil end
            if hit then
                local f=math.clamp(hit.Distance/delta.Magnitude,0,1)
                local elapsed=dt*f
                local incident=velocity+raw.Gravity*elapsed
                local n=hit.Normal
                
                if n.Y>=0.88 and incident.Y< -1.2 then
                    return hit.Position,n,startTime+total+elapsed,bounceCount
                end
                local reflected=bounceVelocity(incident,n,model)
                if not reflected then
                    
                    return nil
                end
                bounceCount=bounceCount+1
                point=hit.Position+n*(r+0.13)
                velocity=reflected
                total=total+math.max(elapsed,0.014)
            else
                point=point+delta
                velocity=velocity+raw.Gravity*dt
                total=total+dt
            end
        end
    end
    return nil
end

local function zoneAt(list,point)
    local chosen,smallest=nil,math.huge
    for _,z in ipairs(list) do
        if z.Parent then
            local p=z.CFrame:PointToObjectSpace(point)
            if math.abs(p.X)<=z.Size.X/2+1 and math.abs(p.Z)<=z.Size.Z/2+1 then
                local size=z.Size.X*z.Size.Z
                if size<smallest then chosen,smallest=z,size end
            end
        end
    end
    return chosen
end
local function lockZone(arena,add)
    local root=character()
    if not root then return false end
    local z=zoneAt(zones[arena],root.Position)
    if not z then return false end
    if not add then table.clear(owned[arena]) end
    owned[arena][z]=true
    return true
end
local function floorAt(point)
    return W:Raycast(point+Vector3.new(0,2,0),Vector3.new(0,-9,0),params())
end
local function ownSide(s,root)
    local impact=zoneAt(s.Zones,s.Point)
    local mine=zoneAt(s.Zones,root.Position)
    
    
    if next(owned[s.Arena])~=nil then
        return impact~=nil and owned[s.Arena][impact]==true
    end
    if impact and mine then return impact==mine end
    if s.Arena~='Practice' then return false end
    local a=floorAt(root.Position)
    local b=floorAt(s.Point)
    return a~=nil and b~=nil and a.Instance==b.Instance
        and a.Normal.Y>0.9 and b.Normal.Y>0.9
end

local function abilityTagged(raw)
    if raw.Tornado~=nil or raw.Magnet~=nil then return true end
    for _,value in pairs(raw) do
        if type(value)=='string' then
            local str=string.lower(value)
            if string.find(str,'curve',1,true)
                or string.find(str,'tornado',1,true) then
                return true
            end
        end
    end
    return false
end

links[#links+1]=event.OnClientEvent:Connect(function(raw)
    if stopped or type(raw)~='table' then return end
    local arena=raw.Arena
    if not markers[arena] then return end
    if type(raw.Time)~='number' or type(raw.EndTime)~='number' then return end
    local oldState=states[arena]
    if oldState and raw.Time<oldState.Time then return end
    local point,normal,error,velocity,collisionTime,reliable,surface=forecast(raw,arena)
    
    
    local firstPoint,firstNormal,firstVelocity,firstSurface=point,normal,velocity,surface
    local estimated,bounces=false,0
    if (surface=='wall' or surface=='ceiling') and point and normal and velocity then
        local ground,groundNormal,groundTime,count=predictFloorAfterBounce(
            raw,arena,point,normal,velocity,collisionTime or raw.EndTime)
        if ground and groundNormal and groundNormal.Y>=0.88
            and count and count<=3 then
            point,normal,collisionTime=ground,groundNormal,groundTime
            surface='floor'
            error=2.0+count*1.15
            reliable=false
            estimated=true
            bounces=count
        else
            
            point,normal,collisionTime,reliable,surface=nil,nil,nil,false,nil
        end
    elseif surface~='floor' then
        point,normal,collisionTime,reliable,surface=nil,nil,nil,false,nil
    end
    local zoneList={}
    if type(raw.Zones)=='table' then
        for _,z in pairs(raw.Zones) do
            if typeof(z)=='Instance' and z:IsA('BasePart') then
                table.insert(zoneList,z)
            end
        end
    end
    local previousZones=zones[arena]
    local changedZones=#previousZones~=#zoneList
    if not changedZones then
        local set={}
        for _,z in ipairs(previousZones) do set[z]=true end
        for _,z in ipairs(zoneList) do
            if not set[z] then changedZones=true break end
        end
    end
    
    
    if point and surface=='floor' and #zoneList>0 then
        local inCourt=false
        for _,zone in ipairs(zoneList) do
            local localPoint=zone.CFrame:PointToObjectSpace(point)
            if math.abs(localPoint.X)<=zone.Size.X*0.5+7
                and math.abs(localPoint.Z)<=zone.Size.Z*0.5+7 then
                inCourt=true
                break
            end
        end
        if not inCourt then
            point,normal,collisionTime,reliable,surface=nil,nil,nil,false,nil
            estimated=false
        end
    end
    zones[arena]=zoneList
    if changedZones then FPS.Revision=FPS.Revision+1 end
    detectMode(true)
    
    if C.SmartDive and not areaAttempt[arena] and #zoneList>0 then
        if lockZone(arena,true) then areaAttempt[arena]=true end
    end
    
    
    if surface=='floor' and point and not estimated and normal and normal.Y>=0.88 then
        liveTracks[arena].FloorY=point.Y
    end
    states[arena]={Arena=arena,Raw=raw,Time=raw.Time,
        EndTime=collisionTime or raw.EndTime,
        RawEndTime=raw.EndTime,
        Point=point,Normal=normal,Error=error or math.huge,
        Reliable=reliable==true,Surface=surface,
        BounceEstimated=estimated,BounceCount=bounces,
        FirstImpactPoint=firstPoint,FirstImpactNormal=firstNormal,
        FirstIncoming=firstVelocity,FirstSurface=firstSurface,
        MotionUncertain=abilityTagged(raw),Live=false,
        ImpactSpeed=velocity and velocity.Magnitude or 0,
        FallSpeed=velocity and -velocity.Y or 0,Zones=zoneList}
    updateMarkers()
end)





local function updateBallMotion()
    local now=os.clock()
    for arena,track in pairs(liveTracks) do
        if now>=track.Next then
            track.Next=now+0.035
            local part=W:FindFirstChild(arena=='Main' and 'Bowling Ball' or 'Default')
            local s=liveState(arena)
            if part and part:IsA('BasePart') and s and s.Raw then
                local samples=track.Samples
                if track.RawTime~=s.Raw.Time then
                    local special=s.Raw.Tornado~=nil or s.Raw.Magnet~=nil
                    local last=samples[#samples]
                    local continuous=special and track.PreviousSpecial and last
                        and now-last.T<0.25 and (last.P-part.Position).Magnitude<20
                    if not continuous then table.clear(samples) end
                    track.RawTime=s.Raw.Time
                    track.PreviousSpecial=special
                    if not special then
                        track.UncertainUntil=nil
                        track.UncertainRawTime=nil
                    end
                end
                samples[#samples+1]={P=part.Position,T=now}
                while #samples>15 or (#samples>2 and now-samples[1].T>0.48) do
                    table.remove(samples,1)
                end
                if #samples>=4 then
                    local first,last=samples[1],samples[#samples]
                    local dt=last.T-first.T
                    
                    
                    
                    local pastKnownBounce=s.BounceEstimated and
                        W:GetServerTimeNow()>=s.RawEndTime-0.03
                    if dt>=0.095 and not pastKnownBounce then
                        local raw=s.Raw
                        local t0=math.clamp(W:GetServerTimeNow()-raw.Time-dt,0,12)
                        local t1=math.clamp(W:GetServerTimeNow()-raw.Time,0,12)
                        local expected=position(raw,t1)-position(raw,t0)
                        local observed=last.P-first.P
                        
                        
                        local error=(observed-expected).Magnitude
                        local speed=observed.Magnitude/dt
                        local unstable=error>math.max(2.5,dt*13)
                            and speed>3
                        if unstable then
                            s.MotionUncertain=true
                            track.UncertainUntil=now+0.40
                            track.UncertainRawTime=s.Raw.Time
                        elseif track.UncertainUntil and now>track.UncertainUntil then
                            s.MotionUncertain=false
                        end
                    end
                end
            else
                table.clear(track.Samples)
                track.RawTime=nil
                track.PreviousSpecial=false
            end
        end
    end
end





local function liveFloor(arena)
    local track=liveTracks[arena]
    local s=liveState(arena)
    if not track or not s or not s.Raw then return nil end
    local now=os.clock()
    
    
    if track.LastLiveCalc and track.LastLiveRawTime==s.Raw.Time
        and now-track.LastLiveCalc<0.085 then
        if track.LastLivePoint then
            return track.LastLivePoint,track.LastLiveNormal,
                math.max(0.04,(track.LastLiveDelay or 0.3)-(now-track.LastLiveCalc))
        end
        return nil
    end
    track.LastLiveCalc=now
    track.LastLiveRawTime=s.Raw.Time
    local q=track.Samples
    local last=q[#q]
    if not last or now-last.T>0.30 then return nil end
    local ballPos=last.P
    local p=params()
    local floorY=track.FloorY
    local groundHit=nil
    local function validGround(hit)
        return hit and hit.Normal.Y>=0.86
            and not (hit.Instance and FPS.HiddenOriginals[hit.Instance]~=nil)
    end
    
    
    local root=character()
    if root and (not track.FloorCheckedAt or now-track.FloorCheckedAt>0.55) then
        track.FloorCheckedAt=now
        local underPlayer=predictionCast(root.Position+Vector3.new(0,3,0),
            Vector3.new(0,-50,0),p)
        if validGround(underPlayer) and math.abs(root.Position.Y-underPlayer.Position.Y)<22 then
            floorY=underPlayer.Position.Y
            groundHit=underPlayer
        end
    end
    if not floorY then
        local underBall=predictionCast(ballPos+Vector3.new(0,3,0),
            Vector3.new(0,-200,0),p)
        if validGround(underBall) then
            floorY=underBall.Position.Y
            groundHit=underBall
        end
    end
    if not floorY then
        
        
        if root and detectMode() == arena then
            floorY=root.Position.Y-3
        end
    end
    if floorY then track.FloorY=floorY end

    
    
    
    local v=Vector3.zero
    local acc=Vector3.zero
    local measured=false
    if #q>=2 then
        local prev=q[math.max(1,#q-4)]
        local dt=last.T-prev.T
        if dt>=0.022 then
            local estimate=(last.P-prev.P)/dt
            if estimate.Magnitude<320 then
                v=estimate
                measured=true
            end
        end
    end
    if #q>=5 then
        local first=q[math.max(1,#q-8)]
        local mid=q[math.max(2,#q-4)]
        local dt1=mid.T-first.T
        local dt2=last.T-mid.T
        if dt1>=0.035 and dt2>=0.035 then
            local v1=(mid.P-first.P)/dt1
            local v2=(last.P-mid.P)/dt2
            local a=(v2-v1)/math.max(0.04,(dt1+dt2)*0.5)
            local horizontal=Vector3.new(a.X,0,a.Z)
            if horizontal.Magnitude>80 then horizontal=horizontal.Unit*80 end
            acc=horizontal
            if v2.Magnitude<320 then v=v2; measured=true end
        end
    end
    local raw=s.Raw
    local gravity=raw.Gravity
    if typeof(gravity)~='Vector3' or gravity.Y>=-0.5 then
        gravity=Vector3.new(0,-10,0)
    end
    if not measured then
        if typeof(raw.Velocity)=='Vector3' and raw.Velocity.Magnitude>1 then
            v=raw.Velocity
        else
            
            
            v=Vector3.zero
        end
    end

    
    
    if not measured and #q<3 and typeof(raw.Target)~='Vector3' then
        return nil
    end
    local t=0.55
    if floorY then
        local h=ballPos.Y-(floorY+radius(arena))
        if h>0.05 then
            local d=v.Y*v.Y-2*gravity.Y*h
            if d>=0 then
                local solution=(-v.Y-math.sqrt(d))/gravity.Y
                if solution==solution and solution>=0 then
                    t=math.clamp(solution,0.04,6.0)
                end
            end
        else
            t=0.08
        end
    else
        local remaining=raw.EndTime-W:GetServerTimeNow()
        if type(remaining)=='number' and remaining>0 and remaining<6 then
            t=math.clamp(remaining,0.15,4.0)
        end
    end
    
    
    local effectTime=math.min(t,0.65)
    local shift=Vector3.new(v.X*t+acc.X*0.5*effectTime*effectTime,
        0,v.Z*t+acc.Z*0.5*effectTime*effectTime)
    local guessed=ballPos+shift
    if not measured and typeof(raw.Target)=='Vector3' then
        local target=raw.Target
        if (Vector3.new(target.X-ballPos.X,0,target.Z-ballPos.Z)).Magnitude<180 then
            guessed=target
        end
    end

    
    
    local chosen,minimum=nil,math.huge
    for _,z in ipairs(zones[arena]) do
        if typeof(z)=='Instance' and z:IsA('BasePart') and z.Parent then
            local lp=z.CFrame:PointToObjectSpace(guessed)
            local lx=math.clamp(lp.X,-math.max(1,z.Size.X*0.5-1),math.max(1,z.Size.X*0.5-1))
            local lz=math.clamp(lp.Z,-math.max(1,z.Size.Z*0.5-1),math.max(1,z.Size.Z*0.5-1))
            local clamped=z.CFrame:PointToWorldSpace(Vector3.new(lx,lp.Y,lz))
            local dx=clamped.X-guessed.X
            local dz=clamped.Z-guessed.Z
            local dist=dx*dx+dz*dz
            if dist<minimum then minimum,chosen=dist,clamped end
        end
    end
    if chosen and minimum>0 then
        
        
        if math.sqrt(minimum)>10 then return nil end
        guessed=Vector3.new(chosen.X,guessed.Y,chosen.Z)
    end
    local topY=math.max(ballPos.Y+25,(floorY or ballPos.Y)+90)
    local landing=predictionCast(Vector3.new(guessed.X,topY,guessed.Z),
        Vector3.new(0,-270,0),p)
    local finalPos,finalNormal
    if validGround(landing) and (not floorY
        or math.abs(landing.Position.Y-floorY)<13) then
        finalPos,finalNormal=landing.Position,landing.Normal
        floorY=landing.Position.Y
        track.FloorY=floorY
    elseif floorY and chosen and minimum<=9 then
        
        
        finalPos=Vector3.new(guessed.X,floorY,guessed.Z)
        finalNormal=Vector3.yAxis
    else
        
        
        return nil
    end
    
    track.LastLivePoint=finalPos
    track.LastLiveNormal=finalNormal
    track.LastLiveDelay=t
    track.LastGroundPoint=finalPos
    track.LastGroundNormal=finalNormal
    track.LastGroundAt=now
    track.LastGroundRawTime=raw.Time
    return finalPos,finalNormal,t
end

correctedState=function(arena)
    local s=liveState(arena)
    if not s then return nil end
    local track=liveTracks[arena]
    local now=os.clock()
    local special=s.AbilitySpecial or (s.Raw and
        (s.Raw.Tornado~=nil or s.Raw.Magnet~=nil))
    if special then
        local point,normal,delay=liveFloor(arena)
        if point then
            return {Arena=arena,Time=s.Time,EndTime=W:GetServerTimeNow()+delay,
                Point=point,Normal=normal,Surface='floor',
                Zones=s.Zones,Error=2,ImpactSpeed=s.ImpactSpeed,
                FallSpeed=1,Reliable=false,Live=true}
        end
        
        if track.LastGroundPoint and track.LastGroundRawTime==s.Raw.Time
            and now-(track.LastGroundAt or -math.huge)<0.16 then
            return {Arena=arena,Time=s.Time,EndTime=W:GetServerTimeNow()+0.08,
                Point=track.LastGroundPoint,Normal=track.LastGroundNormal,
                Surface='floor',Zones=s.Zones,Error=3,
                ImpactSpeed=s.ImpactSpeed,FallSpeed=1,Reliable=false,Live=true}
        end
        return nil
    end
    
    
    if s.MotionUncertain or (track.UncertainUntil and
        now<track.UncertainUntil and track.UncertainRawTime==s.Raw.Time) then
        return nil
    end
    
    
    if s.BounceEstimated and type(s.RawEndTime)=='number'
        and W:GetServerTimeNow()>s.RawEndTime+0.07 then
        return nil
    end
    return s
end




