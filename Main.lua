-- =====================================================
-- VRT HUB — PET SIMULATOR 99 v1.9.8
-- Bỏ hết button "once/now", chỉ giữ toggle
-- Flag: chỉ dùng khi trong zone, không teleport
-- Egg hook: stacked TextLabel, dòng mới đẩy dòng cũ lên
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
local utilFolder = libraryFolder:FindFirstChild("Util")
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
	if not okHook1 then
		table.insert(issues, "FH1_ERR")
	elseif hooked1 then
		table.insert(issues, "FH1_HOOKED")
	end
	if typeof(getgenv().request) == "function" then
		local okHook2, hooked2 = pcall(isfunctionhooked, getgenv().request)
		if not okHook2 then
			table.insert(issues, "FH2_ERR")
		elseif hooked2 then
			table.insert(issues, "FH2_HOOKED")
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
		AntiCheat.lastBlocked = { message = message, messageType = messageType, time = os.clock() }
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
	CustomEggsCmds = safeRequire(clientFolder:FindFirstChild("CustomEggsCmds")),
	HatchingCmds = safeRequire(clientFolder:FindFirstChild("HatchingCmds")),
	DaycareCmds = safeRequire(clientFolder:FindFirstChild("DaycareCmds")),
	PetEquipCmds = safeRequire(clientFolder:FindFirstChild("PetEquipCmds")),
	UltimateCmds = safeRequire(clientFolder:FindFirstChild("UltimateCmds")),
	ZoneCmds = safeRequire(clientFolder:FindFirstChild("ZoneCmds")),
	MapCmds = safeRequire(clientFolder:FindFirstChild("MapCmds")),
	LootboxCmds = safeRequire(clientFolder:FindFirstChild("LootboxCmds")),
	FruitCmds = safeRequire(clientFolder:FindFirstChild("FruitCmds")),
	RankCmds = safeRequire(clientFolder:FindFirstChild("RankCmds")),
	RebirthCmds = safeRequire(clientFolder:FindFirstChild("RebirthCmds")),
	FlexibleFlagCmds = safeRequire(clientFolder:FindFirstChild("FlexibleFlagCmds")),
	ZoneFlagCmds = safeRequire(clientFolder:FindFirstChild("ZoneFlagCmds")),
	PlayerPet = safeRequire(clientFolder:FindFirstChild("PlayerPet")),
	Balancing = safeRequire(clientFolder:FindFirstChild("Balancing")),
	NotificationCmds = safeRequire(clientFolder:FindFirstChild("NotificationCmds")),
	InstancingCmds = safeRequire(clientFolder:FindFirstChild("InstancingCmds")),
	InstanceZoneCmds = safeRequire(clientFolder:FindFirstChild("InstanceZoneCmds")),
	MasteryCmds = safeRequire(clientFolder:FindFirstChild("MasteryCmds")),
	CurrencyCmds = safeRequire(clientFolder:FindFirstChild("CurrencyCmds")),
	DiamondMountainCmds = safeRequire(clientFolder:FindFirstChild("DiamondMountainCmds")),
	MachineScreens = safeRequire(clientFolder:FindFirstChild("MachineScreens")),
	WorldsUtil = safeRequire(utilFolder and utilFolder:FindFirstChild("WorldsUtil")),
	ZonesUtil = safeRequire(utilFolder and utilFolder:FindFirstChild("ZonesUtil")),
	EggsUtil = safeRequire(utilFolder and utilFolder:FindFirstChild("EggsUtil")),
	MerchantUtil = safeRequire(utilFolder and utilFolder:FindFirstChild("MerchantUtil")),
	TravelingMerchantUtil = safeRequire(utilFolder and utilFolder:FindFirstChild("TravelingMerchantUtil")),
	DiamondMountainMerchant = safeRequire(utilFolder and utilFolder:FindFirstChild("DiamondMountainMerchant")),
	DaycareUtil = safeRequire(utilFolder and utilFolder:FindFirstChild("DaycareUtil")),
	Ranks = safeRequire(directoryFolder:FindFirstChild("Ranks")),
	FreeGifts = safeRequire(directoryFolder:FindFirstChild("FreeGifts")),
	EggsDir = safeRequire(directoryFolder:FindFirstChild("Eggs")),
	ZonesDir = safeRequire(directoryFolder:FindFirstChild("Zones")),
	PetsDir = safeRequire(directoryFolder:FindFirstChild("Pets")),
	ZoneFlagsDir = safeRequire(directoryFolder:FindFirstChild("ZoneFlags")),
	MerchantsDir = safeRequire(directoryFolder:FindFirstChild("Merchants")),
	Items = safeRequire(libraryFolder:FindFirstChild("Items")),
}

local network = Modules.Network

local function invoke(name, ...)
	if not network or not network.Invoke then return false end
	local ok, result = pcall(network.Invoke, name, ...)
	if ok then return true, result end
	if typeof(result) == "string" and result:find("assertion failed") then
		return pcall(network.Invoke, network, name, ...)
	end
	return false, result
end

local function fire(name, ...)
	if not network or not network.Fire then return false end
	local ok, result = pcall(network.Fire, name, ...)
	if ok then return true, result end
	if typeof(result) == "string" and result:find("assertion failed") then
		return pcall(network.Fire, network, name, ...)
	end
	return false, result
end

local function unreliable(name, ...)
	if not network or not network.UnreliableFire then return false end
	local ok, result = pcall(network.UnreliableFire, name, ...)
	if ok then return true, result end
	if typeof(result) == "string" and result:find("assertion failed") then
		return pcall(network.UnreliableFire, network, name, ...)
	end
	return false, result
end

-- -----------------------------------------------------
-- Settings.
-- -----------------------------------------------------
local vrt = getgenv().VRT or {}
getgenv().VRT = vrt
vrt.Version = "1.9.8"
vrt.connections = {}
vrt.loops = {}
vrt.fruitLog = {}
vrt.customEggMap = {}

local settings = vrt.Settings or {}
vrt.Settings = settings

local defaults = {
	ClickAuraRadius = 75,
	ClickAuraCooldown = 0.016,
	FastFarmCooldown = 0.2,
	FastFarmHeartbeat = false,
	FastFarmLoop = false,
	CollectOrbs = false,
	ClickAura = false,
	ClickAuraViz = false,
	OpenEgg = false,
	OpenSelectedEgg = false,
	SelectedEggId = "",
	BuySelectedCustomEgg = false,
	SelectedCustomEggUuid = "",
	HideEggAnim = false,
	HookEggAnimation = false,
	InfinitePetSpeed = false,
	OptimizePets = false,
	AntiLag = false,
	Daycare = false,
	PetSlots = false,
	AutoEggSlots = false,
	Zones = false,
	Rebirth = false,
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
	AutoTimeTrial = false,
	FarmTreehouse = false,
	UpgradeFruits = false,
	UpgradeFruitsShiny = false,
	UpgradePotions = false,
	UpgradeEnchants = false,
	EmpowerEnchants = false,
	CardCombine = false,
	FusePets = false,
	FuseAmount = 5,
	GoldMachine = false,
	RainbowMachine = false,
	CoinJar = false,
	Comet = false,
	AutoRank = false,
	SelectedFlag = "Coins Flag",
	AutoUseFlagInZone = false,
	FlagAmount = 45,
	AutoMerchant = false,
	MerchantReturnToPos = true,
	AutoClaimExpedition = false,
	ExpeditionFallbackTeleport = true,
	DMMaxCamp = 6,
	FarmPoint = nil,
	UseFarmPoint = false,
	DMFarmPoint = nil,
	UseDMFarmPoint = false,
	DMAutoJoin = false,
	AdminAbuse = false,
	WebhookUrl = "",
	WebhookEnabled = false,
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
-- CONFIG
-- -----------------------------------------------------
local CONFIG_FOLDER = "VRT"
local CONFIG_PATH = "VRT/PS99_Config.json"

local PERSIST_KEYS = {
	"ClickAuraRadius", "ClickAuraCooldown", "FastFarmCooldown",
	"FastFarmHeartbeat", "FastFarmLoop", "CollectOrbs",
	"ClickAura", "ClickAuraViz",
	"OpenEgg", "OpenSelectedEgg", "SelectedEggId",
	"BuySelectedCustomEgg", "SelectedCustomEggUuid",
	"HideEggAnim", "HookEggAnimation",
	"InfinitePetSpeed", "OptimizePets", "AntiLag",
	"Daycare", "PetSlots", "AutoEggSlots", "Zones", "Rebirth", "Ultimate",
	"FreeGifts", "RankRewards",
	"MailboxClaim", "MailboxSendHuges", "MailboxUsername", "MailboxHugeMode",
	"Relics", "SpinWheels", "OpenChests",
	"CombineKeysAll", "CombineKeysOnce",
	"OpenGifts", "OpenLootboxes", "ConsumeFruits",
	"AutoTimeTrial",
	"FarmTreehouse",
	"UpgradeFruits", "UpgradeFruitsShiny",
	"UpgradePotions", "UpgradeEnchants", "EmpowerEnchants",
	"CardCombine", "FusePets", "FuseAmount", "GoldMachine", "RainbowMachine",
	"CoinJar", "Comet",
	"AutoRank",
	"SelectedFlag", "AutoUseFlagInZone", "FlagAmount",
	"AutoMerchant", "MerchantReturnToPos",
	"AutoClaimExpedition", "ExpeditionFallbackTeleport",
	"DMMaxCamp", "UseFarmPoint", "UseDMFarmPoint",
	"DMAutoJoin", "AdminAbuse",
	"WebhookUrl", "WebhookEnabled",
}

local TABLE_KEYS = {
	"SelectedWheels", "SelectedChests", "SelectedGifts",
	"SelectedLootboxes", "SelectedFruits",
	"SelectedFruitUpgrade", "SelectedEnchantRarity",
	"FarmPoint", "DMFarmPoint",
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
	if not isfile(CONFIG_PATH) then return end
	pcall(function()
		local decoded = httpService:JSONDecode(readfile(CONFIG_PATH))
		if typeof(decoded) ~= "table" then return end
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
	if saveQueued then return end
	saveQueued = true
	task.delay(1, function()
		saveQueued = false
		saveConfig()
	end)
end

getgenv().VRT_SaveConfig = saveConfig
getgenv().VRT_LoadConfig = loadConfig

-- -----------------------------------------------------
-- STATIC DATA
-- -----------------------------------------------------
local FLAGS = {
	"Coins Flag", "Diamonds Flag", "Exotic Treasure Flag",
	"Fortune Flag", "Golden Flag", "Hasty Flag",
	"Magnet Flag", "Rainbow Flag", "Shiny Flag", "Strength Flag",
}

local OPTIMIZE_SIZE = Vector3.new(2.5, 2.5, 2.5)
local OPTIMIZE_MATERIAL = Enum.Material.SmoothPlastic
local VIZ_ROTATION = CFrame.Angles(0, 0, math.rad(90))
local TREEHOUSE_ID = "TreehouseMerchant"
local TREEHOUSE_ROOM = "Treehouse Merchant"
local LOOTBOX_BATCH = 8

local function cleanupTreehouseModels()
	local playerGui = localPlayer:FindFirstChild("PlayerGui")
	if not playerGui then return end
	for _, child in ipairs(playerGui:GetChildren()) do
		if child:IsA("Model") and child.Name == TREEHOUSE_ID then
			child:Destroy()
		end
	end
end

-- -----------------------------------------------------
-- SAVE CACHE + INVENTORY INDEX
-- -----------------------------------------------------
local SKIP_BUCKETS = { Pet = true }
local SaveCache = { data = nil, timestamp = 0, ttl = 2 }
local InventoryIndex = { byId = {}, uidById = {}, bucketIds = {}, timestamp = 0, ttl = 5, dirty = true }

local function getSaveCached()
	local now = os.clock()
	if SaveCache.data and (now - SaveCache.timestamp) < SaveCache.ttl then
		return SaveCache.data
	end
	if not Modules.Save or not Modules.Save.Get then return nil end
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
	local byId, uidById, bucketIds = {}, {}, {}
	for bucketName, bucket in pairs(save.Inventory) do
		if not SKIP_BUCKETS[bucketName] and typeof(bucket) == "table" then
			local ids, seen = {}, {}
			for uid, entry in pairs(bucket) do
				if typeof(entry) == "table" and typeof(entry.id) == "string" then
					byId[entry.id] = entry
					uidById[entry.id] = uid
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
	InventoryIndex.uidById = uidById
	InventoryIndex.bucketIds = bucketIds
	InventoryIndex.timestamp = now
	InventoryIndex.dirty = false
	return InventoryIndex
end

local function findInventoryEntry(itemId)
	if not itemId or itemId == "" then return nil end
	local index = buildInventoryIndex()
	return index.byId[itemId]
end

local function findInventoryUid(itemId)
	if not itemId or itemId == "" then return nil end
	local index = buildInventoryIndex()
	return index.uidById[itemId]
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
	if cached then return cached end
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

local function getEggNumberById(eggId)
	if not eggNumberCache then getEggIdByNumber(0) end
	for num, id in pairs(eggNumberCache or {}) do
		if id == eggId then return num end
	end
	return nil
end

local function getMaxHatch()
	if Modules.EggCmds and Modules.EggCmds.GetMaxHatch then
		local ok, value = pcall(Modules.EggCmds.GetMaxHatch)
		if ok and typeof(value) == "number" and value > 0 then
			return value
		end
	end
	return 1
end

-- -----------------------------------------------------
-- ZONE CACHE
-- -----------------------------------------------------
local ZoneCache = { data = nil, timestamp = 0, ttl = 1 }

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

local function getInstanceInfo()
	if Modules.MapCmds and Modules.MapCmds.GetCurrentInstanceInfo then
		local ok, info = pcall(Modules.MapCmds.GetCurrentInstanceInfo)
		if ok and typeof(info) == "table" then
			return info
		end
	end
	return nil
end

-- -----------------------------------------------------
-- Webhook
-- -----------------------------------------------------
local function sendWebhook(url, payload)
	if not url or url == "" then return false end
	local clean, issues = reqCheck()
	if not clean then
		warn("[VRT] Webhook bị skip, request có vấn đề:", table.concat(issues, ","))
		return false
	end
	local ok, body = pcall(httpService.JSONEncode, httpService, payload)
	if not ok then return false end
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
	if not settings.WebhookEnabled or settings.WebhookUrl == "" then return end
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
-- Hide Egg Anim (RenderStepped — max frequency)
-- -----------------------------------------------------
vrt.eggGuiConnections = {}

local function hideEggGuis()
	local playerGui = localPlayer:FindFirstChild("PlayerGui")
	if not playerGui then return end
	local target = playerGui:FindFirstChild("EggOpenAnimation")
	if target and target:IsA("ScreenGui") then
		if target.Enabled then
			target.Enabled = false
		end
	end
	for _, name in ipairs({ "HatchSettings", "LootMessage" }) do
		local gui = playerGui:FindFirstChild(name)
		if gui and gui:IsA("ScreenGui") and gui.Enabled then
			gui.Enabled = false
		end
	end
end

runService.RenderStepped:Connect(function()
	if not getgenv().VRT_LOADED then return end
	if not settings.HideEggAnim then return end
	local playerGui = localPlayer:FindFirstChild("PlayerGui")
	if not playerGui then return end
	local target = playerGui:FindFirstChild("EggOpenAnimation")
	if target and target:IsA("ScreenGui") and target.Enabled then
		target.Enabled = false
	end
end)

-- -----------------------------------------------------
-- EGG ANIMATION HOOK (stacked messages, newest at bottom)
-- -----------------------------------------------------
local eggHookState = {
	frontend = nil,
	path = nil,
	funcName = nil,
	hook = nil,
	callOriginal = nil,
	hookedTargets = setmetatable({}, { __mode = "k" }),
	thread = nil,
}

local eggMsgGui = nil
local eggMsgContainer = nil
local eggMsgList = {}

local EGG_MSG_MAX = 6
local EGG_MSG_HEIGHT = 38
local EGG_MSG_ANCHOR_Y = 0.62

local function cleanupStaleEggGuis()
	local playerGui = localPlayer:FindFirstChild("PlayerGui")
	if not playerGui then return end
	for _, child in ipairs(playerGui:GetChildren()) do
		if child.Name == "VRT_EggMsg" then
			pcall(function() child:Destroy() end)
		end
	end
end

-- Message mới nhất nằm ở dưới cùng, cũ bị đẩy lên trên.
local function relayoutEggMessages()
	local n = #eggMsgList
	for i, entry in ipairs(eggMsgList) do
		local label = entry.label
		if label and label.Parent then
			local offset = -(n - i) * EGG_MSG_HEIGHT
			label.Position = UDim2.new(0.5, 0, 0, offset)
		end
	end
end

local function createEggMsgLabel()
	local label = Instance.new("TextLabel")
	label.Name = "Message"
	label.AnchorPoint = Vector2.new(0.5, 1)
	label.Position = UDim2.new(0.5, 0, 0, 0)
	label.Size = UDim2.new(0, 900, 0, EGG_MSG_HEIGHT)
	label.BackgroundTransparency = 1
	label.BorderSizePixel = 0
	label.Font = Enum.Font.GothamBlack
	label.TextSize = 30
	label.TextScaled = false
	label.TextWrapped = false
	label.TextXAlignment = Enum.TextXAlignment.Center
	label.TextYAlignment = Enum.TextYAlignment.Center
	label.TextStrokeTransparency = 0
	label.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	label.TextColor3 = Color3.fromRGB(255, 255, 255)
	label.RichText = false
	label.Text = ""
	label.ZIndex = 2
	label.Parent = eggMsgContainer

	local stroke = Instance.new("UIStroke")
	stroke.Name = "Outline"
	stroke.Color = Color3.fromRGB(0, 0, 0)
	stroke.Thickness = 2
	stroke.Transparency = 0
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	stroke.Parent = label

	return label, stroke
end

local function ensureEggMsgGui()
	local playerGui = localPlayer:FindFirstChild("PlayerGui")
	if not playerGui then return end

	if eggMsgGui and eggMsgGui.Parent == playerGui
		and eggMsgContainer and eggMsgContainer.Parent then
		return
	end

	cleanupStaleEggGuis()
	eggMsgGui = nil
	eggMsgContainer = nil
	eggMsgList = {}

	eggMsgGui = Instance.new("ScreenGui")
	eggMsgGui.Name = "VRT_EggMsg"
	eggMsgGui.ResetOnSpawn = false
	eggMsgGui.IgnoreGuiInset = true
	eggMsgGui.DisplayOrder = 999
	eggMsgGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	eggMsgGui.Parent = playerGui

	eggMsgContainer = Instance.new("Frame")
	eggMsgContainer.Name = "Container"
	eggMsgContainer.AnchorPoint = Vector2.new(0.5, 1)
	eggMsgContainer.Position = UDim2.new(0.5, 0, EGG_MSG_ANCHOR_Y, 0)
	eggMsgContainer.Size = UDim2.new(0, 900, 0, EGG_MSG_HEIGHT * EGG_MSG_MAX)
	eggMsgContainer.BackgroundTransparency = 1
	eggMsgContainer.BorderSizePixel = 0
	eggMsgContainer.Parent = eggMsgGui
end

local function pushEggMessage(eggName)
	pcall(function()
		ensureEggMsgGui()
		if not eggMsgContainer then return end

		local maxHatch = getMaxHatch()
		local color = Color3.fromRGB(math.random(0, 255), math.random(0, 255), math.random(0, 255))

		while #eggMsgList >= EGG_MSG_MAX do
			local oldest = table.remove(eggMsgList, 1)
			if oldest and oldest.label then
				pcall(function() oldest.label:Destroy() end)
			end
		end

		local label, stroke = createEggMsgLabel()
		label.Text = "Still Openin " .. tostring(eggName) .. " " .. tostring(maxHatch)
		label.TextColor3 = color
		label.TextTransparency = 0
		label.TextStrokeTransparency = 0

		local entry = { label = label, stroke = stroke }
		table.insert(eggMsgList, entry)
		relayoutEggMessages()

		task.delay(3, function()
			local idx = table.find(eggMsgList, entry)
			if not idx then return end

			local info = TweenInfo.new(0.5)
			if label and label.Parent then
				tweenService:Create(label, info, {
					TextTransparency = 1,
					TextStrokeTransparency = 1,
				}):Play()
			end
			if stroke and stroke.Parent then
				tweenService:Create(stroke, info, { Transparency = 1 }):Play()
			end

			task.delay(0.55, function()
				local i2 = table.find(eggMsgList, entry)
				if i2 then
					table.remove(eggMsgList, i2)
				end
				if label then pcall(function() label:Destroy() end) end
				relayoutEggMessages()
			end)
		end)
	end)
end

local function destroyEggMsgGui()
	if eggMsgGui then
		pcall(function() eggMsgGui:Destroy() end)
	end
	eggMsgGui = nil
	eggMsgContainer = nil
	eggMsgList = {}
end

local function findEggFrontend()
	local paths = {
		{ "PlayerScripts", "Scripts", "Game", "Egg Opening Frontend" },
		{ "PlayerScripts", "Scripts", "Core", "Egg Opening Frontend" },
		{ "PlayerScripts", "PlayerModule", "Egg Opening Frontend" },
	}
	for _, path in ipairs(paths) do
		local node = localPlayer
		for _, name in ipairs(path) do
			node = node and node:FindFirstChild(name)
		end
		if node then
			local ok, env = pcall(getsenv, node)
			if ok and typeof(env) == "table" then
				eggHookState.frontend = env
				eggHookState.path = table.concat(path, ".")
				return true
			end
		end
	end
	return false
end

local function applyEggHook()
	local env = eggHookState.frontend
	if not env then
		if not findEggFrontend() then return false end
		env = eggHookState.frontend
		if not env then return false end
	end

	local funcName = eggHookState.funcName
	if not funcName or typeof(env[funcName]) ~= "function" then
		funcName = nil
		for _, name in ipairs({ "PlayEggAnimation", "PlayAnimation", "PlayEgg", "PlayHatch" }) do
			if typeof(env[name]) == "function" then
				funcName = name
				break
			end
		end
	end
	if not funcName then return false end
	eggHookState.funcName = funcName

	if not eggHookState.hook then
		local hook = function(eggName, ...)
			if settings.HideEggAnim then pcall(hideEggGuis) end
			if settings.HookEggAnimation then
				pushEggMessage(eggName)
				return
			end
			local call = eggHookState.callOriginal
			if call then
				return call(eggName, ...)
			end
		end
		pcall(setstackhidden, hook, true)
		pcall(debug.setinfo, hook, "s", "[C]")
		pcall(debug.setinfo, hook, "n", "")
		eggHookState.hook = hook
	end

	local target = env[funcName]
	if target == eggHookState.hook then return true end
	if eggHookState.hookedTargets[target] then return true end

	eggHookState.hookedTargets[target] = true
	local ok, restored = pcall(hookfunction, target, newcclosure(eggHookState.hook))
	if not ok then
		ok, restored = pcall(hookfunction, target, eggHookState.hook)
	end
	if ok and typeof(restored) == "function" then
		if not eggHookState.callOriginal then
			eggHookState.callOriginal = restored
		end
		return true
	end

	eggHookState.hookedTargets[target] = nil
	if not eggHookState.callOriginal then
		eggHookState.callOriginal = target
	end
	pcall(function() env[funcName] = eggHookState.hook end)
	return true
end

local function installEggHook()
	if not eggHookState.frontend then findEggFrontend() end
	return applyEggHook()
end

local function startEggHookLoop()
	if eggHookState.thread then return end
	eggHookState.thread = task.spawn(function()
		while getgenv().VRT_LOADED do
			if settings.HookEggAnimation or settings.HideEggAnim then
				pcall(applyEggHook)
				task.wait(0.1)
			else
				task.wait(0.5)
			end
		end
		eggHookState.thread = nil
	end)
end

task.spawn(function()
	for _ = 1, 10 do
		if eggHookState.frontend then break end
		findEggFrontend()
		task.wait(1)
	end
	startEggHookLoop()
end)

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

local function getOwnedPetUids()
	local uids = {}
	if Modules.PlayerPet and Modules.PlayerPet.GetAll then
		local ok, pets = pcall(Modules.PlayerPet.GetAll)
		if ok and typeof(pets) == "table" then
			for _, pet in pairs(pets) do
				if typeof(pet) == "table" and pet.owner == localPlayer then
					local uid = pet.euid or pet.uid
					if uid then table.insert(uids, uid) end
				end
			end
		end
	end
	return uids
end

local function getDmMountain()
	local things = workspace:FindFirstChild("__THINGS")
	local container = things and things:FindFirstChild("__INSTANCE_CONTAINER")
	local active = container and container:FindFirstChild("Active")
	return active and active:FindFirstChild("DiamondMountain")
end

local function getBreakZones()
	local mountain = getDmMountain()
	return mountain and mountain:FindFirstChild("BREAK_ZONES")
end

local function getExpedition()
	local mountain = getDmMountain()
	if not mountain then return nil end
	local summit = mountain:FindFirstChild("Summit")
	return summit and summit:FindFirstChild("Expedition")
end

local function getClaimPillar()
	local expedition = getExpedition()
	return expedition and expedition:FindFirstChild("ClaimPillar")
end

-- -----------------------------------------------------
-- BREAKABLE POSITIONS
-- -----------------------------------------------------
local BreakablePositions = { data = nil, timestamp = 0, ttl = 2 }
local breakablePositionCache = setmetatable({}, { __mode = "k" })

local function getBreakablePositions()
	local now = os.clock()
	if BreakablePositions.data and (now - BreakablePositions.timestamp) < BreakablePositions.ttl then
		return BreakablePositions.data
	end
	local folder = getBreakableFolder()
	if not folder then return {} end
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
-- EGG POSITIONS
-- -----------------------------------------------------
local EggPositions = { data = nil, timestamp = 0, ttl = 2 }
local eggPositionCache = setmetatable({}, { __mode = "k" })

local function getEggPositions()
	local now = os.clock()
	if EggPositions.data and (now - EggPositions.timestamp) < EggPositions.ttl then
		return EggPositions.data
	end
	local things = workspace:FindFirstChild("__THINGS")
	if not things then return {} end
	local worldName
	if Modules.WorldsUtil and Modules.WorldsUtil.GetEggsModelName then
		local ok, name = pcall(Modules.WorldsUtil.GetEggsModelName)
		worldName = ok and name or nil
	end
	if not worldName then return {} end
	local list = {}
	local function scanContainer(container)
		if not container then return end
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

local GIFT_BAG_NAMES = {
	["Gift Bag"] = true,
	["Large Gift Bag"] = true,
	["Diamond Gift Bag"] = true,
	["Global Event Gift"] = true,
	["Free Gift Bag"] = true,
	["Party Box"] = true,
}

local function isGiftBagId(id)
	if GIFT_BAG_NAMES[id] then return true end
	if id:find("Gift Bag", 1, true) then return true end
	return false
end

local function getGiftIds()
	return memoize("gifts", function()
		local gifts, seen = {}, {}
		local misc = directFolder and directFolder:FindFirstChild("MiscItems")
		local categorized = misc and misc:FindFirstChild("Categorized")
		local giftsFolder = categorized and categorized:FindFirstChild("Gifts")
		if giftsFolder then
			for _, child in ipairs(giftsFolder:GetChildren()) do
				local id
				local ok, data = pcall(require, child)
				if ok and typeof(data) == "table" and data._id then
					id = data._id
				else
					local parts = string.split(child.Name, " | ")
					id = parts[2] or child.Name
				end
				if id and id ~= "" and not seen[id] then
					seen[id] = true
					table.insert(gifts, id)
				end
			end
		end
		if #gifts == 0 then
			for _, id in ipairs(getBucketIds("Misc")) do
				if isGiftBagId(id) and not seen[id] then
					seen[id] = true
					table.insert(gifts, id)
				end
			end
		end
		table.sort(gifts)
		return gifts
	end)
end

local function getLibraryDirIds(folderName)
	local ids, seen = {}, {}
	local folder = directoryFolder and directoryFolder:FindFirstChild(folderName)
	if folder then
		for _, child in ipairs(folder:GetChildren()) do
			local id
			local ok, data = pcall(require, child)
			if ok and typeof(data) == "table" and data._id then
				id = data._id
			else
				id = child.Name
			end
			if id and id ~= "" and not seen[id] then
				seen[id] = true
				table.insert(ids, id)
			end
		end
		table.sort(ids)
	end
	return ids
end

local function getLootboxIds()
	return memoize("lootboxes", function()
		local list, seen = {}, {}
		local function addAll(src)
			if typeof(src) ~= "table" then return end
			for _, id in ipairs(src) do
				if id and id ~= "" and not seen[id] then
					seen[id] = true
					table.insert(list, id)
				end
			end
		end
		addAll(getLibraryDirIds("Lootboxes"))
		addAll(getDirectoryIds("Lootboxes"))
		addAll(getBucketIds("Lootbox"))
		table.sort(list)
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

local function getEggIdList()
	return memoize("eggIds", function()
		local ids = {}
		for _, egg in pairs(Modules.EggsDir or {}) do
			if typeof(egg) == "table" and egg._id then
				table.insert(ids, egg._id)
			end
		end
		table.sort(ids)
		return ids
	end)
end

local function getCustomEggOptions()
	return memoize("customEggs", function()
		local options = {}
		vrt.customEggMap = {}
		local cmds = Modules.CustomEggsCmds
		if cmds and typeof(cmds.All) == "function" then
			local ok, data = pcall(cmds.All)
			if ok and typeof(data) == "table" then
				for uid, egg in pairs(data) do
					if typeof(egg) == "table" and egg._hatchable == true then
						local name = egg._id or egg.name or uid
						local display = name .. " | " .. tostring(uid):sub(1, 8)
						vrt.customEggMap[display] = {
							uid = uid,
							name = name,
							position = egg._position,
						}
						table.insert(options, display)
					end
				end
			end
		end
		table.sort(options)
		return options
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
-- Anti-AFK
-- -----------------------------------------------------
task.spawn(function()
	if getgenv().VRT_AntiAFK then return end
	getgenv().VRT_AntiAFK = true
	local function kill(signal)
		local ok, conns = pcall(getconnections, signal)
		if not ok or typeof(conns) ~= "table" then return end
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
			pcall(function() idleScript.Enabled = false end)
		end
	end)
	fire("Idle Tracking: Stop Timer")
	local ok, virtualUser = pcall(game.GetService, game, "VirtualUser")
	if not ok then return end
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
-- Core
-- -----------------------------------------------------
local Core = {}

local closestBuffer = {}
local petDataBuffer = {}

Core.FastFarm = function()
	local root = getRoot()
	if not root then return end
	if settings.UseFarmPoint and typeof(settings.FarmPoint) == "table" then
		local fp = settings.FarmPoint
		if fp.x and fp.y and fp.z then
			local targetPos = Vector3.new(fp.x, fp.y, fp.z)
			if (root.Position - targetPos).Magnitude > 15 then
				root.CFrame = CFrame.new(targetPos)
				return
			end
		end
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
	if breakableCount == 0 then return end
	local uids = getOwnedPetUids()
	if #uids == 0 then return end
	table.clear(petDataBuffer)
	for _, uid in ipairs(uids) do
		petDataBuffer[uid] = closestBuffer[math.random(1, breakableCount)]
	end
	fire("Breakables_JoinPetBulk", petDataBuffer)
end

Core.CollectOrbs = function()
	local things = workspace:FindFirstChild("__THINGS")
	local orbs = things and things:FindFirstChild("Orbs")
	if not orbs then return end
	for _, orb in ipairs(orbs:GetChildren()) do
		local orbId = tonumber(orb.Name)
		if orbId then
			fire("Orbs: Collect", { orbId })
			orb:Destroy()
		end
	end
end

local clickAuraCache = { names = {}, rootPos = nil, timestamp = 0, ttl = 0.08 }

Core.ClickAura = function()
	local root = getRoot()
	if not root then return end
	local rootPos = root.Position
	local radius = settings.ClickAuraRadius
	local radiusSq = radius * radius
	local now = os.clock()
	local cache = clickAuraCache
	local stale = (now - cache.timestamp) > cache.ttl
	local movedFar = cache.rootPos and (cache.rootPos - rootPos).Magnitude > 8
	if stale or movedFar then
		local breakables = getBreakablePositions()
		local names = {}
		for _, item in ipairs(breakables) do
			local dx = item.position.X - rootPos.X
			local dy = item.position.Y - rootPos.Y
			local dz = item.position.Z - rootPos.Z
			if dx * dx + dy * dy + dz * dz <= radiusSq then
				names[#names + 1] = item.name
			end
		end
		cache.names = names
		cache.rootPos = rootPos
		cache.timestamp = now
	end
	for _, name in ipairs(cache.names) do
		unreliable("Breakables_PlayerDealDamage", name)
	end
end

Core.ClickAuraViz = function()
	local root = getRoot()
	if not root then return end
	local viz = workspace:FindFirstChild("M")
	if not settings.ClickAuraViz then
		if viz then viz:Destroy() end
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

local function hatchCustomEgg(uuid)
	if not uuid or uuid == "" then return 0 end
	local maxHatch = getMaxHatch()

	local okBatch, result = invoke("CustomEggs_Hatch", uuid, maxHatch)
	if okBatch and result == true then
		return maxHatch
	end

	local total = 0
	for i = 1, maxHatch do
		local ok = invoke("CustomEggs_Hatch", uuid)
		if not ok then break end
		total += 1
		if i < maxHatch then task.wait(0.08) end
	end
	return total
end

Core.OpenEgg = function()
	local root = getRoot()
	if not root then return end
	local rootPos = root.Position

	local customEgg, customDist = nil, math.huge
	local cmds = Modules.CustomEggsCmds
	if cmds and typeof(cmds.All) == "function" then
		local ok, list = pcall(cmds.All)
		if ok and typeof(list) == "table" then
			for uid, egg in pairs(list) do
				if typeof(egg) == "table" and egg._hatchable == true and egg._position then
					local d = (egg._position - rootPos).Magnitude
					if d < customDist then
						customEgg, customDist = uid, d
					end
				end
			end
		end
	end

	local normalEgg, normalDist = nil, math.huge
	local eggs = getEggPositions()
	for _, egg in ipairs(eggs) do
		local d = (egg.position - rootPos).Magnitude
		if d < normalDist then
			normalEgg, normalDist = egg, d
		end
	end

	if not customEgg and not normalEgg then return end

	if customEgg and customDist <= normalDist then
		hatchCustomEgg(customEgg)
	elseif normalEgg then
		local eggId = getEggIdByNumber(normalEgg.eggNumber)
		if not eggId then return end
		invoke("Eggs_RequestPurchase", eggId, getMaxHatch())
	end
end

Core.OpenSelectedEgg = function()
	local eggId = settings.SelectedEggId
	if not eggId or eggId == "" then return end
	invoke("Eggs_RequestPurchase", eggId, getMaxHatch())
end

Core.BuySelectedCustomEgg = function()
	local uuid = settings.SelectedCustomEggUuid
	if not uuid or uuid == "" then return end
	hatchCustomEgg(uuid)
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
	if not petsFolder then return end
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
	if vrt.optimizeConnection then return end
	local debrisFolder = workspace:FindFirstChild("__DEBRIS")
	if not debrisFolder then return end
	vrt.optimizeConnection = debrisFolder.ChildAdded:Connect(function(child)
		pcall(function()
			debrisService:AddItem(child, 0)
		end)
	end)
end

local ANTILAG_KILL = {
	ParticleEmitter = true, Beam = true, Trail = true, Smoke = true,
	Fire = true, Sparkles = true, Explosion = true, Sound = true,
	PointLight = true, SpotLight = true, SurfaceLight = true,
}

local antiLagState = { conn = nil, seen = setmetatable({}, { __mode = "k" }) }

local function antiLagStrip(descendant)
	if antiLagState.seen[descendant] then return false end
	local class = descendant.ClassName
	if ANTILAG_KILL[class] then
		antiLagState.seen[descendant] = true
		pcall(function() descendant:Destroy() end)
		return true
	elseif descendant:IsA("Texture") or descendant:IsA("Decal") then
		antiLagState.seen[descendant] = true
		pcall(function() descendant.Transparency = 1 end)
		return true
	elseif descendant:IsA("SurfaceAppearance") then
		antiLagState.seen[descendant] = true
		pcall(function() descendant:Destroy() end)
		return true
	elseif descendant:IsA("BasePart") then
		antiLagState.seen[descendant] = true
		pcall(function()
			descendant.Material = Enum.Material.SmoothPlastic
			descendant.Reflectance = 0
			descendant.CastShadow = false
		end)
		return true
	end
	return false
end

local function antiLagCrushGraphics()
	pcall(function()
		local lighting = game:GetService("Lighting")
		lighting.FogEnd = 9e9
		lighting.GlobalShadows = false
		lighting.EnvironmentDiffuseScale = 0
		lighting.EnvironmentSpecularScale = 0
		for _, child in ipairs(lighting:GetChildren()) do
			if child:IsA("PostEffect") or child:IsA("Atmosphere")
				or child:IsA("Clouds") or child:IsA("Sky")
			then
				pcall(function() child:Destroy() end)
			end
		end
	end)
	pcall(function()
		local terrain = workspace:FindFirstChildOfClass("Terrain")
		if terrain then
			terrain.WaterWaveSize = 0
			terrain.WaterWaveSpeed = 0
			terrain.WaterReflectance = 0
			terrain.WaterTransparency = 1
			terrain.Decoration = false
		end
	end)
	pcall(function()
		settings().Rendering.QualityLevel = Enum.QualityLevel.Level01
	end)
	if typeof(setfpscap) == "function" then
		pcall(setfpscap, 1000)
	end
end

Core.AntiLag = function()
	local removed = 0
	for _, container in ipairs({ workspace:FindFirstChild("__THINGS"), workspace }) do
		if container then
			for _, descendant in ipairs(container:GetDescendants()) do
				if antiLagStrip(descendant) then removed += 1 end
			end
		end
	end
	for _, player in ipairs(playersService:GetPlayers()) do
		local character = player.Character
		if character then
			for _, descendant in ipairs(character:GetDescendants()) do
				antiLagStrip(descendant)
			end
		end
	end
	antiLagCrushGraphics()
	if not antiLagState.conn then
		antiLagState.conn = workspace.DescendantAdded:Connect(function(descendant)
			if settings.AntiLag then
				task.defer(antiLagStrip, descendant)
			end
		end)
	end
	return removed
end

Core.StopAntiLag = function()
	if antiLagState.conn then
		pcall(function() antiLagState.conn:Disconnect() end)
		antiLagState.conn = nil
	end
	table.clear(antiLagState.seen)
	if typeof(setfpscap) == "function" then
		pcall(setfpscap, 0)
	end
end

Core.Daycare = function()
	local daycare = Modules.DaycareCmds
	if not daycare then return end
	local save = getSaveCached()
	if save and typeof(save.DaycareActive) == "table" and daycare.Claim then
		for uid in pairs(save.DaycareActive) do
			local ok, pet = pcall(daycare.Claim, uid)
			if ok and pet then
				invalidateSaveCache()
				return
			end
		end
	end
	if not daycare.GetMaxSlots or not daycare.GetUsedSlots then return end
	local okMax, maxSlots = pcall(daycare.GetMaxSlots)
	local okUsed, usedSlots = pcall(daycare.GetUsedSlots)
	if not okMax or not okUsed or not maxSlots or not usedSlots or usedSlots >= maxSlots then
		return
	end
	if not save or typeof(save.Inventory) ~= "table" or not save.Inventory.Pet then
		return
	end
	local sorted = {}
	local count = 0
	for uid, petEntry in pairs(save.Inventory.Pet) do
		count += 1
		if count % 100 == 0 then task.wait() end
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
	table.sort(sorted, function(a, b) return a.power > b.power end)
	local enroll = {}
	for index = 1, math.min(maxSlots - usedSlots, #sorted) do
		enroll[sorted[index].uid] = 1
	end
	if not next(enroll) then return end
	if daycare.Enroll then
		local ok = pcall(daycare.Enroll, enroll)
		if ok then invalidateSaveCache() end
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
	if not save then return end
	local rankCmds = Modules.RankCmds
	if not rankCmds or not rankCmds.GetEggBundle then return end
	local purchased = save.EggSlotsPurchased or 0
	if not eggBundleCache then
		eggBundleCache = {}
		for index = 1, 200 do
			local okA, bundleEnd, bundleSize, prevEnd = pcall(function()
				return rankCmds.GetEggBundle(index)
			end)
			if not okA or not bundleEnd then break end
			table.insert(eggBundleCache, { bundleEnd = bundleEnd, prevEnd = prevEnd })
			if bundleEnd > 1000 then break end
		end
	end
	for _, bundle in ipairs(eggBundleCache) do
		if bundle.prevEnd == purchased then
			invoke("EggHatchSlotsMachine_RequestPurchase", bundle.bundleEnd)
			return
		end
	end
end

-- -----------------------------------------------------
-- FLAG (chỉ dùng khi trong zone, KHÔNG teleport)
-- -----------------------------------------------------
local flagAutoCache = {
	lastCheck = 0,
	lastConsume = 0,
	lastZone = nil,
	zoneLog = {},
	failLog = {},
}

local function resolveFlagId(displayName)
	if not displayName or displayName == "" then return nil end
	if findInventoryEntry(displayName) then return displayName end
	local base = displayName:gsub("%s*Flag$", "")
	for _, candidate in ipairs({ base, base .. " Flag", base .. "Flag", base .. "_Flag" }) do
		if findInventoryEntry(candidate) then return candidate end
	end
	return nil
end

local function getFlagGameMax(flagId)
	local flagCmds = Modules.FlexibleFlagCmds
	local root = getRoot()
	if not flagCmds or not root then return 45 end
	if typeof(flagCmds.GetMaxPlaceAutomaticContext) == "function" then
		local ok, value = pcall(flagCmds.GetMaxPlaceAutomaticContext, root.Position)
		if ok and typeof(value) == "number" and value > 0 then
			return value
		end
	end
	return 45
end

Core.GetFlagOwnedAmount = function(displayName)
	local resolvedId = resolveFlagId(displayName)
	if not resolvedId then return 0, nil end
	local entry = findInventoryEntry(resolvedId)
	return entry and (entry._am or 0) or 0, resolvedId
end

Core.GetFlagGameMax = function(flagId)
	return getFlagGameMax(flagId or settings.SelectedFlag)
end

Core.GetFlagMaxAmount = function(displayName)
	local owned = Core.GetFlagOwnedAmount(displayName)
	if owned <= 0 then return 0 end
	return math.min(owned, getFlagGameMax(displayName))
end

local function detectCurrentZone()
	local root = getRoot()
	if not root then return nil end

	local mapCmds = Modules.MapCmds
	if mapCmds and mapCmds.GetCurrentBreakZone then
		local ok, zone = pcall(mapCmds.GetCurrentBreakZone)
		if ok and zone then
			local zoneId = typeof(zone) == "table"
				and (zone.ZoneNumber or zone.Name or zone._id)
				or tostring(zone)
			local anchorPos = nil
			local breakZones = getBreakZones()
			if breakZones then
				local zoneNum = typeof(zone) == "table" and zone.ZoneNumber
				if zoneNum then
					local zonePart = breakZones:FindFirstChild("Zone" .. tostring(zoneNum))
					if zonePart and zonePart:IsA("BasePart") then
						anchorPos = zonePart.Position
					end
				end
				if not anchorPos and typeof(zoneId) == "string" then
					for _, zp in ipairs(breakZones:GetChildren()) do
						if zp:IsA("BasePart") and zp.Name == zoneId then
							anchorPos = zp.Position
							break
						end
					end
				end
			end
			return { id = tostring(zoneId), anchorPos = anchorPos, zone = zone }
		end
	end

	local breakZones = getBreakZones()
	if breakZones then
		for _, zonePart in ipairs(breakZones:GetChildren()) do
			if zonePart:IsA("BasePart") then
				local rel = zonePart.CFrame:PointToObjectSpace(root.Position)
				local halfX = math.max(zonePart.Size.X / 2, 1)
				local halfY = math.max(zonePart.Size.Y / 2, 1)
				local halfZ = math.max(zonePart.Size.Z / 2, 1)
				if math.abs(rel.X) <= halfX
					and math.abs(rel.Y) <= halfY
					and math.abs(rel.Z) <= halfZ then
					return {
						id = zonePart.Name,
						anchorPos = zonePart.Position,
						zone = zonePart,
					}
				end
			end
		end
	end

	return nil
end

local function checkZoneFlag(anchorPos)
	local flagCmds = Modules.FlexibleFlagCmds
	if not flagCmds or typeof(flagCmds.SpatialQuery) ~= "function" then
		return false, nil, nil, nil
	end
	if not anchorPos then return false, nil, nil, nil end
	local ok, ctx = pcall(flagCmds.SpatialQuery, anchorPos)
	if not ok or not ctx then return false, nil, nil, nil end
	local endTime = ctx.EndTime
	if typeof(endTime) == "number" and endTime > os.time() then
		return true, ctx.FlagId, endTime, ctx
	end
	return false, ctx.FlagId, endTime, ctx
end

local function tryConsumeFlagWithCtx(flagId, amount, ctx, pos)
	local flagCmds = Modules.FlexibleFlagCmds
	local zoneFlagCmds = Modules.ZoneFlagCmds
	local zoneFlagsDir = Modules.ZoneFlagsDir
	local root = getRoot()
	if not root then return false, "no root" end

	local info = getInstanceInfo()
	local instanceId = info and info.InstanceId
	local areaId = info and info.AreaId

	local attempts = {}
	local function try(label, fn, ...)
		local ok, result = pcall(fn, ...)
		local success = ok and result ~= false
		table.insert(attempts, { label = label, ok = ok, result = result, success = success })
		return success
	end

	local flagUid = findInventoryUid(flagId) or findInventoryUid(settings.SelectedFlag)
	if flagUid then
		if typeof(flagCmds) == "table" and typeof(flagCmds.Consume) == "function" then
			if try("flex-name-uid-amt", flagCmds.Consume, settings.SelectedFlag, flagUid, amount) then
				return true, "flex-name-uid-amt"
			end
			if flagId ~= settings.SelectedFlag
				and try("flex-id-uid-amt", flagCmds.Consume, flagId, flagUid, amount) then
				return true, "flex-id-uid-amt"
			end
		end
		if try("remote-name-uid-amt", function()
			return invoke("FlexibleFlags_Consume", settings.SelectedFlag, flagUid, amount)
		end) then
			return true, "remote-name-uid-amt"
		end
	end

	local function resolveFlagDir()
		if typeof(zoneFlagsDir) ~= "table" then return nil end
		local displayName = settings.SelectedFlag
		local dir = zoneFlagsDir[displayName] or zoneFlagsDir[flagId]
		if dir then return dir end
		for key, val in pairs(zoneFlagsDir) do
			if typeof(val) == "table" then
				if val._id == flagId or key == flagId or key == displayName
					or val.Name == displayName or val._id == displayName then
					return val
				end
			end
		end
		return nil
	end

	local placeCtx = nil
	if typeof(flagCmds) == "table" and typeof(flagCmds.GetMaxPlaceAutomaticContext) == "function" then
		local okc, c = pcall(flagCmds.GetMaxPlaceAutomaticContext, pos or root.Position)
		if okc then placeCtx = c end
	end

	if typeof(flagCmds) == "table" and typeof(flagCmds.ActivateFlag) == "function" then
		local flagDir = resolveFlagDir()
		if flagDir then
			if placeCtx ~= nil and try("activate-dir-placectx", flagCmds.ActivateFlag, flagDir, placeCtx) then
				return true, "activate-dir-placectx"
			end
			if try("activate-dir-amount", flagCmds.ActivateFlag, flagDir, amount) then
				return true, "activate-dir-amount"
			end
			if ctx and try("activate-dir-ctx", flagCmds.ActivateFlag, flagDir, ctx) then
				return true, "activate-dir-ctx"
			end
			if try("activate-dir-pos", flagCmds.ActivateFlag, flagDir, pos or root.Position) then
				return true, "activate-dir-pos"
			end
			if try("activate-dir-opts", flagCmds.ActivateFlag, flagDir, { Amount = amount }) then
				return true, "activate-dir-opts"
			end
			if try("activate-dir", flagCmds.ActivateFlag, flagDir) then
				return true, "activate-dir"
			end
		end
		if try("activate-name-amount", flagCmds.ActivateFlag, settings.SelectedFlag, amount) then
			return true, "activate-name-amount"
		end
		if try("activate-id-amount", flagCmds.ActivateFlag, flagId, amount) then
			return true, "activate-id-amount"
		end
	end

	if ctx and typeof(flagCmds) == "table" and flagCmds.Consume then
		if try("flex-ctx", flagCmds.Consume, flagId, amount, ctx) then
			return true, "flex-ctx"
		end
	end

	if typeof(flagCmds) == "table" and flagCmds.Consume then
		if try("flex-pos", flagCmds.Consume, flagId, amount, pos) then
			return true, "flex-pos"
		end
		if instanceId and try("flex-instanceId", flagCmds.Consume, flagId, amount, instanceId) then
			return true, "flex-instanceId"
		end
		if areaId and try("flex-areaId", flagCmds.Consume, flagId, amount, areaId) then
			return true, "flex-areaId"
		end
		if try("flex-2args", flagCmds.Consume, flagId, amount) then
			return true, "flex-2args"
		end
	end

	if typeof(zoneFlagCmds) == "table" and zoneFlagCmds.Consume then
		if ctx and try("zflex-ctx", zoneFlagCmds.Consume, flagId, amount, ctx) then
			return true, "zflex-ctx"
		end
		if try("zflex-pos", zoneFlagCmds.Consume, flagId, amount, pos) then
			return true, "zflex-pos"
		end
	end

	local activateDir = resolveFlagDir()
	if activateDir then
		if placeCtx ~= nil and try("fire-activate-dir-placectx", function()
			return fire("FlexibleFlags_Activate", activateDir, placeCtx)
		end) then
			return true, "fire-activate-dir-placectx"
		end
		if try("fire-activate-dir-amount", function()
			return fire("FlexibleFlags_Activate", activateDir, amount)
		end) then
			return true, "fire-activate-dir-amount"
		end
		if try("fire-activate-dir-pos", function()
			return fire("FlexibleFlags_Activate", activateDir, pos or root.Position)
		end) then
			return true, "fire-activate-dir-pos"
		end
	end
	if placeCtx ~= nil and try("fire-activate-name-placectx", function()
		return fire("FlexibleFlags_Activate", settings.SelectedFlag, placeCtx)
	end) then
		return true, "fire-activate-name-placectx"
	end
	if try("fire-activate-name-amount", function()
		return fire("FlexibleFlags_Activate", settings.SelectedFlag, amount)
	end) then
		return true, "fire-activate-name-amount"
	end

	if ctx and try("remote-ctx", function()
		return invoke("FlexibleFlags_Consume", flagId, amount, ctx)
	end) then
		return true, "remote-ctx"
	end
	if try("remote-pos", function()
		return invoke("FlexibleFlags_Consume", flagId, amount, pos)
	end) then
		return true, "remote-pos"
	end
	if try("remote-2args", function()
		return invoke("FlexibleFlags_Consume", flagId, amount)
	end) then
		return true, "remote-2args"
	end

	return false, attempts
end

Core.AutoUseFlag = function()
	local root = getRoot()
	if not root then return end

	local selectedFlag = settings.SelectedFlag
	local owned, resolvedId = Core.GetFlagOwnedAmount(selectedFlag)
	if not resolvedId or owned <= 0 then return end

	local amount = math.min(settings.FlagAmount or 45, owned, getFlagGameMax(resolvedId))
	if amount <= 0 then return end

	local zoneInfo = detectCurrentZone()
	local anchorPos = (zoneInfo and zoneInfo.anchorPos) or root.Position

	local hasFlag, _, _, ctx = checkZoneFlag(anchorPos)
	if hasFlag then return end

	local ok = tryConsumeFlagWithCtx(resolvedId, amount, ctx, anchorPos)
	if ok then
		invalidateSaveCache()
	end
end

-- -----------------------------------------------------
-- MERCHANT
-- -----------------------------------------------------
local merchantState = {
	lastVisit = nil,
	attempted = false,
	lastAttemptAt = 0,
	lastResult = nil,
}

local function getMerchantFeature()
	local dmCmds = Modules.DiamondMountainCmds
	if not dmCmds or typeof(dmCmds.Feature) ~= "function" then return nil end
	local ok, feature = pcall(dmCmds.Feature, "Merchant")
	if not ok or typeof(feature) ~= "table" then return nil end
	return feature
end

local function getMerchantPhase()
	local util = Modules.DiamondMountainMerchant
	if not util or typeof(util.Phase) ~= "function" then return nil end
	local ok, phase = pcall(util.Phase)
	if not ok or typeof(phase) ~= "table" then return nil end
	return phase
end

local function getMerchantPadPart(camp)
	local model = workspace:FindFirstChild("TravelingMerchant" .. tostring(camp), true)
	if not model then return nil end
	local pad = model:FindFirstChild("Pad")
	if pad and pad:IsA("BasePart") then return pad end
	return nil
end

local function getMerchantPadObject(camp)
	local feature = getMerchantFeature()
	if not feature then return nil end
	local okU, wagons = pcall(debug.getupvalue, feature.OnLeave, 4)
	if not okU or typeof(wagons) ~= "table" then return nil end
	for _, wagon in pairs(wagons) do
		if typeof(wagon) == "table" and wagon.camp == camp and typeof(wagon.pad) == "table" then
			return wagon.pad
		end
	end
	return nil
end

local function openMerchantShop()
	local feature = getMerchantFeature()
	if not feature or typeof(feature.Open) ~= "function" then return false end
	local ok = pcall(feature.Open)
	return ok
end

local function closeMerchantShop()
	local playerGui = localPlayer:FindFirstChild("PlayerGui")
	local machines = playerGui and playerGui:FindFirstChild("_MACHINES")
	local merchantGui = machines and machines:FindFirstChild("Merchant")
	if not merchantGui then return end
	local close = merchantGui:FindFirstChild("Close", true)
	if not close or not close:IsA("ImageButton") then return end
	for _, signal in ipairs({ close.Activated, close.MouseButton1Click }) do
		local ok, conns = pcall(getconnections, signal)
		if ok and conns then
			for _, conn in ipairs(conns) do
				if conn.Function then
					pcall(conn.Function)
				end
			end
		end
	end
end

local function clickMerchantBuyButtons()
	local playerGui = localPlayer:FindFirstChild("PlayerGui")
	local machines = playerGui and playerGui:FindFirstChild("_MACHINES")
	local merchantGui = machines and machines:FindFirstChild("Merchant")
	if not merchantGui then return 0 end

	local node = merchantGui
	for _, name in ipairs({ "Frame", "ItemsFrame", "ScrollingItems", "Slots" }) do
		node = node and node:FindFirstChild(name)
	end
	if not node then return 0 end

	local clicked = 0
	for i = 1, 6 do
		local slot = node:FindFirstChild(tostring(i))
		if slot then
			local buy = slot:FindFirstChild("Buy")
			if buy and buy:IsA("ImageButton") and buy.Visible then
				local didClick = false
				for _, signal in ipairs({ buy.Activated, buy.MouseButton1Click }) do
					local ok, conns = pcall(getconnections, signal)
					if ok and conns then
						for _, conn in ipairs(conns) do
							if conn.Function then
								pcall(conn.Function)
								didClick = true
							end
						end
					end
				end
				if didClick then
					clicked += 1
					task.wait(0.3)
				end
			end
		end
	end
	return clicked
end

local function tryMerchantBuyAll()
	local bought = 0
	for slot = 1, 6 do
		local ok, result = invoke("Merchant_RequestPurchase", "DiamondMountainMerchant", slot)
		if ok and result == true then
			bought += 1
		end
		task.wait(0.15)
	end
	return bought
end

local function teleportToPos(pos)
	local root = getRoot()
	if not root then return false end
	local wasAnchored = root.Anchored
	root.Anchored = true
	root.CFrame = CFrame.new(pos)
	task.wait(0.5)
	root.Anchored = wasAnchored
	task.wait(0.3)
	return true
end

Core.BuyFromMerchant = function()
	local phase = getMerchantPhase()
	if not phase then return "no phase" end
	if not phase.Arrived then return "traveling" end

	local visit = phase.Visit
	local camp = phase.Camp
	if typeof(visit) ~= "number" or typeof(camp) ~= "number" then
		return "invalid phase"
	end

	if merchantState.lastVisit ~= visit then
		merchantState.lastVisit = visit
		merchantState.attempted = false
		print(("[VRT Merchant] New visit %s @camp %d"):format(tostring(visit), camp))
	end

	if merchantState.attempted then
		local isError = merchantState.lastResult
			and (merchantState.lastResult:find("failed")
				or merchantState.lastResult:find("error")
				or merchantState.lastResult:find("no pad"))
		if isError then
			if os.clock() - merchantState.lastAttemptAt < 30 then
				return "retry cooldown"
			end
			merchantState.attempted = false
		else
			return "already attempted"
		end
	end

	merchantState.attempted = true
	merchantState.lastAttemptAt = os.clock()

	local root = getRoot()
	if not root then return "no root" end

	openMerchantShop()
	task.wait(0.3)
	local farBought = tryMerchantBuyAll()
	if farBought > 0 then
		merchantState.lastResult = ("bought %d far"):format(farBought)
		print(("[VRT Merchant] Bought %d from FAR"):format(farBought))
		return merchantState.lastResult
	end

	local padPart = getMerchantPadPart(camp)
	local padObj = getMerchantPadObject(camp)
	local targetPos = (padObj and padObj.padPosition) or (padPart and padPart.Position)
	if not targetPos then
		merchantState.lastResult = "no pad position"
		return merchantState.lastResult
	end

	local originalCFrame = root.CFrame
	local wasAnchored = root.Anchored
	local distToPad = (root.Position - targetPos).Magnitude

	if distToPad > 3 then
		local okTp = teleportToPos(targetPos)
		if not okTp then
			merchantState.lastResult = "teleport failed"
			return merchantState.lastResult
		end
		print(("[VRT Merchant] Teleported @camp %d | dist=%.2f -> %.2f"):format(
			camp, distToPad, (root.Position - targetPos).Magnitude
		))
	end

	openMerchantShop()
	task.wait(0.8)

	local padBought = tryMerchantBuyAll()
	if padBought == 0 then
		local clicked = clickMerchantBuyButtons()
		if clicked > 0 then
			padBought = clicked
			print(("[VRT Merchant] Clicked %d buy buttons"):format(clicked))
		end
	end

	if settings.MerchantReturnToPos and root and root.Parent then
		root.Anchored = true
		root.CFrame = originalCFrame
		task.wait(0.3)
		root.Anchored = wasAnchored
		print("[VRT Merchant] Returned to original position")
	end

	closeMerchantShop()

	merchantState.lastResult = ("bought %d pad"):format(padBought)
	return merchantState.lastResult
end

-- -----------------------------------------------------
-- EXPEDITION CLAIM
-- -----------------------------------------------------
local expeditionState = {
	lastClaimAt = 0,
	lastResult = nil,
}

local function findDropContainer(dropInfo)
	if not dropInfo then return nil end
	local frame = dropInfo:FindFirstChild("Frame")
	if frame then
		local items = frame:FindFirstChild("Items")
		if items then
			local c = items:FindFirstChild("Container")
			if c then return c end
		end
	end
	local items2 = dropInfo:FindFirstChild("Items")
	if items2 then
		local c2 = items2:FindFirstChild("Container")
		if c2 then return c2 end
	end
	return dropInfo:FindFirstChild("Container", true)
end

local function countExpeditionLoot()
	local claim = getClaimPillar()
	if not claim then return 0 end
	local dropInfo = claim:FindFirstChild("DropInfo")
	if not dropInfo or not dropInfo.Enabled then return 0 end

	local container = findDropContainer(dropInfo)
	if not container then return 0 end

	local count = 0
	for _, render in ipairs(container:GetChildren()) do
		if render:IsA("Frame") and render.Name == "Render" then
			local holder = render:FindFirstChild("Holder")
			local itemSlot = holder and holder:FindFirstChild("ItemSlot")
			if itemSlot and itemSlot.Visible then
				local qty = itemSlot:FindFirstChild("Quantity")
				local icon = itemSlot:FindFirstChild("Icon")
				local locked = itemSlot:FindFirstChild("Locked")
				local hasQty = qty and qty:IsA("TextLabel") and qty.Text ~= ""
				local hasIcon = icon and icon:IsA("ImageLabel") and icon.Image ~= ""
				local isLocked = locked and locked:IsA("ImageLabel") and locked.Visible
				if (hasQty or hasIcon) and not isLocked then
					count += 1
				end
			end
		end
	end
	return count
end

local function getExpeditionTouchPart()
	local claim = getClaimPillar()
	if not claim then return nil end
	local touchInterest = claim:FindFirstChild("TouchInterest", true)
	if touchInterest and touchInterest.Parent and touchInterest.Parent:IsA("BasePart") then
		return touchInterest.Parent
	end
	local pad = claim:FindFirstChild("Pad", true)
	if pad and pad:IsA("BasePart") then return pad end
	return nil
end

local function claimExpeditionWithTeleport()
	local touchPart = getExpeditionTouchPart()
	if not touchPart then return false, "no touch part" end
	local hrp = getRoot()
	if not hrp then return false, "no char" end

	local originalCFrame = hrp.CFrame
	local wasAnchored = hrp.Anchored

	hrp.Anchored = true
	hrp.CFrame = CFrame.new(touchPart.Position + Vector3.new(0, 3, 0))

	local start = os.clock()
	while (os.clock() - start) < 2 do
		task.wait(0.1)
		if (hrp.Position - touchPart.Position).Magnitude < 5 then
			break
		end
	end
	task.wait(0.5)

	pcall(firetouchinterest, touchPart, hrp, true)
	task.wait(0.3)
	pcall(firetouchinterest, touchPart, hrp, false)
	task.wait(1.5)

	hrp.CFrame = originalCFrame
	task.wait(0.2)
	hrp.Anchored = wasAnchored

	return true, "teleport-touch"
end

local function clickExpeditionItemSlots()
	local claim = getClaimPillar()
	if not claim then return 0 end
	local dropInfo = claim:FindFirstChild("DropInfo")
	if not dropInfo then return 0 end
	local container = findDropContainer(dropInfo)
	if not container then return 0 end

	local clicked = 0
	for _, render in ipairs(container:GetChildren()) do
		if render:IsA("Frame") and render.Name == "Render" then
			local holder = render:FindFirstChild("Holder")
			local itemSlot = holder and holder:FindFirstChild("ItemSlot")
			if itemSlot and itemSlot:IsA("TextButton") and itemSlot.Visible then
				for _, signal in ipairs({ itemSlot.Activated, itemSlot.MouseButton1Click }) do
					local ok, conns = pcall(getconnections, signal)
					if ok and conns then
						for _, conn in ipairs(conns) do
							if conn.Function then
								pcall(conn.Function)
								clicked += 1
							end
						end
					end
				end
			end
		end
	end
	return clicked
end

local function fireExpeditionInteractions()
	local claim = getClaimPillar()
	if not claim then return 0 end
	local fired = 0
	for _, d in ipairs(claim:GetDescendants()) do
		if d:IsA("ProximityPrompt") then
			if not d.Enabled then pcall(function() d.Enabled = true end) end
			pcall(fireproximityprompt, d)
			fired += 1
		elseif d:IsA("ClickDetector") then
			pcall(fireclickdetector, d)
			fired += 1
		end
	end
	return fired
end

Core.ClaimExpedition = function()
	local expedition = getExpedition()
	if not expedition then
		if expeditionState.lastResult ~= "no expedition" then
			expeditionState.lastResult = "no expedition"
		end
		return "no expedition"
	end

	local count = countExpeditionLoot()
	if count <= 0 then
		if expeditionState.lastResult ~= "no loot" then
			expeditionState.lastResult = "no loot"
		end
		return "no loot"
	end

	if os.clock() - expeditionState.lastClaimAt < 15 then
		return "cooldown"
	end

	print(("[VRT Expedition] Loot detected: %d items — claiming..."):format(count))

	if settings.ExpeditionFallbackTeleport then
		local ok, method = claimExpeditionWithTeleport()
		if ok then
			expeditionState.lastClaimAt = os.clock()
			task.wait(1)
			local newCount = countExpeditionLoot()
			if newCount == 0 then
				print(("[VRT Expedition] Claimed via %s — loot gone"):format(method))
				expeditionState.lastResult = "claimed"
				return "claimed"
			end
		end
	end

	local clicked = clickExpeditionItemSlots()
	if clicked > 0 then
		task.wait(1.5)
		local newCount2 = countExpeditionLoot()
		if newCount2 == 0 then
			print("[VRT Expedition] Claimed via click")
			expeditionState.lastResult = "claimed click"
			expeditionState.lastClaimAt = os.clock()
			return "claimed click"
		end
	end

	local fired = fireExpeditionInteractions()
	if fired > 0 then
		task.wait(1.5)
		local newCount3 = countExpeditionLoot()
		if newCount3 == 0 then
			print("[VRT Expedition] Claimed via interactions")
			expeditionState.lastResult = "claimed interactions"
			expeditionState.lastClaimAt = os.clock()
			return "claimed interactions"
		end
	end

	expeditionState.lastClaimAt = os.clock()
	expeditionState.lastResult = "failed"
	return "failed"
end

-- -----------------------------------------------------
-- Other Core functions
-- -----------------------------------------------------
Core.BuyZone = function()
	local zoneUtil = Modules.ZonesUtil
	if zoneUtil and zoneUtil.GetMaxOwnedZone and zoneUtil.GetZoneFromNumber then
		local okMax, maxOwned = pcall(zoneUtil.GetMaxOwnedZone)
		if okMax and typeof(maxOwned) == "number" then
			local okZone, nextZone = pcall(zoneUtil.GetZoneFromNumber, maxOwned + 1)
			if okZone and typeof(nextZone) == "table" and nextZone.ZoneNumber then
				invoke("Zones_RequestPurchase", nextZone.ZoneNumber)
				return
			end
		end
	end
	if Modules.ZoneCmds and Modules.ZoneCmds.GetNextZone then
		local ok, nextZone = pcall(Modules.ZoneCmds.GetNextZone)
		if ok and typeof(nextZone) == "table" and nextZone.ZoneNumber then
			invoke("Zones_RequestPurchase", nextZone.ZoneNumber)
			return
		end
	end
	local save = getSaveCached()
	if not save or typeof(save.UnlockedZones) ~= "table" then return end
	local highest = 1
	for _, zone in pairs(save.UnlockedZones) do
		if typeof(zone) == "table" and zone.ZoneNumber and zone.ZoneNumber > highest then
			highest = zone.ZoneNumber
		end
	end
	invoke("Zones_RequestPurchase", highest + 1)
end

Core.Rebirth = function()
	local rebirthCmds = Modules.RebirthCmds
	if not rebirthCmds then return end
	if rebirthCmds.CanRebirth then
		local ok, can = pcall(rebirthCmds.CanRebirth)
		if not ok or not can then return end
	end
	if rebirthCmds.Rebirth then
		pcall(rebirthCmds.Rebirth)
	end
end

Core.UseUltimate = function()
	local ultimate = Modules.UltimateCmds
	if not ultimate or not ultimate.GetEquippedItem then return end
	local ok, equipped = pcall(ultimate.GetEquippedItem)
	if not ok or typeof(equipped) ~= "table" or not equipped._data then return end
	local itemId = equipped._data.id
	if ultimate.IsCharged then
		local okCharged, charged = pcall(ultimate.IsCharged, itemId)
		if not okCharged or not charged then return end
	end
	if ultimate.Activate then
		pcall(ultimate.Activate, itemId)
	else
		invoke("Ultimates: Activate", itemId)
	end
end

Core.ClaimFreeGifts = function()
	local save = getSaveCached()
	if not save or typeof(Modules.FreeGifts) ~= "table" then return end
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
	if not save or typeof(Modules.Ranks) ~= "table" then return end
	local directory
	for _, rank in pairs(Modules.Ranks) do
		if typeof(rank) == "table" and rank.RankNumber == save.Rank then
			directory = rank
			break
		end
	end
	if not directory or typeof(directory.Rewards) ~= "table" then return end
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
	if settings.MailboxUsername == "" then return end
	local save = getSaveCached()
	if not save or typeof(save.Inventory) ~= "table" or not save.Inventory.Pet then
		return
	end
	if not vrt.sentHuges then vrt.sentHuges = {} end
	for uid, petEntry in pairs(save.Inventory.Pet) do
		if typeof(petEntry) == "table" and petEntry.id then
			if petEntry.id:match("Huge") or petEntry.id:match("Titanic") then
				if not vrt.sentHuges[uid] then
					invoke("Mailbox: Send", settings.MailboxUsername:lower(),
						"VRT " .. generateRandomString(8), "Pet", uid, petEntry._am or 1)
					vrt.sentHuges[uid] = true
					task.wait(1)
					if settings.MailboxHugeMode == "New" then break end
				end
			end
		end
	end
end

Core.CollectRelics = function()
	local ok, relicsScript = pcall(function()
		return localPlayer.PlayerScripts.Scripts.Game.Misc:FindFirstChild("Shiny Relics")
	end)
	if not ok or not relicsScript then return end
	local okEnv, env = pcall(getsenv, relicsScript)
	if not okEnv or not env or not env.SetupRelics then return end
	local okUp, relicList = pcall(getupvalue, env.SetupRelics, 7)
	if not okUp or typeof(relicList) ~= "table" then return end
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
				invoke(remote, 1)
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
					invoke(remote, base)
					invalidateSaveCache()
					task.wait(perKey and 0.5 or 0.6)
				end
			end
		end
	end
end

Core.CombineKeysAll = function() combineKeys(false) end
Core.CombineKeysOnce = function() combineKeys(true) end

Core.OpenGiftBags = function()
	local gifts = getGiftIds()
	local wanted = resolveSelection(settings.SelectedGifts, gifts)
	if #wanted == 0 then return end

	local opened = false
	for _, itemId in ipairs(wanted) do
		local entry = findInventoryEntry(itemId)
		local amount = entry and (entry._am or 0) or 0
		if amount > 0 then
			local ok = invoke("GiftBag_Open", itemId, 1)
			if ok then
				invalidateSaveCache()
				opened = true
			end
		end
	end
	return opened
end

local lootboxMaxCache = nil

local function getLootboxMaxOpen()
	if lootboxMaxCache then return lootboxMaxCache end
	lootboxMaxCache = LOOTBOX_BATCH
	local typesFolder = libraryFolder:FindFirstChild("Types")
	local mod = typesFolder and typesFolder:FindFirstChild("Lootboxes")
	if mod then
		local ok, data = pcall(require, mod)
		if ok and typeof(data) == "table" then
			local cap = data.MaxOpenAmountInstant or data.MaxOpenAmount
			if typeof(cap) == "number" and cap > 0 then
				lootboxMaxCache = cap
			end
		end
	end
	return lootboxMaxCache
end

local function buildLootboxItem(entry, uid, itemId)
	local items = Modules.Items
	if typeof(items) ~= "table" then return nil end
	local builders = {
		function() return items.Lootbox(itemId) end,
		function() return items.Lootbox(items, itemId) end,
		function() return items.From(items, entry) end,
		function() return items.From(entry) end,
		function() return items.FromModule and items.FromModule(items, entry) end,
	}
	for _, build in ipairs(builders) do
		local ok, box = pcall(build)
		if ok and typeof(box) == "table" then
			pcall(function() box._uid = uid end)
			return box
		end
	end
	return nil
end

local function openLootboxBatch(itemId, uid, batch, cmds)
	local before = findInventoryEntry(itemId)
	local beforeAmt = before and (before._am or 0) or 0

	local attempts = {}
	if cmds and typeof(cmds.Open) == "function" then
		local box = buildLootboxItem(before, uid, itemId)
		if box then
			attempts[#attempts + 1] = function() return pcall(cmds.Open, box, batch) end
			attempts[#attempts + 1] = function() return pcall(cmds.Open, cmds, box, batch) end
			attempts[#attempts + 1] = function() return pcall(cmds.Open, box) end
		end
	end
	attempts[#attempts + 1] = function() return invoke("Lootbox: Open", uid, batch) end
	attempts[#attempts + 1] = function() return invoke("Lootbox: Open", itemId, batch) end
	attempts[#attempts + 1] = function() return invoke("Lootbox: Open", uid) end

	for _, attempt in ipairs(attempts) do
		pcall(attempt)
		invalidateSaveCache()
		local after = findInventoryEntry(itemId)
		local afterAmt = after and (after._am or 0) or 0
		if afterAmt < beforeAmt then
			return true
		end
	end
	return false
end

Core.OpenLootboxes = function()
	local lootboxes = getLootboxIds()
	local wanted = resolveSelection(settings.SelectedLootboxes, lootboxes)
	if #wanted == 0 then return end

	local cmds = Modules.LootboxCmds
	local cap = getLootboxMaxOpen()

	for _, itemId in ipairs(wanted) do
		local uid = findInventoryUid(itemId)
		local entry = findInventoryEntry(itemId)
		local amount = entry and (entry._am or 0) or 0
		if uid and amount > 0 then
			local remaining = amount
			local fails = 0
			while remaining > 0 do
				local batch = math.min(remaining, cap)
				uid = findInventoryUid(itemId) or uid
				local ok = openLootboxBatch(itemId, uid, batch, cmds)
				if ok then
					fails = 0
				else
					fails += 1
					if fails >= 2 then break end
				end
				remaining -= batch
				task.wait(0.1)
			end
			task.wait(0.2)
		end
	end
end

local fruitCooldown = {}
local fruitConsumeForm = nil

local function getFruitAmount(uid)
	local save = getSaveCached()
	if not save or typeof(save.Inventory) ~= "table" or typeof(save.Inventory.Fruit) ~= "table" then
		return 0
	end
	local entry = save.Inventory.Fruit[uid]
	return (typeof(entry) == "table" and (entry._am or 0)) or 0
end

local function consumeFruitStack(fruitCmds, uid, entry, amount)
	local before = getFruitAmount(uid)
	if before <= 0 then return false, 0 end

	local forms = {
		function() return fire("Fruits: Consume", uid, amount) end,
		function() return fire("Fruits: Consume", entry, amount) end,
		function() return fire("Fruits: Consume", { uid }, amount) end,
		function()
			if typeof(fruitCmds.Consume) == "function" then
				return pcall(fruitCmds.Consume, entry, amount)
			end
			return false
		end,
	}

	local order = {}
	if fruitConsumeForm then order[#order + 1] = fruitConsumeForm end
	for i = 1, #forms do
		if i ~= fruitConsumeForm then order[#order + 1] = i end
	end

	for _, idx in ipairs(order) do
		pcall(forms[idx])
		invalidateSaveCache()
		task.wait(0.15)
		local after = getFruitAmount(uid)
		if after < before then
			fruitConsumeForm = idx
			return true, before - after
		end
	end

	local consumed = 0
	for _ = 1, amount do
		local cur = getFruitAmount(uid)
		if cur <= 0 then break end
		pcall(function() return fire("Fruits: Consume", uid, 1) end)
		invalidateSaveCache()
		task.wait(0.12)
		local after = getFruitAmount(uid)
		if after < cur then
			consumed += (cur - after)
			fruitConsumeForm = 1
		else
			break
		end
	end
	if consumed > 0 then
		return true, consumed
	end
	return false, 0
end

Core.ConsumeFruits = function()
	local fruitCmds = Modules.FruitCmds
	if not fruitCmds then return end
	local save = getSaveCached()
	if not save or typeof(save.Inventory) ~= "table" or typeof(save.Inventory.Fruit) ~= "table" then
		return
	end

	local wanted = resolveSelection(settings.SelectedFruits, getBucketIds("Fruit"))
	local items = {}
	for uid, entry in pairs(save.Inventory.Fruit) do
		if typeof(entry) == "table" and entry.id and (entry._am or 0) > 0 then
			if table.find(wanted, entry.id) then
				table.insert(items, { uid = uid, entry = entry })
			end
		end
	end
	if #items == 0 then return end
	table.sort(items, function(a, b) return (a.entry._am or 0) > (b.entry._am or 0) end)

	local totalConsumed = 0

	for pass = 1, 3 do
		local consumedThisPass = 0
		for _, item in ipairs(items) do
			local fruitId = item.entry.id
			local stackKey = item.entry.sh == true and "Shiny" or "Normal"
			local cooldownKey = fruitId .. "|" .. stackKey
			local last = fruitCooldown[cooldownKey]
			local now = os.clock()
			if not (last and now - last < 2) then
				local maxConsume = item.entry._am or 0
				local okLimit, value = pcall(fruitCmds.GetMaxConsume, item.entry)
				if okLimit and typeof(value) == "number" and value > 0 then
					maxConsume = math.min(maxConsume, value)
				end

				local remaining = math.min(item.entry._am or 0, maxConsume)
				if remaining > 0 then
					local batch = math.max(1, math.min(remaining, 25))
					local ok, dropped = consumeFruitStack(fruitCmds, item.uid, item.entry, batch)
					if ok then
						fruitCooldown[cooldownKey] = os.clock()
						totalConsumed += dropped
						consumedThisPass += 1
						if not vrt.fruitLog[cooldownKey] then
							vrt.fruitLog[cooldownKey] = true
							print(("[VRT] Fruit: %s (%s) x%d"):format(fruitId, stackKey, dropped))
						end
						task.wait(0.2)
					end
				end
			end
		end
		if consumedThisPass == 0 then break end
		if pass < 3 then task.wait(1) end
	end

	if totalConsumed > 0 then invalidateSaveCache() end
end

-- -----------------------------------------------------
-- Auto Time Trial
-- -----------------------------------------------------
local timeTrialChestCache = nil

local function getTimeTrialChestIds()
	if timeTrialChestCache then return timeTrialChestCache end
	timeTrialChestCache = {}
	local typesFolder = libraryFolder:FindFirstChild("Types")
	local mod = typesFolder and typesFolder:FindFirstChild("TimeTrials")
	local dirName
	if mod then
		local ok, data = pcall(require, mod)
		if ok and typeof(data) == "table" then
			dirName = data.ChestDirectory
		end
	end
	if typeof(dirName) == "string" and dirName ~= "" then
		local ids = getDirectoryIds(dirName)
		if #ids == 0 then ids = getLibraryDirIds(dirName) end
		timeTrialChestCache = ids
	end
	return timeTrialChestCache
end

Core.OpenTimeTrialChests = function()
	local remote = "TimeTrials_OpenChest"
	if networkFolder and not networkFolder:FindFirstChild(remote) then return end

	local chestIds = getTimeTrialChestIds()

	local attempts = { function() return invoke(remote) end }
	for _, id in ipairs(chestIds) do
		attempts[#attempts + 1] = function() return invoke(remote, id) end
		attempts[#attempts + 1] = function() return invoke(remote, id, 1) end
	end

	for _, attempt in ipairs(attempts) do
		pcall(attempt)
		task.wait(0.15)
	end
	invalidateSaveCache()
end

Core.FarmTreehouse = function()
	local save = getSaveCached()
	if not save then return end
	cleanupTreehouseModels()
	local keyEntry = findInventoryEntry("Secret Key")
	if not (keyEntry and (keyEntry._am or 0) > 0) then return end
	local rooms = save.SecretRooms
	if not rooms or not rooms[TREEHOUSE_ROOM] then
		invoke("SecretRoom_Unlock", TREEHOUSE_ROOM)
		task.wait(1)
		return
	end
	invoke("Instancing_PlayerEnterInstance", TREEHOUSE_ID)
	task.wait(1.5)
	Core.ClaimBestTreehouseItem()
	task.wait(1)
	fire("Instancing_PlayerLeaveInstance", TREEHOUSE_ID)
end

Core.ClaimBestTreehouseItem = function()
	local save = getSaveCached()
	if not save then return false end
	local items = save.SecretRooms and save.SecretRooms[TREEHOUSE_ROOM]
	if typeof(items) ~= "table" then return false end
	local itemsModule = Modules.Items or Modules.ItemsDir
	if typeof(itemsModule) ~= "table" then return false end
	local bestItem, bestRap
	for _, entry in ipairs(items) do
		local class = entry.class
		local data = entry.data
		if typeof(data) == "table" and data.id then
			local ctor = itemsModule[class]
			if typeof(ctor) == "function" then
				local ok, instance = pcall(ctor, data.id)
				if ok and instance then
					if class ~= "Enchant" and class ~= "Potion" and data.tn then
						pcall(function() instance:SetTier(data.tn) end)
					end
					local okRap, rap = pcall(function() return instance:GetRAP() end)
					if okRap and typeof(rap) == "number" and (not bestRap or rap > bestRap) then
						bestRap = rap
						bestItem = instance
					end
				end
			end
		end
	end
	if not bestItem then return false end
	invoke("TreehouseMerchant_Purchase", bestItem)
	return true, bestRap
end

Core.ClaimFakeCharacters = function()
	local things = workspace:FindFirstChild("__THINGS")
	local folder = things and things:FindFirstChild("AdminAbuseCharacters")
	local root = getRoot()
	if not folder or not root then return end
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
				if shinyOnly then
					if not entry.sh then
						payload[uid] = 1
					end
				else
					payload[uid] = 1
				end
			end
		end
	end
	if not next(payload) then return end
	invoke(shinyOnly and "UpgradeShinyFruitsMachine_Activate" or "UpgradeFruitsMachine_Activate", payload)
	invalidateSaveCache()
end

Core.UpgradePotions = function()
	local save = getSaveCached()
	local balance = Modules.Balancing
	if not save or not balance or not balance.CalcPotionsPerTierRequired then return end
	if typeof(save.Inventory) ~= "table" or not save.Inventory.Potion then return end
	local payload = {}
	for uid, entry in pairs(save.Inventory.Potion) do
		if typeof(entry) ~= "table" or not entry._am then continue end
		local okCalc, perTier = pcall(balance.CalcPotionsPerTierRequired, entry.tn or 1)
		if not okCalc or not perTier or perTier <= 0 then continue end
		local crafts = entry._am // perTier
		if crafts > 0 then payload[uid] = crafts end
	end
	if next(payload) then
		invoke("UpgradePotionsMachine_ActivateBulk", payload)
		invalidateSaveCache()
	end
end

Core.UpgradeEnchants = function()
	local save = getSaveCached()
	local balance = Modules.Balancing
	if not save or not balance or not balance.CalcEnchantsPerTierRequired then return end
	if typeof(save.Inventory) ~= "table" or not save.Inventory.Enchant then return end
	local payload = {}
	for uid, entry in pairs(save.Inventory.Enchant) do
		if typeof(entry) ~= "table" or not entry._am then continue end
		local okCalc, perTier = pcall(balance.CalcEnchantsPerTierRequired, entry.tn or 1)
		if not okCalc or not perTier or perTier <= 0 then continue end
		local crafts = entry._am // perTier
		if crafts > 0 then payload[uid] = crafts end
	end
	if next(payload) then
		invoke("UpgradeEnchantsMachine_ActivateBulk", payload)
		invalidateSaveCache()
	end
end

Core.EmpowerEnchants = function()
	local save = getSaveCached()
	if not save or typeof(save.Inventory) ~= "table" or not save.Inventory.Enchant then return end
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
	if not save or typeof(save.Inventory) ~= "table" or not save.Inventory.Enchant then return end
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

Core.CombineCards = function()
	local save = getSaveCached()
	if not save or typeof(save.Inventory) ~= "table" or not save.Inventory.Card then
		return
	end
	local payload = {}
	for uid, entry in pairs(save.Inventory.Card) do
		if typeof(entry) == "table" and entry._am and entry._am >= 3 then
			payload[uid] = entry._am // 3
		end
	end
	if not next(payload) then return end
	invoke("CardCombinationMachine_ActivateBulk", payload)
	invalidateSaveCache()
end

local EVENT_PETS_MANUAL = {}

local FUSE_MIN = 3

local function getPetConfig(id, instance)
	local dir = Modules.PetsDir
	if typeof(dir) == "table" then
		local cfg = dir[id]
		if typeof(cfg) == "table" then return cfg end
		if typeof(dir.Pets) == "table" and typeof(dir.Pets[id]) == "table" then
			return dir.Pets[id]
		end
	end
	if typeof(instance) == "table" then
		if typeof(instance._config) == "table" then return instance._config end
		if typeof(instance._data) == "table" then return instance._data end
		if typeof(instance.GetConfig) == "function" then
			local ok, cfg = pcall(instance.GetConfig, instance)
			if ok and typeof(cfg) == "table" then return cfg end
		end
	end
	return nil
end

local function isFusablePet(entry, instance)
	if typeof(entry) ~= "table" then return false end
	local id = entry.id
	if typeof(id) ~= "string" then return false end
	if EVENT_PETS_MANUAL[id] then return false end
	local cfg = getPetConfig(id, instance)
	if typeof(cfg) ~= "table" then return false end
	if cfg.fromEgg == nil then return false end
	return true
end

Core.FusePets = function()
	local save = getSaveCached()
	if not save or typeof(save.Inventory) ~= "table" or not save.Inventory.Pet then
		return
	end
	local items = Modules.Items
	if not items or not items.Pet or not items.Pet.From then return end
	local uids = {}
	for uid, entry in pairs(save.Inventory.Pet) do
		if typeof(entry) == "table" then
			local ok, instance = pcall(items.Pet.From, items.Pet, entry)
			if ok and instance and isFusablePet(entry, instance) then
				table.insert(uids, uid)
			end
		end
	end
	local amount = tonumber(settings.FuseAmount) or 5
	if amount < 1 then amount = 1 end
	local count = math.min(#uids, amount)
	if count < FUSE_MIN then return end
	local payload = {}
	for i = 1, count do
		payload[uids[i]] = 1
	end
	invoke("FuseMachine_Activate", payload)
	invalidateSaveCache()
end

Core.GoldMachine = function()
	local save = getSaveCached()
	if not save or typeof(save.Inventory) ~= "table" or not save.Inventory.Pet then
		return
	end
	local items = Modules.Items
	if not items or not items.Pet or not items.Pet.From then return end
	local normals = {}
	for uid, entry in pairs(save.Inventory.Pet) do
		if typeof(entry) == "table" then
			local ok, instance = pcall(items.Pet.From, items.Pet, entry)
			if ok and instance then
				local isGolden = instance.IsGolden and instance:IsGolden()
				local isRainbow = instance.IsRainbow and instance:IsRainbow()
				if not isGolden and not isRainbow then
					table.insert(normals, uid)
				end
			end
		end
	end
	if #normals < 5 then return end
	local payload = {}
	for i = 1, math.min(#normals, 5) do
		payload[normals[i]] = 1
	end
	invoke("GoldMachine_Activate", payload)
	invalidateSaveCache()
end

Core.RainbowMachine = function()
	local save = getSaveCached()
	if not save or typeof(save.Inventory) ~= "table" or not save.Inventory.Pet then
		return
	end
	local items = Modules.Items
	if not items or not items.Pet or not items.Pet.From then return end
	local goldens = {}
	for uid, entry in pairs(save.Inventory.Pet) do
		if typeof(entry) == "table" then
			local ok, instance = pcall(items.Pet.From, items.Pet, entry)
			if ok and instance then
				local isGolden = instance.IsGolden and instance:IsGolden()
				local isRainbow = instance.IsRainbow and instance:IsRainbow()
				if isGolden and not isRainbow then
					table.insert(goldens, uid)
				end
			end
		end
	end
	if #goldens < 5 then return end
	local payload = {}
	for i = 1, math.min(#goldens, 5) do
		payload[goldens[i]] = 1
	end
	invoke("RainbowMachine_Activate", payload)
	invalidateSaveCache()
end

Core.CoinJar = function()
	local entry = findInventoryEntry("Basic Coin Jar")
	if not entry or (entry._am or 0) <= 0 then return end
	invoke("CoinJar_Spawn")
end

Core.Comet = function()
	local entry = findInventoryEntry("Comet")
	if not entry or (entry._am or 0) <= 0 then return end
	invoke("Comet_Spawn")
end

-- -----------------------------------------------------
-- Loop manager
-- -----------------------------------------------------
local function startLoop(flag, interval, callback)
	if vrt.loops[flag] then return end
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
	if not settings[flag] then return end
	local interval = cooldown or settings.FastFarmCooldown or 0.2
	local lastRun = 0
	vrt.connections[flag] = signal:Connect(function()
		if not settings[flag] then return end
		local now = os.clock()
		if now - lastRun < interval then return end
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
	local CAMP_UNREACHABLE_TTL = 30
	local TELEPORT_TIMEOUT = 3
	local MAX_CAMP = 6
	local BOOST_CATEGORIES = { "CATEGORY_Diamond Mountain", "CATEGORY_Boosts" }
	local BOOST_NAME_FIELDS = { "Id", "Name", "ItemId", "ItemName", "Type", "Category" }
	local BOOST_COUNT_FIELDS = { "Quantity", "Amount", "Count", "Qty" }

	local REMOTE_NAMES = {
		click = "Click", dealDamage = "Breakables_PlayerDealDamage",
		joinPetBulk = "Breakables_JoinPetBulk", hatchEgg = "CustomEggs_Hatch",
		merchantPurchase = "Merchant_RequestPurchase",
		merchantGetOffers = "Merchant_GetOffers",
		machineScreens = "MachineScreens_Get",
		teleportInstance = "Teleports_RequestInstanceTeleport",
		joinInstance = "Instancing_InvokeCustomFromClient",
		purchaseUpgrade = "EventUpgrades: Purchase",
		consumeItem = "Consumables_Consume", inventoryOpened = "Inventory_Opened",
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
		return type(value) == "string" and #value == UUID_LENGTH and value:match("^%x+$") ~= nil
	end

	local function distanceSq(a, b)
		local dx, dy, dz = a.X - b.X, a.Y - b.Y, a.Z - b.Z
		return dx * dx + dy * dy + dz * dz
	end

	local function pressButton(button)
		if not button then return false end
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
			id = "autoFarm", name = "Auto Farm", interval = 1.2,
			run = function(self)
				local root = self:getRoot()
				if not root then return "no character" end
				if not self:getMountain() then self:joinEvent(); return "joining instance" end
				if self.dmFarmPoint then
					local fp = self.dmFarmPoint
					local targetPos = Vector3.new(fp.x, fp.y, fp.z)
					if distanceSq(root.Position, targetPos) > 225 then
						root.CFrame = CFrame.new(targetPos)
						return "teleport dm farm point"
					end
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
				if not self.network.teleportInstance then return "no teleport remote" end
				local campIndex = self:nextFarmCamp()
				if not campIndex then return "no camp reachable" end
				pcall(function()
					self.network.teleportInstance:InvokeServer(string.format("__Zone_%d", campIndex))
				end)
				self.pendingCamp = campIndex
				self.pendingAt = os.clock()
				return "teleport camp " .. campIndex
			end,
		},
		{
			id = "autoFarmBest", name = "Auto Farm Best (highest camp)", interval = 1.5,
			run = function(self)
				local root = self:getRoot()
				if not root then return "no character" end
				if not self:getMountain() then self:joinEvent(); return "joining instance" end
				local highest = self:getHighestOpenCamp()
				local anchor = self:getCampAnchor(highest)
				if anchor and distanceSq(root.Position, anchor) > CAMP_RADIUS * CAMP_RADIUS then
					if self.network.teleportInstance then
						pcall(function()
							self.network.teleportInstance:InvokeServer(string.format("__Zone_%d", highest))
						end)
						return "teleport best camp " .. highest
					end
				end
				local target = self:nearestBreakable(root.Position, FARM_RADIUS)
				if target then
					self:hitBreakable(target)
					self:joinPets(target.id)
					return string.format("farm best %s @%d", target.id, highest)
				end
				return "no target @camp " .. highest
			end,
		},
		{
			id = "breakTrail", name = "Break Trail Chests", interval = 0.2,
			run = function(self)
				local root = self:getRoot()
				if not root then return "no character" end
				local target = self:nearestBreakable(root.Position, TRAIL_RADIUS)
				if not target then return "no chest nearby" end
				self:hitBreakable(target)
				self:joinPets(target.id)
				return "breaking " .. target.id
			end,
		},
		{
			id = "fightYeti", name = "Fight The Yeti", interval = 0.2,
			run = function(self)
				local spot = self:getYetiSpot()
				if not spot then return "no arena" end
				local target = self:nearestBreakable(spot, YETI_RADIUS)
				if not target then return "no yeti" end
				self:hitBreakable(target)
				self:joinPets(target.id)
				return "hitting " .. target.id
			end,
		},
		{
			id = "feedYeti", name = "Feed The Yeti", interval = 0.4,
			run = function(self)
				local spot = self:getYetiSpot()
				if not spot then return "no arena" end
				local target = self:nearestBreakable(spot, YETI_RADIUS)
				if not target then return "no yeti" end
				if self:joinPets(target.id) then return "feeding " .. target.id end
				return "no pets"
			end,
		},
		{
			id = "fillWalls", name = "Fill Rubble Walls", interval = 0.5,
			run = function(self)
				local camps = self:getCampList()
				if #camps == 0 then return "no camps" end
				local filled = 0
				for _, camp in ipairs(camps) do
					local wall = camp:FindFirstChild("Wall")
					local blocker = wall and wall:FindFirstChild("Blocker")
					if blocker and blocker:IsA("BasePart") then
						local target = self:nearestBreakable(blocker.Position, WALL_RADIUS)
						if target and self:joinPets(target.id) then filled += 1 end
					end
				end
				return filled > 0 and string.format("filled %d", filled) or "no pets"
			end,
		},
		{
			id = "merchant", name = "Buy From Traveling Merchant", interval = 10,
			run = function(self)
				return tostring(Core.BuyFromMerchant())
			end,
		},
		{
			id = "claimExpedition", name = "Claim Expeditions", interval = 10,
			run = function(self)
				return tostring(Core.ClaimExpedition())
			end,
		},
		{
			id = "sendExpedition", name = "Send Pets On Expeditions", interval = 2,
			run = function(self)
				local screens = self.network.machineScreens
				if screens then pcall(screens.FireServer, screens, EXPEDITION_MACHINE) end
				task.wait(0.3)
				local prompts = self:getExpeditionPrompts(true)
				if #prompts == 0 then return "no expedition" end
				local fired = 0
				for _, prompt in ipairs(prompts) do
					if prompt.Parent then
						if not prompt.Enabled then pcall(function() prompt.Enabled = true end) end
						pcall(fireproximityprompt, prompt)
						fired += 1
					end
				end
				return fired > 0 and string.format("sent %d", fired) or "no prompt"
			end,
		},
		{
			id = "teleportCamp", name = "Teleport To Camp", interval = 2,
			run = function(self)
				local teleport = self.network.teleportInstance
				if not teleport then return "no teleport remote" end
				local join = self.network.joinInstance
				if join then pcall(join.InvokeServer, join, INSTANCE_ID) end
				pcall(teleport.InvokeServer, teleport, string.format("__Zone_%d", self.campIndex))
				return "camp " .. self.campIndex
			end,
		},
		{
			id = "artifacts", name = "Find Mountain Artifacts", interval = 1,
			run = function(self)
				local mountain = self:getMountain()
				local artifacts = mountain and mountain:FindFirstChild("Artifacts")
				if not artifacts then return "no artifacts" end
				local root = self:getRoot()
				if not root then return "no character" end
				local best, bestDistance
				local total, collected = 0, 0
				for _, artifact in ipairs(artifacts:GetChildren()) do
					total += 1
					local part = artifact:FindFirstChildWhichIsA("BasePart", true)
					if part then
						if part.Transparency >= 1 then
							collected += 1
						else
							local d = distanceSq(part.Position, root.Position)
							if not bestDistance or d < bestDistance then best, bestDistance = part, d end
						end
					end
				end
				if collected >= total then
					return string.format("all collected (%d/%d)", collected, total)
				end
				if not best then return "no uncollected artifact" end
				root.CFrame = CFrame.new(best.Position + Vector3.new(0, 4, 0))
				return string.format("artifact %d/%d (%.0f)", collected, total, math.sqrt(bestDistance))
			end,
		},
		{
			id = "buyUpgrades", name = "Buy Mountain Upgrades", interval = 1,
			run = function(self)
				local purchase = self.network.purchaseUpgrade
				if not purchase then return "no upgrade remote" end
				local ids = self:getUpgradeIds()
				if #ids == 0 then return "open the upgrade machine" end
				local bought = 0
				for _, upgradeId in ipairs(ids) do
					local ok = pcall(purchase.InvokeServer, purchase, upgradeId)
					if ok then bought += 1 end
				end
				return bought > 0 and string.format("bought %d", bought) or "purchase failed"
			end,
		},
		{
			id = "useBoosts", name = "Use Mountain Boosts", interval = 2,
			run = function(self)
				local consume = self.network.consumeItem
				if not consume then return "no consume remote" end
				local uuids = self:getBoostUuids()
				if #uuids == 0 then
					local now = os.clock()
					if not self.gcScanning and now - self.gcCacheTime > GC_SCAN_COOLDOWN then
						self.gcCacheTime = now
						task.spawn(function()
							self.gcCache = self:scanBoostUidsFromGc()
						end)
					end
					return "no boosts found"
				end
				local now = os.clock()
				local used = 0
				for _, uuid in ipairs(uuids) do
					local last = self.boostCooldown[uuid]
					if not last or now - last >= BOOST_COOLDOWN then
						local ok = pcall(consume.InvokeServer, consume, uuid, BOOST_QUANTITY)
						if ok then self.boostCooldown[uuid] = now; used += 1 end
					end
				end
				return used > 0 and string.format("used %d", used) or "waiting cooldown"
			end,
		},
		{
			id = "optimize", name = "Optimize Diamond Mountain", interval = 15,
			run = function(self)
				if self.optimizeDone then
					self.features.optimize.enabled = false
					return "done"
				end
				local mountain = self:getMountain()
				if not mountain then return "not in mountain" end
				local cleaned, scanned = 0, 0
				for _, instance in ipairs(mountain:GetDescendants()) do
					if instance:IsA("ParticleEmitter") or instance:IsA("Beam") or instance:IsA("Trail") then
						if instance.Enabled then instance.Enabled = false; cleaned += 1 end
					end
					scanned += 1
					if scanned % OPTIMIZE_CHUNK == 0 then task.wait() end
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
		self.playerPetModule = nil
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
		self.selectedEggUuid = nil
		self.dmFarmPoint = nil
		self.originalNamecall = nil
		self.hookNamecall = nil
		self.learnDone = false
		self.merchantLogged = false
		self:buildFeatures()
		self:resolveRemotes()
		self:installLearner()
		return self
	end

	function DiamondMountain:buildFeatures()
		table.clear(self.features)
		for _, definition in ipairs(FeatureDefinitions) do
			self.features[definition.id] = {
				id = definition.id, name = definition.name,
				interval = definition.interval or DEFAULT_INTERVAL,
				run = definition.run, enabled = false, status = "idle", thread = nil,
			}
		end
	end

	function DiamondMountain:findNetworkFolder()
		local direct = replicatedStorage:FindFirstChild("Network")
		if direct then return direct end
		local things = workspaceService:FindFirstChild("__THINGS")
		local remotes = things and things:FindFirstChild("__REMOTES")
		local legacy = remotes and remotes:FindFirstChild("Network")
		if legacy then return legacy end
		local okAll, all = pcall(getinstances)
		if okAll and all then
			for _, instance in ipairs(all) do
				if instance.Name == "Network" and instance:IsA("Folder") then return instance end
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
			if not self.network[key] then missing += 1 end
		end
		self.missingCount = missing
		self.learnRemotes = missing > 0
	end

	function DiamondMountain:getMissingRemotes()
		local missing = {}
		for key in pairs(REMOTE_NAMES) do
			if not self.network[key] then table.insert(missing, key) end
		end
		return missing
	end

	function DiamondMountain:installLearner()
		if self.hookNamecall then return end
		local module = self
		local function tryRemoveHook()
			if module.learnRemotes or module.learnPets then return end
			if not module.hookNamecall then return end
			local hook = module.hookNamecall
			module.hookNamecall = nil
			module.learnDone = true
			task.defer(function()
				local ok = pcall(restorefunction, hook)
				if not ok then pcall(hookmetamethod, game, "__namecall", module.originalNamecall) end
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
							if module.missingCount <= 0 then module.learnRemotes = false end
						end
					end
					if module.learnPets and name == "Breakables_JoinPetBulk" then
						local map = ...
						if type(map) == "table" then
							local captured = 0
							for petId in pairs(map) do
								if type(petId) == "number" then module.knownPets[petId] = true; captured += 1 end
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
		if self.breakableFolder and now - self.watchCheckedAt < WATCH_CHECK_TTL then return end
		self.watchCheckedAt = now
		local things = workspaceService:FindFirstChild("__THINGS")
		local folder = things and things:FindFirstChild("Breakables")
		if folder == self.breakableFolder then return end
		for _, connection in ipairs(self.breakableConnections) do
			pcall(function() connection:Disconnect() end)
		end
		table.clear(self.breakableConnections)
		self.breakableFolder = folder
		self.breakableDirty = true
		if not folder then return end
		local module = self
		local function markDirty() module.breakableDirty = true end
		self.breakableConnections[#self.breakableConnections + 1] = folder.ChildAdded:Connect(markDirty)
		self.breakableConnections[#self.breakableConnections + 1] = folder.ChildRemoved:Connect(markDirty)
		self.breakableConnections[#self.breakableConnections + 1] = folder.DescendantAdded:Connect(markDirty)
		self.breakableConnections[#self.breakableConnections + 1] = folder.DescendantRemoving:Connect(markDirty)
	end

	function DiamondMountain:getBreakables()
		self:watchBreakables()
		if not self.breakableDirty then return self.breakableList end
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
			if d < bestDistance then best, bestDistance = entry, d end
		end
		return best
	end

	function DiamondMountain:isCampWallUp(campIndex)
		local now = os.clock()
		local cached = self.wallCache[campIndex]
		if cached and now - cached.at < WORLD_CACHE_TTL then return cached.up end
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
			if self:isCampWallUp(index) then break end
			highest = index + 1
		end
		return highest
	end

	function DiamondMountain:getCampAnchor(campIndex)
		local now = os.clock()
		local cached = self.anchorCache[campIndex]
		if cached and now - cached.at < WORLD_CACHE_TTL then return cached.pos end
		local pos
		local camps = self:getCamps()
		local camp = camps and camps:FindFirstChild(tostring(campIndex))
		if camp then
			local merchant = camp:FindFirstChild("Merchant")
			if merchant then
				local part = merchant:IsA("BasePart") and merchant
					or merchant:FindFirstChildWhichIsA("BasePart", true)
				if part then pos = part.Position end
			end
			if not pos then
				local wallFront = camp:FindFirstChild("WallFront")
				if wallFront and wallFront:IsA("BasePart") then pos = wallFront.Position end
			end
		end
		self.anchorCache[campIndex] = { pos = pos, at = now }
		return pos
	end

	function DiamondMountain:getCurrentCamp()
		local root = self:getRoot()
		if not root then return nil end
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
			if not blockedAt or now - blockedAt > CAMP_UNREACHABLE_TTL then return index end
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
			farmCamp = self.farmCamp, pendingCamp = self.pendingCamp,
			currentCamp = self:getCurrentCamp(),
			highestOpen = self:getHighestOpenCamp(), maxCamp = self.maxCamp,
		}
	end

	function DiamondMountain:setFarmPoint(pos)
		self.dmFarmPoint = pos
	end

	function DiamondMountain:setSelectedEgg(uuid)
		self.selectedEggUuid = uuid
	end

	function DiamondMountain:joinEvent()
		self:resolveRemotes()
		local join = self.network.joinInstance
		if not join then return false, "join remote not resolved" end
		local root = self:getRoot()
		if root then
			local things = workspaceService:FindFirstChild("__THINGS")
			local instances = things and things:FindFirstChild("Instances")
			local dm = instances and instances:FindFirstChild("DiamondMountain")
			local teleports = dm and dm:FindFirstChild("Teleports")
			local enter = teleports and teleports:FindFirstChild("Enter")
			if enter and enter:IsA("BasePart") then
				root.CFrame = enter.CFrame
				task.wait(0.5)
			end
		end
		local ok = pcall(join.InvokeServer, join, INSTANCE_ID)
		if ok then return true, "joining" end
		pcall(join.FireServer, join, INSTANCE_ID)
		return true, "joining (fire)"
	end

	function DiamondMountain:hitBreakable(entry)
		local root = self:getRoot()
		if not root then return false end
		local targetPos = entry.part.Position
		local direction = targetPos - root.Position
		if direction.Magnitude < 0.01 then direction = Vector3.new(0, -1, 0) end
		local click = self.network.click
		if click then pcall(click.FireServer, click, targetPos, direction.Unit) end
		local dealDamage = self.network.dealDamage
		if dealDamage then pcall(dealDamage.FireServer, dealDamage, entry.id) end
		return true
	end

	function DiamondMountain:joinPets(breakableId)
		local joinPetBulk = self.network.joinPetBulk
		if not joinPetBulk or not breakableId then return false end
		local uids = {}
		if not self.playerPetModule then
			local lib = replicatedStorage:FindFirstChild("Library")
			local client = lib and lib:FindFirstChild("Client")
			local pp = client and client:FindFirstChild("PlayerPet")
			if pp then
				local ok, mod = pcall(require, pp)
				if ok then self.playerPetModule = mod end
			end
		end
		if self.playerPetModule and self.playerPetModule.GetAll then
			local ok, pets = pcall(self.playerPetModule.GetAll)
			if ok and type(pets) == "table" then
				for _, pet in pairs(pets) do
					if type(pet) == "table" and pet.owner == localPlayer then
						local uid = pet.euid or pet.uid
						if uid then table.insert(uids, uid) end
					end
				end
			end
		end
		if #uids == 0 then
			for petId in pairs(self.knownPets) do table.insert(uids, petId) end
		end
		if #uids == 0 then return false end
		local map = {}
		for _, uid in ipairs(uids) do map[uid] = breakableId end
		pcall(joinPetBulk.FireServer, joinPetBulk, map)
		return true
	end

	function DiamondMountain:getYetiSpot()
		local now = os.clock()
		if self.yetiSpot and now - self.yetiSpotAt < WORLD_CACHE_TTL then return self.yetiSpot end
		local spot
		local mountain = self:getMountain()
		local summit = mountain and mountain:FindFirstChild("Summit")
		local arena = summit and summit:FindFirstChild("YetiArena")
		if arena then
			local chestSpot = arena:FindFirstChild("ChestSpot")
			if chestSpot and chestSpot:IsA("BasePart") then
				spot = chestSpot.Position
			else
				local ok, pivot = pcall(function() return arena.WorldPivot end)
				if ok and pivot then spot = pivot.Position end
			end
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
		if self.eggCache and now - self.eggCacheAt < EGG_CACHE_TTL then return self.eggCache end
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

	function DiamondMountain:getExpeditionPrompts(force)
		local now = os.clock()
		if not force and self.expeditionPrompts and now - self.expeditionPromptsAt < EXPEDITION_CACHE_TTL then
			return self.expeditionPrompts
		end
		local prompts = {}
		local mountain = self:getMountain()
		local summit = mountain and mountain:FindFirstChild("Summit")
		local expedition = summit and summit:FindFirstChild("Expedition")
		if expedition then
			for _, descendant in ipairs(expedition:GetDescendants()) do
				if descendant:IsA("ProximityPrompt") then
					local parent = descendant.Parent
					local inClaim = false
					while parent and parent ~= expedition do
						if parent.Name == "ClaimPillar" then inClaim = true; break end
						parent = parent.Parent
					end
					if not inClaim then prompts[#prompts + 1] = descendant end
				end
			end
		end
		self.expeditionPrompts = prompts
		self.expeditionPromptsAt = now
		return prompts
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
				if instance.Name == name then found = instance; break end
			end
		end
		self.categoryCache[name] = { instance = found, at = now }
		return found
	end

	function DiamondMountain:getBoostUuids()
		local now = os.clock()
		if self.boostUuidCache and now - self.boostUuidCacheAt < BOOST_UUID_CACHE_TTL then
			return self.boostUuidCache
		end
		local uuids, seen = {}, {}
		local lib = replicatedStorage:FindFirstChild("Library")
		local client = lib and lib:FindFirstChild("Client")
		local saveMod = client and client:FindFirstChild("Save")
		if saveMod then
			local ok, save = pcall(require, saveMod)
			if ok and save and save.Get then
				local okGet, saveData = pcall(save.Get)
				if okGet and type(saveData) == "table" and type(saveData.Inventory) == "table" then
					local consumable = saveData.Inventory.Consumable
					if type(consumable) == "table" then
						for uid, entry in pairs(consumable) do
							if type(entry) == "table" and entry.id then
								local lower = entry.id:lower()
								if lower:find("trail") or lower:find("mountain") or lower:find("boost") then
									if not seen[uid] then
										seen[uid] = true
										table.insert(uuids, uid)
									end
								end
							end
						end
					end
				end
			end
		end
		if #uuids == 0 then
			local category
			for _, name in ipairs(BOOST_CATEGORIES) do
				category = self:findCategory(name)
				if category then break end
			end
			if category then
				local items = category:FindFirstChild("Items")
				if items then
					for _, slot in ipairs(items:GetChildren()) do
						if slot:IsA("TextButton") then
							local ok, uid = pcall(function() return slot:GetAttribute("ItemUID") end)
							if ok and isUuid(uid) and not seen[uid] then
								seen[uid] = true
								table.insert(uuids, uid)
							end
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
		if self.gcScanning then return self.gcCache or {} end
		self.gcScanning = true
		local results, seen = {}, {}
		local okGc, gc = pcall(getgc, true)
		if not okGc or not gc then self.gcScanning = false; return results end
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
								if type(value[field]) == "number" then hasCount = true; break end
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
		if not feature or feature.thread then return false end
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
		if not feature then return false end
		feature.enabled = false
		return true
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
			pcall(function() connection:Disconnect() end)
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
	{ id = "autoFarmBest", name = "Auto Farm Best (highest camp)" },
	{ id = "breakTrail", name = "Break Trail Chests" },
	{ id = "fightYeti", name = "Fight The Yeti" },
	{ id = "feedYeti", name = "Feed The Yeti" },
	{ id = "fillWalls", name = "Fill Rubble Walls" },
	{ id = "merchant", name = "Buy From Traveling Merchant" },
	{ id = "claimExpedition", name = "Claim Expeditions (auto)" },
	{ id = "sendExpedition", name = "Send Pets On Expeditions" },
	{ id = "teleportCamp", name = "Teleport To Camp" },
	{ id = "artifacts", name = "Find Mountain Artifacts" },
	{ id = "buyUpgrades", name = "Buy Mountain Upgrades" },
	{ id = "useBoosts", name = "Use Mountain Boosts" },
	{ id = "optimize", name = "Optimize Diamond Mountain" },
}

local function ensureDmInstance()
	if vrt.dmInstance then return vrt.dmInstance end
	local ok, instance = pcall(DiamondMountain.new)
	if not ok then return nil, "Init lỗi: " .. tostring(instance) end
	vrt.dmInstance = instance
	pcall(function() instance:setMaxCamp(settings.DMMaxCamp or 6) end)
	if settings.DMFarmPoint then
		pcall(function() instance:setFarmPoint(settings.DMFarmPoint) end)
	end
	if settings.SelectedCustomEggUuid then
		pcall(function() instance:setSelectedEgg(settings.SelectedCustomEggUuid) end)
	end
	return instance
end

local function isInDiamondMountain()
	local info = getInstanceInfo()
	if info and info.InstanceId == "DiamondMountain" then
		return true
	end
	local instance = vrt.dmInstance
	if instance then
		local mountain = instance:getMountain()
		if mountain then return true end
	end
	local zone = getCurrentZone()
	if typeof(zone) == "string" then
		local lower = zone:lower()
		if lower:find("diamond") or lower:find("mountain") then
			return true
		end
	end
	local root = getRoot()
	if root then
		local pos = root.Position
		if pos.X >= -31500 and pos.X <= -28500 and pos.Z >= 29900 and pos.Z <= 31700 then
			return true
		end
	end
	return false
end

local function autoJoinTick()
	local instance = ensureDmInstance()
	if not instance then return end
	local root = getRoot()
	if not root then return end

	if isInDiamondMountain() then
		return
	end

	local now = os.clock()
	if vrt.lastJoinAttempt and now - vrt.lastJoinAttempt < 5 then return end
	vrt.lastJoinAttempt = now

	instance:joinEvent()
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
	local ok, tab = pcall(function() return window:CreateTab(name, icon) end)
	if ok and tab then return tab end
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
local eggDropdown, customEggDropdown

local function refreshAllDropdowns()
	invalidateSaveCache()
	clearDerivedCache()
	BreakablePositions.data = nil
	BreakablePositions.timestamp = 0
	breakablePositionCache = setmetatable({}, { __mode = "k" })
	EggPositions.data = nil
	EggPositions.timestamp = 0
	eggPositionCache = setmetatable({}, { __mode = "k" })
	ZoneCache.data = nil
	ZoneCache.timestamp = 0
	pcall(function()
		if wheelsDropdown then wheelsDropdown:Refresh(buildOptions(getDirectoryIds("SpinnyWheels"))) end
		if chestsDropdown then chestsDropdown:Refresh(buildOptions(getChestNames())) end
		if giftsDropdown then giftsDropdown:Refresh(buildOptions(getGiftIds())) end
		if lootboxDropdown then lootboxDropdown:Refresh(buildOptions(getLootboxIds())) end
		if fruitDropdown then fruitDropdown:Refresh(buildOptions(getBucketIds("Fruit"))) end
		if fruitUpgradeDropdown then fruitUpgradeDropdown:Refresh(buildOptions(getDirectoryIds("Fruits"))) end
		if enchantRarityDropdown then enchantRarityDropdown:Refresh(buildOptions(getEnchantRarities())) end
		if eggDropdown then eggDropdown:Refresh(getEggIdList()) end
		if customEggDropdown then customEggDropdown:Refresh(getCustomEggOptions()) end
	end)
end

getgenv().VRT_RefreshDropdowns = refreshAllDropdowns

-- ================= AUTO-FARM =================
if tabs.farm then
	tabs.farm:CreateSection("Farming Section")
	tabs.farm:CreateSlider({
		Name = "Fast Farm Cooldown (only for Heartbeat one)",
		Range = { 0.05, 1 }, Increment = 0.01, Suffix = "s",
		CurrentValue = settings.FastFarmCooldown, Flag = "FastFarmCooldown",
		Callback = function(value) settings.FastFarmCooldown = value; queueSave() end,
	})
	tabs.farm:CreateToggle({
		Name = "Fast Farm (Heartbeat)", CurrentValue = settings.FastFarmHeartbeat, Flag = "FastFarmHeartbeat",
		Callback = function(value)
			settings.FastFarmHeartbeat = value
			queueSave()
			bindConnection("FastFarmHeartbeat", runService.Heartbeat, Core.FastFarm)
		end,
	})
	tabs.farm:CreateToggle({
		Name = "Fast Farm (While loop)", CurrentValue = settings.FastFarmLoop, Flag = "FastFarmLoop",
		Callback = toggleLoop("FastFarmLoop", 0.15, Core.FastFarm),
	})
	tabs.farm:CreateToggle({
		Name = "Auto Collect Orbs", CurrentValue = settings.CollectOrbs, Flag = "CollectOrbs",
		Callback = toggleLoop("CollectOrbs", 0.3, Core.CollectOrbs),
	})

	tabs.farm:CreateSection("Time Trial")
	tabs.farm:CreateToggle({
		Name = "Auto Time Trial (mở chest time trial)",
		CurrentValue = settings.AutoTimeTrial, Flag = "AutoTimeTrial",
		Callback = toggleLoop("AutoTimeTrial", 5, Core.OpenTimeTrialChests),
	})

	tabs.farm:CreateSection("Farm Point")
	tabs.farm:CreateButton({
		Name = "Set Farm Point (lưu vị trí hiện tại)",
		Callback = function()
			local root = getRoot()
			if not root then
				rayfield:Notify({ Title = "VRT", Content = "Không tìm thấy nhân vật", Duration = 3 })
				return
			end
			settings.FarmPoint = { x = root.Position.X, y = root.Position.Y, z = root.Position.Z }
			queueSave()
			rayfield:Notify({
				Title = "VRT",
				Content = ("Đã lưu farm point (%.0f, %.0f, %.0f)"):format(root.Position.X, root.Position.Y, root.Position.Z),
				Duration = 4,
			})
		end,
	})
	tabs.farm:CreateToggle({
		Name = "Use Farm Point", CurrentValue = settings.UseFarmPoint or false, Flag = "UseFarmPoint",
		Callback = function(value) settings.UseFarmPoint = value; queueSave() end,
	})
	tabs.farm:CreateButton({
		Name = "Clear Farm Point",
		Callback = function()
			settings.FarmPoint = nil
			settings.UseFarmPoint = false
			queueSave()
			rayfield:Notify({ Title = "VRT", Content = "Đã xoá farm point", Duration = 3 })
		end,
	})

	tabs.farm:CreateSection("Click Aura")
	tabs.farm:CreateToggle({
		Name = "Click Aura", CurrentValue = settings.ClickAura, Flag = "ClickAura",
		Callback = function(value)
			settings.ClickAura = value
			queueSave()
			vrt.clickAuraDebug = false
			bindConnection("ClickAura", runService.Heartbeat, Core.ClickAura, settings.ClickAuraCooldown or 0.016)
		end,
	})
	tabs.farm:CreateSlider({
		Name = "Click Aura Radius", Range = { 10, 250 }, Increment = 5, Suffix = "Studs",
		CurrentValue = settings.ClickAuraRadius, Flag = "ClickAuraRadius",
		Callback = function(value) settings.ClickAuraRadius = value; queueSave() end,
	})
	tabs.farm:CreateSlider({
		Name = "Click Aura Cooldown", Range = { 0.016, 0.2 }, Increment = 0.004, Suffix = "s",
		CurrentValue = settings.ClickAuraCooldown or 0.016, Flag = "ClickAuraCooldown",
		Callback = function(value)
			settings.ClickAuraCooldown = value
			queueSave()
			if settings.ClickAura then
				bindConnection("ClickAura", runService.Heartbeat, Core.ClickAura, value)
			end
		end,
	})
	tabs.farm:CreateToggle({
		Name = "Click Aura Visualizer", CurrentValue = settings.ClickAuraViz, Flag = "ClickAuraViz",
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
		Name = "Inf Pet Speed", CurrentValue = settings.InfinitePetSpeed, Flag = "InfinitePetSpeed",
		Callback = function(value)
			settings.InfinitePetSpeed = value
			queueSave()
			Core.InfinitePetSpeed(value)
		end,
	})
	tabs.farm:CreateToggle({
		Name = "Optimize Pets", CurrentValue = settings.OptimizePets, Flag = "OptimizePets",
		Callback = toggleLoop("OptimizePets", 10, Core.OptimizePets),
	})
	tabs.farm:CreateToggle({
		Name = "Anti-Lag (xoá hiệu ứng)", CurrentValue = settings.AntiLag, Flag = "AntiLag",
		Callback = function(value)
			settings.AntiLag = value
			queueSave()
			if value then
				local removed = Core.AntiLag()
				rayfield:Notify({
					Title = "Anti-Lag",
					Content = ("Đã xoá %d hiệu ứng"):format(removed or 0),
					Duration = 3,
				})
			else
				Core.StopAntiLag()
			end
		end,
	})
	tabs.farm:CreateButton({
		Name = "Optimize Breakables",
		Callback = function() Core.OptimizeBreakables() end,
	})
end

-- ================= AUTO KEYS / TICKETS =================
if tabs.keys then
	tabs.keys:CreateSection("Spinny Wheels Section")
	wheelsDropdown = tabs.keys:CreateDropdown({
		Name = "Select Which Spinny Wheels To Spin",
		Options = buildOptions(getDirectoryIds("SpinnyWheels")),
		CurrentOption = settings.SelectedWheels, MultipleOptions = true, Flag = "SelectedWheels",
		Callback = function(option) settings.SelectedWheels = option; queueSave() end,
	})
	tabs.keys:CreateToggle({
		Name = "Spin Selected Wheels", CurrentValue = settings.SpinWheels, Flag = "SpinWheels",
		Callback = toggleLoop("SpinWheels", 0.35, Core.SpinWheels),
	})

	tabs.keys:CreateSection("Chests Section")
	chestsDropdown = tabs.keys:CreateDropdown({
		Name = "Select Which Chests To Open",
		Options = buildOptions(getChestNames()),
		CurrentOption = settings.SelectedChests, MultipleOptions = true, Flag = "SelectedChests",
		Callback = function(option) settings.SelectedChests = option; queueSave() end,
	})
	tabs.keys:CreateToggle({
		Name = "Open Selected Chests", CurrentValue = settings.OpenChests, Flag = "OpenChests",
		Callback = toggleLoop("OpenChests", 1, Core.OpenChests),
	})

	tabs.keys:CreateSection("Keys Section")
	tabs.keys:CreateToggle({
		Name = "Combine Keys All at Once", CurrentValue = settings.CombineKeysAll, Flag = "CombineKeysAll",
		Callback = toggleLoop("CombineKeysAll", 3, Core.CombineKeysAll),
	})
	tabs.keys:CreateToggle({
		Name = "Combine Keys One at Once", CurrentValue = settings.CombineKeysOnce, Flag = "CombineKeysOnce",
		Callback = toggleLoop("CombineKeysOnce", 1.5, Core.CombineKeysOnce),
	})

	tabs.keys:CreateSection("Gift Bags Section")
	giftsDropdown = tabs.keys:CreateDropdown({
		Name = "Select Which Gift Bags To Open",
		Options = buildOptions(getGiftIds()),
		CurrentOption = settings.SelectedGifts, MultipleOptions = true, Flag = "SelectedGifts",
		Callback = function(option) settings.SelectedGifts = option; queueSave() end,
	})
	tabs.keys:CreateToggle({
		Name = "Open Selected Gift Bags (Max)", CurrentValue = settings.OpenGifts, Flag = "OpenGifts",
		Callback = toggleLoop("OpenGifts", 0.33, Core.OpenGiftBags),
	})

	tabs.keys:CreateSection("Lootboxes Section")
	lootboxDropdown = tabs.keys:CreateDropdown({
		Name = "Select Which Lootboxes To Open",
		Options = buildOptions(getLootboxIds()),
		CurrentOption = settings.SelectedLootboxes, MultipleOptions = true, Flag = "SelectedLootboxes",
		Callback = function(option) settings.SelectedLootboxes = option; queueSave() end,
	})
	tabs.keys:CreateToggle({
		Name = "Open Selected Lootboxes (1 type per tick)", CurrentValue = settings.OpenLootboxes, Flag = "OpenLootboxes",
		Callback = toggleLoop("OpenLootboxes", 1, Core.OpenLootboxes),
	})

	tabs.keys:CreateSection("Fruits Section")
	fruitDropdown = tabs.keys:CreateDropdown({
		Name = "Select Fruits to Use",
		Options = buildOptions(getBucketIds("Fruit")),
		CurrentOption = settings.SelectedFruits, MultipleOptions = true, Flag = "SelectedFruits",
		Callback = function(option) settings.SelectedFruits = option; queueSave() end,
	})
	tabs.keys:CreateToggle({
		Name = "Use Selected Fruits (Max per type)", CurrentValue = settings.ConsumeFruits, Flag = "ConsumeFruits",
		Callback = function(value)
			settings.ConsumeFruits = value
			queueSave()
			vrt.fruitLog = {}
			if value then startLoop("ConsumeFruits", 3, Core.ConsumeFruits) else stopLoop("ConsumeFruits") end
		end,
	})

	tabs.keys:CreateSection("Secret Keys Section")
	tabs.keys:CreateToggle({
		Name = "Farm Treehouse Merchant", CurrentValue = settings.FarmTreehouse, Flag = "FarmTreehouse",
		Callback = toggleLoop("FarmTreehouse", 5, Core.FarmTreehouse),
	})
	tabs.keys:CreateButton({
		Name = "Unlock Treehouse",
		Callback = function() invoke("SecretRoom_Unlock", TREEHOUSE_ROOM) end,
	})
	tabs.keys:CreateButton({
		Name = "Enter Treehouse",
		Callback = function() invoke("Instancing_PlayerEnterInstance", TREEHOUSE_ID) end,
	})
	tabs.keys:CreateButton({
		Name = "Leave Treehouse",
		Callback = function() fire("Instancing_PlayerLeaveInstance", TREEHOUSE_ID) end,
	})
end

-- ================= EGGS =================
if tabs.eggs then
	tabs.eggs:CreateSection("Egg Opening")
	tabs.eggs:CreateToggle({
		Name = "Hide Egg Animation", CurrentValue = settings.HideEggAnim, Flag = "HideEggAnim",
		Callback = function(value)
			settings.HideEggAnim = value
			queueSave()
			if value then pcall(hideEggGuis) end
			pcall(installEggHook)
		end,
	})
	tabs.eggs:CreateToggle({
		Name = "Hook Egg Animation (TextLabel custom, no anim)",
		CurrentValue = settings.HookEggAnimation or false, Flag = "HookEggAnimation",
		Callback = function(value)
			settings.HookEggAnimation = value
			queueSave()
			pcall(installEggHook)
		end,
	})
	tabs.eggs:CreateToggle({
		Name = "Auto Open Closest Egg (Max)", CurrentValue = settings.OpenEgg, Flag = "OpenEgg",
		Callback = function(value)
			settings.OpenEgg = value
			queueSave()
			vrt.eggDebugLogged = false
			if value then startLoop("OpenEgg", 0.3, Core.OpenEgg) else stopLoop("OpenEgg") end
		end,
	})

	tabs.eggs:CreateSection("Select Egg (Normal)")
	eggDropdown = tabs.eggs:CreateDropdown({
		Name = "Select Egg To Open",
		Options = getEggIdList(),
		CurrentOption = { settings.SelectedEggId ~= "" and settings.SelectedEggId or (getEggIdList()[1] or "") },
		MultipleOptions = false, Flag = "SelectedEggId",
		Callback = function(option) settings.SelectedEggId = option[1]; queueSave() end,
	})
	tabs.eggs:CreateToggle({
		Name = "Auto Open Selected Egg (Max, no teleport)", CurrentValue = settings.OpenSelectedEgg, Flag = "OpenSelectedEgg",
		Callback = function(value)
			settings.OpenSelectedEgg = value
			queueSave()
			if value then startLoop("OpenSelectedEgg", 0.3, Core.OpenSelectedEgg) else stopLoop("OpenSelectedEgg") end
		end,
	})

	tabs.eggs:CreateSection("Select Egg (Custom / DM)")
	customEggDropdown = tabs.eggs:CreateDropdown({
		Name = "Select Custom Egg (chỉ _hatchable)",
		Options = getCustomEggOptions(),
		CurrentOption = { settings.SelectedCustomEggUuid ~= "" and settings.SelectedCustomEggUuid or (getCustomEggOptions()[1] or "") },
		MultipleOptions = false, Flag = "SelectedCustomEggUuid",
		Callback = function(option)
			local display = option[1]
			local info = vrt.customEggMap[display]
			local uuid = info and info.uid or display
			settings.SelectedCustomEggUuid = uuid
			queueSave()
			if vrt.dmInstance then
				pcall(function() vrt.dmInstance:setSelectedEgg(uuid) end)
			end
		end,
	})
	tabs.eggs:CreateToggle({
		Name = "Auto Buy Selected Custom Egg (Max, no teleport)", CurrentValue = settings.BuySelectedCustomEgg, Flag = "BuySelectedCustomEgg",
		Callback = function(value)
			settings.BuySelectedCustomEgg = value
			queueSave()
			if value then startLoop("BuySelectedCustomEgg", 0.6, Core.BuySelectedCustomEgg) else stopLoop("BuySelectedCustomEgg") end
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
end

-- ================= AUTO =================
if tabs.auto then
	tabs.auto:CreateToggle({
		Name = "Auto Daycare (Claim and Enroll)", CurrentValue = settings.Daycare, Flag = "Daycare",
		Callback = toggleLoop("Daycare", 30, Core.Daycare),
	})
	tabs.auto:CreateToggle({
		Name = "Buy Pet Slots", CurrentValue = settings.PetSlots, Flag = "PetSlots",
		Callback = toggleLoop("PetSlots", 10, Core.BuyPetSlots),
	})
	tabs.auto:CreateToggle({
		Name = "Buy Egg Slots", CurrentValue = settings.AutoEggSlots, Flag = "AutoEggSlots",
		Callback = toggleLoop("AutoEggSlots", 10, Core.BuyEggSlots),
	})
	tabs.auto:CreateToggle({
		Name = "Buy Next Zone", CurrentValue = settings.Zones, Flag = "Zones",
		Callback = toggleLoop("Zones", 2, Core.BuyZone),
	})
	tabs.auto:CreateToggle({
		Name = "Auto Rebirth", CurrentValue = settings.Rebirth, Flag = "Rebirth",
		Callback = toggleLoop("Rebirth", 5, Core.Rebirth),
	})
	tabs.auto:CreateToggle({
		Name = "Use Ultimate", CurrentValue = settings.Ultimate, Flag = "Ultimate",
		Callback = toggleLoop("Ultimate", 2, Core.UseUltimate),
	})
	tabs.auto:CreateToggle({
		Name = "Auto Free Gifts", CurrentValue = settings.FreeGifts, Flag = "FreeGifts",
		Callback = toggleLoop("FreeGifts", 60, Core.ClaimFreeGifts),
	})
	tabs.auto:CreateToggle({
		Name = "Collect Shiny Relics", CurrentValue = settings.Relics, Flag = "Relics",
		Callback = toggleLoop("Relics", 5, Core.CollectRelics),
	})

	tabs.auto:CreateSection("Machine")
	tabs.auto:CreateToggle({
		Name = "Auto Combine Cards", CurrentValue = settings.CardCombine, Flag = "CardCombine",
		Callback = toggleLoop("CardCombine", 3, Core.CombineCards),
	})
	tabs.auto:CreateToggle({
		Name = "Auto Fuse Pets (Rainbow/Golden/Shiny)", CurrentValue = settings.FusePets, Flag = "FusePets",
		Callback = toggleLoop("FusePets", 0.5, Core.FusePets),
	})
	tabs.auto:CreateSlider({
		Name = "Fuse Amount (số lượng Pet mỗi lần ép)",
		Range = { 1, 100 }, Increment = 1, Suffix = "pets",
		CurrentValue = settings.FuseAmount or 5, Flag = "FuseAmount",
		Callback = function(value) settings.FuseAmount = value; queueSave() end,
	})
	tabs.auto:CreateToggle({
		Name = "Auto Gold Machine", CurrentValue = settings.GoldMachine, Flag = "GoldMachine",
		Callback = toggleLoop("GoldMachine", 5, Core.GoldMachine),
	})
	tabs.auto:CreateToggle({
		Name = "Auto Rainbow Machine", CurrentValue = settings.RainbowMachine, Flag = "RainbowMachine",
		Callback = toggleLoop("RainbowMachine", 5, Core.RainbowMachine),
	})

	tabs.auto:CreateSection("Spawn")
	tabs.auto:CreateToggle({
		Name = "Auto Coin Jar", CurrentValue = settings.CoinJar, Flag = "CoinJar",
		Callback = toggleLoop("CoinJar", 5, Core.CoinJar),
	})
	tabs.auto:CreateToggle({
		Name = "Auto Comet", CurrentValue = settings.Comet, Flag = "Comet",
		Callback = toggleLoop("Comet", 5, Core.Comet),
	})

	tabs.auto:CreateSection("Flags")
	local initialFlag = settings.SelectedFlag
	if not table.find(FLAGS, initialFlag) then
		initialFlag = FLAGS[1]
		settings.SelectedFlag = initialFlag
		queueSave()
	end
	tabs.auto:CreateDropdown({
		Name = "Select Flag To Use", Options = FLAGS,
		CurrentOption = { initialFlag }, MultipleOptions = false, Flag = "SelectedFlag",
		Callback = function(option)
			settings.SelectedFlag = option[1]
			queueSave()
			vrt.flagWarned = {}
			vrt.flagInfoWarned = false
			vrt.flagSuccessLogged = false
			vrt.flagFailLogged = false
			flagAutoCache.zoneLog = {}
			flagAutoCache.failLog = {}
		end,
	})
	tabs.auto:CreateSlider({
		Name = "Flag Amount to Use (số lượng dùng mỗi lần)",
		Range = { 1, 45 }, Increment = 1, Suffix = "flags",
		CurrentValue = settings.FlagAmount or 45, Flag = "FlagAmount",
		Callback = function(value) settings.FlagAmount = value; queueSave() end,
	})
	tabs.auto:CreateToggle({
		Name = "Auto Use Flag When In Zone (no teleport)",
		CurrentValue = settings.AutoUseFlagInZone or false,
		Flag = "AutoUseFlagInZone",
		Callback = function(value)
			settings.AutoUseFlagInZone = value
			queueSave()
			flagAutoCache.zoneLog = {}
			flagAutoCache.failLog = {}
			flagAutoCache.lastConsume = 0
			if value then
				startLoop("AutoUseFlagInZone", 1, Core.AutoUseFlag)
			else
				stopLoop("AutoUseFlagInZone")
			end
		end,
	})
end

-- ================= UPDATE =================
if tabs.update then
	tabs.update:CreateSection("Fruits")
	fruitUpgradeDropdown = tabs.update:CreateDropdown({
		Name = "Select Fruits To Upgrade",
		Options = buildOptions(getDirectoryIds("Fruits")),
		CurrentOption = settings.SelectedFruitUpgrade, MultipleOptions = true, Flag = "SelectedFruitUpgrade",
		Callback = function(option) settings.SelectedFruitUpgrade = option; queueSave() end,
	})
	tabs.update:CreateToggle({
		Name = "Upgrade Selected Fruits", CurrentValue = settings.UpgradeFruits, Flag = "UpgradeFruits",
		Callback = toggleLoop("UpgradeFruits", 2, function() Core.UpgradeFruits(false) end),
	})
	tabs.update:CreateToggle({
		Name = "Upgrade Shiny Fruits Only", CurrentValue = settings.UpgradeFruitsShiny, Flag = "UpgradeFruitsShiny",
		Callback = toggleLoop("UpgradeFruitsShiny", 2, function() Core.UpgradeFruits(true) end),
	})

	tabs.update:CreateSection("Potions")
	tabs.update:CreateToggle({
		Name = "Upgrade All Potions (Bulk)", CurrentValue = settings.UpgradePotions, Flag = "UpgradePotions",
		Callback = toggleLoop("UpgradePotions", 2, Core.UpgradePotions),
	})

	tabs.update:CreateSection("Enchants")
	enchantRarityDropdown = tabs.update:CreateDropdown({
		Name = "Select Enchant Rarity",
		Options = buildOptions(getEnchantRarities()),
		CurrentOption = settings.SelectedEnchantRarity, MultipleOptions = true, Flag = "SelectedEnchantRarity",
		Callback = function(option) settings.SelectedEnchantRarity = option; queueSave() end,
	})
	tabs.update:CreateToggle({
		Name = "Upgrade All Enchants", CurrentValue = settings.UpgradeEnchants, Flag = "UpgradeEnchants",
		Callback = toggleLoop("UpgradeEnchants", 2, Core.UpgradeEnchants),
	})
	tabs.update:CreateToggle({
		Name = "Empower Selected Rarity", CurrentValue = settings.EmpowerEnchants, Flag = "EmpowerEnchants",
		Callback = toggleLoop("EmpowerEnchants", 2, Core.EmpowerEnchants),
	})
end

-- ================= AUTO-RANK =================
if tabs.rank then
	tabs.rank:CreateSection("Ranking Section")
	tabs.rank:CreateToggle({
		Name = "Auto Claim Rank Rewards", CurrentValue = settings.RankRewards, Flag = "RankRewards",
		Callback = toggleLoop("RankRewards", 5, Core.ClaimRankRewards),
	})
	local AUTO_RANK_URL = "https://raw.githubusercontent.com/ryomolochiton/367/refs/heads/main/AutoRank.lua"
	vrt.loadAutoRank = function()
		if vrt.autoRankFunc then return vrt.autoRankFunc end
		local ok, source = pcall(game.HttpGet, game, AUTO_RANK_URL)
		if not ok or typeof(source) ~= "string" then return nil, "Không tải được script Auto Rank" end
		local chunk, err = loadstring(source, "AutoRank")
		if not chunk then return nil, "Compile lỗi: " .. tostring(err) end
		local okRun, result = pcall(chunk)
		if not okRun then return nil, "Chạy lỗi: " .. tostring(result) end
		if typeof(result) == "function" then
			vrt.autoRankFunc = result
			return result
		end
		vrt.autoRankFunc = function() end
		return vrt.autoRankFunc
	end
	local loadAutoRank = vrt.loadAutoRank
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
		Name = "Auto Rank", CurrentValue = settings.AutoRank, Flag = "AutoRank",
		Callback = function(value)
			settings.AutoRank = value
			queueSave()
			if not value then stopLoop("AutoRank"); return end
			local func, err = loadAutoRank()
			if not func then
				settings.AutoRank = false
				queueSave()
				rayfield:Notify({ Title = "Auto Rank", Content = err or "Load thất bại", Duration = 8 })
				return
			end
			startLoop("AutoRank", 2, func)
		end,
	})
end

-- ================= EVENT =================
if tabs.event then
	tabs.event:CreateSection("Diamond Mountain")

	tabs.event:CreateToggle({
		Name = "Auto Join Diamond Mountain",
		CurrentValue = settings.DMAutoJoin or false,
		Flag = "DMAutoJoin",
		Callback = function(value)
			settings.DMAutoJoin = value
			queueSave()
			if value then
				startLoop("DMAutoJoin", 5, autoJoinTick)
			else
				stopLoop("DMAutoJoin")
			end
		end,
	})

	tabs.event:CreateButton({
		Name = "Reload Remotes",
		Callback = function()
			local instance = ensureDmInstance()
			if not instance then return end
			pcall(instance.resolveRemotes, instance)
			local missing = instance:getMissingRemotes()
			rayfield:Notify({
				Title = "Diamond Mountain",
				Content = #missing == 0 and "Đã resolve đủ remotes." or ("Thiếu: " .. table.concat(missing, ", ")),
				Duration = 5,
			})
		end,
	})

	tabs.event:CreateSection("Traveling Merchant")

	tabs.event:CreateToggle({
		Name = "Auto Buy From Merchant (chờ visit mới)",
		CurrentValue = settings.AutoMerchant or false,
		Flag = "AutoMerchant",
		Callback = function(value)
			settings.AutoMerchant = value
			queueSave()
			merchantState.lastVisit = nil
			merchantState.attempted = false
			if value then
				startLoop("AutoMerchant", 10, function()
					Core.BuyFromMerchant()
				end)
			else
				stopLoop("AutoMerchant")
			end
		end,
	})

	tabs.event:CreateToggle({
		Name = "Return to original position after buy",
		CurrentValue = settings.MerchantReturnToPos ~= false,
		Flag = "MerchantReturnToPos",
		Callback = function(value)
			settings.MerchantReturnToPos = value
			queueSave()
		end,
	})

	tabs.event:CreateSection("Claim Expedition")

	tabs.event:CreateToggle({
		Name = "Auto Claim Expedition (teleport + touch)",
		CurrentValue = settings.AutoClaimExpedition or false,
		Flag = "AutoClaimExpedition",
		Callback = function(value)
			settings.AutoClaimExpedition = value
			queueSave()
			expeditionState.lastClaimAt = 0
			if value then
				startLoop("AutoClaimExpedition", 5, function()
					Core.ClaimExpedition()
				end)
			else
				stopLoop("AutoClaimExpedition")
			end
		end,
	})

	tabs.event:CreateToggle({
		Name = "Fallback: teleport if far touch fails",
		CurrentValue = settings.ExpeditionFallbackTeleport ~= false,
		Flag = "ExpeditionFallbackTeleport",
		Callback = function(value)
			settings.ExpeditionFallbackTeleport = value
			queueSave()
		end,
	})

	tabs.event:CreateSection("DM Farm Point")

	tabs.event:CreateButton({
		Name = "Set DM Farm Point",
		Callback = function()
			local root = getRoot()
			if not root then
				rayfield:Notify({ Title = "VRT", Content = "Không tìm thấy nhân vật", Duration = 3 })
				return
			end
			settings.DMFarmPoint = { x = root.Position.X, y = root.Position.Y, z = root.Position.Z }
			queueSave()
			if vrt.dmInstance then
				pcall(function() vrt.dmInstance:setFarmPoint(settings.DMFarmPoint) end)
			end
			rayfield:Notify({
				Title = "DM Farm Point",
				Content = ("Đã lưu (%.0f, %.0f, %.0f)"):format(root.Position.X, root.Position.Y, root.Position.Z),
				Duration = 4,
			})
		end,
	})

	tabs.event:CreateToggle({
		Name = "Use DM Farm Point (Auto Farm về đây)",
		CurrentValue = settings.UseDMFarmPoint or false,
		Flag = "UseDMFarmPoint",
		Callback = function(value)
			settings.UseDMFarmPoint = value
			queueSave()
			if vrt.dmInstance then
				if value and settings.DMFarmPoint then
					pcall(function() vrt.dmInstance:setFarmPoint(settings.DMFarmPoint) end)
				else
					pcall(function() vrt.dmInstance:setFarmPoint(nil) end)
				end
			end
		end,
	})

	tabs.event:CreateButton({
		Name = "Clear DM Farm Point",
		Callback = function()
			settings.DMFarmPoint = nil
			settings.UseDMFarmPoint = false
			queueSave()
			if vrt.dmInstance then
				pcall(function() vrt.dmInstance:setFarmPoint(nil) end)
			end
			rayfield:Notify({ Title = "VRT", Content = "Đã xoá DM farm point", Duration = 3 })
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

	tabs.event:CreateSection("Features")

	for _, feature in ipairs(DM_FEATURES) do
		tabs.event:CreateToggle({
			Name = feature.name,
			CurrentValue = false,
			Flag = "DM_" .. feature.id,
			Callback = function(value)
				local inst = ensureDmInstance()
				if not inst then return end
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
	tabs.secret:CreateToggle({
		Name = "Auto Claim Hidden Exclusive Egg", CurrentValue = settings.AdminAbuse or false, Flag = "AdminAbuse",
		Callback = function(value)
			settings.AdminAbuse = value
			queueSave()
			if value then startLoop("AdminAbuse", 5, Core.ClaimFakeCharacters) else stopLoop("AdminAbuse") end
		end,
	})

	tabs.secret:CreateSection("Anti-Cheat")
	tabs.secret:CreateToggle({
		Name = "Log Blocked AC Messages", CurrentValue = false, Flag = "ACLogBlocked",
		Callback = function(value) AntiCheat.logBlocked = value end,
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
		Name = "Clear All Caches",
		Callback = function()
			invalidateSaveCache()
			clearDirectoryCache()
			clearDerivedCache()
			BreakablePositions.data = nil
			BreakablePositions.timestamp = 0
			breakablePositionCache = setmetatable({}, { __mode = "k" })
			EggPositions.data = nil
			EggPositions.timestamp = 0
			eggPositionCache = setmetatable({}, { __mode = "k" })
			ZoneCache.data = nil
			ZoneCache.timestamp = 0
			clickAuraCache.names = {}
			clickAuraCache.rootPos = nil
			clickAuraCache.timestamp = 0
			fruitCooldown = {}
			vrt.fruitLog = {}
			flagAutoCache.zoneLog = {}
			flagAutoCache.failLog = {}
			merchantState.lastVisit = nil
			merchantState.attempted = false
			expeditionState.lastClaimAt = 0
			rayfield:Notify({ Title = "VRT", Content = "Đã xoá tất cả cache", Duration = 3 })
		end,
	})
end

-- ================= MAILBOX =================
if tabs.mailbox then
	tabs.mailbox:CreateInput({
		Name = "Input Username", PlaceholderText = "Input Username",
		CurrentValue = settings.MailboxUsername, RemoveTextAfterFocusLost = false, Flag = "MailboxUsername",
		Callback = function(value) settings.MailboxUsername = value; queueSave() end,
	})
	tabs.mailbox:CreateDropdown({
		Name = "Send Huges Mode", Options = { "New", "All" },
		CurrentOption = { settings.MailboxHugeMode }, MultipleOptions = false, Flag = "MailboxHugeMode",
		Callback = function(option)
			settings.MailboxHugeMode = option[1]
			vrt.sentHuges = {}
			queueSave()
		end,
	})
	tabs.mailbox:CreateToggle({
		Name = "Send Huges By Mode", CurrentValue = settings.MailboxSendHuges, Flag = "MailboxSendHuges",
		Callback = toggleLoop("MailboxSendHuges", 10, Core.MailboxSendHuges),
	})
	tabs.mailbox:CreateToggle({
		Name = "Auto Claim Mailbox", CurrentValue = settings.MailboxClaim, Flag = "MailboxClaim",
		Callback = toggleLoop("MailboxClaim", 10, Core.MailboxClaimAll),
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
			rayfield:Notify({ Title = "Config", Content = "Đã lưu vào " .. CONFIG_PATH, Duration = 4 })
		end,
	})
	tabs.mailbox:CreateButton({
		Name = "Reset Config",
		Callback = function()
			pcall(function()
				if isfile(CONFIG_PATH) then delfile(CONFIG_PATH) end
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
-- Refresh dropdowns
-- -----------------------------------------------------
task.spawn(function()
	task.wait(3)
	pcall(refreshAllDropdowns)
end)

-- -----------------------------------------------------
-- Invalidate breakable cache on new breakable
-- -----------------------------------------------------
do
	local brkFolder = getBreakableFolder()
	if brkFolder then
		brkFolder.ChildAdded:Connect(function()
			BreakablePositions.timestamp = 0
		end)
	end
end

-- -----------------------------------------------------
-- Apply saved toggles
-- -----------------------------------------------------
task.spawn(function()
	task.wait(2)

	if settings.FastFarmHeartbeat then
		bindConnection("FastFarmHeartbeat", runService.Heartbeat, Core.FastFarm)
	end
	if settings.ClickAura then
		bindConnection("ClickAura", runService.Heartbeat, Core.ClickAura, settings.ClickAuraCooldown or 0.016)
	end
	if settings.FastFarmLoop then startLoop("FastFarmLoop", 0.15, Core.FastFarm) end
	if settings.CollectOrbs then startLoop("CollectOrbs", 0.3, Core.CollectOrbs) end
	if settings.ClickAuraViz then startLoop("ClickAuraViz", 0.1, Core.ClickAuraViz) end
	if settings.OptimizePets then startLoop("OptimizePets", 10, Core.OptimizePets) end
	if settings.SpinWheels then startLoop("SpinWheels", 0.35, Core.SpinWheels) end
	if settings.OpenChests then startLoop("OpenChests", 1, Core.OpenChests) end
	if settings.CombineKeysAll then startLoop("CombineKeysAll", 3, Core.CombineKeysAll) end
	if settings.CombineKeysOnce then startLoop("CombineKeysOnce", 1.5, Core.CombineKeysOnce) end
	if settings.OpenGifts then startLoop("OpenGifts", 1, Core.OpenGiftBags) end
	if settings.OpenLootboxes then startLoop("OpenLootboxes", 1, Core.OpenLootboxes) end
	if settings.ConsumeFruits then startLoop("ConsumeFruits", 3, Core.ConsumeFruits) end
	if settings.AutoTimeTrial then startLoop("AutoTimeTrial", 5, Core.OpenTimeTrialChests) end
	if settings.FarmTreehouse then startLoop("FarmTreehouse", 5, Core.FarmTreehouse) end
	if settings.OpenEgg then startLoop("OpenEgg", 0.3, Core.OpenEgg) end
	if settings.OpenSelectedEgg then startLoop("OpenSelectedEgg", 0.3, Core.OpenSelectedEgg) end
	if settings.BuySelectedCustomEgg then startLoop("BuySelectedCustomEgg", 0.6, Core.BuySelectedCustomEgg) end
	if settings.Daycare then startLoop("Daycare", 30, Core.Daycare) end
	if settings.PetSlots then startLoop("PetSlots", 10, Core.BuyPetSlots) end
	if settings.AutoEggSlots then startLoop("AutoEggSlots", 10, Core.BuyEggSlots) end
	if settings.Zones then startLoop("Zones", 2, Core.BuyZone) end
	if settings.Rebirth then startLoop("Rebirth", 5, Core.Rebirth) end
	if settings.Ultimate then startLoop("Ultimate", 2, Core.UseUltimate) end
	if settings.FreeGifts then startLoop("FreeGifts", 60, Core.ClaimFreeGifts) end
	if settings.Relics then startLoop("Relics", 5, Core.CollectRelics) end
	if settings.RankRewards then startLoop("RankRewards", 5, Core.ClaimRankRewards) end
	if settings.AutoRank and typeof(vrt.loadAutoRank) == "function" then
		local func = vrt.loadAutoRank()
		if func then
			startLoop("AutoRank", 2, func)
		else
			settings.AutoRank = false
		end
	end
	if settings.UpgradeFruits then startLoop("UpgradeFruits", 2, function() Core.UpgradeFruits(false) end) end
	if settings.UpgradeFruitsShiny then startLoop("UpgradeFruitsShiny", 2, function() Core.UpgradeFruits(true) end) end
	if settings.UpgradePotions then startLoop("UpgradePotions", 2, Core.UpgradePotions) end
	if settings.UpgradeEnchants then startLoop("UpgradeEnchants", 2, Core.UpgradeEnchants) end
	if settings.EmpowerEnchants then startLoop("EmpowerEnchants", 2, Core.EmpowerEnchants) end
	if settings.CardCombine then startLoop("CardCombine", 3, Core.CombineCards) end
	if settings.FusePets then startLoop("FusePets", 0.5, Core.FusePets) end
	if settings.GoldMachine then startLoop("GoldMachine", 5, Core.GoldMachine) end
	if settings.RainbowMachine then startLoop("RainbowMachine", 5, Core.RainbowMachine) end
	if settings.CoinJar then startLoop("CoinJar", 5, Core.CoinJar) end
	if settings.Comet then startLoop("Comet", 5, Core.Comet) end
	if settings.MailboxSendHuges then startLoop("MailboxSendHuges", 10, Core.MailboxSendHuges) end
	if settings.MailboxClaim then startLoop("MailboxClaim", 10, Core.MailboxClaimAll) end
	if settings.InfinitePetSpeed then Core.InfinitePetSpeed(true) end
	if settings.AutoUseFlagInZone then startLoop("AutoUseFlagInZone", 1, Core.AutoUseFlag) end
	if settings.AutoMerchant then startLoop("AutoMerchant", 10, function() Core.BuyFromMerchant() end) end
	if settings.AutoClaimExpedition then startLoop("AutoClaimExpedition", 5, function() Core.ClaimExpedition() end) end
	if settings.AdminAbuse then startLoop("AdminAbuse", 5, Core.ClaimFakeCharacters) end
	if settings.DMAutoJoin then startLoop("DMAutoJoin", 5, autoJoinTick) end
	if settings.HookEggAnimation or settings.HideEggAnim then pcall(installEggHook) end
end)

-- -----------------------------------------------------
-- Unload
-- -----------------------------------------------------
getgenv().VRT_Unload = function()
	getgenv().VRT_LOADED = false
	for flag, connection in pairs(vrt.connections) do
		pcall(function() connection:Disconnect() end)
		vrt.connections[flag] = nil
	end
	for flag in pairs(vrt.loops) do
		vrt.loops[flag] = nil
	end
	Core.ClickAuraViz()
	Core.InfinitePetSpeed(false)
	if vrt.optimizeConnection then
		pcall(function() vrt.optimizeConnection:Disconnect() end)
		vrt.optimizeConnection = nil
	end
	if vrt.dmInstance then
		pcall(vrt.dmInstance.destroy, vrt.dmInstance)
		vrt.dmInstance = nil
	end
	for gui, conn in pairs(vrt.eggGuiConnections or {}) do
		pcall(function() conn:Disconnect() end)
	end
	vrt.eggGuiConnections = {}

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

	if eggHookState.callOriginal and eggHookState.frontend and eggHookState.funcName then
		pcall(function()
			eggHookState.frontend[eggHookState.funcName] = eggHookState.callOriginal
		end)
	end
	eggHookState.hook = nil
	eggHookState.callOriginal = nil
	eggHookState.thread = nil
	destroyEggMsgGui()

	pcall(saveConfig)
	pcall(function() rayfield:Destroy() end)
end

-- -----------------------------------------------------
-- Send webhook
-- -----------------------------------------------------
task.spawn(function()
	task.wait(2)
	pcall(sendExecutionWebhook)
end)

print(("[VRT] v%s | flags=%d | AC=%s | DM=embedded | id=4"):format(
	vrt.Version, #FLAGS, AntiCheat.active and "ON" or "OFF"
))