local function currentProfileUI()
    local k=TestAddon; k:Init()
    local calls={sync=0,reapply=0,ready=true}
    k.Engine.CanReapplyCurrentProfile=function() return calls.ready,"Sync from game first." end
    k.Engine.SyncCurrentProfile=function() calls.sync=calls.sync+1; return true,"Current setup synced." end
    k.Engine.ReapplyCurrentProfile=function() calls.reapply=calls.reapply+1; return true,"Saved setup reapplied." end
    k.UI:Open(); Mock:ResetWrites()
    return k,k.UI,calls
end

function Tests.current_profile_ui_refresh_dispatches_both_directions_without_pending_edits()
    local k,ui,calls=currentProfileUI()
    assert(not k.CurrentBindings:HasEdits() and not ui.apply:IsEnabled())
    assert(ui.refreshCurrent:IsShown() and ui.refreshCurrent:IsEnabled())
    ui.refreshCurrent:Click()
    assert(ui.menu:IsShown() and ui.menu.panel.rows[1].text:GetText()=="Sync from game" and ui.menu.panel.rows[2].text:GetText()=="Reapply saved setup")
    assert(ui.menu.panel:GetPoint()=="BOTTOMRIGHT","Footer menu opens below the screen")
    ui.menu.panel.rows[1]:Click()
    assert(calls.sync==1 and calls.reapply==0 and not ui.menu:IsShown())
    ui.refreshCurrent:Click(); ui.menu.panel.rows[2]:Click()
    assert(calls.sync==1 and calls.reapply==1)
    assert(not ui.confirm or not ui.confirm:IsShown(),"Explicit refresh choice added a second confirmation")
    assert(#Mock.writes==0,"UI dispatch itself changed live controls")
end

function Tests.current_profile_ui_refresh_keeps_pending_current_and_preset_drafts()
    local k,ui,calls=currentProfileUI()
    local draft=k.CurrentBindings:Edits(); draft.keys.F9="OPENCHAT"; draft.expectedKeys.F9=""
    local before=k:Export()
    ui:Refresh(); assert(ui.apply:IsEnabled())
    ui.refreshCurrent:Click(); ui.menu.panel.rows[1]:Click()
    ui.refreshCurrent:Click(); ui.menu.panel.rows[2]:Click()
    assert(calls.sync==1 and calls.reapply==1)
    assert(k.CurrentBindings:Edits()==draft and draft.keys.F9=="OPENCHAT" and k.CurrentBindings:HasEdits(),"Refresh UI consumed Current edits")
    assert(k:Export()==before and ui.bindingSource=="current","Refresh UI saved or switched the preset draft")
end

function Tests.current_profile_ui_reapply_requires_saved_setup_and_shows_reason()
    local k,ui,calls=currentProfileUI(); calls.ready=false
    ui.refreshCurrent:Click()
    local rows=ui.menu.panel.rows
    assert(rows[1]:IsEnabled() and not rows[2]:IsEnabled())
    assert(rows[2].tipDetail=="Sync from game first.")
    rows[2]:Click(); assert(calls.reapply==0 and ui.menu:IsShown())
    assert(not ui:CurrentProfileAction("reapply") and calls.reapply==0)
    ui:CloseMenu(); calls.ready=true
    ui.refreshCurrent:Click(); assert(rows[2]:IsEnabled(),"Saved setup did not enable reapply on reopening")
    rows[2]:Click(); assert(calls.reapply==1)
    ui:Menu(ui.refreshCurrent,{{value="a",label="One"},{value="b",label="Two"}},nil,function() end)
    assert(rows[2]:IsEnabled() and rows[2].tipDetail==nil,"Refresh menu leaked disabled state or tooltip into another menu")
end

function Tests.current_profile_ui_refresh_is_guarded_during_combat_and_busy_work()
    local k,ui,calls=currentProfileUI()
    Mock.combat=true; ui:Refresh()
    assert(not ui.refreshCurrent:IsEnabled())
    ui.refreshCurrent:Click(); assert(not ui.menu or not ui.menu:IsShown())
    Mock.combat=false; ui:Refresh(); ui.refreshCurrent:Click()
    Mock.combat=true; ui.menu.panel.rows[1]:Click()
    assert(calls.sync==0,"Combat began after menu opening but sync still ran")
    Mock.combat=false; ui:Refresh(); ui.refreshCurrent:Click()
    k.Engine.busy=true; k.Engine.job={message="Test update",progress=0}
    ui.menu.panel.rows[2]:Click()
    assert(calls.reapply==0 and not ui.refreshCurrent:IsEnabled() and ui.busyOverlay:IsShown())
    ui.refreshCurrent:Click(); assert(calls.sync==0 and calls.reapply==0)
    k.Engine.busy=false; k.Engine.job=nil; ui:Refresh()
    assert(ui.refreshCurrent:IsEnabled(),"Refresh remained disabled after work finished")
end

function Tests.current_profile_ui_refresh_only_appears_in_current_and_fits_footer()
    local k,ui,calls=currentProfileUI()
    assert(ui.status:GetWidth()==350 and ui.refreshCurrent:GetWidth()==90)
    local _,right=ui.restore:GetPoint(); assert(right==-244)
    ui:SetBindingSource("draft")
    assert(not ui.refreshCurrent:IsShown() and ui.status:GetWidth()==440)
    local _,normalRight=ui.restore:GetPoint(); assert(normalRight==-184)
    ui.refreshCurrent:Click(); assert(not ui.menu or not ui.menu:IsShown())
    assert(not ui:CurrentProfileAction("sync") and calls.sync==0)
    ui:PreviewRecommendations(); assert(not ui.refreshCurrent:IsShown())
    ui:SetBindingSource("current"); ui:ShowPage("Safety")
    assert(not ui.refreshCurrent:IsShown())
    assert(not ui:CurrentProfileAction("reapply") and calls.reapply==0)
end

function Tests.current_profile_ui_refresh_failures_expose_named_details_and_success_clears_them()
    local k,ui,calls=currentProfileUI()
    k.Engine.SyncCurrentProfile=function() return false,"Cannot read the game bars." end
    ui.refreshCurrent:Click(); ui.menu.panel.rows[1]:Click()
    assert(ui.operationError and ui.operationError.kind=="current-sync" and ui.operationError.summary:find("Sync",1,true))
    assert(ui.operationErrorDialog:IsShown() and ui.reviewButton:GetText()=="Details" and ui.reviewButton:IsShown())
    assert(ui.operationError.details:find("Cannot read the game bars.",1,true))
    ui.operationErrorDialog.close:Click(); ui:ClearOperationError()
    k.Engine.ReapplyCurrentProfile=function() return false,"Saved spell unavailable." end
    ui.refreshCurrent:Click(); ui.menu.panel.rows[2]:Click()
    assert(ui.operationError.kind=="current-reapply" and ui.operationError.summary:find("Reapply",1,true))
    ui.operationErrorDialog.close:Click()
    k.Engine.ReapplyCurrentProfile=function() return true,"Saved setup reapplied." end
    ui.refreshCurrent:Click(); ui.menu.panel.rows[2]:Click()
    assert(not ui.operationError and not ui.operationErrorDialog:IsShown())
end
