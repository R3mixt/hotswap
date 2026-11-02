local _,K=...
K.Protection={}
local P=K.Protection
P.options={movement="preserveMovement",camera="preserveCamera",chat="preserveChat",interface="preserveInterface",targeting="preserveTargeting"}
local movement={MOVEANDSTEER=true,MOVEFORWARD=true,MOVEBACKWARD=true,TURNLEFT=true,TURNRIGHT=true,STRAFELEFT=true,STRAFERIGHT=true,JUMP=true,TOGGLEAUTORUN=true,STARTAUTORUN=true,STOPAUTORUN=true,FOLLOWTARGET=true,PITCHUP=true,PITCHDOWN=true,TOGGLERUN=true}
function P:Group(command,registry)
    if type(command)~="string" or command=="" then return end
    -- A user macro/frame name may contain words such as CAMERA or CHAT.
    -- Those names do not make the action a native game control.
    if command:match("^MACRO ") or command:match("^CLICK ") or command:match("^SPELL ") or command:match("^ITEM ") then return end
    if K.API.HiddenMouseCommands[command] or command:find("CAMERA",1,true) or command:match("^SETVIEW") or command:match("^SAVEVIEW") or command:match("^RESETVIEW") or command=="NEXTVIEW" or command=="PREVVIEW" then return "camera" end
    if movement[command] then return "movement" end
    if command:find("CHAT",1,true) or command:find("REPLY",1,true) or command:find("WHISPER",1,true) or command=="SAY" or command=="YELL" then return "chat" end
    if command:match("^TARGET") or command:match("^ASSIST") or command:match("^FOCUS") or command:match("^INTERACT") or command=="ATTACKTARGET" then return "targeting" end
    if command:match("^ACTION") or command:match("^MULTIACTION") or command:match("^BONUSACTION") or command:match("^SHAPESHIFT") or command:match("^PET") or command=="STOPCASTING" or command=="STOPATTACK" then return end
    local row=registry and registry[command]
    local category=row and tostring(row.category or "") or ""
    if category:find("MOVEMENT",1,true) then return "movement" end
    if category:find("CAMERA",1,true) then return "camera" end
    if category:find("CHAT",1,true) then return "chat" end
    if category:find("TARGET",1,true) then return "targeting" end
    if row or command:match("^TOGGLE") or command:match("^OPEN") or command=="SCREENSHOT" then return "interface" end
end
function P:Preserves(command,settings,registry)
    local group=self:Group(command,registry)
    return group and settings[self.options[group]]==true or false
end
function P:Build(settings)
    local keys,actions={},{}
    local requested=false; for _,option in pairs(self.options) do requested=requested or settings[option]==true end
    if not requested then return keys,actions end
    local commands,readable=K.API:GetBindingCommands()
    if not readable then return nil,nil,"The game's controls could not be read. Reload before protecting current bindings." end
    local current={}
    local counted,count=pcall(GetNumBindings)
    if not counted or type(count)~="number" or count<1 or count>10000 or count%1~=0 then return nil,nil,"The game's controls could not be read safely." end
    for index=1,count do
        local row={pcall(GetBinding,index)}
        if not row[1] or type(row[2])~="string" or row[2]=="" then return nil,nil,"A game control could not be read. No protected keys were changed." end
        table.remove(row,1)
        for n=3,#row do if row[n] and row[n]~="" then current[row[n]]=row[1] end end
    end
    local ok,why=K.API:ReadHiddenMouseBindings(current)
    if not ok then return nil,nil,why end
    for key,command in pairs(current) do
        if self:Preserves(command,settings,commands) then
            keys[key]=command
            actions[#actions+1]={id="preserved."..key,key=key,command=command,label=K.API:BindingLabel(command),kind="system",known=true,form="all",category="Preserved controls",preserved=true}
        end
    end
    table.sort(actions,function(a,b) return a.key<b.key end)
    return keys,actions
end
