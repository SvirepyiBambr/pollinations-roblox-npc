--!nonstrict
-- Pollinations.luau
-- A tiny, dependency-free client for Pollinations text models, meant to run
-- inside Roblox **server** scripts (HttpService is server-only).
--
-- Why: Roblox developers should be able to talk to any model from the live
-- Pollinations text list with a few lines, without the game ever crashing when
-- the API is slow or rate-limited. Failures come back as stable error kinds.
--
-- Endpoint: POST https://gen.pollinations.ai/v1/chat/completions
-- Auth:     "Authorization: Bearer <key>" (key from Roblox's Secrets Store)

local HttpService = game:GetService("HttpService")

local ENDPOINT = "https://gen.pollinations.ai/v1/chat/completions"

-- HTTP statuses worth retrying with backoff.
local RETRYABLE = { [408] = true, [429] = true, [500] = true, [502] = true, [503] = true, [504] = true }

-- Stable error kinds returned to callers.
export type ErrorKind = "network" | "auth" | "quota" | "model" | "server" | "decode" | "http"

local Pollinations = {}
Pollinations.__index = Pollinations

export type Config = {
	apiKey: string,
	model: string?,
	temperature: number?,
	maxRetries: number?,
	baseBackoff: number?,
}

export type Message = { role: "system" | "user" | "assistant", content: string }

-- Creates a client. `apiKey` is required; everything else has a sane default.
function Pollinations.new(config: Config)
	assert(typeof(config) == "table", "Pollinations.new: config table is required")
	assert(typeof(config.apiKey) == "string" and #config.apiKey > 0, "Pollinations.new: apiKey is required")

	local self = setmetatable({}, Pollinations)
	self.apiKey = config.apiKey
	self.model = config.model or "openai"
	self.temperature = config.temperature or 0.8
	self.maxRetries = config.maxRetries == nil and 2 or config.maxRetries
	self.baseBackoff = config.baseBackoff or 1
	return self
end

local function kindForStatus(status: number): ErrorKind
	if status == 401 or status == 403 then
		return "auth"
	elseif status == 402 then
		return "quota"
	elseif status == 400 or status == 404 then
		return "model"
	elseif status >= 500 then
		return "server"
	end
	return "http"
end

-- Low-level call. Returns (text, nil) or (nil, kind, status?).
function Pollinations:chat(messages: { Message })
	local body = HttpService:JSONEncode({
		model = self.model,
		messages = messages,
		temperature = self.temperature,
		-- Ask Pollinations not to keep the conversation server-side.
		private = true,
	})

	local attempt = 0
	while true do
		local ok, response = pcall(function()
			return HttpService:RequestAsync({
				Url = ENDPOINT,
				Method = "POST",
				Headers = {
					["Content-Type"] = "application/json",
					["Authorization"] = "Bearer " .. self.apiKey,
				},
				Body = body,
			})
		end)

		if not ok then
			-- Transport-level failure (no HTTP response).
			if attempt < self.maxRetries then
				attempt += 1
				task.wait(self.baseBackoff * 2 ^ (attempt - 1))
				continue
			end
			return nil, "network", nil
		end

		if response.Success then
			local decoded, data = pcall(HttpService.JSONDecode, HttpService, response.Body)
			if not decoded or typeof(data) ~= "table" then
				return nil, "decode", response.StatusCode
			end
			local choices = data.choices
			local content = choices and choices[1] and choices[1].message and choices[1].message.content
			if typeof(content) == "string" and #content > 0 then
				return content, nil
			end
			return nil, "decode", response.StatusCode
		end

		local status = tonumber(response.StatusCode) or 0
		if RETRYABLE[status] and attempt < self.maxRetries then
			attempt += 1
			local retryAfter = tonumber(response.Headers and response.Headers["retry-after"] or "") or 0
			task.wait(math.max(retryAfter, self.baseBackoff * 2 ^ (attempt - 1)))
			continue
		end

		return nil, kindForStatus(status), status
	end
end

return Pollinations
