local _, A = ...
-- Blizzard textures verified in the local Forever 1.60.1.70170 archive.
-- Forever-only entries use themed substitutes, not claimed dungeon portraits.
local dungeonIcons={
 ["Ragefire Chasm"]="RagefireChasm", ["Deadmines"]="Deadmines",
 ["Wailing Caverns"]="WailingCaverns", ["Shadowfang Keep"]="ShadowfangKeep",
 ["Blackfathom Deeps"]="BlackfathomDeeps", ["Stormwind Stockade"]="StormwindStockades",
 ["Razorfen Kraul"]="RazorfenKraul", ["Gnomeregan"]="Gnomeregan",
 ["Scarlet Monastery"]="ScarletMonastery", ["Razorfen Downs"]="RazorfenDowns",
 ["Uldaman"]="Uldaman", ["Zul'Farrak"]="ZulFarak", ["Maraudon"]="Maraudon",
 ["Sunken Temple"]="SunkenTemple", ["Blackrock Depths"]="BlackrockDepths",
 ["Dire Maul"]="DireMaul", ["Lower Blackrock Spire"]="BlackrockSpire",
 ["Upper Blackrock Spire"]="UpperBlackrockSpire", ["Scholomance"]="Scholomance",
 ["Stratholme"]="Stratholme",
}
local themedIcons={
 ["The Hall of Thanes"]="Achievement_Zone_Ironforge",
 ["Excavation Site: Wetlands"]="Achievement_Zone_Wetlands_01",
 ["City of Dalaran"]="Spell_Arcane_PortalDalaran",
 ["The Drowned City"]="Achievement_Zone_Azshara_01",
 ["Krol'dok Stronghold"]="Achievement_Zone_Stranglethorn_01",
 ["Alcaz Prison"]="Achievement_Zone_DustwallowMarsh",
 ["Blackmaw Hold"]="Achievement_Zone_Felwood",
 ["The Shaper's Terrace"]="Achievement_Zone_UnGoroCrater_01",
}
A.dungeonArtwork={}
for name,icon in pairs(dungeonIcons) do A.dungeonArtwork[name]="Interface\\LFGFrame\\LFGIcon-"..icon end
for name,icon in pairs(themedIcons) do A.dungeonArtwork[name]="Interface\\Icons\\"..icon end
-- Existing Lordaeron scenery, used as a thematic substitute for the new dungeon.
A.dungeonArtwork["Ruins of Lordaeron"]="Interface\\LFGFrame\\LFGIcon-RuinsofLordaeron"

-- One preview for the selected current step, not one texture set per quest.
-- Same map-art contract as Forever's Blizzard_MapCanvasDetailLayer.lua.
function A.CreateLocationArtwork(parent)
 local f=CreateFrame("Button",nil,parent); f:SetSize(300,190); f:SetPoint("TOPLEFT")
 f.tiles={}
 f.background=f:CreateTexture(nil,"BACKGROUND"); f.background:SetAllPoints()
 f.background:SetColorTexture(0.29,0.20,0.10,0.12)
 f.caption=f:CreateFontString(nil,"OVERLAY"); f.caption:SetFont("Fonts\\FRIZQT__.TTF",11,"")
 f.caption:SetPoint("BOTTOMLEFT",4,4); f.caption:SetWidth(292); f.caption:SetTextColor(0.20,0.12,0.05)
 f.marker=f:CreateTexture(nil,"OVERLAY"); f.marker:SetSize(12,12)
 f.marker:SetTexture("Interface\\WorldMap\\WorldMapPartyIcon")
 f:SetScript("OnClick",function(self) if self.target then A.Navigate(self.target) end end)
 f:SetScript("OnEnter",function(self)
  GameTooltip:SetOwner(self,"ANCHOR_RIGHT"); GameTooltip:AddLine(self.tip or "Location unavailable",1,1,1,true); GameTooltip:Show()
 end)
 f:SetScript("OnLeave",function() GameTooltip:Hide() end)
 return f
end
function A.UpdateLocationArtwork(f,q,target,tip)
 if not q then f:Hide(); return 0 end
 f:Show(); f.target=target; f:SetEnabled(target~=nil); f.tip=tip
 local p=target and target.pin
 local map=p and p.map
 local art=map and A.Safe(C_Map and C_Map.GetMapArtID,map)
 -- Cache only the currently displayed map. Failed loads are retried on refresh.
 if f.map~=map or f.art~=art or not f.loaded then
  f.map=map; f.art=art; f.loaded=false
  for _,t in ipairs(f.tiles) do t:Hide(); t:SetTexture(nil) end
  local layers=map and A.Safe(C_Map and C_Map.GetMapArtLayers,map)
  local layer=type(layers)=="table" and layers[1]
  local textures=layer and A.Safe(C_Map and C_Map.GetMapArtLayerTextures,map,1)
  if layer and type(textures)=="table" and type(layer.layerWidth)=="number" and type(layer.layerHeight)=="number"
   and type(layer.tileWidth)=="number" and type(layer.tileHeight)=="number"
   and layer.layerWidth>0 and layer.layerHeight>0 and layer.tileWidth>0 and layer.tileHeight>0 then
   local cols=math.ceil(layer.layerWidth/layer.tileWidth)
   local rows=math.ceil(layer.layerHeight/layer.tileHeight)
   local complete=cols*rows<=64
   for i=1,cols*rows do if not textures[i] or textures[i]==0 then complete=false end end
   if complete then
    local scale=math.min(300/layer.layerWidth,150/layer.layerHeight)
    f.artWidth=layer.layerWidth*scale; f.artHeight=layer.layerHeight*scale
    f.artLeft=(300-f.artWidth)/2
    for row=1,rows do for col=1,cols do
     local i=(row-1)*cols+col
     local t=f.tiles[i] or f:CreateTexture(nil,"ARTWORK"); f.tiles[i]=t
     local x,y=(col-1)*layer.tileWidth,(row-1)*layer.tileHeight
     local w,h=math.min(layer.tileWidth,layer.layerWidth-x),math.min(layer.tileHeight,layer.layerHeight-y)
     t:ClearAllPoints(); t:SetPoint("TOPLEFT",f,"TOPLEFT",f.artLeft+x*scale,-y*scale)
     t:SetSize(w*scale,h*scale); t:SetTexCoord(0,w/layer.tileWidth,0,h/layer.tileHeight)
     local ok,result=pcall(t.SetTexture,t,textures[i])
     if not ok or result==false then complete=false end
     t:Show()
    end end
    f.loaded=complete
   end
  end
  if not f.loaded then for _,t in ipairs(f.tiles) do t:Hide() end end
 end
 f.marker:Hide()
 if p then
  local label=p.zone..string.format("  %.1f, %.1f",p.x,p.y)
  local qualifier=p.kind=="entrance" and "Entrance / approach" or (p.reference and "Reference coordinates" or "Recorded destination")
  f.caption:SetText(label.."\n"..(f.loaded and qualifier.." - click map" or "Map artwork unavailable - click to open"))
  if f.loaded then
   f.marker:ClearAllPoints(); f.marker:SetPoint("CENTER",f,"TOPLEFT",f.artLeft+f.artWidth*p.x/100,-f.artHeight*p.y/100); f.marker:Show()
  end
 else
  f.caption:SetText("Location not mapped\nSee the current instructions below")
 end
 f:SetHeight(f.loaded and 190 or 44)
 return (f.loaded and 190 or 44)+10
end
