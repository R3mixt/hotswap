function Tests.library_data_groups_future_catalogs_by_each_class_tree()
  local k=TestAddon; k:Init()
  local expected={DRUID={"Balance","Feral Combat","Restoration"},HUNTER={"Beast Mastery","Marksmanship","Survival"},MAGE={"Arcane","Fire","Frost"},PALADIN={"Holy","Protection","Retribution"},PRIEST={"Discipline","Holy","Shadow"},ROGUE={"Assassination","Combat","Subtlety"},SHAMAN={"Elemental","Enhancement","Restoration"},WARLOCK={"Affliction","Demonology","Destruction"},WARRIOR={"Arms","Fury","Protection"}}
  for class,trees in pairs(expected) do
    for _,flavor in ipairs({"era","forever"}) do
      local seen={}
      for _,definition in ipairs(k.Profiles:Get(class,flavor)) do
        local category,talent=k.LibraryData:Classify(class,definition,flavor)
        assert(type(category)=="string" and type(talent)=="boolean","Catalog classification is incomplete")
        seen[category]=true
      end
      for _,tree in ipairs(trees) do assert(seen[tree],class.." "..flavor.." lost its "..tree.." spell group") end
    end
  end
end

function Tests.library_data_keeps_era_and_forever_talents_separate_and_unknown_safe()
  local k=TestAddon; k:Init()
  local function entry(class,id,flavor)
    return k.LibraryData:Classify(class,{id=id},flavor)
  end
  local category,talent=entry("HUNTER","hunter.aimed_shot","era")
  assert(category=="Marksmanship" and talent,"Era Aimed Shot lost its talent requirement")
  category,talent=entry("HUNTER","hunter.aimed_shot","forever")
  assert(category=="Marksmanship" and not talent,"Forever trained Aimed Shot is falsely marked talent-only")
  category,talent=entry("DRUID","druid.insect_swarm.caster","era")
  assert(category=="Restoration" and talent,"Era Insect Swarm was assigned to the later Balance tree")
  category,talent=entry("DRUID","druid.insect_swarm.caster","forever")
  assert(category=="Balance" and talent,"Forever Insect Swarm has the wrong tree")
  category,talent=entry("WARRIOR","warrior.death_wish","era")
  assert(category=="Fury" and talent,"Source's transposed Warrior IDs leaked into Era grouping")
  category,talent=entry("WARRIOR","warrior.sweeping_strikes","era")
  assert(category=="Arms" and talent,"Era Sweeping Strikes has the wrong tree")
  category,talent=entry("MAGE","mage.unverified_new_spell","forever")
  assert(category=="General" and not talent,"Unknown new spell was assigned a speculative tree or talent")
  category,talent=entry("HUNTER","hunter.pet_bite","era")
  assert(category=="Pets" and not talent,"Pet spell was confused with a player talent")
end
