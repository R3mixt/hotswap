local primary,alternate="priest.power_infusion","priest.mind_flay"
local function ready()
    Mock.class="PRIEST"; Mock.build="1.15.9"; Mock.buildNumber="70576"
    Mock.spells={}; Mock.petSpells={}; Mock.forms={}; Mock.catalog={}
    Mock:Learn(585,"Smite","Rank 1"); Mock:Learn(15407,"Mind Flay","Rank 1")
    Mock.catalog[10060]={id=10060,name="Power Infusion",icon=135939}
    local k=TestAddon; k:Init()
    assert(k.TalentBindings:SetChoices(primary,{primary,alternate}))
    Mock:ResetWrites(); return k
end
local function action(k,id)
    local plan=k:Preview(); assert(#plan.errors==0,table.concat(plan.errors,"; "))
    for _,entry in ipairs(plan.actions) do if entry.id==id then return entry end end
    error("Missing action "..id)
end
local function shared(k) return k:GetSettings().talentAlternatives[primary] end

function Tests.talent_library_fixed_rank_freezes_the_selected_family_and_failed_rank_keeps_choices()
    local k=ready(); local before=k:Export()
    assert(action(k,primary).spellID==15407,"Fixture did not select the learned alternate")
    local ok=k.Library:SetRank(primary,585)
    assert(not ok and k:Export()==before,"Rejected rank changed shared choices or other draft state")
    local key=action(k,primary).key
    local why; ok,why=k.Library:SetRank(primary,15407); assert(ok,why)
    assert(not shared(k),"Fixed rank left an incompatible shared group")
    local fixed=action(k,primary)
    assert(fixed.spellID==15407 and fixed.explicitRank and fixed.key==key,"Fixing the alternate rank reverted to the primary spell family")
    assert(not fixed.body and fixed.spellID==15407,"Fixed alternate rank should use its native spell ID")
    assert(k:GetSettings().actionOverrides[primary].replacement.sourceID==alternate,"Alternate family was not preserved")
    assert(k.Library:SetRank(primary,nil))
    assert(action(k,primary).spellName=="Mind Flay","Returning to highest rank changed the frozen family")
    assert(#Mock.writes==0,"Rank editing installed a live action")
end

function Tests.talent_library_replacement_clears_only_accepted_destination_choices_and_copies_displayed_family()
    local k=ready(); local before=k:Export()
    local ok=k.Library:Place({descriptor={kind="spell",spellID=999999,name="Missing"}},primary)
    assert(not ok and k:Export()==before,"Failed replacement cleared shared choices")
    local displayed
    for _,entry in ipairs(k.Library:List({tab="spells"})) do if entry.actionID==primary then displayed=entry end end
    -- Shared and original copies are deduplicated in the library. The actual
    -- drop contract still uses the selected action ID as its source reference.
    displayed=displayed or {actionID=primary,label="Mind Flay"}
    ok=k.Library:Place(displayed,"priest.smite"); assert(ok)
    local copy=action(k,"priest.smite")
    assert(copy.spellName=="Mind Flay" and copy.librarySourceID==alternate,"Dropping a displayed alternate copied the old primary instead")
    assert(shared(k),"Copying from a shared key destroyed the source's choices")
    ok=k.Library:Place({descriptor={kind="spell",spellID=585,name="Smite",rank="Rank 1",targeting="harm"}},primary); assert(ok)
    assert(not shared(k) and action(k,primary).spellID==585,"Accepted replacement left its destination group invalid")
    assert(#Mock.writes==0,"Replacing a shared action wrote live bindings or bars")
end

function Tests.talent_library_target_modes_intersect_every_choice_and_rejected_staging_restores_state()
    local k=ready(); Mock:Learn(10060,"Power Infusion")
    k.API:ScanSpellbook(); k:InvalidatePreview()
    local selected=action(k,primary); assert(selected.spellID==10060)
    local modes=k.Library:TargetModes(selected); local hasSelf=false
    for _,mode in ipairs(modes) do if mode=="self" then hasSelf=true end end
    assert(not hasSelf,"Target menu offered self-cast while a harmful alternative could later be selected")
    local before=k:Export()
    local ok,why=k.Library:SetTargetMode(primary,"self")
    assert(not ok and why:find("every talent choice",1,true) and k:Export()==before,"Invalid shared targeting changed the draft")
    ok=k.Library:Stage({actionID=primary},"self")
    assert(not ok and k:Export()==before and shared(k),"Rejected staged target edit left shared choices or overrides behind")
    assert(k.Library:SetTargetMode(primary,"target"))
    assert(shared(k) and action(k,primary).targetMode=="target","Compatible targeting removed the shared group")
    assert(#Mock.writes==0,"Target editing wrote live game state")
end

function Tests.talent_library_reset_restores_primary_and_default_targeting_when_alternate_mode_is_incompatible()
    local k=TestAddon; k:Init()
    Mock:AllowFullCatalogMacros() -- Full Druid catalog; target validation is independent of capacity.
    assert(k.TalentBindings:SetChoices("druid.form_moonkin",{"druid.swiftmend"}))
    assert(k.Library:SetTargetMode("druid.form_moonkin","mouseover"))
    assert(action(k,"druid.form_moonkin").spellName=="Swiftmend")
    Mock:ResetWrites()
    local ok,why=k.TalentBindings:SetChoices("druid.form_moonkin",{}); assert(ok,why)
    assert(why:find("Default",1,true),"Reset did not explain its targeting change")
    assert(not k:GetSettings().talentAlternatives["druid.form_moonkin"],"Reset retained the configured group")
    assert(not k:GetSettings().actionOverrides["druid.form_moonkin"].targetMode,"Reset retained incompatible mouseover targeting")
    local restored=action(k,"druid.form_moonkin")
    assert(restored.spellName=="Moonkin Form" and not restored.targetMode,"Reset left the original primary invalid")
    assert(#Mock.writes==0,"Resetting choices applied live changes")
end
