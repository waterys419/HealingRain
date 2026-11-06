-- Offline regression harness: WoW's load order, secure mutation guard, opaque vitals.
local source = arg[1] or 'HealingRain.lua'
local combat, raid, members = false, false, (arg[2]=='solo' and 1 or 3)
local secureContext = false
local frames, named = {}, {}
local M = {}
local function protected(f)
    if combat and f.protected and not secureContext then error('protected frame mutation in combat') end
end
local function frame(kind, name, parent, template)
    local f = setmetatable({kind=kind,name=name,parent=parent,template=template or '',attrs={},scripts={},events={},refs={},visible=true,level=1}, {__index=M})
    frames[#frames+1]=f
    if name then named[name]=f; _G[name]=f end
    if f.template:find('Secure') then
        local p=f
        while p do p.protected=true;p=p.parent end
    end
    return f
end
function M:SetAttribute(k,v) protected(self);self.attrs[k]=v end
function M:GetAttribute(k) return self.attrs[k] end
function M:SetFrameRef(k,v) protected(self);self.refs[k]=v end
function M:GetFrameRef(k) return self.refs[k] end
function M:GetName() return self.name end
function M:SetScript(k,v) self.scripts[k]=v end
function M:RegisterEvent(e) self.events[e]=true end
function M:Show() protected(self);self.visible=true end
function M:Hide() protected(self);self.visible=false end
function M:SetHeight(v) protected(self);self.height=v end
function M:GetHeight() return self.height or 1080 end
function M:SetWidth(v) protected(self);self.width=v end
function M:SetSize(w,h) protected(self);self.width=w;self.height=h end
function M:SetPoint(...) protected(self);self.point={...} end
function M:SetAllPoints(...) protected(self) end
function M:SetMinMaxValues(a,b) self.minimum=a;self.maximum=b end
function M:SetValue(v) self.value=v end
function M:SetText(t) self.text=t end
function M:GetText() return self.text end
function M:SetFormattedText(fmt, ...) self.formatted=(...);self.format=fmt;self.values={...};self.text=fmt end
function M:GetFont() return 'font',12,'' end
function M:GetFrameLevel() return self.level end
function M:SetFrameLevel(v) self.level=v end
function M:CreateFontString(name,...) return frame('FontString',name,self) end
function M:CreateTexture(name,...) return frame('Texture',name,self) end
function M:SetScrollChild(f) self.child=f end
function M:RegisterForClicks(...) self.clicks={...} end
function M:ClearBindings() self.overrides={} end
function M:SetBindingClick(priority,key,name,button) self.overrides=self.overrides or {}; self.overrides[key]={name,button} end
for _, k in ipairs({'SetBackdrop','SetBackdropColor','SetBackdropBorderColor','SetMovable','EnableMouse','RegisterForDrag','StartMoving','StopMovingOrSizing','SetFont','SetShadowOffset','SetTextColor','SetStatusBarColor','SetStatusBarTexture','SetColorTexture','SetFrameStrata','SetClampedToScreen','SetScale','SetAutoFocus','ClearFocus','ClearAllPoints','SetWordWrap','SetTexture','SetTexCoord','SetHighlightTexture'}) do M[k]=function() end end
function M:RegisterForDrag(...) self.dragButtons={...} end
function M:StartMoving() protected(self);self.moving=true end
function M:StopMovingOrSizing() protected(self);self.moving=false end
function M:SetUserPlaced(value) protected(self);self.userPlaced=value end
CreateFrame=frame
UIParent=frame('Frame','UIParent');UIParent.height=1080
Minimap=frame('Frame','Minimap');Minimap.width=140;Minimap.height=140
function M:GetWidth() return self.width end
function M:GetCenter() return 100,100 end
function M:GetEffectiveScale() return 1 end
local ctrl=false
local alt=false
function IsAltKeyDown() return alt end
function IsControlKeyDown() return ctrl end
function GetCursorPosition() return 200,100 end
SlashCmdList={};UISpecialFrames={}
function InCombatLockdown() return combat end
function IsInRaid() return raid end
function IsInGroup() return members>1 end
function GetNumGroupMembers() return members end
local targetExists=false
function UnitExists(u) return u=='player' or (u=='target' and targetExists) or (u:match('raid(%d+)') and tonumber(u:match('%d+'))<=members) or (u:match('party(%d+)') and tonumber(u:match('%d+'))<members) end
function UnitClass() return 'Priest','PRIEST' end
function GetUnitName(u) return u end
local opaque=setmetatable({}, {__lt=function() error('secret comparison') end,__le=function() error('secret comparison') end,__div=function() error('secret division') end,__mul=function() error('secret math') end})
local secretHealth=false
function issecretvalue(v) return v==opaque end
function UnitHealth() return secretHealth and opaque or 50 end
function UnitHealthMax() return secretHealth and opaque or 100 end
function UnitPower() return secretHealth and opaque or 80 end
function UnitPowerMax() return secretHealth and opaque or 100 end
function UnitIsDeadOrGhost() return false end
CurveConstants={ScaleTo100={}}
function UnitHealthPercent() return secretHealth and opaque or 50 end
function SetBinding() error('must not overwrite player bindings') end
function SetBindingClick() error('must not overwrite player bindings') end
function SaveBindings() error('must not persist player bindings') end
function SecureHandlerExecute(f,snippet)
    local fn=assert(loadstring(snippet));setfenv(fn,setmetatable({self=f},{__index=_G}));
    secureContext=true;local ok,err=pcall(fn);secureContext=false;assert(ok,err)
end
local function emit(ev,...)
    for _,f in ipairs(frames) do if f.events[ev] then f.scripts.OnEvent(f,ev,...) end end
end
assert(loadfile(source))('HealingRain')
-- Blizzard restores SavedVariables AFTER executing addon files.
HealingRainDB={small='lesser heal'}
emit('ADDON_LOADED','HealingRain')
emit('PLAYER_LOGIN')
if arg[2]=='solo' then
    assert(named.HealingRainPanel.width==HealingRainDB.frames.width)
    assert(not named.HealingRainHeading.visible and not named.HealingRainTargetPanel.visible)
    assert(named.HealingRainCell1.attrs.unit=='player')
    members=3;emit('GROUP_ROSTER_UPDATE')
    print('PASS: initial solo login followed by party join')
end
assert(HealingRainDB.binds.AltLeft=='lesser heal','legacy spell lost')
assert(named.HealingRainCell1.attrs.type1=='target','blank left must target')
assert(named.HealingRainCell1.attrs['alt-spell1']=='lesser heal')
assert(named.HealingRainCell3.attrs.unit=='party2','three-player party incomplete')
assert(not named.HealingRainCell4)
SlashCmdList.HEALINGRAIN('config')
local edits,save,close={},nil,nil
for _,f in ipairs(frames) do
    if f.kind=='EditBox' and not f.name then edits[#edits+1]=f end
    if f.text=='Save' then save=f end
    if f.text=='Close' then close=f end
end
assert(#edits==36,'20 mouse + 8 wheel + 8 hover edit boxes required')
assert(save and close,'missing save/close')
close.scripts.OnClick();assert(not named.HealingRainConfig.visible)
SlashCmdList.HEALINGRAIN('config');assert(named.HealingRainConfig.visible)
edits[1]:SetText('Lesser Heal')
save.scripts.OnClick()
assert(named.HealingRainCell1.attrs.type1=='spell')
assert(named.HealingRainCell1.attrs.spell1=='Lesser Heal')
-- Secure hover execution scopes wheel keys to the actual cell, and releases them.
SecureHandlerExecute(named.HealingRainCell3,named.HealingRainCell3.attrs._onenter)
assert(named.HealingRainCell3.overrides.MOUSEWHEELUP)
assert(named.HealingRainKeyWheelUp.attrs.unit=='party2')
SecureHandlerExecute(named.HealingRainCell3,named.HealingRainCell3.attrs._onleave)
assert(next(named.HealingRainCell3.overrides)==nil)
-- Health events update even in combat, without protected mutations or secret arithmetic.
combat=true; secretHealth=true
emit('UNIT_HEALTH','party2')
local vitals=0
for _,f in ipairs(frames) do if f.kind=='StatusBar' and f.value==opaque then vitals=vitals+1 end end
assert(vitals==6,'all three health and mana bars must update during combat')
edits[1]:SetText('Flash Heal');save.scripts.OnClick()
assert(named.HealingRainCell1.attrs.spell1=='Lesser Heal','combat save changed protected attributes')
SlashCmdList.HEALINGRAIN('demo');assert(not named.HealingRainCell40,'combat demo created frames')
combat=false;secretHealth=false;emit('PLAYER_REGEN_ENABLED')
assert(named.HealingRainCell1.attrs.spell1=='Flash Heal','pending binding not applied')
SlashCmdList.HEALINGRAIN('demo')
assert(named.HealingRainCell40 and named.HealingRainCell40.attrs.unit==nil)
SlashCmdList.HEALINGRAIN('live')
assert(not named.HealingRainCell40.parent.visible)
assert(named.HealingRainPanel.height==150,'demo height not reset')
raid=true;members=40;emit('GROUP_ROSTER_UPDATE')
assert(named.HealingRainCell1.attrs.unit=='raid1')
assert(named.HealingRainCell40.attrs.unit=='raid40')
assert(not named.HealingRainCell41,'raid duplicated player')
-- Appearance choices apply to live cells and the demo, and survive reinitialization.
local function labelFor(cell, kind)
    for _,f in ipairs(frames) do
        if f.kind=='FontString' and f.parent.kind=='StatusBar' and f.parent.parent==cell.parent then
            if kind=='name' and not f.format and f.text~='DEAD' then return f end
            if kind=='health' and f.format then return f end
        end
    end
end
local nameButton=named.HealingRainOptionnameStyle
local healthButton=named.HealingRainOptionhealthStyle
-- Initials selected from full; next choices are first + last initial, 3 letters, first, last.
local expected={'W. S.','Water S.','Wat Sto','Water','Storm','Water Storm'}
SlashCmdList.HEALINGRAIN('demo')
for _,want in ipairs(expected) do
    nameButton.scripts.OnClick();save.scripts.OnClick()
    assert(labelFor(named.HealingRainCell1,'name').text==want,'bad name style: '..want)
end
healthButton.scripts.OnClick();save.scripts.OnClick()
local health=labelFor(named.HealingRainCell1,'health')
assert(health.format=='%.0f' and health.values[1]==1000)
healthButton.scripts.OnClick();save.scripts.OnClick()
assert(health.format=='%.0f / %.0f' and health.values[2]==1000)
healthButton.scripts.OnClick();save.scripts.OnClick()
assert(health.format=='%.0f (%.0f%%)' and health.values[2]==100)
healthButton.scripts.OnClick();save.scripts.OnClick();assert(health.text=='')
healthButton.scripts.OnClick();save.scripts.OnClick();assert(health.format=='%.0f%%')
named.HealingRainBarWidth:SetText('140');named.HealingRainBarHeight:SetText('52');save.scripts.OnClick()
assert(named.HealingRainCell40.parent.width==140 and named.HealingRainCell40.parent.height==52)
assert(named.HealingRainPanel.height==310)
SlashCmdList.HEALINGRAIN('live')
combat=true;secretHealth=true
for i=1,5 do healthButton.scripts.OnClick();save.scripts.OnClick();emit('UNIT_HEALTH') end
named.HealingRainBarWidth:SetText('180');save.scripts.OnClick()
assert(named.HealingRainCell1.parent.width==140,'resized in combat')
combat=false;secretHealth=false;emit('PLAYER_REGEN_ENABLED')
assert(named.HealingRainCell1.parent.width==180)
-- Missing/invalid dimensions clamp without discarding the working layout.
named.HealingRainBarWidth:SetText('bad');named.HealingRainBarHeight:SetText('999');save.scripts.OnClick()
assert(HealingRainDB.frames.width==180 and HealingRainDB.frames.height==100)
-- Unicode truncation and names without a last name.
GetUnitName=function() return 'Élodie Étang' end
HealingRainDB.frames.nameStyle='three';emit('UNIT_NAME_UPDATE')
assert(labelFor(named.HealingRainCell1,'name').text=='Élo Éta')
GetUnitName=function() return 'Water' end
HealingRainDB.frames.nameStyle='last';emit('UNIT_NAME_UPDATE')
assert(labelFor(named.HealingRainCell1,'name').text=='Water')
GetUnitName=function() return opaque end
emit('UNIT_NAME_UPDATE')
assert(labelFor(named.HealingRainCell1,'name').text==opaque)
emit('ADDON_LOADED','HealingRain')
assert(HealingRainDB.frames.width==180 and HealingRainDB.frames.healthStyle=='percent')
print('PASS: appearance styles, Unicode names, health formats, secret values, resize, demo preview and deferred layout')
print('PASS: saved-settings migration, full GUI, clicks, scoped hover, combat vitals, deferred save, demo, party and 40-player raid')

-- Literal target selects the clicked unit instead of trying to cast a spell.
edits[1]:SetText(' TARGET ');save.scripts.OnClick()
assert(named.HealingRainCell1.attrs.type1=='target')
assert(named.HealingRainCell1.attrs.spell1==nil)
close.scripts.OnClick()
named.HealingRainHeading.scripts.OnClick(named.HealingRainHeading,'RightButton')
assert(named.HealingRainConfig.visible)
close.scripts.OnClick()
local mini=named.HealingRainMinimapButton
mini.scripts.OnClick(mini,'LeftButton');assert(named.HealingRainConfig.visible)
close.scripts.OnClick()
mini.scripts.OnDragStart(mini);assert(not mini.scripts.OnUpdate,'drag requires ctrl')
ctrl=true;mini.scripts.OnDragStart(mini);mini.scripts.OnUpdate()
assert(HealingRainDB.minimap.angle==0)
mini.scripts.OnDragStop(mini);assert(not mini.scripts.OnUpdate)
mini.scripts.OnClick(mini,'LeftButton');assert(not named.HealingRainConfig.visible,'drag must not open config')
ctrl=false
print('PASS: target action, heading settings, minimap settings and Ctrl-drag persistence')

-- The target's secure unit token stays constant while selection changes in combat.
local target=named.HealingRainTargetButton
assert(target and target.attrs.unit=='target')
edits[1]:SetText('Smite');save.scripts.OnClick()
assert(target.attrs.type1=='spell' and target.attrs.spell1=='Smite')
assert(named.HealingRainCell1.attrs.unit=='raid1','raid click target changed')
targetExists=true;combat=true;secretHealth=true
emit('PLAYER_TARGET_CHANGED')
assert(target.attrs.unit=='target')
local targetBar
for _,f in ipairs(frames) do
 if f.kind=='StatusBar' and f.parent==target.parent and f.value==opaque then targetBar=f end
end
assert(targetBar,'target vitals did not update in combat')
SecureHandlerExecute(target,target.attrs._onenter)
assert(named.HealingRainKeyWheelUp.attrs.unit=='target')
SecureHandlerExecute(target,target.attrs._onleave)
combat=false;secretHealth=false
SlashCmdList.HEALINGRAIN('target');assert(not named.HealingRainTargetPanel.visible)
SlashCmdList.HEALINGRAIN('target');assert(named.HealingRainTargetPanel.visible)
targetExists=false;emit('PLAYER_TARGET_CHANGED')
assert(targetBar.value==0,'cleared target still shows old health')
print('PASS: separate target frame, Smite binding, in-combat target changes, hover unit and visibility toggle')

-- Solo layout and secure group transitions, including deferred combat changes.
function M:SetBackdropColor(...) self.backdropColor={...} end
function M:SetBackdropBorderColor(...) self.borderColor={...} end
function M:SetPoint(...) protected(self);self.point={...} end
local panel=named.HealingRainPanel
local heading=named.HealingRainHeading
local first=named.HealingRainCell1.parent
local title
for _,f in ipairs(frames) do
    if f.parent==panel and f.text=='|cffffd200Raid|r' then title=f end
end
assert(title)
raid=false;members=1
emit('GROUP_ROSTER_UPDATE')
assert(panel.width==HealingRainDB.frames.width and panel.height==HealingRainDB.frames.height)
assert(panel.backdropColor[4]==0 and panel.borderColor[4]==0)
assert(not title.visible and not heading.visible and not named.HealingRainTargetPanel.visible)
assert(first.visible and first.point[2]==0 and first.point[3]==0)
assert(named.HealingRainCell1.attrs.unit=='player')
assert(not named.HealingRainCell2.parent.visible)
assert(HealingRainDB.frames.showTarget,'solo must preserve target preference')
combat=true;members=3;emit('GROUP_ROSTER_UPDATE')
assert(not heading.visible and panel.width==HealingRainDB.frames.width,'combat join changed layout')
combat=false;emit('PLAYER_REGEN_ENABLED')
assert(title.visible and heading.visible and named.HealingRainTargetPanel.visible)
assert(panel.backdropColor[4]==0.92 and panel.borderColor[4]==0.9)
assert(first.point[2]==8 and first.point[3]==-26)
assert(named.HealingRainCell3.attrs.unit=='party2')
combat=true;members=1;emit('GROUP_ROSTER_UPDATE')
assert(heading.visible,'combat leave changed layout')
combat=false;emit('PLAYER_REGEN_ENABLED')
assert(not heading.visible and not named.HealingRainTargetPanel.visible)
SlashCmdList.HEALINGRAIN('target');SlashCmdList.HEALINGRAIN('target')
assert(not named.HealingRainTargetPanel.visible,'target toggle exposed solo target box')
raid=true;members=1;emit('GROUP_ROSTER_UPDATE')
assert(heading.visible,'one-member raid must retain raid layout')
raid=false;emit('GROUP_ROSTER_UPDATE')
SlashCmdList.HEALINGRAIN('demo');assert(heading.visible)
SlashCmdList.HEALINGRAIN('live');assert(not heading.visible)
print('PASS: solo square, group restoration, target preference, demo and combat-deferred join/leave')

-- Dragging leaves all secure heal bindings and click handling intact.
local square=named.HealingRainCell1
local clickType=square.attrs.type1
local altSpell=square.attrs['alt-spell1']
assert(square.dragButtons[1]=='LeftButton')
assert(square.scripts.OnClick==nil and square.scripts.PreClick==nil)
alt=false;square.scripts.OnDragStart(square,'LeftButton');assert(not panel.moving)
alt=true;square.scripts.OnDragStart(square,'RightButton');assert(not panel.moving)
square.scripts.OnDragStart(square,'LeftButton');assert(panel.moving)
square.scripts.OnDragStop(square);assert(not panel.moving and panel.userPlaced)
assert(square.attrs.type1==clickType and square.attrs['alt-spell1']==altSpell)
assert(square.attrs.useOnKeyDown==false)
members=3;emit('GROUP_ROSTER_UPDATE')
local partySquare=named.HealingRainCell3
partySquare.scripts.OnDragStart(partySquare,'LeftButton');assert(panel.moving)
partySquare.scripts.OnDragStop(partySquare);assert(not panel.moving)
local targetSquare=named.HealingRainTargetButton
local targetPanel=named.HealingRainTargetPanel
targetSquare.scripts.OnDragStart(targetSquare,'LeftButton')
assert(targetPanel.moving and not panel.moving)
targetSquare.scripts.OnDragStop(targetSquare);assert(targetPanel.userPlaced)
combat=true;square.scripts.OnDragStart(square,'LeftButton');assert(not panel.moving)
square.scripts.OnDragStop(square)
combat=false;square.scripts.OnDragStart(square,'LeftButton');assert(panel.moving)
combat=true;square.scripts.OnDragStop(square) -- defer protected stop if combat began mid-drag
combat=false;emit('PLAYER_REGEN_ENABLED');assert(not panel.moving)
local realPrint=print
local help={};print=function(t) help[#help+1]=t end
combat=true;SlashCmdList.HEALINGRAIN('help');combat=false;print=realPrint
assert(table.concat(help,' '):find('Alt + left-drag',1,true))
print('PASS: solo/group/target Alt-drag, saved position flag, unchanged clicks, combat guards and help')

-- Actual roster dimensions, vertical orientation, subgroup packing and shrinkage.
local subgroups
function GetRaidRosterInfo(i)
    return 'Raider'..i, 0, subgroups and subgroups[i] or math.floor((i-1)/5)+1
end
HealingRainDB.frames.width=86;HealingRainDB.frames.height=36
local function checkGrid(n,inRaid,columns,rows)
    raid=inRaid;members=n;emit('GROUP_ROSTER_UPDATE')
    local solo=not inRaid and n==1
    assert(panel.width==(solo and 86 or 16+columns*86+(columns-1)*4),'wrong width for '..n)
    assert(panel.height==(solo and 36 or 34+rows*36+(rows-1)*4),'wrong height for '..n)
    assert(heading.visible==not solo,'wrong heading visibility')
    for i=1,n do
        local b=named['HealingRainCell'..i]
        local col,row=math.floor((i-1)/5),(i-1)%5
        assert(b.parent.visible,'missing member '..i)
        assert(b.attrs.unit==(inRaid and 'raid'..i or (i==1 and 'player' or 'party'..(i-1))))
        assert(b.parent.point[2]==(solo and 0 or 8)+col*90,'wrong column for member '..i)
        assert(b.parent.point[3]==-(solo and 0 or 26)-row*40,'wrong row for member '..i)
    end
    for i=n+1,40 do
        local b=named['HealingRainCell'..i]
        if b then assert(not b.parent.visible and b.attrs.unit==nil,'stale member '..i) end
    end
end
checkGrid(1,false,1,1)
for n=2,5 do checkGrid(n,false,1,n) end
for _,n in ipairs({10,25,40}) do checkGrid(n,true,n/5,5) end
checkGrid(2,false,1,2) -- shrink from forty to two
checkGrid(1,false,1,1)
-- Partial groups and noncontiguous group numbers: keep members in their subgroup,
-- with neither empty group columns nor empty rows below the largest group.
raid=true;members=5;subgroups={7,2,7,2,7};emit('GROUP_ROSTER_UPDATE')
assert(panel.width==192 and panel.height==150)
for i,slot in ipairs({{1,0},{0,0},{1,1},{0,1},{1,2}}) do
    local p=named['HealingRainCell'..i].parent.point
    assert(p[2]==8+slot[1]*90 and p[3]==-26-slot[2]*40,'subgroup not respected')
end
assert(named.HealingRainTargetButton.parent.point[2]==8 and named.HealingRainTargetButton.parent.point[3]==-26)
-- A membership change during combat must keep the old geometry until combat ends.
combat=true;raid=false;members=2;emit('GROUP_ROSTER_UPDATE')
assert(panel.width==192 and panel.height==150)
combat=false;emit('PLAYER_REGEN_ENABLED');checkGrid(2,false,1,2)
subgroups=nil
-- Fallback for clients without subgroup information still uses columns of five.
GetRaidRosterInfo=nil;checkGrid(10,true,2,5)
print('PASS: solo, parties 2-5, raids 10/25/40, vertical orientation, subgroup packing, shrinkage and deferred sizing')

-- The preview uses real layout sizes but has no actionable unit or click spell.
raid=false;members=1;emit('GROUP_ROSTER_UPDATE')
local function assertPreview(n)
    assert(panel.width==16+math.ceil(n/5)*86+(math.ceil(n/5)-1)*4)
    assert(panel.height==34+math.min(n,5)*36+(math.min(n,5)-1)*4)
    assert(not named.HealingRainTargetPanel.visible)
    for i=1,40 do
        local b=named['HealingRainCell'..i]
        assert(b.parent.visible==(i<=n))
        assert(b.attrs.unit==nil,'preview retained a live unit')
        for _,prefix in ipairs({'','shift-','alt-','ctrl-'}) do
            for button=1,5 do
                assert(b.attrs[prefix..'type'..button]==nil,'preview retained an action')
                assert(b.attrs[prefix..'spell'..button]==nil,'preview retained a spell')
            end
        end
        SecureHandlerExecute(b,b.attrs._onenter)
        assert(not b.overrides or next(b.overrides)==nil,'preview bound wheel/hover casting')
        if i<=n then
            assert(b.parent.point[2]==8+math.floor((i-1)/5)*90)
            assert(b.parent.point[3]==-26-((i-1)%5)*40)
        end
    end
end
-- Clear any hover override left from a live frame on entering demo.
SecureHandlerExecute(named.HealingRainCell1,named.HealingRainCell1.attrs._onenter)
named.HealingRainDemo5.scripts.OnClick();assertPreview(5)
assert(labelFor(named.HealingRainCell1,'name').text~=nil)
local values={}
for _,f in ipairs(frames) do
    if f.kind=='StatusBar' and f.parent==named.HealingRainCell3.parent then values[#values+1]=f.value end
end
assert(values[1]==0.79,'preview has no varied health')
-- Saving settings and roster/vitals events must not re-enable preview actions.
save.scripts.OnClick(save);emit('UNIT_HEALTH');emit('GROUP_ROSTER_UPDATE')
-- Saving restores draft sizes; keep fixed test geometry for the next assertions.
HealingRainDB.frames.width=86;HealingRainDB.frames.height=36;emit('GROUP_ROSTER_UPDATE')
assertPreview(5)
named.HealingRainDemo5.scripts.OnClick();checkGrid(1,false,1,1)
assert(named.HealingRainCell1.attrs.type1~=nil,'leaving preview lost click action')
for _,n in ipairs({10,25,40}) do
    named['HealingRainDemo'..n].scripts.OnClick();assertPreview(n)
    named['HealingRainDemo'..n].scripts.OnClick();checkGrid(1,false,1,1)
end
SlashCmdList.HEALINGRAIN('demo5');assertPreview(5)
SlashCmdList.HEALINGRAIN('demo5');checkGrid(1,false,1,1)
for _,n in ipairs({10,25,40}) do
    SlashCmdList.HEALINGRAIN('demo '..n);assertPreview(n)
end
SlashCmdList.HEALINGRAIN('demo off');checkGrid(1,false,1,1)
combat=true;named.HealingRainDemo5.scripts.OnClick();assert(not heading.visible)
combat=false;SlashCmdList.HEALINGRAIN('demo5')
combat=true;named.HealingRainDemo5.scripts.OnClick();assertPreview(5)
combat=false;SlashCmdList.HEALINGRAIN('demo off')
print('PASS: config and slash demos 5/10/25/40, toggle/off, varied health, no casting/targeting/hover bindings, save safety and combat guards')

-- Resize gesture scales individual squares by occupied columns/rows, not max slots.
local cursorX,cursorY=200,100
function GetCursorPosition() return cursorX,cursorY end
function M:GetLeft() return 100 end
function M:GetTop() return 500 end
local grip=named.HealingRainResizeGrip
local toggle=named.HealingRainSizeToggle
assert(not grip.visible and not HealingRainDB.frames.sizeUnlocked)
assert(toggle.text=='Unlock size')
toggle.scripts.OnClick();assert(grip.visible and toggle.text=='Lock size')
local function dragSize(dx,dy)
    cursorX,cursorY=200,100
    grip.scripts.OnDragStart(grip,'LeftButton')
    cursorX,cursorY=200+dx,100+dy
    grip.scripts.OnUpdate(grip)
    grip.scripts.OnDragStop(grip)
end
for _,case in ipairs({{1,false,1,1},{2,false,1,2},{5,false,1,5},{10,true,2,5},{25,true,5,5},{40,true,8,5}}) do
    HealingRainDB.frames.width=86;HealingRainDB.frames.height=36
    raid=case[2];members=case[1];emit('GROUP_ROSTER_UPDATE')
    dragSize(20*case[3],-10*case[4])
    assert(HealingRainDB.frames.width==106 and HealingRainDB.frames.height==46,'per-cell drag scaling failed')
    assert(named.HealingRainBarWidth.text=='106' and named.HealingRainBarHeight.text=='46')
    local solo=not raid and members==1
    assert(panel.width==(solo and 106 or 16+case[3]*106+(case[3]-1)*4))
    assert(panel.height==(solo and 46 or 34+case[4]*46+(case[4]-1)*4))
    assert(panel.userPlaced)
end
dragSize(100000,-100000)
assert(HealingRainDB.frames.width==240 and HealingRainDB.frames.height==100)
dragSize(-100000,100000)
assert(HealingRainDB.frames.width==60 and HealingRainDB.frames.height==32)
-- Save must use the newly synchronized size fields rather than stale draft numbers.
save.scripts.OnClick(save)
assert(HealingRainDB.frames.width==60 and HealingRainDB.frames.height==32)
raid=false;members=1;emit('GROUP_ROSTER_UPDATE')
named.HealingRainBarWidth:SetText('120');named.HealingRainBarHeight:SetText('50')
save.scripts.OnClick(save)
assert(panel.width==120 and panel.height==50)
named.HealingRainBarWidth:SetText('999');named.HealingRainBarHeight:SetText('2')
save.scripts.OnClick(save)
assert(panel.width==240 and panel.height==32)
assert(named.HealingRainBarWidth.text=='240' and named.HealingRainBarHeight.text=='32')
-- Locked grip and combat attempts do nothing, even if callbacks are invoked directly.
SlashCmdList.HEALINGRAIN('resize');assert(not grip.visible and toggle.text=='Unlock size')
dragSize(-100,100);assert(panel.width==240 and panel.height==32)
combat=true;toggle.scripts.OnClick();assert(not HealingRainDB.frames.sizeUnlocked)
combat=false;toggle.scripts.OnClick()
combat=true;dragSize(-100,100);assert(panel.width==240 and panel.height==32)
combat=false
cursorX,cursorY=200,100;grip.scripts.OnDragStart(grip,'LeftButton')
combat=true;emit('PLAYER_REGEN_DISABLED');cursorX,cursorY=500,0;grip.scripts.OnUpdate(grip)
assert(panel.width==240 and panel.height==32)
combat=false;emit('PLAYER_REGEN_ENABLED');grip.scripts.OnUpdate(grip)
assert(panel.width==240 and panel.height==32,'resize resumed after combat')
-- Correct cursor conversion under UI scaling.
local oldScale=M.GetEffectiveScale
function M:GetEffectiveScale() return self==panel and 2 or 1 end
HealingRainDB.frames.width=86;HealingRainDB.frames.height=36;emit('GROUP_ROSTER_UPDATE')
dragSize(40,-20);assert(panel.width==106 and panel.height==46)
M.GetEffectiveScale=oldScale
-- Resizing demos keeps fake squares inert; lock preference survives DB initialization.
SlashCmdList.HEALINGRAIN('demo5');dragSize(10,-25)
assert(HealingRainDB.frames.width==116 and HealingRainDB.frames.height==51)
for i=1,5 do
    local b=named['HealingRainCell'..i]
    assert(b.attrs.unit==nil and b.attrs.type1==nil and b.attrs['alt-type1']==nil)
end
emit('ADDON_LOADED','HealingRain');assert(HealingRainDB.frames.sizeUnlocked)
SlashCmdList.HEALINGRAIN('demo off')
alt=true;square.scripts.OnDragStart(square,'LeftButton');assert(panel.moving)
square.scripts.OnDragStop(square);assert(not panel.moving)
SlashCmdList.HEALINGRAIN('resize');assert(not grip.visible)
print('PASS: resize lock/config/slash, solo/party/raid per-square scaling, limits, fields/save sync, combat cancellation, UI scale, demo safety and Alt-drag')
