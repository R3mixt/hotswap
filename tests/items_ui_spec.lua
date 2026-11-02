local function fixture()
 Mock.itemInfo[1251]={name="Linen Bandage",effect="Linen Bandage"}
 Mock.itemInfo[1710]={name="Greater Healing Potion",effect="Healing Potion"}
 Mock.bagItems[0]={{id=1251,count=3}}
 local k=TestAddon; k:Init(); k.UI:Open(); k.UI:SetBindingSource("draft"); k.UI:ShowPage("Items")
 return k,k.UI.pages.Items
end
function Tests.items_page_explains_key_current_item_and_missing_saved_choices()
 local k,page=fixture(); Mock:ResetWrites()
 assert(page.context:GetText():find("Leveling",1,true),"Item page omits the preset it edits")
 assert(k.ItemsUI.selected.id=="item.utility","Item page did not select a binding")
 assert(page.currentPanel.name:GetText()=="No item selected")
 page.idInput:SetText("1710"); page.addID:Click()
 assert(#k:GetSettings().itemBindings["item.utility"].alternatives==1,"Add ID did not save the choice")
 assert(not k:GetSettings().itemBindings["item.utility"].selected,"Saving a choice silently changed the primary")
 assert(page.list.rows[1].note:GetText():find("Not in",1,true),"Missing choice does not explain inventory absence")
 page.useChoice:Click()
 assert(k:GetSettings().itemBindings["item.utility"].selected==1710,"Use this item did not select the saved item")
 assert(page.currentPanel.name:GetText()=="Greater Healing Potion")
 assert(page.currentPanel.state:GetText():find("Not in",1,true),"Selected missing item looks available")
 assert(not page.target:IsEnabled(),"Self-use potion offers unsupported targeting modes")
 assert(#Mock.writes==0,"Editing choices applied live bindings")
end
function Tests.items_inventory_chooser_stages_selection_and_fixed_trinkets_stay_slot_based()
 local k,page=fixture(); Mock:ResetWrites()
 page.bagTab:Click()
 local choice
 for _,row in ipairs(page.list.rows) do if row:IsShown() and row.item.id==1251 then choice=row end end
 assert(choice,"Inventory view omitted a usable bandage")
 choice:Click(); page.useChoice:Click()
 assert(k:GetSettings().itemBindings["item.utility"].selected==1251)
 assert(page.target:IsEnabled(),"Verified friendly item targeting is unavailable")
 local trinket
 for _,row in ipairs(page.bindingList.rows) do if row.entry.id=="item.trinket13" then trinket=row end end
 assert(trinket,"Slot-following trinket binding is hidden")
 trinket:Click()
 assert(not page.addID:IsEnabled() and not page.useChoice:IsEnabled(),"Trinket follow-slot row can be accidentally replaced by a bag selection")
 assert(page.currentPanel.active:GetText():find("slot 13",1,true),"Equipped-slot behavior is unexplained")
 assert(#Mock.writes==0)
end
function Tests.items_open_spellbook_button_reliably_opens_its_items_tab()
 local k,page=fixture()
 page.openBook:Click()
 assert(k.UI.activePage=="Bindings" and k.UI.library:IsShown(),"Open spellbook hid the spellbook")
 assert(k.UI.libraryTab=="items","Items page opened the wrong spellbook tab")
 local found=false; for _,entry in ipairs(k.UI.library.entries) do if entry.itemID==1251 then found=true end end
 assert(found,"Item library cannot supply the selected inventory item")
end
