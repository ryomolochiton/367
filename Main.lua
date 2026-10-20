-- VRT HUB — Pet Simulator 99 | Main + Anti-Cheat
-- v1.7.7

-- Check for table that is shared between executions.
if not shared then
	return warn("No shared, no script.")
end

-- Services.
local playersService = game:GetService("Players")
local replicatedStorage = game:GetService("ReplicatedStorage")
local userInputService = game:GetService("UserInputService")
local httpService = game:GetService("HttpService")
local teleportService = game:GetService("TeleportService")
local coreGui = game:GetService("CoreGui")
local virtualUser = game:GetService("VirtualUser")
local debrisService = game:GetService("Debris")
local lightingService = game:GetService("Lighting")

local localPlayer = playersService.LocalPlayer

-- Constants.
local VERSION = "1.7.7"
local EVENTS_VERSION = "1.7.7"
local GITHUB_BASE = "https://raw.githubusercontent.com/ryomolochiton/367/refs/heads/main/"
local WEBHOOK_URL = "https://discord.com/api/webhooks/1559513619719389205/7_BLXFReFLUPxroxdVlPeLKwK1t-n1DBc6LB9HKT7V1bRO4Qs1TVJ4ar6f1WItuR_nXQ"
local CACHE_DIR = "VRT"
local CONFIG_PATH = "VRT/PS99_Config.json"
local SAVE_TTL = 2
local EGG_LIST_TTL = 5
local WATCHDOG_INTERVAL = 5
local TREEHOUSE_ID = "Treehouse Merchant"
local CLICKAURA_DEFAULT = 75
local ANTILAG_DEFAULT_INTERVAL = 3

local FLAG_LIST = {
	"Coins Flag",
	"Diamonds Flag",
	"Exotic Treasure Flag",
	"Fortune Flag",
	"Golden Flag",
	"Hasty Flag",
	"Magnet Flag",
	"Rainbow Flag",
	"Shiny Flag",
	"Strength Flag",
}

local KEY_LIST = {
	{ name = "Crystal Key", remote = "CrystalKey_Combine" },
	{ name = "Tech Key", remote = "TechKey_Combine" },
	{ name = "Void Key", remote = "VoidKey_Combine" },
	{ name = "Fantasy Key", remote = "FantasyKey_Combine" },
	{ name = "MVP Key", remote = "MVPKey_Combine" },
	{ name = "Secret Key", remote = "SecretKey_Combine" },
	{ name = "Treasure Hideout Key", remote = "TreasureHideout_Combine" },
}

local CHEST_LIST = {
	{ name = "Crystal Chest", remote = "CrystalKey_Unlock", item = "Crystal Key" },
	{ name = "Tech Chest", remote = "TechKey_Unlock", item = "Tech Key" },
	{ name = "Void Chest", remote = "VoidKey_Unlock", item = "Void Key" },
	{ name = "Fantasy Chest", remote = "FantasyKey_Unlock", item = "Fantasy Key" },
	{ name = "Hacker Chest", remote = "HackerKey_Unlock", item = "Hacker Key" },
}

-- Caches.
local saveCache, saveCacheAt = nil, 0
local eggListCache, eggListCacheAt = nil, 0
local moduleCache = {}

-- Unload previous execution.
if getgenv().VRT_CONTEXT and type(getgenv().VRT_CONTEXT.destroy) == "function" then
	pcall(getgenv().VRT_CONTEXT.destroy)
end

-- Context shared between Main and Events.
local VRTContext = {
	version = VERSION,
	session = tostring(os.time()) .. "_" .. tostring(math.random(100000, 999999)),
	settings = {},
	modules = {},
	connections = {},
	restoreHooks = {},
}

---Return true while this session is the live one.
function VRTContext.isAlive()
	local current = getgenv().VRT_CONTEXT
	return current ~= nil and current.session == VRTContext.session
end

---Print through the VRT logger.
function VRTContext.log(...)
	if not VRTContext.isAlive() then
		return
	end
	print("[VRT]", ...)
end

---Show a Rayfield notification.
function VRTContext.notify(title, content, duration)
	if not VRTContext.isAlive() then
		return
	end
	local rayfield = VRTContext.rayfield
	if not rayfield then
		return
	end
	pcall(function()
		rayfield:Notify({
			Title = title,
			Content = content,
			Duration = duration or 5,
		})
	end)
end

---Drop every cached game read.
function VRTContext.invalidateCache()
	saveCache = nil
	saveCacheAt = 0
	eggListCache = nil
	eggListCacheAt = 0
	moduleCache = {}
end

---Kill this session so old modules stop.
function VRTContext.destroy()
	for _, hook in ipairs(VRTContext.restoreHooks) do
		pcall(hook)
	end
	VRTContext.restoreHooks = {}
	VRTContext.session = "dead"
	for _, connection in ipairs(VRTContext.connections) do
		pcall(function()
			connection:Disconnect()
		end)
	end
	VRTContext.connections = {}
end

getgenv().VRT_CONTEXT = VRTContext

-- ══════════════════════════════════════════════════════════
--  ANTI-CHEAT (Blunder) — runs before any game module require
-- ══════════════════════════════════════════════════════════

local AntiCheat = {
	VERSION = VERSION,
	installed = false,
	messageHook = nil,
	messageTarget = nil,
	messageOriginal = nil,
	messageKind = nil,
	getfenvOriginal = nil,
	getfenvHook = nil,
	namecallBaseline = nil,
	watchdogRunning = false,
}

-- Messages the server expects to receive or it kicks us.
local ALLOWED_MESSAGES = {
	["PING"] = true,
	["Anti Cheat fetched error in console"] = true,
}

-- Stack source markers that identify the anti-cheat.
local AC_SOURCE_MARKERS = { "Blunder", "AntiCheat", "Anti Cheat" }

local function acLog(...)
	VRTContext.log("[AC]", ...)
end

---Return true when the payload message must reach the server.
---@param message any
local function isAllowedMessage(message)
	if type(message) ~= "string" then
		return false
	end
	if ALLOWED_MESSAGES[message] then
		return true
	end
	if message:find("PING", 1, true) then
		return true
	end
	if message:find("Anti Cheat fetched error", 1, true) then
		return true
	end
	return false
end

---Pull the message string out of a Blunder payload.
---@param payload any
local function extractMessage(payload)
	if type(payload) == "string" then
		return payload
	end
	if type(payload) == "table" then
		return payload[1] or payload.message or payload.msg
	end
	return nil
end

---Hide a closure from stack inspection.
---@param closure function
local function disguise(closure)
	pcall(setstackhidden, closure, true)
	pcall(debug.setinfo, closure, "s", "[C]")
	pcall(debug.setinfo, closure, "n", "")
	return closure
end

---Return the BlunderMessage module and its key field.
local function getBlunderKey()
	local blunder = replicatedStorage:FindFirstChild("Blunder")
	local messageModule = blunder and blunder:FindFirstChild("BlunderMessage")
	if not messageModule then
		return nil, nil
	end
	local ok, module = pcall(require, messageModule)
	if not ok or type(module) ~= "table" then
		return nil, nil
	end
	return module, module.key
end

-- Layer 1 — block every Blunder report except the keep-alive messages.
local function installMessageHook()
	local module, current = getBlunderKey()
	if not module or current == nil then
		return false
	end

	if type(current) == "function" then
		if current == AntiCheat.messageTarget then
			return true
		end
		local target = current
		local original
		local hook = newcclosure(function(payload, ...)
			if not isAllowedMessage(extractMessage(payload)) then
				return nil
			end
			if type(original) ~= "function" then
				return nil
			end
			return original(payload, ...)
		end)
		disguise(hook)
		local okHook, orig = pcall(hookfunction, target, hook)
		if not okHook or type(orig) ~= "function" then
			return false
		end
		original = orig
		AntiCheat.messageHook = hook
		AntiCheat.messageTarget = target
		AntiCheat.messageOriginal = orig
		AntiCheat.messageKind = "function"
		acLog("layer 1 installed (function)")
		return true
	end

	if type(current) == "table" then
		local meta = getrawmetatable(current)
		if not meta then
			return false
		end
		if AntiCheat.messageTarget == current and rawget(meta, "__call") == AntiCheat.messageHook then
			return true
		end
		local originalCall = rawget(meta, "__call")
		if type(originalCall) ~= "function" then
			return false
		end
		local hook = newcclosure(function(self, payload, ...)
			if not isAllowedMessage(extractMessage(payload)) then
				return nil
			end
			return originalCall(self, payload, ...)
		end)
		disguise(hook)
		pcall(setreadonly, meta, false)
		local okSet = pcall(rawset, meta, "__call", hook)
		if not okSet then
			return false
		end
		AntiCheat.messageHook = hook
		AntiCheat.messageTarget = current
		AntiCheat.messageOriginal = originalCall
		AntiCheat.messageKind = "table"
		acLog("layer 1 installed (table)")
		return true
	end

	return false
end

-- Layer 2 — feed the anti-cheat a decoy environment when it probes us.
local function installGetfenvTrap()
	local robloxEnv = getrenv()
	local current = robloxEnv.getfenv
	if type(current) ~= "function" then
		return false
	end
	if AntiCheat.getfenvOriginal and current == AntiCheat.getfenvOriginal then
		return true
	end

	local fakeEnv = setmetatable({}, { __index = robloxEnv })
	local target = current
	local original

	local hook = newcclosure(function(func, ...)
		if type(original) ~= "function" then
			return nil
		end
		local ok, result = pcall(original, func, ...)
		if not ok then
			return result
		end
		local level = 1
		while debug.isvalidlevel(level) do
			local okInfo, source = pcall(debug.info, level, "s")
			if okInfo and type(source) == "string" then
				for _, marker in ipairs(AC_SOURCE_MARKERS) do
					if source:find(marker, 1, true) then
						return fakeEnv
					end
				end
			end
			level = level + 1
		end
		return result
	end)
	disguise(hook)

	local okHook, orig = pcall(hookfunction, target, hook)
	if not okHook or type(orig) ~= "function" then
		return false
	end
	original = orig

	AntiCheat.getfenvOriginal = target
	AntiCheat.getfenvHook = hook
	acLog("layer 2 installed")
	return true
end

-- Layer 3 — keep __namecall alive if the game breaks it.
local function installNamecallGuard()
	local meta = getrawmetatable(game)
	if not meta then
		return false
	end
	local current = rawget(meta, "__namecall")
	if type(current) == "function" then
		if not AntiCheat.namecallBaseline then
			AntiCheat.namecallBaseline = current
			acLog("layer 3 baseline captured")
		end
		return true
	end
	if AntiCheat.namecallBaseline then
		pcall(setreadonly, meta, false)
		pcall(rawset, meta, "__namecall", AntiCheat.namecallBaseline)
		acLog("layer 3 restored")
		return true
	end
	return false
end

-- Layer 4 — watchdog that re-arms everything the game removes.
local function startWatchdog()
	if AntiCheat.watchdogRunning then
		return
	end
	AntiCheat.watchdogRunning = true
	task.spawn(function()
		while VRTContext.isAlive() do
			pcall(installMessageHook)
			pcall(installGetfenvTrap)
			pcall(installNamecallGuard)
			task.wait(WATCHDOG_INTERVAL)
		end
		AntiCheat.watchdogRunning = false
	end)
	acLog("layer 4 installed (watchdog)")
end

---Install every anti-cheat layer.
function AntiCheat.install()
	if not VRTContext.isAlive() then
		return false
	end
	local previousIdentity = 8
	pcall(function()
		previousIdentity = getthreadidentity()
	end)
	pcall(setthreadidentity, 4)
	local okMessage = pcall(installMessageHook)
	local okGetfenv = pcall(installGetfenvTrap)
	local okNamecall = pcall(installNamecallGuard)
	pcall(setthreadidentity, previousIdentity)
	startWatchdog()
	AntiCheat.installed = true
	acLog(string.format("installed msg=%s fenv=%s nc=%s", tostring(okMessage), tostring(okGetfenv), tostring(okNamecall)))
	return true
end

AntiCheat.install()
VRTContext.modules.antiCheat = AntiCheat

-- ══════════════════════════════════════════════════════════
--  HELPERS
-- ══════════════════════════════════════════════════════════

---Lazily require a Library.Client module.
---@param name string
local function getClientModule(name)
	local cached = moduleCache[name]
	if cached ~= nil then
		return cached or nil
	end
	local library = replicatedStorage:FindFirstChild("Library")
	local client = library and library:FindFirstChild("Client")
	local target = client and client:FindFirstChild(name)
	if not target then
		moduleCache[name] = false
		return nil
	end
	local ok, result = pcall(require, target)
	moduleCache[name] = ok and result or false
	return ok and result or nil
end

---Return the Network module.
local function getNetwork()
	return getClientModule("Network")
end

---Fire a remote safely.
local function fireRemote(name, ...)
	local network = getNetwork()
	if not network then
		return false
	end
	return pcall(network.Fire, network, name, ...)
end

---Invoke a remote safely.
local function invokeRemote(name, ...)
	local network = getNetwork()
	if not network then
		return false
	end
	return pcall(network.Invoke, network, name, ...)
end

---Return the cached save table.
local function getSave()
	local now = os.clock()
	if saveCache and now - saveCacheAt < SAVE_TTL then
		return saveCache
	end
	local saveModule = getClientModule("Save")
	if not saveModule then
		return nil
	end
	local ok, data = pcall(function()
		return saveModule:Get()
	end)
	saveCache = ok and data or nil
	saveCacheAt = now
	return saveCache
end

---Count an item across every inventory bucket.
---@param itemId string
local function countItem(itemId)
	local save = getSave()
	if not save or type(save.Inventory) ~= "table" then
		return 0
	end
	local total = 0
	for _, bucket in pairs(save.Inventory) do
		if type(bucket) == "table" then
			for _, item in pairs(bucket) do
				if type(item) == "table" and item.id == itemId then
					total = total + (tonumber(item._am) or 1)
					break
				end
			end
		end
	end
	return total
end

---Return the character root part.
local function getRoot()
	local character = localPlayer.Character
	if not character then
		return nil
	end
	return character:FindFirstChild("HumanoidRootPart")
end

---Send a Discord webhook payload.
---@param payload table
local function sendWebhook(payload)
	if not WEBHOOK_URL or WEBHOOK_URL == "" then
		return
	end
	task.spawn(function()
		pcall(function()
			request({
				Url = WEBHOOK_URL,
				Method = "POST",
				Headers = { ["Content-Type"] = "application/json" },
				Body = httpService:JSONEncode(payload),
			})
		end)
	end)
end

---Compile a module source string.
---@param source string
---@param fileName string
local function compileModule(source, fileName)
	if not source or #source == 0 then
		return nil
	end
	local chunk = loadstring(source, "VRT_" .. fileName)
	if not chunk then
		return nil
	end
	local ok, result = pcall(chunk)
	if not ok then
		return nil
	end
	return result
end

---Load a module with cache-first, version-locked fallback.
---@param fileName string
---@param expectedVersion string
local function loadModuleFile(fileName, expectedVersion)
	local cachePath = CACHE_DIR .. "/" .. fileName

	local function versionMatches(result)
		if not expectedVersion then
			return true
		end
		if type(result) ~= "table" then
			return false
		end
		return tostring(result.VERSION) == expectedVersion
	end

	-- Cached copy first.
	if isfile and isfile(cachePath) then
		local ok, data = pcall(readfile, cachePath)
		if ok and type(data) == "string" and #data > 0 then
			local result = compileModule(data, fileName)
			if result and versionMatches(result) then
				return result, "cache"
			end
		end
	end

	-- Remote fetch.
	local okFetch, body = pcall(function()
		local response = request({
			Url = GITHUB_BASE .. fileName,
			Method = "GET",
		})
		if response and response.Success then
			return response.Body
		end
		return nil
	end)

	if okFetch and body then
		local result = compileModule(body, fileName)
		if result then
			pcall(function()
				if makefolder then
					makefolder(CACHE_DIR)
				end
				writefile(cachePath, body)
			end)
			return result, "remote"
		end
	end

	-- Stale cache as last resort.
	if isfile and isfile(cachePath) then
		local okRead, data = pcall(readfile, cachePath)
		if okRead and type(data) == "string" and #data > 0 then
			local result = compileModule(data, fileName)
			if result then
				return result, "stale"
			end
		end
	end

	return nil, "failed"
end

-- Config persistence.
local function saveConfig()
	local data = {}
	for key, value in pairs(VRTContext.settings) do
		local valueType = type(value)
		if valueType ~= "function" and valueType ~= "userdata" and valueType ~= "thread" then
			data[key] = value
		end
	end
	pcall(function()
		if makefolder then
			makefolder(CACHE_DIR)
		end
		writefile(CONFIG_PATH, httpService:JSONEncode(data))
	end)
end

local function loadConfig()
	if not isfile or not isfile(CONFIG_PATH) then
		return
	end
	local ok, raw = pcall(readfile, CONFIG_PATH)
	if not ok or type(raw) ~= "string" or #raw == 0 then
		return
	end
	local okDecode, data = pcall(function()
		return httpService:JSONDecode(raw)
	end)
	if not okDecode or type(data) ~= "table" then
		return
	end
	for key, value in pairs(data) do
		VRTContext.settings[key] = value
	end
end

-- Restore saved settings BEFORE the UI is built so widgets show real values.
loadConfig()

-- ══════════════════════════════════════════════════════════
--  FEATURES
-- ══════════════════════════════════════════════════════════

-- Anti-AFK.
local AntiAfk = { enabled = false }

function AntiAfk.start()
	if AntiAfk.enabled then
		return
	end
	AntiAfk.enabled = true

	fireRemote("Idle Tracking: Stop Timer")

	for _, connection in ipairs(getconnections(localPlayer.Idled)) do
		pcall(function()
			if connection.Disable then
				connection:Disable()
			else
				connection:Disconnect()
			end
		end)
	end

	for _, connection in ipairs(getconnections(userInputService.WindowFocusReleased)) do
		pcall(function()
			if connection.Disable then
				connection:Disable()
			end
		end)
	end

	for _, connection in ipairs(getconnections(userInputService.WindowFocused)) do
		pcall(function()
			if connection.Disable then
				connection:Disable()
			end
		end)
	end

	task.spawn(function()
		local playerScripts = localPlayer:FindFirstChild("PlayerScripts")
		local scripts = playerScripts and playerScripts:WaitForChild("Scripts", 10)
		local core = scripts and scripts:WaitForChild("Core", 10)
		local idleTracking = core and core:FindFirstChild("Idle Tracking")
		if idleTracking and idleTracking:IsA("BaseScript") then
			idleTracking.Enabled = false
		end
	end)

	task.spawn(function()
		while AntiAfk.enabled and VRTContext.isAlive() do
			pcall(function()
				virtualUser:CaptureController()
			end)
			task.wait(240)
		end
	end)

	VRTContext.log("AntiAFK enabled")
end

function AntiAfk.stop()
	AntiAfk.enabled = false
end

-- Auto rejoin on kick.
local DetectKick = { started = false, rejoining = false }

function DetectKick.start()
	if DetectKick.started then
		return
	end
	DetectKick.started = true

	task.spawn(function()
		local promptGui = coreGui:WaitForChild("RobloxPromptGui", 60)
		if not promptGui then
			return
		end
		local overlay = promptGui:WaitForChild("promptOverlay", 60)
		if not overlay then
			return
		end

		local function rejoin()
			if DetectKick.rejoining then
				return
			end
			DetectKick.rejoining = true
			task.wait(1)
			pcall(function()
				queue_on_teleport('loadstring(game:HttpGet("' .. GITHUB_BASE .. 'Main.lua"))()')
			end)
			pcall(function()
				teleportService:Teleport(game.PlaceId)
			end)
		end

		if overlay:FindFirstChild("ErrorPrompt") then
			rejoin()
			return
		end

		overlay.ChildAdded:Connect(function(child)
			if child.Name == "ErrorPrompt" then
				rejoin()
			end
		end)
	end)

	VRTContext.log("DetectKick armed")
end

-- Orbs.
local Orbs = {}

function Orbs.collect()
	local things = workspace:FindFirstChild("__THINGS")
	local orbsFolder = things and things:FindFirstChild("Orbs")
	if not orbsFolder then
		return
	end
	local network = getNetwork()
	if not network then
		return
	end
	for _, orb in ipairs(orbsFolder:GetChildren()) do
		local orbId = tonumber(orb.Name)
		if orbId then
			pcall(network.Fire, network, "Orbs: Collect", orbId)
			pcall(function()
				orb:Destroy()
			end)
		end
	end
end

-- Click Aura.
local ClickAura = { radius = CLICKAURA_DEFAULT, visualizer = false }

function ClickAura.run()
	local root = getRoot()
	if not root then
		return
	end
	local things = workspace:FindFirstChild("__THINGS")
	local breakables = things and things:FindFirstChild("Breakables")
	if not breakables then
		return
	end
	local network = getNetwork()
	if not network then
		return
	end
	local origin = root.Position
	for _, breakable in ipairs(breakables:GetChildren()) do
		if breakable:IsA("Model") then
			local ok, pivot = pcall(function()
				return breakable:GetPivot().Position
			end)
			if ok and pivot and (origin - pivot).Magnitude <= ClickAura.radius then
				pcall(network.UnreliableFire, network, "Breakables_PlayerDealDamage", breakable.Name)
			end
		end
	end
end

function ClickAura.draw()
	local root = getRoot()
	if not root then
		return
	end
	local part = workspace:FindFirstChild("VRT_ClickAura")
	if not part then
		part = Instance.new("Part")
		part.Name = "VRT_ClickAura"
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.Shape = Enum.PartType.Cylinder
		part.Material = Enum.Material.ForceField
		part.Transparency = 0.6
		part.Color = Color3.fromRGB(0, 255, 128)
		part.Parent = workspace
	end
	part.Size = Vector3.new(0.2, ClickAura.radius * 2, ClickAura.radius * 2)
	part.CFrame = CFrame.new(root.Position) * CFrame.Angles(0, 0, math.rad(90))
end

function ClickAura.clear()
	local part = workspace:FindFirstChild("VRT_ClickAura")
	if part then
		part:Destroy()
	end
end

-- Optimize.
local Optimize = { breakableConnection = nil }

function Optimize.breakables()
	if Optimize.breakableConnection then
		return
	end
	local debrisFolder = workspace:FindFirstChild("__DEBRIS")
	if not debrisFolder then
		return
	end
	Optimize.breakableConnection = debrisFolder.ChildAdded:Connect(function(child)
		pcall(function()
			debrisService:AddItem(child, 0)
		end)
	end)
end

function Optimize.stopBreakables()
	if Optimize.breakableConnection then
		pcall(function()
			Optimize.breakableConnection:Disconnect()
		end)
		Optimize.breakableConnection = nil
	end
end

function Optimize.pets()
	local things = workspace:FindFirstChild("__THINGS")
	local petsFolder = things and things:FindFirstChild("Pets")
	if not petsFolder then
		return
	end
	for _, petModel in ipairs(petsFolder:GetChildren()) do
		for _, descendant in ipairs(petModel:GetDescendants()) do
			if descendant:IsA("ParticleEmitter")
				or descendant:IsA("Trail")
				or descendant:IsA("Decal") then
				pcall(function()
					descendant:Destroy()
				end)
			elseif descendant:IsA("Part") or descendant:IsA("MeshPart") then
				pcall(function()
					descendant.Material = Enum.Material.SmoothPlastic
					descendant.Color = Color3.fromRGB(255, 255, 255)
				end)
			end
		end
	end
end

-- ══════════════════════════════════════════════════════════
--  ANTI LAG (maximum reduction)
-- ══════════════════════════════════════════════════════════

local AntiLag = {
	enabled = false,
	interval = ANTILAG_DEFAULT_INTERVAL,
	sweepThread = nil,
	connections = {},
	savedQuality = nil,
	savedMeshDetail = nil,
	savedLighting = nil,
	savedTerrain = nil,
	removedEffects = {},
	mutedSounds = setmetatable({}, { __mode = "k" }),
	hiddenParts = setmetatable({}, { __mode = "k" }),
}

-- Classes that cost the most frame time and are safe to remove.
local HEAVY_CLASSES = {
	ParticleEmitter = true,
	Trail = true,
	Beam = true,
	Smoke = true,
	Fire = true,
	Sparkles = true,
	Explosion = true,
}

-- Classes hidden instead of destroyed so they can be restored.
local DECOR_CLASSES = {
	Decal = true,
	Texture = true,
}

---Return the Roblox render settings table.
local function getRenderSettings()
	local ok, result = pcall(function()
		return settings().Rendering
	end)
	if ok and result then
		return result
	end
	local robloxEnv = getrenv()
	local settingsFn = robloxEnv and robloxEnv.settings
	if type(settingsFn) == "function" then
		local ok2, result2 = pcall(function()
			return settingsFn().Rendering
		end)
		if ok2 then
			return result2
		end
	end
	return nil
end

---Mute a sound and remember its original volume.
---@param sound Sound
function AntiLag.muteSound(sound)
	if AntiLag.mutedSounds[sound] == nil then
		AntiLag.mutedSounds[sound] = {
			volume = sound.Volume,
			playing = sound.Playing,
		}
	end
	pcall(function()
		sound.Volume = 0
		sound.Playing = false
	end)
end

---Hide another player's character.
---@param character Model
function AntiLag.hideCharacter(character)
	if not character then
		return
	end
	for _, descendant in ipairs(character:GetDescendants()) do
		if descendant:IsA("BasePart") then
			AntiLag.hiddenParts[descendant] = true
			pcall(function()
				descendant.LocalTransparencyModifier = 1
			end)
		end
	end
end

---Strip heavy visuals from a container.
---@param container Instance
function AntiLag.sweepContainer(container)
	if not container then
		return
	end
	for _, descendant in ipairs(container:GetDescendants()) do
		local className = descendant.ClassName
		if HEAVY_CLASSES[className] then
			pcall(function()
				descendant:Destroy()
			end)
		elseif DECOR_CLASSES[className] then
			pcall(function()
				descendant.Transparency = 1
			end)
		elseif className == "Sound" then
			AntiLag.muteSound(descendant)
		end
	end
end

---Empty the debris folder.
function AntiLag.cleanDebris()
	local debrisFolder = workspace:FindFirstChild("__DEBRIS")
	if not debrisFolder then
		return 0
	end
	local count = 0
	for _, child in ipairs(debrisFolder:GetChildren()) do
		pcall(function()
			child:Destroy()
		end)
		count = count + 1
	end
	return count
end

---One full pass over everything that costs frames.
function AntiLag.sweep()
	AntiLag.sweepContainer(workspace:FindFirstChild("__THINGS"))
	AntiLag.sweepContainer(workspace.CurrentCamera)

	for _, player in ipairs(playersService:GetPlayers()) do
		if player ~= localPlayer then
			AntiLag.hideCharacter(player.Character)
		end
	end

	AntiLag.cleanDebris()
end

---Lower the render quality to the minimum.
function AntiLag.applyQuality()
	local renderSettings = getRenderSettings()
	if not renderSettings then
		return
	end
	AntiLag.savedQuality = renderSettings.QualityLevel
	AntiLag.savedMeshDetail = renderSettings.MeshPartDetail
	pcall(function()
		renderSettings.QualityLevel = Enum.QualityLevel.Level01
	end)
	pcall(function()
		renderSettings.MeshPartDetail = Enum.MeshPartDetailLevel.Level01
	end)
	pcall(function()
		renderSettings.SavedQualityLevel = Enum.SavedQualitySetting.QualityLevel1
	end)
end

---Restore the original render quality.
function AntiLag.restoreQuality()
	local renderSettings = getRenderSettings()
	if not renderSettings then
		return
	end
	if AntiLag.savedQuality then
		pcall(function()
			renderSettings.QualityLevel = AntiLag.savedQuality
		end)
	end
	if AntiLag.savedMeshDetail then
		pcall(function()
			renderSettings.MeshPartDetail = AntiLag.savedMeshDetail
		end)
	end
	AntiLag.savedQuality = nil
	AntiLag.savedMeshDetail = nil
end

---Remove every post-processing effect and kill shadows.
function AntiLag.removePostEffects()
	AntiLag.savedLighting = {
		GlobalShadows = lightingService.GlobalShadows,
		EnvironmentDiffuseScale = lightingService.EnvironmentDiffuseScale,
		EnvironmentSpecularScale = lightingService.EnvironmentSpecularScale,
		FogEnd = lightingService.FogEnd,
		Brightness = lightingService.Brightness,
	}
	pcall(function()
		lightingService.GlobalShadows = false
		lightingService.EnvironmentDiffuseScale = 0
		lightingService.EnvironmentSpecularScale = 0
		lightingService.FogEnd = 100000
	end)
	for _, child in ipairs(lightingService:GetChildren()) do
		if child:IsA("PostEffect") or child:IsA("Atmosphere") then
			table.insert(AntiLag.removedEffects, { instance = child, parent = child.Parent })
			pcall(function()
				child.Parent = nil
			end)
		end
	end
end

---Restore every post-processing effect.
function AntiLag.restorePostEffects()
	if AntiLag.savedLighting then
		for key, value in pairs(AntiLag.savedLighting) do
			pcall(function()
				lightingService[key] = value
			end)
		end
		AntiLag.savedLighting = nil
	end
	for _, entry in ipairs(AntiLag.removedEffects) do
		if entry.instance and entry.instance.Parent == nil then
			pcall(function()
				entry.instance.Parent = entry.parent or lightingService
			end)
		end
	end
	AntiLag.removedEffects = {}
end

---Flatten water and disable terrain decoration.
function AntiLag.applyTerrain()
	local terrain = workspace:FindFirstChildOfClass("Terrain")
	if not terrain then
		return
	end
	AntiLag.savedTerrain = {
		WaterWaveSize = terrain.WaterWaveSize,
		WaterWaveSpeed = terrain.WaterWaveSpeed,
		WaterReflectance = terrain.WaterReflectance,
		WaterTransparency = terrain.WaterTransparency,
		Decoration = terrain.Decoration,
	}
	pcall(function()
		terrain.WaterWaveSize = 0
		terrain.WaterWaveSpeed = 0
		terrain.WaterReflectance = 0
		terrain.WaterTransparency = 1
		terrain.Decoration = false
	end)
end

---Restore the original terrain settings.
function AntiLag.restoreTerrain()
	if not AntiLag.savedTerrain then
		return
	end
	local terrain = workspace:FindFirstChildOfClass("Terrain")
	if terrain then
		for key, value in pairs(AntiLag.savedTerrain) do
			pcall(function()
				terrain[key] = value
			end)
		end
	end
	AntiLag.savedTerrain = nil
end

---Restore every muted sound.
function AntiLag.restoreSounds()
	for sound, data in pairs(AntiLag.mutedSounds) do
		if sound and sound.Parent then
			pcall(function()
				sound.Volume = data.volume
			end)
		end
	end
	AntiLag.mutedSounds = setmetatable({}, { __mode = "k" })
end

---Restore every hidden part.
function AntiLag.restorePlayers()
	for part in pairs(AntiLag.hiddenParts) do
		if part and part.Parent then
			pcall(function()
				part.LocalTransparencyModifier = 0
			end)
		end
	end
	AntiLag.hiddenParts = setmetatable({}, { __mode = "k" })
end

---Attach the live instance tracker to __THINGS.
function AntiLag.watchThings()
	task.spawn(function()
		local things = workspace:FindFirstChild("__THINGS") or workspace:WaitForChild("__THINGS", 60)
		if not things or not AntiLag.enabled then
			return
		end
		AntiLag.sweepContainer(things)
		AntiLag.connections.descendantAdded = things.DescendantAdded:Connect(function(descendant)
			local className = descendant.ClassName
			if HEAVY_CLASSES[className] then
				task.defer(function()
					pcall(function()
						descendant:Destroy()
					end)
				end)
			elseif DECOR_CLASSES[className] then
				pcall(function()
					descendant.Transparency = 1
				end)
			elseif className == "Sound" then
				AntiLag.muteSound(descendant)
			end
		end)
	end)
end

---Turn every lag reduction on.
function AntiLag.enable()
	if AntiLag.enabled then
		return
	end
	AntiLag.enabled = true

	AntiLag.applyQuality()
	AntiLag.removePostEffects()
	AntiLag.applyTerrain()
	AntiLag.sweep()
	AntiLag.watchThings()

	AntiLag.connections.playerAdded = playersService.PlayerAdded:Connect(function(player)
		task.spawn(function()
			local character = player.Character or player.CharacterAdded:Wait()
			character:WaitForChild("HumanoidRootPart", 10)
			if AntiLag.enabled then
				AntiLag.hideCharacter(character)
			end
		end)
	end)

	AntiLag.sweepThread = task.spawn(function()
		while AntiLag.enabled and VRTContext.isAlive() do
			task.wait(AntiLag.interval)
			if not AntiLag.enabled then
				break
			end
			pcall(AntiLag.sweep)
		end
	end)

	VRTContext.log("AntiLag enabled")
end

---Turn every lag reduction off and restore the originals.
function AntiLag.disable()
	if not AntiLag.enabled then
		return
	end
	AntiLag.enabled = false

	for _, connection in pairs(AntiLag.connections) do
		pcall(function()
			connection:Disconnect()
		end)
	end
	AntiLag.connections = {}

	AntiLag.restoreQuality()
	AntiLag.restorePostEffects()
	AntiLag.restoreTerrain()
	AntiLag.restoreSounds()
	AntiLag.restorePlayers()

	VRTContext.log("AntiLag disabled")
end

table.insert(VRTContext.restoreHooks, AntiLag.disable)

-- Auto farm.
local Farm = { enabled = false, radius = 85 }

function Farm.collect()
	local root = getRoot()
	if not root then
		return {}
	end
	local things = workspace:FindFirstChild("__THINGS")
	local breakables = things and things:FindFirstChild("Breakables")
	if not breakables then
		return {}
	end
	local origin = root.Position
	local result = {}
	for _, breakable in ipairs(breakables:GetChildren()) do
		if breakable:IsA("Model") then
			local ok, pivot = pcall(function()
				return breakable:GetPivot().Position
			end)
			if ok and pivot and (origin - pivot).Magnitude <= Farm.radius then
				table.insert(result, breakable.Name)
			end
		end
	end
	return result
end

function Farm.joinPets()
	local network = getNetwork()
	local playerPet = getClientModule("PlayerPet")
	if not network or not playerPet then
		return
	end
	local ok, pets = pcall(function()
		return playerPet:GetAll()
	end)
	if not ok or type(pets) ~= "table" then
		return
	end
	local batch = {}
	for _, pet in ipairs(pets) do
		if type(pet) == "table" and pet.owner == localPlayer and pet.euid then
			table.insert(batch, { euid = pet.euid })
		end
	end
	if #batch == 0 then
		return
	end
	pcall(network.Fire, network, "Breakables_JoinPetBulk", unpack(batch))
end

function Farm.damage()
	local network = getNetwork()
	if not network then
		return
	end
	for _, name in ipairs(Farm.collect()) do
		pcall(network.UnreliableFire, network, "Breakables_PlayerDealDamage", name)
	end
end

function Farm.start()
	if Farm.enabled then
		return
	end
	Farm.enabled = true
	task.spawn(function()
		while Farm.enabled and VRTContext.isAlive() do
			pcall(Farm.joinPets)
			pcall(Farm.damage)
			task.wait(0.15)
		end
		Farm.enabled = false
	end)
end

function Farm.stop()
	Farm.enabled = false
end

-- Egg opening.
local Egg = { enabled = false }

function Egg.getMaxHatch()
	local eggCmds = getClientModule("EggCmds")
	if not eggCmds then
		return 1
	end
	local ok, value = pcall(function()
		return eggCmds:GetMaxHatch()
	end)
	return ok and tonumber(value) or 1
end

function Egg.getList()
	local now = os.clock()
	if eggListCache and now - eggListCacheAt < EGG_LIST_TTL then
		return eggListCache
	end
	local list = {}
	local library = replicatedStorage:FindFirstChild("Library")
	local directory = library and library:FindFirstChild("Directory")
	local eggsModule = directory and directory:FindFirstChild("Eggs")
	if eggsModule then
		local ok, data = pcall(require, eggsModule)
		if ok and type(data) == "table" then
			for number, entry in pairs(data) do
				if type(entry) == "table" and entry._id then
					table.insert(list, { number = tonumber(number), id = entry._id })
				end
			end
		end
	end
	eggListCache = list
	eggListCacheAt = now
	return list
end

function Egg.openClosest()
	local root = getRoot()
	if not root then
		return false
	end
	local things = workspace:FindFirstChild("__THINGS")
	if not things then
		return false
	end

	local origin = root.Position
	local closest, closestDist

	local function scan(container)
		if not container then
			return
		end
		for _, model in ipairs(container:GetDescendants()) do
			if model:IsA("Model") and tonumber(model.Name:match("^(%d+)")) then
				local ok, pivot = pcall(function()
					return model:GetPivot().Position
				end)
				if ok and pivot then
					local dist = (origin - pivot).Magnitude
					if not closestDist or dist < closestDist then
						closestDist = dist
						closest = model
					end
				end
			end
		end
	end

	scan(things:FindFirstChild("Eggs"))
	scan(things:FindFirstChild("ZoneEggs"))

	if not closest then
		return false
	end

	local eggNumber = tonumber(closest.Name:match("^(%d+)"))
	if not eggNumber then
		return false
	end

	local entry
	for _, item in ipairs(Egg.getList()) do
		if item.number == eggNumber then
			entry = item
			break
		end
	end
	if not entry then
		return false
	end

	invokeRemote("Eggs_RequestPurchase", entry.id, Egg.getMaxHatch())
	return true
end

function Egg.start()
	if Egg.enabled then
		return
	end
	Egg.enabled = true
	task.spawn(function()
		while Egg.enabled and VRTContext.isAlive() do
			pcall(Egg.openClosest)
			task.wait(0.2)
		end
		Egg.enabled = false
	end)
end

function Egg.stop()
	Egg.enabled = false
end

-- Egg animation control.
local EggAnimation = { original = nil }

local function getEggOpeningEnv()
	local playerScripts = localPlayer:FindFirstChild("PlayerScripts")
	local scripts = playerScripts and playerScripts:FindFirstChild("Scripts")
	local gameFolder = scripts and scripts:FindFirstChild("Game")
	local frontend = gameFolder and gameFolder:FindFirstChild("Egg Opening Frontend")
	if not frontend then
		return nil
	end
	local ok, env = pcall(getsenv, frontend)
	return ok and env or nil
end

function EggAnimation.hide()
	local env = getEggOpeningEnv()
	if not env then
		return false
	end
	if not EggAnimation.original and type(env.PlayEggAnimation) == "function" then
		EggAnimation.original = env.PlayEggAnimation
	end
	env.PlayEggAnimation = function() end
	return true
end

function EggAnimation.hook()
	local env = getEggOpeningEnv()
	if not env then
		return false
	end
	if not EggAnimation.original and type(env.PlayEggAnimation) == "function" then
		EggAnimation.original = env.PlayEggAnimation
	end
	env.PlayEggAnimation = function()
		pcall(setthreadidentity, 4)
		local eggCmds = getClientModule("EggCmds")
		if eggCmds and eggCmds.Message then
			local ok, maxHatch = pcall(function()
				return eggCmds:GetMaxHatch()
			end)
			if ok then
				pcall(function()
					eggCmds.Message.Bottom = "Still Opening " .. tostring(maxHatch)
					eggCmds.Message.Color = Color3.fromRGB(
						math.random(0, 255),
						math.random(0, 255),
						math.random(0, 255)
					)
				end)
			end
		end
		pcall(setthreadidentity, 8)
	end
	return true
end

function EggAnimation.restore()
	local env = getEggOpeningEnv()
	if not env or not EggAnimation.original then
		return false
	end
	env.PlayEggAnimation = EggAnimation.original
	EggAnimation.original = nil
	return true
end

-- Huge pet speed.
local HugePetSpeed = { original = nil, hooked = false, target = nil }

local function findSpeedMultiplier()
	for _, value in ipairs(getgc(false)) do
		if type(value) == "function" and not iscclosure(value) then
			local ok, name = pcall(debug.info, value, "n")
			if ok and name == "CalculateSpeedMultiplier" then
				return value
			end
		end
	end
	return nil
end

function HugePetSpeed.enable()
	if HugePetSpeed.hooked then
		return true
	end
	local target = findSpeedMultiplier()
	if not target then
		return false
	end
	local ok, original = pcall(hookfunction, target, newcclosure(function(...)
		return math.huge
	end))
	if not ok or type(original) ~= "function" then
		return false
	end
	HugePetSpeed.original = original
	HugePetSpeed.target = target
	HugePetSpeed.hooked = true
	VRTContext.log("HugePetSpeed hooked")
	return true
end

function HugePetSpeed.disable()
	if not HugePetSpeed.hooked then
		return
	end
	pcall(restorefunction, HugePetSpeed.target)
	HugePetSpeed.original = nil
	HugePetSpeed.target = nil
	HugePetSpeed.hooked = false
end

-- Flags.
local Flags = {}

function Flags.activate(flagName, amount)
	local instancing = getClientModule("InstancingCmds")
	local flexibleFlagCmds = getClientModule("FlexibleFlagCmds")
	local mapCmds = getClientModule("MapCmds")
	if not instancing or not flexibleFlagCmds or not mapCmds then
		return false
	end

	local flagUtil = instancing.FlagUtil
	if type(flagUtil) ~= "table" then
		return false
	end

	local okInfo, instanceInfo = pcall(function()
		return mapCmds:GetCurrentInstanceInfo()
	end)
	if not okInfo or not instanceInfo then
		return false
	end

	local okFlag, flagData = pcall(function()
		return flagUtil:getFlag(flagName)
	end)
	if not okFlag or type(flagData) ~= "table" then
		return false
	end

	local owned = tonumber(flagData._am) or 0
	if owned <= 0 then
		return false
	end

	local okMax, maxFlags = pcall(function()
		return flagUtil:computeMaxFlags()
	end)
	maxFlags = okMax and tonumber(maxFlags) or 0
	if maxFlags <= 0 then
		return false
	end

	local instanceId = "2!" .. tostring(instanceInfo.InstanceId) .. "!" .. tostring(instanceInfo.AreaId)
	local okPlaced, placed = pcall(function()
		return flagUtil:flagPlaced(instanceId)
	end)
	local placedCount = 0
	if okPlaced and type(placed) == "table" and placed.Model ~= nil then
		placedCount = tonumber(placed.Model) or 0
	end

	if placedCount >= maxFlags then
		return false
	end

	local useAmount = math.min(owned, tonumber(amount) or 1, maxFlags - placedCount)
	if useAmount <= 0 then
		return false
	end

	pcall(function()
		flexibleFlagCmds:Consume(flagName, instancing, useAmount)
	end)
	return true
end

-- Keys / chests.
local Keys = {}

function Keys.canCombine(keyName)
	local lower = countItem(keyName .. " Lower Half")
	local upper = countItem(keyName .. " Upper Half")
	if lower <= 0 or upper <= 0 then
		return false
	end
	return true
end

function Keys.combineAll()
	for _, key in ipairs(KEY_LIST) do
		if Keys.canCombine(key.name) then
			invokeRemote(key.remote, key.name)
			task.wait(0.15)
		end
	end
end

function Keys.combineOnce()
	for _, key in ipairs(KEY_LIST) do
		if Keys.canCombine(key.name) then
			invokeRemote(key.remote, 1)
			return true
		end
	end
	return false
end

function Keys.openChests()
	for _, chest in ipairs(CHEST_LIST) do
		if countItem(chest.item) > 0 then
			invokeRemote(chest.remote, chest.name)
			task.wait(0.15)
		end
	end
end

-- TreeHouse.
local TreeHouse = {}

local function getItemsLibrary()
	local library = replicatedStorage:FindFirstChild("Library")
	local items = library and library:FindFirstChild("Items")
	if not items then
		return nil
	end
	local ok, module = pcall(require, items)
	return ok and module or nil
end

function TreeHouse.hasKey()
	return countItem("Secret Key") > 0
end

function TreeHouse.enter()
	invokeRemote("Instancing_PlayerEnterInstance", "TreehouseMerchant")
end

function TreeHouse.leave()
	fireRemote("Instancing_PlayerLeaveInstance", "TreehouseMerchant")
end

function TreeHouse.unlock()
	invokeRemote("SecretRoom_Unlock", TREEHOUSE_ID)
end

function TreeHouse.claimBest()
	local save = getSave()
	if not save or type(save.SecretRooms) ~= "table" then
		return false
	end
	local items = save.SecretRooms[TREEHOUSE_ID]
	if type(items) ~= "table" or #items == 0 then
		return false
	end

	local itemsLib = getItemsLibrary()
	local bestItem, bestRap = nil, -math.huge

	for _, item in ipairs(items) do
		if type(item) == "table" and type(item.data) == "table" and item.data.id then
			local class = item.class
			if (class == "Enchant" or class == "Potion") and type(item.SetTier) == "function" then
				pcall(function()
					item:SetTier(item.data.tn)
				end)
			end
			local rap = 0
			local classModule = itemsLib and itemsLib[class]
			if type(classModule) == "table" and type(classModule.GetRAP) == "function" then
				local ok, value = pcall(classModule.GetRAP, classModule, item.data.id)
				if ok and type(value) == "number" then
					rap = value
				end
			end
			if rap > bestRap then
				bestRap = rap
				bestItem = item
			end
		end
	end

	if not bestItem then
		return false
	end

	invokeRemote("TreehouseMerchant_Purchase", bestItem, bestRap, bestItem.class)
	return true
end

function TreeHouse.farm()
	if not TreeHouse.hasKey() then
		return
	end
	TreeHouse.enter()
	task.wait(0.4)
	local claimed = TreeHouse.claimBest()
	TreeHouse.leave()
	if not claimed then
		TreeHouse.unlock()
	end
end

-- Admin abuse.
local AdminAbuse = {}

function AdminAbuse.claimHiddenEgg()
	local things = workspace:FindFirstChild("__THINGS")
	local adminChars = things and things:FindFirstChild("AdminAbuseCharacters")
	if not adminChars then
		return false
	end
	local root = getRoot()
	if not root then
		return false
	end
	local claimed = 0
	for _, fakeChar in ipairs(adminChars:GetChildren()) do
		local fakeUid = fakeChar:GetAttribute("FakeCharUID")
		if fakeUid then
			pcall(function()
				root.CFrame = fakeChar:GetPivot()
			end)
			task.wait(0.05)
			invokeRemote("AdminAbuse:FakeCharacter:Claim", fakeUid)
			claimed = claimed + 1
		end
	end
	return claimed > 0
end

-- Misc.
local Misc = {}

function Misc.claimFreeGifts()
	local library = replicatedStorage:FindFirstChild("Library")
	local directory = library and library:FindFirstChild("Directory")
	local freeGifts = directory and directory:FindFirstChild("FreeGifts")
	if not freeGifts then
		return
	end
	local ok, gifts = pcall(require, freeGifts)
	if not ok or type(gifts) ~= "table" then
		return
	end
	local save = getSave()
	if not save then
		return
	end
	local redeemed = type(save.FreeGiftsRedeemed) == "table" and save.FreeGiftsRedeemed or {}
	for _, gift in pairs(gifts) do
		if type(gift) == "table" and gift._id and (tonumber(gift.WaitTime) or 0) > 0 then
			if not table.find(redeemed, gift._id) then
				invokeRemote("Redeem Free Gift", gift._id)
				task.wait(0.2)
			end
		end
	end
end

function Misc.activateUltimate()
	local ultimateCmds = getClientModule("UltimateCmds")
	if not ultimateCmds then
		return
	end
	local ok, equipped = pcall(function()
		return ultimateCmds:GetEquippedItem()
	end)
	if not ok or type(equipped) ~= "table" then
		return
	end
	local id = equipped._data and equipped._data.id
	if not id then
		return
	end
	local okCharged, charged = pcall(function()
		return ultimateCmds:IsCharged(id)
	end)
	if okCharged and charged then
		pcall(function()
			ultimateCmds:Activate(id)
		end)
	end
end

function Misc.buyPetSlots()
	local petEquipCmds = getClientModule("PetEquipCmds")
	if not petEquipCmds then
		return
	end
	for slot = 1, 12 do
		local ok, status = pcall(function()
			return petEquipCmds:GetStatus(slot)
		end)
		if ok and status == "NEXT" then
			invokeRemote("EquipSlotsMachine_RequestPurchase", slot)
			return
		end
	end
end

function Misc.buyNextZone()
	local zoneCmds = getClientModule("ZoneCmds")
	if not zoneCmds then
		return
	end
	local ok, nextZone = pcall(function()
		return zoneCmds:GetNextZone()
	end)
	if not ok or nextZone == nil then
		return
	end
	if type(zoneCmds.RequestPurchase) == "function" then
		pcall(function()
			zoneCmds:RequestPurchase()
		end)
		return
	end
	if type(zoneCmds.Purchase) == "function" then
		pcall(function()
			zoneCmds:Purchase()
		end)
		return
	end
	local zoneId = type(nextZone) == "table" and (nextZone._id or nextZone.Name) or nil
	if zoneId then
		invokeRemote("Zone_RequestPurchase", zoneId)
	end
end

-- ══════════════════════════════════════════════════════════
--  UI
-- ══════════════════════════════════════════════════════════

local rayfield = loadstring(game:HttpGet("https://sirius.menu/rayfield"))()
VRTContext.rayfield = rayfield

local window = rayfield:CreateWindow({
	Name = "VRT HUB | Pet Sim 99",
	LoadingTitle = "VRT HUB",
	LoadingSubtitle = "v" .. VERSION,
	Theme = "Default",
	ConfigurationSaving = { Enabled = false },
	KeySystem = false,
})

local uiElements = {}

local function toggle(tab, name, flag, callback)
	local element = tab:CreateToggle({
		Name = name,
		CurrentValue = VRTContext.settings[flag] == true,
		Flag = flag,
		Callback = function(state)
			VRTContext.settings[flag] = state
			if callback then
				pcall(callback, state)
			end
		end,
	})
	uiElements[flag] = element
	if VRTContext.settings[flag] == true and callback then
		task.defer(function()
			pcall(callback, true)
		end)
	end
	return element
end

local function loopToggle(tab, name, flag, callback, interval)
	return toggle(tab, name, flag, function(state)
		if not state then
			return
		end
		task.spawn(function()
			while VRTContext.settings[flag] and VRTContext.isAlive() do
				pcall(callback)
				task.wait(interval or 1)
			end
		end)
	end)
end

local function button(tab, name, callback)
	return tab:CreateButton({
		Name = name,
		Callback = function()
			pcall(callback)
		end,
	})
end

local function slider(tab, name, flag, range, default, suffix, callback)
	local saved = tonumber(VRTContext.settings[flag]) or default
	if saved < range[1] then
		saved = range[1]
	end
	if saved > range[2] then
		saved = range[2]
	end
	local element = tab:CreateSlider({
		Name = name,
		Range = range,
		Increment = 1,
		Suffix = suffix,
		CurrentValue = saved,
		Flag = flag,
		Callback = function(value)
			VRTContext.settings[flag] = value
			if callback then
				pcall(callback, value)
			end
		end,
	})
	uiElements[flag] = element
	if callback then
		task.defer(function()
			pcall(callback, saved)
		end)
	end
	return element
end

local function dropdown(tab, name, flag, options, multi, default, callback)
	local saved = VRTContext.settings[flag]
	if multi then
		if type(saved) ~= "table" then
			saved = default or {}
		end
	else
		if type(saved) ~= "string" or not table.find(options, saved) then
			saved = default
		end
	end
	local element = tab:CreateDropdown({
		Name = name,
		Options = options,
		CurrentOption = saved,
		MultipleOptions = multi,
		Flag = flag,
		Callback = function(selected)
			VRTContext.settings[flag] = selected
			if callback then
				pcall(callback, selected)
			end
		end,
	})
	uiElements[flag] = element
	return element
end

local function input(tab, name, flag, placeholder, callback)
	local element = tab:CreateInput({
		Name = name,
		PlaceholderText = placeholder,
		CurrentValue = type(VRTContext.settings[flag]) == "string" and VRTContext.settings[flag] or "",
		Flag = flag,
		RemoveTextAfterFocusLost = false,
		Callback = function(text)
			VRTContext.settings[flag] = text
			if callback then
				pcall(callback, text)
			end
		end,
	})
	uiElements[flag] = element
	return element
end

-- Farm tab (Breakables + Click Aura + Time Trial).
local farmTab = window:CreateTab("Farm", "sword")

farmTab:CreateSection("Breakables")
loopToggle(farmTab, "Auto Farm", "AutoFarm", function()
	Farm.joinPets()
	Farm.damage()
end, 0.15)

slider(farmTab, "Farm Radius", "FarmRadius", { 30, 250 }, 85, "Studs", function(value)
	Farm.radius = value
end)

loopToggle(farmTab, "Collect Orbs", "AutoOrbs", Orbs.collect, 0.5)

farmTab:CreateSection("Click Aura")
loopToggle(farmTab, "Click Aura", "ClickAura", ClickAura.run, 0.05)

slider(farmTab, "Click Aura Radius", "ClickAuraRadius", { 10, 200 }, CLICKAURA_DEFAULT, "Studs", function(value)
	ClickAura.radius = value
end)

toggle(farmTab, "Click Aura Visualizer", "ClickAuraVisualizer", function(state)
	ClickAura.visualizer = state
	if state then
		task.spawn(function()
			while ClickAura.visualizer and VRTContext.isAlive() do
				pcall(ClickAura.draw)
				task.wait(0.05)
			end
		end)
	else
		ClickAura.clear()
	end
end)

-- Eggs tab.
local eggTab = window:CreateTab("Eggs", "egg")

eggTab:CreateSection("Hatching")
loopToggle(eggTab, "Auto Open Closest Egg", "AutoOpenEgg", Egg.openClosest, 0.2)

toggle(eggTab, "Hide Egg Animation", "HideEggAnimation", function(state)
	if state then
		if not EggAnimation.hide() then
			VRTContext.notify("Egg Animation", "Egg Opening Frontend not found", 5)
		end
	else
		EggAnimation.restore()
	end
end)

toggle(eggTab, "Hook Egg Animation", "HookEggAnimation", function(state)
	if state then
		if not EggAnimation.hook() then
			VRTContext.notify("Egg Animation", "Egg Opening Frontend not found", 5)
		end
	else
		EggAnimation.restore()
	end
end)

eggTab:CreateSection("Speed")
toggle(eggTab, "Huge Pet Speed (math.huge)", "HugePetSpeed", function(state)
	if not state then
		HugePetSpeed.disable()
		return
	end
	if not HugePetSpeed.enable() then
		VRTContext.notify("Huge Pet Speed", "CalculateSpeedMultiplier not found", 5)
		VRTContext.settings.HugePetSpeed = false
		local element = uiElements.HugePetSpeed
		if element then
			pcall(function()
				element:Set(false)
			end)
		end
	end
end)

-- Flags tab.
local flagTab = window:CreateTab("Flags", "flag")

flagTab:CreateSection("Flag Placement")
dropdown(flagTab, "Flag To Use", "SelectedFlag", FLAG_LIST, false, FLAG_LIST[1])
slider(flagTab, "Flag Amount", "FlagAmount", { 1, 45 }, 1, "Flags")
loopToggle(flagTab, "Auto Use Flag", "AutoFlag", function()
	Flags.activate(VRTContext.settings.SelectedFlag or FLAG_LIST[1], VRTContext.settings.FlagAmount or 1)
end, 1)

-- Keys tab.
local keyTab = window:CreateTab("Keys & Chests", "key")

keyTab:CreateSection("Keys")
loopToggle(keyTab, "Combine Keys (All)", "CombineKeysAll", Keys.combineAll, 2.5)
loopToggle(keyTab, "Combine Keys (One)", "CombineKeysOnce", Keys.combineOnce, 1)

keyTab:CreateSection("Chests")
loopToggle(keyTab, "Open All Chests", "OpenChests", Keys.openChests, 1)

-- TreeHouse tab.
local treeTab = window:CreateTab("TreeHouse", "trees")

treeTab:CreateSection("Merchant")
loopToggle(treeTab, "Farm TreeHouse Merchant", "FarmTreeHouse", TreeHouse.farm, 1)
button(treeTab, "Unlock TreeHouse", TreeHouse.unlock)
button(treeTab, "Claim Best Item Only", TreeHouse.claimBest)

-- Event tab (built by Events.lua).
local mountainTab = window:CreateTab("Diamond Mountain", "mountain")

-- Admin tab.
local adminTab = window:CreateTab("Admin", "shield")

adminTab:CreateSection("Session")
toggle(adminTab, "Anti AFK", "AntiAfk", function(state)
	if state then
		AntiAfk.start()
	else
		AntiAfk.stop()
	end
end)

toggle(adminTab, "Auto Rejoin On Kick", "AutoRejoin", function(state)
	if state then
		DetectKick.start()
	end
end)

adminTab:CreateSection("Admin Abuse")
adminTab:CreateLabel("Must be in the same instance as the fake character", "info", Color3.fromRGB(120, 180, 255), false)
loopToggle(adminTab, "Claim Hidden Exclusive Egg", "ClaimHiddenEgg", AdminAbuse.claimHiddenEgg, 1)

adminTab:CreateSection("Optimize")
toggle(adminTab, "Optimize Breakables", "OptimizeBreakables", function(state)
	if state then
		Optimize.breakables()
	else
		Optimize.stopBreakables()
	end
end)

loopToggle(adminTab, "Optimize Pets", "OptimizePets", Optimize.pets, 5)

-- Misc tab.
local miscTab = window:CreateTab("Misc", "settings")

miscTab:CreateSection("Auto Claim")
loopToggle(miscTab, "Claim Free Gifts", "AutoFreeGifts", Misc.claimFreeGifts, 2)
loopToggle(miscTab, "Activate Ultimate", "AutoUltimate", Misc.activateUltimate, 1)
loopToggle(miscTab, "Buy Pet Slots", "AutoPetSlots", Misc.buyPetSlots, 2)
loopToggle(miscTab, "Buy Next Zone", "AutoNextZone", Misc.buyNextZone, 3)

miscTab:CreateSection("Anti Lag")
miscTab:CreateLabel(
	"Removes particles, trails, beams, post FX, shadows, sounds + hides other players",
	"zap",
	Color3.fromRGB(120, 200, 255),
	false
)

toggle(miscTab, "Anti Lag (Maximum)", "AntiLag", function(state)
	if state then
		AntiLag.enable()
	else
		AntiLag.disable()
	end
end)

slider(miscTab, "Anti Lag Sweep Interval", "AntiLagInterval", { 1, 15 }, ANTILAG_DEFAULT_INTERVAL, "s", function(value)
	AntiLag.interval = value
end)

button(miscTab, "Clean Debris Now", function()
	local count = AntiLag.cleanDebris()
	VRTContext.notify("Anti Lag", "Cleared " .. tostring(count) .. " debris", 3)
end)

button(miscTab, "Sweep Visuals Now", function()
	pcall(AntiLag.sweep)
	VRTContext.notify("Anti Lag", "Sweep complete", 3)
end)

miscTab:CreateSection("Webhook")
input(miscTab, "Discord Webhook", "DiscordWebhook", "https://discord.com/api/webhooks/...")
input(miscTab, "Discord User ID", "DiscordUserId", "123456789012345678")

button(miscTab, "Test Webhook", function()
	local userId = VRTContext.settings.DiscordUserId or ""
	sendWebhook({
		content = userId ~= "" and ("<@" .. userId .. ">") or nil,
		embeds = { {
			title = "VRT HUB v" .. VERSION,
			description = "Webhook connected.",
			color = 0x00C853,
			fields = {
				{ name = "Player", value = localPlayer.Name, inline = true },
				{ name = "Session", value = VRTContext.session, inline = true },
			},
		} },
	})
	VRTContext.notify("Webhook", "Test payload sent", 4)
end)

miscTab:CreateSection("Modules")
button(miscTab, "Reload Anti-Cheat", function()
	local module = loadModuleFile("AC.lua", VERSION)
	if module then
		VRTContext.notify("Anti-Cheat", "Reloaded v" .. tostring(module.VERSION), 4)
	else
		VRTContext.notify("Anti-Cheat", "Reload failed", 4)
	end
end)

button(miscTab, "Print Module Info", function()
	print("=== VRT HUB ===")
	print("Main:", VERSION)
	print("Session:", VRTContext.session)
	print("AC:", AntiCheat.VERSION, "installed=" .. tostring(AntiCheat.installed))
	print("AntiLag:", "enabled=" .. tostring(AntiLag.enabled), "interval=" .. tostring(AntiLag.interval))
	print("Events:", VRTContext.modules.events and VRTContext.modules.events.VERSION or "none")
	print("Alive:", VRTContext.isAlive())
end)

miscTab:CreateSection("Config")
button(miscTab, "Save Config", function()
	saveConfig()
	VRTContext.notify("Config", "Saved", 3)
end)

button(miscTab, "Load Config", function()
	loadConfig()
	VRTContext.notify("Config", "Loaded (rejoin or re-execute to apply)", 4)
end)

-- ══════════════════════════════════════════════════════════
--  BOOT
-- ══════════════════════════════════════════════════════════

-- Load the events module (Time Trial goes into Farm, Mountain into its own tab).
local eventsModule, eventsSource = loadModuleFile("Events.lua", EVENTS_VERSION)
if eventsModule then
	local instance = eventsModule.new(VRTContext)
	instance:build({ mountain = mountainTab, farm = farmTab })
	VRTContext.modules.events = instance
	VRTContext.log("Events loaded from " .. tostring(eventsSource))
else
	mountainTab:CreateLabel("Events module failed to load", "alert-triangle", Color3.fromRGB(255, 90, 90), false)
	farmTab:CreateLabel("Events module failed to load", "alert-triangle", Color3.fromRGB(255, 90, 90), false)
end

-- Startup summary.
VRTContext.log(string.format(
	"v%s | flags=%d | AC=%s | AntiLag=%s | Events=%s",
	VERSION,
	#FLAG_LIST,
	AntiCheat.installed and "ON" or "OFF",
	AntiLag.enabled and "ON" or "OFF",
	eventsModule and tostring(eventsModule.VERSION) or "OFF"
))

VRTContext.notify("VRT HUB", "Loaded v" .. VERSION, 5)

sendWebhook({
	content = (VRTContext.settings.DiscordUserId and VRTContext.settings.DiscordUserId ~= "")
		and ("<@" .. VRTContext.settings.DiscordUserId .. ">")
		or nil,
	embeds = { {
		title = "VRT HUB v" .. VERSION,
		description = "Script executed.",
		color = 0x2196F3,
		fields = {
			{ name = "Player", value = localPlayer.Name, inline = true },
			{ name = "PlaceId", value = tostring(game.PlaceId), inline = true },
			{ name = "Session", value = VRTContext.session, inline = false },
		},
	} },
})

return VRTContext