-- VRT HUB - Pet Simulator 99 | Single file
-- v1.9.3 - fixed dmInvoke vararg + buildPetStacks

if not shared then
	return warn("No shared, no script.")
end

local playersService = game:GetService("Players")
local replicatedStorage = game:GetService("ReplicatedStorage")
local userInputService = game:GetService("UserInputService")
local httpService = game:GetService("HttpService")
local teleportService = game:GetService("TeleportService")
local coreGui = game:GetService("CoreGui")
local virtualUser = game:GetService("VirtualUser")
local virtualInputManager = game:GetService("VirtualInputManager")
local debrisService = game:GetService("Debris")
local lightingService = game:GetService("Lighting")

local localPlayer = playersService.LocalPlayer

local VERSION = "1.9.3"
local WEBHOOK_URL = "https://discord.com/api/webhooks/1559513619719389205/7_BLXFReFLUPxroxdVlPeLKwK1t-n1DBc6LB9HKT7V1bRO4Qs1TVJ4ar6f1WItuR_nXQ"
local CACHE_DIR = "VRT"
local CONFIG_PATH = "VRT/PS99_Config.json"
local SAVE_TTL = 2
local WATCHDOG_INTERVAL = 5
local TREEHOUSE_ID = "Treehouse Merchant"
local CLICKAURA_DEFAULT = 75
local ANTILAG_DEFAULT_INTERVAL = 3
local TT_INSTANCE_ID = "TimeTrial"
local TT_STOP_RADIUS = 15
local TT_FARM_INTERVAL = 0.2
local TT_JUMP_COOLDOWN = 0.3
local TT_ENTER_COOLDOWN = 5
local DM_INSTANCE_ID = "DiamondMountain"
local DM_FARM_RADIUS = 250

local FLAG_LIST = {
	"Coins Flag", "Diamonds Flag", "Exotic Treasure Flag", "Fortune Flag",
	"Golden Flag", "Hasty Flag", "Magnet Flag", "Rainbow Flag", "Shiny Flag", "Strength Flag",
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

local saveCache, saveCacheAt = nil, 0
local moduleCache = {}

if getgenv().VRT_CONTEXT and type(getgenv().VRT_CONTEXT.destroy) == "function" then
	pcall(getgenv().VRT_CONTEXT.destroy)
end

local VRTContext = {
	version = VERSION,
	session = tostring(os.time()) .. "_" .. tostring(math.random(100000, 999999)),
	settings = {},
	modules = {},
	connections = {},
	restoreHooks = {},
}

function VRTContext.isAlive()
	local current = getgenv().VRT_CONTEXT
	return current ~= nil and current.session == VRTContext.session
end

function VRTContext.log(...)
	if not VRTContext.isAlive() then return end
	print("[VRT]", ...)
end

function VRTContext.notify(title, content, duration)
	if not VRTContext.isAlive() then return end
	local rayfield = VRTContext.rayfield
	if not rayfield then return end
	pcall(function()
		rayfield:Notify({ Title = title, Content = content, Duration = duration or 5 })
	end)
end

function VRTContext.invalidateCache()
	saveCache = nil
	saveCacheAt = 0
	moduleCache = {}
end

function VRTContext.destroy()
	for _, hook in ipairs(VRTContext.restoreHooks) do
		pcall(hook)
	end
	VRTContext.restoreHooks = {}
	VRTContext.session = "dead"
	for _, connection in ipairs(VRTContext.connections) do
		pcall(function() connection:Disconnect() end)
	end
	VRTContext.connections = {}
end

getgenv().VRT_CONTEXT = VRTContext

-- ══════════════════════════════════════════════════════════
--  ANTI-CHEAT
-- ══════════════════════════════════════════════════════════

local AntiCheat = {
	VERSION = VERSION, installed = false,
	messageHook = nil, messageTarget = nil, messageOriginal = nil,
	getfenvOriginal = nil, getfenvHook = nil,
	namecallBaseline = nil, watchdogRunning = false,
}

local ALLOWED_MESSAGES = {
	["PING"] = true,
	["Anti Cheat fetched error in console"] = true,
}
local AC_SOURCE_MARKERS = { "Blunder", "AntiCheat", "Anti Cheat" }

local function acLog(...) VRTContext.log("[AC]", ...) end

local function isAllowedMessage(message)
	if type(message) ~= "string" then return false end
	if ALLOWED_MESSAGES[message] then return true end
	if message:find("PING", 1, true) then return true end
	if message:find("Anti Cheat fetched error", 1, true) then return true end
	return false
end

local function extractMessage(payload)
	if type(payload) == "string" then return payload end
	if type(payload) == "table" then return payload[1] or payload.message or payload.msg end
	return nil
end

local function disguise(closure)
	pcall(setstackhidden, closure, true)
	pcall(debug.setinfo, closure, "s", "[C]")
	pcall(debug.setinfo, closure, "n", "")
	return closure
end

local function getBlunderKey()
	local blunder = replicatedStorage:FindFirstChild("Blunder")
	local messageModule = blunder and blunder:FindFirstChild("BlunderMessage")
	if not messageModule then return nil, nil end
	local ok, module = pcall(require, messageModule)
	if not ok or type(module) ~= "table" then return nil, nil end
	return module, module.key
end

local function installMessageHook()
	local module, current = getBlunderKey()
	if not module or current == nil then return false end
	if type(current) == "function" then
		if current == AntiCheat.messageTarget then return true end
		local target = current
		local original
		local hook = newcclosure(function(payload, ...)
			if not isAllowedMessage(extractMessage(payload)) then return nil end
			if type(original) ~= "function" then return nil end
			return original(payload, ...)
		end)
		disguise(hook)
		local okHook, orig = pcall(hookfunction, target, hook)
		if not okHook or type(orig) ~= "function" then return false end
		original = orig
		AntiCheat.messageHook = hook
		AntiCheat.messageTarget = target
		AntiCheat.messageOriginal = orig
		acLog("layer 1 installed (function)")
		return true
	end
	if type(current) == "table" then
		local meta = getrawmetatable(current)
		if not meta then return false end
		if AntiCheat.messageTarget == current and rawget(meta, "__call") == AntiCheat.messageHook then return true end
		local originalCall = rawget(meta, "__call")
		if type(originalCall) ~= "function" then return false end
		local hook = newcclosure(function(self, payload, ...)
			if not isAllowedMessage(extractMessage(payload)) then return nil end
			return originalCall(self, payload, ...)
		end)
		disguise(hook)
		pcall(setreadonly, meta, false)
		if not pcall(rawset, meta, "__call", hook) then return false end
		AntiCheat.messageHook = hook
		AntiCheat.messageTarget = current
		AntiCheat.messageOriginal = originalCall
		acLog("layer 1 installed (table)")
		return true
	end
	return false
end

local function installGetfenvTrap()
	local robloxEnv = getrenv()
	local current = robloxEnv.getfenv
	if type(current) ~= "function" then return false end
	if AntiCheat.getfenvOriginal and current == AntiCheat.getfenvOriginal then return true end
	local fakeEnv = setmetatable({}, { __index = robloxEnv })
	local target = current
	local original
	local hook = newcclosure(function(func, ...)
		if type(original) ~= "function" then return nil end
		local ok, result = pcall(original, func, ...)
		if not ok then return result end
		local level = 1
		while debug.isvalidlevel(level) do
			local okInfo, source = pcall(debug.info, level, "s")
			if okInfo and type(source) == "string" then
				for _, marker in ipairs(AC_SOURCE_MARKERS) do
					if source:find(marker, 1, true) then return fakeEnv end
				end
			end
			level = level + 1
		end
		return result
	end)
	disguise(hook)
	local okHook, orig = pcall(hookfunction, target, hook)
	if not okHook or type(orig) ~= "function" then return false end
	original = orig
	AntiCheat.getfenvOriginal = target
	AntiCheat.getfenvHook = hook
	acLog("layer 2 installed")
	return true
end

local function installNamecallGuard()
	local meta = getrawmetatable(game)
	if not meta then return false end
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

local function startWatchdog()
	if AntiCheat.watchdogRunning then return end
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

function AntiCheat.install()
	if not VRTContext.isAlive() then return false end
	local prev = 8
	pcall(function() prev = getthreadidentity() end)
	pcall(setthreadidentity, 4)
	local okMsg = pcall(installMessageHook)
	local okFenv = pcall(installGetfenvTrap)
	local okNc = pcall(installNamecallGuard)
	pcall(setthreadidentity, prev)
	startWatchdog()
	AntiCheat.installed = true
	acLog(string.format("installed msg=%s fenv=%s nc=%s", tostring(okMsg), tostring(okFenv), tostring(okNc)))
	return true
end

AntiCheat.install()
VRTContext.modules.antiCheat = AntiCheat

-- ══════════════════════════════════════════════════════════
--  HELPERS
-- ══════════════════════════════════════════════════════════

local function getClientModule(name)
	local cached = moduleCache[name]
	if cached ~= nil then return cached or nil end
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

local function getNetwork() return getClientModule("Network") end

local function fireRemote(name, ...)
	local network = getNetwork()
	if not network then return false end
	return pcall(network.Fire, network, name, ...)
end

local function invokeRemote(name, ...)
	local network = getNetwork()
	if not network then return false end
	return pcall(network.Invoke, network, name, ...)
end

local function getSave()
	local now = os.clock()
	if saveCache and now - saveCacheAt < SAVE_TTL then return saveCache end
	local saveModule = getClientModule("Save")
	if not saveModule then return nil end
	local ok, data = pcall(function() return saveModule:Get() end)
	saveCache = ok and data or nil
	saveCacheAt = now
	return saveCache
end

local function countItem(itemId)
	local save = getSave()
	if not save or type(save.Inventory) ~= "table" then return 0 end
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

local function getRoot()
	local character = localPlayer.Character
	if not character then return nil end
	return character:FindFirstChild("HumanoidRootPart")
end

local function sendWebhook(payload)
	if not WEBHOOK_URL or WEBHOOK_URL == "" then return end
	task.spawn(function()
		pcall(function()
			request({
				Url = WEBHOOK_URL, Method = "POST",
				Headers = { ["Content-Type"] = "application/json" },
				Body = httpService:JSONEncode(payload),
			})
		end)
	end)
end

local function saveConfig()
	local data = {}
	for key, value in pairs(VRTContext.settings) do
		local vt = type(value)
		if vt ~= "function" and vt ~= "userdata" and vt ~= "thread" then
			data[key] = value
		end
	end
	pcall(function()
		if makefolder then makefolder(CACHE_DIR) end
		writefile(CONFIG_PATH, httpService:JSONEncode(data))
	end)
end

local function loadConfig()
	if not isfile or not isfile(CONFIG_PATH) then return end
	local ok, raw = pcall(readfile, CONFIG_PATH)
	if not ok or type(raw) ~= "string" or #raw == 0 then return end
	local okDecode, data = pcall(function() return httpService:JSONDecode(raw) end)
	if not okDecode or type(data) ~= "table" then return end
	for key, value in pairs(data) do
		VRTContext.settings[key] = value
	end
end

loadConfig()

-- ══════════════════════════════════════════════════════════
--  INSTANCING
-- ══════════════════════════════════════════════════════════

local Instancing = {}

function Instancing.getCmds() return getClientModule("InstancingCmds") end

function Instancing.isIn(instanceId)
	local cmds = Instancing.getCmds()
	if not cmds then return false end
	local ok, result = pcall(function() return cmds:IsInInstance(instanceId) end)
	return ok and result == true
end

function Instancing.current()
	local cmds = Instancing.getCmds()
	if not cmds then return nil end
	local ok, result = pcall(function() return cmds:Get() end)
	if ok and type(result) == "table" then
		return result.InstanceID or result._id or result.id
	end
	return nil
end

function Instancing.enter(instanceId)
	local cmds = Instancing.getCmds()
	if not cmds then return false end
	return pcall(function() cmds:Enter(instanceId) end)
end

function Instancing.leave()
	local cmds = Instancing.getCmds()
	if not cmds then return false end
	return pcall(function() cmds:Leave() end)
end

-- ══════════════════════════════════════════════════════════
--  FEATURES
-- ══════════════════════════════════════════════════════════

local AntiAfk = { enabled = false }

function AntiAfk.start()
	if AntiAfk.enabled then return true end
	AntiAfk.enabled = true
	fireRemote("Idle Tracking: Stop Timer")
	for _, connection in ipairs(getconnections(localPlayer.Idled)) do
		pcall(function()
			if connection.Disable then connection:Disable() else connection:Disconnect() end
		end)
	end
	for _, connection in ipairs(getconnections(userInputService.WindowFocusReleased)) do
		pcall(function() if connection.Disable then connection:Disable() end end)
	end
	for _, connection in ipairs(getconnections(userInputService.WindowFocused)) do
		pcall(function() if connection.Disable then connection:Disable() end end)
	end
	task.spawn(function()
		local ps = localPlayer:FindFirstChild("PlayerScripts")
		local scripts = ps and ps:WaitForChild("Scripts", 10)
		local core = scripts and scripts:WaitForChild("Core", 10)
		local idle = core and core:FindFirstChild("Idle Tracking")
		if idle and idle:IsA("BaseScript") then
			pcall(function() idle.Enabled = false end)
		end
	end)
	task.spawn(function()
		while AntiAfk.enabled and VRTContext.isAlive() do
			pcall(function() virtualUser:CaptureController() end)
			task.wait(240)
		end
	end)
	VRTContext.log("AntiAFK enabled")
	return true
end

function AntiAfk.stop() AntiAfk.enabled = false end

local Orbs = {}

function Orbs.collect()
	local things = workspace:FindFirstChild("__THINGS")
	local orbsFolder = things and things:FindFirstChild("Orbs")
	if not orbsFolder then return false end
	local network = getNetwork()
	if not network then return false end
	local ids = {}
	for _, orb in ipairs(orbsFolder:GetChildren()) do
		local orbId = tonumber(orb.Name)
		if orbId then
			table.insert(ids, orbId)
			pcall(function() orb:Destroy() end)
		end
	end
	if #ids == 0 then return false end
	pcall(network.Fire, network, "Orbs: Collect", ids)
	return true
end

local ClickAura = { radius = CLICKAURA_DEFAULT, visualizer = false }

function ClickAura.run()
	local root = getRoot()
	if not root then return false end
	local things = workspace:FindFirstChild("__THINGS")
	local breakables = things and things:FindFirstChild("Breakables")
	if not breakables then return false end
	local network = getNetwork()
	if not network then return false end
	local origin = root.Position
	local hit = 0
	for _, breakable in ipairs(breakables:GetChildren()) do
		if breakable:IsA("Model") then
			local ok, pivot = pcall(function() return breakable:GetPivot().Position end)
			if ok and pivot and (origin - pivot).Magnitude <= ClickAura.radius then
				pcall(network.UnreliableFire, network, "Breakables_PlayerDealDamage", breakable.Name)
				hit = hit + 1
			end
		end
	end
	return hit > 0
end

function ClickAura.draw()
	local root = getRoot()
	if not root then return end
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
	if part then part:Destroy() end
end

local Optimize = { breakableConnection = nil }

function Optimize.breakables()
	if Optimize.breakableConnection then return true end
	local debrisFolder = workspace:FindFirstChild("__DEBRIS")
	if not debrisFolder then return false end
	Optimize.breakableConnection = debrisFolder.ChildAdded:Connect(function(child)
		pcall(function() debrisService:AddItem(child, 0) end)
	end)
	return true
end

function Optimize.stopBreakables()
	if Optimize.breakableConnection then
		pcall(function() Optimize.breakableConnection:Disconnect() end)
		Optimize.breakableConnection = nil
	end
end

function Optimize.pets()
	local things = workspace:FindFirstChild("__THINGS")
	local petsFolder = things and things:FindFirstChild("Pets")
	if not petsFolder then return false end
	for _, petModel in ipairs(petsFolder:GetChildren()) do
		for _, descendant in ipairs(petModel:GetDescendants()) do
			if descendant:IsA("ParticleEmitter") or descendant:IsA("Trail") or descendant:IsA("Decal") then
				pcall(function() descendant:Destroy() end)
			elseif descendant:IsA("Part") or descendant:IsA("MeshPart") then
				pcall(function()
					descendant.Material = Enum.Material.SmoothPlastic
					descendant.Color = Color3.fromRGB(255, 255, 255)
				end)
			end
		end
	end
	return true
end

-- ══════════════════════════════════════════════════════════
--  ANTI LAG
-- ══════════════════════════════════════════════════════════

local AntiLag = {
	enabled = false, interval = ANTILAG_DEFAULT_INTERVAL, sweepThread = nil,
	connections = {}, savedQuality = nil, savedMeshDetail = nil,
	savedLighting = nil, savedTerrain = nil, removedEffects = {},
	mutedSounds = setmetatable({}, { __mode = "k" }),
	hiddenParts = setmetatable({}, { __mode = "k" }),
}

local HEAVY_CLASSES = { ParticleEmitter = true, Trail = true, Beam = true, Smoke = true, Fire = true, Sparkles = true, Explosion = true }
local DECOR_CLASSES = { Decal = true, Texture = true }

local function getRenderSettings()
	local robloxEnv = getrenv()
	local settingsFn = robloxEnv and robloxEnv.settings
	if type(settingsFn) == "function" then
		local ok, result = pcall(function() return settingsFn().Rendering end)
		if ok and result then return result end
	end
	local ok2, result2 = pcall(function() return settings().Rendering end)
	if ok2 then return result2 end
	return nil
end

function AntiLag.muteSound(sound)
	if AntiLag.mutedSounds[sound] == nil then
		AntiLag.mutedSounds[sound] = { volume = sound.Volume, playing = sound.Playing }
	end
	pcall(function()
		sound.Volume = 0
		sound.Playing = false
	end)
end

function AntiLag.hideCharacter(character)
	if not character then return end
	for _, descendant in ipairs(character:GetDescendants()) do
		if descendant:IsA("BasePart") then
			AntiLag.hiddenParts[descendant] = true
			pcall(function() descendant.LocalTransparencyModifier = 1 end)
		end
	end
end

function AntiLag.sweepContainer(container)
	if not container then return end
	for _, descendant in ipairs(container:GetDescendants()) do
		local className = descendant.ClassName
		if HEAVY_CLASSES[className] then
			pcall(function() descendant:Destroy() end)
		elseif DECOR_CLASSES[className] then
			pcall(function() descendant.Transparency = 1 end)
		elseif className == "Sound" then
			AntiLag.muteSound(descendant)
		end
	end
end

function AntiLag.cleanDebris()
	local debrisFolder = workspace:FindFirstChild("__DEBRIS")
	if not debrisFolder then return 0 end
	local count = 0
	for _, child in ipairs(debrisFolder:GetChildren()) do
		pcall(function() child:Destroy() end)
		count = count + 1
	end
	return count
end

function AntiLag.sweep()
	AntiLag.sweepContainer(workspace:FindFirstChild("__THINGS"))
	AntiLag.sweepContainer(workspace.CurrentCamera)
	for _, player in ipairs(playersService:GetPlayers()) do
		if player ~= localPlayer then AntiLag.hideCharacter(player.Character) end
	end
	AntiLag.cleanDebris()
	return true
end

function AntiLag.applyQuality()
	local rs = getRenderSettings()
	if not rs then return false end
	AntiLag.savedQuality = rs.QualityLevel
	AntiLag.savedMeshDetail = rs.MeshPartDetail
	pcall(function() rs.QualityLevel = Enum.QualityLevel.Level01 end)
	pcall(function() rs.MeshPartDetail = Enum.MeshPartDetailLevel.Level01 end)
	return true
end

function AntiLag.restoreQuality()
	local rs = getRenderSettings()
	if not rs then return end
	if AntiLag.savedQuality then pcall(function() rs.QualityLevel = AntiLag.savedQuality end) end
	if AntiLag.savedMeshDetail then pcall(function() rs.MeshPartDetail = AntiLag.savedMeshDetail end) end
	AntiLag.savedQuality = nil
	AntiLag.savedMeshDetail = nil
end

function AntiLag.removePostEffects()
	AntiLag.savedLighting = {
		GlobalShadows = lightingService.GlobalShadows,
		EnvironmentDiffuseScale = lightingService.EnvironmentDiffuseScale,
		EnvironmentSpecularScale = lightingService.EnvironmentSpecularScale,
		FogEnd = lightingService.FogEnd,
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
			pcall(function() child.Parent = nil end)
		end
	end
	return true
end

function AntiLag.restorePostEffects()
	if AntiLag.savedLighting then
		for key, value in pairs(AntiLag.savedLighting) do
			pcall(function() lightingService[key] = value end)
		end
		AntiLag.savedLighting = nil
	end
	for _, entry in ipairs(AntiLag.removedEffects) do
		if entry.instance and entry.instance.Parent == nil then
			pcall(function() entry.instance.Parent = entry.parent or lightingService end)
		end
	end
	AntiLag.removedEffects = {}
end

function AntiLag.applyTerrain()
	local terrain = workspace:FindFirstChildOfClass("Terrain")
	if not terrain then return false end
	AntiLag.savedTerrain = {
		WaterWaveSize = terrain.WaterWaveSize, WaterWaveSpeed = terrain.WaterWaveSpeed,
		WaterReflectance = terrain.WaterReflectance, WaterTransparency = terrain.WaterTransparency,
		Decoration = terrain.Decoration,
	}
	pcall(function()
		terrain.WaterWaveSize = 0
		terrain.WaterWaveSpeed = 0
		terrain.WaterReflectance = 0
		terrain.WaterTransparency = 1
		terrain.Decoration = false
	end)
	return true
end

function AntiLag.restoreTerrain()
	if not AntiLag.savedTerrain then return end
	local terrain = workspace:FindFirstChildOfClass("Terrain")
	if terrain then
		for key, value in pairs(AntiLag.savedTerrain) do
			pcall(function() terrain[key] = value end)
		end
	end
	AntiLag.savedTerrain = nil
end

function AntiLag.restoreSounds()
	for sound, data in pairs(AntiLag.mutedSounds) do
		if sound and sound.Parent then
			pcall(function() sound.Volume = data.volume end)
		end
	end
	AntiLag.mutedSounds = setmetatable({}, { __mode = "k" })
end

function AntiLag.restorePlayers()
	for part in pairs(AntiLag.hiddenParts) do
		if part and part.Parent then
			pcall(function() part.LocalTransparencyModifier = 0 end)
		end
	end
	AntiLag.hiddenParts = setmetatable({}, { __mode = "k" })
end

function AntiLag.watchThings()
	task.spawn(function()
		local things = workspace:FindFirstChild("__THINGS") or workspace:WaitForChild("__THINGS", 60)
		if not things or not AntiLag.enabled then return end
		AntiLag.sweepContainer(things)
		AntiLag.connections.descendantAdded = things.DescendantAdded:Connect(function(descendant)
			local className = descendant.ClassName
			if HEAVY_CLASSES[className] then
				task.defer(function() pcall(function() descendant:Destroy() end) end)
			elseif DECOR_CLASSES[className] then
				pcall(function() descendant.Transparency = 1 end)
			elseif className == "Sound" then
				AntiLag.muteSound(descendant)
			end
		end)
	end)
end

function AntiLag.enable()
	if AntiLag.enabled then return true end
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
			if AntiLag.enabled then AntiLag.hideCharacter(character) end
		end)
	end)
	AntiLag.sweepThread = task.spawn(function()
		while AntiLag.enabled and VRTContext.isAlive() do
			task.wait(AntiLag.interval)
			if not AntiLag.enabled then break end
			pcall(AntiLag.sweep)
		end
	end)
	VRTContext.log("AntiLag enabled")
	return true
end

function AntiLag.disable()
	if not AntiLag.enabled then return end
	AntiLag.enabled = false
	for _, connection in pairs(AntiLag.connections) do
		pcall(function() connection:Disconnect() end)
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

-- ══════════════════════════════════════════════════════════
--  FARM
-- ══════════════════════════════════════════════════════════

local Farm = { enabled = false, radius = 85 }

function Farm.collect()
	local root = getRoot()
	if not root then return {} end
	local things = workspace:FindFirstChild("__THINGS")
	local breakables = things and things:FindFirstChild("Breakables")
	if not breakables then return {} end
	local origin = root.Position
	local result = {}
	for _, breakable in ipairs(breakables:GetChildren()) do
		if breakable:IsA("Model") then
			local ok, pivot = pcall(function() return breakable:GetPivot().Position end)
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
	if not network or not playerPet then return false end
	local ok, pets = pcall(function() return playerPet:GetAll() end)
	if not ok or type(pets) ~= "table" then return false end
	local batch = {}
	for _, pet in ipairs(pets) do
		if type(pet) == "table" and pet.owner == localPlayer and pet.euid then
			table.insert(batch, { euid = pet.euid })
		end
	end
	if #batch == 0 then return false end
	pcall(network.Fire, network, "Breakables_JoinPetBulk", unpack(batch))
	return true
end

function Farm.damage()
	local network = getNetwork()
	if not network then return false end
	local names = Farm.collect()
	if #names == 0 then return false end
	for _, name in ipairs(names) do
		pcall(network.UnreliableFire, network, "Breakables_PlayerDealDamage", name)
	end
	return true
end

function Farm.start()
	if Farm.enabled then return true end
	Farm.enabled = true
	task.spawn(function()
		while Farm.enabled and VRTContext.isAlive() do
			pcall(Farm.joinPets)
			pcall(Farm.damage)
			task.wait(0.15)
		end
		Farm.enabled = false
	end)
	return true
end

function Farm.stop() Farm.enabled = false end

-- ══════════════════════════════════════════════════════════
--  EGGS
-- ══════════════════════════════════════════════════════════

local Egg = { enabled = false, lastError = nil, lastOpened = nil }

function Egg.getMaxHatch()
	local eggCmds = getClientModule("EggCmds")
	if not eggCmds then return 1 end
	local ok, value = pcall(function() return eggCmds:GetMaxHatch() end)
	return ok and tonumber(value) or 1
end

local function getThingsFolder()
	return workspace:FindFirstChild("__THINGS")
end

local function getWorldEggsFolder()
	local things = getThingsFolder()
	if not things then return nil end
	local eggs = things:FindFirstChild("Eggs")
	if not eggs then return nil end
	local world = eggs:FindFirstChild("World")
	if world and #world:GetChildren() > 0 then return world end
	if #eggs:GetChildren() > 0 then return eggs end
	return nil
end

local function getZoneEggsFolder()
	local things = getThingsFolder()
	if not things then return nil end
	local zoneEggs = things:FindFirstChild("ZoneEggs")
	if not zoneEggs then return nil end
	local world = zoneEggs:FindFirstChild("World")
	if world and #world:GetChildren() > 0 then return world end
	if #zoneEggs:GetChildren() > 0 then return zoneEggs end
	return nil
end

local function getCustomEggsFolder()
	local things = getThingsFolder()
	if not things then return nil end
	return things:FindFirstChild("CustomEggs")
end

local function getRenderedEggsFolder()
	local things = getThingsFolder()
	if not things then return nil end
	return things:FindFirstChild("RenderedEggs")
end

local function isEggInstance(inst)
	return inst:IsA("Model") or inst:IsA("BasePart")
end

local function getEggPosition(inst)
	local ok, pivot = pcall(function() return inst:GetPivot().Position end)
	if ok and pivot then return pivot end
	local ok2, pos = pcall(function() return inst.Position end)
	if ok2 and pos then return pos end
	return nil
end

local function findClosestInFolder(folder, filterName)
	if not folder then return nil end
	local root = getRoot()
	if not root then return nil end
	local origin = root.Position
	local closest, closestDist
	for _, child in ipairs(folder:GetChildren()) do
		if isEggInstance(child) then
			local matches = filterName == nil or child.Name == filterName
			if matches then
				local pos = getEggPosition(child)
				if pos then
					local dist = (origin - pos).Magnitude
					if not closestDist or dist < closestDist then
						closestDist = dist
						closest = child
					end
				end
			end
		end
	end
	return closest
end

function Egg.getNames()
	local names = {}
	local seen = {}
	local folders = { getWorldEggsFolder(), getZoneEggsFolder() }
	local count = 0
	for _, folder in ipairs(folders) do
		if folder then
			for _, child in ipairs(folder:GetChildren()) do
				if isEggInstance(child) and not seen[child.Name] then
					seen[child.Name] = true
					table.insert(names, child.Name)
					count = count + 1
				end
			end
		end
	end
	if count == 0 then
		local rendered = getRenderedEggsFolder()
		if rendered then
			for _, child in ipairs(rendered:GetChildren()) do
				if isEggInstance(child) and not seen[child.Name] then
					seen[child.Name] = true
					table.insert(names, child.Name)
				end
			end
		end
	end
	table.sort(names)
	return names
end

function Egg.findClosest(filterName)
	local worldEgg = findClosestInFolder(getWorldEggsFolder(), filterName)
	local zoneEgg = findClosestInFolder(getZoneEggsFolder(), filterName)
	if worldEgg and zoneEgg then
		local root = getRoot()
		if root then
			local origin = root.Position
			local worldPos = getEggPosition(worldEgg)
			local zonePos = getEggPosition(zoneEgg)
			if worldPos and zonePos then
				local worldDist = (origin - worldPos).Magnitude
				local zoneDist = (origin - zonePos).Magnitude
				return worldDist <= zoneDist and worldEgg or zoneEgg
			end
		end
		return worldEgg
	end
	return worldEgg or zoneEgg
end

local function openEggRemote(remoteName, eggModel, maxHatch)
	local network = getNetwork()
	if not network then return false, "no network" end
	local ok, r1, r2 = pcall(network.Invoke, network, remoteName, eggModel, maxHatch)
	if not ok then return false, "pcall: " .. tostring(r1) end
	if r1 == false then return false, "server: " .. tostring(r2) end
	return true
end

function Egg.openClosest()
	local selected = VRTContext.settings.SelectedEgg
	local filterName = nil
	if selected and selected ~= "Auto (Closest)" then filterName = selected end

	local maxHatch = Egg.getMaxHatch()
	if maxHatch <= 0 then
		Egg.lastError = "maxHatch=0"
		return false, Egg.lastError
	end

	if filterName == nil then
		local customEgg = findClosestInFolder(getCustomEggsFolder(), nil)
		if customEgg then
			local ok, err = openEggRemote("CustomEggs_Hatch", tostring(customEgg), maxHatch)
			if ok then
				Egg.lastOpened = customEgg.Name
				Egg.lastError = nil
				return true
			end
			Egg.lastError = "custom: " .. tostring(err)
		end
	end

	local model = Egg.findClosest(filterName)
	if not model then
		Egg.lastError = "no egg found"
		return false, Egg.lastError
	end

	local ok, err = openEggRemote("Eggs_RequestPurchase", model, maxHatch)
	if ok then
		Egg.lastOpened = model.Name
		Egg.lastError = nil
		return true
	end

	Egg.lastError = tostring(err)
	return false, Egg.lastError
end

function Egg.start()
	if Egg.enabled then return true end
	Egg.enabled = true
	task.spawn(function()
		while Egg.enabled and VRTContext.isAlive() do
			pcall(Egg.openClosest)
			task.wait(0.2)
		end
		Egg.enabled = false
	end)
	return true
end

function Egg.stop() Egg.enabled = false end

local EggAnimation = { original = nil }

local function getEggOpeningEnv()
	local ps = localPlayer:FindFirstChild("PlayerScripts")
	local scripts = ps and ps:FindFirstChild("Scripts")
	local gameFolder = scripts and scripts:FindFirstChild("Game")
	local frontend = gameFolder and gameFolder:FindFirstChild("Egg Opening Frontend")
	if not frontend then return nil end
	local ok, env = pcall(getsenv, frontend)
	return ok and env or nil
end

function EggAnimation.hide()
	local env = getEggOpeningEnv()
	if not env then return false end
	if not EggAnimation.original and type(env.PlayEggAnimation) == "function" then
		EggAnimation.original = env.PlayEggAnimation
	end
	env.PlayEggAnimation = function() end
	return true
end

function EggAnimation.hook()
	local env = getEggOpeningEnv()
	if not env then return false end
	if not EggAnimation.original and type(env.PlayEggAnimation) == "function" then
		EggAnimation.original = env.PlayEggAnimation
	end
	env.PlayEggAnimation = function()
		pcall(setthreadidentity, 4)
		local eggCmds = getClientModule("EggCmds")
		if eggCmds and eggCmds.Message then
			local ok, maxHatch = pcall(function() return eggCmds:GetMaxHatch() end)
			if ok then
				pcall(function()
					eggCmds.Message.Bottom = "Still Opening " .. tostring(maxHatch)
					eggCmds.Message.Color = Color3.fromRGB(math.random(0,255), math.random(0,255), math.random(0,255))
				end)
			end
		end
		pcall(setthreadidentity, 8)
	end
	return true
end

function EggAnimation.restore()
	local env = getEggOpeningEnv()
	if not env or not EggAnimation.original then return false end
	env.PlayEggAnimation = EggAnimation.original
	EggAnimation.original = nil
	return true
end

-- ══════════════════════════════════════════════════════════
--  HUGE PET SPEED
-- ══════════════════════════════════════════════════════════

local HugePetSpeed = { original = nil, hooked = false }

function HugePetSpeed.enable()
	if HugePetSpeed.hooked then return true end
	local playerPet = getClientModule("PlayerPet")
	if not playerPet then return false end
	local target = playerPet.CalculateSpeedMultiplier
	if type(target) ~= "function" then return false end
	local ok, original = pcall(hookfunction, target, newcclosure(function(...) return math.huge end))
	if not ok or type(original) ~= "function" then return false end
	HugePetSpeed.original = original
	HugePetSpeed.hooked = true
	VRTContext.log("HugePetSpeed hooked")
	return true
end

function HugePetSpeed.disable()
	if not HugePetSpeed.hooked then return end
	local playerPet = getClientModule("PlayerPet")
	if playerPet then pcall(restorefunction, playerPet.CalculateSpeedMultiplier) end
	HugePetSpeed.original = nil
	HugePetSpeed.hooked = false
end

-- ══════════════════════════════════════════════════════════
--  FLAGS
-- ══════════════════════════════════════════════════════════

local Flags = {}

function Flags.activate(flagName, amount)
	local flagCmds = getClientModule("FlexibleFlagCmds")
	if not flagCmds then return false end
	if type(flagCmds.Consume) == "function" then
		local ok = pcall(function() flagCmds:Consume(flagName, amount) end)
		if ok then return true end
	end
	return invokeRemote("FlexibleFlags_Consume", flagName, amount)
end

-- ══════════════════════════════════════════════════════════
--  KEYS / CHESTS
-- ══════════════════════════════════════════════════════════

local Keys = {}

function Keys.canCombine(keyName)
	local lower = countItem(keyName .. " Lower Half")
	local upper = countItem(keyName .. " Upper Half")
	return lower > 0 and upper > 0
end

function Keys.combineAll()
	local did = false
	for _, key in ipairs(KEY_LIST) do
		if Keys.canCombine(key.name) then
			invokeRemote(key.remote, key.name)
			did = true
			task.wait(0.15)
		end
	end
	return did
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
	local did = false
	for _, chest in ipairs(CHEST_LIST) do
		if countItem(chest.item) > 0 then
			invokeRemote(chest.remote, chest.name)
			did = true
			task.wait(0.15)
		end
	end
	return did
end

-- ══════════════════════════════════════════════════════════
--  TREEHOUSE
-- ══════════════════════════════════════════════════════════

local TreeHouse = {}

local function getItemsLibrary()
	local library = replicatedStorage:FindFirstChild("Library")
	local items = library and library:FindFirstChild("Items")
	if not items then return nil end
	local ok, module = pcall(require, items)
	return ok and module or nil
end

function TreeHouse.hasKey() return countItem("Secret Key") > 0 end
function TreeHouse.enter() invokeRemote("Instancing_PlayerEnterInstance", "TreehouseMerchant") end
function TreeHouse.leave() fireRemote("Instancing_PlayerLeaveInstance", "TreehouseMerchant") end
function TreeHouse.unlock() invokeRemote("SecretRoom_Unlock", TREEHOUSE_ID) end

function TreeHouse.claimBest()
	local save = getSave()
	if not save or type(save.SecretRooms) ~= "table" then return false end
	local items = save.SecretRooms[TREEHOUSE_ID]
	if type(items) ~= "table" or #items == 0 then return false end
	local itemsLib = getItemsLibrary()
	local bestItem, bestRap = nil, -math.huge
	for _, item in ipairs(items) do
		if type(item) == "table" and type(item.data) == "table" and item.data.id then
			local class = item.class
			if (class == "Enchant" or class == "Potion") and type(item.SetTier) == "function" then
				pcall(function() item:SetTier(item.data.tn) end)
			end
			local rap = 0
			local classModule = itemsLib and itemsLib[class]
			if type(classModule) == "table" and type(classModule.GetRAP) == "function" then
				local ok, value = pcall(classModule.GetRAP, classModule, item.data.id)
				if ok and type(value) == "number" then rap = value end
			end
			if rap > bestRap then
				bestRap = rap
				bestItem = item
			end
		end
	end
	if not bestItem then return false end
	invokeRemote("TreehouseMerchant_Purchase", bestItem, bestRap, bestItem.class)
	return true
end

function TreeHouse.farm()
	if not TreeHouse.hasKey() then return false end
	TreeHouse.enter()
	task.wait(0.4)
	local claimed = TreeHouse.claimBest()
	TreeHouse.leave()
	if not claimed then TreeHouse.unlock() end
	return claimed
end

-- ══════════════════════════════════════════════════════════
--  ADMIN ABUSE
-- ══════════════════════════════════════════════════════════

local AdminAbuse = {}

function AdminAbuse.claimHiddenEgg()
	local things = workspace:FindFirstChild("__THINGS")
	local adminChars = things and things:FindFirstChild("AdminAbuseCharacters")
	if not adminChars then return false end
	local root = getRoot()
	if not root then return false end
	local claimed = 0
	for _, fakeChar in ipairs(adminChars:GetChildren()) do
		local fakeUid = fakeChar:GetAttribute("FakeCharUID")
		if fakeUid then
			pcall(function() root.CFrame = fakeChar:GetPivot() end)
			task.wait(0.05)
			invokeRemote("AdminAbuse:FakeCharacter:Claim", fakeUid)
			claimed = claimed + 1
		end
	end
	return claimed > 0
end

-- ══════════════════════════════════════════════════════════
--  BOOSTS
-- ══════════════════════════════════════════════════════════

local Boosts = {}

local function getMiscItems()
	local save = getSave()
	if not save or type(save.Inventory) ~= "table" then return {} end
	local misc = save.Inventory.Misc
	if type(misc) ~= "table" then return {} end
	local list = {}
	for _, item in pairs(misc) do
		if type(item) == "table" and item.id then
			local uid = item._uid or item.euid or item.uid
			if uid then
				table.insert(list, { id = item.id, uid = uid, amount = tonumber(item._am) or 1 })
			end
		end
	end
	return list
end

function Boosts.consume(uid) return invokeRemote("Consumables_Consume", uid) end

function Boosts.consumeByPrefix(prefix)
	local items = getMiscItems()
	local did = false
	for _, item in ipairs(items) do
		if item.id:find(prefix, 1, true) then
			Boosts.consume(item.uid)
			did = true
			task.wait(0.15)
		end
	end
	return did
end

function Boosts.consumeMountain() return Boosts.consumeByPrefix("Boost | DiamondMountain") end

function Boosts.consumeGeneral()
	local items = getMiscItems()
	local did = false
	for _, item in ipairs(items) do
		if item.id:find("Boost |", 1, true) and not item.id:find("DiamondMountain", 1, true) then
			Boosts.consume(item.uid)
			did = true
			task.wait(0.15)
		end
	end
	return did
end

function Boosts.list()
	local names = {}
	for _, item in ipairs(getMiscItems()) do
		if item.id:find("Boost |", 1, true) then table.insert(names, item.id) end
	end
	table.sort(names)
	return names
end

-- ══════════════════════════════════════════════════════════
--  MISC
-- ══════════════════════════════════════════════════════════

local Misc = {}

function Misc.claimFreeGifts()
	local library = replicatedStorage:FindFirstChild("Library")
	local directory = library and library:FindFirstChild("Directory")
	local freeGifts = directory and directory:FindFirstChild("FreeGifts")
	if not freeGifts then return false end
	local ok, gifts = pcall(require, freeGifts)
	if not ok or type(gifts) ~= "table" then return false end
	local save = getSave()
	if not save then return false end
	local redeemed = type(save.FreeGiftsRedeemed) == "table" and save.FreeGiftsRedeemed or {}
	local did = false
	for _, gift in pairs(gifts) do
		if type(gift) == "table" and gift._id and (tonumber(gift.WaitTime) or 0) > 0 then
			if not table.find(redeemed, gift._id) then
				invokeRemote("Redeem Free Gift", gift._id)
				did = true
				task.wait(0.2)
			end
		end
	end
	return did
end

function Misc.activateUltimate()
	local ultimateCmds = getClientModule("UltimateCmds")
	if not ultimateCmds then return false end
	local ok, equipped = pcall(function() return ultimateCmds:GetEquippedItem() end)
	if not ok or type(equipped) ~= "table" then return false end
	local id = equipped._data and equipped._data.id
	if not id then return false end
	local okCharged, charged = pcall(function() return ultimateCmds:IsCharged(id) end)
	if okCharged and charged then
		pcall(function() ultimateCmds:Activate(id) end)
		return true
	end
	return false
end

function Misc.buyPetSlots()
	local petEquipCmds = getClientModule("PetEquipCmds")
	if not petEquipCmds then return false end
	for slot = 1, 20 do
		local ok, status = pcall(function() return petEquipCmds:GetStatus(slot) end)
		if ok and status == "NEXT" then
			invokeRemote("EquipSlotsMachine_RequestPurchase", slot)
			return true
		end
	end
	return false
end

function Misc.buyNextZone()
	local zoneCmds = getClientModule("ZoneCmds")
	if not zoneCmds then return false end
	local ok, nextZone = pcall(function() return zoneCmds:GetNextZone() end)
	if not ok or nextZone == nil then return false end
	if type(zoneCmds.RequestPurchase) == "function" then
		if pcall(function() zoneCmds:RequestPurchase() end) then return true end
	end
	local zoneId = type(nextZone) == "table" and (nextZone._id or nextZone.ZoneNumber) or nextZone
	invokeRemote("Zones_RequestPurchase", zoneId)
	return true
end

function Misc.claimRankRewards()
	local rankCmds = getClientModule("RankCmds")
	if rankCmds and type(rankCmds.ClaimAll) == "function" then
		if pcall(function() rankCmds:ClaimAll() end) then return true end
	end
	fireRemote("Ranks_ClaimReward")
	return true
end

-- ══════════════════════════════════════════════════════════
--  DIAMOND MOUNTAIN
-- ══════════════════════════════════════════════════════════

local DiamondMountain = { features = {} }

local function getDmRoot()
	local library = replicatedStorage:FindFirstChild("Library")
	local client = library and library:FindFirstChild("Client")
	local dmRoot = client and client:FindFirstChild("DiamondMountainCmds")
	if not dmRoot then return nil end
	local ok, module = pcall(require, dmRoot)
	if not ok or type(module) ~= "table" then return nil end
	return module
end

local function getDmInstance()
	local root = getDmRoot()
	if not root then return nil end
	if type(root.Instance) ~= "function" then return nil end
	local ok, instance = pcall(function() return root.Instance() end)
	return ok and instance or nil
end

-- FIX: pcall trực tiếp, không bọc closure để tránh lỗi "Cannot use '...' outside of a vararg function"
local function dmInvoke(action, ...)
	local instance = getDmInstance()
	if not instance then return false end
	return pcall(instance.InvokeCustom, instance, action, ...)
end

function DiamondMountain.isInside() return Instancing.isIn(DM_INSTANCE_ID) end

function DiamondMountain.getFolder()
	local things = workspace:FindFirstChild("__THINGS")
	if not things then return nil end
	local container = things:FindFirstChild("__INSTANCE_CONTAINER")
	local active = container and container:FindFirstChild("Active")
	local folder = active and active:FindFirstChild(DM_INSTANCE_ID)
	if folder then return folder end
	local instances = things:FindFirstChild("Instances")
	return instances and instances:FindFirstChild(DM_INSTANCE_ID) or nil
end

-- FIX: đọc thẳng Save.Inventory.Pet, không dùng PetItem:All() + GetUID() (không tồn tại)
local function buildPetStacks(limit)
	local save = getSave()
	if not save or type(save.Inventory) ~= "table" then return {} end
	local pets = save.Inventory.Pet
	if type(pets) ~= "table" then return {} end
	local stacks = {}
	local count = 0
	for _, pet in pairs(pets) do
		if count >= (limit or 100) then break end
		if type(pet) == "table" then
			local uid = pet._uid or pet.euid or pet.uid
			local amount = tonumber(pet._am) or 1
			if uid and amount > 0 then
				stacks[uid] = amount
				count = count + 1
			end
		end
	end
	return stacks
end

local function getYetiStacks()
	local library = replicatedStorage:FindFirstChild("Library")
	local client = library and library:FindFirstChild("Client")
	local dmFolder = client and client:FindFirstChild("DiamondMountainCmds")
	local depositInst = dmFolder and dmFolder:FindFirstChild("Deposit")
	if not depositInst then return {} end
	local ok, deposit = pcall(require, depositInst)
	if not ok or type(deposit) ~= "table" then return {} end
	local ok2, stacks = pcall(function() return deposit.Stacks("yeti") end)
	if not ok2 or type(stacks) ~= "table" then return {} end
	local result = {}
	for _, entry in ipairs(stacks) do
		if type(entry) == "table" and entry.uid and entry.count then
			result[entry.uid] = entry.count
		end
	end
	return result
end

function DiamondMountain.claimExpedition() return dmInvoke("PL_Queue_Claim", nil) end

function DiamondMountain.pullExpedition()
	local did = false
	for pedestal = 1, 4 do
		if dmInvoke("PL_Queue_Pull", pedestal) then did = true end
		task.wait(0.15)
	end
	return did
end

function DiamondMountain.sendExpedition()
	local stacks = buildPetStacks(100)
	local uidList = {}
	for uid in pairs(stacks) do table.insert(uidList, uid) end
	if #uidList == 0 then return false end
	local sent = 0
	local idx = 1
	for pedestal = 1, 4 do
		for _ = 1, 25 do
			if idx > #uidList then break end
			if dmInvoke("PL_Queue_Send", pedestal, uidList[idx]) then sent = sent + 1 end
			idx = idx + 1
			task.wait(0.15)
		end
	end
	return sent > 0
end

function DiamondMountain.unlockExpedition()
	local did = false
	for pedestal = 1, 4 do
		if dmInvoke("PL_Queue_Unlock", pedestal) then did = true end
		task.wait(0.2)
	end
	return did
end

function DiamondMountain.loadYeti()
	local stacks = buildPetStacks(100)
	if next(stacks) == nil then return false end
	return dmInvoke("HT_Attach_Load", stacks)
end

function DiamondMountain.pickupYeti()
	local stacks = getYetiStacks()
	local did = false
	for uid, count in pairs(stacks) do
		if dmInvoke("HT_Attach_PickUp", uid, count) then did = true end
		task.wait(0.15)
	end
	return did
end

function DiamondMountain.feedYeti()
	local stacks = buildPetStacks(100)
	if next(stacks) == nil then return false end
	return dmInvoke("KV_Pulse_Feed", stacks)
end

function DiamondMountain.merchant()
	local did = false
	for slot = 1, 6 do
		if invokeRemote("Merchant_RequestPurchase", "DiamondMountainMerchant", slot) then
			did = true
		end
		task.wait(0.15)
	end
	return did
end

function DiamondMountain.buyUpgrades()
	local eventUpgradeCmds = getClientModule("EventUpgradeCmds")
	if not eventUpgradeCmds then return false end
	local library = replicatedStorage:FindFirstChild("Library")
	local directory = library and library:FindFirstChild("Directory")
	local upgradesFolder = directory and directory:FindFirstChild("EventUpgrades")
	if not upgradesFolder then return false end
	local eventFolder = upgradesFolder:FindFirstChild("Event")
	local dmFolder = eventFolder and eventFolder:FindFirstChild("DiamondMountain")
	if not dmFolder then return false end
	local did = false
	for _, upgradeScript in ipairs(dmFolder:GetChildren()) do
		if upgradeScript:IsA("ModuleScript") then
			local ok, upgradeData = pcall(require, upgradeScript)
			if ok and type(upgradeData) == "table" then
				if pcall(function() eventUpgradeCmds.Purchase(upgradeData) end) then
					did = true
				end
				task.wait(0.15)
			end
		end
	end
	return did
end

function DiamondMountain.loadWalls()
	local library = replicatedStorage:FindFirstChild("Library")
	local client = library and library:FindFirstChild("Client")
	local dmFolder = client and client:FindFirstChild("DiamondMountainCmds")
	local wallsInst = dmFolder and dmFolder:FindFirstChild("Walls")
	if not wallsInst then return false end
	local ok, walls = pcall(require, wallsInst)
	if not ok or type(walls) ~= "table" then return false end
	local stacks = buildPetStacks(100)
	if next(stacks) == nil then return false end
	local did = false
	for wall = 1, 6 do
		if pcall(function() walls.Load(wall, stacks) end) then did = true end
		task.wait(0.2)
	end
	return did
end

function DiamondMountain.autoFarm()
	local network = getNetwork()
	local root = getRoot()
	if not network or not root then return false end
	local dmFolder = DiamondMountain.getFolder()
	if not dmFolder then return false end
	local breakables = dmFolder:FindFirstChild("Breakables")
	if not breakables then return false end
	local origin = root.Position
	local hit = 0
	for _, breakable in ipairs(breakables:GetChildren()) do
		if breakable:IsA("Model") then
			local ok, pivot = pcall(function() return breakable:GetPivot().Position end)
			if ok and pivot and (origin - pivot).Magnitude <= DM_FARM_RADIUS then
				pcall(network.UnreliableFire, network, "Breakables_PlayerDealDamage", breakable.Name)
				hit = hit + 1
			end
		end
	end
	return hit > 0
end

function DiamondMountain.enter() return Instancing.enter(DM_INSTANCE_ID) end
function DiamondMountain.leave() return Instancing.leave() end

function DiamondMountain.optimize()
	local folder = DiamondMountain.getFolder()
	if not folder then return false end
	for _, descendant in ipairs(folder:GetDescendants()) do
		if descendant:IsA("ParticleEmitter") or descendant:IsA("Trail")
			or descendant:IsA("Beam") or descendant:IsA("Decal") then
			pcall(function() descendant:Destroy() end)
		end
	end
	return true
end

function DiamondMountain.startFeature(key, callback, interval)
	if DiamondMountain.features[key] then return end
	DiamondMountain.features[key] = true
	task.spawn(function()
		while DiamondMountain.features[key] and VRTContext.isAlive() do
			pcall(callback)
			task.wait(interval or 1)
		end
		DiamondMountain.features[key] = false
	end)
end

function DiamondMountain.stopFeature(key) DiamondMountain.features[key] = false end

-- ══════════════════════════════════════════════════════════
--  TIME TRIAL
-- ══════════════════════════════════════════════════════════

local TimeTrial = {
	enabled = false, moveHooked = false, originalMoveDirection = nil,
	hoverboardInstance = nil, saveCache = nil, saveCacheAt = 0,
	lastJumpAt = 0, lastEnterAt = 0,
}

function TimeTrial.getSave()
	local now = os.clock()
	if TimeTrial.saveCache and now - TimeTrial.saveCacheAt < SAVE_TTL then
		return TimeTrial.saveCache
	end
	local saveModule = getClientModule("Save")
	if not saveModule then return nil end
	local ok, data = pcall(function() return saveModule:Get() end)
	TimeTrial.saveCache = ok and data or nil
	TimeTrial.saveCacheAt = now
	return TimeTrial.saveCache
end

function TimeTrial.isInside() return Instancing.isIn(TT_INSTANCE_ID) end

function TimeTrial.isSpawned()
	local character = localPlayer.Character
	if not character then return false end
	local humanoid = character:FindFirstChild("Humanoid")
	if humanoid and humanoid.Health <= 0 then return false end
	return character:FindFirstChild("HumanoidRootPart") ~= nil
end

function TimeTrial.enter()
	if TimeTrial.isInside() then return false end
	local now = os.clock()
	if now - TimeTrial.lastEnterAt < TT_ENTER_COOLDOWN then return false end
	TimeTrial.lastEnterAt = now
	return Instancing.enter(TT_INSTANCE_ID)
end

function TimeTrial.jump()
	local now = os.clock()
	if now - TimeTrial.lastJumpAt < TT_JUMP_COOLDOWN then return false end
	TimeTrial.lastJumpAt = now
	pcall(function() virtualInputManager:SendKeyEvent(true, Enum.KeyCode.Space, false, game) end)
	task.wait(0.05)
	pcall(function() virtualInputManager:SendKeyEvent(false, Enum.KeyCode.Space, false, game) end)
	return true
end

function TimeTrial.getHoverboardInstance()
	if TimeTrial.hoverboardInstance then return TimeTrial.hoverboardInstance end
	local ps = localPlayer:FindFirstChild("PlayerScripts")
	local scripts = ps and ps:FindFirstChild("Scripts")
	local gameFolder = scripts and scripts:FindFirstChild("Game")
	local manager = gameFolder and gameFolder:FindFirstChild("Hoverboard Manager")
	local module = manager and manager:FindFirstChild("HoverboardInstance")
	if not module then return nil end
	local ok, result = pcall(require, module)
	if not ok or type(result) ~= "table" then return nil end
	TimeTrial.hoverboardInstance = result
	return result
end

function TimeTrial.getBestZone()
	local things = workspace:FindFirstChild("__THINGS")
	local breakables = things and things:FindFirstChild("Breakables")
	if not breakables then return nil end
	local counts = {}
	for _, breakable in ipairs(breakables:GetChildren()) do
		local areaId = breakable:GetAttribute("AreaID")
		if areaId then counts[areaId] = (counts[areaId] or 0) + 1 end
	end
	local bestId, bestCount
	for id, count in pairs(counts) do
		if not bestCount or count > bestCount then
			bestCount = count
			bestId = id
		end
	end
	if not bestId then return nil end
	local instances = things:FindFirstChild("Instances")
	local ttFolder = instances and instances:FindFirstChild(TT_INSTANCE_ID)
	local spawns = ttFolder and ttFolder:FindFirstChild("BREAKABLE_SPAWNS")
	local spawnPart = spawns and spawns:FindFirstChild(bestId)
	if spawnPart then return spawnPart end
	for _, breakable in ipairs(breakables:GetChildren()) do
		if breakable:GetAttribute("AreaID") == bestId then return breakable end
	end
	return nil
end

function TimeTrial.computeDirection()
	local root = getRoot()
	if not root then return Vector3.zero, Vector3.zero end
	local zone = TimeTrial.getBestZone()
	if not zone then return Vector3.zero, Vector3.zero end
	local ok, target = pcall(function() return zone.Position end)
	if not ok or not target then return Vector3.zero, Vector3.zero end
	local delta = target - root.Position
	if delta.Magnitude <= TT_STOP_RADIUS then return Vector3.zero, Vector3.zero end
	return delta.Unit, Vector3.zero
end

function TimeTrial.hookMove()
	if TimeTrial.moveHooked then return true end
	local hoverboard = TimeTrial.getHoverboardInstance()
	if not hoverboard then return false end
	local original = hoverboard.ComputeMoveDirection
	if type(original) ~= "function" then return false end
	pcall(setreadonly, hoverboard, false)
	local replacement = function(boardSelf, ...)
		if not TimeTrial.enabled then return original(boardSelf, ...) end
		local ok, direction, extra = pcall(TimeTrial.computeDirection)
		if not ok then return original(boardSelf, ...) end
		return direction, extra
	end
	if not pcall(function() hoverboard.ComputeMoveDirection = replacement end) then
		return false
	end
	TimeTrial.originalMoveDirection = original
	TimeTrial.moveHooked = true
	VRTContext.log("[TT] move hook installed")
	return true
end

function TimeTrial.unhookMove()
	if not TimeTrial.moveHooked then return end
	local hoverboard = TimeTrial.hoverboardInstance
	if hoverboard and TimeTrial.originalMoveDirection then
		pcall(function() hoverboard.ComputeMoveDirection = TimeTrial.originalMoveDirection end)
	end
	TimeTrial.originalMoveDirection = nil
	TimeTrial.moveHooked = false
end

function TimeTrial.tick()
	if not TimeTrial.isSpawned() then return end
	if TimeTrial.isInside() then TimeTrial.jump() return end
	TimeTrial.enter()
end

function TimeTrial.start()
	if TimeTrial.enabled then return true end
	TimeTrial.enabled = true
	TimeTrial.hookMove()
	task.spawn(function() pcall(TimeTrial.tick) end)
	task.spawn(function()
		while TimeTrial.enabled and VRTContext.isAlive() do
			pcall(TimeTrial.tick)
			task.wait(TT_FARM_INTERVAL)
		end
		TimeTrial.enabled = false
		TimeTrial.unhookMove()
	end)
	VRTContext.log("[TT] farm started")
	return true
end

function TimeTrial.stop()
	TimeTrial.enabled = false
	TimeTrial.unhookMove()
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
			if callback then pcall(callback, state) end
		end,
	})
	uiElements[flag] = element
	if VRTContext.settings[flag] == true and callback then
		task.defer(function() pcall(callback, true) end)
	end
	return element
end

local function loopToggle(tab, name, flag, callback, interval)
	return toggle(tab, name, flag, function(state)
		if not state then return end
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
		Callback = function() pcall(callback) end,
	})
end

local function slider(tab, name, flag, range, default, suffix, callback)
	local saved = tonumber(VRTContext.settings[flag]) or default
	if saved < range[1] then saved = range[1] end
	if saved > range[2] then saved = range[2] end
	local element = tab:CreateSlider({
		Name = name, Range = range, Increment = 1, Suffix = suffix,
		CurrentValue = saved, Flag = flag,
		Callback = function(value)
			VRTContext.settings[flag] = value
			if callback then pcall(callback, value) end
		end,
	})
	uiElements[flag] = element
	if callback then task.defer(function() pcall(callback, saved) end) end
	return element
end

local function dropdown(tab, name, flag, options, multi, default, callback)
	local saved = VRTContext.settings[flag]
	if multi then
		if type(saved) ~= "table" then saved = default or {} end
	else
		if type(saved) ~= "string" or not table.find(options, saved) then saved = default end
	end
	local element = tab:CreateDropdown({
		Name = name, Options = options, CurrentOption = saved,
		MultipleOptions = multi, Flag = flag,
		Callback = function(selected)
			VRTContext.settings[flag] = selected
			if callback then pcall(callback, selected) end
		end,
	})
	uiElements[flag] = element
	return element
end

local function input(tab, name, flag, placeholder, callback)
	local element = tab:CreateInput({
		Name = name, PlaceholderText = placeholder,
		CurrentValue = type(VRTContext.settings[flag]) == "string" and VRTContext.settings[flag] or "",
		Flag = flag, RemoveTextAfterFocusLost = false,
		Callback = function(text)
			VRTContext.settings[flag] = text
			if callback then pcall(callback, text) end
		end,
	})
	uiElements[flag] = element
	return element
end

-- Farm tab.
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

farmTab:CreateSection("Time Trial")

local ttStatusLabel = farmTab:CreateLabel("Status: ...", "timer", Color3.fromRGB(120, 200, 255), false)

task.spawn(function()
	while VRTContext.isAlive() do
		local inside = TimeTrial.isInside()
		pcall(function()
			ttStatusLabel:Set("Status: " .. (inside and "IN TRIAL" or "Not in trial"))
		end)
		task.wait(2)
	end
end)

toggle(farmTab, "Auto Farm Time Trial", "TT_AutoFarm", function(state)
	if state then TimeTrial.start() else TimeTrial.stop() end
end)

button(farmTab, "Enter Time Trial Now", function()
	local ok = TimeTrial.enter()
	VRTContext.notify("Time Trial", ok and "Entering..." or "Failed", 3)
end)

button(farmTab, "Leave Instance", function()
	Instancing.leave()
	VRTContext.notify("Instance", "Leaving...", 3)
end)

-- Eggs tab.
local eggTab = window:CreateTab("Eggs", "egg")

eggTab:CreateSection("Egg Selection")

local eggOptions = { "Auto (Closest)" }
for _, name in ipairs(Egg.getNames()) do table.insert(eggOptions, name) end

dropdown(eggTab, "Select Egg", "SelectedEgg", eggOptions, false, "Auto (Closest)")

button(eggTab, "Refresh Egg List", function()
	local names = Egg.getNames()
	VRTContext.notify("Eggs", "Found " .. #names .. " eggs (re-execute to update dropdown)", 5)
end)

eggTab:CreateSection("Hatching")
loopToggle(eggTab, "Auto Open Egg", "AutoOpenEgg", Egg.openClosest, 0.2)

eggTab:CreateSection("Debug")
button(eggTab, "Test Egg Open (Print Debug)", function()
	print("=== EGG DEBUG v" .. VERSION .. " ===")

	local worldFolder = getWorldEggsFolder()
	local zoneFolder = getZoneEggsFolder()
	local customFolder = getCustomEggsFolder()
	local renderedFolder = getRenderedEggsFolder()

	print("World folder:", worldFolder and worldFolder:GetFullName() or "nil")
	print("World children:", worldFolder and #worldFolder:GetChildren() or 0)
	print("Zone folder:", zoneFolder and zoneFolder:GetFullName() or "nil")
	print("Zone children:", zoneFolder and #zoneFolder:GetChildren() or 0)
	print("Custom folder:", customFolder and customFolder:GetFullName() or "nil")
	print("Custom children:", customFolder and #customFolder:GetChildren() or 0)
	print("Rendered folder:", renderedFolder and renderedFolder:GetFullName() or "nil")
	print("Rendered children:", renderedFolder and #renderedFolder:GetChildren() or 0)

	if worldFolder then
		print("--- World egg names (first 10) ---")
		for i, child in ipairs(worldFolder:GetChildren()) do
			if i > 10 then print("  ...") break end
			print("  " .. i .. ". " .. child.Name .. " [" .. child.ClassName .. "]")
		end
	end

	print("MaxHatch:", Egg.getMaxHatch())

	local model = Egg.findClosest(nil)
	if not model then
		print("Closest egg: NONE FOUND")
		VRTContext.notify("Eggs", "No egg found - see console", 5)
		return
	end
	print("Closest egg:", model.Name)
	print("Closest egg class:", model.ClassName)
	print("Closest egg full:", model:GetFullName())
	local pos = getEggPosition(model)
	print("Closest egg position:", pos and tostring(pos) or "nil")

	local ok, err = Egg.openClosest()
	print("Open result:", ok, "| err:", tostring(err))
	print("Last opened:", tostring(Egg.lastOpened))
	print("Last error:", tostring(Egg.lastError))

	VRTContext.notify("Eggs", ok and ("Opening " .. model.Name) or ("Failed: " .. tostring(err)), 4)
end)

button(eggTab, "Force Open World Egg", function()
	local worldFolder = getWorldEggsFolder()
	if not worldFolder then
		VRTContext.notify("Eggs", "World folder not found", 4)
		return
	end
	local firstEgg
	for _, child in ipairs(worldFolder:GetChildren()) do
		if isEggInstance(child) then
			firstEgg = child
			break
		end
	end
	if not firstEgg then
		VRTContext.notify("Eggs", "No egg in world folder", 4)
		return
	end
	local maxHatch = Egg.getMaxHatch()
	print("[VRT] Force open:", firstEgg.Name, "| maxHatch:", maxHatch)
	local ok, err = openEggRemote("Eggs_RequestPurchase", firstEgg, maxHatch)
	print("[VRT] Force result:", ok, "| err:", tostring(err))
	VRTContext.notify("Eggs", ok and ("Force opening " .. firstEgg.Name) or ("Failed: " .. tostring(err)), 4)
end)

eggTab:CreateSection("Animation")
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
	if not state then HugePetSpeed.disable() return end
	if not HugePetSpeed.enable() then
		VRTContext.notify("Huge Pet Speed", "PlayerPet.CalculateSpeedMultiplier not found", 5)
		VRTContext.settings.HugePetSpeed = false
		local element = uiElements.HugePetSpeed
		if element then pcall(function() element:Set(false) end) end
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

-- Event tab.
local eventTab = window:CreateTab("Event", "sparkles")

eventTab:CreateSection("Instance")
local dmStatusLabel = eventTab:CreateLabel("Status: ...", "info", Color3.fromRGB(120, 180, 255), false)

task.spawn(function()
	while VRTContext.isAlive() do
		local inside = DiamondMountain.isInside()
		pcall(function()
			dmStatusLabel:Set("Diamond Mountain: " .. (inside and "INSIDE" or "Not inside"))
		end)
		task.wait(2)
	end
end)

toggle(eventTab, "Auto Join Diamond Mountain", "DM_AutoJoin", function(state)
	if state then
		task.spawn(function()
			while VRTContext.settings.DM_AutoJoin and VRTContext.isAlive() do
				if not DiamondMountain.isInside() then DiamondMountain.enter() end
				task.wait(5)
			end
		end)
	end
end)

button(eventTab, "Join Diamond Mountain Now", function()
	local ok = DiamondMountain.enter()
	VRTContext.notify("Diamond Mountain", ok and "Entering..." or "Failed", 3)
end)

button(eventTab, "Leave Instance", function()
	Instancing.leave()
	VRTContext.notify("Instance", "Leaving...", 3)
end)

eventTab:CreateSection("Expedition (PL_Queue)")
loopToggle(eventTab, "Auto Claim Expedition", "DM_ClaimExp", DiamondMountain.claimExpedition, 3)
loopToggle(eventTab, "Auto Pull Expedition", "DM_PullExp", DiamondMountain.pullExpedition, 10)
loopToggle(eventTab, "Auto Send Expedition", "DM_SendExp", DiamondMountain.sendExpedition, 30)
loopToggle(eventTab, "Auto Unlock Expedition", "DM_UnlockExp", DiamondMountain.unlockExpedition, 15)

eventTab:CreateSection("Yeti (HT_Attach + KV_Pulse)")
loopToggle(eventTab, "Auto Load Yeti Pets", "DM_LoadYeti", DiamondMountain.loadYeti, 10)
loopToggle(eventTab, "Auto Pickup Yeti Pets", "DM_PickupYeti", DiamondMountain.pickupYeti, 30)
loopToggle(eventTab, "Auto Feed Yeti Power", "DM_FeedYeti", DiamondMountain.feedYeti, 15)

eventTab:CreateSection("Economy")
loopToggle(eventTab, "Auto Merchant Buy", "DM_Merchant", DiamondMountain.merchant, 10)
loopToggle(eventTab, "Auto Buy Upgrades", "DM_Upgrades", DiamondMountain.buyUpgrades, 10)
loopToggle(eventTab, "Auto Load Walls", "DM_Walls", DiamondMountain.loadWalls, 15)
loopToggle(eventTab, "Auto Farm Mountain", "DM_Farm", DiamondMountain.autoFarm, 0.3)
loopToggle(eventTab, "Optimize Visuals", "DM_Optimize", DiamondMountain.optimize, 10)

eventTab:CreateSection("Quick Actions")
button(eventTab, "Claim Expedition Now", function()
	local ok = DiamondMountain.claimExpedition()
	VRTContext.notify("Expedition", ok and "Claimed" or "Nothing to claim", 3)
end)

button(eventTab, "Pull All Expedition Pets", function()
	local ok = DiamondMountain.pullExpedition()
	VRTContext.notify("Expedition", ok and "Pulling..." or "Failed", 3)
end)

button(eventTab, "Send Pets to Expedition", function()
	local ok = DiamondMountain.sendExpedition()
	VRTContext.notify("Expedition", ok and "Sending..." or "No pets available", 3)
end)

button(eventTab, "Buy All Upgrades Now", function()
	local ok = DiamondMountain.buyUpgrades()
	VRTContext.notify("Upgrades", ok and "Purchasing..." or "Failed", 3)
end)

-- Admin tab.
local adminTab = window:CreateTab("Admin", "shield")

adminTab:CreateSection("Session")
toggle(adminTab, "Anti AFK", "AntiAfk", function(state)
	if state then AntiAfk.start() else AntiAfk.stop() end
end)

adminTab:CreateSection("Admin Abuse")
adminTab:CreateLabel("Must be in the same instance as the fake character", "info", Color3.fromRGB(120, 180, 255), false)
loopToggle(adminTab, "Claim Hidden Exclusive Egg", "ClaimHiddenEgg", AdminAbuse.claimHiddenEgg, 1)

adminTab:CreateSection("Optimize")
toggle(adminTab, "Optimize Breakables", "OptimizeBreakables", function(state)
	if state then Optimize.breakables() else Optimize.stopBreakables() end
end)

loopToggle(adminTab, "Optimize Pets", "OptimizePets", Optimize.pets, 5)

-- Misc tab.
local miscTab = window:CreateTab("Misc", "settings")

miscTab:CreateSection("Auto Claim")
loopToggle(miscTab, "Claim Free Gifts", "AutoFreeGifts", Misc.claimFreeGifts, 2)
loopToggle(miscTab, "Activate Ultimate", "AutoUltimate", Misc.activateUltimate, 1)
loopToggle(miscTab, "Buy Pet Slots", "AutoPetSlots", Misc.buyPetSlots, 2)
loopToggle(miscTab, "Buy Next Zone", "AutoNextZone", Misc.buyNextZone, 3)
loopToggle(miscTab, "Claim Rank Rewards", "AutoRankRewards", Misc.claimRankRewards, 5)

miscTab:CreateSection("Boosts")
miscTab:CreateLabel(
	"Consumes boost items via Consumables_Consume UUID",
	"zap", Color3.fromRGB(120, 200, 255), false
)

loopToggle(miscTab, "Auto Use Diamond Mountain Boosts", "AutoMountainBoosts", Boosts.consumeMountain, 5)
loopToggle(miscTab, "Auto Use General Boosts", "AutoGeneralBoosts", Boosts.consumeGeneral, 5)

button(miscTab, "List Boost Items", function()
	local names = Boosts.list()
	print("[VRT] Boost items in inventory (" .. #names .. "):")
	for _, name in ipairs(names) do print("  " .. name) end
	VRTContext.notify("Boosts", #names .. " boost items found (see console)", 5)
end)

button(miscTab, "Use Mountain Boosts Now", function()
	local ok = Boosts.consumeMountain()
	VRTContext.notify("Boosts", ok and "Consumed" or "Nothing to consume", 3)
end)

miscTab:CreateSection("Anti Lag")
miscTab:CreateLabel(
	"Removes particles, trails, beams, post FX, shadows, sounds + hides other players",
	"zap", Color3.fromRGB(120, 200, 255), false
)

toggle(miscTab, "Anti Lag (Maximum)", "AntiLag", function(state)
	if state then AntiLag.enable() else AntiLag.disable() end
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

-- Diagnostics.
miscTab:CreateSection("Diagnostics")

button(miscTab, "Test All Features", function()
	local tests = {
		{ "Network", function() return getNetwork() ~= nil end },
		{ "Save", function() return getSave() ~= nil end },
		{ "EggCmds", function() return getClientModule("EggCmds") ~= nil end },
		{ "PlayerPet", function() return getClientModule("PlayerPet") ~= nil end },
		{ "PlayerPet.CalculateSpeedMultiplier", function()
			local pp = getClientModule("PlayerPet")
			return pp ~= nil and type(pp.CalculateSpeedMultiplier) == "function"
		end },
		{ "FlexibleFlagCmds", function() return getClientModule("FlexibleFlagCmds") ~= nil end },
		{ "MapCmds", function() return getClientModule("MapCmds") ~= nil end },
		{ "ZoneCmds", function() return getClientModule("ZoneCmds") ~= nil end },
		{ "UltimateCmds", function() return getClientModule("UltimateCmds") ~= nil end },
		{ "PetEquipCmds", function() return getClientModule("PetEquipCmds") ~= nil end },
		{ "InstancingCmds", function() return getClientModule("InstancingCmds") ~= nil end },
		{ "DiamondMountainCmds root", function() return getDmRoot() ~= nil end },
		{ "DiamondMountainCmds.Instance()", function() return getDmInstance() ~= nil end },
		{ "EventUpgradeCmds", function() return getClientModule("EventUpgradeCmds") ~= nil end },
		{ "RankCmds", function() return getClientModule("RankCmds") ~= nil end },
		{ "Eggs.World folder", function() return getWorldEggsFolder() ~= nil end },
		{ "Eggs.World has eggs", function()
			local f = getWorldEggsFolder()
			return f ~= nil and #f:GetChildren() > 0
		end },
		{ "ZoneEggs.World folder", function() return getZoneEggsFolder() ~= nil end },
		{ "CustomEggs folder", function() return getCustomEggsFolder() ~= nil end },
		{ "Egg Opening Frontend", function() return getEggOpeningEnv() ~= nil end },
		{ "HoverboardInstance", function() return TimeTrial.getHoverboardInstance() ~= nil end },
		{ "Breakables", function()
			local things = workspace:FindFirstChild("__THINGS")
			return things ~= nil and things:FindFirstChild("Breakables") ~= nil
		end },
		{ "Orbs folder", function()
			local things = workspace:FindFirstChild("__THINGS")
			return things ~= nil and things:FindFirstChild("Orbs") ~= nil
		end },
		{ "AntiCheat msg hook", function() return AntiCheat.messageTarget ~= nil end },
		{ "AntiCheat fenv hook", function() return AntiCheat.getfenvOriginal ~= nil end },
		{ "Save.Inventory.Pet", function()
			local save = getSave()
			return save ~= nil and type(save.Inventory) == "table" and type(save.Inventory.Pet) == "table"
		end },
		{ "Pet has _uid field", function()
			local save = getSave()
			if not save or type(save.Inventory) ~= "table" or type(save.Inventory.Pet) ~= "table" then
				return false
			end
			for _, pet in pairs(save.Inventory.Pet) do
				if type(pet) == "table" and (pet._uid or pet.euid or pet.uid) then
					return true
				end
			end
			return false
		end },
	}

	print("=== VRT HUB FEATURE TEST ===")
	local passed, failed = 0, 0
	for _, test in ipairs(tests) do
		local ok, result = pcall(test[2])
		local good = ok and result == true
		if good then passed = passed + 1 else failed = failed + 1 end
		print(string.format("[%s] %s%s", good and "PASS" or "FAIL", test[1],
			(not ok) and (" (" .. tostring(result) .. ")") or ""))
	end
	print(string.format("=== %d passed / %d failed ===", passed, failed))
	VRTContext.notify("Diagnostics", passed .. " pass / " .. failed .. " fail (see console)", 8)
end)

button(miscTab, "Print DM Info", function()
	print("=== DIAMOND MOUNTAIN INFO ===")
	local root = getDmRoot()
	print("Root module:", root and "OK" or "MISSING")
	local instance = getDmInstance()
	print("Instance:", instance and "OK" or "NOT IN INSTANCE")
	print("Is inside DM:", DiamondMountain.isInside())
	local folder = DiamondMountain.getFolder()
	print("DM folder:", folder and folder:GetFullName() or "NOT FOUND")
	local stacks = buildPetStacks(100)
	local count = 0
	for _ in pairs(stacks) do count = count + 1 end
	print("Inventory pet stacks:", count)
	local yetiStacks = getYetiStacks()
	local yCount = 0
	for _ in pairs(yetiStacks) do yCount = yCount + 1 end
	print("Yeti loaded stacks:", yCount)
end)

button(miscTab, "Print Module Info", function()
	print("=== VRT HUB ===")
	print("Main:", VERSION)
	print("Session:", VRTContext.session)
	print("AC:", AntiCheat.VERSION, "installed=" .. tostring(AntiCheat.installed))
	print("AntiLag:", "enabled=" .. tostring(AntiLag.enabled))
	print("Instance:", tostring(Instancing.current() or "none"))
	print("Alive:", VRTContext.isAlive())
end)

-- Webhook.
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

-- Config.
miscTab:CreateSection("Config")
button(miscTab, "Save Config", function()
	saveConfig()
	VRTContext.notify("Config", "Saved", 3)
end)

button(miscTab, "Load Config", function()
	loadConfig()
	VRTContext.notify("Config", "Loaded (re-execute to apply)", 4)
end)

-- ══════════════════════════════════════════════════════════
--  BOOT
-- ══════════════════════════════════════════════════════════

VRTContext.log(string.format(
	"v%s | flags=%d | AC=%s | AntiLag=%s",
	VERSION, #FLAG_LIST,
	AntiCheat.installed and "ON" or "OFF",
	AntiLag.enabled and "ON" or "OFF"
))

VRTContext.notify("VRT HUB", "Loaded v" .. VERSION, 5)

sendWebhook({
	content = (VRTContext.settings.DiscordUserId and VRTContext.settings.DiscordUserId ~= "")
		and ("<@" .. VRTContext.settings.DiscordUserId .. ">") or nil,
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