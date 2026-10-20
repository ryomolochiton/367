-- =====================================================
-- VRT HUB — PET SIMULATOR 99 v1.5.0
-- Single file | DM embedded | Optimized (WorldPivot, consts, id4)
-- =====================================================

if getgenv().VRT_LOADED then
	if typeof(getgenv().VRT_Unload) == "function" then
		pcall(getgenv().VRT_Unload)
		task.wait(0.3)
	end
	getgenv().VRT_LOADED = nil
	getgenv().VRT_AntiAFK = nil
end
getgenv().VRT_LOADED = true

pcall(setthreadidentity, 4)

if not game:IsLoaded() then
	game.Loaded:Wait()
end

-- Services.
local playersService = game:GetService("Players")
local replicatedStorage = game:GetService("ReplicatedStorage")
local runService = game:GetService("RunService")
local userInputService = game:GetService("UserInputService")
local debrisService = game:GetService("Debris")
local httpService = game:GetService("HttpService")
local marketplaceService = game:GetService("MarketplaceService")
local tweenService = game:GetService("TweenService")

local localPlayer = playersService.LocalPlayer
local libraryFolder = replicatedStorage:WaitForChild("Library")
local clientFolder = libraryFolder:WaitForChild("Client")
local directoryFolder = libraryFolder:WaitForChild("Directory")
local networkFolder = replicatedStorage:WaitForChild("Network")
local directFolder = replicatedStorage:FindFirstChild("__DIRECTORY")

-- -----------------------------------------------------
-- ANTI-CHEAT BYPASS
-- -----------------------------------------------------
local AntiCheat = {}
AntiCheat.active = false
AntiCheat.originalKey = nil
AntiCheat.logBlocked = false
AntiCheat.blockedCount = 0
AntiCheat.lastBlocked = nil

local function reqCheck()
	local issues = {}

	local okInfo, info = pcall(debug.getinfo, request)
	if okInfo and info and info.what == "Lua" then
		table.insert(issues, "WHAT")
	end

	local okHook1, hooked1 = pcall(isfunctionhooked, request)
	if not okHook1 or not hooked1 then
		table.insert(issues, "FH1")
	end

	if typeof(getgenv().request) == "function" then
		local okHook2, hooked2 = pcall(isfunctionhooked, getgenv().request)
		if not okHook2 or not hooked2 then
			table.insert(issues, "FH2")
		end
	end

	return #issues == 0, issues
end

local function installBlunderBypass()
	local ok, blunderMessage = pcall(function()
		return require(replicatedStorage:WaitForChild("Blunder", 10):WaitForChild("BlunderMessage", 10))
	end)

	if not ok or typeof(blunderMessage) ~= "table" then
		return false
	end

	if AntiCheat.originalKey then
		return true
	end

	AntiCheat.originalKey = blunderMessage.key

	local hook = function(...)
		local args = { ... }
		local payload = args[1]

		if typeof(payload) ~= "table" then
			return AntiCheat.originalKey(...)
		end

		local message = payload.message
		local messageType = payload.messageType

		if message == "PING" or message == "Anti Cheat fetched error in console" then
			return AntiCheat.originalKey(...)
		end

		AntiCheat.blockedCount += 1
		AntiCheat.lastBlocked = {
			message = message,
			messageType = messageType,
			time = os.clock(),
		}

		if AntiCheat.logBlocked then
			warn("[VRT AC] Blocked:", tostring(messageType), tostring(message))
		end

		return
	end

	pcall(setstackhidden, hook, true)
	pcall(debug.setinfo, hook, "s", "[C]")
	pcall(debug.setinfo, hook, "n", "")

	pcall(setreadonly, blunderMessage, false)
	blunderMessage.key = hook
	pcall(setreadonly, blunderMessage, true)

	AntiCheat.active = true
	return true
end

installBlunderBypass()

-- -----------------------------------------------------
-- Modules.
-- -----------------------------------------------------
local function safeRequire(instance)
	if not instance or typeof(instance) ~= "Instance" then
		return nil
	end
	local ok, result = pcall(require, instance)
	return ok and result or nil
end

local Modules = {
	Network = safeRequire(clientFolder:FindFirstChild("Network")),
	Save = safeRequire(clientFolder:FindFirstChild("Save")),
	EggCmds = safeRequire(clientFolder:FindFirstChild("EggCmds")),
	DaycareCmds = safeRequire(clientFolder:FindFirstChild("DaycareCmds")),
	PetEquipCmds = safeRequire(clientFolder:FindFirstChild("PetEquipCmds")),
	UltimateCmds = safeRequire(clientFolder:FindFirstChild("UltimateCmds")),
	ZoneCmds = safeRequire(clientFolder:FindFirstChild("ZoneCmds")),
	MapCmds = safeRequire(clientFolder:FindFirstChild("MapCmds")),
	LootboxCmds = safeRequire(clientFolder:FindFirstChild("LootboxCmds")),
	FruitCmds = safeRequire(clientFolder:FindFirstChild("FruitCmds")),
	RankCmds = safeRequire(clientFolder:FindFirstChild("RankCmds")),
	FlexibleFlagCmds = safeRequire(clientFolder:FindFirstChild("FlexibleFlagCmds")),
	PlayerPet = safeRequire(clientFolder:FindFirstChild("PlayerPet")),
	Balancing = safeRequire(clientFolder:FindFirstChild("Balancing")),
	WorldsUtil = safeRequire(libraryFolder:FindFirstChild("Util") and libraryFolder.Util:FindFirstChild("WorldsUtil")),
	FlagUtil = safeRequire(libraryFolder:FindFirstChild("Util") and libraryFolder.Util:FindFirstChild("FlagUtil")),
	Ranks = safeRequire(directoryFolder:FindFirstChild("Ranks")),
	FreeGifts = safeRequire(directoryFolder:FindFirstChild("FreeGifts")),
	EggsDir = safeRequire(directoryFolder:FindFirstChild("Eggs")),
	Items = safeRequire(libraryFolder:FindFirstChild("Items")),
}

local network = Modules.Network

local function fire(name, ...)
	if not network or not network.Fire then
		return false
	end
	return pcall(network.Fire, name, ...)
end

local function invoke(name, ...)
	if not network or not network.Invoke then
		return false
	end
	return pcall(network.Invoke, name, ...)
end

local function unreliable(name, ...)
	if not network or not network.UnreliableFire then
		return false
	end
	return pcall(network.UnreliableFire, name, ...)
end

-- -----------------------------------------------------
-- Settings.
-- -----------------------------------------------------
local vrt = getgenv().VRT or {}
getgenv().VRT = vrt
vrt.Version = "1.5.0"
vrt.connections = {}
vrt.loops = {}

local settings = vrt.Settings or {}
vrt.Settings = settings

local defaults = {
	ClickAuraRadius = 75,
	FastFarmCooldown = 0.2,
	FastFarmHeartbeat = false,
	FastFarmLoop = false,
	CollectOrbs = false,
	ClickAura = false,
	ClickAuraViz = false,
	OpenEgg = false,
	HideEggAnim = false,
	EggNotification = true,
	InfinitePetSpeed = false,
	OptimizePets = false,
	Daycare = false,
	PetSlots = false,
	AutoEggSlots = false,
	Zones = false,
	Ultimate = false,
	FreeGifts = false,
	RankRewards = false,
	MailboxClaim = false,
	MailboxSendHuges = false,
	MailboxUsername = "",
	MailboxHugeMode = "New",
	Relics = false,
	SpinWheels = false,
	OpenChests = false,
	CombineKeysAll = false,
	CombineKeysOnce = false,
	OpenGifts = false,
	OpenLootboxes = false,
	ConsumeFruits = false,
	FarmTreehouse = false,
	AutoHatch = false,
	UpgradeFruits = false,
	UpgradeFruitsShiny = false,
	UpgradePotions = false,
	UpgradeEnchants = false,
	EmpowerEnchants = false,
	AutoRank = false,
	SelectedFlag = "Coins Flag",
	UseSelectedFlag = false,
	DMMaxCamp = 6,
	WebhookUrl = "https://discord.com/api/webhooks/1559513619719389205/7_BLXFReFLUPxroxdVlPeLKwK1t-n1DBc6LB9HKT7V1bRO4Qs1TVJ4ar6f1WItuR_nXQ",
	WebhookEnabled = true,
	SelectedWheels = { "All" },
	SelectedChests = { "All" },
	SelectedGifts = { "All" },
	SelectedLootboxes = { "All" },
	SelectedFruits = { "All" },
	SelectedFruitUpgrade = { "All" },
	SelectedEnchantRarity = { "All" },
	eggUnmappedWarned = {},
}

for key, value in pairs(defaults) do
	if settings[key] == nil then
		settings[key] = value
	end
end

if typeof(settings.eggUnmappedWarned) ~= "table" then
	settings.eggUnmappedWarned = {}
end

-- -----------------------------------------------------
-- CONFIG SAVE/LOAD
-- -----------------------------------------------------
local CONFIG_FOLDER = "VRT"
local CONFIG_PATH = "VRT/PS99_Config.json"

local PERSIST_KEYS = {
	"ClickAuraRadius", "FastFarmCooldown",
	"FastFarmHeartbeat", "FastFarmLoop", "CollectOrbs",
	"ClickAura", "ClickAuraViz",
	"OpenEgg", "HideEggAnim", "EggNotification",
	"InfinitePetSpeed", "OptimizePets",
	"Daycare", "PetSlots", "AutoEggSlots", "Zones", "Ultimate",
	"FreeGifts", "RankRewards",
	"MailboxClaim", "MailboxSendHuges", "MailboxUsername", "MailboxHugeMode",
	"Relics", "SpinWheels", "OpenChests",
	"CombineKeysAll", "CombineKeysOnce",
	"OpenGifts", "OpenLootboxes", "ConsumeFruits",
	"FarmTreehouse", "AutoHatch",
	"UpgradeFruits", "UpgradeFruitsShiny",
	"UpgradePotions", "UpgradeEnchants", "EmpowerEnchants",
	"AutoRank",
	"SelectedFlag", "UseSelectedFlag",
	"DMMaxCamp",
	"WebhookUrl", "WebhookEnabled",
}

local TABLE_KEYS = {
	"SelectedWheels", "SelectedChests", "SelectedGifts",
	"SelectedLootboxes", "SelectedFruits",
	"SelectedFruitUpgrade", "SelectedEnchantRarity",
}

local function saveConfig()
	pcall(function()
		if not isfolder(CONFIG_FOLDER) then
			makefolder(CONFIG_FOLDER)
		end

		local out = {}
		for _, key in ipairs(PERSIST_KEYS) do
			local value = settings[key]
			if value ~= nil then
				out[key] = value
			end
		end

		for _, key in ipairs(TABLE_KEYS) do
			local value = settings[key]
			if typeof(value) == "table" then
				out[key] = value
			end
		end

		writefile(CONFIG_PATH, httpService:JSONEncode(out))
	end)
end

local function loadConfig()
	if not isfile(CONFIG_PATH) then
		return
	end

	pcall(function()
		local decoded = httpService:JSONDecode(readfile(CONFIG_PATH))
		if typeof(decoded) ~= "table" then
			return
		end

		for key, value in pairs(decoded) do
			if defaults[key] ~= nil then
				settings[key] = value
			end
		end
	end)
end

loadConfig()

local saveQueued = false

local function queueSave()
	if saveQueued then
		return
	end
	saveQueued = true
	task.delay(1, function()
		saveQueued = false
		saveConfig()
	end)
end

getgenv().VRT_SaveConfig = saveConfig
getgenv().VRT_LoadConfig = loadConfig

-- -----------------------------------------------------
-- STATIC DATA + PRECOMPUTED CONSTANTS
-- -----------------------------------------------------
local FLAGS = {
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

local OPTIMIZE_SIZE = Vector3.new(2.5, 2.5, 2.5)
local OPTIMIZE_MATERIAL = Enum.Material.SmoothPlastic
local VIZ_ROTATION = CFrame.Angles(0, 0, math.rad(90))
local VIZ_SIZE_TEMPLATE = Vector3.new(0.2, 1, 1)
local TREEHOUSE_ID = "TreehouseMerchant"
local TREEHOUSE_ROOM = "Treehouse Merchant"

-- -----------------------------------------------------
-- SAVE CACHE + INVENTORY INDEX
-- -----------------------------------------------------
local SKIP_BUCKETS = {
	Pet = true,
}

local SaveCache = {
	data = nil,
	timestamp = 0,
	ttl = 2,
}

local InventoryIndex = {
	byId = {},
	bucketIds = {},
	timestamp = 0,
	ttl = 5,
	dirty = true,
}

local function getSaveCached()
	local now = os.clock()
	if SaveCache.data and (now - SaveCache.timestamp) < SaveCache.ttl then
		return SaveCache.data
	end
	if not Modules.Save or not Modules.Save.Get then
		return nil
	end
	local ok, save = pcall(Modules.Save.Get)
	if ok and typeof(save) == "table" and next(save) then
		SaveCache.data = save
		SaveCache.timestamp = now
		return save
	end
	return SaveCache.data
end

local function invalidateSaveCache()
	SaveCache.data = nil
	SaveCache.timestamp = 0
	InventoryIndex.dirty = true
end

getgenv().VRT_InvalidateCache = invalidateSaveCache

local function buildInventoryIndex()
	local now = os.clock()
	if not InventoryIndex.dirty and (now - InventoryIndex.timestamp) < InventoryIndex.ttl then
		return InventoryIndex
	end

	local save = getSaveCached()
	if not save or typeof(save.Inventory) ~= "table" then
		return InventoryIndex
	end

	local byId = {}
	local bucketIds = {}

	for bucketName, bucket in pairs(save.Inventory) do
		if not SKIP_BUCKETS[bucketName] and typeof(bucket) == "table" then
			local ids, seen = {}, {}
			for _, entry in pairs(bucket) do
				if typeof(entry) == "table" and typeof(entry.id) == "string" then
					byId[entry.id] = entry
					if not seen[entry.id] then
						seen[entry.id] = true
						table.insert(ids, entry.id)
					end
				end
			end
			table.sort(ids)
			bucketIds[bucketName] = ids
		end
	end

	InventoryIndex.byId = byId
	InventoryIndex.bucketIds = bucketIds
	InventoryIndex.timestamp = now
	InventoryIndex.dirty = false
	return InventoryIndex
end

local function findInventoryEntry(itemId)
	if not itemId or itemId == "" then
		return nil
	end
	local index = buildInventoryIndex()
	return index.byId[itemId]
end

local function getBucketIds(bucketName)
	local index = buildInventoryIndex()
	return index.bucketIds[bucketName] or {}
end

-- -----------------------------------------------------
-- DIRECTORY CACHE
-- -----------------------------------------------------
local DirectoryCache = {}

local function getDirectoryIds(folderName)
	local cached = DirectoryCache[folderName]
	if cached then
		return cached
	end
	local ids = {}
	local folder = directFolder and directFolder:FindFirstChild(folderName)
	if folder then
		for _, child in ipairs(folder:GetChildren()) do
			local id
			local ok, data = pcall(require, child)
			if ok and typeof(data) == "table" and data._id then
				id = data._id
			else
				local parts = string.split(child.Name, " | ")
				id = parts[2] or child.Name
			end
			if id and id ~= "" then
				table.insert(ids, id)
			end
		end
		table.sort(ids)
	end
	DirectoryCache[folderName] = ids
	return ids
end

local function clearDirectoryCache()
	DirectoryCache = {}
end

-- -----------------------------------------------------
-- EGG ID CACHE
-- -----------------------------------------------------
local eggNumberCache = nil

local function getEggIdByNumber(eggNumber)
	if not eggNumberCache then
		eggNumberCache = {}
		for _, egg in pairs(Modules.EggsDir or {}) do
			if typeof(egg) == "table" and egg._id and egg.eggNumber then
				eggNumberCache[egg.eggNumber] = egg._id
			end
		end
	end
	return eggNumberCache[eggNumber]
end

-- -----------------------------------------------------
-- MAX HATCH CACHE
-- -----------------------------------------------------
local maxHatchCache = {
	value = 1,
	timestamp = 0,
	ttl = 5,
}

local function getMaxHatch()
	local now = os.clock()
	if (now - maxHatchCache.timestamp) < maxHatchCache.ttl then
		return maxHatchCache.value
	end
	if Modules.EggCmds and Modules.EggCmds.GetMaxHatch then
		local ok, value = pcall(Modules.EggCmds.GetMaxHatch)
		if ok and typeof(value) == "number" and value > 0 then
			maxHatchCache.value = value
		end
	end
	maxHatchCache.timestamp = now
	return maxHatchCache.value
end

-- -----------------------------------------------------
-- ZONE CACHE
-- -----------------------------------------------------
local ZoneCache = {
	data = nil,
	timestamp = 0,
	ttl = 1,
}

local function getCurrentZone()
	local now = os.clock()
	if ZoneCache.timestamp > 0 and (now - ZoneCache.timestamp) < ZoneCache.ttl then
		return ZoneCache.data
	end
	if Modules.MapCmds and Modules.MapCmds.GetCurrentZone then
		local ok, zone = pcall(Modules.MapCmds.GetCurrentZone)
		if ok then
			ZoneCache.data = zone
			ZoneCache.timestamp = now
			return zone
		end
	end
	return nil
end

-- -----------------------------------------------------
-- Webhook.
-- -----------------------------------------------------
local function sendWebhook(url, payload)
	if not url or url == "" then
		return false
	end

	local clean, issues = reqCheck()
	if not clean then
		warn("[VRT] Webhook bị skip, request có vấn đề:", table.concat(issues, ","))
		return false
	end

	local ok, body = pcall(httpService.JSONEncode, httpService, payload)
	if not ok then
		return false
	end

	return pcall(function()
		request({
			Url = url,
			Method = "POST",
			Headers = { ["Content-Type"] = "application/json" },
			Body = body,
		})
	end)
end

local function sendExecutionWebhook()
	if not settings.WebhookEnabled or settings.WebhookUrl == "" then
		return
	end

	local executorName, executorVersion = "Unknown", ""
	pcall(function()
		local a, b = identifyexecutor()
		executorName = a or "Unknown"
		executorVersion = b or ""
	end)

	local gameName = "Unknown"
	pcall(function()
		gameName = marketplaceService:GetProductInfo(game.PlaceId, Enum.InfoType.Asset).Name
	end)

	sendWebhook(settings.WebhookUrl, {
		embeds = {
			{
				title = "VRT PS99 — Script Executed",
				color = 3447003,
				fields = {
					{ name = "Player", value = localPlayer.Name, inline = true },
					{ name = "Display Name", value = localPlayer.DisplayName, inline = true },
					{ name = "User ID", value = tostring(localPlayer.UserId), inline = true },
					{ name = "Account Age", value = tostring(localPlayer.AccountAge) .. " days", inline = true },
					{ name = "Place ID", value = tostring(game.PlaceId), inline = true },
					{ name = "Game Name", value = gameName, inline = false },
					{ name = "Execution Time", value = os.date("%c"), inline = false },
					{ name = "Executor", value = (tostring(executorName) .. " " .. tostring(executorVersion)):gsub("%s+$", ""), inline = true },
					{ name = "Script Version", value = vrt.Version, inline = true },
					{ name = "AC Bypass", value = AntiCheat.active and "active" or "inactive", inline = true },
				},
				footer = { text = "VRT PS99 — v" .. vrt.Version },
			},
		},
	})
end

-- -----------------------------------------------------
-- Egg notification overlay.
-- -----------------------------------------------------
local notifyGui = Instance.new("ScreenGui")
notifyGui.Name = "VRT_EggNotify"
notifyGui.ResetOnSpawn = false
notifyGui.IgnoreGuiInset = true
notifyGui.DisplayOrder = 999

do
	local parent
	pcall(function()
		parent = gethui()
	end)
	if not parent then
		local ok, cg = pcall(game.GetService, game, "CoreGui")
		parent = ok and cg or nil
	end
	if not parent then
		parent = localPlayer:WaitForChild("PlayerGui")
	end
	notifyGui.Parent = parent
end

local activeNotifs = {}

local COLOR_PALETTE = {
	Color3.fromRGB(255, 255, 0),
	Color3.fromRGB(255, 200, 0),
	Color3.fromRGB(255, 140, 0),
	Color3.fromRGB(255, 80, 80),
	Color3.fromRGB(255, 20, 100),
	Color3.fromRGB(255, 100, 200),
	Color3.fromRGB(200, 100, 255),
	Color3.fromRGB(150, 80, 255),
	Color3.fromRGB(100, 150, 255),
	Color3.fromRGB(50, 180, 255),
	Color3.fromRGB(0, 220, 255),
	Color3.fromRGB(0, 255, 200),
	Color3.fromRGB(0, 255, 130),
	Color3.fromRGB(80, 255, 80),
	Color3.fromRGB(180, 255, 50),
	Color3.fromRGB(255, 230, 100),
	Color3.fromRGB(255, 150, 200),
	Color3.fromRGB(180, 220, 255),
	Color3.fromRGB(220, 180, 255),
	Color3.fromRGB(255, 255, 255),
}

local lastColorIndex = 0

local function pickNextColor()
	local index
	local attempts = 0
	repeat
		index = math.random(1, #COLOR_PALETTE)
		attempts += 1
	until index ~= lastColorIndex or attempts > 5
	lastColorIndex = index
	return COLOR_PALETTE[index]
end

local function showEggNotification(eggName, maxHatch)
	while #activeNotifs >= 3 do
		local oldest = table.remove(activeNotifs, 1)
		if oldest and oldest.Parent then
			oldest:Destroy()
		end
	end

	local text = ("Still Openin %s %d"):format(tostring(eggName), maxHatch)
	local color = pickNextColor()

	local label = Instance.new("TextLabel")
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.Size = UDim2.new(0, 700, 0, 36)
	label.Position = UDim2.new(0.5, 0, 0.66, 0)
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextSize = 24
	label.Font = Enum.Font.GothamBlack
	label.TextColor3 = color
	label.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	label.TextStrokeTransparency = 1
	label.TextTransparency = 1
	label.ZIndex = 10
	label.Parent = notifyGui

	table.insert(activeNotifs, label)

	tweenService:Create(label, TweenInfo.new(0.15, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		TextTransparency = 0,
		TextStrokeTransparency = 0.4,
	}):Play()

	task.delay(2, function()
		if not label.Parent then
			return
		end
		local fadeOut = tweenService:Create(label, TweenInfo.new(0.4), {
			TextTransparency = 1,
			TextStrokeTransparency = 1,
		})
		fadeOut:Play()
		fadeOut.Completed:Connect(function()
			for i, n in ipairs(activeNotifs) do
				if n == label then
					table.remove(activeNotifs, i)
					break
				end
			end
			label:Destroy()
		end)
	end)
end

-- -----------------------------------------------------
-- Hide Egg Anim
-- -----------------------------------------------------
local hideEggAnimUntil = 0

local function requestHideEggAnim()
	hideEggAnimUntil = os.clock() + 8
end

task.spawn(function()
	while getgenv().VRT_LOADED do
		if settings.HideEggAnim and hideEggAnimUntil > os.clock() then
			local playerGui = localPlayer:FindFirstChild("PlayerGui")
			if playerGui then
				for _, gui in ipairs(playerGui:GetChildren()) do
					if gui:IsA("ScreenGui") and gui.Enabled and gui.Name ~= "VRT_EggNotify" then
						if gui.Name:find("Egg") or gui.Name:find("Hatch") or gui.Name:find("Open") then
							gui.Enabled = false
						end
					end
				end
			end
		end
		task.wait(0.1)
	end
end)

-- -----------------------------------------------------
-- Egg animation hook.
-- -----------------------------------------------------
local eggFrontend
do
	local ok, env = pcall(function()
		return getsenv(localPlayer.PlayerScripts.Scripts.Game["Egg Opening Frontend"])
	end)
	if ok then
		eggFrontend = env
	end
end

if eggFrontend and typeof(eggFrontend.PlayEggAnimation) == "function" then
	if getgenv().VRT_ORIGINAL_PLAY_EGG then
		pcall(function()
			eggFrontend.PlayEggAnimation = getgenv().VRT_ORIGINAL_PLAY_EGG
		end)
	end

	getgenv().VRT_ORIGINAL_PLAY_EGG = eggFrontend.PlayEggAnimation
	vrt.originalPlayEgg = eggFrontend.PlayEggAnimation

	local eggHook = function(eggName, ...)
		if settings.EggNotification then
			pcall(showEggNotification, eggName, getMaxHatch())
		end

		if settings.HideEggAnim then
			requestHideEggAnim()
		end

		local ok, result = pcall(vrt.originalPlayEgg, eggName, ...)
		if ok then
			return result
		end
		return
	end

	pcall(setstackhidden, eggHook, true)
	eggFrontend.PlayEggAnimation = eggHook
end

-- -----------------------------------------------------
-- Helpers.
-- -----------------------------------------------------
local function getRoot()
	local character = localPlayer.Character
	return character and character:FindFirstChild("HumanoidRootPart") or nil
end

local function getBreakableFolder()
	local things = workspace:FindFirstChild("__THINGS")
	return things and things:FindFirstChild("Breakables") or nil
end

-- -----------------------------------------------------
-- PET UID CACHE
-- -----------------------------------------------------
local PetsCache = {
	data = nil,
	timestamp = 0,
	ttl = 1,
}

local function getOwnedPetUids()
	local now = os.clock()
	if PetsCache.data and (now - PetsCache.timestamp) < PetsCache.ttl then
		return PetsCache.data
	end
	local uids = {}
	if Modules.PlayerPet and Modules.PlayerPet.GetAll then
		local ok, pets = pcall(Modules.PlayerPet.GetAll)
		if ok and typeof(pets) == "table" then
			for _, pet in pairs(pets) do
				if typeof(pet) == "table" and pet.owner == localPlayer then
					local uid = pet.euid or pet.uid
					if uid then
						table.insert(uids, uid)
					end
				end
			end
		end
	end
	PetsCache.data = uids
	PetsCache.timestamp = now
	return uids
end

-- -----------------------------------------------------
-- BREAKABLE POSITIONS (WorldPivot + weak cache)
-- -----------------------------------------------------
local BreakablePositions = {
	data = nil,
	timestamp = 0,
	ttl = 2,
}

local breakablePositionCache = setmetatable({}, { __mode = "k" })

local function getBreakablePositions()
	local now = os.clock()
	if BreakablePositions.data and (now - BreakablePositions.timestamp) < BreakablePositions.ttl then
		return BreakablePositions.data
	end
	local folder = getBreakableFolder()
	if not folder then
		return {}
	end
	local list = {}
	for _, model in ipairs(folder:GetChildren()) do
		if model:IsA("Model") then
			local cached = breakablePositionCache[model]
			if not cached then
				local ok, pivot = pcall(function() return model.WorldPivot end)
				if ok and pivot then
					cached = {
						position = pivot.Position,
						parentId = model:GetAttribute("ParentID"),
					}
					breakablePositionCache[model] = cached
				end
			end
			if cached then
				table.insert(list, {
					name = model.Name,
					position = cached.position,
					parentId = cached.parentId,
				})
			end
		end
	end
	BreakablePositions.data = list
	BreakablePositions.timestamp = now
	return list
end

-- -----------------------------------------------------
-- EGG POSITIONS (WorldPivot + weak cache)
-- -----------------------------------------------------
local EggPositions = {
	data = nil,
	timestamp = 0,
	ttl = 2,
}

local eggPositionCache = setmetatable({}, { __mode = "k" })

local function getEggPositions()
	local now = os.clock()
	if EggPositions.data and (now - EggPositions.timestamp) < EggPositions.ttl then
		return EggPositions.data
	end
	local things = workspace:FindFirstChild("__THINGS")
	if not things then
		return {}
	end
	local worldName
	if Modules.WorldsUtil and Modules.WorldsUtil.GetEggsModelName then
		local ok, name = pcall(Modules.WorldsUtil.GetEggsModelName)
		worldName = ok and name or nil
	end
	if not worldName then
		return {}
	end
	local list = {}
	local function scanContainer(container)
		if not container then
			return
		end
		for _, model in ipairs(container:GetChildren()) do
			if model:IsA("Model") then
				local cached = eggPositionCache[model]
				if not cached then
					local eggNumber = tonumber(model.Name:match("^(%d+)"))
					if eggNumber and getEggIdByNumber(eggNumber) then
						local light = model:FindFirstChild("Light")
						local position
						if light then
							position = light.CFrame.Position
						else
							local ok, pivot = pcall(function() return model.WorldPivot end)
							position = ok and pivot.Position or nil
						end
						if position then
							cached = { eggNumber = eggNumber, position = position }
							eggPositionCache[model] = cached
						end
					end
				end
				if cached then
					table.insert(list, cached)
				end
			end
		end
	end
	local zoneEggs = things:FindFirstChild("ZoneEggs")
	if zoneEggs and zoneEggs:FindFirstChild(worldName) then
		scanContainer(zoneEggs[worldName])
	end
	local eggs = things:FindFirstChild("Eggs")
	if eggs and eggs:FindFirstChild(worldName) then
		scanContainer(eggs[worldName])
	end
	EggPositions.data = list
	EggPositions.timestamp = now
	return list
end

-- -----------------------------------------------------
-- Dropdown memoize
-- -----------------------------------------------------
local DerivedCache = {}
local DERIVED_TTL = 5

local function memoize(key, fn)
	local entry = DerivedCache[key]
	local now = os.clock()
	if entry and (now - entry.timestamp) < DERIVED_TTL then
		return entry.value
	end
	local value = fn()
	DerivedCache[key] = { value = value, timestamp = now }
	return value
end

local function clearDerivedCache()
	DerivedCache = {}
end

local function getChestNames()
	return memoize("chests", function()
		local names, seen = {}, {}
		local miscIds = getBucketIds("Misc")
		for _, id in ipairs(miscIds) do
			local base = id:match("^(.+) Lower Half$")
			if base then
				local chestName = base:gsub("%s*Key$", "") .. " Chest"
				if not seen[chestName] then
					seen[chestName] = true
					table.insert(names, chestName)
				end
			end
		end
		table.sort(names)
		return names
	end)
end

local function getGiftIds()
	return memoize("gifts", function()
		local gifts = {}
		for _, id in ipairs(getBucketIds("Misc")) do
			if id:find("Gift") then
				table.insert(gifts, id)
			end
		end
		return gifts
	end)
end

local function getLootboxIds()
	return memoize("lootboxes", function()
		local list = getBucketIds("Lootbox")
		if #list == 0 then
			list = getDirectoryIds("Lootboxes")
		end
		return list
	end)
end

local function getEnchantRarities()
	return memoize("rarities", function()
		local rarities, seen = {}, {}
		local save = getSaveCached()
		if not save or typeof(save.Inventory) ~= "table" or not save.Inventory.Enchant then
			return rarities
		end
		for _, entry in pairs(save.Inventory.Enchant) do
			if typeof(entry) == "table" then
				local rarity = tostring(entry.rn or entry.rarity or "Unknown")
				if not seen[rarity] then
					seen[rarity] = true
					table.insert(rarities, rarity)
				end
			end
		end
		table.sort(rarities)
		return rarities
	end)
end

local function resolveSelection(selected, allOptions)
	if typeof(selected) ~= "table" or #selected == 0 then
		return allOptions
	end
	if table.find(selected, "All") then
		return allOptions
	end
	return selected
end

local function buildOptions(list)
	local options = { "All" }
	for _, name in ipairs(list) do
		if not table.find(options, name) then
			table.insert(options, name)
		end
	end
	return options
end

local function generateRandomString(length)
	local chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789"
	local out = {}
	for _ = 1, length do
		local index = math.random(1, #chars)
		table.insert(out, chars:sub(index, index))
	end
	return table.concat(out)
end

-- -----------------------------------------------------
-- Anti-AFK.
-- -----------------------------------------------------
task.spawn(function()
	if getgenv().VRT_AntiAFK then
		return
	end
	getgenv().VRT_AntiAFK = true

	local function kill(signal)
		local ok, conns = pcall(getconnections, signal)
		if not ok or typeof(conns) ~= "table" then
			return
		end
		for _, connection in pairs(conns) do
			pcall(function()
				if connection.Disable then
					connection:Disable()
				elseif connection.Disconnect then
					connection:Disconnect()
				end
			end)
		end
	end

	kill(localPlayer.Idled)
	kill(userInputService.WindowFocusReleased)
	kill(userInputService.WindowFocused)

	task.spawn(function()
		local scripts = localPlayer:WaitForChild("PlayerScripts", 10)
		local scriptsFolder = scripts and scripts:WaitForChild("Scripts", 10)
		local coreFolder = scriptsFolder and scriptsFolder:WaitForChild("Core", 10)
		local idleScript = coreFolder and coreFolder:WaitForChild("Idle Tracking", 10)
		if idleScript then
			pcall(function()
				idleScript.Enabled = false
			end)
		end
	end)

	fire("Idle Tracking: Stop Timer")

	local ok, virtualUser = pcall(game.GetService, game, "VirtualUser")
	if not ok then
		return
	end

	while getgenv().VRT_LOADED do
		pcall(function()
			virtualUser:Button2Up(Vector2.new(0, 0))
		end)
		fire("Idle Tracking: Update Timer", 10)
		fire("Idle Tracking: Stop Timer")
		task.wait(280 + math.random() * 40)
	end
end)

-- -----------------------------------------------------
-- Core.
-- -----------------------------------------------------
local Core = {}

-- Reusable buffers (avoid table allocation each tick)
local closestBuffer = {}
local petDataBuffer = {}

Core.FastFarm = function()
	local root = getRoot()
	if not root then
		return
	end
	local rootPos = root.Position
	local zone = getCurrentZone()
	local breakables = getBreakablePositions()

	table.clear(closestBuffer)
	for _, item in ipairs(breakables) do
		if item.parentId == nil or item.parentId == zone then
			if (item.position - rootPos).Magnitude < 85 then
				table.insert(closestBuffer, item.name)
			end
		end
	end
	local breakableCount = #closestBuffer
	if breakableCount == 0 then
		return
	end

	local uids = getOwnedPetUids()
	if #uids == 0 then
		return
	end

	table.clear(petDataBuffer)
	for _, uid in ipairs(uids) do
		petDataBuffer[uid] = closestBuffer[math.random(1, breakableCount)]
	end

	fire("Breakables_JoinPetBulk", petDataBuffer)
end

Core.CollectOrbs = function()
	local things = workspace:FindFirstChild("__THINGS")
	local orbs = things and things:FindFirstChild("Orbs")
	if not orbs then
		return
	end
	for _, orb in ipairs(orbs:GetChildren()) do
		local orbId = tonumber(orb.Name)
		if orbId then
			fire("Orbs: Collect", { [1] = orbId })
			orb:Destroy()
		end
	end
end

Core.ClickAura = function()
	local root = getRoot()
	if not root then
		return
	end
	local rootPos = root.Position
	local radius = settings.ClickAuraRadius
	local breakables = getBreakablePositions()
	for _, item in ipairs(breakables) do
		if (item.position - rootPos).Magnitude <= radius then
			unreliable("Breakables_PlayerDealDamage", item.name)
		end
	end
end

Core.ClickAuraViz = function()
	local root = getRoot()
	if not root then
		return
	end
	local viz = workspace:FindFirstChild("M")
	if not settings.ClickAuraViz then
		if viz then
			viz:Destroy()
		end
		return
	end
	if not viz then
		viz = Instance.new("Part")
		viz.Name = "M"
		viz.Anchored = true
		viz.CanCollide = false
		viz.CanQuery = false
		viz.CanTouch = false
		viz.Shape = Enum.PartType.Cylinder
		viz.Material = Enum.Material.Neon
		viz.BrickColor = BrickColor.new("Light green (Mint)")
		viz.Transparency = 0.5
		viz.Parent = workspace
	end
	local radius = settings.ClickAuraRadius
	viz.Size = Vector3.new(0.2, radius * 2, radius * 2)
	viz.CFrame = CFrame.new(root.Position) * VIZ_ROTATION
end

Core.OpenEgg = function()
	local root = getRoot()
	if not root then
		return
	end
	local rootPos = root.Position
	local eggs = getEggPositions()
	if #eggs == 0 then
		return
	end
	local closest, closestDistance = nil, math.huge
	for _, egg in ipairs(eggs) do
		local distance = (egg.position - rootPos).Magnitude
		if distance < closestDistance then
			closest, closestDistance = egg, distance
		end
	end
	if not closest then
		return
	end
	local eggId = getEggIdByNumber(closest.eggNumber)
	if not eggId then
		if not settings.eggUnmappedWarned[closest.eggNumber] then
			settings.eggUnmappedWarned[closest.eggNumber] = true
			warn(("[VRT] Egg %d không có trong Directory.Eggs"):format(closest.eggNumber))
		end
		return
	end
	invoke("Eggs_RequestPurchase", eggId, getMaxHatch())
end

Core.InfinitePetSpeed = function(enabled)
	if not Modules.PlayerPet or not Modules.PlayerPet.CalculateSpeedMultiplier then
		return
	end
	if enabled then
		vrt.originalPetSpeed = vrt.originalPetSpeed or Modules.PlayerPet.CalculateSpeedMultiplier
		Modules.PlayerPet.CalculateSpeedMultiplier = function()
			return math.huge
		end
	elseif vrt.originalPetSpeed then
		Modules.PlayerPet.CalculateSpeedMultiplier = vrt.originalPetSpeed
	end
end

local optimizedPets = setmetatable({}, { __mode = "k" })

Core.OptimizePets = function()
	local things = workspace:FindFirstChild("__THINGS")
	local petsFolder = things and things:FindFirstChild("Pets")
	if not petsFolder then
		return
	end
	for _, pet in ipairs(petsFolder:GetChildren()) do
		if not optimizedPets[pet] then
			optimizedPets[pet] = true
			for _, descendant in ipairs(pet:GetDescendants()) do
				if descendant:IsA("Part") then
					descendant.Material = OPTIMIZE_MATERIAL
					descendant.Size = OPTIMIZE_SIZE
				elseif descendant:IsA("SpecialMesh")
					or descendant:IsA("ParticleEmitter")
					or descendant:IsA("MeshPart")
					or descendant:IsA("Decal")
				then
					descendant:Destroy()
				end
			end
		end
	end
end

Core.OptimizeBreakables = function()
	if vrt.optimizeConnection then
		return
	end
	local debrisFolder = workspace:FindFirstChild("__DEBRIS")
	if not debrisFolder then
		return
	end
	vrt.optimizeConnection = debrisFolder.ChildAdded:Connect(function(child)
		pcall(function()
			debrisService:AddItem(child, 0)
		end)
	end)
end

Core.Daycare = function()
	local daycare = Modules.DaycareCmds
	if not daycare or not daycare.GetMaxSlots or not daycare.GetUsedSlots then
		return
	end
	local okMax, maxSlots = pcall(daycare.GetMaxSlots)
	local okUsed, usedSlots = pcall(daycare.GetUsedSlots)
	if not okMax or not okUsed or not maxSlots or not usedSlots or usedSlots >= maxSlots then
		return
	end
	local save = getSaveCached()
	if not save or typeof(save.Inventory) ~= "table" or not save.Inventory.Pet then
		return
	end
	local sorted = {}
	local count = 0
	for uid, petEntry in pairs(save.Inventory.Pet) do
		count += 1
		if count % 100 == 0 then
			task.wait()
		end
		if typeof(petEntry) == "table" then
			local power = 0
			if Modules.Items and Modules.Items.Pet and Modules.Items.Pet.From then
				local ok, instance = pcall(Modules.Items.Pet.From, Modules.Items.Pet, petEntry)
				if ok and instance and instance.CalculatePower then
					local okPower, value = pcall(instance.CalculatePower, instance)
					power = (okPower and value) or 0
				end
			end
			table.insert(sorted, { uid = uid, power = power })
		end
	end
	table.sort(sorted, function(a, b)
		return a.power > b.power
	end)
	local enroll = {}
	for index = 1, math.min(maxSlots - usedSlots, #sorted) do
		enroll[sorted[index].uid] = 1
	end
	if not next(enroll) then
		return
	end
	if daycare.Enroll then
		pcall(daycare.Enroll, enroll)
	else
		invoke("Daycare: Enroll", enroll)
	end
end

Core.BuyPetSlots = function()
	local save = getSaveCached()
	if not save or not Modules.PetEquipCmds or not Modules.PetEquipCmds.GetStatus then
		return
	end
	local purchased = save.PetSlotsPurchased or 0
	local ok, status = pcall(Modules.PetEquipCmds.GetStatus, purchased + 1)
	if ok and status == "NEXT" then
		invoke("EquipSlotsMachine_RequestPurchase", purchased + 1)
	end
end

local eggBundleCache = nil

Core.BuyEggSlots = function()
	local save = getSaveCached()
	if not save then
		return
	end
	local rankCmds = Modules.RankCmds
	if not rankCmds or not rankCmds.GetEggBundle then
		return
	end
	local purchased = save.EggSlotsPurchased or 0

	if not eggBundleCache then
		eggBundleCache = {}
		for index = 1, 200 do
			local okA, bundleEnd, bundleSize, prevEnd = pcall(function()
				return rankCmds.GetEggBundle(index)
			end)
			if not okA or not bundleEnd then
				break
			end
			table.insert(eggBundleCache, { bundleEnd = bundleEnd, prevEnd = prevEnd })
			if bundleEnd > 1000 then
				break
			end
		end
	end

	for _, bundle in ipairs(eggBundleCache) do
		if bundle.prevEnd == purchased then
			invoke("EggHatchSlotsMachine_RequestPurchase", bundle.bundleEnd)
			return
		end
	end
end

Core.GetFlagMaxAmount = function(flagId)
	if not flagId or flagId == "" then
		return 0
	end
	local entry = findInventoryEntry(flagId)
	local owned = entry and (entry._am or 0) or 0
	if owned <= 0 then
		return 0
	end
	local gameMax = 45
	local flagUtil = Modules.FlagUtil
	if flagUtil and flagUtil.computeMaxFlags then
		local ok, maxFlags = pcall(flagUtil.computeMaxFlags)
		if ok and typeof(maxFlags) == "number" and maxFlags > 0 then
			gameMax = maxFlags
		end
	end
	return math.min(owned, gameMax)
end

Core.ActivateFlag = function()
	local flagId = settings.SelectedFlag
	if not flagId or flagId == "" then
		return
	end
	local flagCmds = Modules.FlexibleFlagCmds
	if flagCmds and flagCmds.GetActiveFlag then
		local ok, active = pcall(flagCmds.GetActiveFlag)
		if ok and active then
			return
		end
	end
	local amount = Core.GetFlagMaxAmount(flagId)
	if amount <= 0 then
		if not vrt.flagWarned then
			vrt.flagWarned = {}
		end
		if not vrt.flagWarned[flagId] then
			vrt.flagWarned[flagId] = true
			warn(("[VRT] Không có %s trong inventory"):format(flagId))
		end
		return
	end
	local instanceId, areaId
	if Modules.MapCmds and Modules.MapCmds.GetCurrentInstanceInfo then
		local ok, info = pcall(Modules.MapCmds.GetCurrentInstanceInfo)
		if ok and typeof(info) == "table" then
			instanceId = info.InstanceId
			areaId = info.AreaId
		end
	end
	if not vrt.flagDebug then
		vrt.flagDebug = {}
	end
	if not vrt.flagDebug[flagId] then
		vrt.flagDebug[flagId] = true
		print(("[VRT] Use flag: %s | amount=%d (MAX)"):format(flagId, amount))
	end
	if flagCmds and flagCmds.Consume then
		local ok = pcall(flagCmds.Consume, flagId, amount)
		if ok then
			invalidateSaveCache()
			return
		end
	end
	if instanceId and areaId then
		local ok = invoke("FlexibleFlags_Consume", flagId, amount)
		if ok then
			invalidateSaveCache()
			return
		end
	end
	invoke("Flags: Consume", flagId, amount)
	invalidateSaveCache()
end

Core.BuyZone = function()
	if Modules.ZoneCmds and Modules.ZoneCmds.GetNextZone then
		local ok, nextZone = pcall(Modules.ZoneCmds.GetNextZone)
		if ok and typeof(nextZone) == "table" and nextZone.ZoneNumber then
			invoke("Zones_RequestPurchase", nextZone.ZoneNumber)
			return
		end
	end
	local save = getSaveCached()
	if not save or typeof(save.UnlockedZones) ~= "table" then
		return
	end
	local highest = 1
	for _, zone in pairs(save.UnlockedZones) do
		if typeof(zone) == "table" and zone.ZoneNumber and zone.ZoneNumber > highest then
			highest = zone.ZoneNumber
		end
	end
	invoke("Zones_RequestPurchase", highest + 1)
end

Core.UseUltimate = function()
	local ultimate = Modules.UltimateCmds
	if not ultimate or not ultimate.GetEquippedItem then
		return
	end
	local ok, equipped = pcall(ultimate.GetEquippedItem)
	if not ok or typeof(equipped) ~= "table" or not equipped._data then
		return
	end
	local itemId = equipped._data.id
	if ultimate.IsCharged then
		local okCharged, charged = pcall(ultimate.IsCharged, itemId)
		if not okCharged or not charged then
			return
		end
	end
	if ultimate.Activate then
		pcall(ultimate.Activate, itemId)
	else
		invoke("Ultimates: Activate", itemId)
	end
end

Core.ClaimFreeGifts = function()
	local save = getSaveCached()
	if not save or typeof(Modules.FreeGifts) ~= "table" then
		return
	end
	local redeemed = save.FreeGiftsRedeemed or {}
	for _, gift in pairs(Modules.FreeGifts) do
		if typeof(gift) == "table" and gift._id and not table.find(redeemed, gift._id) then
			invoke("Redeem Free Gift", gift._id)
			task.wait(1)
		end
	end
end

Core.ClaimRankRewards = function()
	local save = getSaveCached()
	if not save or typeof(Modules.Ranks) ~= "table" then
		return
	end
	local directory
	for _, rank in pairs(Modules.Ranks) do
		if typeof(rank) == "table" and rank.RankNumber == save.Rank then
			directory = rank
			break
		end
	end
	if not directory or typeof(directory.Rewards) ~= "table" then
		return
	end
	local stars = save.RankStars or 0
	local redeemed = save.RedeemedRankRewards or {}
	for rewardId, reward in pairs(directory.Rewards) do
		if typeof(reward) == "table" and reward.StarsRequired and reward.StarsRequired <= stars then
			if not redeemed[tostring(rewardId)] then
				fire("Ranks_ClaimReward", rewardId)
				task.wait(1)
			end
		end
	end
end

Core.MailboxClaimAll = function()
	invoke("Mailbox: Claim All")
end

Core.MailboxSendHuges = function()
	if settings.MailboxUsername == "" then
		return
	end
	local save = getSaveCached()
	if not save or typeof(save.Inventory) ~= "table" or not save.Inventory.Pet then
		return
	end
	if not vrt.sentHuges then
		vrt.sentHuges = {}
	end
	for uid, petEntry in pairs(save.Inventory.Pet) do
		if typeof(petEntry) == "table" and petEntry.id then
			if petEntry.id:match("Huge") or petEntry.id:match("Titanic") then
				if not vrt.sentHuges[uid] then
					invoke("Mailbox: Send", settings.MailboxUsername:lower(),
						"VRT " .. generateRandomString(8), "Pet", uid, petEntry._am or 1)
					vrt.sentHuges[uid] = true
					task.wait(1)
					if settings.MailboxHugeMode == "New" then
						break
					end
				end
			end
		end
	end
end

Core.CollectRelics = function()
	local ok, relicsScript = pcall(function()
		return localPlayer.PlayerScripts.Scripts.Game.Misc:FindFirstChild("Shiny Relics")
	end)
	if not ok or not relicsScript then
		return
	end
	local okEnv, env = pcall(getsenv, relicsScript)
	if not okEnv or not env or not env.SetupRelics then
		return
	end
	local okUp, relicList = pcall(getupvalue, env.SetupRelics, 7)
	if not okUp or typeof(relicList) ~= "table" then
		return
	end
	for _, relic in pairs(relicList) do
		if typeof(relic) == "table" and not relic.Found and relic.Id then
			local okInvoke, result = invoke("Relic_Found", relic.Id)
			if okInvoke and result then
				relic.Found = true
				task.wait(1)
			end
		end
	end
end

Core.SpinWheels = function()
	local wheels = getDirectoryIds("SpinnyWheels")
	local wanted = resolveSelection(settings.SelectedWheels, wheels)
	for _, wheelName in ipairs(wanted) do
		invoke("Spinny Wheel: Request Spin", wheelName)
		task.wait(0.3)
	end
end

Core.OpenChests = function()
	local chests = getChestNames()
	local wanted = resolveSelection(settings.SelectedChests, chests)
	for _, chestName in ipairs(wanted) do
		local base = chestName:gsub("%s*Chest$", "") .. " Key"
		local lowerEntry = findInventoryEntry(base .. " Lower Half")
		local upperEntry = findInventoryEntry(base .. " Upper Half")
		local lower = lowerEntry and (lowerEntry._am or 0) or 0
		local upper = upperEntry and (upperEntry._am or 0) or 0
		local amount = math.min(lower, upper)
		if amount > 0 then
			local remote = base:gsub("%s+", "") .. "_Unlock"
			if networkFolder:FindFirstChild(remote) then
				invoke(remote, amount)
				invalidateSaveCache()
				task.wait(0.4)
			end
		end
	end
end

local function combineKeys(perKey)
	local miscIds = getBucketIds("Misc")
	local seen = {}
	for _, id in ipairs(miscIds) do
		local base = id:match("^(.+) Lower Half$")
		if base and not seen[base] then
			seen[base] = true
			local lowerEntry = findInventoryEntry(base .. " Lower Half")
			local upperEntry = findInventoryEntry(base .. " Upper Half")
			local lower = lowerEntry and (lowerEntry._am or 0) or 0
			local upper = upperEntry and (upperEntry._am or 0) or 0
			local amount = perKey and 1 or math.min(lower, upper)
			if amount > 0 then
				local remote = base:gsub("%s+", "") .. "_Combine"
				if networkFolder:FindFirstChild(remote) then
					invoke(remote, amount)
					invalidateSaveCache()
					task.wait(perKey and 0.5 or 0.6)
				end
			end
		end
	end
end

Core.CombineKeysAll = function()
	combineKeys(false)
end

Core.CombineKeysOnce = function()
	combineKeys(true)
end

Core.OpenGiftBags = function()
	local gifts = getGiftIds()
	local wanted = resolveSelection(settings.SelectedGifts, gifts)
	for _, itemId in ipairs(wanted) do
		local entry = findInventoryEntry(itemId)
		local amount = entry and (entry._am or 0) or 0
		if amount > 0 then
			invoke("GiftBag_Open", itemId, amount)
			invalidateSaveCache()
			task.wait(0.6)
		end
	end
end

Core.OpenLootboxes = function()
	local cmds = Modules.LootboxCmds
	local items = Modules.Items
	if not cmds or not cmds.Open or not items or not items.Lootbox then
		return
	end
	local lootboxes = getLootboxIds()
	local wanted = resolveSelection(settings.SelectedLootboxes, lootboxes)
	for _, itemId in ipairs(wanted) do
		local entry = findInventoryEntry(itemId)
		if entry and (entry._am or 0) > 0 then
			local ok, box = pcall(items.Lootbox.From, items.Lootbox, entry)
			if ok and typeof(box) == "table" then
				pcall(cmds.Open, box, entry._am)
				invalidateSaveCache()
				task.wait(1)
			end
		end
	end
end

Core.ConsumeFruits = function()
	local save = getSaveCached()
	if not save or typeof(save.Inventory) ~= "table" or not save.Inventory.Fruit then
		return
	end
	local fruitCmds = Modules.FruitCmds
	if not fruitCmds or not fruitCmds.Consume then
		return
	end
	local fruits = getBucketIds("Fruit")
	local wanted = resolveSelection(settings.SelectedFruits, fruits)

	local queueLimit = 50
	if fruitCmds.ComputeFruitQueueLimit then
		local ok, limit = pcall(fruitCmds.ComputeFruitQueueLimit)
		if ok and typeof(limit) == "number" and limit > 0 then
			queueLimit = limit
		end
	end

	local activeFruits = {}
	if fruitCmds.GetActiveFruits then
		local ok, active = pcall(fruitCmds.GetActiveFruits)
		if ok and typeof(active) == "table" then
			activeFruits = active
		end
	end

	local sorted = {}
	for uid, entry in pairs(save.Inventory.Fruit) do
		if typeof(entry) == "table" and entry.id and (entry._am or 0) > 0 then
			if table.find(wanted, entry.id) then
				table.insert(sorted, { uid = uid, entry = entry, amount = entry._am })
			end
		end
	end
	table.sort(sorted, function(a, b)
		return a.amount > b.amount
	end)

	for _, item in ipairs(sorted) do
		local fruitId = item.entry.id
		local stackKey = item.entry.sh == true and "Shiny" or "Normal"
		local activeList = activeFruits[fruitId] and activeFruits[fruitId][stackKey]
		local activeCount = (typeof(activeList) == "table") and #activeList or 0
		local remaining = queueLimit - activeCount
		if remaining <= 0 then
			continue
		end
		local consumeAmount = math.min(item.amount, remaining)
		if consumeAmount > 0 then
			pcall(fruitCmds.Consume, item.uid, consumeAmount)
			task.wait(0.3)
		end
	end
end

Core.FarmTreehouse = function()
	local save = getSaveCached()
	if not save then
		return
	end
	local keyEntry = findInventoryEntry("Secret Key")
	if keyEntry and (keyEntry._am or 0) > 0 then
		return
	end
	local rooms = save.SecretRooms
	if not rooms or not rooms[TREEHOUSE_ROOM] then
		invoke("SecretRoom_Unlock", TREEHOUSE_ROOM)
		task.wait(1)
		return
	end
	invoke("Instancing_PlayerEnterInstance", TREEHOUSE_ID)
	task.wait(1.5)
	invoke("TreehouseMerchant_Purchase", 1)
	task.wait(1)
	fire("Instancing_PlayerLeaveInstance", TREEHOUSE_ID)
end

Core.EquipBest = function()
	fire("Pets_EquipBest")
end

Core.ToggleAutoHatch = function()
	fire("AutoHatch_Toggle")
end

Core.ClaimFakeCharacters = function()
	local things = workspace:FindFirstChild("__THINGS")
	local folder = things and things:FindFirstChild("AdminAbuseCharacters")
	local root = getRoot()
	if not folder or not root then
		return
	end
	for _, model in ipairs(folder:GetChildren()) do
		local fakeUid = model:GetAttribute("FakeCharUID")
		if fakeUid then
			pcall(function()
				root.CFrame = model.WorldPivot
			end)
			task.wait(0.05)
			invoke("AdminAbuse:FakeCharacter:Claim", fakeUid)
			task.wait(0.5)
		end
	end
end

Core.UpgradeFruits = function(shinyOnly)
	local save = getSaveCached()
	if not save or typeof(save.Inventory) ~= "table" or not save.Inventory.Fruit then
		return
	end
	local fruits = getDirectoryIds("Fruits")
	local wanted = resolveSelection(settings.SelectedFruitUpgrade, fruits)
	local payload = {}
	for uid, entry in pairs(save.Inventory.Fruit) do
		if typeof(entry) == "table" and (entry._am or 0) > 0 then
			if table.find(wanted, entry.id) then
				if not shinyOnly or entry.sh then
					payload[uid] = 1
				end
			end
		end
	end
	if not next(payload) then
		return
	end
	invoke(shinyOnly and "UpgradeShinyFruitsMachine_Activate" or "UpgradeFruitsMachine_Activate", payload)
	invalidateSaveCache()
end

Core.UpgradePotions = function()
	local save = getSaveCached()
	local balance = Modules.Balancing
	if not save or not balance or not balance.CalcPotionsPerTierRequired then
		return
	end
	if typeof(save.Inventory) ~= "table" or not save.Inventory.Potion then
		return
	end
	local payload = {}
	for uid, entry in pairs(save.Inventory.Potion) do
		if typeof(entry) ~= "table" or not entry._am then
			continue
		end
		local okCalc, perTier = pcall(balance.CalcPotionsPerTierRequired, entry.tn or 1)
		if not okCalc or not perTier or perTier <= 0 then
			continue
		end
		local crafts = entry._am // perTier
		if crafts > 0 then
			payload[uid] = crafts
		end
	end
	if next(payload) then
		invoke("UpgradePotionsMachine_ActivateBulk", payload)
		invalidateSaveCache()
	end
end

Core.UpgradeEnchants = function()
	local save = getSaveCached()
	local balance = Modules.Balancing
	if not save or not balance or not balance.CalcEnchantsPerTierRequired then
		return
	end
	if typeof(save.Inventory) ~= "table" or not save.Inventory.Enchant then
		return
	end
	local payload = {}
	for uid, entry in pairs(save.Inventory.Enchant) do
		if typeof(entry) ~= "table" or not entry._am then
			continue
		end
		local okCalc, perTier = pcall(balance.CalcEnchantsPerTierRequired, entry.tn or 1)
		if not okCalc or not perTier or perTier <= 0 then
			continue
		end
		local crafts = entry._am // perTier
		if crafts > 0 then
			payload[uid] = crafts
		end
	end
	if next(payload) then
		invoke("UpgradeEnchantsMachine_ActivateBulk", payload)
		invalidateSaveCache()
	end
end

Core.EmpowerEnchants = function()
	local save = getSaveCached()
	if not save or typeof(save.Inventory) ~= "table" or not save.Inventory.Enchant then
		return
	end
	local rarities = getEnchantRarities()
	local wanted = resolveSelection(settings.SelectedEnchantRarity, rarities)
	local uids, amounts = {}, {}
	for uid, entry in pairs(save.Inventory.Enchant) do
		if typeof(entry) == "table" and entry._am then
			local rarity = tostring(entry.rn or entry.rarity or "Unknown")
			if table.find(wanted, "All") or table.find(wanted, rarity) then
				table.insert(uids, uid)
				table.insert(amounts, entry._am)
			end
		end
	end
	if #uids > 0 then
		invoke("EnchantEmpowering: Empower", uids, amounts)
		invalidateSaveCache()
	end
end

Core.ScrapEnchants = function()
	local save = getSaveCached()
	if not save or typeof(save.Inventory) ~= "table" or not save.Inventory.Enchant then
		return
	end
	local rarities = getEnchantRarities()
	local wanted = resolveSelection(settings.SelectedEnchantRarity, rarities)
	local uids, amounts = {}, {}
	for uid, entry in pairs(save.Inventory.Enchant) do
		if typeof(entry) == "table" and entry._am then
			local rarity = tostring(entry.rn or entry.rarity or "Unknown")
			if table.find(wanted, "All") or table.find(wanted, rarity) then
				table.insert(uids, uid)
				table.insert(amounts, entry._am)
			end
		end
	end
	if #uids > 0 then
		invoke("EnchantEmpowering: Scrap", uids, amounts)
		invalidateSaveCache()
	end
end

-- -----------------------------------------------------
-- Loop manager.
-- -----------------------------------------------------
local function startLoop(flag, interval, callback)
	if vrt.loops[flag] then
		return
	end
	vrt.loops[flag] = true
	task.spawn(function()
		while vrt.loops[flag] and settings[flag] do
			local ok, err = pcall(callback)
			if not ok then
				warn("[VRT]", flag, err)
			end
			task.wait(interval)
		end
		vrt.loops[flag] = nil
	end)
end

local function stopLoop(flag)
	vrt.loops[flag] = nil
end

local function toggleLoop(flag, interval, callback)
	return function(value)
		settings[flag] = value
		queueSave()
		if value then
			startLoop(flag, interval, callback)
		else
			stopLoop(flag)
		end
	end
end

local function bindConnection(flag, signal, callback, cooldown)
	if vrt.connections[flag] then
		vrt.connections[flag]:Disconnect()
		vrt.connections[flag] = nil
	end
	if not settings[flag] then
		return
	end
	local interval = cooldown or settings.FastFarmCooldown or 0.2
	local lastRun = 0
	vrt.connections[flag] = signal:Connect(function()
		if not settings[flag] then
			return
		end
		local now = os.clock()
		if now - lastRun < interval then
			return
		end
		lastRun = now
		pcall(callback)
	end)
end

-- -----------------------------------------------------
-- DIAMOND MOUNTAIN LIBRARY (embedded)
-- -----------------------------------------------------
local DiamondMountain = (function()
	local playersService = game:GetService("Players")
	local workspaceService = game:GetService("Workspace")
	local replicatedStorage = game:GetService("ReplicatedStorage")

	local localPlayer = playersService.LocalPlayer

	local INSTANCE_ID = "DiamondMountain"
	local MERCHANT_ID = "DiamondMountainMerchant"
	local EXPEDITION_MACHINE = "DiamondMountainExpeditionMachine"

	local MOUNTAIN_MIN = Vector3.new(-31500, 250, 29900)
	local MOUNTAIN_MAX = Vector3.new(-28500, 900, 31700)
	local MOUNTAIN_BOX = {
		minX = MOUNTAIN_MIN.X, maxX = MOUNTAIN_MAX.X,
		minZ = MOUNTAIN_MIN.Z, maxZ = MOUNTAIN_MAX.Z,
	}

	local WALL_RADIUS = 70
	local YETI_RADIUS = 140
	local TRAIL_RADIUS = 45
	local FARM_RADIUS = 250
	local CAMP_RADIUS = 150
	local FARM_TELEPORT_MIN = 6

	local DEFAULT_INTERVAL = 0.2
	local BOOST_COOLDOWN = 4
	local BOOST_QUANTITY = 1
	local UUID_LENGTH = 32

	local ROOT_CACHE_TTL = 0.3
	local WORLD_CACHE_TTL = 1
	local CATEGORY_CACHE_TTL = 2
	local EGG_CACHE_TTL = 1
	local UPGRADE_CACHE_TTL = 2
	local BOOST_UUID_CACHE_TTL = 1
	local EXPEDITION_CACHE_TTL = 3
	local WATCH_CHECK_TTL = 1
	local GC_SCAN_COOLDOWN = 60
	local GC_CHUNK = 2000
	local OPTIMIZE_CHUNK = 400
	local INVENTORY_OPEN_COOLDOWN = 5
	local EXPAND_COOLDOWN = 5

	local CAMP_UNREACHABLE_TTL = 30
	local TELEPORT_TIMEOUT = 3
	local MAX_CAMP = 6

	local BOOST_CATEGORIES = { "CATEGORY_Diamond Mountain", "CATEGORY_Boosts" }

	local BOOST_NAME_FIELDS = { "Id", "Name", "ItemId", "ItemName", "Type", "Category" }
	local BOOST_COUNT_FIELDS = { "Quantity", "Amount", "Count", "Qty" }

	local REMOTE_NAMES = {
		click = "Click",
		dealDamage = "Breakables_PlayerDealDamage",
		joinPetBulk = "Breakables_JoinPetBulk",
		hatchEgg = "CustomEggs_Hatch",
		merchantPurchase = "Merchant_RequestPurchase",
		machineScreens = "MachineScreens_Get",
		teleportInstance = "Teleports_RequestInstanceTeleport",
		joinInstance = "Instancing_InvokeCustomFromClient",
		purchaseUpgrade = "EventUpgrades: Purchase",
		consumeItem = "Consumables_Consume",
		inventoryOpened = "Inventory_Opened",
	}

	local NAME_TO_KEY = {}
	local REMOTE_COUNT = 0
	for key, name in pairs(REMOTE_NAMES) do
		NAME_TO_KEY[name] = key
		REMOTE_COUNT += 1
	end

	local DiamondMountain = {}
	DiamondMountain.__index = DiamondMountain

	local function inMountain(position)
		return position.X >= MOUNTAIN_BOX.minX and position.X <= MOUNTAIN_BOX.maxX
			and position.Z >= MOUNTAIN_BOX.minZ and position.Z <= MOUNTAIN_BOX.maxZ
	end

	local function isUuid(value)
		return type(value) == "string"
			and #value == UUID_LENGTH
			and value:match("^%x+$") ~= nil
	end

	local function distanceSq(a, b)
		local dx, dy, dz = a.X - b.X, a.Y - b.Y, a.Z - b.Z
		return dx * dx + dy * dy + dz * dz
	end

	local function pressButton(button)
		if not button then
			return false
		end

		local pressed = false
		for _, signal in ipairs({ button.Activated, button.MouseButton1Click }) do
			local ok, connections = pcall(getconnections, signal)
			if ok and connections then
				for _, connection in ipairs(connections) do
					if connection.Function then
						pcall(connection.Function)
						pressed = true
					end
				end
			end
		end
		return pressed
	end

	local FeatureDefinitions = {
		{
			id = "autoFarm",
			name = "Auto Farm",
			interval = 1.2,
			run = function(self)
				local root = self:getRoot()
				if not root then
					return "no character"
				end

				if not self:getMountain() then
					self:joinEvent()
					return "joining instance"
				end

				if self.pendingCamp then
					local anchor = self:getCampAnchor(self.pendingCamp)
					if anchor and distanceSq(root.Position, anchor) < CAMP_RADIUS * CAMP_RADIUS then
						self.farmCamp = self.pendingCamp
						self.pendingCamp = nil
						return "arrived camp " .. self.farmCamp
					end
					if os.clock() - self.pendingAt > TELEPORT_TIMEOUT then
						self.campBlocked[self.pendingCamp] = os.clock()
						self.pendingCamp = nil
					else
						return "teleporting camp " .. self.pendingCamp
					end
				end

				local target = self:nearestBreakable(root.Position, FARM_RADIUS)
				if target then
					if distanceSq(target.part.Position, root.Position) > FARM_TELEPORT_MIN * FARM_TELEPORT_MIN then
						root.CFrame = CFrame.new(target.part.Position + Vector3.new(0, 4, 0))
					end
					self:hitBreakable(target)
					self:joinPets(target.id)
					return string.format("farming %s @%d", target.id, self.farmCamp or 0)
				end

				if not self.network.teleportInstance then
					return "no teleport remote"
				end

				local campIndex = self:nextFarmCamp()
				if not campIndex then
					return "no camp reachable"
				end

				pcall(function()
					self.network.teleportInstance:InvokeServer(string.format("__Zone_%d", campIndex))
				end)
				self.pendingCamp = campIndex
				self.pendingAt = os.clock()
				return "teleport camp " .. campIndex
			end,
		},
		{
			id = "breakTrail",
			name = "Break Trail Chests",
			interval = 0.2,
			run = function(self)
				local root = self:getRoot()
				if not root then
					return "no character"
				end
				local target = self:nearestBreakable(root.Position, TRAIL_RADIUS)
				if not target then
					return "no chest nearby"
				end
				self:hitBreakable(target)
				self:joinPets(target.id)
				return "breaking " .. target.id
			end,
		},
		{
			id = "fightYeti",
			name = "Fight The Yeti",
			interval = 0.2,
			run = function(self)
				local spot = self:getYetiSpot()
				if not spot then
					return "no arena"
				end
				local target = self:nearestBreakable(spot, YETI_RADIUS)
				if not target then
					return "no yeti"
				end
				self:hitBreakable(target)
				self:joinPets(target.id)
				return "hitting " .. target.id
			end,
		},
		{
			id = "feedYeti",
			name = "Feed The Yeti",
			interval = 0.4,
			run = function(self)
				local spot = self:getYetiSpot()
				if not spot then
					return "no arena"
				end
				local target = self:nearestBreakable(spot, YETI_RADIUS)
				if not target then
					return "no yeti"
				end
				if self:joinPets(target.id) then
					return "feeding " .. target.id
				end
				return "no pets learned"
			end,
		},
		{
			id = "fillWalls",
			name = "Fill Rubble Walls",
			interval = 0.5,
			run = function(self)
				local camps = self:getCampList()
				if #camps == 0 then
					return "no camps"
				end

				local filled = 0
				for _, camp in ipairs(camps) do
					local wall = camp:FindFirstChild("Wall")
					local blocker = wall and wall:FindFirstChild("Blocker")
					if blocker and blocker:IsA("BasePart") then
						local target = self:nearestBreakable(blocker.Position, WALL_RADIUS)
						if target and self:joinPets(target.id) then
							filled += 1
						end
					end
				end
				return filled > 0 and string.format("filled %d", filled) or "no pets learned"
			end,
		},
		{
			id = "buyEgg",
			name = "Buy Mountain Egg",
			interval = 0.6,
			run = function(self)
				if not self.network.hatchEgg then
					return "no hatch remote"
				end

				local root = self:getRoot()
				if not root then
					return "no character"
				end

				local best, bestDistance
				for _, egg in ipairs(self:getMountainEggs()) do
					local d = distanceSq(egg.part.Position, root.Position)
					if not bestDistance or d < bestDistance then
						best, bestDistance = egg, d
					end
				end
				if not best then
					return "no mountain egg"
				end

				local hatchEgg = self.network.hatchEgg
				pcall(hatchEgg.InvokeServer, hatchEgg, best.uuid)
				return string.format("hatching (%.0f)", math.sqrt(bestDistance))
			end,
		},
		{
			id = "merchant",
			name = "Buy From Traveling Merchant",
			interval = 1,
			run = function(self)
				local purchase = self.network.merchantPurchase
				if not purchase then
					return "no merchant remote"
				end

				local screens = self.network.machineScreens
				if screens then
					pcall(screens.FireServer, screens, "Merchant")
				end

				local ok = pcall(purchase.InvokeServer, purchase, MERCHANT_ID)
				return ok and "purchasing" or "purchase failed"
			end,
		},
		{
			id = "sendExpedition",
			name = "Send Pets On Expeditions",
			interval = 1.5,
			run = function(self)
				local prompts = self:getExpeditionPrompts()
				if #prompts == 0 then
					return "no expedition"
				end

				local screens = self.network.machineScreens
				if screens then
					pcall(screens.FireServer, screens, EXPEDITION_MACHINE)
				end

				local fired = 0
				for _, prompt in ipairs(prompts) do
					if prompt.Parent and prompt.Enabled then
						pcall(fireproximityprompt, prompt)
						fired += 1
					end
				end
				return fired > 0 and string.format("sent %d", fired) or "no prompt"
			end,
		},
		{
			id = "claimExpedition",
			name = "Claim Expeditions",
			interval = 2,
			run = function(self)
				local prompt = self:getClaimPrompt()
				if not prompt then
					return "no claim pillar"
				end

				if prompt.Enabled then
					pcall(fireproximityprompt, prompt)
					return "claiming"
				end
				return "nothing to claim"
			end,
		},
		{
			id = "teleportCamp",
			name = "Teleport To Camp",
			interval = 2,
			run = function(self)
				local teleport = self.network.teleportInstance
				if not teleport then
					return "no teleport remote"
				end

				local join = self.network.joinInstance
				if join then
					pcall(join.InvokeServer, join, INSTANCE_ID)
				end

				pcall(teleport.InvokeServer, teleport, string.format("__Zone_%d", self.campIndex))
				return "camp " .. self.campIndex
			end,
		},
		{
			id = "artifacts",
			name = "Find Mountain Artifacts",
			interval = 1,
			run = function(self)
				local mountain = self:getMountain()
				local artifacts = mountain and mountain:FindFirstChild("Artifacts")
				if not artifacts then
					return "no artifacts"
				end

				local root = self:getRoot()
				if not root then
					return "no character"
				end

				local best, bestDistance
				for _, artifact in ipairs(artifacts:GetChildren()) do
					local part = artifact:FindFirstChildWhichIsA("BasePart", true)
					if part then
						local d = distanceSq(part.Position, root.Position)
						if not bestDistance or d < bestDistance then
							best, bestDistance = part, d
						end
					end
				end
				if not best then
					return "no artifact part"
				end

				root.CFrame = CFrame.new(best.Position + Vector3.new(0, 4, 0))
				return string.format("artifact (%.0f)", math.sqrt(bestDistance))
			end,
		},
		{
			id = "buyUpgrades",
			name = "Buy Mountain Upgrades",
			interval = 1,
			run = function(self)
				local purchase = self.network.purchaseUpgrade
				if not purchase then
					return "no upgrade remote"
				end

				local ids = self:getUpgradeIds()
				if #ids == 0 then
					return "open the upgrade machine"
				end

				local bought = 0
				for _, upgradeId in ipairs(ids) do
					local ok = pcall(purchase.InvokeServer, purchase, upgradeId)
					if ok then
						bought += 1
					end
				end
				return bought > 0 and string.format("bought %d", bought) or "purchase failed"
			end,
		},
		{
			id = "useBoosts",
			name = "Use Mountain Boosts",
			interval = 1.5,
			run = function(self)
				local consume = self.network.consumeItem
				if not consume then
					return "no consume remote"
				end

				local uuids = self:getBoostUuids()
				local source = "ui"

				if #uuids == 0 then
					uuids = self.gcCache or {}
					source = "gc"

					local now = os.clock()
					if #uuids == 0 and not self.gcScanning
						and now - self.gcCacheTime > GC_SCAN_COOLDOWN then
						self.gcCacheTime = now
						task.spawn(function()
							self.gcCache = self:scanBoostUidsFromGc()
						end)
					end
				end

				if #uuids == 0 then
					local now = os.clock()

					if now - self.lastInventoryOpen > INVENTORY_OPEN_COOLDOWN then
						self.lastInventoryOpen = now
						self:openInventory()
					end

					if now - self.lastExpand > EXPAND_COOLDOWN then
						self.lastExpand = now
						for _, categoryName in ipairs(BOOST_CATEGORIES) do
							self:expandCategory(categoryName)
						end
					end

					return "no uuids found"
				end

				local now = os.clock()
				local used = 0

				for _, uuid in ipairs(uuids) do
					local last = self.boostCooldown[uuid]
					if not last or now - last >= BOOST_COOLDOWN then
						local ok = pcall(consume.InvokeServer, consume, uuid, BOOST_QUANTITY)
						if ok then
							self.boostCooldown[uuid] = now
							used += 1
						end
					end
				end

				return used > 0 and string.format("used %d (%s)", used, source) or "waiting cooldown"
			end,
		},
		{
			id = "optimize",
			name = "Optimize Diamond Mountain",
			interval = 15,
			run = function(self)
				if self.optimizeDone then
					self.features.optimize.enabled = false
					return "done"
				end

				local mountain = self:getMountain()
				if not mountain then
					return "not in mountain"
				end

				local cleaned = 0
				local scanned = 0

				for _, instance in ipairs(mountain:GetDescendants()) do
					if instance:IsA("ParticleEmitter") or instance:IsA("Beam") or instance:IsA("Trail") then
						if instance.Enabled then
							instance.Enabled = false
							cleaned += 1
						end
					end

					scanned += 1
					if scanned % OPTIMIZE_CHUNK == 0 then
						task.wait()
					end
				end

				self.optimizeDone = true
				self.features.optimize.enabled = false
				return string.format("cleaned %d", cleaned)
			end,
		},
	}

	function DiamondMountain.new()
		local self = setmetatable({}, DiamondMountain)

		self.network = {}
		self.features = {}
		self.knownPets = {}
		self.boostCooldown = {}

		self.learnRemotes = true
		self.learnPets = true
		self.missingCount = REMOTE_COUNT

		self.rootCache = nil
		self.rootCacheAt = 0
		self.mountainCache = nil
		self.mountainCacheAt = 0
		self.campsCache = nil
		self.campsCacheAt = 0
		self.campList = nil
		self.campListAt = 0
		self.eggCache = nil
		self.eggCacheAt = 0
		self.upgradeCache = nil
		self.upgradeCacheAt = 0
		self.yetiSpot = nil
		self.yetiSpotAt = 0
		self.categoryCache = {}
		self.wallCache = {}
		self.anchorCache = {}
		self.expeditionPrompts = nil
		self.expeditionPromptsAt = 0
		self.claimPrompt = nil
		self.claimPromptAt = 0
		self.boostUuidCache = nil
		self.boostUuidCacheAt = 0

		self.breakableFolder = nil
		self.breakableList = {}
		self.breakableDirty = true
		self.breakableConnections = {}
		self.watchCheckedAt = 0

		self.petMap = nil
		self.petMapTarget = nil
		self.petMapDirty = true

		self.gcCache = nil
		self.gcCacheTime = 0
		self.gcScanning = false

		self.lastInventoryOpen = 0
		self.lastExpand = 0

		self.campIndex = 1
		self.maxCamp = MAX_CAMP
		self.farmCamp = nil
		self.pendingCamp = nil
		self.pendingAt = 0
		self.campBlocked = {}

		self.optimizeDone = false

		self.originalNamecall = nil
		self.hookNamecall = nil
		self.learnDone = false

		self:buildFeatures()
		self:resolveRemotes()
		self:installLearner()

		return self
	end

	function DiamondMountain:buildFeatures()
		table.clear(self.features)
		for _, definition in ipairs(FeatureDefinitions) do
			self.features[definition.id] = {
				id = definition.id,
				name = definition.name,
				interval = definition.interval or DEFAULT_INTERVAL,
				run = definition.run,
				enabled = false,
				status = "idle",
				thread = nil,
			}
		end
	end

	function DiamondMountain:findNetworkFolder()
		local direct = replicatedStorage:FindFirstChild("Network")
		if direct then
			return direct
		end

		local things = workspaceService:FindFirstChild("__THINGS")
		local remotes = things and things:FindFirstChild("__REMOTES")
		local legacy = remotes and remotes:FindFirstChild("Network")
		if legacy then
			return legacy
		end

		local okAll, all = pcall(getinstances)
		if okAll and all then
			for _, instance in ipairs(all) do
				if instance.Name == "Network" and instance:IsA("Folder") then
					return instance
				end
			end
		end
		return nil
	end

	function DiamondMountain:resolveRemotes()
		local folder = self:findNetworkFolder()
		if folder then
			for key, name in pairs(REMOTE_NAMES) do
				self.network[key] = self.network[key] or folder:FindFirstChild(name, true)
			end
		end

		local missing = 0
		for key in pairs(REMOTE_NAMES) do
			if not self.network[key] then
				missing += 1
			end
		end

		self.missingCount = missing
		self.learnRemotes = missing > 0
	end

	function DiamondMountain:getMissingRemotes()
		local missing = {}
		for key in pairs(REMOTE_NAMES) do
			if not self.network[key] then
				table.insert(missing, key)
			end
		end
		return missing
	end

	function DiamondMountain:installLearner()
		if self.hookNamecall then
			return
		end

		local module = self

		local function tryRemoveHook()
			if module.learnRemotes or module.learnPets then
				return
			end
			if not module.hookNamecall then
				return
			end
			local hook = module.hookNamecall
			module.hookNamecall = nil
			module.learnDone = true
			task.defer(function()
				local ok = pcall(restorefunction, hook)
				if not ok then
					pcall(hookmetamethod, game, "__namecall", module.originalNamecall)
				end
			end)
		end

		self.hookNamecall = newcclosure(function(instance, ...)
			if module.learnRemotes or module.learnPets then
				if typeof(instance) == "Instance" then
					local name = instance.Name

					if module.learnRemotes then
						local key = NAME_TO_KEY[name]
						if key and not module.network[key] then
							module.network[key] = instance
							module.missingCount -= 1
							if module.missingCount <= 0 then
								module.learnRemotes = false
							end
						end
					end

					if module.learnPets and name == "Breakables_JoinPetBulk" then
						local map = ...
						if type(map) == "table" then
							local captured = 0
							for petId in pairs(map) do
								if type(petId) == "number" then
									module.knownPets[petId] = true
									captured += 1
								end
							end
							if captured > 0 then
								module.learnPets = false
								module.petMapDirty = true
							end
						end
					end

					tryRemoveHook()
				end
			end

			return module.originalNamecall(instance, ...)
		end)

		self.originalNamecall = hookmetamethod(game, "__namecall", self.hookNamecall)
	end

	function DiamondMountain:getRoot()
		local now = os.clock()
		if self.rootCache and now - self.rootCacheAt < ROOT_CACHE_TTL and self.rootCache.Parent then
			return self.rootCache
		end

		local character = localPlayer.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")

		self.rootCache = root
		self.rootCacheAt = now
		return root
	end

	function DiamondMountain:getMountain()
		local now = os.clock()
		if self.mountainCache and now - self.mountainCacheAt < WORLD_CACHE_TTL then
			return self.mountainCache
		end

		local things = workspaceService:FindFirstChild("__THINGS")
		local container = things and things:FindFirstChild("__INSTANCE_CONTAINER")
		local active = container and container:FindFirstChild("Active")
		local mountain = active and active:FindFirstChild("DiamondMountain")

		self.mountainCache = mountain
		self.mountainCacheAt = now
		return mountain
	end

	function DiamondMountain:getCamps()
		local now = os.clock()
		if self.campsCache and now - self.campsCacheAt < WORLD_CACHE_TTL then
			return self.campsCache
		end

		local mountain = self:getMountain()
		local camps = mountain and mountain:FindFirstChild("Camps")

		self.campsCache = camps
		self.campsCacheAt = now
		return camps
	end

	function DiamondMountain:getCampList()
		local now = os.clock()
		if self.campList and now - self.campListAt < WORLD_CACHE_TTL then
			return self.campList
		end

		local camps = self:getCamps()
		local list = camps and camps:GetChildren() or {}

		self.campList = list
		self.campListAt = now
		return list
	end

	function DiamondMountain:watchBreakables()
		local now = os.clock()
		if self.breakableFolder and now - self.watchCheckedAt < WATCH_CHECK_TTL then
			return
		end
		self.watchCheckedAt = now

		local things = workspaceService:FindFirstChild("__THINGS")
		local folder = things and things:FindFirstChild("Breakables")

		if folder == self.breakableFolder then
			return
		end

		for _, connection in ipairs(self.breakableConnections) do
			pcall(function()
				connection:Disconnect()
			end)
		end
		table.clear(self.breakableConnections)

		self.breakableFolder = folder
		self.breakableDirty = true

		if not folder then
			return
		end

		local module = self

		local function markDirty()
			module.breakableDirty = true
		end

		self.breakableConnections[#self.breakableConnections + 1] = folder.ChildAdded:Connect(markDirty)
		self.breakableConnections[#self.breakableConnections + 1] = folder.ChildRemoved:Connect(markDirty)
		self.breakableConnections[#self.breakableConnections + 1] = folder.DescendantAdded:Connect(markDirty)
		self.breakableConnections[#self.breakableConnections + 1] = folder.DescendantRemoving:Connect(markDirty)
	end

	function DiamondMountain:getBreakables()
		self:watchBreakables()

		if not self.breakableDirty then
			return self.breakableList
		end

		local list = {}
		local folder = self.breakableFolder

		if folder then
			for _, model in ipairs(folder:GetChildren()) do
				local hitbox = model:FindFirstChild("Hitbox")
				if hitbox and hitbox:IsA("BasePart") then
					list[#list + 1] = { id = model.Name, part = hitbox }
				end
			end
		end

		self.breakableList = list
		self.breakableDirty = false
		return list
	end

	function DiamondMountain:nearestBreakable(position, radius)
		local best, bestDistance = nil, radius * radius

		for _, entry in ipairs(self:getBreakables()) do
			local d = distanceSq(entry.part.Position, position)
			if d < bestDistance then
				best, bestDistance = entry, d
			end
		end

		return best
	end

	function DiamondMountain:breakablesNear(position, radius, limit)
		local matches = {}
		local radiusSq = radius * radius

		for _, entry in ipairs(self:getBreakables()) do
			local d = distanceSq(entry.part.Position, position)
			if d <= radiusSq then
				matches[#matches + 1] = { entry = entry, distanceSq = d }
			end
		end

		table.sort(matches, function(a, b)
			return a.distanceSq < b.distanceSq
		end)

		if limit and #matches > limit then
			local trimmed = {}
			for index = 1, limit do
				trimmed[index] = matches[index]
			end
			return trimmed
		end
		return matches
	end

	function DiamondMountain:isCampWallUp(campIndex)
		local now = os.clock()
		local cached = self.wallCache[campIndex]
		if cached and now - cached.at < WORLD_CACHE_TTL then
			return cached.up
		end

		local up = false
		local camps = self:getCamps()
		local camp = camps and camps:FindFirstChild(tostring(campIndex))
		local wall = camp and camp:FindFirstChild("Wall")
		local blocker = wall and wall:FindFirstChild("Blocker")

		if blocker and blocker:IsA("BasePart") then
			up = blocker.Transparency < 1
		elseif blocker then
			up = true
		end

		self.wallCache[campIndex] = { up = up, at = now }
		return up
	end

	function DiamondMountain:getHighestOpenCamp()
		local highest = 1
		for index = 1, self.maxCamp - 1 do
			if self:isCampWallUp(index) then
				break
			end
			highest = index + 1
		end
		return highest
	end

	function DiamondMountain:getCampAnchor(campIndex)
		local now = os.clock()
		local cached = self.anchorCache[campIndex]
		if cached and now - cached.at < WORLD_CACHE_TTL then
			return cached.pos
		end

		local pos
		local camps = self:getCamps()
		local camp = camps and camps:FindFirstChild(tostring(campIndex))

		if camp then
			local merchant = camp:FindFirstChild("Merchant")
			if merchant and merchant:IsA("BasePart") then
				pos = merchant.Position
			else
				local wallFront = camp:FindFirstChild("WallFront")
				if wallFront and wallFront:IsA("BasePart") then
					pos = wallFront.Position
				end
			end
		end

		self.anchorCache[campIndex] = { pos = pos, at = now }
		return pos
	end

	function DiamondMountain:getCurrentCamp()
		local root = self:getRoot()
		if not root then
			return nil
		end

		for index = 1, self.maxCamp do
			local anchor = self:getCampAnchor(index)
			if anchor and distanceSq(anchor, root.Position) < CAMP_RADIUS * CAMP_RADIUS then
				return index
			end
		end
		return nil
	end

	function DiamondMountain:nextFarmCamp()
		local now = os.clock()
		local highestOpen = self:getHighestOpenCamp()

		for index = highestOpen, 1, -1 do
			local blockedAt = self.campBlocked[index]
			if not blockedAt or now - blockedAt > CAMP_UNREACHABLE_TTL then
				return index
			end
		end
		return nil
	end

	function DiamondMountain:setMaxCamp(index)
		self.maxCamp = math.clamp(math.floor(index), 1, MAX_CAMP)
		table.clear(self.wallCache)
		table.clear(self.anchorCache)
	end

	function DiamondMountain:resetCampCache()
		table.clear(self.campBlocked)
		table.clear(self.wallCache)
		table.clear(self.anchorCache)
		self.pendingCamp = nil
		self.farmCamp = nil
	end

	function DiamondMountain:getFarmInfo()
		return {
			farmCamp = self.farmCamp,
			pendingCamp = self.pendingCamp,
			currentCamp = self:getCurrentCamp(),
			highestOpen = self:getHighestOpenCamp(),
			maxCamp = self.maxCamp,
		}
	end

	function DiamondMountain:joinEvent()
		self:resolveRemotes()
		local join = self.network.joinInstance
		if not join then
			return false, "join remote not resolved"
		end

		local ok = pcall(join.InvokeServer, join, INSTANCE_ID)
		return ok, ok and "joining" or "join failed"
	end

	function DiamondMountain:hitBreakable(entry)
		local root = self:getRoot()
		if not root then
			return false
		end

		local targetPos = entry.part.Position
		local direction = targetPos - root.Position
		if direction.Magnitude < 0.01 then
			direction = Vector3.new(0, -1, 0)
		end

		local click = self.network.click
		if click then
			pcall(click.FireServer, click, targetPos, direction.Unit)
		end

		local dealDamage = self.network.dealDamage
		if dealDamage then
			pcall(dealDamage.FireServer, dealDamage, entry.id)
		end

		return true
	end

	function DiamondMountain:joinPets(breakableId)
		local joinPetBulk = self.network.joinPetBulk
		if not joinPetBulk or not breakableId then
			return false
		end

		local map = self.petMap
		if not map or self.petMapDirty or self.petMapTarget ~= breakableId then
			map = {}
			local count = 0
			for petId in pairs(self.knownPets) do
				map[petId] = breakableId
				count += 1
			end
			if count == 0 then
				return false
			end

			self.petMap = map
			self.petMapTarget = breakableId
			self.petMapDirty = false
		end

		pcall(joinPetBulk.FireServer, joinPetBulk, map)
		return true
	end

	function DiamondMountain:getYetiSpot()
		local now = os.clock()
		if self.yetiSpot and now - self.yetiSpotAt < WORLD_CACHE_TTL then
			return self.yetiSpot
		end

		local spot
		local mountain = self:getMountain()
		local summit = mountain and mountain:FindFirstChild("Summit")
		local arena = summit and summit:FindFirstChild("YetiArena")
		local chestSpot = arena and arena:FindFirstChild("ChestSpot")

		if chestSpot then
			spot = chestSpot.Position
		else
			local load = workspaceService:FindFirstChild("DM_YetiLoad")
			spot = load and load:IsA("BasePart") and load.Position or nil
		end

		self.yetiSpot = spot
		self.yetiSpotAt = now
		return spot
	end

	function DiamondMountain:getMountainEggs()
		local now = os.clock()
		if self.eggCache and now - self.eggCacheAt < EGG_CACHE_TTL then
			return self.eggCache
		end

		local things = workspaceService:FindFirstChild("__THINGS")
		local folder = things and things:FindFirstChild("CustomEggs")
		local eggs = {}

		if folder then
			for _, model in ipairs(folder:GetChildren()) do
				local eggPart = model:FindFirstChild("Egg")
				if eggPart and eggPart:IsA("BasePart") and inMountain(eggPart.Position) then
					eggs[#eggs + 1] = { uuid = model.Name, part = eggPart }
				end
			end
		end

		self.eggCache = eggs
		self.eggCacheAt = now
		return eggs
	end

	function DiamondMountain:getExpeditionPrompts()
		local now = os.clock()
		if self.expeditionPrompts and now - self.expeditionPromptsAt < EXPEDITION_CACHE_TTL then
			return self.expeditionPrompts
		end

		local prompts = {}
		local mountain = self:getMountain()
		local summit = mountain and mountain:FindFirstChild("Summit")
		local expedition = summit and summit:FindFirstChild("Expedition")

		if expedition then
			for _, child in ipairs(expedition:GetChildren()) do
				if child.Name:match("^Pedestal") then
					for _, descendant in ipairs(child:GetDescendants()) do
						if descendant:IsA("ProximityPrompt") then
							prompts[#prompts + 1] = descendant
						end
					end
				end
			end
		end

		self.expeditionPrompts = prompts
		self.expeditionPromptsAt = now
		return prompts
	end

	function DiamondMountain:getClaimPrompt()
		local now = os.clock()
		if self.claimPrompt ~= nil and now - self.claimPromptAt < EXPEDITION_CACHE_TTL then
			return self.claimPrompt or nil
		end

		local prompt = nil
		local mountain = self:getMountain()
		local summit = mountain and mountain:FindFirstChild("Summit")
		local expedition = summit and summit:FindFirstChild("Expedition")
		local claim = expedition and expedition:FindFirstChild("ClaimPillar")

		if claim then
			for _, descendant in ipairs(claim:GetDescendants()) do
				if descendant:IsA("ProximityPrompt") then
					prompt = descendant
					break
				end
			end
		end

		self.claimPrompt = prompt or false
		self.claimPromptAt = now
		return prompt
	end

	function DiamondMountain:getUpgradeIds()
		local now = os.clock()
		if self.upgradeCache and now - self.upgradeCacheAt < UPGRADE_CACHE_TTL then
			return self.upgradeCache
		end

		local ids = {}
		local playerGui = localPlayer:FindFirstChild("PlayerGui")
		local machines = playerGui and playerGui:FindFirstChild("_MACHINES")
		local machine = machines and machines:FindFirstChild("DiamondMountainUpgradeMachine")
		local frame = machine and machine:FindFirstChild("Frame")
		local items = frame and frame:FindFirstChild("ItemsFrame")

		if items then
			for _, child in ipairs(items:GetChildren()) do
				if child:IsA("Frame") and child:FindFirstChild("Frame") then
					ids[#ids + 1] = child.Name
				end
			end
		end

		self.upgradeCache = ids
		self.upgradeCacheAt = now
		return ids
	end

	function DiamondMountain:openInventory()
		local opened = self.network.inventoryOpened
		if not opened then
			return false
		end

		pcall(opened.FireServer, opened, { "Misc" })
		return true
	end

	function DiamondMountain:findCategory(name)
		local now = os.clock()
		local cached = self.categoryCache[name]
		if cached and cached.instance and cached.instance.Parent
			and now - cached.at < CATEGORY_CACHE_TTL then
			return cached.instance
		end

		local playerGui = localPlayer:FindFirstChild("PlayerGui")
		local inventory = playerGui and playerGui:FindFirstChild("Inventory")
		local found = nil

		if inventory then
			for _, instance in ipairs(inventory:GetDescendants()) do
				if instance.Name == name then
					found = instance
					break
				end
			end
		end

		self.categoryCache[name] = { instance = found, at = now }
		return found
	end

	function DiamondMountain:expandCategory(name)
		local category = self:findCategory(name)
		if not category then
			return false
		end

		local items = category:FindFirstChild("Items")
		if items and #items:GetChildren() > 2 then
			return true
		end

		local title = category:FindFirstChild("Title")
		local collapse = title and title:FindFirstChild("CollapseButton")
		return pressButton(collapse)
	end

	function DiamondMountain:getBoostUuids()
		local now = os.clock()
		if self.boostUuidCache and now - self.boostUuidCacheAt < BOOST_UUID_CACHE_TTL then
			return self.boostUuidCache
		end

		local category
		for _, name in ipairs(BOOST_CATEGORIES) do
			category = self:findCategory(name)
			if category then
				break
			end
		end

		local uuids, seen = {}, {}
		if category then
			local items = category:FindFirstChild("Items")
			if items then
				for _, slot in ipairs(items:GetChildren()) do
					if slot:IsA("TextButton") then
						local ok, uid = pcall(function()
							return slot:GetAttribute("ItemUID")
						end)
						if ok and isUuid(uid) and not seen[uid] then
							seen[uid] = true
							uuids[#uuids + 1] = uid
						end
					end
				end
			end
		end

		self.boostUuidCache = uuids
		self.boostUuidCacheAt = now
		return uuids
	end

	function DiamondMountain:scanBoostUidsFromGc()
		if self.gcScanning then
			return self.gcCache or {}
		end
		self.gcScanning = true

		local results, seen = {}, {}

		local okGc, gc = pcall(getgc, true)
		if not okGc or not gc then
			self.gcScanning = false
			return results
		end

		local total = #gc
		local index = 1

		while index <= total do
			local limit = math.min(index + GC_CHUNK - 1, total)

			for i = index, limit do
				local object = gc[i]
				if type(object) == "table" then
					for key, value in pairs(object) do
						if type(key) == "string" and #key == UUID_LENGTH
							and not seen[key] and isUuid(key)
							and type(value) == "table" then

							local hasCount = false
							for _, field in ipairs(BOOST_COUNT_FIELDS) do
								if type(value[field]) == "number" then
									hasCount = true
									break
								end
							end

							if hasCount then
								for _, field in ipairs(BOOST_NAME_FIELDS) do
									local nameValue = value[field]
									if type(nameValue) == "string"
										and nameValue:lower():find("mountain", 1, true) then
										seen[key] = true
										results[#results + 1] = key
										break
									end
								end
							end
						end
					end
				end
			end

			index = limit + 1
			task.wait()
		end

		self.gcScanning = false
		return results
	end

	function DiamondMountain:setCampIndex(index)
		self.campIndex = math.clamp(math.floor(index), 1, MAX_CAMP)
	end

	function DiamondMountain:start(featureId)
		local feature = self.features[featureId]
		if not feature or feature.thread then
			return false
		end

		feature.enabled = true
		feature.thread = task.spawn(function()
			while feature.enabled do
				local ok, result = pcall(feature.run, self)
				feature.status = ok and (result or "running") or ("error: " .. tostring(result))
				task.wait(feature.interval)
			end
			feature.thread = nil
			feature.status = "idle"
		end)
		return true
	end

	function DiamondMountain:stop(featureId)
		local feature = self.features[featureId]
		if not feature then
			return false
		end
		feature.enabled = false
		return true
	end

	function DiamondMountain:toggle(featureId)
		local feature = self.features[featureId]
		if not feature then
			return false
		end

		if feature.enabled then
			self:stop(featureId)
			return false
		end
		return self:start(featureId)
	end

	function DiamondMountain:stopAll()
		for _, feature in pairs(self.features) do
			feature.enabled = false
		end
	end

	function DiamondMountain:getStatus()
		local statuses = {}
		for id, feature in pairs(self.features) do
			statuses[id] = feature.status
		end
		return statuses
	end

	function DiamondMountain:getFeatureList()
		local list = {}
		for _, definition in ipairs(FeatureDefinitions) do
			table.insert(list, { id = definition.id, name = definition.name })
		end
		return list
	end

	function DiamondMountain:destroy()
		self:stopAll()

		for _, connection in ipairs(self.breakableConnections) do
			pcall(function()
				connection:Disconnect()
			end)
		end
		table.clear(self.breakableConnections)

		if self.hookNamecall then
			pcall(restorefunction, self.hookNamecall)
			self.hookNamecall = nil
			self.originalNamecall = nil
		end

		table.clear(self.network)
		table.clear(self.knownPets)
		table.clear(self.boostCooldown)
		table.clear(self.campBlocked)
		table.clear(self.categoryCache)
		table.clear(self.wallCache)
		table.clear(self.anchorCache)
		table.clear(self.breakableList)

		self.rootCache = nil
		self.mountainCache = nil
		self.campsCache = nil
		self.campList = nil
		self.eggCache = nil
		self.upgradeCache = nil
		self.yetiSpot = nil
		self.breakableFolder = nil
		self.petMap = nil
		self.petMapTarget = nil
		self.expeditionPrompts = nil
		self.claimPrompt = nil
		self.boostUuidCache = nil
		self.gcCache = nil
		self.gcScanning = false
		self.watchCheckedAt = 0
	end

	return DiamondMountain
end)()

getgenv().VRT_DiamondMountain = DiamondMountain

local DM_FEATURES = {
	{ id = "autoFarm", name = "Auto Farm" },
	{ id = "breakTrail", name = "Break Trail Chests" },
	{ id = "fightYeti", name = "Fight The Yeti" },
	{ id = "feedYeti", name = "Feed The Yeti" },
	{ id = "fillWalls", name = "Fill Rubble Walls" },
	{ id = "buyEgg", name = "Buy Mountain Egg" },
	{ id = "merchant", name = "Buy From Traveling Merchant" },
	{ id = "sendExpedition", name = "Send Pets On Expeditions" },
	{ id = "claimExpedition", name = "Claim Expeditions" },
	{ id = "teleportCamp", name = "Teleport To Camp" },
	{ id = "artifacts", name = "Find Mountain Artifacts" },
	{ id = "buyUpgrades", name = "Buy Mountain Upgrades" },
	{ id = "useBoosts", name = "Use Mountain Boosts" },
	{ id = "optimize", name = "Optimize Diamond Mountain" },
}

local function ensureDmInstance()
	if vrt.dmInstance then
		return vrt.dmInstance
	end
	local ok, instance = pcall(DiamondMountain.new)
	if not ok then
		return nil, "Init lỗi: " .. tostring(instance)
	end
	vrt.dmInstance = instance
	pcall(function()
		instance:setMaxCamp(settings.DMMaxCamp or 6)
	end)
	return instance
end

-- -----------------------------------------------------
-- UI.
-- -----------------------------------------------------
local rayfieldOk, rayfield = pcall(function()
	return loadstring(game:HttpGet("https://sirius.menu/rayfield"))()
end)

if not rayfieldOk or typeof(rayfield) ~= "table" then
	getgenv().VRT_LOADED = nil
	return warn("[VRT] Không load được Rayfield: " .. tostring(rayfield))
end

local windowOk, window = pcall(function()
	return rayfield:CreateWindow({
		Name = "VRT PET SIM 99",
		LoadingTitle = "VRT PET SIM 99",
		LoadingSubtitle = "v" .. vrt.Version,
		ConfigurationSaving = { Enabled = true, FolderName = "VRT_PS99", FileName = "Config" },
		Discord = { Enabled = true, Invite = "JwfXeX9gjw", RememberJoins = true },
		KeySystem = false,
	})
end)

if not windowOk or not window then
	getgenv().VRT_LOADED = nil
	return warn("[VRT] CreateWindow thất bại: " .. tostring(window))
end

local function safeTab(name, icon)
	local ok, tab = pcall(function()
		return window:CreateTab(name, icon)
	end)
	if ok and tab then
		return tab
	end
	warn("[VRT] Không tạo được tab: " .. name)
	return nil
end

local tabs = {
	farm = safeTab("Auto-Farm", "dollar-sign"),
	keys = safeTab("Auto Keys/Tickets", "box"),
	eggs = safeTab("Eggs", "egg"),
	auto = safeTab("Auto", "settings"),
	update = safeTab("Update", "refresh-cw"),
	rank = safeTab("Auto-Rank", "dollar-sign"),
	event = safeTab("Event", "mountain"),
	secret = safeTab("Admin Abuse", "shield"),
	mailbox = safeTab("Mailbox", "mail"),
}

local wheelsDropdown, chestsDropdown, giftsDropdown, lootboxDropdown
local fruitDropdown, fruitUpgradeDropdown, enchantRarityDropdown

local function refreshAllDropdowns()
	invalidateSaveCache()
	clearDerivedCache()
	BreakablePositions.data = nil
	BreakablePositions.timestamp = 0
	breakablePositionCache = setmetatable({}, { __mode = "k" })
	EggPositions.data = nil
	EggPositions.timestamp = 0
	eggPositionCache = setmetatable({}, { __mode = "k" })
	PetsCache.data = nil
	PetsCache.timestamp = 0
	ZoneCache.data = nil
	ZoneCache.timestamp = 0
	pcall(function()
		if wheelsDropdown then
			wheelsDropdown:Refresh(buildOptions(getDirectoryIds("SpinnyWheels")))
		end
		if chestsDropdown then
			chestsDropdown:Refresh(buildOptions(getChestNames()))
		end
		if giftsDropdown then
			giftsDropdown:Refresh(buildOptions(getGiftIds()))
		end
		if lootboxDropdown then
			lootboxDropdown:Refresh(buildOptions(getLootboxIds()))
		end
		if fruitDropdown then
			fruitDropdown:Refresh(buildOptions(getBucketIds("Fruit")))
		end
		if fruitUpgradeDropdown then
			fruitUpgradeDropdown:Refresh(buildOptions(getDirectoryIds("Fruits")))
		end
		if enchantRarityDropdown then
			enchantRarityDropdown:Refresh(buildOptions(getEnchantRarities()))
		end
	end)
end

getgenv().VRT_RefreshDropdowns = refreshAllDropdowns

-- ================= AUTO-FARM =================
if tabs.farm then
	tabs.farm:CreateSection("Farming Section")

	tabs.farm:CreateSlider({
		Name = "Fast Farm Cooldown (only for Heartbeat one)",
		Range = { 0.05, 1 },
		Increment = 0.01,
		Suffix = "s",
		CurrentValue = settings.FastFarmCooldown,
		Flag = "FastFarmCooldown",
		Callback = function(value)
			settings.FastFarmCooldown = value
			queueSave()
		end,
	})

	tabs.farm:CreateToggle({
		Name = "Fast Farm (Heartbeat)",
		CurrentValue = settings.FastFarmHeartbeat,
		Flag = "FastFarmHeartbeat",
		Callback = function(value)
			settings.FastFarmHeartbeat = value
			queueSave()
			bindConnection("FastFarmHeartbeat", runService.Heartbeat, Core.FastFarm)
		end,
	})

	tabs.farm:CreateToggle({
		Name = "Fast Farm (While loop)",
		CurrentValue = settings.FastFarmLoop,
		Flag = "FastFarmLoop",
		Callback = toggleLoop("FastFarmLoop", 0.15, Core.FastFarm),
	})

	tabs.farm:CreateToggle({
		Name = "Auto Collect Orbs",
		CurrentValue = settings.CollectOrbs,
		Flag = "CollectOrbs",
		Callback = toggleLoop("CollectOrbs", 0.3, Core.CollectOrbs),
	})

	tabs.farm:CreateSection("Click Aura")

	tabs.farm:CreateToggle({
		Name = "Click Aura",
		CurrentValue = settings.ClickAura,
		Flag = "ClickAura",
		Callback = function(value)
			settings.ClickAura = value
			queueSave()
			bindConnection("ClickAura", runService.Heartbeat, Core.ClickAura, 0.15)
		end,
	})

	tabs.farm:CreateSlider({
		Name = "Click Aura Radius",
		Range = { 10, 150 },
		Increment = 5,
		Suffix = "Studs",
		CurrentValue = settings.ClickAuraRadius,
		Flag = "ClickAuraRadius",
		Callback = function(value)
			settings.ClickAuraRadius = value
			queueSave()
		end,
	})

	tabs.farm:CreateToggle({
		Name = "Click Aura Visualizer",
		CurrentValue = settings.ClickAuraViz,
		Flag = "ClickAuraViz",
		Callback = function(value)
			settings.ClickAuraViz = value
			queueSave()
			if value then
				startLoop("ClickAuraViz", 0.1, Core.ClickAuraViz)
			else
				stopLoop("ClickAuraViz")
				Core.ClickAuraViz()
			end
		end,
	})

	tabs.farm:CreateSection("Optimize")

	tabs.farm:CreateToggle({
		Name = "Inf Pet Speed",
		CurrentValue = settings.InfinitePetSpeed,
		Flag = "InfinitePetSpeed",
		Callback = function(value)
			settings.InfinitePetSpeed = value
			queueSave()
			Core.InfinitePetSpeed(value)
		end,
	})

	tabs.farm:CreateToggle({
		Name = "Optimize Pets",
		CurrentValue = settings.OptimizePets,
		Flag = "OptimizePets",
		Callback = toggleLoop("OptimizePets", 10, Core.OptimizePets),
	})

	tabs.farm:CreateButton({
		Name = "Optimize Breakables",
		Callback = function()
			Core.OptimizeBreakables()
		end,
	})
end

-- ================= AUTO KEYS / TICKETS =================
if tabs.keys then
	tabs.keys:CreateSection("Spinny Wheels Section")

	wheelsDropdown = tabs.keys:CreateDropdown({
		Name = "Select Which Spinny Wheels To Spin",
		Options = buildOptions(getDirectoryIds("SpinnyWheels")),
		CurrentOption = settings.SelectedWheels,
		MultipleOptions = true,
		Flag = "SelectedWheels",
		Callback = function(option)
			settings.SelectedWheels = option
			queueSave()
		end,
	})

	tabs.keys:CreateToggle({
		Name = "Spin Selected Wheels",
		CurrentValue = settings.SpinWheels,
		Flag = "SpinWheels",
		Callback = toggleLoop("SpinWheels", 0.35, Core.SpinWheels),
	})

	tabs.keys:CreateSection("Chests Section")

	chestsDropdown = tabs.keys:CreateDropdown({
		Name = "Select Which Chests To Open",
		Options = buildOptions(getChestNames()),
		CurrentOption = settings.SelectedChests,
		MultipleOptions = true,
		Flag = "SelectedChests",
		Callback = function(option)
			settings.SelectedChests = option
			queueSave()
		end,
	})

	tabs.keys:CreateToggle({
		Name = "Open Selected Chests",
		CurrentValue = settings.OpenChests,
		Flag = "OpenChests",
		Callback = toggleLoop("OpenChests", 1, Core.OpenChests),
	})

	tabs.keys:CreateSection("Keys Section")

	tabs.keys:CreateToggle({
		Name = "Combine Keys All at Once",
		CurrentValue = settings.CombineKeysAll,
		Flag = "CombineKeysAll",
		Callback = toggleLoop("CombineKeysAll", 3, Core.CombineKeysAll),
	})

	tabs.keys:CreateToggle({
		Name = "Combine Keys One at Once",
		CurrentValue = settings.CombineKeysOnce,
		Flag = "CombineKeysOnce",
		Callback = toggleLoop("CombineKeysOnce", 1.5, Core.CombineKeysOnce),
	})

	tabs.keys:CreateSection("Gift Bags Section")

	giftsDropdown = tabs.keys:CreateDropdown({
		Name = "Select Which Gift Bags To Open",
		Options = buildOptions(getGiftIds()),
		CurrentOption = settings.SelectedGifts,
		MultipleOptions = true,
		Flag = "SelectedGifts",
		Callback = function(option)
			settings.SelectedGifts = option
			queueSave()
		end,
	})

	tabs.keys:CreateToggle({
		Name = "Open Selected Gift Bags",
		CurrentValue = settings.OpenGifts,
		Flag = "OpenGifts",
		Callback = toggleLoop("OpenGifts", 1, Core.OpenGiftBags),
	})

	tabs.keys:CreateSection("Lootboxes Section")

	lootboxDropdown = tabs.keys:CreateDropdown({
		Name = "Select Which Lootboxes To Open",
		Options = buildOptions(getLootboxIds()),
		CurrentOption = settings.SelectedLootboxes,
		MultipleOptions = true,
		Flag = "SelectedLootboxes",
		Callback = function(option)
			settings.SelectedLootboxes = option
			queueSave()
		end,
	})

	tabs.keys:CreateToggle({
		Name = "Open Selected Lootboxes",
		CurrentValue = settings.OpenLootboxes,
		Flag = "OpenLootboxes",
		Callback = toggleLoop("OpenLootboxes", 1.5, Core.OpenLootboxes),
	})

	tabs.keys:CreateSection("Fruits Section")

	fruitDropdown = tabs.keys:CreateDropdown({
		Name = "Select Fruits to Use",
		Options = buildOptions(getBucketIds("Fruit")),
		CurrentOption = settings.SelectedFruits,
		MultipleOptions = true,
		Flag = "SelectedFruits",
		Callback = function(option)
			settings.SelectedFruits = option
			queueSave()
		end,
	})

	tabs.keys:CreateToggle({
		Name = "Use Selected Fruits (Max)",
		CurrentValue = settings.ConsumeFruits,
		Flag = "ConsumeFruits",
		Callback = function(value)
			settings.ConsumeFruits = value
			queueSave()
			if value then
				startLoop("ConsumeFruits", 3, Core.ConsumeFruits)
			else
				stopLoop("ConsumeFruits")
			end
		end,
	})

	tabs.keys:CreateSection("Secret Keys Section")

	tabs.keys:CreateToggle({
		Name = "Farm Treehouse Merchant",
		CurrentValue = settings.FarmTreehouse,
		Flag = "FarmTreehouse",
		Callback = toggleLoop("FarmTreehouse", 5, Core.FarmTreehouse),
	})

	tabs.keys:CreateButton({
		Name = "Unlock Treehouse",
		Callback = function()
			invoke("SecretRoom_Unlock", TREEHOUSE_ROOM)
		end,
	})

	tabs.keys:CreateButton({
		Name = "Enter Treehouse",
		Callback = function()
			invoke("Instancing_PlayerEnterInstance", TREEHOUSE_ID)
		end,
	})

	tabs.keys:CreateButton({
		Name = "Leave Treehouse",
		Callback = function()
			fire("Instancing_PlayerLeaveInstance", TREEHOUSE_ID)
		end,
	})
end

-- ================= EGGS =================
if tabs.eggs then
	tabs.eggs:CreateSection("Notification")

	tabs.eggs:CreateToggle({
		Name = "Show Egg Notification (random color)",
		CurrentValue = settings.EggNotification,
		Flag = "EggNotification",
		Callback = function(value)
			settings.EggNotification = value
			queueSave()
		end,
	})

	tabs.eggs:CreateSection("Egg Opening")

	tabs.eggs:CreateToggle({
		Name = "Hide Egg Animation",
		CurrentValue = settings.HideEggAnim,
		Flag = "HideEggAnim",
		Callback = function(value)
			settings.HideEggAnim = value
			queueSave()
		end,
	})

	tabs.eggs:CreateToggle({
		Name = "Auto Open Closest Egg (Max)",
		CurrentValue = settings.OpenEgg,
		Flag = "OpenEgg",
		Callback = function(value)
			settings.OpenEgg = value
			queueSave()
			if value then
				startLoop("OpenEgg", 0.3, Core.OpenEgg)
			else
				stopLoop("OpenEgg")
			end
		end,
	})

	tabs.eggs:CreateToggle({
		Name = "Auto Hatch (game feature)",
		CurrentValue = settings.AutoHatch,
		Flag = "AutoHatch",
		Callback = function(value)
			settings.AutoHatch = value
			queueSave()
			Core.ToggleAutoHatch()
		end,
	})

	tabs.eggs:CreateSection("Utility")

	tabs.eggs:CreateButton({
		Name = "Refresh Dropdowns",
		Callback = function()
			clearDirectoryCache()
			refreshAllDropdowns()
			rayfield:Notify({ Title = "VRT", Content = "Đã refresh dropdowns", Duration = 3 })
		end,
	})

	tabs.eggs:CreateButton({
		Name = "Print Egg Hatch Stats",
		Callback = function()
			local save = getSaveCached()
			if not save then
				return
			end
			print(("[VRT] EggHatchCount = %d"):format(save.EggHatchCount or 0))
			print(("[VRT] EggSlotsPurchased = %d"):format(save.EggSlotsPurchased or 0))
			print(("[VRT] GetMaxHatch() = %d"):format(getMaxHatch()))
		end,
	})
end

-- ================= AUTO =================
if tabs.auto then
	tabs.auto:CreateToggle({
		Name = "Auto Daycare (Claim and Enroll)",
		CurrentValue = settings.Daycare,
		Flag = "Daycare",
		Callback = toggleLoop("Daycare", 60, Core.Daycare),
	})

	tabs.auto:CreateToggle({
		Name = "Buy Pet Slots",
		CurrentValue = settings.PetSlots,
		Flag = "PetSlots",
		Callback = toggleLoop("PetSlots", 10, Core.BuyPetSlots),
	})

	tabs.auto:CreateToggle({
		Name = "Buy Egg Slots",
		CurrentValue = settings.AutoEggSlots,
		Flag = "AutoEggSlots",
		Callback = toggleLoop("AutoEggSlots", 10, Core.BuyEggSlots),
	})

	tabs.auto:CreateToggle({
		Name = "Buy Next Zone",
		CurrentValue = settings.Zones,
		Flag = "Zones",
		Callback = toggleLoop("Zones", 2, Core.BuyZone),
	})

	tabs.auto:CreateToggle({
		Name = "Use Ultimate",
		CurrentValue = settings.Ultimate,
		Flag = "Ultimate",
		Callback = toggleLoop("Ultimate", 2, Core.UseUltimate),
	})

	tabs.auto:CreateToggle({
		Name = "Auto Free Gifts",
		CurrentValue = settings.FreeGifts,
		Flag = "FreeGifts",
		Callback = toggleLoop("FreeGifts", 60, Core.ClaimFreeGifts),
	})

	tabs.auto:CreateToggle({
		Name = "Collect Shiny Relics",
		CurrentValue = settings.Relics,
		Flag = "Relics",
		Callback = toggleLoop("Relics", 5, Core.CollectRelics),
	})

	tabs.auto:CreateButton({
		Name = "Equip Best Pets",
		Callback = function()
			Core.EquipBest()
		end,
	})

	tabs.auto:CreateSection("Flags")

	local initialFlag = settings.SelectedFlag
	if not table.find(FLAGS, initialFlag) then
		initialFlag = FLAGS[1]
		settings.SelectedFlag = initialFlag
		queueSave()
	end

	tabs.auto:CreateDropdown({
		Name = "Select Flag To Use",
		Options = FLAGS,
		CurrentOption = { initialFlag },
		MultipleOptions = false,
		Flag = "SelectedFlag",
		Callback = function(option)
			settings.SelectedFlag = option[1]
			queueSave()
			vrt.flagWarned = {}
		end,
	})

	tabs.auto:CreateLabel("Flag Amount = MAX (tự tính theo inventory + game cap)")

	tabs.auto:CreateToggle({
		Name = "Use Selected Flag",
		CurrentValue = settings.UseSelectedFlag,
		Flag = "UseSelectedFlag",
		Callback = function(value)
			settings.UseSelectedFlag = value
			queueSave()
			vrt.flagWarned = {}
			if value then
				startLoop("UseSelectedFlag", 2, Core.ActivateFlag)
			else
				stopLoop("UseSelectedFlag")
			end
		end,
	})

	tabs.auto:CreateButton({
		Name = "Print Flag Info",
		Callback = function()
			print(("[VRT] Flags: %d"):format(#FLAGS))
			for _, flagId in ipairs(FLAGS) do
				local entry = findInventoryEntry(flagId)
				local owned = entry and (entry._am or 0) or 0
				local max = Core.GetFlagMaxAmount(flagId)
				print(("[VRT]   %s | owned=%d | max=%d"):format(flagId, owned, max))
			end
			if Modules.FlexibleFlagCmds and Modules.FlexibleFlagCmds.GetActiveFlag then
				local ok, active = pcall(Modules.FlexibleFlagCmds.GetActiveFlag)
				print(("[VRT] Active flag: %s"):format(ok and tostring(active) or "error"))
			end
		end,
	})

	tabs.auto:CreateSection("Discord Webhook")

	tabs.auto:CreateInput({
		Name = "Webhook URL",
		PlaceholderText = "https://discord.com/api/webhooks/...",
		CurrentValue = settings.WebhookUrl,
		RemoveTextAfterFocusLost = false,
		Flag = "WebhookUrl",
		Callback = function(value)
			settings.WebhookUrl = value
			queueSave()
		end,
	})

	tabs.auto:CreateToggle({
		Name = "Send Webhook on Script Load",
		CurrentValue = settings.WebhookEnabled,
		Flag = "WebhookEnabled",
		Callback = function(value)
			settings.WebhookEnabled = value
			queueSave()
		end,
	})

	tabs.auto:CreateButton({
		Name = "Test Webhook Now",
		Callback = function()
			if settings.WebhookUrl == "" then
				rayfield:Notify({
					Title = "Webhook",
					Content = "Chưa có URL.",
					Duration = 5,
				})
				return
			end
			sendExecutionWebhook()
			rayfield:Notify({
				Title = "Webhook",
				Content = "Đã gửi. Kiểm tra Discord.",
				Duration = 4,
			})
		end,
	})
end

-- ================= UPDATE =================
if tabs.update then
	tabs.update:CreateSection("Fruits")

	fruitUpgradeDropdown = tabs.update:CreateDropdown({
		Name = "Select Fruits To Upgrade",
		Options = buildOptions(getDirectoryIds("Fruits")),
		CurrentOption = settings.SelectedFruitUpgrade,
		MultipleOptions = true,
		Flag = "SelectedFruitUpgrade",
		Callback = function(option)
			settings.SelectedFruitUpgrade = option
			queueSave()
		end,
	})

	tabs.update:CreateToggle({
		Name = "Upgrade Selected Fruits",
		CurrentValue = settings.UpgradeFruits,
		Flag = "UpgradeFruits",
		Callback = toggleLoop("UpgradeFruits", 2, function()
			Core.UpgradeFruits(false)
		end),
	})

	tabs.update:CreateToggle({
		Name = "Upgrade Shiny Fruits Only",
		CurrentValue = settings.UpgradeFruitsShiny,
		Flag = "UpgradeFruitsShiny",
		Callback = toggleLoop("UpgradeFruitsShiny", 2, function()
			Core.UpgradeFruits(true)
		end),
	})

	tabs.update:CreateButton({
		Name = "Upgrade Fruits Now",
		Callback = function()
			Core.UpgradeFruits(false)
		end,
	})

	tabs.update:CreateSection("Potions")

	tabs.update:CreateToggle({
		Name = "Upgrade All Potions (Bulk)",
		CurrentValue = settings.UpgradePotions,
		Flag = "UpgradePotions",
		Callback = toggleLoop("UpgradePotions", 2, Core.UpgradePotions),
	})

	tabs.update:CreateButton({
		Name = "Upgrade Potions Now",
		Callback = function()
			Core.UpgradePotions()
		end,
	})

	tabs.update:CreateSection("Enchants")

	enchantRarityDropdown = tabs.update:CreateDropdown({
		Name = "Select Enchant Rarity",
		Options = buildOptions(getEnchantRarities()),
		CurrentOption = settings.SelectedEnchantRarity,
		MultipleOptions = true,
		Flag = "SelectedEnchantRarity",
		Callback = function(option)
			settings.SelectedEnchantRarity = option
			queueSave()
		end,
	})

	tabs.update:CreateToggle({
		Name = "Upgrade All Enchants",
		CurrentValue = settings.UpgradeEnchants,
		Flag = "UpgradeEnchants",
		Callback = toggleLoop("UpgradeEnchants", 2, Core.UpgradeEnchants),
	})

	tabs.update:CreateButton({
		Name = "Upgrade Enchants Now",
		Callback = function()
			Core.UpgradeEnchants()
		end,
	})

	tabs.update:CreateToggle({
		Name = "Empower Selected Rarity",
		CurrentValue = settings.EmpowerEnchants,
		Flag = "EmpowerEnchants",
		Callback = toggleLoop("EmpowerEnchants", 2, Core.EmpowerEnchants),
	})

	tabs.update:CreateButton({
		Name = "Scrap Selected Rarity",
		Callback = function()
			Core.ScrapEnchants()
		end,
	})
end

-- ================= AUTO-RANK =================
if tabs.rank then
	tabs.rank:CreateSection("Ranking Section")

	tabs.rank:CreateToggle({
		Name = "Auto Claim Rank Rewards",
		CurrentValue = settings.RankRewards,
		Flag = "RankRewards",
		Callback = toggleLoop("RankRewards", 5, Core.ClaimRankRewards),
	})

	local AUTO_RANK_URL = "https://raw.githubusercontent.com/ryomolochiton/367/refs/heads/main/AutoRank.lua"

	local function loadAutoRank()
		if vrt.autoRankFunc then
			return vrt.autoRankFunc
		end
		local ok, source = pcall(game.HttpGet, game, AUTO_RANK_URL)
		if not ok or typeof(source) ~= "string" then
			return nil, "Không tải được script Auto Rank"
		end
		local chunk, err = loadstring(source, "AutoRank")
		if not chunk then
			return nil, "Compile lỗi: " .. tostring(err)
		end
		local okRun, result = pcall(chunk)
		if not okRun then
			return nil, "Chạy lỗi: " .. tostring(result)
		end
		if typeof(result) == "function" then
			vrt.autoRankFunc = result
			return result
		end
		vrt.autoRankFunc = function() end
		return vrt.autoRankFunc
	end

	tabs.rank:CreateButton({
		Name = "Access Auto Rank",
		Callback = function()
			local func, err = loadAutoRank()
			rayfield:Notify({
				Title = "Auto Rank",
				Content = func and "Đã load Auto Rank module." or (err or "Load thất bại"),
				Duration = func and 4 or 8,
			})
		end,
	})

	tabs.rank:CreateLabel("Auto Rank is free for now.\nlast update: 28.04.2026", "refresh-cw")

	tabs.rank:CreateToggle({
		Name = "Auto Rank",
		CurrentValue = settings.AutoRank,
		Flag = "AutoRank",
		Callback = function(value)
			settings.AutoRank = value
			queueSave()
			if not value then
				stopLoop("AutoRank")
				return
			end
			local func, err = loadAutoRank()
			if not func then
				settings.AutoRank = false
				queueSave()
				rayfield:Notify({
					Title = "Auto Rank",
					Content = err or "Load thất bại",
					Duration = 8,
				})
				return
			end
			startLoop("AutoRank", 2, func)
		end,
	})
end

-- ================= EVENT (Diamond Mountain — embedded) =================
if tabs.event then
	tabs.event:CreateSection("Diamond Mountain")

	tabs.event:CreateButton({
		Name = "Join Diamond Mountain",
		Callback = function()
			local instance, err = ensureDmInstance()
			if not instance then
				rayfield:Notify({
					Title = "Diamond Mountain",
					Content = err or "Không tạo được instance",
					Duration = 8,
				})
				return
			end
			local ok, message = instance:joinEvent()
			rayfield:Notify({
				Title = "Diamond Mountain",
				Content = ok and "Đang vào instance..." or (message or "Join thất bại"),
				Duration = 5,
			})
		end,
	})

	tabs.event:CreateButton({
		Name = "Reload Remotes",
		Callback = function()
			local instance, err = ensureDmInstance()
			if not instance then
				rayfield:Notify({
					Title = "Diamond Mountain",
					Content = err or "Không tạo được instance",
					Duration = 8,
				})
				return
			end
			pcall(instance.resolveRemotes, instance)
			local missing = instance:getMissingRemotes()
			rayfield:Notify({
				Title = "Diamond Mountain",
				Content = #missing == 0 and "Đã resolve đủ remotes." or ("Thiếu: " .. table.concat(missing, ", ")),
				Duration = 5,
			})
		end,
	})

	tabs.event:CreateSection("Auto Farm Controls")

	tabs.event:CreateSlider({
		Name = "Max Camp (Auto Farm)",
		Range = { 1, 6 },
		Increment = 1,
		Suffix = "camp",
		CurrentValue = settings.DMMaxCamp,
		Flag = "DMMaxCamp",
		Callback = function(value)
			settings.DMMaxCamp = value
			queueSave()
			if vrt.dmInstance then
				pcall(vrt.dmInstance.setMaxCamp, vrt.dmInstance, value)
			end
		end,
	})

	tabs.event:CreateSlider({
		Name = "Manual Teleport Camp",
		Range = { 1, 6 },
		Increment = 1,
		Suffix = "camp",
		CurrentValue = 1,
		Flag = "DMCampIndex",
		Callback = function(value)
			if vrt.dmInstance then
				pcall(vrt.dmInstance.setCampIndex, vrt.dmInstance, value)
			end
		end,
	})

	tabs.event:CreateButton({
		Name = "Reset Camp Cache",
		Callback = function()
			if vrt.dmInstance then
				pcall(vrt.dmInstance.resetCampCache, vrt.dmInstance)
				rayfield:Notify({
					Title = "Diamond Mountain",
					Content = "Đã xoá cache camp.",
					Duration = 3,
				})
			end
		end,
	})

	tabs.event:CreateButton({
		Name = "Print Farm Info",
		Callback = function()
			if not vrt.dmInstance then
				print("[VRT] Diamond Mountain chưa khởi tạo")
				return
			end
			local ok, info = pcall(vrt.dmInstance.getFarmInfo, vrt.dmInstance)
			if not ok or typeof(info) ~= "table" then
				print("[VRT] getFarmInfo error")
				return
			end
			print(("[VRT] Farm Camp    = %s"):format(tostring(info.farmCamp)))
			print(("[VRT] Pending Camp = %s"):format(tostring(info.pendingCamp)))
			print(("[VRT] Current Camp = %s"):format(tostring(info.currentCamp)))
			print(("[VRT] Highest Open = %s"):format(tostring(info.highestOpen)))
			print(("[VRT] Max Camp     = %s"):format(tostring(info.maxCamp)))
		end,
	})

	tabs.event:CreateSection("Features")

	for _, feature in ipairs(DM_FEATURES) do
		tabs.event:CreateToggle({
			Name = feature.name,
			CurrentValue = false,
			Flag = "DM_" .. feature.id,
			Callback = function(value)
				local inst = ensureDmInstance()
				if not inst then
					return
				end
				if value then
					inst:start(feature.id)
				else
					inst:stop(feature.id)
				end
			end,
		})
	end

	tabs.event:CreateSection("Utility")

	tabs.event:CreateButton({
		Name = "Print Status",
		Callback = function()
			if not vrt.dmInstance then
				print("[VRT] Diamond Mountain chưa khởi tạo")
				return
			end
			local statuses = vrt.dmInstance:getStatus()
			for id, status in pairs(statuses) do
				print(("[VRT] %s: %s"):format(id, tostring(status)))
			end
		end,
	})

	tabs.event:CreateButton({
		Name = "Print Missing Remotes",
		Callback = function()
			if not vrt.dmInstance then
				print("[VRT] Diamond Mountain chưa khởi tạo")
				return
			end
			local missing = vrt.dmInstance:getMissingRemotes()
			if #missing == 0 then
				print("[VRT] Đủ remotes.")
				return
			end
			print(("[VRT] Thiếu %d remotes:"):format(#missing))
			for _, key in ipairs(missing) do
				print("  " .. key)
			end
		end,
	})

	tabs.event:CreateButton({
		Name = "Stop All Features",
		Callback = function()
			if vrt.dmInstance then
				pcall(vrt.dmInstance.stopAll, vrt.dmInstance)
			end
		end,
	})
end

-- ================= ADMIN ABUSE =================
if tabs.secret then
	tabs.secret:CreateSection("Admin Abuse Section")

	tabs.secret:CreateButton({
		Name = "Claim Hidden Exclusive Egg",
		Callback = function()
			Core.ClaimFakeCharacters()
		end,
	})

	tabs.secret:CreateButton({
		Name = "Claim Rank Rewards Now",
		Callback = function()
			Core.ClaimRankRewards()
		end,
	})

	tabs.secret:CreateSection("Anti-Cheat")

	tabs.secret:CreateButton({
		Name = "Print AC Status",
		Callback = function()
			print(("[VRT] Blunder bypass: %s"):format(AntiCheat.active and "ACTIVE" or "INACTIVE"))
			print(("[VRT] Original key: %s"):format(AntiCheat.originalKey and "cached" or "none"))
			print(("[VRT] Blocked count: %d"):format(AntiCheat.blockedCount))
			if AntiCheat.lastBlocked then
				print(("[VRT] Last blocked: %s"):format(tostring(AntiCheat.lastBlocked.message)))
			end
			local clean, issues = reqCheck()
			print(("[VRT] Request clean: %s | issues: %s"):format(
				tostring(clean), table.concat(issues, ",")
			))
		end,
	})

	tabs.secret:CreateToggle({
		Name = "Log Blocked AC Messages",
		CurrentValue = false,
		Flag = "ACLogBlocked",
		Callback = function(value)
			AntiCheat.logBlocked = value
		end,
	})

	tabs.secret:CreateButton({
		Name = "Print AC Blocked Stats",
		Callback = function()
			print(("[VRT] Blocked count: %d"):format(AntiCheat.blockedCount))
			if AntiCheat.lastBlocked then
				local lb = AntiCheat.lastBlocked
				print(("[VRT] Last: type=%s | msg=%s | %ds ago"):format(
					tostring(lb.messageType),
					tostring(lb.message),
					math.floor(os.clock() - lb.time)
				))
			else
				print("[VRT] No blocked messages yet.")
			end
		end,
	})

	tabs.secret:CreateButton({
		Name = "Reinstall Blunder Bypass",
		Callback = function()
			AntiCheat.originalKey = nil
			local ok = installBlunderBypass()
			rayfield:Notify({
				Title = "Anti-Cheat",
				Content = ok and "Đã cài lại bypass." or "Cài đặt thất bại.",
				Duration = 4,
			})
		end,
	})

	tabs.secret:CreateSection("Performance")

	tabs.secret:CreateButton({
		Name = "Print Cache Stats",
		Callback = function()
			local save = getSaveCached()
			local inventorySize = 0
			if save and typeof(save.Inventory) == "table" then
				for _, bucket in pairs(save.Inventory) do
					if typeof(bucket) == "table" then
						for _ in pairs(bucket) do
							inventorySize += 1
						end
					end
				end
			end
			print(("[VRT] Save cached: %s"):format(SaveCache.data and "yes" or "no"))
			print(("[VRT] Inventory size: %d"):format(inventorySize))
			print(("[VRT] Indexed buckets: all except Pet"))
			print(("[VRT] Breakables cached: %d"):format(BreakablePositions.data and #BreakablePositions.data or 0))
			print(("[VRT] Eggs cached: %d"):format(EggPositions.data and #EggPositions.data or 0))
			print(("[VRT] Pets cached: %d"):format(PetsCache.data and #PetsCache.data or 0))
			print(("[VRT] Active loops: %d"):format((function()
				local n = 0
				for _ in pairs(vrt.loops) do n += 1 end
				return n
			end)()))
			if vrt.dmInstance then
				print(("[VRT] DM learnDone: %s"):format(vrt.dmInstance.learnDone and "yes" or "no"))
				print(("[VRT] DM hook active: %s"):format(vrt.dmInstance.hookNamecall and "yes" or "no"))
			else
				print("[VRT] DM instance: not created (lazy)")
			end
		end,
	})

	tabs.secret:CreateButton({
		Name = "Clear All Caches",
		Callback = function()
			invalidateSaveCache()
			clearDirectoryCache()
			clearDerivedCache()
			PetsCache.data = nil
			PetsCache.timestamp = 0
			BreakablePositions.data = nil
			BreakablePositions.timestamp = 0
			breakablePositionCache = setmetatable({}, { __mode = "k" })
			EggPositions.data = nil
			EggPositions.timestamp = 0
			eggPositionCache = setmetatable({}, { __mode = "k" })
			ZoneCache.data = nil
			ZoneCache.timestamp = 0
			maxHatchCache.timestamp = 0
			rayfield:Notify({ Title = "VRT", Content = "Đã xoá tất cả cache", Duration = 3 })
		end,
	})
end

-- ================= MAILBOX =================
if tabs.mailbox then
	tabs.mailbox:CreateInput({
		Name = "Input Username",
		PlaceholderText = "Input Username",
		CurrentValue = settings.MailboxUsername,
		RemoveTextAfterFocusLost = false,
		Flag = "MailboxUsername",
		Callback = function(value)
			settings.MailboxUsername = value
			queueSave()
		end,
	})

	tabs.mailbox:CreateDropdown({
		Name = "Send Huges Mode",
		Options = { "New", "All" },
		CurrentOption = { settings.MailboxHugeMode },
		MultipleOptions = false,
		Flag = "MailboxHugeMode",
		Callback = function(option)
			settings.MailboxHugeMode = option[1]
			vrt.sentHuges = {}
			queueSave()
		end,
	})

	tabs.mailbox:CreateToggle({
		Name = "Send Huges By Mode",
		CurrentValue = settings.MailboxSendHuges,
		Flag = "MailboxSendHuges",
		Callback = toggleLoop("MailboxSendHuges", 10, Core.MailboxSendHuges),
	})

	tabs.mailbox:CreateToggle({
		Name = "Auto Claim Mailbox",
		CurrentValue = settings.MailboxClaim,
		Flag = "MailboxClaim",
		Callback = toggleLoop("MailboxClaim", 10, Core.MailboxClaimAll),
	})

	tabs.mailbox:CreateButton({
		Name = "Claim All Now",
		Callback = function()
			Core.MailboxClaimAll()
			rayfield:Notify({ Title = "VRT", Content = "Claiming mailbox...", Duration = 3 })
		end,
	})

	tabs.mailbox:CreateButton({
		Name = "Reset Sent Huges",
		Callback = function()
			vrt.sentHuges = {}
			rayfield:Notify({ Title = "VRT", Content = "Đã reset danh sách huge đã gửi", Duration = 3 })
		end,
	})

	tabs.mailbox:CreateSection("Config")

	tabs.mailbox:CreateButton({
		Name = "Save Config Now",
		Callback = function()
			saveConfig()
			rayfield:Notify({
				Title = "Config",
				Content = "Đã lưu vào " .. CONFIG_PATH,
				Duration = 4,
			})
		end,
	})

	tabs.mailbox:CreateButton({
		Name = "Reset Config",
		Callback = function()
			pcall(function()
				if isfile(CONFIG_PATH) then
					delfile(CONFIG_PATH)
				end
			end)
			rayfield:Notify({
				Title = "Config",
				Content = "Đã xoá config. Restart script để về mặc định.",
				Duration = 5,
			})
		end,
	})
end

-- -----------------------------------------------------
-- Refresh dropdowns after save load
-- -----------------------------------------------------
task.spawn(function()
	task.wait(3)
	pcall(refreshAllDropdowns)
	print("[VRT] Dropdowns refreshed.")
end)

-- -----------------------------------------------------
-- Apply saved toggles.
-- -----------------------------------------------------
task.spawn(function()
	task.wait(2)

	if settings.FastFarmHeartbeat then
		bindConnection("FastFarmHeartbeat", runService.Heartbeat, Core.FastFarm)
	end
	if settings.ClickAura then
		bindConnection("ClickAura", runService.Heartbeat, Core.ClickAura, 0.15)
	end
	if settings.FastFarmLoop then
		startLoop("FastFarmLoop", 0.15, Core.FastFarm)
	end
	if settings.CollectOrbs then
		startLoop("CollectOrbs", 0.3, Core.CollectOrbs)
	end
	if settings.ClickAuraViz then
		startLoop("ClickAuraViz", 0.1, Core.ClickAuraViz)
	end
	if settings.OptimizePets then
		startLoop("OptimizePets", 10, Core.OptimizePets)
	end
	if settings.SpinWheels then
		startLoop("SpinWheels", 0.35, Core.SpinWheels)
	end
	if settings.OpenChests then
		startLoop("OpenChests", 1, Core.OpenChests)
	end
	if settings.CombineKeysAll then
		startLoop("CombineKeysAll", 3, Core.CombineKeysAll)
	end
	if settings.CombineKeysOnce then
		startLoop("CombineKeysOnce", 1.5, Core.CombineKeysOnce)
	end
	if settings.OpenGifts then
		startLoop("OpenGifts", 1, Core.OpenGiftBags)
	end
	if settings.OpenLootboxes then
		startLoop("OpenLootboxes", 1.5, Core.OpenLootboxes)
	end
	if settings.ConsumeFruits then
		startLoop("ConsumeFruits", 3, Core.ConsumeFruits)
	end
	if settings.FarmTreehouse then
		startLoop("FarmTreehouse", 5, Core.FarmTreehouse)
	end
	if settings.OpenEgg then
		startLoop("OpenEgg", 0.3, Core.OpenEgg)
	end
	if settings.Daycare then
		startLoop("Daycare", 60, Core.Daycare)
	end
	if settings.PetSlots then
		startLoop("PetSlots", 10, Core.BuyPetSlots)
	end
	if settings.AutoEggSlots then
		startLoop("AutoEggSlots", 10, Core.BuyEggSlots)
	end
	if settings.Zones then
		startLoop("Zones", 2, Core.BuyZone)
	end
	if settings.Ultimate then
		startLoop("Ultimate", 2, Core.UseUltimate)
	end
	if settings.FreeGifts then
		startLoop("FreeGifts", 60, Core.ClaimFreeGifts)
	end
	if settings.Relics then
		startLoop("Relics", 5, Core.CollectRelics)
	end
	if settings.RankRewards then
		startLoop("RankRewards", 5, Core.ClaimRankRewards)
	end
	if settings.UpgradeFruits then
		startLoop("UpgradeFruits", 2, function()
			Core.UpgradeFruits(false)
		end)
	end
	if settings.UpgradeFruitsShiny then
		startLoop("UpgradeFruitsShiny", 2, function()
			Core.UpgradeFruits(true)
		end)
	end
	if settings.UpgradePotions then
		startLoop("UpgradePotions", 2, Core.UpgradePotions)
	end
	if settings.UpgradeEnchants then
		startLoop("UpgradeEnchants", 2, Core.UpgradeEnchants)
	end
	if settings.EmpowerEnchants then
		startLoop("EmpowerEnchants", 2, Core.EmpowerEnchants)
	end
	if settings.MailboxSendHuges then
		startLoop("MailboxSendHuges", 10, Core.MailboxSendHuges)
	end
	if settings.MailboxClaim then
		startLoop("MailboxClaim", 10, Core.MailboxClaimAll)
	end
	if settings.InfinitePetSpeed then
		Core.InfinitePetSpeed(true)
	end
	if settings.UseSelectedFlag then
		startLoop("UseSelectedFlag", 2, Core.ActivateFlag)
	end

	print("[VRT] Config restored.")
end)

-- -----------------------------------------------------
-- Unload.
-- -----------------------------------------------------
getgenv().VRT_Unload = function()
	getgenv().VRT_LOADED = false
	for flag, connection in pairs(vrt.connections) do
		pcall(function()
			connection:Disconnect()
		end)
		vrt.connections[flag] = nil
	end
	for flag in pairs(vrt.loops) do
		vrt.loops[flag] = nil
	end
	Core.ClickAuraViz()
	Core.InfinitePetSpeed(false)
	if vrt.optimizeConnection then
		pcall(function()
			vrt.optimizeConnection:Disconnect()
		end)
		vrt.optimizeConnection = nil
	end
	if vrt.dmInstance then
		pcall(vrt.dmInstance.destroy, vrt.dmInstance)
		vrt.dmInstance = nil
	end

	if AntiCheat.originalKey then
		pcall(function()
			local blunderMessage = require(replicatedStorage:WaitForChild("Blunder", 5):WaitForChild("BlunderMessage", 5))
			pcall(setreadonly, blunderMessage, false)
			blunderMessage.key = AntiCheat.originalKey
			pcall(setreadonly, blunderMessage, true)
		end)
		AntiCheat.originalKey = nil
		AntiCheat.active = false
	end

	if eggFrontend and getgenv().VRT_ORIGINAL_PLAY_EGG then
		pcall(function()
			eggFrontend.PlayEggAnimation = getgenv().VRT_ORIGINAL_PLAY_EGG
		end)
	end

	pcall(saveConfig)

	pcall(function()
		notifyGui:Destroy()
	end)
	pcall(function()
		rayfield:Destroy()
	end)
	print("[VRT] Unloaded.")
end

-- -----------------------------------------------------
-- Send execution webhook.
-- -----------------------------------------------------
task.spawn(function()
	task.wait(2)
	pcall(sendExecutionWebhook)
end)

print(("[VRT] v%s | flags=%d | AC=%s | DM=embedded | id=4"):format(
	vrt.Version, #FLAGS, AntiCheat.active and "ON" or "OFF"
))