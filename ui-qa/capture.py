"""Render geometry emitted by actual UI.lua. Mock data; never an in-game screenshot."""
from pathlib import Path
import json, math, sys
ROOT = Path(__file__).resolve().parent.parent
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
 function f:ClearAllPoints() self.points={} end
 function f:SetAllPoints(other) self.all=other or self.parent end
 function f:SetWidth(v) self.width=v end
 function f:SetHeight(v) self.height=v end
 function f:SetFrameLevel(v) self.frameLevel=v end
 function f:GetFrameLevel() return self.frameLevel or 1 end
 function f:GetWidth() local _,_,w=geom(self);return w end
 function f:GetHeight() local _,_,_,h=geom(self);return h end
 function f:SetBackdropColor(...) self.fill={...} end
 function f:SetBackdropBorderColor(...) self.border={...} end
 function f:SetColorTexture(...) self.fill={...} end
 function f:SetTextColor(...) self.color={...} end
 function f:SetFont(_,size) self.fontsize=size end
 function f:SetWordWrap(v) self.wrap=v end
 function f:SetJustifyH(v) self.justify=v end
 function f:SetJustifyV(v) self.justifyV=v end
 function f:CreateFontString(name,layer,font)
   local fs=CreateFrame('FontString',name,self);fs.fontObject=font
   fs.fontsize=font and font:find('Large') and 16 or font and font:find('Small') and 10 or 12
   return fs
 end
 function f:CreateTexture() return CreateFrame('Texture',nil,self) end
 function f:GetThumbTexture() if not self.thumb then self.thumb=CreateFrame('Texture',nil,self) end;return self.thumb end
 function f:SetScrollChild(child) self.scrollChild=child; child.scrollHost=self end
 function f:GetStringHeight() return (self.fontsize or 12)*math.max(1,math.ceil(#tostring(self.text)/(math.max(10,(self.width or 400)/((self.fontsize or 12)*0.53))))) end
 if template=='UIPanelCloseButton' then f:SetSize(24,24) end
 if template=='UICheckButtonTemplate' then f:SetSize(26,26) end
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
lua.execute(r'''
K:Init(); K:GetSettings().flavor='era'
for _,s in ipairs(Mock.spells) do s.icon='QA:'..s.name end
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
for page,filename,form,layer in cases:
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
    nodes={}
    for _,f in lua.globals().QA.items():
        def ident(value):
            if value is None:return None
            return int(value['qid']) if value['qid'] else 0
        n={'id':int(f.qid),'kind':f.kind,'strata':f.strata,'parent':ident(f.parent),'all':ident(f.all),'scrollHost':ident(f.scrollHost),'shown':bool(f.shown),'w':f.width,'h':f.height,'text':str(f.GetText(f) or ''),'font':f.fontsize or 12,'wrap':f.wrap is not False,'justify':f.justify or 'LEFT','points':[], 'template':f.template, 'texture':f.texture if isinstance(f.texture,str) else None,'selected':bool(f.selected),'checked':bool(f.checked),'enabled':f.enabled is not False,'keycap':bool(f.base)}
        if f.backdrop:n['backdrop']={k:v for k,v in f.backdrop.items() if k in ('bgFile','edgeFile','edgeSize')}
        parent=f.parent
        # Native button state textures are displayed conditionally by the client.
        if parent:
            for key in ('highlightTexture','pushedTexture','disabledTexture','disabledCheckedTexture','checkedTexture'):
                region=parent[key]
                if region and region.qid==f.qid:
                    n['shown']=key=='checkedTexture' and bool(parent.checked)
        for name in ('fill','border','color'):
            val=f[name];n[name]=list(val.values()) if val else None
        for _,p in f.points.items():n['points'].append([p.point,ident(p.rel),p.rp,p.x,p.y])
        nodes[n['id']]=n
    cache={0:(0,0,1920,1080)}
    def bounds(i,stack=None):
        if i in cache:return cache[i]
        if i is None:return cache[0]
        n=nodes[i];stack=(stack or [])+[i]
        if len(stack)>30:raise RuntimeError('anchor cycle '+str(stack))
        if n['all'] is not None: cache[i]=bounds(n['all'],stack);return cache[i]
        w=n['w'];h=n['h']
        if n['kind']=='FontString':
            w=w or len(n['text'])*n['font']*.66+16
            h=h or n['font']*1.4*max(1,math.ceil(len(n['text'])*n['font']*.53/max(1,w)))
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
        return i is None or i==0 or (nodes[i]['shown'] and visible(nodes[i]['parent']))
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
    ordered=sorted(nodes.items(),key=lambda row:(strata(row[0]),depth(row[0]),row[0]))
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
    (ROOT/'ui-qa'/f'{filename}.json').write_text(json.dumps(result),encoding='utf-8')
    print(filename, 'captured',len(result),'visible native UI objects')
print('Actual UI.lua instantiated successfully under Lua 5.1. Mock geometry only; no game-client claim.')
