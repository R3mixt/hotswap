local _, K = ...

-- Curated layouts, not claimed to be a consensus of professional players.
-- IDs identify spell families. The live spellbook, never this catalog, decides
-- whether an action is learned. New Forever spells may resolve by their exact
-- learned name until a verified client ID is available. See docs/research.md.
K.Profiles = {}
local P = K.Profiles
P.classes = {"DRUID", "MAGE", "WARRIOR", "ROGUE", "HUNTER", "PRIEST", "PALADIN", "SHAMAN", "WARLOCK"}
P.version = 2

local function copy(value)
    if type(value) ~= "table" then return value end
    local result = {}
    for key, child in pairs(value) do result[key] = copy(child) end
    return result
end

local function add(list, id, name, ids, key, category, targeting, extra)
    local entry = {
        id = id, name = name, spellIDs = ids or {}, key = key,
        category = category or "Attack", targeting = targeting or "harm",
        form = "all", priority = 40,
        source = "Curated functional layout; see docs/research.md",
    }
    for field, value in pairs(extra or {}) do entry[field] = value end
    list[#list + 1] = entry
    return entry
end

local function focus(list, original, key)
    local item = copy(original)
    item.id = original.id .. ".focus"
    item.key, item.targeting, item.focusOf = key, "focus", original.id
    item.name = original.name
    list[#list + 1] = item
    return item
end

local function addRows(list, class, rows)
    for _, row in ipairs(rows) do
        local item = add(list, class .. "." .. row[1], row[2], row[3], row[4], row[5], row[6], row[7])
        if row[8] then focus(list, item, row[8]) end
    end
end

local function druid(flavor)
    local list = {}
    local forever = flavor == "forever"
    local function d(id, name, ids, key, category, target, extra)
        return add(list, "druid." .. id, name, ids, key, category, target, extra)
    end
    -- The same persistent bank is used in every druid talent build.
    local utility = {priority = 10, cancelForm = true}
    d("rejuvenation", "Rejuvenation", {774}, "Q", "Healing", "help", utility)
    d("regrowth", "Regrowth", {8936}, "E", "Healing", "help", utility)
    d("swiftmend", "Swiftmend", {18562}, "SHIFT-Q", "Healing", "help", utility)
    d("healing_touch", "Healing Touch", {5185}, "SHIFT-E", "Healing", "help", utility)
    if forever then d("wild_growth", "Wild Growth", {}, "B", "Healing", "help", utility) end
    d("tranquility", "Tranquility", {740}, "SHIFT-B", "Healing", "self", {cancelForm = true, priority = 20})
    d("barkskin", "Barkskin", {22812}, "F", "Defense", "self", {priority = 1, cancelForm = not forever})
    d("natures_grasp", "Nature's Grasp", {16689}, "SHIFT-F", "Defense", "self", {priority = 10, cancelForm = not forever})
    d("frenzied_regeneration", "Frenzied Regeneration", {22842}, "G", "Defense", "self", {requiresForm = "bear", priority = 2})
    local roots = d("roots", "Entangling Roots", {339}, "C", "Control", "harm", {cancelForm = true, priority = 10})
    focus(list, roots, "SHIFT-C")
    local sleep = d("hibernate", "Hibernate", {2637}, "Z", "Control", "harm", {cancelForm = true, priority = 20})
    focus(list, sleep, "SHIFT-Z")
    d("remove_curse", "Remove Curse", {2782}, "V", "Dispel", "help", utility)
    d("abolish_poison", "Abolish Poison", {2893}, "SHIFT-V", "Dispel", "help", utility)
    d("cure_poison", "Cure Poison", {8946}, "CTRL-V", "Dispel", "help", utility)
    d("innervate", "Innervate", {29166}, "X", "Utility", "help", utility)
    d("rebirth", "Rebirth", {20484}, "SHIFT-X", "Resurrection", "dead", utility)
    if forever then d("revive", "Revive", {}, "CTRL-X", "Resurrection", "dead", utility) end
    local bash = d("bash", "Bash", {5211}, "BUTTON4", "Control", "harm", {requiresForm = "bear", priority = 3})
    focus(list, bash, "SHIFT-BUTTON4")
    d("dash", "Dash", {1850}, "BUTTON5", "Movement", "self", {requiresForm = "cat", priority = 5})
    local charge = d("feral_charge", "Feral Charge", {16979}, "SHIFT-BUTTON5", "Movement", "harm", {requiresForm = "bear", priority = 5})
    focus(list, charge, "CTRL-BUTTON5")
    d("natures_swiftness_heal", "Nature's Swiftness + Healing Touch", {17116}, "SHIFT-G", "Healing", "self", {combo = {17116, 5185}, cancelForm = true, priority = 2})
    d("natures_swiftness", "Nature's Swiftness", {17116}, "CTRL-G", "Healing", "none", {priority = 5})
    d("mark", "Mark of the Wild", {1126}, "CTRL-Q", "Buff", "help", utility)
    d("thorns", "Thorns", {467}, "CTRL-E", "Buff", "help", utility)
    d("gift", "Gift of the Wild", {21849}, "CTRL-B", "Buff", "help", utility)
    d("omen", "Omen of Clarity", {16864}, "CTRL-4", "Buff", "self", {cancelForm = true})
    d("soothe", "Soothe Animal", {2908}, "CTRL-C", "Utility", "harm", {cancelForm = true, spellNames = {"Soothe Animal", "Soothe"}})
    d("teleport_moonglade", "Teleport: Moonglade", {18960}, "CTRL-6", "Travel", "none", {cancelForm = true, priority = 90})

    d("form_bear", "Dire Bear Form", {9634, 5487}, "MOUSEWHEELUP", "Forms", "form", {formType = "bear", spellNames = {"Dire Bear Form", "Bear Form"}, priority = 1})
    d("form_cat", "Cat Form", {768}, "MOUSEWHEELDOWN", "Forms", "form", {formType = "cat", priority = 1})
    d("form_travel", "Travel Form", {783}, "SHIFT-MOUSEWHEELUP", "Forms", "form", {formType = "travel", priority = 5})
    d("form_aquatic", "Aquatic Form", {1066}, "SHIFT-MOUSEWHEELDOWN", "Forms", "form", {formType = "aquatic", priority = 30})
    d("form_moonkin", "Moonkin Form", {24858}, "CTRL-MOUSEWHEELUP", "Forms", "form", {formType = "moonkin", priority = 10})
    d("prowl", "Prowl", {5215}, "CTRL-MOUSEWHEELDOWN", "Forms", "none", {nonToggle = true, requiresForm = "cat", priority = 5})
    if not forever then
        d("powershift_cat", "Cat Form", {768}, "CTRL-R", "Forms", "form", {formType = "cat", powerShift = true, priority = 30})
    end

    -- Each combat state is a complete, independent 12-slot bank. Even the
    -- caster and moonkin banks are explicit; a healer spec does not move them.
    local caster = {
        {"wrath", "Wrath", {5176}, "1", "Attack", "harm"},
        {"moonfire", "Moonfire", {8921}, "2", "Attack", "harm"},
        {"starfire", "Starfire", {2912}, "3", "Attack", "harm"},
        {"insect_swarm", "Insect Swarm", {5570}, "4", "Attack", "harm"},
        {"faerie_fire", "Faerie Fire", {770}, "5", "Utility", "harm"},
        {"hurricane", "Hurricane", {16914}, "R", "Area", "ground"},
        {"rejuvenation", "Rejuvenation", {774}, "SHIFT-1", "Healing", "help", {cancelForm = true}},
        {"regrowth", "Regrowth", {8936}, "SHIFT-2", "Healing", "help", {cancelForm = true}},
        {"healing_touch", "Healing Touch", {5185}, "SHIFT-3", "Healing", "help", {cancelForm = true}},
        {"tranquility", "Tranquility", {740}, "SHIFT-4", "Healing", "self", {cancelForm = true}},
        {"natures_swiftness", "Nature's Swiftness", {17116}, "SHIFT-5", "Healing", "none"},
        {"soothe", "Soothe Animal", {2908}, "SHIFT-R", "Utility", "harm", {spellNames = {"Soothe Animal", "Soothe"}}},
    }
    local cat = {
        {"claw", "Claw", {1082}, "1"}, {"rake", "Rake", {1822}, "2"},
        {"shred", "Shred", {5221}, "3"}, {"rip", "Rip", {1079}, "4"},
        {"bite", "Ferocious Bite", {22568}, "5"}, {"tigers_fury", "Tiger's Fury", {5217}, "R", "Offense", "self"},
        {"ravage", "Ravage", {6785}, "SHIFT-1"}, {"pounce", "Pounce", {9005}, "SHIFT-2", "Control"},
        {"cower", "Cower", {8998}, "SHIFT-3", "Utility", "none"},
        {"faerie_fire_feral", "Faerie Fire (Feral)", {16857}, "SHIFT-4", "Utility"},
        {"track_humanoids", "Track Humanoids", {5225}, "SHIFT-5", "Tracking", "none"},
        {"natures_swiftness", "Nature's Swiftness", {17116}, "SHIFT-R", "Healing", "none"},
    }
    local bear = {
        {"maul", "Maul", {6807}, "1"}, {"swipe", "Swipe", {779}, "2", "Area", "none"},
        {"lacerate", "Lacerate", {}, "3"},
        {"growl", "Growl", {6795}, "4", "Taunt"}, {"bash", "Bash", {5211}, "5", "Control"},
        {"enrage", "Enrage", {5229}, "R", "Resource", "self"},
        {"demoralizing_roar", "Demoralizing Roar", {99}, "SHIFT-1", "Defense", "none"},
        {"challenging_roar", "Challenging Roar", {5209}, "SHIFT-2", "Taunt", "none"},
        {"feral_charge", "Feral Charge", {16979}, "SHIFT-3", "Movement"},
        {"faerie_fire_feral", "Faerie Fire (Feral)", {16857}, "SHIFT-4", "Utility"},
        {"frenzied_regeneration", "Frenzied Regeneration", {22842}, "SHIFT-5", "Defense", "self"},
        {"natures_swiftness", "Nature's Swiftness", {17116}, "SHIFT-R", "Healing", "none"},
    }
    if forever then
        cat[6] = {"shifting_power", "Shifting Power", {}, "R", "Resource", "none"}
        cat[10] = {"faerie_fire", "Faerie Fire", {770}, "SHIFT-4", "Utility", "harm"}
        bear[5] = {"primal_bite", "Primal Bite", {}, "5", "Attack", "harm"}
        bear[10] = copy(cat[10])
    else
        -- Era has neither Lacerate nor Primal Bite. Keep the complete bank
        -- useful without importing a later expansion's bear rotation.
        bear[3] = {"bash", "Bash", {5211}, "3", "Control", "harm"}
        bear[5] = {"frenzied_regeneration", "Frenzied Regeneration", {22842}, "5", "Defense", "self"}
        bear[11] = {"bash_focus", "Bash", {5211}, "SHIFT-5", "Control", "focus"}
    end
    local function page(rows, form)
        for _, row in ipairs(rows) do
            local extra = copy(row[7] or {})
            extra.form, extra.priority = form, 15
            d(row[1] .. "." .. form, row[2], row[3], row[4], row[5], row[6], extra)
        end
    end
    page(caster, "caster")
    page(caster, "moonkin")
    page(cat, "cat")
    -- Blizzard's Cat page does not change when Prowl is active. Keep its
    -- openers on Shift-1/2 so the keyboard and native action bar always agree.
    page(bear, "bear")
    if forever then
        -- New talent names are kept separate from the Era catalog. Their IDs
        -- are intentionally empty until verified; learned-name matching only.
        d("berserk", "Berserk", {}, "CTRL-R", "Offense", "none")
        d("feral_charge_cat", "Feral Charge - Cat", {}, "CTRL-BUTTON4", "Movement", "harm", {requiresForm = "cat", spellNames = {"Feral Charge - Cat", "Feral Charge (Cat)"}})
    end
    return list
end

local catalog = {}
catalog.MAGE = {
    {"frostbolt", "Frostbolt", {116}, "1"}, {"fireball", "Fireball", {133}, "SHIFT-1"},
    {"fire_blast", "Fire Blast", {2136}, "2"}, {"scorch", "Scorch", {2948}, "SHIFT-2"},
    {"arcane_missiles", "Arcane Missiles", {5143}, "3"}, {"arcane_explosion", "Arcane Explosion", {1449}, "SHIFT-3", "Area", "none"},
    {"cone_of_cold", "Cone of Cold", {120}, "4", "Area", "none"}, {"blizzard", "Blizzard", {10}, "SHIFT-4", "Area", "ground"},
    {"frost_nova", "Frost Nova", {122}, "5", "Control", "none"}, {"flamestrike", "Flamestrike", {2120}, "SHIFT-5", "Area", "ground"},
    {"counterspell", "Counterspell", {2139}, "R", "Interrupt", "harm", {priority = 1}, "SHIFT-R"},
    {"polymorph", "Polymorph", {118}, "Q", "Control", "harm", {priority = 5}, "SHIFT-Q"},
    {"blink", "Blink", {1953}, "E", "Movement", "none", {priority = 1}},
    {"ice_barrier", "Ice Barrier", {11426}, "F", "Defense", "self", {priority = 1}},
    {"mana_shield", "Mana Shield", {1463}, "SHIFT-F", "Defense", "self"},
    {"ice_block", "Ice Block", {11958}, "G", "Defense", "self", {priority = 1}},
    {"cold_snap", "Cold Snap", {12472}, "SHIFT-G", "Offense", "none"},
    {"pyroblast", "Pyroblast", {11366}, "CTRL-R", "Attack", "harm"},
    {"remove_curse", "Remove Lesser Curse", {475}, "V", "Dispel", "help", {spellNames = {"Remove Lesser Curse", "Remove Curse"}, priority = 5}},
    {"evocation", "Evocation", {12051}, "X", "Resource", "self"},
    {"presence_of_mind", "Presence of Mind", {12043}, "Z", "Offense", "self"},
    {"arcane_power", "Arcane Power", {12042}, "SHIFT-Z", "Offense", "self"},
    {"combustion", "Combustion", {11129}, "C", "Offense", "self"},
    {"blast_wave", "Blast Wave", {11113}, "SHIFT-C", "Control", "none"},
    {"ice_armor", "Ice Armor", {7302}, "B", "Buff", "self"},
    {"mage_armor", "Mage Armor", {6117}, "SHIFT-B", "Buff", "self"},
    {"frost_armor", "Frost Armor", {168}, "CTRL-B", "Buff", "self"},
    {"dampen_magic", "Dampen Magic", {604}, "CTRL-Q", "Buff", "help"},
    {"amplify_magic", "Amplify Magic", {1008}, "CTRL-E", "Buff", "help"},
    {"detect_magic", "Detect Magic", {2855}, "CTRL-C", "Utility", "harm"},
    {"slow_fall", "Slow Fall", {130}, "CTRL-V", "Movement", "help"},
    {"intellect", "Arcane Intellect", {1459}, "CTRL-1", "Buff", "help"},
    {"brilliance", "Arcane Brilliance", {23028}, "CTRL-2", "Buff", "help"},
    {"conjure_water", "Conjure Water", {5504}, "CTRL-3", "Conjure", "none"},
    {"conjure_food", "Conjure Food", {587}, "CTRL-4", "Conjure", "none"},
    {"conjure_ruby", "Conjure Mana Ruby", {10054}, "CTRL-5", "Conjure", "none"},
    {"conjure_citrine", "Conjure Mana Citrine", {10053}, "CTRL-6", "Conjure", "none"},
    {"conjure_jade", "Conjure Mana Jade", {3552}, "SHIFT-6", "Conjure", "none"},
    {"conjure_agate", "Conjure Mana Agate", {759}, "6", "Conjure", "none"},
    {"fire_ward", "Fire Ward", {543}, "BUTTON4", "Defense", "self"},
    {"frost_ward", "Frost Ward", {6143}, "SHIFT-BUTTON4", "Defense", "self"},
    {"teleport_sw", "Teleport: Stormwind", {3561}, "7", "Travel", "none"},
    {"teleport_if", "Teleport: Ironforge", {3562}, "8", "Travel", "none"},
    {"teleport_darn", "Teleport: Darnassus", {3565}, "9", "Travel", "none"},
    {"teleport_org", "Teleport: Orgrimmar", {3567}, "0", "Travel", "none"},
    {"teleport_uc", "Teleport: Undercity", {3563}, "-", "Travel", "none"},
    {"teleport_tb", "Teleport: Thunder Bluff", {3566}, "=", "Travel", "none"},
    {"portal_sw", "Portal: Stormwind", {10059}, "SHIFT-7", "Travel", "none"},
    {"portal_if", "Portal: Ironforge", {11416}, "SHIFT-8", "Travel", "none"},
    {"portal_darn", "Portal: Darnassus", {11419}, "SHIFT-9", "Travel", "none"},
    {"portal_org", "Portal: Orgrimmar", {11417}, "SHIFT-0", "Travel", "none"},
    {"portal_uc", "Portal: Undercity", {11418}, "SHIFT--", "Travel", "none"},
    {"portal_tb", "Portal: Thunder Bluff", {11420}, "SHIFT-=", "Travel", "none"},
}

catalog.WARRIOR = {
    {"heroic_strike", "Heroic Strike", {78}, "1"}, {"cleave", "Cleave", {845}, "SHIFT-1"},
    {"mortal_strike", "Mortal Strike", {12294}, "2"}, {"bloodthirst", "Bloodthirst", {23881}, "SHIFT-2"},
    {"overpower", "Overpower", {7384}, "3"}, {"revenge", "Revenge", {6572}, "SHIFT-3"},
    {"execute", "Execute", {5308}, "4"}, {"whirlwind", "Whirlwind", {1680}, "SHIFT-4", "Area", "none"},
    {"rend", "Rend", {772}, "5"}, {"slam", "Slam", {1464}, "SHIFT-5"},
    {"pummel", "Pummel", {6552}, "R", "Interrupt", "harm", {priority = 1}, "SHIFT-R"},
    {"shield_bash", "Shield Bash", {72}, "Q", "Interrupt", "harm", {priority = 1}, "SHIFT-Q"},
    {"hamstring", "Hamstring", {1715}, "E", "Control", "harm"},
    {"piercing_howl", "Piercing Howl", {12323}, "SHIFT-E", "Control", "none"},
    {"shield_block", "Shield Block", {2565}, "F", "Defense", "self", {priority = 1}},
    {"retaliation", "Retaliation", {20230}, "SHIFT-F", "Defense", "self"},
    {"shield_wall", "Shield Wall", {871}, "G", "Defense", "self", {priority = 1}},
    {"last_stand", "Last Stand", {12975}, "SHIFT-G", "Defense", "self"},
    {"intimidating_shout", "Intimidating Shout", {5246}, "C", "Control", "harm", nil, "SHIFT-C"},
    {"taunt", "Taunt", {355}, "V", "Taunt", "harm"},
    {"mocking_blow", "Mocking Blow", {694}, "SHIFT-V", "Taunt", "harm"},
    {"challenging_shout", "Challenging Shout", {1161}, "CTRL-V", "Taunt", "none"},
    {"disarm", "Disarm", {676}, "Z", "Control", "harm", nil, "SHIFT-Z"},
    {"bloodrage", "Bloodrage", {2687}, "X", "Resource", "self"},
    {"berserker_rage", "Berserker Rage", {18499}, "SHIFT-X", "Defense", "self"},
    {"charge", "Charge", {100}, "BUTTON5", "Movement", "harm", {priority = 5}},
    {"intercept", "Intercept", {20252}, "SHIFT-BUTTON5", "Movement", "harm", {priority = 5}},
    {"concussion_blow", "Concussion Blow", {12809}, "BUTTON4", "Control", "harm", nil, "SHIFT-BUTTON4"},
    {"shield_slam", "Shield Slam", {23922}, "6"}, {"sunder_armor", "Sunder Armor", {7386}, "SHIFT-6"},
    {"thunder_clap", "Thunder Clap", {6343}, "B", "Area", "none"},
    {"demoralizing_shout", "Demoralizing Shout", {1160}, "SHIFT-B", "Defense", "none"},
    {"battle_shout", "Battle Shout", {6673}, "CTRL-B", "Buff", "none"},
    {"sweeping_strikes", "Sweeping Strikes", {12328}, "CTRL-Q", "Offense", "self"},
    {"recklessness", "Recklessness", {1719}, "CTRL-E", "Offense", "self"},
    {"death_wish", "Death Wish", {12292}, "CTRL-R", "Offense", "self"},
    {"battle_stance", "Battle Stance", {2457}, "MOUSEWHEELUP", "Stances", "none"},
    {"defensive_stance", "Defensive Stance", {71}, "MOUSEWHEELDOWN", "Stances", "none"},
    {"berserker_stance", "Berserker Stance", {2458}, "SHIFT-MOUSEWHEELUP", "Stances", "none"},
}

catalog.ROGUE = {
    {"sinister_strike", "Sinister Strike", {1752}, "1"}, {"backstab", "Backstab", {53}, "SHIFT-1"},
    {"hemorrhage", "Hemorrhage", {16511}, "2"}, {"ghostly_strike", "Ghostly Strike", {14278}, "SHIFT-2"},
    {"eviscerate", "Eviscerate", {2098}, "3"}, {"slice_and_dice", "Slice and Dice", {5171}, "SHIFT-3", "Offense", "self"},
    {"rupture", "Rupture", {1943}, "4"}, {"expose_armor", "Expose Armor", {8647}, "SHIFT-4"},
    {"feint", "Feint", {1966}, "5", "Defense", "harm"}, {"riposte", "Riposte", {14251}, "SHIFT-5"},
    {"kick", "Kick", {1766}, "R", "Interrupt", "harm", {priority = 1}, "SHIFT-R"},
    {"gouge", "Gouge", {1776}, "Q", "Control", "harm", nil, "SHIFT-Q"},
    {"kidney_shot", "Kidney Shot", {408}, "E", "Control", "harm", nil, "SHIFT-E"},
    {"evasion", "Evasion", {5277}, "F", "Defense", "self", {priority = 1}},
    {"preparation", "Preparation", {14185}, "SHIFT-F", "Defense", "self"},
    {"vanish", "Vanish", {1856}, "G", "Defense", "self", {priority = 1}},
    {"sprint", "Sprint", {2983}, "BUTTON5", "Movement", "self"},
    {"blind", "Blind", {2094}, "C", "Control", "harm", nil, "SHIFT-C"},
    {"sap", "Sap", {6770}, "V", "Control", "harm", nil, "SHIFT-V"},
    {"stealth", "Stealth", {1784}, "Z", "Stealth", "none", {nonToggle = true}},
    {"distract", "Distract", {1725}, "SHIFT-Z", "Control", "ground"},
    {"cheap_shot", "Cheap Shot", {1833}, "BUTTON4", "Control", "harm", nil, "SHIFT-BUTTON4"},
    {"ambush", "Ambush", {8676}, "X"}, {"garrote", "Garrote", {703}, "SHIFT-X"},
    {"blade_flurry", "Blade Flurry", {13877}, "B", "Offense", "self"},
    {"adrenaline_rush", "Adrenaline Rush", {13750}, "SHIFT-B", "Offense", "self"},
    {"cold_blood", "Cold Blood", {14177}, "CTRL-E", "Offense", "self"},
    {"premeditation", "Premeditation", {14183}, "CTRL-Q", "Offense", "harm"},
    {"pick_pocket", "Pick Pocket", {921}, "CTRL-X", "Utility", "harm"},
    {"pick_lock", "Pick Lock", {1804}, "CTRL-C", "Utility", "none"},
    {"poisons", "Poisons", {2842}, "CTRL-V", "Crafting", "none"},
    {"disarm_trap", "Disarm Trap", {1842}, "CTRL-B", "Utility", "none"},
}

catalog.HUNTER = {
    {"auto_shot", "Auto Shot", {75}, "1", "Attack", "harm", {nonToggle = true}},
    {"aimed_shot", "Aimed Shot", {19434}, "2"}, {"arcane_shot", "Arcane Shot", {3044}, "3"},
    {"multi_shot", "Multi-Shot", {2643}, "4"}, {"serpent_sting", "Serpent Sting", {1978}, "5"},
    {"raptor_strike", "Raptor Strike", {2973}, "SHIFT-1"}, {"mongoose_bite", "Mongoose Bite", {1495}, "SHIFT-2"},
    {"counterattack", "Counterattack", {19306}, "SHIFT-3", "Control"},
    {"volley", "Volley", {1510}, "SHIFT-4", "Area", "ground"}, {"scorpid_sting", "Scorpid Sting", {3043}, "SHIFT-5"},
    {"scatter_shot", "Scatter Shot", {19503}, "R", "Control", "harm", {priority = 5}, "SHIFT-R"},
    {"concussive_shot", "Concussive Shot", {5116}, "Q", "Control", "harm", nil, "SHIFT-Q"},
    {"wing_clip", "Wing Clip", {2974}, "E", "Control", "harm"},
    {"deterrence", "Deterrence", {19263}, "F", "Defense", "self", {priority = 1}},
    {"feign_death", "Feign Death", {5384}, "G", "Defense", "self", {priority = 1}},
    {"disengage", "Disengage", {781}, "SHIFT-G", "Utility", "harm"},
    {"distracting_shot", "Distracting Shot", {20736}, "CTRL-SHIFT-R", "Threat", "harm"},
    {"intimidation", "Intimidation", {19577}, "BUTTON4", "Control", "harm"},
    {"freezing_trap", "Freezing Trap", {1499}, "C", "Control", "none"},
    {"frost_trap", "Frost Trap", {13809}, "SHIFT-C", "Control", "none"},
    {"explosive_trap", "Explosive Trap", {13813}, "CTRL-C", "Area", "none"},
    {"immolation_trap", "Immolation Trap", {13795}, "CTRL-E", "Attack", "none"},
    {"tranquilizing_shot", "Tranquilizing Shot", {19801}, "V", "Dispel", "harm"},
    {"viper_sting", "Viper Sting", {3034}, "SHIFT-V", "Utility", "harm"},
    {"scare_beast", "Scare Beast", {1513}, "Z", "Control", "harm", nil, "SHIFT-Z"},
    {"hunters_mark", "Hunter's Mark", {1130}, "X", "Utility", "harm"},
    {"flare", "Flare", {1543}, "SHIFT-X", "Utility", "ground"},
    {"rapid_fire", "Rapid Fire", {3045}, "B", "Offense", "self"},
    {"bestial_wrath", "Bestial Wrath", {19574}, "SHIFT-B", "Offense", "none"},
    {"wyvern_sting", "Wyvern Sting", {19386}, "SHIFT-E", "Control", "harm"},
    {"aspect_cheetah", "Aspect of the Cheetah", {5118}, "BUTTON5", "Movement", "self"},
    {"aspect_pack", "Aspect of the Pack", {13159}, "SHIFT-BUTTON5", "Movement", "self"},
    {"aspect_hawk", "Aspect of the Hawk", {13165}, "MOUSEWHEELUP", "Buff", "self"},
    {"aspect_monkey", "Aspect of the Monkey", {13163}, "MOUSEWHEELDOWN", "Buff", "self"},
    {"aspect_wild", "Aspect of the Wild", {20043}, "SHIFT-MOUSEWHEELUP", "Buff", "self"},
    {"aspect_beast", "Aspect of the Beast", {13161}, "SHIFT-MOUSEWHEELDOWN", "Buff", "self"},
    {"mend_pet", "Mend Pet", {136}, "CTRL-Q", "Pet", "none"},
    {"revive_pet", "Revive Pet", {982}, "CTRL-R", "Pet", "none"},
    {"call_pet", "Call Pet", {883}, "CTRL-X", "Pet", "none"},
    {"dismiss_pet", "Dismiss Pet", {2641}, "CTRL-V", "Pet", "none"},
    {"feed_pet", "Feed Pet", {6991}, "CTRL-B", "Pet", "none"},
    {"trueshot_aura", "Trueshot Aura", {19506}, "CTRL-1", "Buff", "self"},
    {"beast_lore", "Beast Lore", {1462}, "CTRL-2", "Utility", "harm"},
    {"eagle_eye", "Eagle Eye", {6197}, "CTRL-3", "Utility", "ground"},
    {"eyes_beast", "Eyes of the Beast", {1002}, "CTRL-4", "Pet", "none"},
    {"tame_beast", "Tame Beast", {1515}, "CTRL-5", "Pet", "harm"},
    {"track_beasts", "Track Beasts", {1494}, "6", "Tracking", "none"},
    {"track_humanoids", "Track Humanoids", {19883}, "SHIFT-6", "Tracking", "none"},
    {"track_hidden", "Track Hidden", {19885}, "CTRL-6", "Tracking", "none"},
    {"track_undead", "Track Undead", {19884}, "7", "Tracking", "none"},
    {"track_elementals", "Track Elementals", {19880}, "8", "Tracking", "none"},
    {"track_demons", "Track Demons", {19878}, "9", "Tracking", "none"},
    {"track_giants", "Track Giants", {19882}, "0", "Tracking", "none"},
    {"track_dragonkin", "Track Dragonkin", {19879}, "-", "Tracking", "none"},
    {"beast_training", "Beast Training", {5149}, "=", "Pet", "none"},
}

catalog.PRIEST = {
    {"smite", "Smite", {585}, "1"}, {"holy_fire", "Holy Fire", {14914}, "SHIFT-1"},
    {"shadow_word_pain", "Shadow Word: Pain", {589}, "2"}, {"mind_blast", "Mind Blast", {8092}, "3"},
    {"mind_flay", "Mind Flay", {15407}, "4"}, {"holy_nova", "Holy Nova", {15237}, "5", "Area", "none"},
    {"vampiric_embrace", "Vampiric Embrace", {15286}, "SHIFT-2", "Attack", "harm"},
    {"devouring_plague", "Devouring Plague", {2944}, "SHIFT-3"}, {"starshards", "Starshards", {10797}, "SHIFT-4"},
    {"feedback", "Feedback", {13896}, "SHIFT-5", "Defense", "self"},
    {"silence", "Silence", {15487}, "R", "Interrupt", "harm", {priority = 1}, "SHIFT-R"},
    {"renew", "Renew", {139}, "Q", "Healing", "help", {priority = 5}},
    {"flash_heal", "Flash Heal", {2061}, "E", "Healing", "help", {priority = 5}},
    {"greater_heal", "Greater Heal", {2060}, "SHIFT-E", "Healing", "help"},
    {"prayer_healing", "Prayer of Healing", {596}, "SHIFT-Q", "Healing", "help"},
    {"shield", "Power Word: Shield", {17}, "F", "Defense", "help", {priority = 1}},
    {"inner_focus", "Inner Focus", {14751}, "SHIFT-F", "Offense", "self"},
    {"desperate_prayer", "Desperate Prayer", {19236}, "G", "Defense", "self", {priority = 1}},
    {"fade", "Fade", {586}, "SHIFT-G", "Defense", "self"},
    {"psychic_scream", "Psychic Scream", {8122}, "C", "Control", "none", {priority = 5}},
    {"mind_control", "Mind Control", {605}, "SHIFT-C", "Control", "harm"},
    {"dispel_magic", "Dispel Magic", {527}, "V", "Dispel", "help", {priority = 5}},
    {"dispel_magic_enemy", "Dispel Magic", {527}, "SHIFT-V", "Dispel", "harm"},
    {"abolish_disease", "Abolish Disease", {552}, "CTRL-V", "Dispel", "help"},
    {"cure_disease", "Cure Disease", {528}, "CTRL-C", "Dispel", "help"},
    {"shackle", "Shackle Undead", {9484}, "Z", "Control", "harm", nil, "SHIFT-Z"},
    {"power_infusion", "Power Infusion", {10060}, "X", "Offense", "help"},
    {"resurrection", "Resurrection", {2006}, "SHIFT-X", "Resurrection", "dead"},
    {"fear_ward", "Fear Ward", {6346}, "BUTTON4", "Defense", "help"},
    {"shadowguard", "Shadowguard", {18137}, "SHIFT-BUTTON4", "Defense", "self"},
    {"shadowform", "Shadowform", {15473}, "MOUSEWHEELDOWN", "Forms", "none", {nonToggle = true}},
    {"levitate", "Levitate", {1706}, "BUTTON5", "Movement", "help"},
    {"touch_weakness", "Touch of Weakness", {2652}, "SHIFT-BUTTON5", "Defense", "self"},
    {"lesser_heal", "Lesser Heal", {2050}, "6", "Healing", "help"}, {"heal", "Heal", {2054}, "SHIFT-6", "Healing", "help"},
    {"fortitude", "Power Word: Fortitude", {1243}, "B", "Buff", "help"},
    {"prayer_fortitude", "Prayer of Fortitude", {21562}, "SHIFT-B", "Buff", "help"},
    {"divine_spirit", "Divine Spirit", {14752}, "CTRL-B", "Buff", "help"},
    {"prayer_spirit", "Prayer of Spirit", {27681}, "CTRL-Q", "Buff", "help"},
    {"inner_fire", "Inner Fire", {588}, "CTRL-E", "Buff", "self"},
    {"shadow_protection", "Shadow Protection", {976}, "CTRL-1", "Buff", "help"},
    {"prayer_shadow", "Prayer of Shadow Protection", {27683}, "CTRL-2", "Buff", "help"},
    {"mind_soothe", "Mind Soothe", {453}, "CTRL-3", "Utility", "harm"},
    {"mind_vision", "Mind Vision", {2096}, "CTRL-4", "Utility", "harm"},
    {"elunes_grace", "Elune's Grace", {2651}, "CTRL-5", "Defense", "self"},
    {"hex_weakness", "Hex of Weakness", {9035}, "CTRL-6", "Utility", "harm"},
    {"mana_burn", "Mana Burn", {8129}, "CTRL-R", "Resource", "harm"},
    {"lightwell", "Lightwell", {724}, "8", "Healing", "ground"},
}

catalog.PALADIN = {
    {"seal_righteousness", "Seal of Righteousness", {20154}, "1", "Offense", "self"},
    {"seal_command", "Seal of Command", {20375}, "SHIFT-1", "Offense", "self"},
    {"judgement", "Judgement", {20271}, "2"}, {"consecration", "Consecration", {26573}, "3", "Area", "none"},
    {"exorcism", "Exorcism", {879}, "4"}, {"holy_wrath", "Holy Wrath", {2812}, "SHIFT-4", "Area", "none"},
    {"hammer_wrath", "Hammer of Wrath", {24275}, "5"},
    {"seal_crusader", "Seal of the Crusader", {21082}, "SHIFT-2", "Offense", "self"},
    {"seal_wisdom", "Seal of Wisdom", {20166}, "SHIFT-3", "Resource", "self"},
    {"seal_light", "Seal of Light", {20165}, "SHIFT-5", "Healing", "self"},
    {"hammer_justice", "Hammer of Justice", {853}, "R", "Control", "harm", {priority = 1}, "SHIFT-R"},
    {"flash_light", "Flash of Light", {19750}, "Q", "Healing", "help", {priority = 5}},
    {"holy_light", "Holy Light", {635}, "E", "Healing", "help", {priority = 5}},
    {"holy_shock", "Holy Shock", {20473}, "SHIFT-Q", "Healing", "help"},
    {"holy_shock_enemy", "Holy Shock", {20473}, "SHIFT-E", "Attack", "harm"},
    {"divine_protection", "Divine Protection", {498}, "F", "Defense", "self", {priority = 1}},
    {"holy_shield", "Holy Shield", {20925}, "SHIFT-F", "Defense", "self"},
    {"divine_shield", "Divine Shield", {642}, "G", "Defense", "self", {priority = 1}},
    {"lay_on_hands", "Lay on Hands", {633}, "SHIFT-G", "Healing", "help", {priority = 2}},
    {"repentance", "Repentance", {20066}, "C", "Control", "harm", nil, "SHIFT-C"},
    {"cleanse", "Cleanse", {4987}, "V", "Dispel", "help", {priority = 5}},
    {"purify", "Purify", {1152}, "SHIFT-V", "Dispel", "help"},
    {"turn_undead", "Turn Undead", {2878}, "Z", "Control", "harm", nil, "SHIFT-Z"},
    {"divine_favor", "Divine Favor", {20216}, "X", "Healing", "none"},
    {"redemption", "Redemption", {7328}, "SHIFT-X", "Resurrection", "dead"},
    {"blessing_protection", "Blessing of Protection", {1022}, "BUTTON4", "Defense", "help", {priority = 1}},
    {"blessing_sacrifice", "Blessing of Sacrifice", {6940}, "SHIFT-BUTTON4", "Defense", "help"},
    {"blessing_freedom", "Blessing of Freedom", {1044}, "BUTTON5", "Movement", "help", {priority = 1}},
    {"righteous_fury", "Righteous Fury", {25780}, "CTRL-R", "Tank", "self"},
    {"seal_justice", "Seal of Justice", {20164}, "CTRL-E", "Control", "self"},
    {"blessing_might", "Blessing of Might", {19740}, "B", "Buff", "help"},
    {"blessing_wisdom", "Blessing of Wisdom", {19742}, "SHIFT-B", "Buff", "help"},
    {"blessing_kings", "Blessing of Kings", {20217}, "CTRL-B", "Buff", "help"},
    {"blessing_sanctuary", "Blessing of Sanctuary", {20911}, "CTRL-Q", "Buff", "help"},
    {"blessing_salvation", "Blessing of Salvation", {1038}, "CTRL-C", "Buff", "help"},
    {"blessing_light", "Blessing of Light", {19977}, "CTRL-V", "Buff", "help"},
    {"devotion_aura", "Devotion Aura", {465}, "MOUSEWHEELUP", "Auras", "none"},
    {"retribution_aura", "Retribution Aura", {7294}, "MOUSEWHEELDOWN", "Auras", "none"},
    {"concentration_aura", "Concentration Aura", {19746}, "SHIFT-MOUSEWHEELUP", "Auras", "none"},
    {"sanctity_aura", "Sanctity Aura", {20218}, "SHIFT-MOUSEWHEELDOWN", "Auras", "none"},
    {"shadow_resistance", "Shadow Resistance Aura", {19876}, "CTRL-1", "Auras", "none"},
    {"frost_resistance", "Frost Resistance Aura", {19888}, "CTRL-2", "Auras", "none"},
    {"fire_resistance", "Fire Resistance Aura", {19891}, "CTRL-3", "Auras", "none"},
    {"sense_undead", "Sense Undead", {5502}, "CTRL-4", "Tracking", "none"},
    {"divine_intervention", "Divine Intervention", {19752}, "CTRL-5", "Utility", "help", {priority = 90}},
    {"greater_might", "Greater Blessing of Might", {25782}, "7", "Buff", "help"},
    {"greater_wisdom", "Greater Blessing of Wisdom", {25894}, "8", "Buff", "help"},
    {"greater_kings", "Greater Blessing of Kings", {25898}, "9", "Buff", "help"},
    {"greater_sanctuary", "Greater Blessing of Sanctuary", {25899}, "0", "Buff", "help"},
    {"greater_salvation", "Greater Blessing of Salvation", {25895}, "-", "Buff", "help"},
    {"greater_light", "Greater Blessing of Light", {25890}, "=", "Buff", "help"},
    {"summon_warhorse", "Summon Warhorse", {13819}, "SHIFT-7", "Travel", "none"},
    {"summon_charger", "Summon Charger", {23214}, "SHIFT-8", "Travel", "none"},
}

catalog.SHAMAN = {
    {"lightning_bolt", "Lightning Bolt", {403}, "1"}, {"chain_lightning", "Chain Lightning", {421}, "SHIFT-1"},
    {"flame_shock", "Flame Shock", {8050}, "2"}, {"frost_shock", "Frost Shock", {8056}, "3", "Control", "harm"},
    {"stormstrike", "Stormstrike", {17364}, "4"}, {"lightning_shield", "Lightning Shield", {324}, "5", "Defense", "self"},
    {"earth_shock", "Earth Shock", {8042}, "R", "Interrupt", "harm", {priority = 1}, "SHIFT-R"},
    {"healing_wave", "Healing Wave", {331}, "Q", "Healing", "help", {priority = 5}},
    {"lesser_healing_wave", "Lesser Healing Wave", {8004}, "E", "Healing", "help", {priority = 5}},
    {"chain_heal", "Chain Heal", {1064}, "SHIFT-Q", "Healing", "help"},
    {"natures_swiftness", "Nature's Swiftness", {16188}, "SHIFT-E", "Healing", "none"},
    {"stoneclaw", "Stoneclaw Totem", {5730}, "F", "Defense", "none"},
    {"stoneskin", "Stoneskin Totem", {8071}, "SHIFT-F", "Defense", "none"},
    {"grounding", "Grounding Totem", {8177}, "G", "Defense", "none", {priority = 1}},
    {"tremor", "Tremor Totem", {8143}, "SHIFT-G", "Defense", "none", {priority = 2}},
    {"earthbind", "Earthbind Totem", {2484}, "C", "Control", "none"},
    {"purge", "Purge", {370}, "V", "Dispel", "harm", nil, "SHIFT-V"},
    {"cure_poison", "Cure Poison", {526}, "Z", "Dispel", "help"},
    {"cure_disease", "Cure Disease", {2870}, "SHIFT-Z", "Dispel", "help"},
    {"elemental_mastery", "Elemental Mastery", {16166}, "X", "Offense", "none"},
    {"ancestral_spirit", "Ancestral Spirit", {2008}, "SHIFT-X", "Resurrection", "dead"},
    {"ghost_wolf", "Ghost Wolf", {2645}, "BUTTON5", "Movement", "none", {nonToggle = true}},
    {"mana_tide", "Mana Tide Totem", {16190}, "BUTTON4", "Resource", "none"},
    {"healing_stream", "Healing Stream Totem", {5394}, "SHIFT-2", "Healing", "none"},
    {"mana_spring", "Mana Spring Totem", {5675}, "SHIFT-3", "Resource", "none"},
    {"searing", "Searing Totem", {3599}, "SHIFT-4", "Attack", "none"},
    {"fire_nova", "Fire Nova Totem", {1535}, "SHIFT-5", "Area", "none"},
    {"magma", "Magma Totem", {8190}, "SHIFT-B", "Area", "none"},
    {"windfury_totem", "Windfury Totem", {8512}, "B", "Buff", "none"},
    {"grace_air", "Grace of Air Totem", {8835}, "CTRL-B", "Buff", "none"},
    {"strength_earth", "Strength of Earth Totem", {8075}, "CTRL-Q", "Buff", "none"},
    {"tranquil_air", "Tranquil Air Totem", {25908}, "CTRL-E", "Buff", "none"},
    {"poison_cleansing", "Poison Cleansing Totem", {8166}, "SHIFT-C", "Dispel", "none"},
    {"disease_cleansing", "Disease Cleansing Totem", {8170}, "CTRL-C", "Dispel", "none"},
    {"fire_resistance", "Fire Resistance Totem", {8184}, "CTRL-1", "Defense", "none"},
    {"frost_resistance", "Frost Resistance Totem", {8181}, "CTRL-2", "Defense", "none"},
    {"nature_resistance", "Nature Resistance Totem", {10595}, "CTRL-3", "Defense", "none"},
    {"windwall", "Windwall Totem", {15107}, "CTRL-4", "Defense", "none"},
    {"sentry", "Sentry Totem", {6495}, "CTRL-5", "Utility", "none"},
    {"flametongue_totem", "Flametongue Totem", {8227}, "CTRL-6", "Buff", "none"},
    {"windfury_weapon", "Windfury Weapon", {8232}, "6", "Imbue", "none"},
    {"flametongue_weapon", "Flametongue Weapon", {8024}, "SHIFT-6", "Imbue", "none"},
    {"rockbiter_weapon", "Rockbiter Weapon", {8017}, "7", "Imbue", "none"},
    {"frostbrand_weapon", "Frostbrand Weapon", {8033}, "SHIFT-7", "Imbue", "none"},
    {"water_walking", "Water Walking", {546}, "CTRL-V", "Movement", "help"},
    {"water_breathing", "Water Breathing", {131}, "CTRL-X", "Utility", "help"},
    {"far_sight", "Far Sight", {6196}, "8", "Utility", "ground"},
    {"astral_recall", "Astral Recall", {556}, "SHIFT-8", "Travel", "none"},
}

catalog.WARLOCK = {
    {"shadow_bolt", "Shadow Bolt", {686}, "1"}, {"searing_pain", "Searing Pain", {5676}, "SHIFT-1"},
    {"corruption", "Corruption", {172}, "2"}, {"immolate", "Immolate", {348}, "3"},
    {"drain_life", "Drain Life", {689}, "4"}, {"shadowburn", "Shadowburn", {17877}, "5"},
    {"soul_fire", "Soul Fire", {6353}, "SHIFT-2"}, {"conflagrate", "Conflagrate", {17962}, "SHIFT-3"},
    {"rain_fire", "Rain of Fire", {5740}, "SHIFT-4", "Area", "ground"},
    {"hellfire", "Hellfire", {1949}, "SHIFT-5", "Area", "none"},
    {"spell_lock", "Spell Lock", {19244, 19647}, "R", "Interrupt", "harm", {priority = 1, petSpell = true}, "SHIFT-R"},
    {"fear", "Fear", {5782}, "Q", "Control", "harm", {priority = 5}, "SHIFT-Q"},
    {"death_coil", "Death Coil", {6789}, "E", "Control", "harm", {priority = 1}, "SHIFT-E"},
    {"sacrifice", "Sacrifice", {7812}, "F", "Defense", "none", {priority = 1, petSpell = true}},
    {"shadow_ward", "Shadow Ward", {6229}, "SHIFT-F", "Defense", "self"},
    {"soul_link", "Soul Link", {19028}, "G", "Defense", "self"},
    {"siphon_life", "Siphon Life", {18265}, "SHIFT-G", "Attack", "harm"},
    {"howl_terror", "Howl of Terror", {5484}, "C", "Control", "none"},
    {"seduction", "Seduction", {6358}, "SHIFT-C", "Control", "harm", {petSpell = true}, "CTRL-C"},
    {"devour_magic", "Devour Magic", {19505}, "V", "Dispel", "help", {petSpell = true}},
    {"devour_magic_enemy", "Devour Magic", {19505}, "SHIFT-V", "Dispel", "harm", {petSpell = true}},
    {"banish", "Banish", {710}, "Z", "Control", "harm", nil, "SHIFT-Z"},
    {"life_tap", "Life Tap", {1454}, "X", "Resource", "self"},
    {"drain_mana", "Drain Mana", {5138}, "SHIFT-X", "Resource", "harm"},
    {"drain_soul", "Drain Soul", {1120}, "B", "Resource", "harm"},
    {"health_funnel", "Health Funnel", {755}, "SHIFT-B", "Pet", "none"},
    {"curse_agony", "Curse of Agony", {980}, "BUTTON4", "Curse", "harm"},
    {"curse_tongues", "Curse of Tongues", {1714}, "SHIFT-BUTTON4", "Curse", "harm"},
    {"curse_exhaustion", "Curse of Exhaustion", {18223}, "BUTTON5", "Control", "harm"},
    {"curse_elements", "Curse of the Elements", {1490}, "SHIFT-BUTTON5", "Curse", "harm"},
    {"curse_weakness", "Curse of Weakness", {702}, "CTRL-Q", "Curse", "harm"},
    {"curse_recklessness", "Curse of Recklessness", {704}, "CTRL-E", "Curse", "harm"},
    {"curse_shadow", "Curse of Shadow", {17862}, "CTRL-R", "Curse", "harm"},
    {"curse_doom", "Curse of Doom", {603}, "CTRL-V", "Curse", "harm"},
    {"amplify_curse", "Amplify Curse", {18288}, "CTRL-X", "Offense", "self"},
    {"fel_domination", "Fel Domination", {18708}, "CTRL-B", "Pet", "self"},
    {"demonic_sacrifice", "Demonic Sacrifice", {18788}, "CTRL-1", "Pet", "none"},
    {"dark_pact", "Dark Pact", {18220}, "CTRL-2", "Resource", "none"},
    {"inferno", "Inferno", {1122}, "CTRL-3", "Summon", "ground"},
    {"ritual_doom", "Ritual of Doom", {18540}, "CTRL-4", "Summon", "none"},
    {"enslave_demon", "Enslave Demon", {1098}, "CTRL-5", "Control", "harm"},
    {"ritual_summoning", "Ritual of Summoning", {698}, "CTRL-6", "Summon", "help"},
    {"summon_imp", "Summon Imp", {688}, "6", "Pet", "none"},
    {"summon_voidwalker", "Summon Voidwalker", {697}, "SHIFT-6", "Pet", "none"},
    {"summon_succubus", "Summon Succubus", {712}, "7", "Pet", "none"},
    {"summon_felhunter", "Summon Felhunter", {691}, "SHIFT-7", "Pet", "none"},
    {"create_healthstone", "Create Healthstone (Major)", {11730,11729,5699,6202,6201}, "8", "Conjure", "none", {rankFamily=true, spellNames = {"Create Healthstone (Major)", "Create Healthstone (Greater)", "Create Healthstone", "Create Healthstone (Lesser)", "Create Healthstone (Minor)"}}},
    {"create_soulstone", "Create Soulstone (Major)", {20757,20756,20755,20752,693}, "SHIFT-8", "Conjure", "none", {rankFamily=true, spellNames = {"Create Soulstone (Major)", "Create Soulstone (Greater)", "Create Soulstone", "Create Soulstone (Lesser)", "Create Soulstone (Minor)"}}},
    {"create_spellstone", "Create Spellstone (Major)", {17728,17727,2362}, "9", "Conjure", "none", {rankFamily=true, spellNames={"Create Spellstone (Major)","Create Spellstone (Greater)","Create Spellstone"}}},
    {"create_firestone", "Create Firestone (Major)", {17953,17952,17951,6366}, "SHIFT-9", "Conjure", "none", {rankFamily=true, spellNames={"Create Firestone (Major)","Create Firestone (Greater)","Create Firestone","Create Firestone (Lesser)"}}},
    {"demon_armor", "Demon Armor", {706}, "0", "Buff", "self"},
    {"demon_skin", "Demon Skin", {687}, "SHIFT-0", "Buff", "self"},
    {"unending_breath", "Unending Breath", {5697}, "-", "Buff", "help"},
    {"detect_invisibility", "Detect Greater Invisibility", {11743,2970,132}, "SHIFT--", "Buff", "help", {rankFamily=true, spellNames={"Detect Greater Invisibility","Detect Invisibility","Detect Lesser Invisibility"}}},
    {"sense_demons", "Sense Demons", {5500}, "=", "Tracking", "none"},
    {"eye_kilrogg", "Eye of Kilrogg", {126}, "SHIFT-=", "Utility", "none"},
    {"summon_felsteed", "Summon Felsteed", {5784}, "CTRL-7", "Travel", "none"},
    {"summon_dreadsteed", "Summon Dreadsteed", {23161}, "CTRL-8", "Travel", "none"},
}

-- Forever additions never leak into the Era catalog. Most new spell IDs are
-- intentionally unspecified: a matching learned spellbook name is required.
-- Pet skills are spell families too: reserve them before a pet learns them.
-- Petopia's Classic family list and original Vanilla pet data are documented
-- in research.md. Autocast state is left under the player's control.
local petRows={
    HUNTER={
        {"pet_bite","Bite",{17253},nil,"Pet","harm"},
        {"pet_claw","Claw",{16827},nil,"Pet","harm"},
        {"pet_growl","Growl",{2649},nil,"Pet","harm"},
        {"pet_cower","Cower",{1742},nil,"Pet","none"},
        {"pet_dash","Dash",{23099},nil,"Pet","none"},
        {"pet_dive","Dive",{23145},nil,"Pet","none"},
        {"pet_charge","Charge",{7371},nil,"Pet","harm"},
        {"pet_prowl","Prowl",{24450},nil,"Pet","none"},
        {"pet_screech","Screech",{24423},nil,"Pet","none"},
        {"pet_furious_howl","Furious Howl",{24604},nil,"Pet","none"},
        {"pet_lightning_breath","Lightning Breath",{24844},nil,"Pet","harm"},
        {"pet_scorpid_poison","Scorpid Poison",{24640},nil,"Pet","harm"},
        {"pet_shell_shield","Shell Shield",{26064},nil,"Pet","none"},
        {"pet_thunderstomp","Thunderstomp",{26090},nil,"Pet","none"},
    },
    WARLOCK={
        {"pet_firebolt","Firebolt",{3110},nil,"Pet","harm"},
        {"pet_blood_pact","Blood Pact",{6307},nil,"Pet","none"},
        {"pet_fire_shield","Fire Shield",{2947},nil,"Pet","help"},
        {"pet_phase_shift","Phase Shift",{4511},nil,"Pet","none"},
        {"pet_torment","Torment",{3716},nil,"Pet","harm"},
        {"pet_consume_shadows","Consume Shadows",{17767},nil,"Pet","none"},
        {"pet_suffering","Suffering",{17735},nil,"Pet","none"},
        {"pet_lash_pain","Lash of Pain",{7814},nil,"Pet","harm"},
        {"pet_soothing_kiss","Soothing Kiss",{6360},nil,"Pet","harm"},
        {"pet_lesser_invisibility","Lesser Invisibility",{7870},nil,"Pet","none"},
        {"pet_tainted_blood","Tainted Blood",{19478},nil,"Pet","none"},
        {"pet_paranoia","Paranoia",{19480},nil,"Pet","none"},
    },
}
local foreverRows = {
    MAGE = {
        {"frost_blast", "Frost Blast", {}, "SHIFT-E", "Control", "harm"},
        {"ice_lance", "Ice Lance", {}, "BUTTON5", "Attack", "harm"},
        {"arcane_blast", "Arcane Blast", {}, "CTRL-X", "Attack", "harm"},
        {"frostfire_bolt", "Frostfire Bolt", {}, "SHIFT-V", "Attack", "harm"},
        {"comprehend_scroll", "Comprehend Scroll", {}, "CTRL-7", "Utility", "none"},
    },
    WARRIOR = {
        {"victory_rush", "Victory Rush", {}, "CTRL-1", "Healing", "harm"},
        {"spearing_strike", "Spearing Strike", {}, "CTRL-2", "Attack", "harm"},
    },
    ROGUE = {
        {"mutilate", "Mutilate", {}, "5", "Attack", "harm"},
        {"venom", "Venom", {}, "CTRL-R", "Offense", "harm"},
    },
    HUNTER = {
        {"summon_hawk", "Summon Hawk", {}, "SHIFT-F", "Attack", "harm"},
        {"sniper_shot", "Sniper Shot", {}, "SHIFT-E", "Attack", "harm"},
        {"strider_kick", "Strider Kick", {}, "SHIFT-BUTTON4", "Movement", "harm"},
    },
    PALADIN = {
        {"holy_strike", "Holy Strike", {}, "1", "Attack", "harm"},
        {"seal_fury", "Seal of Fury", {}, "SHIFT-6", "Tank", "self"},
        {"voice_truth", "Voice of Truth", {}, "SHIFT-BUTTON5", "Defense", "self"},
        {"lights_vigil", "Light's Vigil", {}, "B", "Healing", "help"},
        {"lights_vigil_enemy", "Light's Vigil", {}, "CTRL-6", "Attack", "harm"},
        {"swift_judgement", "Swift Judgement", {}, "CTRL-X", "Tank", "self"},
        {"templars_bulwark", "Templar's Bulwark", {}, "CTRL-G", "Defense", "self"},
    },
    SHAMAN = {
        {"water_shield", "Water Shield", {}, "SHIFT-BUTTON4", "Resource", "self"},
        {"riptide", "Riptide", {}, "SHIFT-BUTTON5", "Healing", "help"},
        {"totemic_projection", "Totemic Projection", {}, "MOUSEWHEELDOWN", "Utility", "ground"},
        {"totemic_recall", "Totemic Recall", {}, "CTRL-E", "Utility", "none"},
        {"call_elements", "Call of the Elements", {}, "MOUSEWHEELUP", "Totems", "none"},
        {"call_spirits", "Call of the Spirits", {}, "SHIFT-MOUSEWHEELUP", "Totems", "none"},
        {"call_ancestors", "Call of the Ancestors", {}, "SHIFT-MOUSEWHEELDOWN", "Totems", "none"},
        {"lava_burst", "Lava Burst", {}, "CTRL-R", "Attack", "harm"},
        {"rage_farseer", "Rage of the Farseer", {}, "X", "Offense", "self"},
    },
    PRIEST = {
        {"prayer_mending", "Prayer of Mending", {}, "B", "Healing", "help"},
        {"penance", "Penance", {}, "BUTTON4", "Healing", "help"},
        {"penance_enemy", "Penance", {}, "CTRL-BUTTON4", "Attack", "harm"},
        {"binding_heal", "Binding Heal", {}, "SHIFT-BUTTON4", "Healing", "help"},
        {"shadow_word_death", "Shadow Word: Death", {}, "CTRL-X", "Attack", "harm"},
        {"confounding_flash", "Confounding Flash", {}, "CTRL-MOUSEWHEELUP", "Control", "none"},
        {"contingency_plan", "Contingency Plan", {}, "CTRL-BUTTON5", "Defense", "help"},
        {"chastise", "Chastise", {}, "CTRL-MOUSEWHEELDOWN", "Control", "harm"},
        {"divine_grace", "Divine Grace", {}, "CTRL-G", "Healing", "help", {noSelf = true}},
        {"dark_sacrifice", "Dark Sacrifice", {}, "9", "Resource", "self"},
    },
    WARLOCK = {
        {"wrack", "Wrack", {}, "MOUSEWHEELUP", "Attack", "harm"},
        {"incinerate", "Incinerate", {}, "MOUSEWHEELDOWN", "Attack", "harm"},
        {"bane_havoc", "Bane of Havoc", {}, "CTRL-R", "Bane", "harm"},
        {"summon_incubus", "Summon Incubus", {}, "CTRL-9", "Pet", "none"},
    },
}

-- Explicit version changes keep obsolete abilities from occupying slots used
-- by new actions. Talent choices never move druid's persistent bank.
local foreverRemoved = {
    HUNTER = {wyvern_sting = true},
    PRIEST = {lightwell = true},
    SHAMAN = {tranquil_air = true, elemental_mastery = true},
    WARLOCK = {curse_shadow = true, dark_pact = true},
}
local foreverMoves = {
    ROGUE = {feint = "6"},
    PRIEST = {fortitude = "7", fear_ward = "CTRL-Q", prayer_spirit = "CTRL-7", shadowguard = "CTRL-8"},
    PALADIN = {seal_righteousness = "6", blessing_might = "CTRL-7"},
}
local foreverRenames = {
    SHAMAN = {fire_nova = "Fire Nova"},
    PALADIN = {blessing_salvation = "Salvation", greater_salvation = "Mass Salvation"},
    WARLOCK = {curse_agony = "Bane of Agony", curse_doom = "Bane of Doom"},
}

function P:Get(class, flavor)
    class = string.upper(tostring(class or ""))
    flavor = string.lower(tostring(flavor or "classic"))
    if class == "DRUID" then return druid(flavor) end
    local list = {}
    addRows(list, string.lower(class), catalog[class] or {})
    if flavor~="retail" then
        local first=#list
        addRows(list,string.lower(class),petRows[class] or {})
        local keys={"1","2","3","4","5","6","7","8","9","0","H","Y","U","N"}
        for i=first+1,#list do list[i].petSpell=true; list[i].priority=70; list[i].key="CTRL-SHIFT-"..keys[i-first] end
    end
    if flavor == "forever" then
        for index = #list, 1, -1 do
            local entry = list[index]
            local shortID = string.match(entry.id, "^[^.]+%.(.+)$")
            if (foreverRemoved[class] or {})[shortID] then
                table.remove(list, index)
            else
                entry.key = (foreverMoves[class] or {})[shortID] or entry.key
                local renamed = (foreverRenames[class] or {})[shortID]
                if renamed then
                    entry.name, entry.spellIDs, entry.spellNames = renamed, {}, {renamed}
                end
            end
        end
        addRows(list, string.lower(class), foreverRows[class] or {})
    end
    return list
end
