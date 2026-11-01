function Tests.rank_library_keeps_exact_learned_ranks_separate_from_highest_family()
  local k=TestAddon; k:Init()
  local book=k.API:GetCachedSpellbook()
  local exact=k.API:ResolveExact(5176,book)
  assert(exact.id==5176 and exact.rank=="Rank 1" and exact.known,"Explicit first rank was promoted")
  assert(exact.category=="Druid","Learned rank lost its spellbook category")
  assert(k.API:Resolve({name="Wrath",spellIDs={5176}},book).id==5177,"Family no longer picks highest learned rank")
  exact.id=1
  assert(k.API:GetExactSpell(5176).id==5176,"Library caller mutated the spellbook rank cache")
  local ranks=k.API:GetSpellRanks({name="Wrath",spellIDs={5176}},book)
  assert(#ranks==2 and ranks[1].id==5176 and ranks[2].id==5177,"Library did not enumerate both learned ranks")
end

function Tests.rank_library_validates_unknown_catalog_identity_without_promoting_knowledge()
  local k=TestAddon; k:Init()
  Mock.catalog[5178]={id=5178,name="Wrath",rank="Rank 3",icon=456}
  Mock.catalog[999999]={id=999999,name="Different spell",rank="Rank 4",icon=789}
  local exact=k.API:ResolveExact(5178)
  assert(exact and not exact.known and exact.rank=="Rank 3","Unlearned rank knowledge came from display metadata")
  assert(not k.API:GetExactSpell(5178),"Unlearned rank was returned as learned")
  local ranks=k.API:GetSpellRanks({name="Wrath",spellIDs={5176,5178,999999}})
  assert(#ranks==3 and ranks[3].id==5178 and not ranks[3].known,"Rank library omitted future rank or accepted mismatched identity")
  for _,entry in ipairs(k.API:GetLearnedRanks()) do assert(entry.id~=5178,"Future metadata contaminated learned-rank list") end
end
