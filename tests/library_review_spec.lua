function Tests.library_review_rejects_imported_macro_syntax_and_unresolved_spell_identity()
  local k=TestAddon; k:Init()
  local dangerous={kind="spell",spellID=99999999,name="Wrath; Healing Touch",rank="Rank 1",targeting="harm"}
  local ok,id=k.Library:Stage({descriptor=dangerous})
  if ok then
    local plan=k:Preview()
    assert(#plan.errors>0,"Unresolved imported spell emitted a castable macro from its supplied name")
    assert(not k:Apply(),"Unsafe imported spell reached binding installation")
  end
  local rank={kind="spell",spellID=5176,name="Wrath",rank="Rank 1);Healing Touch(",targeting="harm"}
  local action,why=k.Library:ResolveDescriptor("custom.review",rank)
  if action then
    assert(action.selectedRank=="Rank 1","Imported rank syntax replaced client-provided rank metadata")
  else assert(why,"Rejected descriptor has no explanation") end
  local payload="KBO2\nc\tDRUID\nn\tUnsafe\nu\tUnsafe\tcustom.1\tkind\tspell\nu\tUnsafe\tcustom.1\tspellID\t99999999\nu\tUnsafe\tcustom.1\tname\tWrath%3B Healing Touch\nu\tUnsafe\tcustom.1\trank\tRank 1\na\tUnsafe"
  local before=k.db.activePreset
  assert(not k.Presets:Import(payload),"Data-only import accepted macro control syntax")
  assert(k.db.activePreset==before,"Rejected import changed selected preset")
end

function Tests.library_review_rejects_excessive_custom_actions_before_mutating_presets()
  local k=TestAddon; k:Init(); local before=k.db.activePreset
  local payload={"KBO2","c\tDRUID","n\tToo large"}
  for n=1,600 do
    payload[#payload+1]="u\tToo large\tcustom."..n.."\tkind\temote"
    payload[#payload+1]="u\tToo large\tcustom."..n.."\temote\tWAVE"
  end
  payload[#payload+1]="a\tToo large"
  local ok,why=k.Presets:Import(table.concat(payload,"\n"))
  assert(not ok and why,"Excessive import was accepted and can force a long synchronous preview")
  assert(k.db.activePreset==before and not k.db.presets['Too large'],"Rejected oversized import partially mutated presets")
end
