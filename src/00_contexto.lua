




local P=game:GetService('Players')
local R=game:GetService('ReplicatedStorage')
local Run=game:GetService('RunService')
local U=game:GetService('UserInputService')
local CAS=game:GetService('ContextActionService')
local T=game:GetService('TweenService')
local W=game:GetService('Workspace')
local Http=game:GetService('HttpService')
local me=P.LocalPlayer
local C={Main=true,Practice=true,LockOn=false,SmartDive=false,
    Radius=3.1,MainColor=Color3.fromRGB(75,255,150),
    PracticeColor=Color3.fromRGB(85,200,255),
    DiveLead=0.55,MinLead=0.15,MaxLead=1.5,
    MinSpeed=52,MinFall=5,MaxError=1.2,
    DiveReach=24,DiveSpeed=100,DiveCooldown=1.2,
    ChaseRange=85,ChaseWindow=3.5,StopDistance=11,
    AimDelay=0.06,InputDelay=0.065,LockSpeed=9,
    SafetyLead=0.08, MinNativeLead=0.24,
    
    
    MaxEarlyWait=5.2, EmergencyWindow=0.020,
    SteerDive=true, 
    SpikeDirection=false,SpikeKey='X',
    FPSBoost=true}
local env=_G
if type(getgenv)=='function' then
    local ok,e=pcall(getgenv)
    if ok and type(e)=='table' then env=e end
end

local saveFile='VolleyBombLanding_settings.json'
local savedKeys={'LockOn','SmartDive',
    'DiveLead','SpikeDirection','SpikeKey','FPSBoost'}
local uiPrefs={}
local saveLocation='sessao'
local hasV65Preferences=false

local function loadSettings(data)
    if type(data)~='table' then return end
    if data.Version=='6.5' or data.Version=='6.6' or data.Version=='6.7' or data.Version=='6.8' or data.Version=='6.9' or data.Version=='7.0' or data.Version=='7.1' or data.Version=='7.2' or data.Version=='7.3' or data.Version=='7.4' or data.Version=='7.5' or data.Version=='7.6' or data.Version=='7.7' or data.Version=='7.8' or data.Version=='7.9' or data.Version=='8.0' or data.Version=='8.1' or data.Version=='8.2' or data.Version=='8.3' or data.Version=='8.4' or data.Version=='8.5' or data.Version=='8.6' or data.Version=='8.8' or data.Version=='8.9' or data.Version=='9.0' or data.Version=='9.1' or data.Version=='9.2' or data.Version=='9.3' or data.Version=='9.4' or data.Version=='9.5' or data.Version=='9.6' or data.Version=='9.7' or data.Version=='9.8' then hasV65Preferences=true end
    for _,key in ipairs(savedKeys) do
        local value=data[key]
        if key=='DiveLead' then
            if type(value)=='number' and value==value then
                C[key]=math.clamp(value,C.MinLead,C.MaxLead)
            end
        elseif key=='SpikeKey' then
            
            if type(value)=='string' and value:match('^[A-Z]$')
                and not string.find('WASDE',value,1,true) then
                C.SpikeKey=value
            end
        elseif type(value)=='boolean' then
            C[key]=value
        end
    end
    if type(data.UI)=='table' then
        for _,key in ipairs({'IconX','IconY','PanelX','PanelY'}) do
            local v=data.UI[key]
            if type(v)=='number' and v==v and math.abs(v)<100000 then
                uiPrefs[key]=v
            end
        end
    end
end


loadSettings(env.VolleyBombLandingSettings)
if type(readfile)=='function' then
    pcall(function()
        if type(isfile)~='function' or isfile(saveFile) then
            loadSettings(Http:JSONDecode(readfile(saveFile)))
        end
    end)
end

local old=env.VolleyBombLanding
if type(old)=='table' then
    
    loadSettings(old.Config)
    if type(old.UI)=='table' then loadSettings({UI=old.UI}) end
    if type(old.Stop)=='function' then pcall(old.Stop,'replace') end
end

C.Main=true
C.Practice=true

C.SteerDive=true

local function saveSettings()
    local data={Version='9.8',UI={}}
    for _,key in ipairs(savedKeys) do data[key]=C[key] end
    for _,key in ipairs({'IconX','IconY','PanelX','PanelY'}) do
        data.UI[key]=uiPrefs[key]
    end
    env.VolleyBombLandingSettings=data
    saveLocation='sessao'
    if type(writefile)=='function' then
        local ok=pcall(function()
            writefile(saveFile,Http:JSONEncode(data))
        end)
        if ok and type(readfile)=='function' then saveLocation='arquivo' end
    end
    return saveLocation
end

local event=R:WaitForChild('Packages'):WaitForChild('Net'):WaitForChild('RE/BallState')
local folder=Instance.new('Folder')
folder.Name='VolleyLanding85'
folder.Parent=W
local links,states,markers={},{},{}
local zones={Main={},Practice={}}
local owned={Main={},Practice={}}
local areaAttempt={Main=false,Practice=false}
local stopped=false
local rotHum,rotOriginal=nil,nil
local aimTarget,pending=nil,nil
local diveAnimations={}
local lastPhysicalPress=-math.huge
local lastNativeStart=-math.huge
local learnedDiveProfile={}
local profileSample=nil
local diveAnimating=false
local lastDecision='Aguardando E'
local aimUntil,blockMoveUntil=0,0
local lastDive,lastID=-math.huge,nil
local sample=nil
local measuredSpeed=nil
local ping=0.08
local lastPing=0
local renderKey='VolleyLanding85_Render'
local spikeActionKey='VolleyLanding85_Spike'
local actionKey='VolleyLanding85_E'
local inputBound=false
local refreshSmart
local steerTarget=nil
local steerDirection=nil 
local steerUntil=0
local steerActive=false
local lastSteerDistance=nil
local steerPathLength=0 
local steerAnimationSeen=false
local steerArmedAt=0
local steerStarted=false       
local steerDetectedAt=0
local steerStartSource=''
local steerStartPosition=nil
local activePressAt=0
local liveTracks={Main={Samples={},Next=0},Practice={Samples={},Next=0}}

local function make(class,properties,parent)
    local o=Instance.new(class)
    for k,v in pairs(properties) do o[k]=v end
    o.Parent=parent
    return o
end






