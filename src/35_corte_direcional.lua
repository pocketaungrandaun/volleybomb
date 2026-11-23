local spikeHeld=false
local spikeJumped=false
local spikeJumpHum=nil
local spikeStateLink=nil
local spikeCaptureKey=false
local spikeKeyRefresh=nil
local spikeLockedDir=nil
local spikeLockedUntil=0
local spikeLastClick=-math.huge
local function clearSpikeLock()
    spikeLockedDir=nil
    spikeLockedUntil=0
end
local function directionFromCamera()
    local cam=W.CurrentCamera
    if not cam then return nil end
    local look=cam.CFrame.LookVector
    local flat=Vector3.new(look.X,0,look.Z)
    if flat.Magnitude<0.025 then return nil end
    return flat.Unit
end
local function isSpikeJump(hum)
    if not hum or hum.Health<=0 or not spikeJumped or spikeJumpHum~=hum then
        return false
    end
    return hum.FloorMaterial==Enum.Material.Air
end
local function attachSpikeJump(char)
    if spikeStateLink then spikeStateLink:Disconnect() spikeStateLink=nil end
    spikeJumped=false
    spikeJumpHum=nil
    clearSpikeLock()
    local hum=char:FindFirstChildOfClass('Humanoid') or char:WaitForChild('Humanoid',5)
    if stopped or not hum then return end
    spikeJumpHum=hum
    if hum:GetState()==Enum.HumanoidStateType.Jumping then spikeJumped=true end
    spikeStateLink=hum.StateChanged:Connect(function(_,newState)
        if newState==Enum.HumanoidStateType.Jumping then
            spikeJumped=true
        elseif newState==Enum.HumanoidStateType.Landed
            or newState==Enum.HumanoidStateType.Running
            or newState==Enum.HumanoidStateType.RunningNoPhysics
            or newState==Enum.HumanoidStateType.Dead
            or newState==Enum.HumanoidStateType.Seated then
            spikeJumped=false
        end
    end)
end
if me.Character then attachSpikeJump(me.Character) end
links[#links+1]=me.CharacterAdded:Connect(attachSpikeJump)

local function orientSpike(root,hum,dir)
    if not dir then return false end
    keepRotation(hum)
    root.CFrame=CFrame.lookAt(root.Position,root.Position+dir)
    return true
end
local function spikeAvailable()
    if stopped or not C.SpikeDirection or spikeCaptureKey then return false end
    if os.clock()-lastPhysicalPress<0.35 then return false end
    if C.SmartDive and steerActive and os.clock()<steerUntil then return false end
    local root,hum=character()
    return root~=nil and isSpikeJump(hum)
end
local function onSpikeClick()
    if not spikeAvailable() or not spikeHeld then return end
    local now=os.clock()
    if now-spikeLastClick<0.08 then return end
    local dir=directionFromCamera()
    if not dir then return end
    spikeLastClick=now
    spikeLockedDir=dir
    
    spikeLockedUntil=now+0.40
    local root,hum=character()
    if root and hum then orientSpike(root,hum,dir) end
end
local function updateSpikeFacing(root,hum)
    if not C.SpikeDirection then clearSpikeLock() return false end
    local now=os.clock()
    if now<spikeLockedUntil and spikeLockedDir then
        if hum.Health>0 and hum.FloorMaterial==Enum.Material.Air then
            return orientSpike(root,hum,spikeLockedDir)
        end
        clearSpikeLock()
        return false
    end
    if spikeLockedDir then clearSpikeLock() end
    
    
    if spikeHeld and spikeAvailable() then
        return orientSpike(root,hum,directionFromCamera())
    end
    return false
end


links[#links+1]=U.InputBegan:Connect(function(input,processed)
    if stopped then return end
    if spikeCaptureKey and input.UserInputType==Enum.UserInputType.Keyboard then
        local name=input.KeyCode.Name
        if name=='Escape' then
            spikeCaptureKey=false
            if spikeKeyRefresh then spikeKeyRefresh() end
            return
        end
        if name:match('^[A-Z]$') and not string.find('WASDE',name,1,true) then
            C.SpikeKey=name
            spikeHeld=false
            spikeCaptureKey=false
            clearSpikeLock()
            saveSettings()
            if spikeKeyRefresh then spikeKeyRefresh() end
        end
        return
    end
    if U:GetFocusedTextBox() then return end
    if input.UserInputType==Enum.UserInputType.Keyboard
        and input.KeyCode.Name==C.SpikeKey then
        spikeHeld=true
    elseif input.UserInputType==Enum.UserInputType.MouseButton1 and not processed then
        
        onSpikeClick()
    end
end)
links[#links+1]=U.InputEnded:Connect(function(input)
    if input.UserInputType==Enum.UserInputType.Keyboard
        and input.KeyCode.Name==C.SpikeKey then
        spikeHeld=false
    end
end)


local spikeBindOK=pcall(function()
    CAS:BindActionAtPriority(spikeActionKey,function(_,state)
        if state==Enum.UserInputState.Begin then onSpikeClick() end
        return Enum.ContextActionResult.Pass
    end,false,9000,Enum.UserInputType.MouseButton1)
end)
if not spikeBindOK then
    warn('[VolleyBomb] Captura do corte por CAS indisponivel; usando InputBegan')
end




