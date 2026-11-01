local function readyItems() local k=TestAddon; k:Init(); return k end
local function itemAction(plan,id) for _,action in ipairs(plan.actions) do if action.id==id then return action end end end
local function has(value,needle) return type(value)=="string" and value:find(needle,1,true)~=nil end
local function macroBody(action) local _,_,body=GetMacroInfo(GetMacroIndexByName(action.macroName)); return body end

function Tests.item_binding_missing_selection_does_not_silently_use_a_saved_alternative()
  local k=readyItems()
  Mock.itemInfo[9001]={name="Selected Potion",effect="Heal"}; Mock.itemInfo[9002]={name="Other Potion",effect="Heal"}
  Mock.bagItems[0]={{id=9002}}
  assert(k.Items:SetBindingItem("item.potion",9001)); assert(k.Items:AddAlternative("item.potion",9002))
  local current=k.Items:ResolveBinding("item.potion")
  assert(current.selectedID==9001 and current.id==9001 and current.missing and not current.known,"Saved alternative silently replaced missing primary")
  local plan=k:Preview(); local action=itemAction(plan,"item.potion")
  assert(action.itemID==9001 and not action.known and not has(action.body,"/use"),"Missing selection activated another item")
  assert(k.Items:SetBindingItem("item.potion",9002)); action=itemAction(k:Preview(),"item.potion")
  assert(action.known and action.itemID==9002,"Manual saved-choice selection did not change the item")
end

function Tests.item_binding_arrival_updates_only_installed_macro_and_preserves_staged_selection()
  local k=readyItems(); Mock.async=true
  Mock.itemInfo[9001]={name="Installed Potion",effect="Heal"}; Mock.itemInfo[9002]={name="Staged Potion",effect="Heal"}
  assert(k.Items:SetBindingItem("item.potion",9001))
  assert(k:Apply()=="pending"); local ok,why=Mock:Drain(); assert(ok,why)
  local installed=itemAction(k.db.appliedPlan,"item.potion")
  assert(not installed.known and not has(macroBody(installed),"/use"),"Missing item did not start inert")
  assert(k.Items:SetBindingItem("item.potion",9002))
  Mock.bagItems[0]={{id=9001},{id=9002}}; Mock:ResetWrites(); Mock:Fire("BAG_UPDATE_DELAYED")
  ok,why=Mock:Drain(); assert(ok,why)
  assert(installed.known and installed.itemID==9001 and has(macroBody(installed),"/use item:9001"),"Item arrival used staged settings instead of the installed item")
  assert(k:GetSettings().itemBindings["item.potion"].selected==9002 and k.dirty,"Item refresh discarded or applied staged selection")
  for _,write in ipairs(Mock.writes) do assert(write[1]~="binding" and write[1]~="action","Item arrival rebuilt bindings or bar placement") end
  Mock.combat=true; Mock.bagItems[0]={}; Mock:ResetWrites(); Mock:Fire("BAG_UPDATE_DELAYED")
  assert(k.pendingItemMaintenance and #Mock.writes==0,"Item maintenance wrote protected state in combat")
  Mock.combat=false; Mock:Fire("PLAYER_REGEN_ENABLED"); ok,why=Mock:Drain(); assert(ok,why)
  assert(not installed.known and not has(macroBody(installed),"/use"),"Missing installed item did not return to an inert macro")
end

function Tests.item_binding_target_modes_use_verified_item_semantics_not_generic_helpful_flags()
  local k=readyItems()
  IsHelpfulItem=function() return true end; IsHarmfulItem=function() return true end
  local function modes(id) local found={}; for _,mode in ipairs(k.Items:GetTargetModes({itemID=id})) do found[mode]=true end; return found end
  assert(modes(14530).focus and modes(14530).self and modes(14530).mouseover,"Bandage unit targeting is incomplete")
  for _,id in ipairs({10720,10645,10716,4388}) do
    local value=modes(id); assert(value.focus and value.mouseover and value.target and not value.self,"Engineering unit target modes are wrong")
  end
  for _,id in ipairs({117,3928,10577,4380,9003}) do
    local value=k.Items:GetTargetModes({itemID=id}); assert(#value==1 and value[1]=="default","Food, ground device or unknown item was treated as a unit-target spell")
  end
  assert(k.Items:GetTargetInfo({itemID=10577}).kind=="ground","Mortar is not explicitly marked ground-targeted")
  assert(not k.Items:GetTargetInfo({itemID=9003}).verified,"Unknown target type is presented as verified")
  assert(k.Items:SetBindingItem("item.utility",10577)); assert(not k.Items:SetBindingTargetMode("item.utility","focus"),"Ground device accepted focus override")
end

function Tests.item_binding_unequipped_gear_stays_inert_and_fixed_trinkets_remain_slot_based()
  local k=readyItems(); Mock.itemInfo[10720]={name="Gnomish Net-o-Matic Projector",effect="Net-o-Matic",equipLoc="INVTYPE_TRINKET"}
  Mock.bagItems[0]={{id=10720}}
  assert(k.Items:SetBindingItem("item.utility",10720))
  local action=itemAction(k:Preview(),"item.utility")
  assert(not action.known and action.requiresEquip and not has(action.body,"/use"),"Bag equipment binding can equip rather than use")
  assert(not k.Items:SetBindingItem("item.trinket13",10720),"Upper trinket stopped following equipped slot")
  Mock.equipment[13]=10720; k.Items:Invalidate()
  action=itemAction(k:Preview(),"item.utility")
  assert(action.known and action.itemSlot==13 and has(action.body,"/use [harm,nodead] 13") and not has(action.body,"/use item:"),"Equipped on-use item was not resolved safely to its slot")
end

function Tests.item_binding_clear_suppresses_fallback_preserves_choices_and_rejects_bad_import_data()
  local k=readyItems(); Mock.itemInfo[9001]={name="Selected Potion",effect="Heal"}; Mock.bagItems[0]={{id=9001}}
  assert(k.Items:SetBindingItem("item.potion",9001)); assert(k.Items:SetBindingItem("item.potion",nil))
  local record=k:GetSettings().itemBindings["item.potion"]
  assert(record.empty and not record.selected and record.alternatives[1]==9001,"Clearing removed saved choices or kept selection")
  assert(not k.Items:ResolveBinding("item.potion",9001),"Cleared binding silently resurrected fallback item")
  local action=itemAction(k:Preview(),"item.potion")
  assert(not action.itemID and not action.itemSlot and not action.known,"Cleared binding still has an item")
  assert(not k.Items:ValidateBinding({selected=10577,targetMode="focus"}),"Imported mortar focus override bypassed item semantics")
  assert(not k.Items:ValidateBinding({selected=9001,alternatives={[1]=9001,[3]=9002}}),"Sparse saved choices accepted")
  assert(not k.Items:ValidateBinding({selected=9001,body="/run arbitrary"}),"Raw macro text accepted in item binding")
end

function Tests.item_binding_library_items_and_manual_choices_roundtrip_in_a_preset()
  local k=readyItems(); Mock.itemInfo[14530]={name="Heavy Runecloth Bandage",effect="First Aid"}; Mock.bagItems[0]={{id=14530}}
  local entry=k.Items:LibraryEntries()[1]
  assert(entry.itemID==14530 and entry.descriptor.kind=="item" and entry.known,"Item library metadata incomplete")
  local ok,id=k.Library:Stage(entry,"focus"); assert(ok,id)
  k:GetSettings().bindingOverrides[id]="CTRL-SHIFT-F20"
  assert(k.Items:AddAlternative(id,1251))
  local exported,why=k.Presets:Export("Leveling"); assert(exported,why)
  local imported,message=k.Presets:Import(exported); assert(imported,message)
  local record=k:GetSettings().itemBindings[id]
  assert(record and record.selected==14530 and record.alternatives[2]==1251 and record.targetMode=="focus","Per-key item settings did not survive import")
  local action=itemAction(k:Preview(),id)
  assert(action and action.key=="CTRL-SHIFT-F20" and has(action.body,"@focus,help,nodead"),"Imported item binding lost its key or target semantics")
end

function Tests.item_binding_shared_macro_is_updated_once_for_multiple_keys()
  local k=readyItems(); Mock.async=true
  Mock.itemInfo[9001]={name="Shared Potion",effect="Heal"}
  assert(k.Items:SetBindingItem("item.utility",9001)); assert(k.Items:SetBindingItem("item.potion",9001))
  assert(k:Apply()=="pending"); local ok,why=Mock:Drain(); assert(ok,why)
  local first=itemAction(k.db.appliedPlan,"item.utility"); local second=itemAction(k.db.appliedPlan,"item.potion")
  assert(first.macroName==second.macroName,"Fixture did not share its identical inert macro")
  Mock.bagItems[0]={{id=9001}}; Mock:ResetWrites(); Mock:Fire("BAG_UPDATE_DELAYED")
  ok,why=Mock:Drain(); assert(ok,why)
  assert(first.known and second.known and has(macroBody(first),"/use item:9001"),"Shared item maintenance did not update both action records")
  local count=0; for _,event in ipairs(Mock.writes) do if event[1]=="editmacro" then count=count+1 end end
  assert(count==1,"Shared macro was edited more than once")
end

function Tests.item_binding_different_target_modes_remain_distinct_before_item_arrives()
  local k=readyItems(); Mock.async=true
  Mock.itemInfo[14530]={name="Heavy Runecloth Bandage",effect="First Aid"}
  assert(k.Items:SetBindingItem("item.utility",14530)); assert(k.Items:SetBindingTargetMode("item.utility","focus"))
  assert(k.Items:SetBindingItem("item.potion",14530)); assert(k.Items:SetBindingTargetMode("item.potion","mouseover"))
  assert(k:Apply()=="pending"); local ok,why=Mock:Drain(); assert(ok,why)
  local first=itemAction(k.db.appliedPlan,"item.utility"); local second=itemAction(k.db.appliedPlan,"item.potion")
  assert(first.macroName~=second.macroName and not has(macroBody(first),"/use") and not has(macroBody(second),"/use"),"Distinct future item target modes shared an executable or ambiguous placeholder")
  Mock.bagItems[0]={{id=14530}}; Mock:Fire("BAG_UPDATE_DELAYED")
  ok,why=Mock:Drain(); assert(ok,why)
  assert(has(macroBody(first),"@focus,help,nodead") and has(macroBody(second),"@mouseover,help,nodead"),"Item arrival lost the per-binding target modes")
end
