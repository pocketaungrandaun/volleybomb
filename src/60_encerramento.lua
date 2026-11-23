local function stop(reason)
    if stopped then return end
    
    
    if reason~='replace' then
        local active=env.VolleyBombLanding
        if type(active)=='table' and active.Stop==stop
            and type(active.CancelTeleport)=='function' then
            pcall(active.CancelTeleport)
        end
    end
    
    saveSettings()
    stopped=true
    pending,aimTarget=nil,nil
    spikeCaptureKey=false
    spikeHeld=false
    spikeJumped=false
    clearSpikeLock()
    if spikeStateLink then spikeStateLink:Disconnect() end
    if spikeBindOK then CAS:UnbindAction(spikeActionKey) end
    stopSteering()
    FPS.Generation=FPS.Generation+1
    FPS.Enabled=false
    fpsRestore()
    cancelTweens()
    restoreCamera()
    Run:UnbindFromRenderStep(renderKey)
    if animationLink then animationLink:Disconnect() end
    if inputBound then CAS:UnbindAction(actionKey) end
    for _,link in ipairs(links) do link:Disconnect() end
    gui:Destroy()
    folder:Destroy()
    if type(env.VolleyBombLanding)=='table'
        and env.VolleyBombLanding.Stop==stop then
        env.VolleyBombLanding=nil
    end
end
links[#links+1]=close.MouseButton1Click:Connect(stop)
env.VolleyBombLanding={Stop=stop,Config=C,UI=uiPrefs,Version='9.8'}
print('[VolleyBomb v9.8] Rebote 0.60 e normal do BallState; Dive v8.0 preservado. Corte: '..C.SpikeKey..'. FPS: '..(C.FPSBoost and 'TURBO' or 'OFF')..'. Config: '..saveLocation)
