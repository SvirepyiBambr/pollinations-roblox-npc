local ServerScriptService = game:GetService("ServerScriptService")
local Players = game:GetService("Players")

local NpcDialogue = require(ServerScriptService.PollinationsNPC)

-- Read the key from the Secrets Store so it never reaches a client.
local apiKey = game:GetService("SecretStore"):GetSecret("POLLINATIONS_API_KEY")

-- A trivial NPC model so the example place is playable without extra setup.
local tomo = Instance.new("Model")
tomo.Name = "Tomo"
local head = Instance.new("Part")
head.Name = "Head"
head.Shape = Enum.PartType.Ball
head.Size = Vector3.new(2, 2, 2)
head.Position = Vector3.new(0, 4, 0)
head.Anchored = true
head.BrickColor = BrickColor.new("Bright orange")
head.Parent = tomo
tomo.PrimaryPart = head
tomo.Parent = workspace

local dialogue = NpcDialogue.attach(tomo, {
	apiKey = apiKey,
	name = "Tomo",
	persona = "You keep the old lighthouse on Pollen Island and love bad sea puns.",
})

-- Minimal playable loop: type in "say <message>" and Tomo answers.
Players.PlayerAdded:Connect(function(player)
	player.Chatted:Connect(function(message)
		local text, err = dialogue:reply(player, message)
		if text then
			print(("Tomo → %s: %s"):format(player.Name, text))
		else
			warn(("Tomo is quiet right now (%s)"):format(err))
		end
	end)
end)

Players.PlayerRemoving:Connect(function(player)
	dialogue:forget(player)
end)

print("Pollinations NPC example ready — say something in chat.")
