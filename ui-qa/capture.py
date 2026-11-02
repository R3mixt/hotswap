"""Capture the actual addon widget tree with deterministic offline sample data.

Run ``python ui-qa/capture.py`` then ``pwsh -File ui-qa/render.ps1``.
The JSON is geometry and styling from Lua, not a hand-built UI mockup. Blizzard
artwork and client rendering remain approximations in the PNG renderer.
"""
from pathlib import Path
import json, math, sys
from icon_assets import verify as verify_icons
ROOT = Path(__file__).resolve().parent.parent
icon_manifest = verify_icons()
sys.path.insert(0, str(ROOT/'python-deps'))
from lupa.lua51 import LuaRuntime
lua = LuaRuntime(unpack_returned_tuples=True)
lua.execute((ROOT/'tests/mock.lua').read_text(encoding='utf-8'))
lua.execute(r'''
QA={}
local anchor={TOPLEFT={0,1},TOP={.5,1},TOPRIGHT={1,1},LEFT={0,.5},CENTER={.5,.5},RIGHT={1,.5},BOTTOMLEFT={0,0},BOTTOM={.5,0},BOTTOMRIGHT={1,0}}
local function geom(f,depth)
 depth=(depth or 0)+1;if depth>30 then error('mock geometry cycle') end
 if not f or f==UIParent then return 0,0,1920,1080 end
 if f.sliderOwner then
   local owner=f.sliderOwner;local x,y,w,h=geom(owner,depth);local lo,hi=owner:GetMinMaxValues()
   local ratio=hi>lo and math.max(0,math.min(1,(owner:GetValue()-lo)/(hi-lo))) or 0
   local tw,th=f.width or 9,f.height or 18
   if owner.orientation=='VERTICAL' then return x+(w-tw)/2,y+(1-ratio)*(h-th),tw,th end
   return x+ratio*(w-tw),y+(h-th)/2,tw,th
 end
 if f.all then return geom(f.all,depth) end
 local w,h=f.width,f.height
 if f.kind=='FontString' then w=w or (#tostring(f.text)*(f.fontsize or 12)*.66+16);h=h or (f.fontsize or 12)*1.4 end
 local points={}
 for _,p in ipairs(f.points or {}) do local x,y,rw,rh=geom(p.rel,depth);local a,b=anchor[p.point],anchor[p.rp];points[#points+1]={a[1],a[2],x+rw*b[1]+p.x,y+rh*b[2]+p.y} end
 if #points==0 then local x,y,pw,ph=geom(f.parent,depth);if f.scrollHost then return x,y+ph-(h or 1),w or pw,h or 1 end;return x,y,w or pw,h or ph end
 for _,p in ipairs(points) do for _,q in ipairs(points) do if math.abs(p[1]-q[1])>.1 then w=(p[3]-q[3])/(p[1]-q[1]) end;if math.abs(p[2]-q[2])>.1 then h=(p[4]-q[4])/(p[2]-q[2]) end end end
 w=w or 1;h=h or 1;local p=points[1];return p[3]-p[1]*w,p[4]-p[2]*h,w,h
end
local oldCreate=CreateFrame
function CreateFrame(kind,name,parent,template)
 local f=oldCreate(kind,name,parent,template)
 f.qid=#QA+1; QA[f.qid]=f; f.shown=true; f.points={}
 function f:SetPoint(point,a,b,c,d)
   local rel,rp,x,y
   if type(a)=='table' then rel=a; rp=b or point; x=c or 0; y=d or 0
   elseif type(a)=='number' then rel=self.parent or UIParent;rp=point;x=a;y=b or 0
   else rel=self.parent or UIParent;rp=point;x=0;y=0 end
   self.points[#self.points+1]={point=point,rel=rel,rp=rp,x=x,y=y}
 end
 function f:ClearAllPoints() self.points={}; self.all=nil end
 function f:SetAllPoints(other) self.all=other or self.parent end
 function f:SetWidth(v) self.width=v end
 function f:SetHeight(v) self.height=v end
 function f:SetFrameLevel(v) self.frameLevel=v end
 function f:GetFrameLevel() return self.frameLevel or 1 end
 function f:GetWidth() local _,_,w=geom(self);return w end
 function f:GetHeight() local _,_,_,h=geom(self);return h end
 function f:SetBackdropColor(...) self.fill={...} end
 function f:GetBackdropColor() return unpack(self.fill or {1,1,1,1}) end
 function f:SetBackdropBorderColor(...) self.border={...} end
 function f:GetBackdropBorderColor() return unpack(self.border or {1,1,1,1}) end
 function f:SetColorTexture(...) self.fill={...};self.texture=nil end
 function f:SetTexture(value) self.texture=value;self.fill=nil end
 function f:SetTexCoord(...) self.texCoord={...} end
 function f:SetTextColor(...) self.color={...} end
 function f:GetTextColor() return unpack(self.color or {1,1,1,1}) end
 function f:GetVertexColor() return unpack(self.vertexColor or {1,1,1,1}) end
 function f:SetOrientation(value) self.orientation=value end
 function f:SetFont(path,size,flags) self.fontsize=size; self.fontpath=path; self.font={path,size,flags or ''} end
 function f:SetWordWrap(v) self.wrap=v end
 function f:SetJustifyH(v) self.justify=v end
 function f:SetJustifyV(v) self.justifyV=v end
 function f:CreateFontString(name,layer,font)
   local fs=CreateFrame('FontString',name,self);fs.fontObject=font
   fs.layer=layer or 'OVERLAY'
   fs.fontsize=font and font:find('Large') and 16 or font and font:find('Small') and 10 or 12
   return fs
 end
 function f:CreateTexture(name,layer,template,sublevel)
   local texture=CreateFrame('Texture',name,self);texture.layer=layer or 'ARTWORK';texture.sublevel=sublevel or 0;return texture
 end
 function f:GetThumbTexture()
   if not self.thumb then self.thumb=CreateFrame('Texture',nil,self);self.thumb.sliderOwner=self;self.thumb.layer='OVERLAY';self.thumb:SetSize(9,18) end
   return self.thumb
 end
 function f:SetScrollChild(child) self.scrollChild=child; child.scrollHost=self end
 function f:GetStringHeight() return (self.fontsize or 12)*math.max(1,math.ceil(#tostring(self.text)/(math.max(10,(self.width or 400)/((self.fontsize or 12)*0.53))))) end
 if template=='UIPanelCloseButton' then f:SetSize(24,24) end
 if template=='UICheckButtonTemplate' then f:SetSize(26,26) end
 -- Minimal XML geometry for built-in template children. Runtime code may
 -- override these anchors, exactly as it does with the client's template.
 if template=='BasicFrameTemplateWithInset' then
   f.TitleText:SetPoint('TOPLEFT',f,'TOPLEFT',12,-5);f.TitleText:SetPoint('TOPRIGHT',f,'TOPRIGHT',-32,-5);f.TitleText:SetHeight(20)
   f.CloseButton:SetPoint('TOPRIGHT',f,'TOPRIGHT',-4,-4)
   f.Inset:SetPoint('TOPLEFT',f,'TOPLEFT',4,-24);f.Inset:SetPoint('BOTTOMRIGHT',f,'BOTTOMRIGHT',-4,4)
 end
 local oldFont=f.GetFontString
 function f:GetFontString()
   local fs=oldFont(self)
   fs:ClearAllPoints();fs:SetPoint('CENTER');fs:SetJustifyH('CENTER');fs:SetJustifyV('MIDDLE')
   fs:SetTextColor(1,.82,0);fs:SetFont(STANDARD_TEXT_FONT,12)
   return fs
 end
 return f
end
''')
lua.execute((ROOT/'tests/native_mock.lua').read_text(encoding='utf-8'))
namespace=lua.table()
modules=[line.strip()[:-4] for line in (ROOT/'KeybindOptimizer/KeybindOptimizer.toc').read_text().splitlines() if line.strip().endswith('.lua')]
for module in modules:
    lua.compile((ROOT/'KeybindOptimizer'/f'{module}.lua').read_text(encoding='utf-8-sig'))('KeybindOptimizer',namespace)
lua.globals().K=namespace
lua.globals().TestAddon=namespace
icons=lua.table()
for key,entry in icon_manifest['entities'].items():
    record=lua.table()
    for field,value in entry.items():record[field]=value
    icons[key]=record
lua.globals().PreviewIcons=icons
lua.execute(r'''
Mock.build='1.15.9'; Mock.buildNumber='70576'
-- Resolve art for both learned and unlearned spells, without changing learning.
for key,entry in pairs(PreviewIcons) do
    if entry.kind=='spell' then
        local known=Mock:Spell(entry.id)
        if known then known.icon='ICON:'..key
        else Mock.catalog[entry.id]={id=entry.id,name=entry.name,icon='ICON:'..key} end
    end
end
for _,macro in pairs(Mock.macros) do macro.icon='Interface\\Icons\\INV_Misc_QuestionMark' end
local originalItemInfo=GetItemInfo
function GetItemInfo(id)
    local values={originalItemInfo(id)}
    if values[1] and PreviewIcons['item:'..id] then values[10]='ICON:item:'..id end
    return unpack(values)
end
C_Item.GetItemInfo=GetItemInfo
function GetInventoryItemTexture(unit,slot)
    local id=Mock.equipment[slot]
    return id and PreviewIcons['item:'..id] and 'ICON:item:'..id or nil
end
local originalBagItemInfo=C_Container.GetContainerItemInfo
function C_Container.GetContainerItemInfo(bag,slot)
    local item=originalBagItemInfo(bag,slot)
    if item and PreviewIcons['item:'..item.itemID] then item.iconFileID='ICON:item:'..item.itemID end
    return item
end
function GetShapeshiftFormInfo(index)
    local form=Mock.forms[index]
    if form then return 'ICON:spell:'..form.id,false,true,form.id end
end
K:Init(); K:GetSettings().flavor='era'
Mock.itemInfo[5512]={name='Minor Healthstone',effect='Restores health'}
Mock.itemInfo[1710]={name='Greater Healing Potion',effect='Restores health'}
Mock.itemInfo[4388]={name='Discombobulator Ray',effect='Discombobulator Ray'}
Mock.itemInfo[14530]={name='Heavy Runecloth Bandage',effect='First Aid'}
Mock.itemInfo[10577]={name='Goblin Mortar',effect='Goblin Mortar',equipLoc='INVTYPE_TRINKET'}
Mock.bagItems[0]={{id=5512,count=2},{id=4388,count=1},{id=14530,count=8}}
K.Items:SetBindingItem('item.utility',4388)
K.Items:AddAlternative('item.utility',1710)
K.Items:AddAlternative('item.utility',14530)
K.Items:AddAlternative('item.utility',10577)
K.Items:SetBindingItem('item.healthstone',5512)
K.Presets:Create('Dungeon healer',true); K.Presets:SetHotkey('Dungeon healer','CTRL-F11')
K.Presets:Create('Travel and gathering',true); K.Presets:SetHotkey('Travel and gathering','CTRL-F12')
K.Presets:Select('Leveling')
K.UI:Open()
''')
anchors={'TOPLEFT':(0,1),'TOP':(.5,1),'TOPRIGHT':(1,1),'LEFT':(0,.5),'CENTER':(.5,.5),'RIGHT':(1,.5),'BOTTOMLEFT':(0,0),'BOTTOM':(.5,0),'BOTTOMRIGHT':(1,0)}
cases=[('Setup','setup',None,None),('Presets','presets',None,None),('Bindings','bindings','caster',''),('Bindings','bindings-shift','caster','SHIFT-'),('Bindings','bindings-cat','cat',''),('Bindings','bindings-test','cat',''),('Items','items',None,None),('Safety','safety',None,None),('Share','share',None,None),('Bindings','library-spells','caster',''),('Bindings','library-ranks','caster',''),('Bindings','library-items','caster',''),('Bindings','library-macros','caster','')]
cases.extend([('Setup','action-bars',None,None),('Settings','settings',None,None),('Settings','diagnostic-log',None,None),('Setup','operation-error',None,None)])
cases.extend([('Settings','settings-controls',None,None),('Settings','settings-bars',None,None),('Settings','settings-window',None,None),('Settings','settings-diagnostics',None,None),('Bindings','talent-choices','caster',''),('Bindings','talent-own','caster','')])
cases.append(('Bindings','hover-bind','caster',''))
cases.append(('Bindings','save-preset','caster',''))
cases.extend([('Bindings','bindings-current',None,''),('Bindings','current-hover',None,''),('Bindings','bindings-recommendation','caster','')])
showcase_cases=[]
for theme in ('classic','modern'):
    showcase_cases.extend([
        ('Bindings',f'{theme}-current',None,''),
        ('Presets',f'{theme}-presets',None,None),
        ('Settings',f'{theme}-settings',None,None),
        ('Bindings',f'{theme}-spellbook','caster',''),
    ])
if namespace.Themes:
    cases.extend(showcase_cases)
uncached_icons=set()
for page,output_name,form,layer in cases:
    showcase=output_name.startswith(('classic-','modern-'))
    theme=output_name.split('-',1)[0] if showcase else 'classic'
    filename={'current':'bindings-current','settings':'settings-window','spellbook':'library-spells'}.get(output_name.split('-',1)[-1],output_name.split('-',1)[-1]) if showcase else output_name
    if showcase:
        # Populate a representative current layout from actual Blizzard binding
        # commands and spell IDs. None of this sample data reaches SavedVariables.
        lua.execute(r'''
K.UI:ClearOperationError(); K.Engine.lastJob=nil
K.UI.selectedAction=nil; K.UI.selectedKey=nil
Mock.bindings.W='MOVEFORWARD'; Mock.bindings.A='STRAFELEFT'; Mock.bindings.S='MOVEBACKWARD'; Mock.bindings.D='STRAFERIGHT'; Mock.bindings.SPACE='JUMP'
local spells={5177,8921,2912,19970,2637,1058,8936,5185,1126,467}
for slot,id in ipairs(spells) do
    Mock.actions[slot]={'spell',id}
    Mock.bindings[slot==10 and '0' or tostring(slot)]='ACTIONBUTTON'..slot
end
Mock.actions[11]={'spell',768}; Mock.bindings.Q='ACTIONBUTTON11'
Mock.actions[12]={'spell',783}; Mock.bindings.E='ACTIONBUTTON12'
K.UI.libraryCategory=nil; K.UI.libraryQuery=''; K.UI.libraryRanks=false
''')
        namespace.Themes.Set(namespace.Themes,theme)
    lua.execute('for _,name in ipairs({"nativeBarsDialog","diagnosticLogDialog","operationErrorDialog","talentDialog","saveDialog"}) do local f=K.UI[name]; if f then f:Hide() end end')
    if filename.startswith('settings-') or filename.startswith('talent-'):
        lua.execute('K.UI:ClearOperationError()')
    lua.globals().K.UI.libraryOpen=filename.startswith('library-') or filename=='bindings-current'
    if filename in ('bindings-current','current-hover'):
        lua.execute('Mock.bindings["1"]="ACTIONBUTTON1"; Mock.actions[1]={"spell",5176}; K.UI:ClearOperationError(); K.UI:Open()')
    elif filename == 'bindings-recommendation':
        lua.execute('K.UI:ClearOperationError(); K.UI:PreviewRecommendations()')
    else:
        lua.execute('K.UI:SetBindingSource("draft")')
    if form:lua.globals().K.UI.SetActionPage(lua.globals().K.UI,form)
    if layer is not None:lua.globals().K.UI.pinnedLayer=layer
    lua.globals().K.UI.ShowPage(lua.globals().K.UI,page)
    sections={'settings-controls':'Controls','settings-bars':'Action bars','settings-window':'Window','settings-diagnostics':'Diagnostics'}
    if filename in sections:
        lua.globals().K.SettingsUI.ShowSection(lua.globals().K.SettingsUI,lua.globals().K.UI.pages.Settings,sections[filename])
    if filename == 'talent-choices':
        lua.execute('K.TalentBindings:SetChoices("druid.form_moonkin",{"druid.form_moonkin","druid.natures_swiftness","druid.swiftmend"}); K.UI:Refresh(); for _,a in ipairs(K.UI.plan.actions) do if a.id=="druid.form_moonkin" then K.UI:OpenTalentChoices(a); break end end')
    if filename == 'talent-own':
        lua.execute('K.TalentBindings:SetMode("druid.form_moonkin","separate"); K.UI:Refresh(); for _,a in ipairs(K.UI.plan.actions) do if a.id=="druid.form_moonkin" then K.UI:OpenTalentChoices(a); break end end')
    if filename == 'save-preset':
        lua.execute('K.UI:ClearOperationError(); K.UI:PromptSavePreset(nil,true)')
    if filename == 'current-hover':
        lua.execute('K.UI:OpenHoverBindings()')
    if filename == 'hover-bind':
        lua.execute('K.UI:ClearOperationError(); K.UI:OpenHoverBindings()')
    if filename == 'action-bars':
        lua.globals().K.UI.OpenNativeBars(lua.globals().K.UI)
    if filename == 'diagnostic-log':
        lua.execute('K.Diagnostics:SetEnabled(true); K.Diagnostics:Record("error","step-error","Sample: the client rejected a binding.",{operation="apply",stage="Installing bindings",key="F6",command="TARGETFOCUS",backup="backup-example"}); K.SettingsUI:OpenLog()')
    if filename == 'operation-error':
        lua.execute('K.Engine.lastJob={kind="apply",finished=true,ok=false,rollingBack=true,message="Setup failed and was rolled back: Sample binding failure.",failure="The client rejected F6 (Target focus; TARGETFOCUS).",failureStage="Installing bindings",entry={id="backup-example",name="Character-Druid-2026-11-01 17:00:00",complete=true}}; K.UI:OnOperationComplete(false,K.Engine.lastJob.message,"apply")')
    if filename == 'bindings-test':
        lua.globals().K.UI.TestKeyDown(lua.globals().K.UI,'1')
    if filename == 'share':
        lua.globals().K.UI.ExportToShare(lua.globals().K.UI,True)
    if filename.startswith('library-'):
        lua.globals().K.UI.libraryTab='spells' if filename=='library-ranks' else filename[8:]
        lua.globals().K.UI.libraryRanks=filename=='library-ranks'
        lua.globals().K.UI.SyncLibrary(lua.globals().K.UI)
    if showcase and filename=='bindings-current':
        lua.execute('local cap=K.UI.pages.Bindings.keyboard.keys["1"]; if cap and cap.action then K.UI.selectedAction=cap.action; K.UI:BindingDetail(cap.action) end')
    nodes={}
    for _,f in lua.globals().QA.items():
        def ident(value):
            if value is None:return None
            return int(value['qid']) if value['qid'] else 0
        n={'id':int(f.qid),'kind':f.kind,'strata':f.strata,'parent':ident(f.parent),'all':ident(f.all),'scrollHost':ident(f.scrollHost),'shown':bool(f.shown),'alpha':f.alpha if isinstance(f.alpha,(int,float)) else 1,'w':f.width,'h':f.height,'text':str(f.GetText(f) or ''),'font':f.fontsize or 12,'fontpath':f.fontpath,'wrap':f.wrap is not False,'justify':f.justify or 'LEFT','justifyV':f.justifyV or 'TOP','points':[], 'template':f.template, 'texture':f.texture if isinstance(f.texture,str) else None,'selected':bool(f.selected),'checked':bool(f.checked),'enabled':f.enabled is not False,'keycap':bool(f.base),'theme':theme,'themeRole':f.hotSwapThemeRole}
        n['texCoord']=list(f.texCoord.values()) if f.texCoord else [0,1,0,1]
        n['desaturated']=bool(f.desaturated)
        if isinstance(f.texture,(int,float)):n['unresolvedTexture']=f.texture
        if n['texture'] and n['texture'].startswith('ICON:'):
            n['icon']=icon_manifest['entities'][n['texture'][5:]]['icon']
        elif n['texture'] and n['texture'].lower().startswith('interface\\icons\\'):
            n['icon']=n['texture'].split('\\')[-1].lower()
        if n.get('icon') and n['icon'] not in icon_manifest['assets']:
            uncached_icons.add(n['icon'])
        if f.backdrop:n['backdrop']={k:v for k,v in f.backdrop.items() if k in ('bgFile','edgeFile','edgeSize')}
        n['layer']=f.layer or ('OVERLAY' if f.kind=='FontString' else 'ARTWORK')
        n['sublevel']=f.sublevel if isinstance(f.sublevel,(int,float)) else 0
        n['sliderOwner']=ident(f.sliderOwner)
        n['orientation']=f.orientation
        n['value']=f.value if isinstance(f.value,(int,float)) else 0
        n['minimum']=f.minimum if isinstance(f.minimum,(int,float)) else 0
        n['maximum']=f.maximum if isinstance(f.maximum,(int,float)) else 1
        parent=f.parent
        # Native button state textures are displayed conditionally by the client.
        if parent:
            for key in ('highlightTexture','pushedTexture','disabledTexture','disabledCheckedTexture','checkedTexture'):
                region=parent[key]
                if region and region.qid==f.qid:
                    n['shown']=key=='checkedTexture' and bool(parent.checked)
        for name in ('fill','border','color','vertexColor'):
            val=f[name];n[name]=list(val.values()) if val else None
        for _,p in f.points.items():n['points'].append([p.point,ident(p.rel),p.rp,p.x,p.y])
        nodes[n['id']]=n
    cache={0:(0,0,1920,1080)}
    def bounds(i,stack=None):
        if i in cache:return cache[i]
        if i is None:return cache[0]
        n=nodes[i];stack=(stack or [])+[i]
        if len(stack)>30:raise RuntimeError('anchor cycle '+str(stack))
        if n['sliderOwner'] is not None:
            owner=nodes[n['sliderOwner']];x,y,w,h=bounds(n['sliderOwner'],stack)
            span=owner['maximum']-owner['minimum']
            ratio=max(0,min(1,(owner['value']-owner['minimum'])/span)) if span>0 else 0
            tw,th=n['w'] or 9,n['h'] or 18
            cache[i]=(x+(w-tw)/2,y+(1-ratio)*(h-th),tw,th) if owner['orientation']=='VERTICAL' else (x+ratio*(w-tw),y+(h-th)/2,tw,th)
            return cache[i]
        if n['all'] is not None: cache[i]=bounds(n['all'],stack);return cache[i]
        w=n['w'];h=n['h']
        if n['kind']=='FontString':
            w=w or len(n['text'])*n['font']*.66+16
            lines=max(1,math.ceil(len(n['text'])*n['font']*.53/max(1,w))) if n['wrap'] else 1
            h=h or n['font']*1.4*lines
        ps=[]
        for a,rel,rp,x,y in n['points']:
            rx,ry,rw,rh=bounds(rel,stack);ra,rb=anchors[rp];ax,ay=anchors[a]
            ps.append((ax,ay,rx+rw*ra+x,ry+rh*rb+y))
        if not ps:
            if n['scrollHost'] is not None:
                px,py,pw,ph=bounds(n['scrollHost'],stack);cache[i]=(px,py+ph-(h or 1),w or pw,h or 1);return cache[i]
            px,py,pw,ph=bounds(n['parent'],stack);cache[i]=(px,py,w or pw,h or ph);return cache[i]
        for p in ps:
            for q in ps:
                if abs(p[0]-q[0])>0.1:w=(p[2]-q[2])/(p[0]-q[0])
                if abs(p[1]-q[1])>0.1:h=(p[3]-q[3])/(p[1]-q[1])
        w=w or 1;h=h or 1;p=ps[0];cache[i]=(p[2]-p[0]*w,p[3]-p[1]*h,w,h);return cache[i]
    def visible(i):
        return i is None or i==0 or (nodes[i]['shown'] and nodes[i]['alpha']>0 and visible(nodes[i]['parent']))
    frame_id=int(lua.globals().K.UI.frame.qid);fx,fy,fw,fh=bounds(frame_id)
    if filename.startswith('library-') or filename=='bindings-current':fw+=320
    result=[]
    def depth(i):
        p=nodes[i]['parent']
        return 0 if not p else depth(p)+1
    # Template child regions can be created before their owning frame.
    strata_order={'BACKGROUND':0,'LOW':1,'MEDIUM':2,'HIGH':3,'DIALOG':4,'FULLSCREEN':5,'FULLSCREEN_DIALOG':6,'TOOLTIP':7}
    def strata(i):
        n=nodes[i]
        return strata_order.get(n['strata'],2) if n['strata'] else (strata(n['parent']) if n['parent'] else 2)
    draw_layers={'BACKGROUND':0,'BORDER':1,'ARTWORK':2,'OVERLAY':3,'HIGHLIGHT':4}
    def draw_order(row):
        i,n=row
        region=n['kind'] in ('FontString','Texture')
        # Frame artwork is behind its regions. Region draw layers matter:
        # a Modern background texture can be created after a title FontString.
        return (strata(i),depth(n['parent']) if region and n['parent'] else depth(i),draw_layers.get(n['layer'],2) if region else -1,n['sublevel'],i)
    ordered=sorted(nodes.items(),key=draw_order)
    for i,n in ordered:
        if not visible(i):continue
        x,y,w,h=bounds(i)
        if x>fx+fw or y>fy+fh or x+w<fx or y+h<fy:continue
        # Enforce scrolling viewport clipping in the mock image.
        ancestor=n;clip=(fx,fy,fw,fh)
        while ancestor:
            if ancestor['scrollHost'] is not None:
                cx,cy,cw,ch=bounds(ancestor['scrollHost']); lx=max(clip[0],cx);by=max(clip[1],cy);rx=min(clip[0]+clip[2],cx+cw);ty=min(clip[1]+clip[3],cy+ch);clip=(lx,by,max(0,rx-lx),max(0,ty-by))
            ancestor=nodes.get(ancestor['parent'])
        n.update(x=x-fx,y=fy+fh-y-h,w=w,h=h,clip=[clip[0]-fx,fy+fh-clip[1]-clip[3],clip[2],clip[3]])
        result.append(n)
    (ROOT/'ui-qa'/f'{output_name}.json').write_text(json.dumps(result),encoding='utf-8')
    print(output_name, 'captured',len(result),'visible native UI objects')
if uncached_icons:
    raise RuntimeError('Uncached icon assets: '+', '.join(sorted(uncached_icons)))
print('Actual UI.lua instantiated successfully under Lua 5.1. Mock geometry only; no game-client claim.')
