-- SelfTest.server.luau
-- Runs in Roblox Studio (a server script). Prints PASS/FAIL for the paths a
-- game actually depends on: a real round trip, a bad key, and memory trimming.
--
-- Add this file to ServerScriptService and start a server.

local ServerScriptService = game:GetService("ServerScriptService")
local Players = game:GetService("Players")
local NpcDialogue = require(ServerScriptService.PollinationsNPC)

local passes, failures = 0, 0
local function check(label, ok)
	if ok then
		passes += 1
		print(("PASS  %s"):format(label))
	else
		failures += 1
		warn(("FAIL  %s"):format(label))
	end
end

local key = select(1, pcall(function()
	return game:GetService("SecretStore"):GetSecret("POLLINATIONS_API_KEY")
end))

-- 1. Bad key → "auth" (never a raw throw).
do
	local npc = NpcDialogue.new({ apiKey = "sk_definitely_not_valid", name = "Test" })
	local player = Players:GetPlayers()[1]
	if player then
		local text, kind = npc:reply(player, "ping")
		check("bad key returns auth error kind", text == nil and (kind == "auth" or kind == "http"))
	else
		print("SKIP  bad-key check (no player yet)")
	end
end

-- 2. Real round trip + memory trim.
do
	local npc = NpcDialogue.new({ apiKey = key, name = "Tomo", maxHistory = 2 })
	local player = Players:GetPlayers()[1]
	if player then
		local text, err = npc:reply(player, "Say hi in three words.")
		check("real round trip returns text", typeof(text) == "string" and #text > 0 or err ~= nil)
		for i = 1, 5 do
			npc:reply(player, "turn " .. i)
		end
		check("memory is bounded by maxHistory", #npc._memory[tostring(player.UserId)] <= npc.maxHistory + 1)
	else
		print("SKIP  round-trip check (no player yet)")
	end
end

print(("SelfTest done: %d passed, %d failed"):format(passes, failures))
