"""Original quest wording and missing-text fallback; mocked client APIs."""
from pathlib import Path
import runpy
root=Path(__file__).resolve().parents[1]
lua=runpy.run_path(str(root/'tools/check.py'))['lua']
lua.execute(r''' 
A.log[990123]={index=7}
C_QuestLog=C_QuestLog or {}
C_QuestLog.GetLogIndexForQuestID=function(id) assert(id==990123); return 7 end
GetQuestLogQuestText=function(index) assert(index==7); return "First paragraph.\n\nSecond paragraph.","Return to Alba." end
C_QuestLog.GetQuestObjectives=function() return {{text="Return to Alba.",finished=true}} end
local lines=A.QuestLogWords({id=990123,name="Explosive Consultation"})
local text=table.concat(lines,"\n")
assert(text:find("First paragraph.\n\nSecond paragraph.",1,true))
assert(text:find("Return to Alba. (Complete)",1,true))
assert(not A.QuestLogWords({id=990124,name="Unaccepted"}))
GetQuestLogQuestText=function() error("unavailable") end
C_QuestLog.GetQuestObjectives=function() return nil end
assert(not A.QuestLogWords({id=990123,name="Unavailable"}))
print("PASS: original quest wording, paragraphs, completion, unaccepted quests and unavailable text")
''')
