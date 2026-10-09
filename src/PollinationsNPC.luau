--!nonstrict
-- PollinationsNPC.luau
-- Give any Roblox NPC a persona and a short per-player memory in a few lines.
--
--     local NpcDialogue = require(ServerScriptService.PollinationsNPC)
--     local npc = NpcDialogue.attach(workspace.Tomo, {
--         name = "Tomo",
--         persona = "You keep the old lighthouse on Pollen Island and love bad sea puns.",
--     })
--     print(npc:reply(player, "Who are you?"))
--
-- The API key is read from Roblox's Secrets Store on the server; it never
-- reaches the client. Memory is per-player and bounded, so a long session can
-- not grow the prompt without limit.

local Pollinations = require(script.Parent.Pollinations)

local NpcDialogue = {}
NpcDialogue.__index = NpcDialogue

local DEFAULT_HISTORY = 6

export type Options = {
	apiKey: string,
	name: string,
	persona: string?,
	model: string?,
	temperature: number?,
	maxHistory: number?,
}

local function buildSystemPrompt(opts: Options): string
	local lines = {
		("You are %s, an NPC in a Roblox game."):format(opts.name),
	}
	if opts.persona and #opts.persona > 0 then
		table.insert(lines, opts.persona)
	end
	table.insert(lines, "Reply in character, in one or two short spoken sentences.")
	table.insert(lines, "Keep everything appropriate for players of all ages.")
	table.insert(lines, "Never mention being an AI, a model, or an API.")
	return table.concat(lines, " ")
end

-- Returns a fresh dialogue instance (does not touch any instance).
function NpcDialogue.new(opts: Options)
	assert(typeof(opts) == "table", "NpcDialogue.new: options table is required")
	assert(typeof(opts.name) == "string" and #opts.name > 0, "NpcDialogue.new: name is required")

	local self = setmetatable({}, NpcDialogue)
	self.client = Pollinations.new({
		apiKey = opts.apiKey,
		model = opts.model,
		temperature = opts.temperature,
	})
	self.system = buildSystemPrompt(opts)
	self.maxHistory = opts.maxHistory or DEFAULT_HISTORY
	self._memory = {} -- [playerId] = { Message }
	return self
end

-- Answers `message` from `player`, remembering the last few turns for that
-- player. Returns (text, nil) on success or (nil, kind) on failure.
function NpcDialogue:reply(player, message)
	assert(typeof(player) == "Instance" and player:IsA("Player"), "NpcDialogue:reply: a Player is required")
	assert(typeof(message) == "string" and #message > 0, "NpcDialogue:reply: message must be a non-empty string")

	local id = tostring(player.UserId)
	local history = self._memory[id]
	if not history then
		history = {}
		self._memory[id] = history
	end

	table.insert(history, { role = "user", content = message })
	while #history > self.maxHistory do
		table.remove(history, 1)
	end

	local messages = { { role = "system", content = self.system } }
	for _, m in ipairs(history) do
		table.insert(messages, m)
	end

	local text, kind = self.client:chat(messages)
	if not text then
		-- Drop the failed turn so a retry starts from a clean state.
		table.remove(history, #history)
		return nil, kind
	end

	table.insert(history, { role = "assistant", content = text })
	return text, nil
end

-- Forgets one player's conversation (call on PlayerRemoving).
function NpcDialogue:forget(player)
	self._memory[tostring(player.UserId)] = nil
end

-- Convenience: build a dialogue from a key in the Secrets Store and wire it to
-- an NPC model. Answering is left to the game's own chat/ProximityPrompt code.
function NpcDialogue.attach(npc, opts)
	if not opts.apiKey then
		error("NpcDialogue.attach: apiKey is required (read it from the Secrets Store)")
	end
	local dialogue = NpcDialogue.new(opts)
	dialogue.npc = npc
	return dialogue
end

return NpcDialogue
