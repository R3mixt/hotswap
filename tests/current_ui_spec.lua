local function liveWarlock()
    Mock.class="WARLOCK"; Mock.build="1.15.9"; Mock.spells={}; Mock.catalog={}; Mock.forms={}
    UnitClass=function() return "Warlock","WARLOCK",9 end
    Mock:Learn(686,"Shadow Bolt"); Mock:Learn(172,"Corruption")
    Mock.catalog[686]={id=686,name="Shadow Bolt",icon=686}; Mock.catalog[172]={id=172,name="Corruption",icon=172}
    Mock.actions={[1]={"spell",686}}
    Mock.bindings={["1"]="ACTIONBUTTON1",["2"]="ACTIONBUTTON2",F="OPENCHAT",BUTTON1="CAMERAORSELECTORMOVE",BUTTON2="TURNORACTION",BUTTON8="TARGETSELF",["ALT-1"]="ACTIONBUTTON1"}
    Mock.bindingInventory=nil
    local k=TestAddon; k:Init(); Mock:ResetWrites()
    return k
end
function Tests.current_ui_default_warlock_reads_actual_bindings_without_building_a_draft()
    local k=liveWarlock(); local presets=k:Export()
    k.UI:Open()
    assert(k.UI.activePage=="Bindings" and k.UI.bindingSource=="current" and k.UI.bindingPlan.isCurrent)
    assert(not k.UI.draftPlan,"Default view built an editable recommendation")
    local keys=k.UI.pages.Bindings.keyboard.keys
    assert(keys["1"].action.spellID==686 and keys["2"].action.liveEmpty and not keys["2"].icon:IsShown(),"Live slots were replaced with recommended icons")
    assert(keys.F.action.command=="OPENCHAT" and keys.BUTTON1.action.command=="CAMERAORSELECTORMOVE" and keys.BUTTON2.action.command=="TURNORACTION")
    assert(keys.BUTTON8 and keys.BUTTON8.action.command=="TARGETSELF","Actual side button was omitted because the draft did not enable it")
    assert(not k.UI.apply:IsEnabled() and k.UI.pages.Bindings.hoverBind:IsEnabled() and k.UI.pages.Bindings.libraryToggle:IsEnabled() and k.UI.library:IsShown())
    keys["1"]:Click(); assert(k.UI.bindingMenu and k.UI.bindingMenu:IsShown())
    assert(not k.UI.capture or not k.UI.capture:IsShown())
    k.UI.bindingMenu.done:Click()
    k.UI:OpenHoverBindings(); k.UI.apply:Click()
    assert(k.UI.hoverBindings.active and not k.db.enabled and k:Export()==presets and #Mock.writes==0,"Inspecting Current modified a preset or live game state")
    Mock.alt=true; k.UI:RenderKeyboard()
    assert(not k.UI.pages.Bindings.layerHint:GetText():find("self-cast",1,true),"Current Alt view claims a recommended self-cast binding")
end

function Tests.current_ui_slot_and_binding_events_refresh_live_icons_and_reopen_resets_the_view()
    local k=liveWarlock(); k.UI:Open()
    Mock.actions[1]={"spell",172}; Mock:Fire("ACTIONBAR_SLOT_CHANGED",1); Mock:Advance(0.2)
    assert(k.UI.pages.Bindings.keyboard.keys["1"].action.spellID==172,"Slot event retained the old live icon")
    Mock.bindings.F="TARGETSELF"; Mock:Fire("UPDATE_BINDINGS"); Mock:Advance(0.2)
    assert(k.UI.pages.Bindings.keyboard.keys.F.action.command=="TARGETSELF","Binding event retained the old command")
    k.UI:SetBindingSource("draft"); assert(k.UI.draftPlan and k.UI.bindingPlan==k.UI.draftPlan)
    k.UI.frame:Hide(); k.UI:Open()
    assert(k.UI.bindingSource=="current" and k.UI.pages.Bindings.keyboard.keys["1"].action.spellID==172,"Reopening showed a stale recommendation draft")
    assert(#Mock.writes==0)
end

function Tests.current_ui_recommendation_preview_creates_nothing_until_explicitly_saved_as_draft()
    local k=liveWarlock(); k.UI:Open(); local exported=k:Export(); local count=#k.Presets:List()
    k.UI:ShowPage("Presets"); k.UI.pages.Presets.recommendations:Click()
    assert(k.UI.bindingSource=="recommendation" and k.UI.recommendationSnapshot and k.UI.bindingPlan==k.UI.recommendationPlan)
    assert(k:Export()==exported and #k.Presets:List()==count and #Mock.writes==0,"Preview made a preset or applied it")
    assert(not k.UI.apply:IsShown() and k.UI.saveRecommendation:IsShown() and not k.UI.pages.Bindings.hoverBind:IsEnabled())
    local first=k.UI.pages.Bindings.keyboard.keys["1"].action
    assert(first and not k.UI:AssignBinding(first,"NUMPAD9"),"Preview allowed edits before creating a draft")
    k.UI:UseSelectedPreset(); assert(not k.db.enabled and #Mock.writes==0,"Recommendation preview could be applied directly")
    k.UI.saveRecommendation:Click()
    assert(k.UI.saveDialog:IsShown() and #k.Presets:List()==count)
    k.UI.saveDialog.new:Click()
    k.UI.nameDialog.input:SetText("Recommended Warlock"); k.UI.nameDialog.save:Click()
    assert(k.UI.bindingSource=="draft" and #k.Presets:List()==count+1 and k.db.activePreset=="Recommended Warlock")
    assert(not k.db.enabled and #Mock.writes==0 and #k.Engine:ListBackups()==0,"Saving the preview activated it")
end

function Tests.current_ui_read_errors_are_visible_and_never_replaced_with_recommendations()
    local k=liveWarlock()
    k.CurrentBindings.Get=function() return {isCurrent=true,readOnly=true,actions={},errors={{message="The client could not enumerate bindings."}}} end
    k.UI:Open()
    assert(k.UI.status:GetText():find("could not be read",1,true),"Current read failure was presented as a complete layout")
    assert(k.UI.pages.Bindings.source.tipDetail:find("could not enumerate",1,true),"Full read error is inaccessible")
    assert(not next(k.UI.keyIndex) and not k.UI.apply:IsEnabled() and #Mock.writes==0)
end

function Tests.current_ui_unbinding_a_selected_live_action_clears_stale_details()
    local k=liveWarlock(); k.UI:Open(); k.UI:KeyboardKeyClick("F")
    assert(k.UI.selectedAction and k.UI.selectedAction.key=="F")
    Mock.bindings.F=nil; Mock:Fire("UPDATE_BINDINGS"); Mock:Advance(0.2)
    assert(not k.UI.selectedAction and not k.UI.pages.Bindings.keyboard.keys.F.action,"Removed live binding remained selected")
    assert(k.UI.pages.Bindings.detail.title:GetText()=="Select a binding","Detail retained the removed game action")
end
