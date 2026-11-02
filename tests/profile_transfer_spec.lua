local function readyTransfer()
    local k=TestAddon; k:Init(); Mock:ResetWrites(); return k
end
function Tests.profile_transfer_preserves_current_draft_identity_preview_and_settings()
    local k=readyTransfer()
    local payload=k:Export('Leveling')
    k.db.settings.wheel=false
    local settings=k.db.settings; local plan={marker=true}; k.plan=plan; k.previewValid=true; k.dirty=false
    local ok,why,names=k:Import(payload); assert(ok,why)
    assert(names[1]=='Leveling (2)')
    assert(k.db.activePreset=='Leveling' and k.db.settings==settings and settings.wheel==false)
    assert(k.plan==plan and k.previewValid==true and k.dirty==false)
    assert(k.db.presets['Leveling (2)'].settings.wheel==true)
    assert(#Mock.writes==0)
end
function Tests.profile_transfer_validator_exception_is_atomic()
    local k=readyTransfer(); local original=k.db.presets; local settings=k.db.settings
    local serial=k.db.nextPresetID; local payload='KBO2\nc\tDRUID\nn\tIncoming\nh\tIncoming\tCTRL-F24\na\tIncoming'
    k.Presets.SetHotkey=function() error('injected validator failure') end
    local ok,why=k:Import(payload)
    assert(not ok and why:find('no presets were added',1,true))
    assert(k.db.presets==original and not k.db.presets.Incoming)
    assert(k.db.settings==settings and k.db.nextPresetID==serial and #Mock.writes==0)
end
function Tests.profile_transfer_downloaded_utf8_bom_crlf_and_surrounding_space()
    local k=readyTransfer(); local payload=k:Export('Leveling')
    local ok,why=k:Import('\239\187\191\r\n '..payload:gsub('\n','\r\n')..'\r\n ')
    assert(ok,why); assert(k.db.presets['Leveling (2)'])
    assert(k.db.activePreset=='Leveling' and #Mock.writes==0)
end
function Tests.profile_transfer_suffix_collisions_do_not_overwrite_either_import()
    local k=readyTransfer()
    local ok,why=k:Import('KBO2\nc\tDRUID\nn\tLeveling\nn\tLeveling (2)\na\tLeveling')
    assert(ok,why)
    assert(k.db.presets['Leveling (2)'] and k.db.presets['Leveling (2) (2)'])
    assert(k.db.presets['Leveling (2)'].id~=k.db.presets['Leveling (2) (2)'].id)
end
function Tests.profile_transfer_rejects_unsafe_legacy_numbers_and_invalid_keys()
    local k=readyTransfer(); local serial=k.db.nextPresetID
    for _,data in ipairs({'s\tmount\tnumber\t1e309','s\tmount\tnumber\t-1','s\tmount\tstring\tspell:0','b\tdruid.wrath.caster\t/run evil()'}) do
        assert(not k:Import('KBO1\n'..data..'\na\tLeveling'),data)
    end
    assert(k.db.nextPresetID==serial and #Mock.writes==0)
end
function Tests.profile_transfer_malformed_data_never_partially_imports()
    local k=readyTransfer(); local serial=k.db.nextPresetID
    local prefix='KBO2\nc\tDRUID\nn\tIncoming\n'
    for _,line in ipairs({'u\tIncoming\tcustom.1\tbody\t/run evil()', 's\tIncoming\tflavor\tstring\tnonsense','p\tIncoming\tpotion\t1e309','n\tIncoming','garbage','b\tIncoming\tmode.p1\tQ'}) do
        assert(not k:Import(prefix..line),line)
        assert(not k.db.presets.Incoming and k.db.nextPresetID==serial)
    end
    assert(not k:Import(string.rep('x',2000001)))
    assert(#Mock.writes==0)
end
function Tests.profile_transfer_imported_shortcut_invalidates_cached_plan_without_switching_settings()
    local k=readyTransfer(); Mock:AllowFullCatalogMacros()
    local settings=k.db.settings; local before=k:PreviewCached()
    local ok,why=k:Import('KBO2\nc\tDRUID\nn\tIncoming\nh\tIncoming\tCTRL-F24\na\tIncoming')
    assert(ok,why); assert(k.db.presets.Incoming.hotkey=='CTRL-F24')
    assert(k.db.activePreset=='Leveling' and k.db.settings==settings)
    assert(not k.previewValid)
    local after=k:PreviewCached(); assert(after~=before)
    local found=false
    for _,action in ipairs(after.actions) do if action.presetName=='Incoming' then found=action.key=='CTRL-F24' end end
    assert(found and #Mock.writes==0)
end
