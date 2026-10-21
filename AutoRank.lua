-- AutoRank Rewrite (Pet Simulator 99) — clean / no vNN obfuscation artifacts
-- Public API on getgenv().AutoRank

-- Constants.
local HATCH_RARE_PET_EGGS = { [3] = "215 - Egg Capsule", [4] = "264 - Egg Capsule" }
local TELEPORT_OFFSETS = { [3] = { Dist = 35, Offset = 30 }, [4] = { Dist = 85, Offset = -30 } }
local DEFAULT_TELEPORT_OFFSET = { Dist = 5, Offset = 1 }
local ENCHANT_BLACKLIST = { "Magnet 3" }
local QUEST_PRIORITY = {
	BEST_RAINBOW_PET = 1, BEST_GOLD_PET = 1, USE_POTION = 1,
	COLLECT_POTION = 1, COLLECT_ENCHANT = 1, HATCH_RARE_PET = 1,
	USE_FLAG = 2, BEST_COMET = 2, BEST_COIN_JAR = 2, BEST_LUCKYBLOCK = 2, BEST_PINATA = 2,
	BEST_EGG = 3, CURRENT_BREAKABLE = 3,
	BEST_SUPERIOR_MINI_CHEST = 4, DIAMOND_BREAKABLE = 4, BEST_MINI_CHEST = 4,
	CURRENCY = 5,
}
local WORLD_CURRENCY = { [1] = "Coins", [2] = "TechCoins", [3] = "VoidCoins", [4] = "FantasyCoins" }

-- Services.
local playersService = game:GetService("Players")
local replicatedStorage = game:GetService("ReplicatedStorage")
local workspaceService = game:GetService("Workspace")
local localPlayer = playersService.LocalPlayer

-- Modules.
local library = replicatedStorage:WaitForChild("Library")
local client = library.Client
local saveModule = require(client.Save)
local networkModule = require(client.Network)
local eggCmds = require(client.EggCmds)
local zoneCmds = require(client.ZoneCmds)
local currencyCmds = require(client.CurrencyCmds)
local rebirthCmds = require(client.RebirthCmds)
local worldsUtil = require(library.Util.WorldsUtil)
local eggsDirectory = require(library.Directory.Eggs)
local zonesDirectory = require(library.Directory.Zones)
local questsTypes = require(library.Types.Quests).Goals
local calcGatePrice = require(library.Balancing.CalcGatePrice)
local calcEggPricePlayer = require(library.Balancing.CalcEggPricePlayer)
local calcPotionsPerTier = require(library.Balancing.CalcPotionsPerTierRequired)
local calcEnchantsPerTier = require(library.Balancing.CalcEnchantsPerTierRequired)

-- State.
local questState = {}
local activeQuests = {}
local zoneGateQuests = {}

-- Helpers.
local function refreshInventory()
	questState = saveModule.Get().Inventory or {}
end

local function getHrp()
	local character = localPlayer.Character
	return character and character:FindFirstChild("HumanoidRootPart")
end

local function teleportToArea(area)
	if not area then
		return
	end
	local hrp = getHrp()
	if not hrp then
		return
	end

	local interact = area:FindFirstChild("INTERACT")
	local target = interact and interact:FindFirstChild("BREAKABLE_SPAWNS")
	target = target and target:FindFirstChild("Main")

	if target and (hrp.Position - target.Position).Magnitude <= 30 then
		return
	end

	local persistent = area:FindFirstChild("PERSISTENT")
	local teleportPart = persistent and persistent:FindFirstChild("Teleport")
	if teleportPart then
		hrp.CFrame = teleportPart.CFrame
		repeat
			task.wait()
		until localPlayer.Character and localPlayer.Character.Humanoid.FloorMaterial ~= Enum.Material.Air
	end

	if target then
		hrp.CFrame = target.CFrame
	end
end

local function getBestEggNumber()
	return zoneCmds.GetMaximumOverallZone().MaximumAvailableEgg
end

local function getWorldNumber()
	return worldsUtil.GetWorld().WorldNumber
end

local function getCoins()
	return currencyCmds.Get(WORLD_CURRENCY[getWorldNumber()] or "Coins")
end

local function getBestEggModule()
	for _, eggModule in pairs(eggsDirectory) do
		if eggModule.eggNumber == getBestEggNumber() then
			return eggModule
		end
	end
	return nil
end

local function findBestEggInstance()
	local bestNumber = getBestEggNumber()
	local things = workspaceService:FindFirstChild("__THINGS")
	if not things then
		return nil
	end

	local worldName = "World" .. getWorldNumber()
	local folders = {}
	for _, folderName in ipairs({ "ZoneEggs", "Eggs" }) do
		local parent = things:FindFirstChild(folderName)
		local folder = parent and parent:FindFirstChild(worldName)
		if folder then
			table.insert(folders, folder)
		end
	end

	for _, folder in ipairs(folders) do
		for _, instance in ipairs(folder:GetChildren()) do
			if tonumber(instance.Name:split(" ")[1]) == bestNumber then
				return instance
			end
		end
	end

	return nil
end

local function getBestPetsLookup()
	local bestEgg = nil
	local bestNumber = getBestEggNumber()

	for _, eggModule in pairs(eggsDirectory) do
		if eggModule.eggNumber == bestNumber then
			bestEgg = eggModule
		end
	end

	local lookup = {}
	if not bestEgg then
		return lookup
	end

	for _, petEntry in pairs(bestEgg.pets) do
		local petName = petEntry[1]
		if petName and not petName:match("Huge") and not petName:match("Titanic") and not petName:match("Gargantuan") then
			lookup[petName] = true
		end
	end

	return lookup
end

local function getPetsByRarity(rarity)
	local lookup = getBestPetsLookup()
	local result = {}

	for uid, pet in pairs(questState.Pet or {}) do
		if lookup[pet.id] and (pet.pt or 0) == rarity and not pet.sh then
			result[uid] = { PetName = pet.id, UID = uid, Amount = pet._am or 1 }
		end
	end

	return result
end

local function getMaximumZoneInfo()
	local zone = zoneCmds.GetMaximumZone()
	return { ID = zone._id, Number = zone.ZoneNumber, Folder = zone.ZoneFolder, World = zone.WorldNumber }
end

local function getBestZoneNumber()
	return zoneCmds.GetMaximumZone().ZoneNumber
end

local function getNextZone()
	local targetNumber = getBestZoneNumber() + 1
	for _, zone in pairs(zonesDirectory) do
		if zone.ZoneNumber == targetNumber then
			return zone
		end
	end
	return nil
end

local function getCurrentZoneQuests()
	return saveModule.Get().ZoneGateQuest
end

local function useMiscItem(itemId, remoteAction)
	for uid, item in pairs(questState.Misc or {}) do
		if item.id == itemId then
			networkModule.Invoke(remoteAction, tostring(uid))
			return
		end
	end
end

local function usePotion(tier, amount)
	for uid, potion in pairs(questState.Potion or {}) do
		if tier <= potion.tn and amount <= (potion._am or 1) then
			networkModule.Fire("Potions: Consume", tostring(uid), amount)
			return
		end
	end
end

local function isCombinablePotion(potion)
	return potion.tn > 1 and potion.tn <= 4 and potion.id ~= "Walkspeed" and potion.tn ~= 3
end

local function isCombinableEnchant(enchant)
	if not (enchant.tn > 1 and enchant.tn <= 4) then
		return false
	end
	return not table.find(ENCHANT_BLACKLIST, enchant.id .. " " .. enchant.tn)
end

local function combinePotions(multiplier)
	if multiplier <= 0 then
		return
	end

	for uid, potion in pairs(questState.Potion or {}) do
		if isCombinablePotion(potion) then
			setthreadidentity(4)
			local required = calcPotionsPerTier(potion.tn) * multiplier
			if required < (potion._am or 1) then
				print("Combining potion:", potion.id, potion.tn, required)
				networkModule.Invoke("UpgradePotionsMachine_Activate", uid, multiplier)
			else
				break
			end
		end
	end
end

local function combineEnchants(multiplier)
	if multiplier <= 0 then
		return
	end

	for uid, enchant in pairs(questState.Enchant or {}) do
		if isCombinableEnchant(enchant) then
			setthreadidentity(4)
			local required = calcEnchantsPerTier(enchant.tn) * multiplier
			if required < (enchant._am or 1) then
				print("Combining enchant:", enchant.id, enchant.tn, required)
				networkModule.Invoke("UpgradeEnchantsMachine_Activate", uid, multiplier)
			else
				break
			end
		end
	end
end

local function findClosestCustomEgg()
	local hrp = getHrp()
	if not hrp then
		return nil, nil
	end

	local customEggs = workspaceService.__THINGS.CustomEggs
	local bestEgg, bestDist = nil, math.huge
	for _, egg in ipairs(customEggs:GetChildren()) do
		if egg:IsA("Model") then
			local dist = (hrp.Position - egg.WorldPivot.Position).Magnitude
			if dist < bestDist then
				bestEgg, bestDist = egg, dist
			end
		end
	end

	return bestEgg, bestDist
end

local function findClosestEgg()
	local hrp = getHrp()
	if not hrp then
		return nil, nil, nil
	end

	local things = workspaceService.__THINGS
	local worldNumber = getWorldNumber()
	local bestEgg, bestDist = nil, math.huge

	for _, folderName in ipairs({ "ZoneEggs", "Eggs" }) do
		local parent = things:FindFirstChild(folderName)
		for _, worldFolder in ipairs(parent and parent:GetChildren() or {}) do
			if worldFolder.Name:find("World") then
				for _, egg in ipairs(worldFolder:GetChildren()) do
					local light = egg:FindFirstChild("Light")
					if light and egg.Name:sub(1, 1) == tostring(worldNumber) then
						local dist = (hrp.Position - light.CFrame.Position).Magnitude
						if dist < bestDist then
							bestEgg, bestDist = egg, dist
						end
					end
				end
			end
		end
	end

	if not bestEgg then
		return nil, nil, nil
	end

	local parts = bestEgg.Name:split(" ")
	local nameParts = {}
	for index = 3, math.min(#parts, 6) do
		table.insert(nameParts, parts[index])
	end

	return table.concat(nameParts, " "), bestDist, bestEgg
end

local function hatchBestEgg()
	local maxHatch = eggCmds.GetMaxHatch()
	local customEgg, customDist = findClosestCustomEgg()
	local eggName, eggDist = findClosestEgg()

	if not customEgg or not eggName then
		return
	end

	if customDist < eggDist then
		networkModule.Invoke("CustomEggs_Hatch", tostring(customEgg), maxHatch)
	else
		networkModule.Invoke("Eggs_RequestPurchase", eggName, maxHatch)
	end
end

local function hasPetAmount(pets, neededAmount)
	for uid, pet in pairs(pets) do
		if pet.Amount >= (neededAmount + 1) * 10 then
			return true, uid, pet.Amount
		end
	end
	return false, nil, 0
end

local function hasMiscAmount(itemId, neededAmount)
	for uid, item in pairs(questState.Misc or {}) do
		if item.id == itemId then
			local amount = item._am or 1
			return neededAmount <= amount, uid, amount
		end
	end
	return false, nil, 0
end

local function hasPotionAmount(tier, neededAmount)
	for uid, potion in pairs(questState.Potion or {}) do
		if tier <= potion.tn then
			local amount = potion._am or 1
			if neededAmount <= amount then
				return true, uid, amount
			end
		end
	end
	return false, nil, 0
end

local function hasPotionUpgrade(neededAmount)
	for uid, potion in pairs(questState.Potion or {}) do
		if isCombinablePotion(potion) then
			setthreadidentity(4)
			local required = calcPotionsPerTier(potion.tn) * neededAmount
			local amount = potion._am or 1
			if required <= amount then
				return true, uid, amount
			end
		end
	end
	return false, nil, 0
end

local function hasEnchantUpgrade(neededAmount)
	for uid, enchant in pairs(questState.Enchant or {}) do
		if isCombinableEnchant(enchant) then
			setthreadidentity(4)
			local required = calcEnchantsPerTier(enchant.tn) * neededAmount
			local amount = enchant._am or 1
			if required <= amount then
				return true, uid, amount
			end
		end
	end
	return false, nil, 0
end

local function getQuestByID(questId)
	for questName, goalId in pairs(questsTypes) do
		if questId == goalId then
			return questName
		end
	end
	return nil
end

local function getIDByQuest(questName)
	return questsTypes[questName]
end

local function getQuestPriority(questName)
	return QUEST_PRIORITY[questName] or 4
end

local function getActiveQuests()
	table.clear(activeQuests)

	for _, goal in pairs(saveModule.Get().Goals) do
		local questName = getQuestByID(goal.Type)
		table.insert(activeQuests, {
			questname = questName,
			priority = getQuestPriority(questName),
			amount = goal.Amount,
			neededamount = goal.Amount - goal.Progress,
			queststars = goal.Stars,
			id = goal.Type,
			potiontier = goal.PotionTier,
		})
	end

	return activeQuests
end

local function getZoneGateQuests()
	table.clear(zoneGateQuests)

	local zoneQuest = getCurrentZoneQuests()
	if not zoneQuest then
		return zoneGateQuests
	end

	local questName = getQuestByID(zoneQuest.Type)
	table.insert(zoneGateQuests, {
		questname = questName,
		priority = getQuestPriority(questName),
		amount = zoneQuest.Amount,
		neededamount = zoneQuest.Amount - zoneQuest.Progress,
		id = zoneQuest.Type,
		potiontier = zoneQuest.PotionTier,
	})

	return zoneGateQuests
end

local function sortQuestsByPriority(list)
	table.sort(list, function(a, b)
		return a.priority < b.priority
	end)
	return list
end

local function highlightQuest(questStars)
	local playerGui = localPlayer:FindFirstChildOfClass("PlayerGui")
	local goalsSide = playerGui and playerGui:FindFirstChild("GoalsSide")
	local frame = goalsSide and goalsSide:FindFirstChild("Frame")
	local quests = frame and frame:FindFirstChild("Quests")
	local gradient = quests and quests:FindFirstChild("QuestsGradient")
	local holder = gradient and gradient:FindFirstChild("QuestsHolder")
	if not holder then
		return
	end

	for _, questFrame in ipairs(holder:GetChildren()) do
		if questFrame:IsA("Frame") and questFrame:FindFirstChild("Title") then
			if questFrame.Name == tostring(questStars) then
				questFrame.Title.TextColor3 = Color3.fromRGB(0, 170, 255)
			else
				questFrame.Title.TextColor3 = Color3.fromRGB(255, 255, 255)
			end
		end
	end
end

-- Quest handlers (make).
local makeQuest = {}

makeQuest.BEST_RAINBOW_PET = function(quest)
	local ok, uid = hasPetAmount(getPetsByRarity(1), quest.neededamount)
	if ok then
		networkModule.Invoke("RainbowMachine_Activate", uid, quest.neededamount + 1)
	else
		teleportToArea(quest.Folder)
	end
end

makeQuest.BEST_GOLD_PET = function(quest)
	local ok, uid = hasPetAmount(getPetsByRarity(0), quest.neededamount)
	if ok then
		networkModule.Invoke("GoldMachine_Activate", uid, quest.neededamount + 1)
	else
		teleportToArea(quest.Folder)
	end
end

makeQuest.COLLECT_POTION = function(quest)
	combinePotions(quest.neededamount)
end

makeQuest.COLLECT_ENCHANT = function(quest)
	combineEnchants(quest.neededamount)
end

local function useMiscQuest(itemId, remoteAction)
	return function(quest)
		teleportToArea(quest.Folder)
		useMiscItem(itemId, remoteAction)
	end
end

makeQuest.BEST_COMET = useMiscQuest("Comet", "Comet_Spawn")
makeQuest.BEST_COIN_JAR = useMiscQuest("Basic Coin Jar", "CoinJar_Spawn")
makeQuest.BEST_LUCKYBLOCK = useMiscQuest("Mini Lucky Block", "MiniLuckyBlock_Consume")
makeQuest.BEST_PINATA = useMiscQuest("Mini Pinata", "MiniPinata_Consume")

makeQuest.USE_POTION = function(quest)
	usePotion(quest.potiontier, quest.neededamount)
end

makeQuest.CURRENT_BREAKABLE = function(quest)
	teleportToArea(quest.Folder)
end
makeQuest.BREAKABLE = makeQuest.CURRENT_BREAKABLE

makeQuest.HATCH_RARE_PET = function(quest)
	local worldNumber = getWorldNumber()
	local eggName = HATCH_RARE_PET_EGGS[worldNumber]
	local hrp = getHrp()
	if eggName and hrp then
		hrp.CFrame = workspaceService.__THINGS.Eggs["World" .. worldNumber][eggName].Tier.CFrame
		hatchBestEgg()
	end
end

makeQuest.BEST_EGG = function(quest)
	local bestEggModule = getBestEggModule()
	local eggInstance = findBestEggInstance()
	local zoneInfo = getMaximumZoneInfo()
	local coins = getCoins()

	if not bestEggModule or not eggInstance then
		return
	end

	setthreadidentity(4)
	local price = calcEggPricePlayer(bestEggModule)
	local neededAmount = quest.neededamount or 1

	if coins < price * neededAmount then
		teleportToArea(zoneInfo.Folder)
		return
	end

	local priceHud = eggInstance:FindFirstChild("PriceHUD")
	local hrp = getHrp()
	if not priceHud or not hrp then
		return
	end

	local offset = TELEPORT_OFFSETS[zoneInfo.World] or DEFAULT_TELEPORT_OFFSET
	if (hrp.Position - priceHud.Position).Magnitude >= offset.Dist then
		hrp.CFrame = priceHud.CFrame * CFrame.new(0, 0, offset.Offset)
	end

	hatchBestEgg()
end

local function makeQuestFor(questName, questData)
	local handler = makeQuest[questName]
	if not handler then
		teleportToArea(getMaximumZoneInfo().Folder)
		return
	end

	questData.Folder = getMaximumZoneInfo().Folder
	handler(questData)
end

-- Quest handlers (availability check).
local requiresResources = {}

requiresResources.BEST_COMET = function(quest)
	return hasMiscAmount("Comet", quest.neededamount)
end
requiresResources.BEST_COIN_JAR = function(quest)
	return hasMiscAmount("Basic Coin Jar", quest.neededamount)
end
requiresResources.BEST_LUCKYBLOCK = function(quest)
	return hasMiscAmount("Mini Lucky Block", quest.neededamount)
end
requiresResources.BEST_PINATA = function(quest)
	return hasMiscAmount("Mini Pinata", quest.neededamount)
end
requiresResources.USE_POTION = function(quest)
	return hasPotionAmount(quest.potiontier, quest.neededamount)
end
requiresResources.COLLECT_POTION = function(quest)
	return hasPotionUpgrade(quest.neededamount)
end
requiresResources.COLLECT_ENCHANT = function(quest)
	return hasEnchantUpgrade(quest.neededamount)
end
requiresResources.BEST_GOLD_PET = function(quest)
	return hasPetAmount(getPetsByRarity(0), quest.neededamount)
end
requiresResources.BEST_RAINBOW_PET = function(quest)
	return hasPetAmount(getPetsByRarity(1), quest.neededamount)
end

-- Main entry.
local function runQuest(quest)
	local check = requiresResources[quest.questname]
	if check and not check(quest) then
		print("Not enough resources for:", quest.questname)
		return
	end

	highlightQuest(quest.queststars)
	makeQuestFor(quest.questname, {
		amount = quest.amount,
		potiontier = quest.potiontier,
		neededamount = quest.neededamount,
	})
end

local function handleZoneProgression()
	local zoneInfo = getMaximumZoneInfo()
	local nextZone = getNextZone()
	local nextRebirth = rebirthCmds.GetNextRebirth()
	local gatePrice = nextZone and calcGatePrice(nextZone) or nil
	local coins = getCoins()

	if not nextZone then
		if nextRebirth and zoneInfo.Number >= nextRebirth.ZoneNumberRequired then
			rebirthCmds.Rebirth(tostring(nextRebirth.RebirthNumber))
		else
			teleportToArea(zoneInfo.Folder)
		end
		return
	end

	if zoneInfo.World ~= nextZone.WorldNumber then
		networkModule.Invoke("World" .. nextZone.WorldNumber .. "Teleport")
		teleportToArea(nextZone.ZoneFolder)
		return
	end

	if nextRebirth and zoneInfo.Number >= nextRebirth.ZoneNumberRequired then
		rebirthCmds.Rebirth(tostring(nextRebirth.RebirthNumber))
	elseif gatePrice and gatePrice <= coins then
		networkModule.Invoke("Zones_RequestPurchase", nextZone._id)
	else
		teleportToArea(zoneInfo.Folder)
	end
end

local function initQuest()
	refreshInventory()

	if getMaximumZoneInfo().Number == zoneCmds.GetMaximumOverallZone().ZoneNumber then
		for _, quest in ipairs(sortQuestsByPriority(getActiveQuests())) do
			runQuest(quest)
		end
		return
	end

	if getCurrentZoneQuests() then
		print("MAKING ZONEGATEQUEST")
		handleZoneProgression()
		for _, quest in ipairs(sortQuestsByPriority(getZoneGateQuests())) do
			runQuest(quest)
		end
		return
	end

	print("Farm Areas")
	handleZoneProgression()
end

getgenv().AutoRank = {
	init = initQuest,
	getActiveQuests = getActiveQuests,
	getZoneGateQuests = getZoneGateQuests,
	getBestEggNumber = getBestEggNumber,
	getCoins = getCoins,
}

return initQuest
