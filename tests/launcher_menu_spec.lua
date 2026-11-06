-- Pin the requested native Game Menu integration. These lifecycle tests do
-- not emulate the client's protected execution or taint propagation.
function Tests.launcher_registration_does_not_build_a_hidden_native_menu()
 local k=TestAddon; k:Init(); local menu=Mock:CreateGameMenu(true)
 local originalInit=menu.InitButtons; local builds=0
 menu.InitButtons=function(self) builds=builds+1; return originalInit(self) end
 local pool,buttons=menu.buttonPool,menu.activeButtons
 assert(k.Launcher:RegisterMenu())
 assert(builds==0,"Registration rebuilt a hidden native menu")
 assert(menu.buttonPool==pool and menu.activeButtons==buttons and #buttons==0,"Registration acquired a button before the hidden menu was built")
 assert(not menu:IsShown(),"Registration opened the native menu")
 assert(k.Launcher:RegisterMenu() and builds==0 and #buttons==0,"Repeated registration built a hidden menu")
end

function Tests.launcher_registering_open_menu_appends_once_after_addons_without_rebuilding()
 local k=TestAddon; k:Init(); local menu=Mock:CreateGameMenu(true)
 local originalInit=menu.InitButtons; local builds=0
 menu.InitButtons=function(self) builds=builds+1; return originalInit(self) end
 menu:Show()
 local nativeButtons=menu.activeButtons; local originals={unpack(nativeButtons)}; local count=#nativeButtons
 k.Launcher:RegisterMenu(); local button=k.Launcher.menuButton
 assert(builds==1 and menu.activeButtons==nativeButtons,"Registration rebuilt the already open native menu")
 assert(button and button:GetParent()==menu and button:GetText()=="Hot Swap","Launcher was not integrated into the native menu")
 assert(#nativeButtons==count+1,"Registration did not append exactly one button")
 local addons,logout
 for index,original in ipairs(originals) do
  assert(nativeButtons[index]==original,"Registration replaced an existing native button")
  if original:GetText()==(ADDONS or "AddOns") then addons=original end
  if original:GetText()=="Logout" then logout=original end
 end
 assert(addons and logout and button.layoutIndex>addons.layoutIndex and button.layoutIndex<logout.layoutIndex,
  "Launcher was not placed immediately after AddOns in the native layout")
 for index=1,3 do
  k.Launcher:AppendMenuButton(menu); k.Launcher:RegisterMenu()
  assert(k.Launcher.menuButton==button and #nativeButtons==count+1 and builds==1,"Repeated append or registration duplicated/rebuilt the launcher")
 end
end

function Tests.launcher_active_native_menu_ignores_an_obsolete_initbuttons_callback()
 local k=TestAddon; k:Init(); local first=Mock:CreateGameMenu(true)
 k.Launcher:RegisterMenu(); first:Show()
 assert(#first.activeButtons==4,"First menu did not receive its launcher")
 local second=Mock:CreateGameMenu(true); k.Launcher:RegisterMenu(); second:Show()
 local button=k.Launcher.menuButton; local buttons=second.activeButtons
 assert(button:GetParent()==second and #buttons==4,"New active menu did not receive its own launcher")
 first:InitButtons()
 assert(#first.activeButtons==3,"An obsolete InitButtons callback appended another launcher")
 assert(k.Launcher.menuButton==button and second.activeButtons==buttons and #buttons==4,"An obsolete callback changed the active launcher")
 first:Hide(); first:Show()
 assert(#first.activeButtons==3 and k.Launcher.menuButton==button,"Showing an obsolete menu reclaimed the launcher")
end
