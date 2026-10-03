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
