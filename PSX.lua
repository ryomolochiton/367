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
local BLACKLIST_TIME = 60
local LOOTBAG_TIMEOUT = 3
local HATCH_BUFFER = 3
local RESYNC_INTERVAL = 20
local BEST_AREA = "Best Unlocked Area"
local FARM_MODES = { "All Pets on One Coin", "One Pet per Coin" }
local COIN_PRIORITIES = { "Nearest", "Highest Health", "Lowest Health" }
local EGG_PRESETS = { "Best Unlocked Egg", "Best Unlocked Normal Egg", "Best Unlocked Golden Egg" }
local EGG_AMOUNTS = { "Best Available", "1 Egg", "3 Eggs", "8 Eggs" }
local DEFAULT_BOOSTS = { "Triple Coins", "Triple Damage" }
local DEFAULT_CHESTS = { "Giant Tech Chest", "Giant Steampunk Chest", "Giant Rainbow Chest" }
local PROTECTED_RARITIES = { Huge = true, Titanic = true }
local FUSABLE_RARITIES = { "Basic", "Rare", "Epic", "Legendary" }
local FUSE_BLOCKED = { Event = true, Exclusive = true, Secret = true, Mythical = true }
local SELECT_GRACE = 4
local DAMAGE_GRACE = 3

-- State.
local localPlayer = playersService.LocalPlayer
local PsxHub = { running = true, rayfield = nil, flags = {}, connections = {}, status = {} }
local flags = PsxHub.flags
local status = PsxHub.status
local library, network
local coinCache = {}
local selections = {}
local failedCoins = {}
local lastAck = {}
local originalPetsControl = nil
local lastMode = nil
local blacklist = {}
local boostCooldowns = {}
local runningLootbags = {}
local managedRarities = {}
local homeLabels = {}
local areaLookup = {}
local eggLookup = {}
local upgradeLookup = {}
local areaDropdown, eggDropdown, chestDropdown
local merchantBought = false
local hatchMode = false
local originalOpenEgg = nil
local lastResync = 0

flags.farmArea = BEST_AREA
flags.farmMode = FARM_MODES[2]
flags.coinPriority = COIN_PRIORITIES[1]
flags.farmDelay = 0.4
flags.eggChoice = EGG_PRESETS[2]
flags.eggAmount = EGG_AMOUNTS[1]
flags.keepPets = 4
flags.fuseCount = 12
flags.selectedChests = {}
flags.selectedUpgrades = {}
flags.autoBoosts = {}
flags.deleteRarities = {}
flags.fuseRarities = {}

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

---Turn the selected dropdown options into a set.
---@param options table|string
---@return table
local function toSet(options)
	local set = {}

	for _, name in ipairs(type(options) == "table" and options or { options }) do
		set[name] = true
	end

	return set
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

	pcall(PsxHub.rayfield.Notify, PsxHub.rayfield, { Title = title, Content = content, Duration = 6 })
end

---Call a function and return its result, or nil when it errors.
---@param callback function
---@return any
local function safeCall(callback, ...)
	local success, result = pcall(callback, ...)
	if success then
		return result
	end

	return nil
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
	local libraryModule = frameworkFolder and frameworkFolder:FindFirstChild("Library")

	if not (libraryModule and libraryModule:IsA("ModuleScript")) then
		libraryModule = replicatedStorage:WaitForChild("Library", 30)
	end

	local gameLibrary = require(libraryModule)
	while not gameLibrary.Loaded do
		task.wait()
	end

	return gameLibrary
end

---Get the player save.
---@return table?
local function getSave()
	return safeCall(library.Save.Get)
end

---Get the amount of a currency.
---@param save table
---@param currency string
---@return number
local function getCurrency(save, currency)
	return tonumber(save[currency]) or 0
end

---Get the uids of every equipped pet.
---@return string[]
local function getEquippedPets()
	local uids = {}
	local equipped = safeCall(library.PetCmds.GetEquipped, nil, true)

	if type(equipped) == "table" then
		for _, uid in ipairs(equipped) do
			table.insert(uids, uid)
		end
	end

	return uids
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

---Take the first uids of a list.
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

---Get the current world name.
---@return string?
local function getWorldName()
	return safeCall(library.WorldCmds.Get)
end

---Check if the player owns an area.
---@param name string
---@return boolean
local function hasArea(name)
	return safeCall(library.WorldCmds.HasArea, name) == true
end

---Check if an area is open (not locked by an event).
---@param name string
---@return boolean
local function isAreaOpen(name)
	return safeCall(library.RebornLock.AreaOpen, name) ~= false
end

---Get the farmable areas of the current world, worst first.
---@return table
local function getWorldAreas()
	local world = getWorldName()
	local areas = {}

	for name, area in pairs(library.Directory.Areas) do
		if type(area) == "table" and area.world == world and not area.hidden and not area.isShop then
			table.insert(areas, { name = name, data = area })
		end
	end

	table.sort(areas, function(a, b)
		return (tonumber(a.data.mult) or 0) < (tonumber(b.data.mult) or 0)
	end)

	return areas
end

---Get the best area the player owns.
---@return string?
local function getBestArea()
	local areas = getWorldAreas()

	for index = #areas, 1, -1 do
		local name = areas[index].name
		if hasArea(name) and isAreaOpen(name) then
			return name
		end
	end

	return nil
end

---Get the cheapest area that is still locked.
---@return string?, table?
local function getNextArea()
	local best, bestCost, bestGate = nil, math.huge, nil

	for _, area in ipairs(getWorldAreas()) do
		local gate = area.data.gate
		if gate and tonumber(gate.cost) and not hasArea(area.name) and isAreaOpen(area.name) and gate.cost < bestCost then
			best, bestCost, bestGate = area.name, gate.cost, gate
		end
	end

	return best, bestGate
end

---Build a coin entry from the server data.
---@param id string
---@param data table
---@return table
local function normalizeCoin(id, data)
	return {
		index = tostring(id),
		name = tostring(data.n),
		area = data.a and tostring(data.a) or nil,
		health = tonumber(data.h) or 0,
		position = typeof(data.p) == "Vector3" and data.p or nil,
		distance = math.huge,
		lastDamage = 0,
	}
end

---Reload every coin of the world from the server.
local function resyncCoins()
	local response = invoke("Get Coins")
	if type(response) ~= "table" then
		return
	end

	local fresh = {}
	for coinId, data in pairs(response) do
		if type(data) == "table" then
			fresh[tostring(coinId)] = normalizeCoin(coinId, data)
		end
	end

	coinCache = fresh
	lastResync = os.clock()
end

---Listen to a game network event.
---@param name string
---@param handler function
local function connectEvent(name, handler)
	local signal = safeCall(network.Fired, name)
	if not signal then
		return
	end

	local connection = safeCall(signal.Connect, signal, handler)
	if connection then
		table.insert(PsxHub.connections, connection)
	end
end

---Get the distance the server accepts for coins.
---@return number
local function getCoinRange()
	local settings = library.Settings
	return (settings and tonumber(settings.CoinGrabDistance) or 300) - 20
end

---Move the character next to a position.
---@param position Vector3
local function teleportTo(position)
	local root = getRoot()
	if root then
		root.CFrame = CFrame.new(position + Vector3.new(0, 6, 0))
	end
end

---Check if a coin is a giant one.
---@param coin table
---@return boolean
local function isGiantCoin(coin)
	return string.find(string.lower(coin.name), "giant", 1, true) ~= nil
end

---Get the model the game uses for a coin.
---@param coinId string
---@return Instance?
local function getCoinModel(coinId)
	local coinsFolder = library.Things:FindFirstChild("Coins")
	return coinsFolder and coinsFolder:FindFirstChild(coinId)
end

---Check if pets are attacking a coin we selected. Damage events are the proof.
---@param coin table
---@return boolean
local function isActive(coin)
	local selection = selections[coin.index]
	if not selection then
		return false
	end

	local now = os.clock()
	return now - selection.time < SELECT_GRACE or now - coin.lastDamage < DAMAGE_GRACE
end

---Check if a coin was refused recently.
---@param coin table
---@return boolean
local function isFailed(coin)
	return (failedCoins[coin.index] or 0) > os.clock()
end

---Make single selections pick one pet instead of the whole group.
local function ensureSinglePetControl()
	local save = getSave()
	local settings = save and save.Settings

	if type(settings) == "table" and settings.PetsControl == 2 then
		originalPetsControl = originalPetsControl or settings.PetsControl
		settings.PetsControl = 1
	end
end

---Restore the pets control setting.
local function restorePetsControl()
	local save = getSave()
	local settings = save and save.Settings

	if originalPetsControl and type(settings) == "table" then
		settings.PetsControl = originalPetsControl
	end

	originalPetsControl = nil
end

---Select a coin exactly like a tap does and wait for the server answer.
---The game then sends the pets and fires Farm Coin when they arrive.
---@param coin table
---@param allPets boolean
---@return boolean
local function selectCoin(coin, allPets)
	local model = getCoinModel(coin.index)
	if not model then
		failedCoins[coin.index] = os.clock() + 3
		return false
	end

	local before = lastAck[coin.index]
	local eventName = allPets and "Group Select Coin" or "Select Coin"
	if not pcall(library.Signal.Fire, eventName, model) then
		status.farm = "Signal.Fire failed"
		return false
	end

	local startTime = os.clock()
	while PsxHub.running and os.clock() - startTime < 1.5 do
		if lastAck[coin.index] ~= before then
			selections[coin.index] = { time = os.clock() }
			return true
		end

		task.wait()
	end

	-- The server refused (the coin is too far or already gone).
	failedCoins[coin.index] = os.clock() + 5
	status.farm = ("Join Coin refused: %s"):format(coin.name)
	return false
end

---Break the selected giant chests. Returns true while a chest is being handled.
---@param coins table
---@return boolean
local function breakChests(coins)
	if not flags.autoChests or next(flags.selectedChests) == nil then
		return false
	end

	local targets = {}
	for _, coin in ipairs(coins) do
		if flags.selectedChests[coin.name] then
			table.insert(targets, coin)
		end
	end

	if #targets == 0 then
		return false
	end

	table.sort(targets, function(a, b)
		return a.distance < b.distance
	end)

	local target = targets[1]
	status.farm = ("Giant chest: %s"):format(target.name)

	if target.distance > getCoinRange() then
		teleportTo(target.position)
		task.wait(0.4)
		return true
	end

	if not isActive(target) and not isFailed(target) then
		selectCoin(target, true)
	end

	return true
end

---Farm the coins of the selected area.
---@param coins table
---@param pets string[]
local function farmCoins(coins, pets)
	local areaName = flags.farmArea == BEST_AREA and getBestArea() or flags.farmArea
	local candidates = {}

	for _, coin in ipairs(coins) do
		local areaMatches = not areaName or coin.area == areaName
		if areaMatches and not (flags.ignoreGiant and isGiantCoin(coin)) then
			table.insert(candidates, coin)
		end
	end

	-- The area name did not match any coin, so farm everything around instead.
	if #candidates == 0 then
		for _, coin in ipairs(coins) do
			if not (flags.ignoreGiant and isGiantCoin(coin)) then
				table.insert(candidates, coin)
			end
		end
	end

	if #candidates == 0 then
		status.farm = "No coins found"
		return
	end

	local range = getCoinRange()
	local inRange = {}
	for _, coin in ipairs(candidates) do
		if coin.distance <= range then
			table.insert(inRange, coin)
		end
	end

	-- The server only accepts coins close to the player, so move to the area first.
	if #inRange == 0 then
		table.sort(candidates, function(a, b)
			return a.distance < b.distance
		end)

		status.farm = ("Moving to %s"):format(tostring(areaName or "coins"))
		teleportTo(candidates[1].position)
		task.wait(0.4)
		return
	end

	table.sort(inRange, function(a, b)
		if flags.coinPriority == "Highest Health" then
			return a.health > b.health
		elseif flags.coinPriority == "Lowest Health" then
			return a.health < b.health
		end

		return a.distance < b.distance
	end)

	if lastMode ~= flags.farmMode then
		lastMode = flags.farmMode
		table.clear(selections)
	end

	local active = 0
	for _, coin in pairs(coinCache) do
		if isActive(coin) then
			active = active + 1
		end
	end

	status.farm = ("%s | in range %d | attacking %d | pets %d"):format(tostring(areaName or "All"), #inRange, active, #pets)

	if flags.farmMode == FARM_MODES[1] then
		if active == 0 then
			for _, coin in ipairs(inRange) do
				if not isFailed(coin) and selectCoin(coin, true) then
					break
				end
			end
		end

		return
	end

	ensureSinglePetControl()

	local needed = #pets - active
	for _, coin in ipairs(inRange) do
		if needed <= 0 or not PsxHub.running then
			break
		end

		if not isActive(coin) and not isFailed(coin) and selectCoin(coin, false) then
			needed = needed - 1
		end
	end
end

---Farm step.
local function farmStep()
	if not flags.autoFarm and not flags.autoChests then
		return
	end

	local root = getRoot()
	local pets = getEquippedPets()

	if not root or #pets == 0 then
		status.farm = "No character or no equipped pets"
		return
	end

	local coins = {}
	for _, coin in pairs(coinCache) do
		if coin.position then
			coin.distance = (coin.position - root.Position).Magnitude
			table.insert(coins, coin)
		end
	end

	if breakChests(coins) then
		return
	end

	if flags.autoFarm then
		farmCoins(coins, pets)
	end
end

---Get the egg models of the current world with their data.
---@return table
local function collectEggEntries()
	local entries = {}
	local models = safeCall(library.WorldCmds.GetAllEggs)

	for _, model in ipairs(type(models) == "table" and models or {}) do
		local eggId = model:GetAttribute("ID")
		local data = eggId and library.Directory.Eggs[eggId]

		if data and data.hatchable ~= false and not data.disabled then
			table.insert(entries, {
				id = eggId,
				data = data,
				model = model,
				name = tostring(data.displayName or eggId),
				unlocked = model:GetAttribute("Unlocked") == true,
				cost = tonumber(data.cost) or 0,
			})
		end
	end

	return entries
end

---Resolve the egg the player wants to buy.
---@param entries table
---@return table?
local function resolveEgg(entries)
	local choice = flags.eggChoice
	local best = nil

	for _, entry in ipairs(entries) do
		local matches = false

		if choice == EGG_PRESETS[1] then
			matches = entry.unlocked
		elseif choice == EGG_PRESETS[2] then
			matches = entry.unlocked and not entry.data.isGolden
		elseif choice == EGG_PRESETS[3] then
			matches = entry.unlocked and entry.data.isGolden == true
		else
			matches = entry.name == choice
		end

		if matches and (not best or entry.cost > best.cost) then
			best = entry
		end
	end

	return best
end

---Get how many eggs can be opened at once.
---@param save table
---@return number
local function getMaxEggAmount(save)
	if flags.eggAmount == EGG_AMOUNTS[2] then
		return 1
	elseif flags.eggAmount == EGG_AMOUNTS[3] then
		return 3
	elseif flags.eggAmount == EGG_AMOUNTS[4] then
		return 8
	end

	if save.OwnsOctupleEggs then
		return 8
	end

	local gamepass = safeCall(function()
		return library.Gamepasses.Owns(library.Directory.Gamepasses["Triple Egg Open"].ID)
	end)

	return gamepass and 3 or 1
end

---Count the pets the player owns that come from an egg.
---@param save table
---@param eggData table
---@return number
local function countEggPets(save, eggData)
	local drops = eggData.drops
	if type(drops) == "string" then
		local source = library.Directory.Eggs[drops]
		drops = source and source.drops
	end

	if type(drops) ~= "table" then
		return 0
	end

	local ids = {}
	for _, drop in ipairs(drops) do
		ids[tostring(drop[1])] = true
	end

	local total = 0
	for _, pet in ipairs(save.Pets) do
		if ids[tostring(pet.id)] then
			total = total + 1
		end
	end

	return total
end

---Decide if the player should be hatching right now.
---@param save table
---@return table?, number
local function getHatchTarget(save)
	local entry = resolveEgg(collectEggEntries())
	if not entry then
		status.egg = "No egg found for the selection"
		return nil, 0
	end

	if flags.saveMoney then
		local nextArea = getNextArea()
		if nextArea and countEggPets(save, entry.data) >= flags.keepPets then
			status.egg = ("Saving money for %s"):format(nextArea)
			hatchMode = false
			return nil, 0
		end
	end

	local money = getCurrency(save, entry.data.currency)
	local maxAmount = getMaxEggAmount(save)
	local amount = 0

	for _, option in ipairs({ 8, 3, 1 }) do
		if option <= maxAmount and money >= entry.cost * option then
			amount = option
			break
		end
	end

	-- Keep a buffer before going back to hatching so the player does not bounce between the egg and the area.
	local needed = hatchMode and entry.cost or entry.cost * math.max(amount, 1) * HATCH_BUFFER
	if amount == 0 or money < needed then
		status.egg = ("Waiting for %s (%s)"):format(entry.data.currency, entry.name)
		hatchMode = false
		return nil, 0
	end

	hatchMode = true
	return entry, amount
end

---Buy an egg.
---@param entry table
---@param amount number
local function hatchEgg(entry, amount)
	local root = getRoot()
	local center = entry.model:FindFirstChild("Center")
	local position = center and center.Position or entry.model:GetPivot().Position

	-- The server rejects purchases when the player is too far from the egg.
	if root and (root.Position - position).Magnitude > 20 then
		root.CFrame = CFrame.new(position + Vector3.new(0, 4, 8))
		task.wait(0.25)
	end

	local success, message = invoke("Buy Egg", entry.id, amount == 3, amount == 8)
	status.egg = success and ("Hatching %s x%d"):format(entry.name, amount) or ("Buy Egg failed: %s"):format(tostring(message))

	if not success then
		task.wait(1)
	end
end

---Main step. Hatching has priority and farming earns the money for it.
local function mainStep()
	local save = getSave()
	if not save or not getRoot() then
		return
	end

	if os.clock() - lastResync > RESYNC_INTERVAL then
		resyncCoins()
	end

	if flags.autoHatch then
		local variables = library.Variables
		if not flags.skipAnimation and (variables.OpeningEgg or 0) > 0 then
			return
		end

		local entry, amount = getHatchTarget(save)
		if entry then
			hatchEgg(entry, amount)
			return
		end
	else
		hatchMode = false
	end

	farmStep()
end

---Auto collect step. Orbs and lootbags are pulled to the player.
local function collectStep()
	if not flags.autoCollect then
		return
	end

	local root = getRoot()
	if not root then
		return
	end

	local orbsFolder = library.Things:FindFirstChild("Orbs")
	if orbsFolder then
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

	local lootbagFolder = library.Things:FindFirstChild("Lootbags")
	if not lootbagFolder then
		return
	end

	for _, lootbag in ipairs(lootbagFolder:GetChildren()) do
		if lootbag:IsA("BasePart") and not runningLootbags[lootbag] then
			runningLootbags[lootbag] = true

			task.spawn(function()
				local startTime = os.clock()

				while PsxHub.running and flags.autoCollect and lootbag.Parent and os.clock() - startTime < LOOTBAG_TIMEOUT do
					local currentRoot = getRoot()
					if currentRoot then
						lootbag.CFrame = currentRoot.CFrame
					end

					task.wait()
				end

				runningLootbags[lootbag] = nil
			end)
		end
	end
end

---Replace or restore the egg opening animation.
---@param enabled boolean
local function setSkipAnimation(enabled)
	if not getsenv then
		return notify("Unsupported", "Your executor has no getsenv.")
	end

	local playerScripts = localPlayer:FindFirstChild("PlayerScripts")
	local scriptsFolder = playerScripts and playerScripts:FindFirstChild("Scripts")
	local gameFolder = scriptsFolder and scriptsFolder:FindFirstChild("Game")
	local openEggs = gameFolder and gameFolder:FindFirstChild("Open Eggs")
	local env = openEggs and safeCall(getsenv, openEggs)

	if not env then
		return notify("Skip Animation", "Could not read the Open Eggs script.")
	end

	if enabled then
		originalOpenEgg = originalOpenEgg or env.OpenEgg

		env.OpenEgg = function(eggId)
			pcall(library.Signal.Fire, "Opening Egg", eggId)
			pcall(library.Signal.Fire, "Done Opening Egg", eggId)
		end

		if env.OpenEgg == originalOpenEgg then
			notify("Skip Animation", "Your executor did not apply the change.")
		end
	elseif originalOpenEgg then
		env.OpenEgg = originalOpenEgg
	end
end

---Get the machine rows for an odds table.
---@param odds table
---@return table?
local function getMachineRows(odds)
	local rows = safeCall(library.RebornBalance.MachineRows, odds, library.Shared.IsHardcore)
	if type(rows) == "table" and #rows > 0 then
		return rows
	end

	return nil
end

---Get the kind of a pet.
---@param pet table
---@return string
local function getPetKind(pet)
	return (pet.r and "Rainbow") or (pet.g and "Gold") or (pet.dm and "DarkMatter") or "Normal"
end

---Group the free pets by kind and type so the machines can use them.
---@return table
local function getPetGroups()
	local groups = {}
	local equipped = getEquippedSet()
	local save = getSave()

	if not save then
		return groups
	end

	for _, pet in ipairs(save.Pets) do
		local petData = library.Directory.Pets[pet.id]
		local usable = petData and not PROTECTED_RARITIES[tostring(petData.rarity)]

		if usable and not equipped[pet.uid] and not pet.l then
			local kind = getPetKind(pet)
			local key = ("%s:%s:%s:%s"):format(kind, tostring(pet.id), pet.hc and 1 or 0, pet.sh and 1 or 0)

			groups[key] = groups[key] or { kind = kind, id = pet.id, uids = {} }
			table.insert(groups[key].uids, pet.uid)
		end
	end

	return groups
end

---Auto golden and rainbow step. Always uses the machine max so the chance is the best one.
local function machineStep()
	if not flags.autoGolden and not flags.autoRainbow then
		return
	end

	local goldRows = getMachineRows(library.Shared.GoldMachineOdds)
	local rainbowRows = getMachineRows(library.Shared.RainbowMachineOdds)

	for key, group in pairs(getPetGroups()) do
		if not PsxHub.running then
			return
		end

		local remote, rows = nil, nil
		if group.kind == "Normal" and flags.autoGolden then
			remote, rows = "Use Golden Machine", goldRows
		elseif group.kind == "Gold" and flags.autoRainbow then
			remote, rows = "Use Rainbow Machine", rainbowRows
		end

		if remote and rows and #group.uids >= #rows and not isBlacklisted(key) then
			local success, message = invoke(remote, takeUids(group.uids, #rows))
			status.machine = success and (remote .. " ok") or (remote .. ": " .. tostring(message))

			if not success then
				blacklistKey(key)
			end
		end
	end
end

---Auto fuse step. Fuses normal pets of the selected rarities (Basic when nothing is selected).
local function fuseStep()
	if not flags.autoFuse then
		return
	end

	local save = getSave()
	if not save then
		return
	end

	local selected = next(flags.fuseRarities) ~= nil and flags.fuseRarities or { Basic = true }
	local minPets = tonumber(library.Shared.FuseMinPets) or 3
	local maxPets = tonumber(library.Shared.FuseMaxPets) or 12
	local count = math.clamp(flags.fuseCount, minPets, maxPets)
	local equipped = getEquippedSet()
	local groups = {}

	for _, pet in ipairs(save.Pets) do
		local petData = library.Directory.Pets[pet.id]
		local rarity = petData and tostring(petData.rarity)
		local fusable = petData and not petData.isPremium and not petData.isGift and not FUSE_BLOCKED[rarity]

		if fusable and selected[rarity] and getPetKind(pet) == "Normal" and not equipped[pet.uid] and not pet.l then
			local key = pet.hc and "hardcore" or "normal"
			groups[key] = groups[key] or {}
			table.insert(groups[key], pet.uid)
		end
	end

	if next(groups) == nil then
		status.fuse = "No unequipped, unlocked pets match the fuse rarities"
		return
	end

	for key, uids in pairs(groups) do
		if #uids < count then
			status.fuse = ("Waiting for pets: %d/%d"):format(#uids, count)
		elseif not isBlacklisted("fuse:" .. key) then
			local cost = safeCall(library.RebornBalance.MachineCost, library.Shared.FusePetsCost, library.Shared.FuseHardcoreCost, key == "hardcore")

			if cost and getCurrency(save, "Diamonds") < cost then
				status.fuse = ("Need %d Diamonds to fuse"):format(cost)
			else
				local success, message = invoke("Fuse Pets", takeUids(uids, count))
				status.fuse = success and ("Fused %d pets"):format(count) or ("Fuse failed: %s"):format(tostring(message))

				if not success then
					blacklistKey("fuse:" .. key)
				end
			end
		end
	end
end

---Auto equip best pets step.
local function equipStep()
	if flags.autoEquipBest then
		invoke("Equip Best Pets")
	end
end

---Keep the server auto delete setting in sync with the selected rarities.
local function autoDeleteStep()
	local save = getSave()
	if not save or type(save.AutoDelete) ~= "table" then
		return
	end

	local selected = flags.autoDelete and flags.deleteRarities or {}

	for rarity in pairs(selected) do
		managedRarities[rarity] = true
	end

	for rarity in pairs(managedRarities) do
		local wanted = selected[rarity] == true
		local current = save.AutoDelete[rarity] == true

		if wanted ~= current then
			invoke("Toggle Auto Delete", rarity)
		end

		if not wanted then
			managedRarities[rarity] = nil
		end
	end
end

---Auto dark matter step.
local function darkMatterStep()
	if flags.autoDarkClaim then
		invoke("Redeem All Dark Matter Pets")
	end

	if not flags.autoDarkConvert or not flags.darkMatterPet or flags.darkMatterPet == "" then
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
				local success, message = invoke("Convert To Dark Matter", takeUids(group.uids, #rows))
				status.machine = success and "Convert To Dark Matter ok" or ("Convert To Dark Matter: " .. tostring(message))

				if not success then
					blacklistKey(key)
				end
			end
		end
	end
end

---Show the dark matter queue.
local function showDarkMatterQueue()
	local save = getSave()
	local serverTime = invoke("Get OSTime") or os.time()
	local lines = {}

	for _, entry in pairs(save and save.DarkMatterQueue or {}) do
		local petData = library.Directory.Pets[entry.petId]
		local remaining = entry.readyTime - serverTime
		table.insert(lines, ("%s: %s"):format(petData and petData.name or "?", remaining > 1 and formatTime(remaining) or "Ready"))
	end

	notify("Dark Matter", #lines > 0 and table.concat(lines, "\n") or "Queue is empty.")
end

---Auto unlock next area and teleports step.
local function areaStep()
	local save = getSave()
	if not save then
		return
	end

	if flags.autoUnlockArea then
		local areaName, gate = getNextArea()
		if areaName and gate and getCurrency(save, gate.currency) >= gate.cost and not isBlacklisted("area:" .. areaName) then
			local success, message = invoke("Buy Area", areaName)
			status.progress = success and ("Unlocked %s"):format(areaName) or ("Buy Area %s: %s"):format(areaName, tostring(message))

			if not success then
				blacklistKey("area:" .. areaName)
			end
		end
	end

	if flags.autoBuyTeleports then
		for _, area in ipairs(getWorldAreas()) do
			local price = tonumber(area.data.teleportPrice)
			local owned = safeCall(library.WorldCmds.HasTeleport, area.name) == true

			if price and hasArea(area.name) and not owned and getCurrency(save, "Diamonds") >= price and not isBlacklisted("teleport:" .. area.name) then
				local success = invoke("Buy Teleport Area", area.name)
				if not success then
					blacklistKey("teleport:" .. area.name)
				end
			end
		end
	end
end

---Auto upgrade step.
local function upgradeStep()
	if not flags.autoUpgrades then
		return
	end

	local save = getSave()
	if not save then
		return
	end

	for upgradeId in pairs(flags.selectedUpgrades) do
		local data = library.Directory.Upgrades[upgradeId]
		local level = save.Upgrades and tonumber(save.Upgrades[upgradeId]) or 0
		local price = data and data.prices and data.prices[level + 1]

		if price and getCurrency(save, data.currency) >= price and not isBlacklisted("upgrade:" .. upgradeId) then
			local success = invoke("Buy Upgrade", upgradeId)
			if not success then
				blacklistKey("upgrade:" .. upgradeId)
			end

			return
		end
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
	if not flags.autoUseBoosts then
		return
	end

	local save = getSave()
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

---Auto rewards step.
local function rewardsStep()
	if flags.autoRankReward then
		invoke("Redeem Rank Rewards")
	end

	if flags.autoVipReward then
		invoke("Redeem VIP Rewards")
	end

	if flags.autoFreeGifts then
		local save = getSave()
		for index, gift in ipairs(library.Directory.FreeGifts or {}) do
			local redeemed = false
			for _, done in ipairs(save and save.FreeGiftsRedeemed or {}) do
				redeemed = redeemed or done == index
			end

			if save and not redeemed and save.FreeGiftsTime >= gift.waitTime and not isBlacklisted("gift:" .. index) then
				local success = invoke("Redeem Free Gift", index)
				if not success then
					blacklistKey("gift:" .. index)
				end
			end
		end
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

---Update the labels of the home tab.
local function homeStep()
	local save = getSave()
	local nextArea, gate = getNextArea()
	local coinCount = 0
	for _ in pairs(coinCache) do
		coinCount = coinCount + 1
	end

	local lines = {
		world = ("World: %s | Best area: %s"):format(tostring(getWorldName()), tostring(getBestArea())),
		next = nextArea and ("Next area: %s (%s %s)"):format(nextArea, tostring(gate.cost), tostring(gate.currency)) or "Next area: none",
		farm = ("Farm: %s | Coins: %d"):format(status.farm or "idle", coinCount),
		egg = ("Egg: %s"):format(status.egg or "idle"),
		progress = ("Progress: %s | Pets equipped: %d"):format(status.progress or "idle", #getEquippedPets()),
		pets = ("Fuse: %s | Machine: %s"):format(status.fuse or "idle", status.machine or "idle"),
	}

	for key, text in pairs(lines) do
		if homeLabels[key] then
			pcall(homeLabels[key].Set, homeLabels[key], text)
		end
	end

	return save
end

---Run a check of everything the script depends on and copy the report.
local function runDiagnostics()
	local lines = {}
	local save = getSave()
	local root = getRoot()
	local entries = collectEggEntries()
	local egg = resolveEgg(entries)
	local nearest, inRange, total = math.huge, 0, 0

	for _, coin in pairs(coinCache) do
		total = total + 1
		if root and coin.position then
			local distance = (coin.position - root.Position).Magnitude
			nearest = math.min(nearest, distance)
			inRange = inRange + (distance <= getCoinRange() and 1 or 0)
		end
	end

	table.insert(lines, ("Save: %s | World: %s"):format(save and "ok" or "MISSING", tostring(getWorldName())))
	table.insert(lines, ("Equipped pets: %d"):format(#getEquippedPets()))
	table.insert(lines, ("Coins: %d | in range: %d | nearest: %s"):format(total, inRange, nearest == math.huge and "-" or tostring(math.floor(nearest))))
	local attacking, newestDamage = 0, 0
	for _, coin in pairs(coinCache) do
		if isActive(coin) then
			attacking = attacking + 1
		end

		newestDamage = math.max(newestDamage, coin.lastDamage)
	end

	table.insert(lines, ("Attacking coins: %d | last damage: %s"):format(attacking, newestDamage > 0 and ("%.1fs ago"):format(os.clock() - newestDamage) or "never"))
	table.insert(lines, ("Best area: %s | Next area: %s"):format(tostring(getBestArea()), tostring((getNextArea()))))
	table.insert(lines, ("Eggs: %d | selected: %s"):format(#entries, egg and egg.name or "none"))
	table.insert(lines, ("getsenv: %s | getgc: %s | setfpscap: %s"):format(tostring(getsenv ~= nil), tostring(getgc ~= nil), tostring(setfpscap ~= nil)))

	for key, text in pairs(status) do
		table.insert(lines, key .. ": " .. tostring(text))
	end

	local report = table.concat(lines, "\n")
	print(report)

	if setclipboard then
		pcall(setclipboard, report)
	end

	notify("Self-Test (copied to clipboard)", report)
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
				status.error = ("%s: %s"):format(name, tostring(result))
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
		pcall(connection.Disconnect, connection)
	end
	table.clear(PsxHub.connections)

	pcall(restorePetsControl)
	pcall(setSkipAnimation, false)
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

---Create a multiple option dropdown.
---@param tab table
---@param name string
---@param flagName string
---@param options string[]
---@param onChange function
---@return table
local function addMultiDropdown(tab, name, flagName, options, onChange)
	return tab:CreateDropdown({
		Name = name,
		Options = options,
		CurrentOption = {},
		MultipleOptions = true,
		Flag = flagName,
		Callback = function(selected)
			onChange(toSet(selected))
		end,
	})
end

---Build the area dropdown options for the current world.
---@return string[]
local function buildAreaOptions()
	local options = { BEST_AREA }
	table.clear(areaLookup)

	for _, area in ipairs(getWorldAreas()) do
		if hasArea(area.name) then
			local display = tostring(area.data.name or area.name)
			areaLookup[display] = area.name
			table.insert(options, display)
		end
	end

	return options
end

---Build the egg dropdown options for the current world.
---@return string[]
local function buildEggOptions()
	local options = { EGG_PRESETS[1], EGG_PRESETS[2], EGG_PRESETS[3] }
	local entries = collectEggEntries()
	local seen = {}

	table.sort(entries, function(a, b)
		return a.cost < b.cost
	end)

	for _, entry in ipairs(entries) do
		if not seen[entry.name] then
			seen[entry.name] = true
			table.insert(options, entry.name)
		end
	end

	return options
end

---Build the giant chest options from the coins around.
---@return string[]
local function buildChestOptions()
	local options, seen = {}, {}

	local function add(name)
		if not seen[name] then
			seen[name] = true
			table.insert(options, name)
		end
	end

	for _, name in ipairs(DEFAULT_CHESTS) do
		add(name)
	end

	for _, coin in pairs(coinCache) do
		if isGiantCoin(coin) then
			add(coin.name)
		end
	end

	table.sort(options)
	return options
end

---Build the upgrade options.
---@return string[]
local function buildUpgradeOptions()
	local options = {}
	table.clear(upgradeLookup)

	for upgradeId, data in pairs(library.Directory.Upgrades) do
		if type(data) == "table" and not (data.isHalloweenEvent or data.isLuckyBlockEvent or data.isYeetEvent) then
			local display = tostring(data.title or upgradeId)
			upgradeLookup[display] = upgradeId
			table.insert(options, display)
		end
	end

	table.sort(options)
	return options
end

---Build the pet rarity options from the pet directory.
---@return string[]
local function buildRarityOptions()
	local options, seen = {}, {}

	for _, data in pairs(library.Directory.Pets) do
		local rarity = type(data) == "table" and data.rarity
		if rarity and not seen[rarity] then
			seen[rarity] = true
			table.insert(options, tostring(rarity))
		end
	end

	table.sort(options)
	return options
end

---Collect the boost names the player can activate.
---@return string[]
local function buildBoostOptions()
	local options, seen = {}, {}

	local function add(name)
		if not seen[name] then
			seen[name] = true
			table.insert(options, name)
		end
	end

	for _, name in ipairs(DEFAULT_BOOSTS) do
		add(name)
	end

	local save = getSave()
	for name in pairs(save and save.BoostsInventory or {}) do
		add(tostring(name))
	end

	table.sort(options)
	return options
end

---Convert selected display names to ids.
---@param lookup table
---@param selected table
---@return table
local function mapSelection(lookup, selected)
	local ids = {}
	for display in pairs(selected) do
		ids[lookup[display] or display] = true
	end

	return ids
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

	-- Home tab.
	local homeTab = window:CreateTab("Home", TAB_ICON)
	homeTab:CreateSection("Status")
	homeLabels.world = homeTab:CreateLabel("World: ...")
	homeLabels.next = homeTab:CreateLabel("Next area: ...")
	homeLabels.farm = homeTab:CreateLabel("Farm: idle")
	homeLabels.egg = homeTab:CreateLabel("Egg: idle")
	homeLabels.progress = homeTab:CreateLabel("Progress: idle")
	homeLabels.pets = homeTab:CreateLabel("Pets: idle")
	homeTab:CreateButton({ Name = "Run Self-Test (copies report)", Callback = runDiagnostics })

	-- Auto Farm tab.
	local farmTab = window:CreateTab("Auto Farm", TAB_ICON)
	farmTab:CreateSection("Coins")
	areaDropdown = addDropdown(farmTab, "Select Area to Farm", "farmAreaOption", buildAreaOptions(), BEST_AREA, function(value)
		flags.farmArea = areaLookup[value] or BEST_AREA
	end)
	addDropdown(farmTab, "Select Farming Mode", "farmModeOption", FARM_MODES, FARM_MODES[2], function(value)
		flags.farmMode = value
	end)
	addDropdown(farmTab, "Select Coin Priority", "coinPriorityOption", COIN_PRIORITIES, COIN_PRIORITIES[1], function(value)
		flags.coinPriority = value
	end)
	addToggle(farmTab, "Ignore Giant Chests", "ignoreGiant", false)
	addToggle(farmTab, "Auto Farm Coins", "autoFarm", false)
	farmTab:CreateSection("Giant Chests")
	chestDropdown = addMultiDropdown(farmTab, "Select Giant Chests", "chestOptions", buildChestOptions(), function(selected)
		flags.selectedChests = selected
	end)
	farmTab:CreateButton({
		Name = "Refresh Areas and Chests",
		Callback = function()
			pcall(areaDropdown.Refresh, areaDropdown, buildAreaOptions())
			pcall(chestDropdown.Refresh, chestDropdown, buildChestOptions())
		end,
	})
	addToggle(farmTab, "Auto Break Selected Giant Chests", "autoChests", false)
	farmTab:CreateSection("Orbs/Lootbags")
	addToggle(farmTab, "Auto Collect Orbs/Lootbags", "autoCollect", false)

	-- Egg tab.
	local eggTab = window:CreateTab("Egg", TAB_ICON)
	eggTab:CreateSection("Eggs")
	eggDropdown = addDropdown(eggTab, "Select Egg to Buy", "eggOption", buildEggOptions(), EGG_PRESETS[2], function(value)
		flags.eggChoice = value
	end)
	eggTab:CreateButton({
		Name = "Refresh Eggs",
		Callback = function()
			pcall(eggDropdown.Refresh, eggDropdown, buildEggOptions())
		end,
	})
	addDropdown(eggTab, "Select Eggs per Open", "eggAmountOption", EGG_AMOUNTS, EGG_AMOUNTS[1], function(value)
		flags.eggAmount = value
	end)
	eggTab:CreateLabel("Save Money: only buys eggs until you own the selected amount of pets from that egg, then farms to unlock the next area.")
	addSlider(eggTab, "Select Pets to Keep from the Egg", "keepPets", { 1, 50 }, 1, 4)
	addToggle(eggTab, "Save Money for Area Unlock", "saveMoney", false)
	addToggle(eggTab, "Auto Buy Selected Egg", "autoHatch", false)
	addToggle(eggTab, "Skip Egg Opening Animation", "skipAnimation", false, setSkipAnimation)
	eggTab:CreateSection("Auto Delete")
	addMultiDropdown(eggTab, "Select Rarities to Delete", "deleteOptions", buildRarityOptions(), function(selected)
		flags.deleteRarities = selected
	end)
	addToggle(eggTab, "Auto Delete Selected Rarities", "autoDelete", false)

	-- Pet tab.
	local petTab = window:CreateTab("Pet", TAB_ICON)
	petTab:CreateSection("Pets")
	addToggle(petTab, "Auto Equip Best Pets", "autoEquipBest", false)
	petTab:CreateSection("Golden and Rainbow Machines (cost Diamonds, max pets)")
	addToggle(petTab, "Auto Make Golden Pets", "autoGolden", false)
	addToggle(petTab, "Auto Make Rainbow Pets", "autoRainbow", false)
	petTab:CreateSection("Dark Matter")
	petTab:CreateInput({
		Name = "Pet Name",
		PlaceholderText = "Exact rainbow pet name",
		RemoveTextAfterFocusLost = false,
		Callback = function(text)
			flags.darkMatterPet = text
		end,
	})
	addToggle(petTab, "Auto Convert to Dark Matter", "autoDarkConvert", false)
	addToggle(petTab, "Auto Claim Dark Matter", "autoDarkClaim", false)
	petTab:CreateButton({ Name = "Show Dark Matter Queue", Callback = showDarkMatterQueue })
	petTab:CreateSection("Fuse Pets (unequipped, unlocked, normal pets)")
	addMultiDropdown(petTab, "Select Rarities to Fuse (empty = Basic)", "fuseOptions", FUSABLE_RARITIES, function(selected)
		flags.fuseRarities = selected
	end)
	addSlider(petTab, "Select Pets per Fuse", "fuseCount", { 3, 12 }, 1, 12)
	addToggle(petTab, "Auto Fuse Pets", "autoFuse", false)

	-- Progression tab.
	local progressTab = window:CreateTab("Progression", TAB_ICON)
	progressTab:CreateSection("Areas")
	addToggle(progressTab, "Auto Unlock Next Area", "autoUnlockArea", false)
	addToggle(progressTab, "Auto Buy Area Teleports", "autoBuyTeleports", false)
	progressTab:CreateSection("Upgrades")
	addMultiDropdown(progressTab, "Select Upgrades to Buy", "upgradeOptions", buildUpgradeOptions(), function(selected)
		flags.selectedUpgrades = mapSelection(upgradeLookup, selected)
	end)
	addToggle(progressTab, "Auto Buy Selected Upgrades", "autoUpgrades", false)
	progressTab:CreateSection("Boosts")
	addMultiDropdown(progressTab, "Select Boosts to Use", "boostOptions", buildBoostOptions(), function(selected)
		flags.autoBoosts = selected
	end)
	addToggle(progressTab, "Auto Use Selected Boosts", "autoUseBoosts", false)
	progressTab:CreateSection("Rewards")
	addToggle(progressTab, "Auto Rank Rewards", "autoRankReward", false)
	addToggle(progressTab, "Auto VIP Rewards", "autoVipReward", false)
	addToggle(progressTab, "Auto Free Gifts", "autoFreeGifts", false)
	addToggle(progressTab, "Auto Buy Merchant Items (spends Diamonds)", "autoMerchant", false)

	-- Main tab.
	local mainTab = window:CreateTab("Main", TAB_ICON)
	mainTab:CreateSection("Utility")
	addToggle(mainTab, "Anti AFK", "antiAfk", true)
	addToggle(mainTab, "Disable 3D Rendering", "noRendering", false, function(value)
		runService:Set3dRenderingEnabled(not value)
	end)
	mainTab:CreateSlider({
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
	mainTab:CreateButton({ Name = "Anti Lag", Callback = applyAntiLag })
	mainTab:CreateButton({
		Name = "Rejoin",
		Callback = function()
			teleportService:Teleport(game.PlaceId, localPlayer)
		end,
	})
	mainTab:CreateButton({
		Name = "Copy Discord",
		Callback = function()
			if setclipboard then
				setclipboard(DISCORD_URL)
			end

			notify("Discord", DISCORD_URL)
		end,
	})
	mainTab:CreateButton({ Name = "Destroy UI", Callback = PsxHub.detach })
end

---Initialize the script.
local function initializeScript()
	library = resolveLibrary()
	network = library.Network

	resyncCoins()
	connectEvent("Add Coin", function(coinId, data)
		if type(data) == "table" then
			coinCache[tostring(coinId)] = normalizeCoin(coinId, data)
		end
	end)
	connectEvent("Remove Coin", function(coinId)
		coinCache[tostring(coinId)] = nil
		selections[tostring(coinId)] = nil
	end)
	connectEvent("Update Coin Health", function(coinId, health)
		local coin = coinCache[tostring(coinId)]
		if coin then
			coin.health = tonumber(health) or coin.health
			coin.lastDamage = os.clock()
		end
	end)

	-- The game fires this when the server accepted the pets for a coin.
	local selectedSignal = safeCall(library.Signal.Fired, "Coin Selected")
	local selectedConnection = selectedSignal and safeCall(selectedSignal.Connect, selectedSignal, function(coinId)
		lastAck[tostring(coinId)] = os.clock()
	end)
	if selectedConnection then
		table.insert(PsxHub.connections, selectedConnection)
	end

	-- The coins of the previous world are gone, so load the new ones.
	local worldSignal = safeCall(library.Signal.Fired, "World Changed")
	local worldConnection = worldSignal and safeCall(worldSignal.Connect, worldSignal, function()
		table.clear(selections)
		task.delay(1.5, resyncCoins)
	end)
	if worldConnection then
		table.insert(PsxHub.connections, worldConnection)
	end

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

	startLoop("Main", function()
		return hatchMode and 0.2 or flags.farmDelay
	end, mainStep)
	startLoop("Collect", 0.3, collectStep)
	startLoop("Machines", 2, machineStep)
	startLoop("Fuse", 3, fuseStep)
	startLoop("AutoDelete", 3, autoDeleteStep)
	startLoop("DarkMatter", 15, darkMatterStep)
	startLoop("Equip", 30, equipStep)
	startLoop("Areas", 2, areaStep)
	startLoop("Upgrades", 2, upgradeStep)
	startLoop("Boosts", 5, boostStep)
	startLoop("Rewards", 10, rewardsStep)
	startLoop("Merchant", 2, merchantStep)
	startLoop("Home", 1, homeStep)

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
