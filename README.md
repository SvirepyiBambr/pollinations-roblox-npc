# Pollinations NPC for Roblox

Give any Roblox NPC a persona and a short per-player memory — in a few lines of
Luau, powered by [Pollinations](https://pollinations.ai) text models.

Submission for **quest #15583** — *"Pollinations NPC dialogue for Roblox"*.

- **App (live demo):** https://svirepyibambr.github.io/pollinations-roblox-npc/
- **Run it in Roblox:** copy `src/` into `ServerScriptService` (or Rojo with
  `example/default.project.json`).

The Roblox app itself is a **library**: the runnable entry point is the hosted
demo page (which calls the same Pollinations text endpoint from the browser), and
the in-game usage is the two `src` ModuleScripts below.

## What it does

Two dependency-free ModuleScripts, meant to run **server-side** (so the API key
never reaches a client):

| File | Role |
| --- | --- |
| `src/Pollinations.luau` | Minimal client for `POST https://gen.pollinations.ai/v1/chat/completions`. Retries `429`/`5xx` with backoff, honours `Retry-After`, and returns a **stable error kind** instead of throwing. |
| `src/PollinationsNPC.luau` | Persona + bounded per-player memory. `reply(player, message)` returns text or an error kind; `forget(player)` clears a player's history. |

Failures never crash the game: the caller gets `nil, kind` where `kind` is one of
`network | auth | quota | model | server | decode | http`, and the failed turn is
dropped so a retry starts clean.

## Install

**Rojo (recommended):** the `example/default.project.json` maps `src/` into
`ServerScriptService.PollinationsNPC`.

```
rojo serve example/default.project.json
```

**Manual:** create a `Folder` named `PollinationsNPC` in `ServerScriptService`
and drop both `.luau` files inside it (rename them from `.luau` to the
corresponding module names if your workflow needs it).

## Store the key safely

Put your key in Roblox's [Secrets Store](https://create.roblox.com/docs/cloud-services/secrets)
and read it on the server, so it is never shipped to clients:

```lua
local key = game:GetService("SecretStore"):GetSecret("POLLINATIONS_API_KEY")
```

## Use it

```lua
local ServerScriptService = game:GetService("ServerScriptService")
local Players = game:GetService("Players")
local NpcDialogue = require(ServerScriptService.PollinationsNPC)

local apiKey = game:GetService("SecretStore"):GetSecret("POLLINATIONS_API_KEY")

local tomo = NpcDialogue.attach(workspace.Tomo, {
    apiKey = apiKey,
    name = "Tomo",
    persona = "You keep the old lighthouse on Pollen Island and love bad sea puns.",
})

-- Answer a player (wire this to your own chat / ProximityPrompt UI):
local text, err = tomo:reply(player, "Who are you?")
if text then
    print(tomo.npc.Name .. ":", text)
else
    warn("NPC is quiet right now:", err) -- "quota", "network", ...
end

-- Free memory when a player leaves:
Players.PlayerRemoving:Connect(function(p) tomo:forget(p) end)
```

`model` is optional — it accepts **any id from the live text model list**
(`https://gen.pollinations.ai/text/models`); the default is `openai`.

## How players pay (BYOP)

Billing follows the account behind the key. For a published game, don't bundle a
shared key — let every player bring their own Pollen key via the
[device-flow handshake](https://github.com/pollinations/pollinations/blob/main/BRING_YOUR_OWN_POLLEN.md#%EF%B8%8F-clis--headless-apps-device-flow),
and pass the resulting `sk_` key into `NpcDialogue.attach`. For development, any
key from https://enter.pollinations.ai/keys works.

## Verify it yourself

`example/SelfTest.server.luau` runs in Studio and prints PASS/FAIL for: a real
round trip, a bad-key call returning `auth`, and memory trimming. Add it under
`ServerScriptService` and start a server.

## Notes / limits

- `HttpService` must be enabled; requests are server-only by design.
- History is bounded (`maxHistory`, default 6) so long sessions don't grow the prompt.
- The module never sends a system prompt that claims to be an AI or an API.

## License

MIT — see `LICENSE`.
