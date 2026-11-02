local function startBarUI()
    local k=TestAddon; k:Init(); k.UI:Open()
    -- UI tests exercise the NativeBars capability contract; real toggle/page
    -- detection and installation have separate NativeBars integration tests.
    k.NativeBars.GetBarOptions=function(_,plan,settings)
        local requested=settings.nativeBars
        return {
            {toggle=1,label="Action bar 2",available=true,shown=false,required=true,requested=requested[1]},
            {toggle=2,label="Action bar 3",available=true,shown=false,required=false,requested=requested[2]},
            {toggle=3,label="Action bar 4",available=true,shown=true,required=false,requested=requested[3]},
            {toggle=7,label="Action bar 8",available=false,shown=false,required=false,requested=requested[7]},
        }
    end
    k.UI.pages.Setup.nativeBars:Click()
    return k,k.UI.nativeBarsDialog
end

function Tests.native_bar_ui_distinguishes_required_optional_hidden_and_unsupported_bars()
    local k,f=startBarUI(); Mock:ResetWrites()
    assert(f:IsShown(),"Action bars button did not open its native dialog")
    local required,hidden,shown,unsupported=unpack(f.rows)
    assert(required.check:GetChecked() and not required.check:IsEnabled(),"Required hidden bar was not forced on")
    assert(required.state:GetText()=="Required by preset","Required behavior is unexplained")
    assert(hidden.check:IsEnabled() and not hidden.check:GetChecked(),"Available hidden bar cannot be enabled")
    assert(shown.check:IsEnabled() and shown.check:GetChecked(),"Current optional visibility was lost")
    assert(not unsupported.check:IsEnabled() and unsupported.state:GetText()=="Unavailable on this client","Unsupported bar looks merely hidden")
    assert(not k.UI:SetNativeBarPreference(1,false),"Required bar could be hidden")
    assert(not k.UI:SetNativeBarPreference(7,true),"Unsupported bar could be enabled")
    hidden.check:Click(); shown.check:Click()
    assert(k:GetSettings().nativeBars[2]==true and k:GetSettings().nativeBars[3]==false,"Optional on/off choices were not preserved")
    assert(hidden.check:GetChecked() and not shown.check:GetChecked(),"Explicit false fell through to current visible state")
    assert(shown.state:GetText()=="Hide when applied","Staged off preference is not clear")
    assert(#Mock.writes==0,"Checkboxes changed live bars before Use preset")
    f.reset:Click()
    assert(not next(k:GetSettings().nativeBars),"Defaults did not restore leave-unchanged behavior")
    assert(shown.check:GetChecked() and shown.state:GetText()=="Keep current visibility","Default visibility was not restored")
    Mock:KeyDown("ESCAPE"); Mock:Advance(0.05)
    assert(not f:IsShown() and k.UI.frame:IsShown(),"Escape closed the whole addon instead of the bar dialog")
end

function Tests.native_bar_ui_closes_during_async_apply_and_staged_choices_survive_presets()
    local k,f=startBarUI(); Mock.async=true
    k:GetSettings().allowAccountMacros=true -- Full Druid fixture needs both banks.
    assert(k.UI:SetNativeBarPreference(2,true))
    assert(k.Presets:Create("Extra bars",true))
    assert(k:GetSettings().nativeBars[2]==true,"Duplicating a preset dropped its bar preference")
    k:UpdateSetting("nativeBars",{[3]=false})
    assert(k.Presets:Select("Leveling"))
    assert(k:GetSettings().nativeBars[2]==true and k:GetSettings().nativeBars[3]==nil,"Presets shared their visibility map")
    assert(k.Presets:Activate("Leveling")=="pending")
    k.UI:Refresh()
    assert(not f:IsShown() and not k.UI.escapeModal,"Busy state retained an editable bar dialog")
    assert(not k.UI.pages.Setup.nativeBars:IsEnabled(),"Busy state left bar preferences enabled")
    local ok,why=Mock:Drain(); assert(ok,why)
end

function Tests.native_bar_preferences_export_import_roundtrip_and_reject_malformed_records()
    local k=TestAddon; k:Init(); Mock:ResetWrites()
    assert(k:UpdateSetting("nativeBars",{[1]=true,[2]=false,[7]=true}))
    local exported=k:Export("Leveling")
    assert(exported:find("v\tLeveling\t2\tfalse",1,true),"Export dropped an explicit off choice")
    assert(k:Import(exported))
    local bars=k:GetSettings().nativeBars
    assert(bars[1]==true and bars[2]==false and bars[7]==true and bars[3]==nil,"Bar preference roundtrip changed booleans or defaults")
    assert(#Mock.writes==0,"Import installed visibility preferences")
    local before=k:Export()
    for _,suffix in ipairs({"0\ttrue","8\ttrue","1.5\ttrue","01\ttrue","1\t1","1\tfalse\nv\tLeveling\t1\ttrue","2\tfalse\nv\tLeveling\t2\tfalse"}) do
        local ok=k:Import("KBO2\nc\tDRUID\nn\tLeveling\nv\tLeveling\t"..suffix.."\na\tLeveling")
        assert(not ok,"Malformed bar preference was accepted: "..suffix)
        assert(k:Export()==before,"Rejected import partially changed saved presets")
    end
    for _,invalid in ipairs({false,"1",{[0]=true},{[8]=false},{[1.5]=true},{["1"]=true},{[1]="true"}}) do
        assert(not k:UpdateSetting("nativeBars",invalid),"Invalid settings map was accepted")
        assert(k:Export()==before,"Invalid settings edit mutated a preset")
    end
end
