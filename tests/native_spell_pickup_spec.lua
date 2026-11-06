-- Direct spell pickup can silently leave an empty cursor on a live client.
-- The fallback must recover the exact saved rank from the current spellbook.
local function ready()
 local k=TestAddon; k:Init(); return k
end
local function rejectDirectPickup()
 local calls={}
 local function reject(id) calls[#calls+1]=id end
 C_Spell.PickupSpell=reject; PickupSpell=reject
 return calls
end
local function exactBookPickup(expectedID,expectedBank)
 local calls={}
 local function pick(index,bank)
  calls[#calls+1]={index=index,bank=bank}
  assert(bank==expectedBank,"Spell pickup used the wrong spellbook bank")
  local spell=Mock.spells[index]
  assert(spell and spell.id==expectedID,"Spell pickup substituted another spell or rank")
  Mock.cursor={"spell",spell.id,"spell"}
 end
 return pick,calls
end
local function equalMap(actual,expected)
 for key,value in pairs(expected) do assert(actual[key]==value,"Changed binding: "..key) end
 for key,value in pairs(actual) do assert(expected[key]==value,"Unexpected binding: "..key) end
end

function Tests.native_spell_pickup_modern_empty_cursor_falls_back_to_exact_rank()
 local k=ready(); local direct=rejectDirectPickup()
 local pick,calls=exactBookPickup(5176,Enum.SpellBookSpellBank.Player)
 C_SpellBook.PickupSpellBookItem=pick
 k.NativeBars:WriteSlot(107,{kind="spell",id=5176})
 assert(#direct>0 and direct[1]==5176,"Direct pickup did not try the saved spell ID")
 assert(#calls==1 and calls[1].index==1,"Exact learned rank was not picked from its book slot")
 assert(select(2,GetActionInfo(107))==5176 and not GetCursorInfo())
end

function Tests.native_spell_pickup_legacy_empty_cursor_uses_legacy_slot_and_bank()
 local k=ready(); C_SpellBook=nil; C_Spell.PickupSpell=nil
 local tried
 PickupSpell=function(id) tried=id end
 local pick,calls=exactBookPickup(5176,BOOKTYPE_SPELL)
 PickupSpellBookItem=pick
 k.NativeBars:WriteSlot(107,{kind="spell",id=5176})
 assert(tried==5176 and #calls==1 and calls[1].index==1)
 assert(select(2,GetActionInfo(107))==5176 and not GetCursorInfo())
end

function Tests.native_spell_pickup_success_never_scans_or_uses_fallback()
 local k=ready(); local calls=0
 C_Spell.PickupSpell=function(id) calls=calls+1; Mock.cursor={"spell",id,"spell"} end
 k.API.ScanSpellbook=function() error("Successful direct pickup rescanned the spellbook") end
 C_SpellBook.PickupSpellBookItem=function() error("Successful direct pickup tried a fallback") end
 k.NativeBars:WriteSlot(107,{kind="spell",id=5176})
 assert(calls==1 and select(2,GetActionInfo(107))==5176 and not GetCursorInfo())
end

function Tests.native_spell_pickup_rescans_when_cached_rank_slot_has_moved()
 local k=ready(); local cached=k.API:GetCachedSpellbook()
 assert(cached.byExactID[5176].index==1)
 Mock.spells[1],Mock.spells[2]=Mock.spells[2],Mock.spells[1]
 assert(k.API.spellbook==cached and Mock.spells[1].id==5177,"Fixture did not retain a stale rank slot")
 rejectDirectPickup()
 local pick,calls=exactBookPickup(5176,Enum.SpellBookSpellBank.Player)
 C_SpellBook.PickupSpellBookItem=pick
 k.NativeBars:WriteSlot(107,{kind="spell",id=5176})
 assert(#calls==1 and calls[1].index==2,"Fallback reused the stale cached spellbook position")
 assert(select(2,GetActionInfo(107))==5176 and not GetCursorInfo())
end

function Tests.native_spell_pickup_unavailable_rank_preserves_destination_and_reports_identity()
 local k=ready(); k.API:GetCachedSpellbook()
 Mock.catalog[5176]={id=5176,name="Wrath",rank="Rank 1"}
 table.remove(Mock.spells,1)
 assert(Mock.spells[1].id==5177,"Fixture needs a learned higher rank of the same spell")
 rejectDirectPickup()
 C_SpellBook.PickupSpellBookItem=function() error("Unavailable rank was replaced by a learned spell") end
 Mock.actions[107]={"item",1234}; Mock:ResetWrites()
 local ok,why=pcall(k.NativeBars.WriteSlot,k.NativeBars,107,{kind="spell",id=5176})
 assert(not ok and tostring(why):find("5176",1,true) and tostring(why):find("Wrath",1,true)
  and tostring(why):find("spell",1,true),"Pickup failure omitted the saved action identity: "..tostring(why))
 assert(GetActionInfo(107)=="item" and select(2,GetActionInfo(107))==1234,"Failed pickup changed the existing destination")
 assert(#Mock.writes==0 and not GetCursorInfo(),"Failed pickup wrote actions or left a cursor")
end

local function namedRestoreFixture()
 local k=ready(); Mock:AllowFullCatalogMacros()
 Mock.actions[1]={"spell",774,"spell"}; Mock.actions[107]={"spell",5176,"spell"}
 local bindings=k.Copy(Mock.bindings)
 local ok,why=k:Apply(); assert(ok,why)
 local id=k.Engine:ListBackups()[1].id
 assert(k.db.bindingBackups[id].snapshot.native.actions[107].id==5176)
 -- Keep a different usable rank in the live slot to exercise restoration.
 Mock.actions[107]={"spell",5177,"spell"}
 return k,id,bindings
end

function Tests.native_spell_pickup_named_restore_recovers_slot_107_through_exact_fallback()
 local k,id,bindings=namedRestoreFixture()
 local pickup=C_Spell.PickupSpell; local directCalls=0
 C_Spell.PickupSpell=function(spellID)
  if spellID==5176 then directCalls=directCalls+1; return end
  return pickup(spellID)
 end
 PickupSpell=C_Spell.PickupSpell
 local pick,calls=exactBookPickup(5176,Enum.SpellBookSpellBank.Player)
 C_SpellBook.PickupSpellBookItem=pick
 local ok,why=k.Engine:RestoreBackup(id); assert(ok,why)
 assert(directCalls>0 and #calls==1,"Named restore did not exercise exact-rank fallback")
 assert(select(2,GetActionInfo(107))==5176 and select(2,GetActionInfo(1))==774)
 equalMap(Mock.bindings,bindings)
 assert(not k.db.enabled and not GetCursorInfo())
 assert(k.Engine:ListBackups()[1].status=="restored","Successful restore lost its undo backup")
end

function Tests.native_spell_pickup_named_restore_unavailable_rank_rolls_back_without_substitution()
 local k,id=namedRestoreFixture()
 local before=k.NativeBars:Snapshot(); local bindings=k.Copy(Mock.bindings)
 local applied=k.db.appliedPlan; local pickup=C_Spell.PickupSpell; local rejected=false
 Mock.catalog[5176]={id=5176,name="Wrath",rank="Rank 1"}
 table.remove(Mock.spells,1)
 C_Spell.PickupSpell=function(spellID)
  if spellID==5176 then rejected=true; return end
  return pickup(spellID)
 end
 PickupSpell=C_Spell.PickupSpell
 C_SpellBook.PickupSpellBookItem=function() error("Restore substituted another learned rank") end
 local ok,why=k.Engine:RestoreBackup(id)
 assert(not ok and rejected and tostring(why):find("rolled back",1,true),tostring(why))
 assert(tostring(why):find("107",1,true) and tostring(why):find("5176",1,true),tostring(why))
 for slot,content in pairs(before.actions) do
  assert(k.NativeBars:SameContent(k.NativeBars:ReadSlot(slot),content),"Failed restore did not recover action slot "..slot)
 end
 equalMap(Mock.bindings,bindings)
 assert(k.db.enabled and k.db.appliedPlan.class==applied.class and not GetCursorInfo())
 assert(k.Engine:ListBackups()[1].status=="failed" and k.db.bindingBackups[id],"Failed restore discarded a recovery backup")
end
