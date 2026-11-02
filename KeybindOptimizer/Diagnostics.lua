local _,K=...
K.Diagnostics={limit=200,messageLimit=3000}
local D=K.Diagnostics
local contextKeys={"class","flavor","version","stage","key","command","action","operation","backup","outcome"}
local function primitive(value,limit)
    local kind=type(value)
    if kind~="string" and kind~="number" and kind~="boolean" then return nil end
    if kind=="number" and (value~=value or value==math.huge or value==-math.huge) then return nil end
    local text=tostring(value):gsub("\r\n","\n"):gsub("\r","\n"):gsub("[%z\1-\8\11\12\14-\31\127]","")
    return text:sub(1,limit)
end
local function contextCopy(context)
    local result={}
    if type(context)=="table" then
        for _,key in ipairs(contextKeys) do
            local value=primitive(context[key],128)
            if value then result[key]=value end
        end
    end
    return result
end
local function stamp()
    if date then local ok,value=pcall(date,"%Y-%m-%d %H:%M:%S"); if ok and type(value)=="string" then return value end end
    return tostring(time and time() or 0)
end
local function runtime()
    local version,build
    if GetBuildInfo then version,build=GetBuildInfo() end
    local class=UnitClass and select(2,UnitClass("player")) or K.playerClass
    local flavor="unknown"
    if K.API and K.API.GetFlavor then
        local ok,value=pcall(K.API.GetFlavor,K.API)
        if ok and type(value)=="string" then flavor=value end
    end
    return primitive(version or "unknown",80),primitive(build or "unknown",80),primitive(class or "unknown",80),primitive(flavor,80)
end
function D:IsEnabled()
    return K.db and type(K.db.preferences)=="table" and K.db.preferences.diagnostics==true or false
end
function D:Count()
    return K.db and type(K.db.diagnostics)=="table" and #K.db.diagnostics or 0
end
function D:Trace(message)
    local text=primitive(message,self:IsEnabled() and 2000 or self.messageLimit) or "Unknown Lua error"
    if not self:IsEnabled() or type(debugstack)~="function" then return text end
    -- Capture call locations only, never locals or saved preset/macro tables.
    local ok,stack=pcall(debugstack,2,16,0)
    if ok and type(stack)=="string" and stack~="" then text=text.."\nStack:\n"..stack end
    return text:sub(1,self.messageLimit)
end
function D:Record(level,event,message,context)
    if not self:IsEnabled() then return false end
    local logs=K.db.diagnostics
    if type(logs)~="table" then logs={}; K.db.diagnostics=logs end
    local _,_,class,flavor=runtime()
    local fields=contextCopy(context)
    fields.class=fields.class or class; fields.flavor=fields.flavor or flavor; fields.version=fields.version or tostring(K.version or "unknown")
    local record={timestamp=stamp(),level=primitive(level or "info",16),event=primitive(event or "event",80),message=primitive(message or "",self.messageLimit),context=fields}
    record.level=record.level or "info"; record.event=record.event or "event"; record.message=record.message or ""
    while #logs>=self.limit do table.remove(logs,1) end
    logs[#logs+1]=record
    return true
end
local function addonError(message)
    if type(message)~="string" then return false end
    local lower=message:lower()
    return lower:find("keybindoptimizer",1,true)~=nil or lower:find("addons/hot swap/",1,true)~=nil or lower:find("addons\\hot swap\\",1,true)~=nil or message:find("KBO_",1,true)~=nil
end
function D:UpdateErrorHandler()
    if not self:IsEnabled() then
        if self.handlerToken then self.handlerToken.active=false end
        if self.errorWrapper and geterrorhandler and seterrorhandler and geterrorhandler()==self.errorWrapper then
            pcall(seterrorhandler,self.previousErrorHandler)
        end
        -- If another addon wrapped us, leave its chain intact. This wrapper's
        -- immutable token is now inactive and only forwards to its predecessor.
        self.errorWrapper=nil; self.previousErrorHandler=nil; self.handlerToken=nil
        return
    end
    if self.handlerToken and self.handlerToken.active then return end
    if not geterrorhandler or not seterrorhandler then return end
    local previous=geterrorhandler()
    if type(previous)~="function" then return end
    local token={active=true}
    local wrapper=function(message,...)
        if token.active and D:IsEnabled() and not D.recordingError and addonError(message) then
            D.recordingError=true
            local ok,traced=pcall(D.Trace,D,message)
            pcall(D.Record,D,"error","lua_error",ok and traced or message,{operation="error-handler"})
            D.recordingError=false
        end
        -- Always preserve the previous game/addon handler's arguments/results.
        return previous(message,...)
    end
    local ok=pcall(seterrorhandler,wrapper)
    if not ok then token.active=false; return end
    self.errorWrapper=wrapper; self.previousErrorHandler=previous; self.handlerToken=token
end
function D:SetEnabled(enabled)
    if type(enabled)~="boolean" then return false,"Choose whether to enable diagnostic logging." end
    if not K.db then return false,"Hot Swap settings are not ready." end
    if type(K.db.preferences)~="table" then K.db.preferences={} end
    K.db.preferences.diagnostics=enabled
    self:UpdateErrorHandler()
    return true
end
function D:Clear()
    if not K.db then return false,"Hot Swap settings are not ready." end
    K.db.diagnostics={}
    return true
end
function D:Init()
    if not K.db then return end
    if type(K.db.preferences)~="table" then K.db.preferences={} end
    K.db.preferences.diagnostics=K.db.preferences.diagnostics==true
    local stored=type(K.db.diagnostics)=="table" and K.db.diagnostics or {}
    local records={}
    for index=math.max(1,#stored-self.limit+1),#stored do
        local entry=stored[index]
        if type(entry)=="table" then
            records[#records+1]={timestamp=primitive(entry.timestamp,80) or "unknown",level=primitive(entry.level,16) or "info",event=primitive(entry.event,80) or "event",message=primitive(entry.message,self.messageLimit) or "",context=contextCopy(entry.context)}
        end
    end
    K.db.diagnostics=records
    self:UpdateErrorHandler()
end
function D:Export()
    local version,build,class,flavor=runtime()
    local lines={"Hot Swap diagnostics", "Addon: "..tostring(K.version or "unknown"),"Client: "..version.." (build "..build..")","Class: "..class.." | Profile: "..flavor,"Logging: "..(self:IsEnabled() and "enabled" or "disabled"),"Entries: "..self:Count().." / "..self.limit,""}
    for index,entry in ipairs(K.db and K.db.diagnostics or {}) do
        lines[#lines+1]=string.format("%03d [%s] %s %s",index,entry.timestamp or "unknown",entry.level or "info",entry.event or "event")
        lines[#lines+1]=entry.message or ""
        local fields={}
        for _,key in ipairs(contextKeys) do
            local value=entry.context and primitive(entry.context[key],128)
            if value then fields[#fields+1]=key.."="..value:gsub("\n","\\n"):gsub("\t","\\t") end
        end
        if #fields>0 then lines[#lines+1]=table.concat(fields," | ") end
        lines[#lines+1]=""
    end
    if self:Count()==0 then lines[#lines+1]="No diagnostic entries recorded." end
    return table.concat(lines,"\n")
end
