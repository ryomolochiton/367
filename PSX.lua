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
local BLACKLIST_TIME = 60
local FARM_MODES = { "Normal", "Multi Target", "Nearest", "Highest Value", "Chests" }
local HATCH_AMOUNTS = { "1", "3", "8" }
local DEFAULT_BOOSTS = { "Triple Coins", "Triple Damage" }
local CHEST_KEYWORDS = { "chest", "vault", "safe" }

-- State.
local localPlayer = playersService.LocalPlayer
local PsxHub = { running = true, rayfield = nil, flags = {}, connections = {} }
local flags = PsxHub.flags
local library, network, coinsFolder
local selectedEggId = nil
local eggLookup = {}
local blacklist = {}
local boostCooldowns = {}
local runningLootbags = {}
local merchantBought = false
local areaDropdown = nil
local eggDropdown = nil

flags.farmMode = "Normal"
flags.farmArea = "All"
flags.farmDelay = 0.5
flags.hatchAmount = 1
flags.darkMatterPet = ""
flags.autoBoosts = {}

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

---Invoke a game network remote safely.
---@param name string
---@return any, any
local function invoke(name, ...)
	local success, first, second = pcall(network.Invoke, name, ...)
	if not success then
		return nil, first
	end

	return first, second
end

---Fire a game network remote safely.
---@param name string
local function fire(name, ...)
	pcall(network.Fire, name, ...)
end

---Mark a key as failed for a while so it is not retried every tick.
---@param key string
local function blacklistKey(key)
	blacklist[key] = os.clock() + BLACKLIST_TIME
end

---Check if a key is still blacklisted.
---@param key string
---@return boolean
local function isBlacklisted(key)
	local expires = blacklist[key]
	return expires ~= nil and expires > os.clock()
end

---Resolve the game library module.
---@return table
local function resolveLibrary()
	local frameworkFolder = replicatedStorage:FindFirstChild("Framework")
	local frameworkLibrary = frameworkFolder and frameworkFolder:FindFirstChild("Library")
	local libraryModule = frameworkLibrary

	if not (libraryModule and libraryModule:IsA("ModuleScript")) then
		libraryModule = replicatedStorage:WaitForChild("Library", 30)
	end

	local gameLibrary = require(libraryModule)
	while not gameLibrary.Loaded do
		task.wait()
	end

	return gameLibrary
end

---Get the uids of every equipped pet.
---@return string[]
local function getEquippedPets()
	local uids = {}
	local success, equipped = pcall(library.PetCmds.GetEquipped, nil, true)

	if success and type(equipped) == "table" then
		for _, uid in ipairs(equipped) do
			table.insert(uids, uid)
		end
	end

	return uids
end

---Get every coin currently alive in the selected area.
---@param areaName string
---@return table
local function getCoins(areaName)
	local response = invoke("Get Coins")
	local coins = {}

	if type(response) ~= "table" then
		return coins
	end

	for coinId, coin in pairs(response) do
		if type(coin) == "table" and (areaName == "All" or tostring(coin.a) == areaName) then
			table.insert(coins, {
				index = tostring(coinId),
				name = tostring(coin.n),
				health = tonumber(coin.h) or 0,
				position = typeof(coin.p) == "Vector3" and coin.p or nil,
			})
		end
	end

	return coins
end

---Collect the area names that currently have coins.
---@return string[]
local function collectAreaOptions()
	local response = invoke("Get Coins")
	local options = { "All" }
	local seen = { All = true }
	local names = {}

	if type(response) == "table" then
		for _, coin in pairs(response) do
			if type(coin) == "table" and coin.a and not seen[tostring(coin.a)] then
				seen[tostring(coin.a)] = true
				table.insert(names, tostring(coin.a))
			end
		end
	end

	table.sort(names)
	for _, name in ipairs(names) do
		table.insert(options, name)
	end

	return options
end

---Send pets to farm one coin.
---@param coin table
---@param petUids string[]
local function farmCoin(coin, petUids)
	if flags.teleportToCoin and coin.position then
		local root = getRoot()
		if root then
			root.CFrame = CFrame.new(coin.position + Vector3.new(0, 6, 0))
		end
	end

	local joined = invoke("Join Coin", coin.index, petUids)
	if type(joined) ~= "table" then
		return
	end

	for petUid, state in pairs(joined) do
		if state == true then
			fire("Farm Coin", coin.index, petUid)
		end
	end
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

local farmModes = {}

farmModes["Normal"] = function(pets, coins)
	for _, coin in ipairs(coins) do
		if not (PsxHub.running and flags.autoFarm) then
			return
		end

		if coinsFolder:FindFirstChild(coin.index) then
			farmCoin(coin, pets)
			waitForCoinGone(coin.index, COIN_TIMEOUT)
		end
	end
end

farmModes["Multi Target"] = function(pets, coins)
	if #coins == 0 then
		return
	end

	local assignments = {}
	for index, petUid in ipairs(pets) do
		local coin = coins[(index - 1) % #coins + 1]
		assignments[coin.index] = assignments[coin.index] or { coin = coin, pets = {} }
		table.insert(assignments[coin.index].pets, petUid)
	end

	local pending = 0
	for _, assignment in pairs(assignments) do
		pending = pending + 1

		task.spawn(function()
			farmCoin(assignment.coin, assignment.pets)
			waitForCoinGone(assignment.coin.index, COIN_TIMEOUT)
			pending = pending - 1
		end)
	end

	local startTime = os.clock()
	while pending > 0 and PsxHub.running and flags.autoFarm and os.clock() - startTime < COIN_TIMEOUT + 2 do
		task.wait()
	end
end

farmModes["Nearest"] = function(pets, coins)
	local root = getRoot()
	if not root then
		return
	end

	local nearest, nearestDistance = nil, math.huge
	for _, coin in ipairs(coins) do
		if coin.position then
			local distance = (coin.position - root.Position).Magnitude
			if distance < nearestDistance then
				nearest, nearestDistance = coin, distance
			end
		end
	end

	if nearest then
		farmCoin(nearest, pets)
		waitForCoinGone(nearest.index, COIN_TIMEOUT)
	end
end

farmModes["Highest Value"] = function(pets, coins)
	table.sort(coins, function(a, b)
		return a.health > b.health
	end)

	if coins[1] then
		farmCoin(coins[1], pets)
		waitForCoinGone(coins[1].index, COIN_TIMEOUT)
	end
end

farmModes["Chests"] = function(pets, coins)
	local chests = {}

	for _, coin in ipairs(coins) do
		local name = string.lower(coin.name)
		for _, keyword in ipairs(CHEST_KEYWORDS) do
			if string.find(name, keyword, 1, true) then
				table.insert(chests, coin)
				break
			end
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

---Auto orb step. Orbs are pulled to the player and claimed.
local function orbStep()
	if not flags.autoOrbs then
		return
	end

	local orbsFolder = library.Things:FindFirstChild("Orbs")
	local root = getRoot()
	if not orbsFolder or not root then
		return
	end

	local ids = {}
	for _, orb in ipairs(orbsFolder:GetChildren()) do
		if orb:IsA("BasePart") then
			orb.CFrame = root.CFrame
		end

		table.insert(ids, orb.Name)
	end

	if #ids > 0 then
		fire("Claim Orbs", ids)
	end
end

---Auto lootbag step. Lootbags are pulled to the player so the game collects them.
local function lootbagStep()
	if not flags.autoLootbags then
		return
	end

	local lootbagFolder = library.Things:FindFirstChild("Lootbags")
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

---Get the egg models of the current world.
---@return Instance[]
local function getEggModels()
	local success, eggs = pcall(library.WorldCmds.GetAllEggs)
	if success and type(eggs) == "table" then
		return eggs
	end

	return {}
end

---Find the egg model with an id.
---@param eggId string
---@return Instance?
local function findEggModel(eggId)
	for _, egg in ipairs(getEggModels()) do
		if egg:GetAttribute("ID") == eggId then
			return egg
		end
	end

	return nil
end

---Build the egg dropdown entries for the current world.
---@return string[]
local function buildEggOptions()
	local entries = {}
	local seen = {}

	table.clear(eggLookup)

	for _, egg in ipairs(getEggModels()) do
		local eggId = egg:GetAttribute("ID")
		local eggData = eggId and library.Directory.Eggs[eggId]

		if eggData and not seen[eggId] then
			seen[eggId] = true
			table.insert(entries, {
				id = eggId,
				name = tostring(eggData.displayName or eggId),
				currency = tostring(eggData.currency or "?"),
				cost = tonumber(eggData.cost) or 0,
			})
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
		if eggLookup[display] then
			display = display .. " (" .. entry.id .. ")"
		end

		eggLookup[display] = entry.id
		table.insert(options, display)
	end

	return options
end

---Auto hatch step.
local function hatchStep()
	if not flags.autoHatch or not selectedEggId then
		return
	end

	local variables = library.Variables
	if flags.waitAnimation and (variables.OpeningEgg or 0) > 0 then
		return
	end

	local root = getRoot()
	local eggModel = findEggModel(selectedEggId)
	local center = eggModel and eggModel:FindFirstChild("Center")

	-- The server rejects purchases when the player is too far from the egg.
	if flags.teleportToEgg and root and center and (root.Position - center.Position).Magnitude > 20 then
		root.CFrame = CFrame.new(center.Position + Vector3.new(0, 4, 8))
		task.wait(0.2)
	end

	local amount = flags.hatchAmount
	local success, message = invoke("Buy Egg", selectedEggId, amount == 3, amount == 8)

	if not success then
		warn("[PsxHub] Buy Egg: " .. tostring(message))
		task.wait(1)
	end
end

---Get the equipped pet set.
---@return table
local function getEquippedSet()
	local set = {}
	for _, uid in ipairs(getEquippedPets()) do
		set[uid] = true
	end

	return set
end

---Get the machine rows for an odds table.
---@param odds table
---@return table?
local function getMachineRows(odds)
	local success, rows = pcall(library.RebornBalance.MachineRows, odds, library.Shared.IsHardcore)
	if success and type(rows) == "table" and #rows > 0 then
		return rows
	end

	return nil
end

---Group the free pets by kind and type so the machines can use them.
---@return table
local function getPetGroups()
	local groups = {}
	local equipped = getEquippedSet()
	local save = library.Save.Get()

	if not save then
		return groups
	end

	for _, pet in ipairs(save.Pets) do
		local petData = library.Directory.Pets[pet.id]
		local usable = petData and not petData.huge and not petData.titanic

		if usable and not equipped[pet.uid] and not pet.l then
			local kind = (pet.r and "Rainbow") or (pet.g and "Gold") or (pet.dm and "DarkMatter") or "Normal"
			local key = ("%s:%s:%s:%s"):format(kind, tostring(pet.id), pet.hc and 1 or 0, pet.sh and 1 or 0)

			groups[key] = groups[key] or { kind = kind, id = pet.id, uids = {} }
			table.insert(groups[key].uids, pet.uid)
		end
	end

	return groups
end

---Take the first uids of a group.
---@param uids string[]
---@param count number
---@return string[]
local function takeUids(uids, count)
	local taken = {}
	for index = 1, count do
		taken[index] = uids[index]
	end

	return taken
end

---Auto golden and rainbow step. Always uses the machine max so the chance is the best one.
local function combineStep()
	if not flags.autoGolden and not flags.autoRainbow then
		return
	end

	local goldRows = getMachineRows(library.Shared.GoldMachineOdds)
	local rainbowRows = getMachineRows(library.Shared.RainbowMachineOdds)

	for key, group in pairs(getPetGroups()) do
		if not (PsxHub.running and (flags.autoGolden or flags.autoRainbow)) then
			return
		end

		local remote, rows = nil, nil
		if group.kind == "Normal" and flags.autoGolden then
			remote, rows = "Use Golden Machine", goldRows
		elseif group.kind == "Gold" and flags.autoRainbow then
			remote, rows = "Use Rainbow Machine", rainbowRows
		end

		if remote and rows and #group.uids >= #rows and not isBlacklisted(key) then
			local success = invoke(remote, takeUids(group.uids, #rows))
			if not success then
				blacklistKey(key)
			end
		end
	end
end

---Auto dark matter step.
local function darkMatterStep()
	if flags.autoDarkClaim then
		invoke("Redeem All Dark Matter Pets")
	end

	if not flags.autoDarkConvert or flags.darkMatterPet == "" then
		return
	end

	local rows = getMachineRows(library.Shared.DarkMatterMachineSettings)
	if not rows then
		return
	end

	local wanted = string.lower(flags.darkMatterPet)

	for key, group in pairs(getPetGroups()) do
		local petData = library.Directory.Pets[group.id]

		if group.kind == "Rainbow" and petData and string.lower(tostring(petData.name)) == wanted then
			if #group.uids >= #rows and not isBlacklisted(key) then
				local success = invoke("Convert To Dark Matter", takeUids(group.uids, #rows))
				if not success then
					blacklistKey(key)
				end
			end
		end
	end
end

---Show the dark matter queue.
local function showDarkMatterQueue()
	local save = library.Save.Get()
	local serverTime = invoke("Get OSTime") or os.time()
	local lines = {}

	for _, entry in pairs(save and save.DarkMatterQueue or {}) do
		local petData = library.Directory.Pets[entry.petId]
		local remaining = entry.readyTime - serverTime
		table.insert(lines, ("%s: %s"):format(petData and petData.name or "?", remaining > 1 and formatTime(remaining) or "Ready"))
	end

	notify("Dark Matter", #lines > 0 and table.concat(lines, "\n") or "Queue is empty.")
end

---Auto rank and vip rewards step.
local function rewardsStep()
	if flags.autoRankReward then
		invoke("Redeem Rank Rewards")
	end

	if flags.autoVipReward then
		invoke("Redeem VIP Rewards")
	end
end

---Check whether a boost entry in the save is running.
---@param value any
---@return boolean
local function isBoostActive(value)
	if type(value) == "number" then
		return value > 0
	end

	return value ~= nil and value ~= false
end

---Auto boost step. Only activates a boost that is not already running.
local function boostStep()
	local save = library.Save.Get()
	if not save then
		return
	end

	for boostName in pairs(flags.autoBoosts) do
		local owned = save.BoostsInventory and save.BoostsInventory[boostName]
		local cooldown = boostCooldowns[boostName] or 0

		if not isBoostActive(save.Boosts and save.Boosts[boostName]) and type(owned) == "number" and owned > 0 and os.clock() > cooldown then
			boostCooldowns[boostName] = os.clock() + 15
			fire("Activate Boost", boostName)
		end
	end
end

---Auto equip best pets step.
local function equipStep()
	if flags.autoEquipBest then
		invoke("Equip Best Pets")
	end
end

---Auto merchant step. Buys the items once per merchant visit.
local function merchantStep()
	if not flags.autoMerchant then
		return
	end

	local isHere = invoke("Is Merchant Here")

	if isHere and not merchantBought then
		merchantBought = true

		local items = invoke("Get Merchant Items")
		local levels = {}
		for key in pairs(type(items) == "table" and items or {}) do
			local level = tonumber(tostring(key):match("%d+"))
			if level then
				table.insert(levels, level)
			end
		end

		table.sort(levels)
		for _, level in ipairs(levels) do
			invoke("Buy Merchant Item", level)
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
		debris:ClearAllChildren()
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

---Create a single option dropdown.
---@param tab table
---@param name string
---@param flagName string
---@param options string[]
---@param default string
---@param onChange function
---@return table
local function addDropdown(tab, name, flagName, options, default, onChange)
	return tab:CreateDropdown({
		Name = name,
		Options = options,
		CurrentOption = { default },
		MultipleOptions = false,
		Flag = flagName,
		Callback = function(option)
			onChange(firstOption(option))
		end,
	})
end

---Collect the boost names the player can activate.
---@return string[]
local function collectBoostOptions()
	local options = {}
	local seen = {}

	local function add(name)
		if not seen[name] then
			seen[name] = true
			table.insert(options, name)
		end
	end

	for _, name in ipairs(DEFAULT_BOOSTS) do
		add(name)
	end

	local save = library.Save.Get()
	for name in pairs(save and save.BoostsInventory or {}) do
		add(tostring(name))
	end

	table.sort(options)
	return options
end

---Build the Rayfield interface.
local function buildInterface()
	local rayfield = loadstring(httpGet(RAYFIELD_URL))()
	PsxHub.rayfield = rayfield

	local window = rayfield:CreateWindow({
		Name = "Byte | PSX Classic",
		LoadingTitle = "Byte",
		LoadingSubtitle = "discord.gg/xbyte",
		ConfigurationSaving = { Enabled = true, FolderName = "ByteHub", FileName = "PSXClassic" },
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
	addToggle(farmTab, "Teleport To Coin (use if pets do not hit)", "teleportToCoin", false)
	addSlider(farmTab, "Delay Between Rounds", "farmDelay", { 0.1, 5 }, 0.1, 0.5)
	addToggle(farmTab, "Auto Collect Orbs", "autoOrbs", false)
	addToggle(farmTab, "Auto Collect Lootbags", "autoLootbags", false)
	addToggle(farmTab, "Auto Equip Best Pets (every 30s)", "autoEquipBest", false)
	farmTab:CreateButton({
		Name = "Equip Best Pets",
		Callback = function()
			invoke("Equip Best Pets")
		end,
	})

	-- Eggs tab.
	local eggTab = window:CreateTab("Eggs", TAB_ICON)
	local eggOptions = buildEggOptions()
	selectedEggId = eggLookup[eggOptions[1]]
	eggDropdown = addDropdown(eggTab, "Egg (current world)", "eggOption", eggOptions, eggOptions[1] or "", function(value)
		selectedEggId = eggLookup[value]
	end)
	eggTab:CreateButton({
		Name = "Refresh Eggs",
		Callback = function()
			local options = buildEggOptions()
			selectedEggId = eggLookup[options[1]]
			pcall(eggDropdown.Refresh, eggDropdown, options)
		end,
	})
	addDropdown(eggTab, "Hatch Amount (3 and 8 need the pass)", "hatchAmountOption", HATCH_AMOUNTS, "1", function(value)
		flags.hatchAmount = tonumber(value) or 1
	end)
	addToggle(eggTab, "Teleport To Egg (server checks distance)", "teleportToEgg", true)
	addToggle(eggTab, "Wait For Animation", "waitAnimation", true)
	addToggle(eggTab, "Auto Hatch", "autoHatch", false)

	-- Pets tab.
	local petTab = window:CreateTab("Pets", TAB_ICON)
	petTab:CreateSection("Machines cost Diamonds. Uses the max pets for the best chance.")
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
	addToggle(petTab, "Auto Convert", "autoDarkConvert", false)
	addToggle(petTab, "Auto Claim", "autoDarkClaim", false)
	petTab:CreateButton({ Name = "Show Queue", Callback = showDarkMatterQueue })

	-- Auto tab.
	local autoTab = window:CreateTab("Auto", TAB_ICON)
	addToggle(autoTab, "Rank Rewards", "autoRankReward", false)
	addToggle(autoTab, "VIP Rewards", "autoVipReward", false)
	autoTab:CreateDropdown({
		Name = "Auto Boosts (only when not running)",
		Options = collectBoostOptions(),
		CurrentOption = {},
		MultipleOptions = true,
		Flag = "autoBoostOptions",
		Callback = function(options)
			flags.autoBoosts = {}
			for _, name in ipairs(type(options) == "table" and options or { options }) do
				flags.autoBoosts[name] = true
			end
		end,
	})
	autoTab:CreateSection("Merchant spends Diamonds")
	addToggle(autoTab, "Buy All Merchant Items", "autoMerchant", false)

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

---Initialize the script.
local function initializeScript()
	library = resolveLibrary()
	network = library.Network
	coinsFolder = library.Things:WaitForChild("Coins")

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
	startLoop("Hatch", 0.2, hatchStep)
	startLoop("Combine", 2, combineStep)
	startLoop("DarkMatter", 15, darkMatterStep)
	startLoop("Rewards", 10, rewardsStep)
	startLoop("Boosts", 5, boostStep)
	startLoop("Equip", 30, equipStep)
	startLoop("Merchant", 2, merchantStep)

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
