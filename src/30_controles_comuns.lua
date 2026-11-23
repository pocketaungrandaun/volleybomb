local function shiftLockAtivo()
    return U.MouseBehavior==Enum.MouseBehavior.LockCenter
end

local function restoreRotation()
    if rotHum and rotHum.Parent and rotOriginal~=nil then
        rotHum.AutoRotate=rotOriginal
    end
    rotHum,rotOriginal=nil,nil
end
local function keepRotation(hum)
    if rotHum~=hum then
        restoreRotation()
        rotHum,rotOriginal=hum,hum.AutoRotate
    end
    hum.AutoRotate=false
end
local function restoreCamera()
    
    restoreRotation()
end
local function face(root,hum,target)
    local dir=horizontal(root.Position,target)
    if not dir then return end
    keepRotation(hum)
    root.CFrame=CFrame.lookAt(root.Position,root.Position+dir)
end

local function targetLock(root)
    local best,distance=nil,math.huge
    local mode=detectMode()
    for arena in pairs(markers) do
        if arena==mode then
            local s=active(arena)
            if s and s.Point and s.Surface=='floor'
                and s.Reliable and not s.MotionUncertain then
                local d=(s.Point-root.Position).Magnitude
                if d<distance then best,distance=s.Point,d end
            end
        end
    end
    return best
end







