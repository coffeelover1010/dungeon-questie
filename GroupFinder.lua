local _, A = ...

local aliases={stockade="stockades",stormwindstockade="stockades",stormwindstockades="stockades"}
local function key(name)
 local value=(name or ""):lower():gsub("^the%s+",""):gsub("[^%w]","")
 return aliases[value] or value
end

-- Resolve against the client's activities instead of assuming retail dungeon IDs.
function A.GroupActivities(dungeon)
 local ids,seen,category={},{},nil
 local api=C_LFGList
 if not api or not api.GetAvailableCategories or not api.GetAvailableActivities or not api.GetActivityInfoTable then return ids end
 for _,categoryID in ipairs(api.GetAvailableCategories() or {}) do
  for _,id in ipairs(api.GetAvailableActivities(categoryID) or {}) do
   local info=api.GetActivityInfoTable(id)
   local groupName=info and info.groupFinderActivityGroupID and api.GetActivityGroupInfo and api.GetActivityGroupInfo(info.groupFinderActivityGroupID)
   if info and (key(info.fullName)==key(dungeon) or key(info.shortName)==key(dungeon) or (groupName and key(groupName)==key(dungeon))) then
    if not category then category=info.categoryID end
    if info.categoryID==category and not seen[id] then ids[#ids+1]=id; seen[id]=true end
   end
  end
 end
 return ids
end

function A.FindGroup(dungeon)
 if InCombatLockdown() then A.Print("Leave combat before opening the Group Browser."); return end
 if not C_LFGInfo or not C_LFGInfo.CanPlayerUsePremadeGroup or not C_LFGInfo.CanPlayerUsePremadeGroup() then
  A.Print("The Group Browser is not available to this character right now."); return
 end
 if not LFGBrowseFrame and GroupFinderVanillaStyle_LoadUI then GroupFinderVanillaStyle_LoadUI() end
 local browser=LFGBrowseFrame
 if not browser or not browser.ShowSearchForActivities or not LFGVanilla_ShowFrame then
  A.Print("The Group Browser could not be opened."); return
 end
 -- Do not replace filters while the native browser is completing an older search.
 if browser.searching then A.Print("Wait for the current Group Browser search to finish, then try again."); return end
 local activities=A.GroupActivities(dungeon)
 if #activities==0 then
  if A.recruit and A.recruit.frame then A.recruit.frame:Hide() end
  LFGVanilla_ShowFrame(2)
  if browser.ResetDropdowns then browser:ResetDropdowns() end
  A.Print("No available LFG activity matched "..dungeon..". Choose an activity in the Group Browser.")
 else
  browser:ShowSearchForActivities(activities)
  if A.OpenRecruit then A.OpenRecruit(dungeon,activities) end
 end
 if A.window then A.window:Hide() end
end
