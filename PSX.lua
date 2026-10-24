-- Check for table that is shared between executions.
if not shared then
	return warn("No shared, no script.")
end

-- Wait for the game to finish loading.
if not game:IsLoaded() then
	game.Loaded:Wait()
end

-- Services.
local playersService = game:GetService("Players")
local replicatedStorage = game:GetService("ReplicatedStorage")
local runService = game:GetService("RunService")
local teleportService = game:GetService("TeleportService")
local virtualUserService = game:GetService("VirtualUser")

-- Constants.
local RAYFIELD_URL = "https://sirius.menu/rayfield"
local DISCORD_URL = "https://discord.gg/xbyte"
local TAB_ICON = 4483362458
local COIN_TIMEOUT = 8
local LOOTBAG_TIMEOUT = 3
local FARM_MODES = { "Normal", "Multi Target", "Nearest", "Highest Value", "Chests" }
local BOOSTS = { autoTripleDamage = "Triple Damage", autoTripleCoins = "Triple Coins" }
local PRIMED_REMOTES = {
	{ "b", "buy egg" },
	{ "b", "join coin" },
	{ "a", "farm coin" },
	{ "a", "claim orbs" },
	{ "a", "change pet target" },
	{ "b", "redeem rank rewards" },
	{ "b", "redeem vip rewards" },
	{ "a", "activate boost" },
	{ "b", "convert to dark matter" },
	{ "b", "redeem dark matter pet" },
}

-- State.
local localPlayer = playersService.LocalPlayer
local PsxHub = { running = true, rayfield = nil, flags = {}, connections = {} }
local flags = PsxHub.flags
local library, network, things, remotes, coinsFolder
local selectedEgg = nil
local eggLookup = {}
local idToName = {}
local busyPets = {}
local runningLootbags = {}
local eggOpeners = {}
local merchantBought = false
local areaDropdown = nil

flags.farmMode = "Normal"
flags.farmArea = "All"
flags.farmDelay = 0.5
flags.combineCount = 6
flags.darkMatterCount = 6
flags.darkMatterPet = ""

---Resolve the executor request function.
---@return function
local function getRequestFunction()
	return request or http_request or (syn and syn.request) or (http and http.request)
end

---Download the body of an url through the request function.
---@param url string
---@return string
local function httpGet(url)
	local requestFunction = getRequestFunction()
	if not requestFunction then
		error("Executor has no request function.")
	end

	local response = requestFunction({ Url = url, Method = "GET" })
	if type(response) ~= "table" or type(response.Body) ~= "string" or response.Body == "" then
		error("Request failed for " .. url)
	end

	return response.Body
end

---Rayfield dropdowns return a table in newer versions and a string in older ones.
---@param option table|string
---@return string
local function firstOption(option)
	if type(option) == "table" then
		return option[1]
	end

	return option
end

---Format seconds as HH:MM:SS.
---@param seconds number
---@return string
local function formatTime(seconds)
	seconds = math.max(0, math.floor(seconds))
	return ("%02d:%02d:%02d"):format(math.floor(seconds / 3600), math.floor(seconds % 3600 / 60), seconds % 60)
end

---Show a Rayfield notification.
---@param title string
---@param content string
local function notify(title, content)
	if not PsxHub.rayfield then
		return
	end

	PsxHub.rayfield:Notify({ Title = title, Content = content, Duration = 5 })
end

---Get the local player root part.
---@return BasePart?
local function getRoot()
	local character = localPlayer.Character
	return character and character:FindFirstChild("HumanoidRootPart")
end

---Invoke a game remote safely.
---@param name string
---@return any
local function invokeRemote(name, ...)
	local remote = remotes:FindFirstChild(name)
	if not remote then
		return nil
	end

	local success, result = pcall(remote.InvokeServer, remote, ...)
	if not success then
		return nil
	end

	return result
end

---Fire a game remote safely.
---@param name string
local function fireRemote(name, ...)
	local remote = remotes:FindFirstChild(name)
	if not remote then
		return
	end

	pcall(remote.FireServer, remote, ...)
end

---Strip the FRONT suffix so both halves of an area share one name.
---@param areaName string
---@return string
local function getBaseArea(areaName)
	return (tostring(areaName):gsub(" FRONT$", ""))
end

---Get every coin currently alive in the selected area.
---@param areaName string
---@return table
local function getCoins(areaName)
	local response = invokeRemote("get coins", {})
	local coinList = type(response) == "table" and response[1]
	local coins = {}

	if type(coinList) ~= "table" then
		return coins
	end

	for coinId, coin in pairs(coinList) do
		if type(coin) == "table" and (areaName == "All" or getBaseArea(coin.a) == areaName) then
			table.insert(coins, { index = tostring(coinId), name = tostring(coin.n), health = tonumber(coin.h) or 0 })
		end
	end

	return coins
end

---Collect the area names that currently have coins.
---@return string[]
local function collectAreaOptions()
	local response = invokeRemote("get coins", {})
	local coinList = type(response) == "table" and response[1]
	local options = { "All" }
	local seen = { All = true }
	local names = {}

	if type(coinList) == "table" then
		for _, coin in pairs(coinList) do
			if type(coin) == "table" and coin.a then
				local baseArea = getBaseArea(coin.a)
				if not seen[baseArea] then
					seen[baseArea] = true
					table.insert(names, baseArea)
				end
			end
		end
	end

	table.sort(names)
	for _, name in ipairs(names) do
		table.insert(options, name)
	end

	return options
end

---Get the uids of every equipped pet.
---@return string[]
local function getEquippedPets()
	local uids = {}

	for _, pet in pairs(library.Save.Get().Pets) do
		if pet.e then
			table.insert(uids, pet.uid)
		end
	end

	return uids
end

---Send one pet to farm one coin.
---@param coinId string
---@param petUid string
local function farmCoin(coinId, petUid)
	invokeRemote("join coin", { coinId, { petUid } })
	fireRemote("farm coin", { coinId, petUid })
end

---Wait until a coin is broken, the timeout passes or farming stops.
---@param coinId string
---@param timeout number
local function waitForCoinGone(coinId, timeout)
	local startTime = os.clock()

	while PsxHub.running and flags.autoFarm and coinsFolder:FindFirstChild(coinId) and os.clock() - startTime < timeout do
		task.wait()
	end
end

---Send every pet to one coin and wait for it to break.
---@param pets string[]
---@param coin table
local function farmWithAllPets(pets, coin)
	for _, pet in ipairs(pets) do
		task.spawn(farmCoin, coin.index, pet)
	end

	waitForCoinGone(coin.index, COIN_TIMEOUT)
end

local farmModes = {}

farmModes["Normal"] = function(pets, coins)
	for _, coin in ipairs(coins) do
		if not (PsxHub.running and flags.autoFarm) then
			return
		end

		if coinsFolder:FindFirstChild(coin.index) then
			farmWithAllPets(pets, coin)
		end
	end
end

farmModes["Multi Target"] = function(pets, coins)
	for index, coin in ipairs(coins) do
		if not (PsxHub.running and flags.autoFarm) then
			return
		end

		local pet = pets[(index - 1) % #pets + 1]
		if not busyPets[pet] and coinsFolder:FindFirstChild(coin.index) then
			busyPets[pet] = true

			task.spawn(function()
				farmCoin(coin.index, pet)
				waitForCoinGone(coin.index, COIN_TIMEOUT)
				busyPets[pet] = nil
			end)
		end

		if index % #pets == 0 then
			task.wait()
		end
	end
end

farmModes["Nearest"] = function(pets, coins)
	local root = getRoot()
	if not root then
		return
	end

	local nearest, nearestDistance = nil, math.huge
	for _, coin in ipairs(coins) do
		local instance = coinsFolder:FindFirstChild(coin.index)
		local position = instance and instance:FindFirstChild("POS")

		if position then
			local distance = (position.Position - root.Position).Magnitude
			if distance < nearestDistance then
				nearest, nearestDistance = coin, distance
			end
		end
	end

	if nearest then
		farmWithAllPets(pets, nearest)
	end
end

farmModes["Highest Value"] = function(pets, coins)
	table.sort(coins, function(a, b)
		return a.health > b.health
	end)

	for _, coin in ipairs(coins) do
		if coinsFolder:FindFirstChild(coin.index) then
			farmWithAllPets(pets, coin)
			return
		end
	end
end

farmModes["Chests"] = function(pets, coins)
	local chests = {}

	for _, coin in ipairs(coins) do
		if string.find(coin.name, "Chest") then
			table.insert(chests, coin)
		end
	end

	farmModes["Normal"](pets, chests)
end

---Auto farm step.
local function farmStep()
	if not flags.autoFarm then
		return
	end

	local pets = getEquippedPets()
	if #pets == 0 then
		return
	end

	local farmMode = farmModes[flags.farmMode] or farmModes["Normal"]
	farmMode(pets, getCoins(flags.farmArea))
end

---Auto orb step.
local function orbStep()
	if not flags.autoOrbs then
		return
	end

	local orbsFolder = things:FindFirstChild("Orbs")
	if not orbsFolder then
		return
	end

	local names = {}
	for _, orb in ipairs(orbsFolder:GetChildren()) do
		table.insert(names, orb.Name)
	end

	if #names > 0 then
		fireRemote("claim orbs", { names })
	end
end

---Auto lootbag step.
local function lootbagStep()
	if not flags.autoLootbags then
		return
	end

	local lootbagFolder = things:FindFirstChild("Lootbags")
	if not lootbagFolder then
		return
	end

	for _, lootbag in ipairs(lootbagFolder:GetChildren()) do
		if lootbag:IsA("BasePart") and not runningLootbags[lootbag] then
			runningLootbags[lootbag] = true

			task.spawn(function()
				local startTime = os.clock()

				while PsxHub.running and flags.autoLootbags and lootbag.Parent and os.clock() - startTime < LOOTBAG_TIMEOUT do
					local root = getRoot()
					if root then
						lootbag.CFrame = root.CFrame
					end

					task.wait()
				end

				runningLootbags[lootbag] = nil
			end)
		end
	end
end

---Auto hatch step.
local function hatchStep()
	if not flags.autoHatch or not selectedEgg then
		return
	end

	invokeRemote("buy egg", { selectedEgg, flags.tripleHatch == true })
end

---Replace or restore the egg opening animation.
---@param skip boolean
local function setEggAnimation(skip)
	if not getgc then
		return
	end

	for _, object in pairs(getgc(true)) do
		if type(object) == "table" and rawget(object, "OpenEgg") then
			if skip then
				if not eggOpeners[object] then
					eggOpeners[object] = object.OpenEgg
				end

				object.OpenEgg = function() end
			elseif eggOpeners[object] then
				object.OpenEgg = eggOpeners[object]
				eggOpeners[object] = nil
			end
		end
	end
end

---Group the unequipped pets by type so the machines can use them.
---@return table
local function getPetGroups()
	local groups = {}

	for _, pet in pairs(library.Save.Get().Pets) do
		if not pet.e then
			local kind = (pet.g and "Gold") or (pet.r and "Rainbow") or (pet.dm and "Dark Matter") or "Normal"
			local key = kind .. ":" .. tostring(pet.id)

			groups[key] = groups[key] or { kind = kind, uids = {} }
			table.insert(groups[key].uids, pet.uid)
		end
	end

	return groups
end

---Auto golden and rainbow step.
local function combineStep()
	if not flags.autoGolden and not flags.autoRainbow then
		return
	end

	local required = flags.combineCount

	for _, group in pairs(getPetGroups()) do
		if #group.uids >= required then
			local uids = {}
			for index = 1, required do
				uids[index] = group.uids[index]
			end

			if group.kind == "Normal" and flags.autoGolden then
				network.Invoke("use golden machine", uids)
			elseif group.kind == "Gold" and flags.autoRainbow then
				network.Invoke("use rainbow machine", uids)
			end
		end
	end
end

---Auto dark matter step.
local function darkMatterStep()
	if not flags.autoDarkClaim and not flags.autoDarkConvert then
		return
	end

	local save = library.Save.Get()
	local queue = save.DarkMatterQueue or {}

	if flags.autoDarkClaim then
		for queueIndex, entry in pairs(queue) do
			if entry.readyTime - os.time() < 0 then
				invokeRemote("redeem dark matter pet", { queueIndex })
			end
		end
	end

	if not flags.autoDarkConvert or flags.darkMatterPet == "" then
		return
	end

	local queued = 0
	for _ in pairs(queue) do
		queued = queued + 1
	end

	local freeSlots = (save.DarkMatterSlots or 0) - queued
	if freeSlots <= 0 then
		return
	end

	local wanted = string.lower(flags.darkMatterPet)
	local needed = flags.darkMatterCount
	local candidates = {}

	for _, pet in pairs(save.Pets) do
		local name = idToName[pet.id]
		if pet.r and not pet.e and name and string.lower(name) == wanted then
			table.insert(candidates, pet.uid)
		end
	end

	for _ = 1, freeSlots do
		if #candidates < needed then
			break
		end

		local uids = {}
		for _ = 1, needed do
			table.insert(uids, table.remove(candidates))
		end

		invokeRemote("convert to dark matter", { uids })
	end
end

---Show the dark matter queue.
local function showDarkMatterQueue()
	local lines = {}

	for _, entry in pairs(library.Save.Get().DarkMatterQueue or {}) do
		local remaining = entry.readyTime - os.time()
		table.insert(lines, ("%s: %s"):format(idToName[entry.petId] or "?", remaining > 0 and formatTime(remaining) or "Ready"))
	end

	notify("Dark Matter", #lines > 0 and table.concat(lines, "\n") or "Queue is empty.")
end

---Auto rank and vip rewards step.
local function rewardsStep()
	if flags.autoRankReward then
		invokeRemote("redeem rank rewards", {})
	end

	if flags.autoVipReward then
		invokeRemote("redeem vip rewards", {})
	end
end

---Auto boost step.
local function boostStep()
	local mainGui = localPlayer.PlayerGui:FindFirstChild("Main")
	local boostsGui = mainGui and mainGui:FindFirstChild("Boosts")
	if not boostsGui then
		return
	end

	for flagName, boostName in pairs(BOOSTS) do
		if flags[flagName] and not boostsGui:FindFirstChild(boostName) then
			fireRemote("activate boost", { boostName })
		end
	end
end

---Auto merchant step. Buys the selected slots once per merchant visit.
local function merchantStep()
	if not (flags.merchantSlot1 or flags.merchantSlot2 or flags.merchantSlot3) then
		return
	end

	local response = invokeRemote("is merchant here", {})
	local isHere = type(response) == "table" and response[1]

	if isHere and not merchantBought then
		merchantBought = true

		for slot = 1, 3 do
			if flags["merchantSlot" .. slot] then
				invokeRemote("buy merchant item", { slot })
			end
		end
	elseif not isHere then
		merchantBought = false
	end
end

---Disable the heavy visual scripts.
local function applyAntiLag()
	local playerScripts = localPlayer:FindFirstChild("PlayerScripts")
	local scriptsFolder = playerScripts and playerScripts:FindFirstChild("Scripts")
	local guisFolder = scriptsFolder and scriptsFolder:FindFirstChild("GUIs")
	local rewardsHud = guisFolder and guisFolder:FindFirstChild("Coin Rewards HUD")

	if rewardsHud then
		rewardsHud.Disabled = true
	end

	local debris = workspace:FindFirstChild("__DEBRIS")
	if debris then
		debris:Destroy()
	end
end

---Spawn a loop that runs a step while the hub is alive.
---@param name string
---@param interval number|function
---@param step function
local function startLoop(name, interval, step)
	task.spawn(function()
		while PsxHub.running do
			local success, result = pcall(step)
			if not success then
				warn(("[PsxHub] %s: %s"):format(name, tostring(result)))
				task.wait(5)
			end

			local delay = type(interval) == "function" and interval() or interval
			task.wait(math.max(delay, 0.05))
		end
	end)
end

---Stop everything and remove the interface.
function PsxHub.detach()
	PsxHub.running = false

	for _, connection in ipairs(PsxHub.connections) do
		connection:Disconnect()
	end
	table.clear(PsxHub.connections)

	pcall(setEggAnimation, false)
	pcall(runService.Set3dRenderingEnabled, runService, true)

	if PsxHub.rayfield then
		pcall(PsxHub.rayfield.Destroy, PsxHub.rayfield)
		PsxHub.rayfield = nil
	end

	if shared.PsxHub == PsxHub then
		shared.PsxHub = nil
	end
end

---Create a toggle bound to a flag.
---@param tab table
---@param name string
---@param flagName string
---@param default boolean
---@param onChange function?
local function addToggle(tab, name, flagName, default, onChange)
	flags[flagName] = default == true

	tab:CreateToggle({
		Name = name,
		CurrentValue = default == true,
		Flag = flagName,
		Callback = function(value)
			flags[flagName] = value

			if onChange then
				onChange(value)
			end
		end,
	})
end

---Create a slider bound to a flag.
---@param tab table
---@param name string
---@param flagName string
---@param range table
---@param increment number
---@param default number
local function addSlider(tab, name, flagName, range, increment, default)
	flags[flagName] = default

	tab:CreateSlider({
		Name = name,
		Range = range,
		Increment = increment,
		Suffix = "",
		CurrentValue = default,
		Flag = flagName,
		Callback = function(value)
			flags[flagName] = value
		end,
	})
end

---Create a dropdown that returns a single option.
---@param tab table
---@param name string
---@param flagName string
---@param options string[]
---@param default string
---@param onChange function?
---@return table
local function addDropdown(tab, name, flagName, options, default, onChange)
	return tab:CreateDropdown({
		Name = name,
		Options = options,
		CurrentOption = { default },
		MultipleOptions = false,
		Flag = flagName,
		Callback = function(option)
			local value = firstOption(option)

			if onChange then
				onChange(value)
			else
				flags[flagName] = value
			end
		end,
	})
end

---Build the egg dropdown entries sorted by currency and price.
---@return string[]
local function buildEggOptions()
	local entries = {}

	for eggName, eggData in pairs(library.Directory.Eggs) do
		if type(eggData) == "table" and eggData.currency and eggData.cost then
			table.insert(entries, { name = eggName, currency = tostring(eggData.currency), cost = tonumber(eggData.cost) or 0 })
		end
	end

	table.sort(entries, function(a, b)
		if a.currency ~= b.currency then
			return a.currency < b.currency
		end

		return a.cost < b.cost
	end)

	local options = {}
	for _, entry in ipairs(entries) do
		local display = ("%s [%s]"):format(entry.name, entry.currency)
		eggLookup[display] = entry.name
		table.insert(options, display)
	end

	return options
end

---Build the Rayfield interface.
local function buildInterface()
	local rayfield = loadstring(httpGet(RAYFIELD_URL))()
	PsxHub.rayfield = rayfield

	local window = rayfield:CreateWindow({
		Name = "Byte | Pet Simulator X",
		LoadingTitle = "Byte",
		LoadingSubtitle = "discord.gg/xbyte",
		ConfigurationSaving = { Enabled = true, FolderName = "ByteHub", FileName = "PetSimulatorX" },
		Discord = { Enabled = false },
		KeySystem = false,
	})

	-- Farm tab.
	local farmTab = window:CreateTab("Farm", TAB_ICON)
	addToggle(farmTab, "Auto Farm", "autoFarm", false)
	addDropdown(farmTab, "Farm Mode", "farmModeOption", FARM_MODES, "Normal", function(value)
		flags.farmMode = value
	end)
	areaDropdown = addDropdown(farmTab, "Farm Area", "farmAreaOption", collectAreaOptions(), "All", function(value)
		flags.farmArea = value
	end)
	farmTab:CreateButton({
		Name = "Refresh Areas",
		Callback = function()
			pcall(areaDropdown.Refresh, areaDropdown, collectAreaOptions())
		end,
	})
	addSlider(farmTab, "Delay Between Rounds", "farmDelay", { 0.1, 5 }, 0.1, 0.5)
	addToggle(farmTab, "Auto Collect Orbs", "autoOrbs", false)
	addToggle(farmTab, "Auto Collect Lootbags", "autoLootbags", false)
	farmTab:CreateButton({
		Name = "Equip Best Pets",
		Callback = function()
			invokeRemote("equip best pets", {})
		end,
	})

	-- Eggs tab.
	local eggTab = window:CreateTab("Eggs", TAB_ICON)
	local eggOptions = buildEggOptions()
	if #eggOptions > 0 then
		selectedEgg = eggLookup[eggOptions[1]]
		addDropdown(eggTab, "Egg", "eggOption", eggOptions, eggOptions[1], function(value)
			selectedEgg = eggLookup[value]
		end)
	end
	addToggle(eggTab, "Triple Hatch", "tripleHatch", false)
	addToggle(eggTab, "Auto Hatch", "autoHatch", false)
	addToggle(eggTab, "Skip Egg Animation", "skipAnimation", false, function(value)
		if not getgc then
			return notify("Unsupported", "Your executor has no getgc.")
		end

		setEggAnimation(value)
	end)

	-- Pets tab.
	local petTab = window:CreateTab("Pets", TAB_ICON)
	petTab:CreateSection("Golden & Rainbow")
	addSlider(petTab, "Pets Per Machine", "combineCount", { 1, 6 }, 1, 6)
	addToggle(petTab, "Auto Golden", "autoGolden", false)
	addToggle(petTab, "Auto Rainbow", "autoRainbow", false)
	petTab:CreateSection("Dark Matter")
	petTab:CreateInput({
		Name = "Pet Name",
		PlaceholderText = "Exact rainbow pet name",
		RemoveTextAfterFocusLost = false,
		Callback = function(text)
			flags.darkMatterPet = text
		end,
	})
	addSlider(petTab, "Pets Per Conversion", "darkMatterCount", { 1, 6 }, 1, 6)
	addToggle(petTab, "Auto Convert", "autoDarkConvert", false)
	addToggle(petTab, "Auto Claim", "autoDarkClaim", false)
	petTab:CreateButton({ Name = "Show Queue", Callback = showDarkMatterQueue })

	-- Auto tab.
	local autoTab = window:CreateTab("Auto", TAB_ICON)
	addToggle(autoTab, "Rank Rewards", "autoRankReward", false)
	addToggle(autoTab, "VIP Rewards", "autoVipReward", false)
	addToggle(autoTab, "Triple Damage Boost", "autoTripleDamage", false)
	addToggle(autoTab, "Triple Coins Boost", "autoTripleCoins", false)
	autoTab:CreateSection("Merchant (enable before it arrives)")
	addToggle(autoTab, "Buy Slot 1", "merchantSlot1", false)
	addToggle(autoTab, "Buy Slot 2", "merchantSlot2", false)
	addToggle(autoTab, "Buy Slot 3", "merchantSlot3", false)

	-- Misc tab.
	local miscTab = window:CreateTab("Misc", TAB_ICON)
	addToggle(miscTab, "Anti AFK", "antiAfk", true)
	addToggle(miscTab, "Disable 3D Rendering", "noRendering", false, function(value)
		runService:Set3dRenderingEnabled(not value)
	end)
	miscTab:CreateSlider({
		Name = "FPS Cap",
		Range = { 10, 360 },
		Increment = 5,
		Suffix = "",
		CurrentValue = 240,
		Flag = "fpsCap",
		Callback = function(value)
			if setfpscap then
				setfpscap(value)
			end
		end,
	})
	miscTab:CreateButton({ Name = "Anti Lag", Callback = applyAntiLag })
	miscTab:CreateButton({
		Name = "Rejoin",
		Callback = function()
			teleportService:Teleport(game.PlaceId, localPlayer)
		end,
	})
	miscTab:CreateButton({
		Name = "Copy Discord",
		Callback = function()
			if setclipboard then
				setclipboard(DISCORD_URL)
			end

			notify("Discord", DISCORD_URL)
		end,
	})
	miscTab:CreateButton({ Name = "Destroy UI", Callback = PsxHub.detach })
end

---Tell the game server about the remotes this script uses.
local function primeRemotes()
	local mainRemote = remotes:FindFirstChild("MAIN")
	if not mainRemote then
		return
	end

	for _, entry in ipairs(PRIMED_REMOTES) do
		pcall(mainRemote.FireServer, mainRemote, entry[1], entry[2])
	end
end

---Initialize the script.
local function initializeScript()
	library = require(replicatedStorage:WaitForChild("Framework"):WaitForChild("Library"))
	network = library.Network
	things = workspace:WaitForChild("__THINGS")
	remotes = things:WaitForChild("__REMOTES")
	coinsFolder = things:WaitForChild("Coins")

	for petId, petData in pairs(library.Directory.Pets) do
		if type(petData) == "table" and petData.name then
			idToName[petId] = petData.name
		end
	end

	primeRemotes()

	-- Keep the character from being kicked for idling.
	table.insert(
		PsxHub.connections,
		localPlayer.Idled:Connect(function()
			if not flags.antiAfk then
				return
			end

			virtualUserService:Button2Down(Vector2.new(0, 0), workspace.CurrentCamera.CFrame)
			task.wait(1)
			virtualUserService:Button2Up(Vector2.new(0, 0), workspace.CurrentCamera.CFrame)
		end)
	)

	buildInterface()

	startLoop("Farm", function()
		return flags.farmDelay
	end, farmStep)
	startLoop("Orbs", 0.3, orbStep)
	startLoop("Lootbags", 0.5, lootbagStep)
	startLoop("Hatch", 0.1, hatchStep)
	startLoop("Combine", 1, combineStep)
	startLoop("DarkMatter", 15, darkMatterStep)
	startLoop("Rewards", 5, rewardsStep)
	startLoop("Boosts", 2, boostStep)
	startLoop("Merchant", 1, merchantStep)

	PsxHub.rayfield:LoadConfiguration()
	notify("Byte", "Loaded. " .. DISCORD_URL)
end

---This is called when initialization errors.
---@param error string
local function onInitializeError(error)
	warn("Failed to initialize.")
	warn(error)
	warn(debug.traceback())
	PsxHub.detach()
end

-- Detach the previous execution, then become the active one.
if shared.PsxHub then
	shared.PsxHub.detach()
end
shared.PsxHub = PsxHub

-- Safely initialize the script as well as handle errors.
xpcall(initializeScript, onInitializeError)
