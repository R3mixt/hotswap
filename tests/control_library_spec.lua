-- Camera and movement remain native commands, presented independently from
-- spell actions. Browsing and assigning entries must only stage edits.
local function controls(open)
    Mock.build="1.15.9"; Mock.buildNumber="70576"
    local k=TestAddon; k:Init(); k:GetSettings().flavor="era"
    if open then k.UI:Open() end
    return k
end
local function commands(k,tab,options)
    options=options or {}; options.tab=tab
    local result={}
    for _,entry in ipairs(k.Library:List(options)) do
        assert(entry.descriptor and entry.descriptor.kind=="system","A native-control menu contains a non-command entry")
        assert(not result[entry.descriptor.command],"Duplicate control in "..tab)
        result[entry.descriptor.command]=entry
    end
    return result
end
local function entry(k,tab,command)
    local found=commands(k,tab)[command]
    assert(found,command.." missing from "..tab)
    return found
end

function Tests.control_library_separates_turning_strafing_and_camera_views()
    local k=controls(); local movement=commands(k,"movement"); local camera=commands(k,"camera"); local game=commands(k,"game")
    for _,command in ipairs({"MOVEFORWARD","MOVEBACKWARD","STRAFELEFT","STRAFERIGHT","TURNLEFT","TURNRIGHT","JUMP","TOGGLEAUTORUN","PITCHUP","PITCHDOWN","MOVEANDSTEER"}) do
        assert(movement[command],"Movement omitted "..command)
        assert(not camera[command] and not game[command],"Movement control duplicated outside its menu: "..command)
    end
    for _,command in ipairs({"CAMERAZOOMIN","CAMERAZOOMOUT","NEXTVIEW","PREVVIEW","SETVIEW1","SAVEVIEW2","RESETVIEW3","CAMERAORSELECTORMOVE","TURNORACTION"}) do
        assert(camera[command],"Camera omitted "..command)
        assert(not movement[command] and not game[command],"Camera control duplicated outside its menu: "..command)
        assert(k.Library:ValidateDescriptor(camera[command].descriptor),"Displayed camera control cannot be assigned")
    end
    assert(game.TARGETSELF and game.TOGGLEWORLDMAP,"Other game controls disappeared after splitting menus")
    assert(commands(k,"chat").OPENCHAT and not game.OPENCHAT,"Chat controls were moved into Game")
    assert(not GetBindingKey("TURNLEFT") and movement.TURNLEFT,"Unbound movement is not available to assign")
    assert(not GetBindingKey("SETVIEW1") and camera.SETVIEW1,"Unbound camera view is not available to assign")
end

function Tests.control_library_uses_raw_categories_and_localized_labels()
    local k=controls()
    Mock:RegisterBindingCommand("CUSTOM_LOCOMOTION","BINDING_HEADER_MOVEMENT")
    Mock:RegisterBindingCommand("CUSTOM_PERSPECTIVE","BINDING_HEADER_CAMERA")
    GetLocale=function() return "deDE" end
    BINDING_HEADER_MOVEMENT="Kamera (localized fixture)"
    BINDING_HEADER_CAMERA="Bewegung (localized fixture)"
    BINDING_NAME_CUSTOM_LOCOMOTION="Seitwaerts bewegen"
    BINDING_NAME_CUSTOM_PERSPECTIVE="Ansicht drehen"
    local move=entry(k,"movement","CUSTOM_LOCOMOTION")
    local camera=entry(k,"camera","CUSTOM_PERSPECTIVE")
    assert(move.label=="Seitwaerts bewegen" and camera.label=="Ansicht drehen","New control menus lost localized labels")
    assert(not commands(k,"camera").CUSTOM_LOCOMOTION and not commands(k,"movement").CUSTOM_PERSPECTIVE,"Translated category text changed native classification")
    local search=k.Library:List({tab="movement",query="SEITWAERTS"})
    assert(#search==1 and search[1].descriptor.command=="CUSTOM_LOCOMOTION","Movement search did not use localized control labels")
    local categories=k.Library:Categories("movement")
    local found=false; for _,name in ipairs(categories) do if name==move.category then found=true end end
    assert(found,"Movement category picker omitted a visible category")
    for _,v in ipairs(k.Library:List({tab="movement",category=move.category})) do
        assert(v.category==move.category,"Category filtering leaked another category")
    end
end

function Tests.control_library_reflects_client_capability_changes_and_registry_failures()
    local k=controls(); assert(commands(k,"camera").CAMERAZOOMOUT)
    Mock:SetBindingCommandAvailable("CAMERAZOOMOUT",false)
    assert(not commands(k,"camera").CAMERAZOOMOUT,"Removed client capability stayed in cached Camera menu")
    Mock:RegisterBindingCommand("CUSTOM_LOCOMOTION","BINDING_HEADER_MOVEMENT")
    assert(commands(k,"movement").CUSTOM_LOCOMOTION,"New client movement capability was not discoverable")
    local original=GetBinding
    GetBinding=function() error("unreadable binding registry") end
    k.API:InvalidateBindingCommands()
    assert(not next(commands(k,"camera")) and not next(commands(k,"movement")),"Unusable registry produced guessed bindable commands")
    GetBinding=original
end

function Tests.control_library_tabs_fit_both_themes_and_navigation_does_not_apply()
    local k=controls(true); local ui=k.UI; local f=ui.library
    local exported,dirty=k:Export(),k.dirty
    local order={"spells","items","movement","camera","game","chat","emotes","macros"}
    for _,theme in ipairs({"classic","modern"}) do
        assert(k.Themes:Set(theme)); local rects={}
        for _,name in ipairs(order) do
            local tab=f.tabs[name]; assert(tab and tab:IsVisible(),"Missing visible spellbook tab: "..name)
            local _,x,y=tab:GetPoint(); local w,h=tab:GetWidth(),tab:GetHeight()
            assert(type(x)=="number" and x>=0 and x+w<=f:GetWidth(),"Spellbook tab exceeds panel width: "..name)
            local top=-y; assert(top>=24,"Spellbook tab overlaps title: "..name)
            for _,r in ipairs(rects) do
                assert(x>=r.x+r.w or x+w<=r.x or top>=r.y+r.h or top+h<=r.y,"Overlapping spellbook tabs")
            end
            rects[#rects+1]={x=x,y=top,w=w,h=h}
        end
        local _,_,categoryY=f.category:GetPoint()
        for _,r in ipairs(rects) do assert(r.y+r.h<=-categoryY,"Menu tabs overlap category controls") end
    end
    ui.libraryEntry={label="Previous selection"}; ui.libraryCategory="Previous category"
    f.search:SetText("old search"); f.list.slider:SetValue(120)
    Mock:ResetWrites(); f.tabs.camera:Click()
    assert(ui.libraryTab=="camera" and not ui.libraryCategory and not ui.libraryEntry,"Camera navigation left stale drag/category state")
    assert(f.search:GetText()=="" and f.list.sf:GetVerticalScroll()==0,"Camera navigation retained old search or scroll")
    assert(not f.ranks:IsShown() and not f.addItem:IsShown(),"Camera menu exposes unrelated spell/item controls")
    assert(f.note:GetText():find("Clear key",1,true),"Control menu does not explain how to leave a key unbound")
    f.tabs.movement:Click()
    assert(ui.libraryTab=="movement" and #f.entries>0,"Movement tab is not usable")
    assert(k:Export()==exported and k.dirty==dirty and #Mock.writes==0,"Browsing menus edited a preset or applied game changes")
end

function Tests.control_library_current_drop_stages_native_movement_and_camera_commands()
    local k=controls(true); local ui=k.UI; local exported=k:Export()
    Mock:ResetWrites()
    ui.libraryEntry=entry(k,"movement","TURNLEFT")
    assert(ui:DropLibraryEntry("NUMPAD9"),"Movement menu entry cannot be assigned to an empty Current key")
    ui.libraryEntry=entry(k,"camera","CAMERAZOOMIN")
    assert(ui:DropLibraryEntry("CTRL-NUMPAD9"),"Camera menu entry cannot be assigned to an empty Current key")
    local edits=k.CurrentBindings.edits
    assert(edits.keys.NUMPAD9=="TURNLEFT" and edits.keys["CTRL-NUMPAD9"]=="CAMERAZOOMIN","Native controls were staged as the wrong command")
    assert(GetBindingAction("NUMPAD9")=="" and GetBindingAction("CTRL-NUMPAD9")=="" and #Mock.writes==0,"Dropping controls changed live keys before Apply")
    assert(k:Export()==exported,"Current control drops modified the selected preset")
end

function Tests.control_library_draft_drop_exports_native_descriptors_without_macros()
    local k=controls(true); local ui=k.UI; ui:SetBindingSource("draft")
    Mock:ResetWrites()
    ui.libraryEntry=entry(k,"movement","TURNRIGHT")
    assert(ui:DropLibraryEntry("CTRL-F24"),"Movement menu entry cannot be added to a preset")
    ui.libraryEntry=entry(k,"camera","SETVIEW1")
    assert(ui:DropLibraryEntry("CTRL-F23"),"Camera menu entry cannot be added to a preset")
    local found={}
    for _,action in ipairs(k:Preview().actions) do
        if action.key=="CTRL-F24" or action.key=="CTRL-F23" then
            found[action.command]=true
            assert(action.kind=="system" and not action.body,"Native control was compiled into a macro")
        end
    end
    assert(found.TURNRIGHT and found.SETVIEW1,"Preset control assignments were lost in preview")
    local text=k:Export()
    assert(text:find("TURNRIGHT",1,true) and text:find("SETVIEW1",1,true),"Preset transfer omitted new-menu control descriptors")
    assert(k.dirty and #Mock.writes==0,"Editing a control applied the preset immediately")
end
