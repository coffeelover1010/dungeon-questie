local name,A=...
local icons
function A.SetMinimapShown(shown)
 A.db.minimap.hide=not shown
 if icons then icons[shown and "Show" or "Hide"](icons,name) end
end
local events=CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")
events:SetScript("OnEvent",function(self)
 self:UnregisterEvent("PLAYER_LOGIN")
 if not A.db then return end
 icons=LibStub("LibDBIcon-1.0")
 local broker=LibStub("LibDataBroker-1.1")
 local launcher=broker:GetDataObjectByName(name) or broker:NewDataObject(name,{
  type="launcher",text="Dungeon Questie",icon="Interface\\Icons\\INV_Misc_Map_01",
  OnClick=function() A.Toggle() end,
  OnTooltipShow=function(t)
   t:AddLine("Dungeon Questie",1,0.82,0.4)
   t:AddLine("Click to open your dungeon quest checklist.",1,1,1)
   t:AddLine("Drag to move. /dungeons minimap hide to hide.",0.8,0.8,0.8)
   local d,n=A.Count(); t:AddLine(d.." / "..n,0.5,0.85,0.6)
  end,
 })
 if not icons:IsRegistered(name) then icons:Register(name,launcher,A.db.minimap) end
    -- Centre the face on the visible hole in the 64px tracking-ring texture.
    do
        local button = icons:GetMinimapButton(name)
        if button and button.border and button.icon then
            local x, y = button.border:GetWidth() * 20 / 64, -button.border:GetHeight() * 19 / 64
            -- Fill the tracking ring's opening; keep its border and hit area standard.
            local faceSize = button.border:GetWidth() * 26 / 64
            button.icon:SetSize(faceSize, faceSize)
            if not button.foreverFaceMask then
                local mask = button:CreateMaskTexture(nil, "ARTWORK")
                mask:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
                mask:SetAllPoints(button.icon)
                button.icon:AddMaskTexture(mask)
                button.foreverFaceMask = mask
            end
            button.icon:ClearAllPoints()
            button.icon:SetPoint("CENTER", button.border, "TOPLEFT", x, y)
            if button.background then
                button.background:ClearAllPoints()
                button.background:SetPoint("CENTER", button.border, "TOPLEFT", x, y)
            end
        end
    end
end)
