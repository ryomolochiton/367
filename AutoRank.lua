--// AutoRank (Pet Simulator 99) - BAN CHUAN (khoi phuc + doi chieu)
--//
--// Logic lay tu: null62156.txt + AutoRank_clean.lua (decompile bytecode that).
--// rank.txt chi dung de DOI CHIEU ten/hang so, KHONG lay logic (no goi API sai cu phap:
--// Save:Get / Network:Invoke / Util:... trong khi 2 ban decompile dung Save.Get / Network.Invoke).
--//
--// rank.txt xac nhan: "215 - Egg Capsule", "264 - Egg Capsule", potion "Walkspeed",
--// mau (0,170,255), GUI GoalsSide...QuestsHolder, cac item (Basic Coin Jar, Mini Pinata,
--// Mini Lucky Block) va cac remote: CustomEggs_Hatch, Eggs_RequestPurchase, Potions: Consume,
--// UpgradePotionsMachine_Activate, UpgradeEnchantsMachine_Activate, RainbowMachine_Activate,
--// GoldMachine_Activate, Comet_Spawn, CoinJar_Spawn, MiniLuckyBlock_Consume,
--// MiniPinata_Consume, Zones_RequestPurchase.
--// rank.txt KHONG co: "Magnet 3", ten tien te cac world, remote World<N>Teleport, bang uu tien,
--// bang [so sao] -> ten Frame (da thay bang co che tu dong, xem phan "To mau tieu de quest").
--//
--// Script tra ve ham InitQuest. Goi lap lai, vi du:
--//     local InitQuest = loadstring(...)()
--//     while task.wait() do InitQuest() end

local DEBUG = true -- dat false de tat cac dong print

local function dprint(...)
    if DEBUG then
        print(...)
    end
end

------------------------------------------------------------------------
-- Services / modules
------------------------------------------------------------------------
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = game:GetService("Players").LocalPlayer
local Workspace = game:GetService("Workspace")

local Library = ReplicatedStorage:WaitForChild("Library")
local Client = Library.Client

local Save = require(Client.Save)
local Network = require(Client.Network)
local EggCmds = require(Client.EggCmds)
local ZoneCmds = require(Client.ZoneCmds)
local CurrencyCmds = require(Client.CurrencyCmds)
local RebirthCmds = require(Client.RebirthCmds)
local WorldsUtil = require(Library.Util.WorldsUtil)
local EggsDirectory = require(Library.Directory.Eggs)
local ZonesDirectory = require(Library.Directory.Zones)
local Goals = require(Library.Types.Quests).Goals

local Balancing = Library.Balancing
local CalcGatePrice = require(Balancing.CalcGatePrice)
local CalcEggPricePlayer = require(Balancing.CalcEggPricePlayer)
local CalcPotionsPerTierRequired = require(Balancing.CalcPotionsPerTierRequired)
local CalcEnchantsPerTierRequired = require(Balancing.CalcEnchantsPerTierRequired)

local function Inventory()
    return Save.Get().Inventory
end

------------------------------------------------------------------------
-- Di chuyen
------------------------------------------------------------------------
local function IsGrounded()
    local character = LocalPlayer.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    return humanoid ~= nil and humanoid.FloorMaterial ~= Enum.Material.Air
end

-- Teleport toi khu vuc (zone folder) neu dang o xa (> 30 stud) diem spawn breakable
local function TeleportToZone(zoneFolder)
    if not zoneFolder then
        return
    end

    local character = LocalPlayer.Character
    local root = character and character:FindFirstChild("HumanoidRootPart")
    if not root then
        return
    end

    local function getMainSpawn()
        local interact = zoneFolder:FindFirstChild("INTERACT")
        local spawns = interact and interact:FindFirstChild("BREAKABLE_SPAWNS")
        return spawns and spawns:FindFirstChild("Main")
    end

    local mainSpawn = getMainSpawn()
    if not mainSpawn or (root.Position - mainSpawn.Position).Magnitude > 30 then
        local persistent = zoneFolder:FindFirstChild("PERSISTENT")
        local teleportPart = persistent and persistent:FindFirstChild("Teleport")
        if not teleportPart then
            return
        end

        root.CFrame = teleportPart.CFrame

        local waitStart = os.clock()
        repeat
            task.wait()
        until not LocalPlayer.Character or IsGrounded() or os.clock() - waitStart > 5

        -- INTERACT chi stream sau khi da toi gan
        mainSpawn = getMainSpawn()
        if mainSpawn then
            root.CFrame = mainSpawn.CFrame
        end
    end
end

------------------------------------------------------------------------
-- World / zone / currency
------------------------------------------------------------------------
function GetBestEggNumber()
    return ZoneCmds.GetMaximumOverallZone().MaximumAvailableEgg
end

local function GetWorldNumber()
    return WorldsUtil.GetWorld().WorldNumber
end

local CURRENCY_BY_WORLD = {
    [1] = "Coins",
    [2] = "TechCoins",
    [3] = "VoidCoins",
    [4] = "FantasyCoins",
}

local function GetCurrency()
    local currencyName = CURRENCY_BY_WORLD[GetWorldNumber()] or "Coins"
    return CurrencyCmds.Get(currencyName)
end

local function GetMaximumZone()
    return ZoneCmds.GetMaximumZone()
end

local function GetMaximumZoneInfo()
    local zone = ZoneCmds.GetMaximumZone()
    return {
        ID = zone._id,
        Number = zone.ZoneNumber,
        Folder = zone.ZoneFolder,
        World = zone.WorldNumber,
    }
end

function GetBestZoneNumber()
    return ZoneCmds.GetMaximumZone().ZoneNumber
end

local function GetNextZone()
    local target = GetBestZoneNumber() + 1
    for _, zone in pairs(ZonesDirectory) do
        if zone.ZoneNumber == target then
            return zone
        end
    end
    return nil
end

function GetCurrentZoneQuests()
    return Save.Get().ZoneGateQuest
end

------------------------------------------------------------------------
-- Trung / pet
------------------------------------------------------------------------
function GetBestEggModule()
    local bestEggNumber = GetBestEggNumber()
    for _, egg in pairs(EggsDirectory) do
        if egg.eggNumber == bestEggNumber then
            return egg
        end
    end
    return nil
end

-- Tim model trung tot nhat trong workspace (ZoneEggs truoc, roi Eggs)
local function GetBestEggInstance()
    local worldName = "World" .. GetWorldNumber()
    local bestEggNumber = GetBestEggNumber()

    for _, parent in ipairs({ Workspace.__THINGS.ZoneEggs, Workspace.__THINGS.Eggs }) do
        local folder = parent:FindFirstChild(worldName)
        if folder then
            for _, egg in pairs(folder:GetChildren()) do
                if tonumber(egg.Name:split(" ")[1]) == bestEggNumber then
                    return egg
                end
            end
        end
    end
    return nil
end

-- Tap hop ten pet co the ra tu trung tot nhat (bo Huge / Titanic / Gargantuan)
function GetBestPetsLookup()
    local maxEggNumber = ZoneCmds.GetMaximumOverallZone().MaximumAvailableEgg

    local bestEgg
    for _, egg in pairs(EggsDirectory) do
        if egg.eggNumber == maxEggNumber then
            bestEgg = egg
        end
    end

    local lookup = {}
    if bestEgg then
        for _, pet in pairs(bestEgg.pets) do
            local name = pet[1]
            if not name:match("Huge") and not name:match("Titanic") and not name:match("Gargantuan") then
                lookup[name] = true
            end
        end
    end
    return lookup
end

-- petType: 0 = thuong (dung cho Gold machine), 1 = gold (dung cho Rainbow machine)
function GetPetsByRarity(petType)
    local lookup = GetBestPetsLookup()
    local result = {}

    for uid, pet in pairs(Inventory().Pet) do
        if lookup[pet.id] and (pet.pt or 0) == petType and not pet.sh then
            result[uid] = {
                PetName = pet.id,
                UID = uid,
                Amount = pet._am or 1,
            }
        end
    end
    return result
end

-- Co du pet de nau khong (can (needed + 1) * 10)
local function HasEnoughPets(pets, needed)
    for uid, pet in pairs(pets) do
        if pet.Amount >= (needed + 1) * 10 then
            return true, uid, pet.Amount, pet.PetName
        end
    end
    return false, nil, 0
end

------------------------------------------------------------------------
-- Vat pham (Misc / Potion / Enchant)
------------------------------------------------------------------------
-- So khop id khong phan biet hoa thuong, dau cach, "_" va "-"
local function NormalizeId(id)
    return (tostring(id):lower():gsub("[%s_%-]", ""))
end

local MISSING_MISC_REPORT_INTERVAL = 20 -- giay: in lai moi 20s de khong bi troi khoi console
local lastMissingMiscReport = {}

-- Khi khong thay item trong Inventory.Misc: in danh sach Misc dang co, va do them cac kho
-- khac (Potion, Enchant, Egg, ...) xem item co nam sai kho khong
local function ReportMissingMisc(itemId)
    local now = os.clock()
    if lastMissingMiscReport[itemId] and now - lastMissingMiscReport[itemId] < MISSING_MISC_REPORT_INTERVAL then
        return
    end
    lastMissingMiscReport[itemId] = now

    local inventory = Inventory()
    local entries = {}
    for _, item in pairs(inventory.Misc or {}) do
        table.insert(entries, tostring(item.id) .. " x" .. tostring(item._am or 1))
        if #entries >= 40 then
            break
        end
    end

    local wanted = NormalizeId(itemId)
    local elsewhere = {}
    for category, items in pairs(inventory) do
        if category ~= "Misc" and category ~= "Pet" and type(items) == "table" then
            for _, item in pairs(items) do
                if type(item) == "table" and item.id ~= nil and #elsewhere < 15 then
                    local id = NormalizeId(item.id)
                    if id:find(wanted, 1, true) or (#id >= 4 and wanted:find(id, 1, true)) then
                        table.insert(elsewhere, tostring(category) .. ":" .. tostring(item.id) .. " x" .. tostring(item._am or 1))
                    end
                end
            end
        end
    end

    dprint(
        "Khong thay '" .. itemId .. "' (>= 1) trong Inventory.Misc. Misc dang co: "
            .. (#entries > 0 and table.concat(entries, ", ") or "(trong)")
            .. (#elsewhere > 0 and (" | Id tuong tu o kho khac: " .. table.concat(elsewhere, ", ")) or "")
    )
end

-- Tim stack theo id: Misc truoc, neu khong co thi tim o cac kho khac (tru Pet) phong khi
-- game da chuyen vi tri item. Tra ve: uid, soLuong, tenKho (nil, 0 neu khong co)
local foundOutsideMisc = {}

local function FindMisc(itemId)
    local wanted = NormalizeId(itemId)
    local inventory = Inventory()

    local function search(items)
        for uid, item in pairs(items) do
            if type(item) == "table" and item.id ~= nil then
                local have = item._am or 1
                if have >= 1 and NormalizeId(item.id) == wanted then
                    return uid, have
                end
            end
        end
    end

    local uid, have = search(inventory.Misc or {})
    if uid then
        return uid, have, "Misc"
    end

    for category, items in pairs(inventory) do
        if category ~= "Misc" and category ~= "Pet" and type(items) == "table" then
            uid, have = search(items)
            if uid then
                if not foundOutsideMisc[itemId] then
                    foundOutsideMisc[itemId] = true
                    dprint("'" .. itemId .. "' khong o Misc, tim thay o kho: " .. tostring(category))
                end
                return uid, have, category
            end
        end
    end

    ReportMissingMisc(itemId)
    return nil, 0
end

-- Dung 1 item Misc (Comet, Coin Jar, Lucky Block, Pinata...). Tra ve true neu da goi server.
function UseMiscItem(itemId, remoteName)
    local uid = FindMisc(itemId)
    if not uid then
        return false
    end

    local success, ok, result = pcall(Network.Invoke, remoteName, tostring(uid))
    dprint(
        "UseMiscItem:", itemId, remoteName, "uid=" .. tostring(uid),
        "-> pcall=" .. tostring(success), "ok=" .. tostring(ok), "result=" .. tostring(result)
    )
    return success
end

function UsePotion(minTier, amount)
    for uid, potion in pairs(Inventory().Potion) do
        if minTier <= potion.tn and amount <= (potion._am or 1) then
            Network.Fire("Potions: Consume", tostring(uid), amount)
            break
        end
    end
end

-- Khong gop cac vat pham nay
local EXCLUDED_POTIONS = { "Walkspeed" } -- theo ten
local EXCLUDED_ENCHANTS = { "Magnet 3" } -- theo "ten tier"

local function IsExcludedPotion(potion)
    return table.find(EXCLUDED_POTIONS, potion.id) ~= nil
end

local function IsExcludedEnchant(enchant)
    return table.find(EXCLUDED_ENCHANTS, tostring(enchant.id) .. " " .. tostring(enchant.tn)) ~= nil
end

-- uid gop loi -> thoi diem het han, de khong bi spam 1 stack khong gop duoc
local upgradeBlacklist = {}
local UPGRADE_BLACKLIST_TIME = 30

-- Quest Collect khong yeu cau tier: tier nao gop duoc cung tinh, uu tien tier THAP truoc.
-- Tra ve: uid, soLanGop, soLuongDangCo, vatPham (hoac nil neu khong gop duoc)
local function FindUpgrade(items, calcPerTier, isExcluded, wanted)
    local candidates = {}
    local now = os.clock()

    for uid, item in pairs(items or {}) do
        local blockedUntil = upgradeBlacklist[uid]
        if type(item) == "table" and not isExcluded(item) and not (blockedUntil and blockedUntil > now) then
            table.insert(candidates, { uid = uid, item = item })
        end
    end

    table.sort(candidates, function(a, b)
        local tierA, tierB = a.item.tn or 1, b.item.tn or 1
        if tierA ~= tierB then
            return tierA < tierB
        end
        return tostring(a.uid) < tostring(b.uid)
    end)

    setthreadidentity(4)
    for _, candidate in ipairs(candidates) do
        local item = candidate.item
        local success, perUpgrade = pcall(calcPerTier, item.tn or 1)
        local have = item._am or 1

        if success and perUpgrade and perUpgrade > 0 then
            local times = math.min(wanted, math.floor(have / perUpgrade))
            if times >= 1 then
                return candidate.uid, times, have, item
            end
        end
    end
    return nil
end

local function FindPotionUpgrade(wanted)
    return FindUpgrade(Inventory().Potion, CalcPotionsPerTierRequired, IsExcludedPotion, wanted)
end

local function FindEnchantUpgrade(wanted)
    return FindUpgrade(Inventory().Enchant, CalcEnchantsPerTierRequired, IsExcludedEnchant, wanted)
end

-- Tra ve true neu da gop. Chi gop 1 stack moi lan goi.
local function RunUpgrade(find, remoteName, wanted)
    if not wanted or wanted < 1 then
        return false
    end

    local uid, times, _, item = find(wanted)
    if not uid then
        return false
    end

    print("Combining:", item.id, item.tn, times)
    local success, ok = pcall(Network.Invoke, remoteName, uid, times)
    if not success or ok == false then
        upgradeBlacklist[uid] = os.clock() + UPGRADE_BLACKLIST_TIME
    end
    return true
end

local function CombinePotions(wanted)
    return RunUpgrade(FindPotionUpgrade, "UpgradePotionsMachine_Activate", wanted)
end

local function CombineEnchants(wanted)
    return RunUpgrade(FindEnchantUpgrade, "UpgradeEnchantsMachine_Activate", wanted)
end

------------------------------------------------------------------------
-- Hatch trung
------------------------------------------------------------------------
function FindClosestCustomEgg()
    local character = LocalPlayer.Character
    local root = character and character:FindFirstChild("HumanoidRootPart")
    if not root then
        return
    end

    local closest, closestDistance = nil, math.huge
    for _, model in pairs(Workspace.__THINGS.CustomEggs:GetChildren()) do
        if model:IsA("Model") then
            local distance = (root.Position - model.WorldPivot.Position).Magnitude
            if distance < closestDistance then
                closest, closestDistance = model, distance
            end
        end
    end
    return closest, closestDistance
end

-- Tra ve: tenTrung, khoangCach, moduleTrung
function FindClosestEgg()
    local character = LocalPlayer.Character
    local root = character and character:FindFirstChild("HumanoidRootPart")
    if not root then
        return
    end

    local modelName = EggCmds.GetEggsModelName()
    local closest, closestDistance = nil, math.huge

    for _, parent in ipairs({ Workspace.__THINGS.ZoneEggs, Workspace.__THINGS.Eggs }) do
        local folder = parent:FindFirstChild(modelName)
        if folder then
            for _, model in pairs(folder:GetChildren()) do
                if model:IsA("Model") then
                    local light = model:FindFirstChild("Light")
                    if light then
                        local distance = (root.Position - light.CFrame.Position).Magnitude
                        if distance < closestDistance then
                            closest, closestDistance = model, distance
                        end
                    end
                end
            end
        end
    end

    if not closest then
        return
    end

    -- Tim ten that cua trung trong thu muc Directory (dang "123 | Ten Trung")
    local eggNumber = closest.Name:split(" ")[1]
    local zoneEggsDirectory = ReplicatedStorage.__DIRECTORY.Eggs["Zone Eggs"]
    local worldDirectory = zoneEggsDirectory:FindFirstChild(WorldsUtil.GetWorld()._id)
    if not worldDirectory then
        return
    end

    for _, descendant in pairs(worldDirectory:GetDescendants()) do
        local parts = descendant.Name:split(" ")
        if parts[1] == eggNumber and parts[3] then
            local eggName = table.concat(parts, " ", 3, math.min(#parts, 6))
            return eggName, closestDistance, descendant
        end
    end
    return
end

local function HatchClosestEgg()
    local maxHatch = EggCmds.GetMaxHatch()

    local customEgg, customDistance = FindClosestCustomEgg()
    local eggName, eggDistance = FindClosestEgg()

    customDistance = customEgg and customDistance or math.huge
    eggDistance = eggName and eggDistance or math.huge

    if customDistance == math.huge and eggDistance == math.huge then
        return
    end

    if customDistance < eggDistance then
        Network.Invoke("CustomEggs_Hatch", customEgg.Name, maxHatch)
    else
        Network.Invoke("Eggs_RequestPurchase", eggName, maxHatch)
    end
end

------------------------------------------------------------------------
-- Quest: du lieu
------------------------------------------------------------------------
-- Do uu tien: so NHO = uu tien CAO. Quest khong co trong bang = DEFAULT_QUEST_PRIORITY.
-- Moi lan InitQuest chay, script chon lai quest co so uu tien NHO NHAT (khong can du tai nguyen,
-- xem SKIP_QUESTS_WITHOUT_RESOURCES). Quest moi xuat hien o muc cao hon se duoc chuyen sang ngay.
-- Quest cung muc uu tien duoc xep co dinh theo thu tu trong Goals (slot).
local QUEST_PRIORITY = {
    BEST_RAINBOW_PET = 1,
    BEST_GOLD_PET = 1,
    USE_FLAG = 2,
    USE_POTION = 1,
    COLLECT_POTION = 1,
    COLLECT_ENCHANT = 1,
    BEST_COMET = 2,
    BEST_COIN_JAR = 2,
    BEST_LUCKYBLOCK = 2,
    BEST_PINATA = 3,
    BEST_EGG = 3,
    CURRENT_BREAKABLE = 4,
    BEST_SUPERIOR_MINI_CHEST = 4,
    DIAMOND_BREAKABLE = 4,
    BEST_MINI_CHEST = 4,
    HATCH_RARE_PET = 1,
    CURRENCY = 5,
}

local DEFAULT_QUEST_PRIORITY = 4

local function GetQuestPriority(questName)
    return QUEST_PRIORITY[questName] or DEFAULT_QUEST_PRIORITY
end

-- Goals: [tenQuest] = id
function GetQuestByID(id)
    for name, goalId in pairs(Goals) do
        if id == goalId then
            return name, goalId
        end
    end
    return nil
end

function GetIDByQuest(name)
    for goalName, goalId in pairs(Goals) do
        if name == goalName then
            return goalId, goalName
        end
    end
    return nil
end

-- So sanh khoa cua bang Goals: so truoc (theo gia tri), chuoi sau (theo chu cai)
local function CompareGoalKeys(a, b)
    local na, nb = tonumber(a), tonumber(b)
    if na and nb then
        return na < nb
    end
    if na then
        return true
    end
    if nb then
        return false
    end
    return tostring(a) < tostring(b)
end

local activeQuests = {}
function GetActiveQuests()
    table.clear(activeQuests)

    local goals = Save.Get().Goals
    local keys = {}
    for key in pairs(goals) do
        table.insert(keys, key)
    end
    table.sort(keys, CompareGoalKeys)

    for slot, key in ipairs(keys) do
        local goal = goals[key]
        local questName = GetQuestByID(goal.Type)
        table.insert(activeQuests, {
            slot = slot, -- vi tri quest trong danh sach Goals (dung de tim Frame tren UI)
            questname = questName,
            priority = GetQuestPriority(questName),
            amount = goal.Amount,
            neededamount = goal.Amount - goal.Progress,
            queststars = goal.Stars,
            id = goal.Type,
            potiontier = goal.PotionTier or nil,
        })
    end
    return activeQuests
end

local zoneGateQuests = {}
function GetZoneGateQuests()
    table.clear(zoneGateQuests)

    local quest = GetCurrentZoneQuests()
    if not quest then
        return
    end

    local questName = GetQuestByID(quest.Type)
    table.insert(zoneGateQuests, {
        questname = questName,
        priority = GetQuestPriority(questName),
        amount = quest.Amount,
        neededamount = quest.Amount - quest.Progress,
        id = quest.Type,
        potiontier = quest.PotionTier or nil,
    })
    return zoneGateQuests
end

-- priority tang dan (so nho = uu tien cao); bang nhau thi theo slot -> thu tu co dinh,
-- khong bi dao qua lai giua cac vong lap (table.sort khong on dinh neu chi so sanh priority)
function SortQuestsByPriority(quests)
    table.sort(quests, function(a, b)
        if a.priority ~= b.priority then
            return a.priority < b.priority
        end
        return (a.slot or 0) < (b.slot or 0)
    end)
    return quests
end

------------------------------------------------------------------------
-- Quest: kiem tra tai nguyen (tra ve: du?, uid, soLuongDangCo)
------------------------------------------------------------------------
-- Moi lan spawn/dung 1 item deu tinh vao quest, nen chi can co it nhat 1 cai
-- (khong can du ca neededamount, neu khong thi co 1-2 item van khong bao gio duoc spawn)
local function CheckMisc(itemId)
    local uid, have = FindMisc(itemId)
    return uid ~= nil, uid, have
end

local function CheckPotion(minTier, needed)
    for uid, potion in pairs(Inventory().Potion) do
        local have = potion._am or 1
        if minTier <= potion.tn and needed <= have then
            return true, uid, have
        end
    end
    return false, nil, 0
end

local function CheckCollectPotion(amount)
    if not amount then
        return
    end

    local uid, _, have = FindPotionUpgrade(amount)
    if uid then
        return true, uid, have
    end
    return false, nil, 0
end

local function CheckCollectEnchant(amount)
    if not amount then
        return
    end

    local uid, _, have = FindEnchantUpgrade(amount)
    if uid then
        return true, uid, have
    end
    return false, nil, 0
end

local QuestChecks = {
    BEST_COMET = function(quest)
        return CheckMisc("Comet")
    end,
    BEST_COIN_JAR = function(quest)
        return CheckMisc("Basic Coin Jar")
    end,
    BEST_LUCKYBLOCK = function(quest)
        return CheckMisc("Mini Lucky Block")
    end,
    BEST_PINATA = function(quest)
        return CheckMisc("Mini Pinata")
    end,
    USE_POTION = function(quest)
        return CheckPotion(quest.potiontier, quest.neededamount)
    end,
    COLLECT_POTION = function(quest)
        return CheckCollectPotion(quest.neededamount)
    end,
    COLLECT_ENCHANT = function(quest)
        return CheckCollectEnchant(quest.neededamount)
    end,
    BEST_GOLD_PET = function(quest)
        return HasEnoughPets(GetPetsByRarity(0), quest.neededamount)
    end,
    BEST_RAINBOW_PET = function(quest)
        return HasEnoughPets(GetPetsByRarity(1), quest.neededamount)
    end,
}

------------------------------------------------------------------------
-- Quest: thuc hien
------------------------------------------------------------------------
-- Dung item (neu co) trong khu vuc tot nhat hien tai
local function UseItemInBestZone(itemId, remoteName)
    TeleportToZone(GetMaximumZoneInfo().Folder)
    if itemId and remoteName then
        UseMiscItem(itemId, remoteName)
    end
end

local function ConvertPets(petType, machineRemote, quest)
    for uid, pet in pairs(GetPetsByRarity(petType)) do
        if pet.Amount >= (quest.neededamount + 1) * 10 then
            Network.Invoke(machineRemote, uid, quest.neededamount + 1)
            return
        end
    end
    TeleportToZone(quest.Folder)
end

local RARE_EGG_CAPSULES = {
    [3] = "215 - Egg Capsule",
    [4] = "264 - Egg Capsule",
}

-- StreamingEnabled: capsule bi unload khi dung xa nen FindFirstChild tra ve nil.
-- Luu CFrame khi da thay, lan sau xa thi tele thang toi do de stream lai.
local capsuleCFrames = {}

local function GetCapsuleCFrame(worldNumber, capsuleName)
    local eggs = Workspace.__THINGS:FindFirstChild("Eggs")
    local worldFolder = eggs and eggs:FindFirstChild("World" .. worldNumber)
    local capsule = worldFolder and worldFolder:FindFirstChild(capsuleName)
    if not capsule then
        return nil
    end

    local tier = capsule:FindFirstChild("Tier")
    return tier and tier.CFrame or capsule:GetPivot()
end

-- Lan dau chua co CFrame: tim zone co trung cung so voi capsule de tele toi gan
local function FindZoneByEgg(eggNumber, worldNumber)
    for _, zone in pairs(ZonesDirectory) do
        if zone.WorldNumber == worldNumber and zone.MaximumAvailableEgg == eggNumber then
            return zone
        end
    end
    return nil
end

local EGG_STAND_OFFSETS = {
    [3] = { Dist = 35, Offset = 30 },
    [4] = { Dist = 85, Offset = -30 },
}

local QuestHandlers = {
    BEST_RAINBOW_PET = function(quest)
        ConvertPets(1, "RainbowMachine_Activate", quest)
    end,

    BEST_GOLD_PET = function(quest)
        ConvertPets(0, "GoldMachine_Activate", quest)
    end,

    COLLECT_POTION = function(quest)
        if not CombinePotions(quest.neededamount) then
            TeleportToZone(quest.Folder)
        end
    end,

    COLLECT_ENCHANT = function(quest)
        if not CombineEnchants(quest.neededamount) then
            TeleportToZone(quest.Folder)
        end
    end,

    BEST_COMET = function()
        UseItemInBestZone("Comet", "Comet_Spawn")
    end,

    BEST_COIN_JAR = function()
        UseItemInBestZone("Basic Coin Jar", "CoinJar_Spawn")
    end,

    BEST_LUCKYBLOCK = function()
        UseItemInBestZone("Mini Lucky Block", "MiniLuckyBlock_Consume")
    end,

    BEST_PINATA = function()
        UseItemInBestZone("Mini Pinata", "MiniPinata_Consume")
    end,

    USE_POTION = function(quest)
        UsePotion(quest.potiontier, quest.neededamount)
    end,

    CURRENT_BREAKABLE = function()
        UseItemInBestZone()
    end,

    BREAKABLE = function()
        UseItemInBestZone()
    end,

    HATCH_RARE_PET = function(quest)
        local worldNumber = GetWorldNumber()
        local capsuleName = RARE_EGG_CAPSULES[worldNumber]
        local root = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        if not capsuleName or not root then
            return
        end

        local capsuleCFrame = GetCapsuleCFrame(worldNumber, capsuleName)
        if capsuleCFrame then
            capsuleCFrames[worldNumber] = capsuleCFrame
            root.CFrame = capsuleCFrame
            HatchClosestEgg()
            return
        end

        -- Capsule chua duoc stream (dung qua xa)
        local cached = capsuleCFrames[worldNumber]
        if cached then
            root.CFrame = cached
            pcall(LocalPlayer.RequestStreamAroundAsync, LocalPlayer, cached.Position)
            return
        end

        local zone = FindZoneByEgg(tonumber(capsuleName:split(" ")[1]), worldNumber)
        TeleportToZone((zone and zone.ZoneFolder) or quest.Folder)
    end,

    BEST_EGG = function(quest)
        local eggModule = GetBestEggModule()
        local eggInstance = GetBestEggInstance()
        local zone = GetMaximumZoneInfo()
        local currency = GetCurrency()

        if not eggModule or not eggInstance then
            return
        end

        setthreadidentity(4)
        local price = CalcEggPricePlayer(eggModule)
        local needed = quest.neededamount or 1

        if currency >= price * needed then
            local priceHUD = eggInstance:FindFirstChild("PriceHUD")
            local root = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
            if priceHUD and root then
                local stand = EGG_STAND_OFFSETS[zone.World] or { Dist = 5, Offset = 1 }
                if (root.Position - priceHUD.Position).Magnitude >= stand.Dist then
                    root.CFrame = priceHUD.CFrame * CFrame.new(0, 0, stand.Offset)
                end
                HatchClosestEgg()
            end
        else
            TeleportToZone(zone.Folder)
        end
    end,
}

-- Chay quest: neu co handler thi goi, khong thi chi farm o zone tot nhat
function MakeQuest(questName, args)
    local zone = GetMaximumZoneInfo()
    local handler = QuestHandlers[questName]

    if handler then
        args.Folder = zone.Folder
        handler(args)
    else
        TeleportToZone(zone.Folder)
    end
end

------------------------------------------------------------------------
-- To mau tieu de quest dang lam trong UI (hieu ung hien thi)
------------------------------------------------------------------------
local QUEST_HIGHLIGHT_COLOR = Color3.fromRGB(0, 170, 255) -- quest dang lam
local QUEST_DEFAULT_COLOR = Color3.fromRGB(255, 255, 255) -- cac quest con lai

-- (Tuy chon) [so sao] -> ten Frame, neu ban biet chinh xac (cach lam cua script goc,
-- bang nay bi mat khi decompile). De trong = tu dong xac dinh theo vi tri.
local QUEST_FRAME_NAME = {}

local function GetQuestHolder()
    local gui = LocalPlayer:FindFirstChild("PlayerGui")
    local goalsSide = gui and gui:FindFirstChild("GoalsSide")
    local frame = goalsSide and goalsSide:FindFirstChild("Frame")
    local quests = frame and frame:FindFirstChild("Quests")
    local gradient = quests and quests:FindFirstChild("QuestsGradient")
    return gradient and gradient:FindFirstChild("QuestsHolder")
end

-- Cac Frame quest dang hien, sap theo thu tu hien thi (LayoutOrder, roi toa do Y)
local function GetQuestFrames()
    local frames = {}
    local holder = GetQuestHolder()
    if not holder then
        return frames
    end

    for _, child in pairs(holder:GetChildren()) do
        if child:IsA("Frame") and child.Visible and child:FindFirstChild("Title") then
            table.insert(frames, child)
        end
    end

    table.sort(frames, function(a, b)
        if a.LayoutOrder ~= b.LayoutOrder then
            return a.LayoutOrder < b.LayoutOrder
        end
        return a.AbsolutePosition.Y < b.AbsolutePosition.Y
    end)
    return frames
end

-- Tim Frame cua quest dang lam:
--   1) neu QUEST_FRAME_NAME co khai bao -> dung ten Frame theo so sao (cach goc)
--   2) neu khong -> quest thu N trong Goals = Frame thu N tren UI
--      (chi dung khi so Frame == so Goals, de khong to nham dong)
local function FindQuestFrame(quest, goalCount, frames)
    local frameName = QUEST_FRAME_NAME[quest.queststars]
    if frameName then
        for _, frame in ipairs(frames) do
            if frame.Name == frameName then
                return frame
            end
        end
        return nil
    end

    if quest.slot and goalCount == #frames then
        return frames[quest.slot]
    end
    return nil
end

local highlightWarned = false

local function HighlightQuest(quest, goalCount)
    pcall(function()
        local frames = GetQuestFrames()
        if #frames == 0 then
            return
        end

        local target = FindQuestFrame(quest, goalCount, frames)
        if not target and not highlightWarned then
            highlightWarned = true
            dprint(
                "HighlightQuest: khong xac dinh duoc Frame (so Frame = " .. #frames
                    .. ", so Goals = " .. tostring(goalCount)
                    .. "). Chay DumpQuestFrames() de xem ten Frame."
            )
        end

        for _, frame in ipairs(frames) do
            frame.Title.TextColor3 = (frame == target) and QUEST_HIGHLIGHT_COLOR or QUEST_DEFAULT_COLOR
        end
    end)
end

-- Cong cu tro giup: in thong tin cac Frame trong QuestsHolder de dien QUEST_FRAME_NAME
function DumpQuestFrames()
    local holder = GetQuestHolder()
    if not holder then
        print("Khong tim thay QuestsHolder")
        return
    end

    for _, child in pairs(holder:GetChildren()) do
        if child:IsA("GuiObject") then
            local title = child:FindFirstChild("Title")
            print(
                child.ClassName,
                child.Name,
                "LayoutOrder=" .. tostring(child.LayoutOrder),
                "Visible=" .. tostring(child.Visible),
                title and title.Text or ""
            )
        end
    end
end

------------------------------------------------------------------------
-- Vong lap chinh
------------------------------------------------------------------------
-- Rebirth neu da du zone, neu khong thi mua zone ke tiep khi du tien.
-- Tra ve true neu da thuc hien 1 hanh dong.
local function TryRebirthOrBuyZone(maxZone, nextZone)
    local nextRebirth = RebirthCmds.GetNextRebirth()
    if nextRebirth and maxZone.ZoneNumber >= nextRebirth.ZoneNumberRequired then
        RebirthCmds.Rebirth(tostring(nextRebirth.RebirthNumber))
        return true
    end

    if nextZone then
        local price = CalcGatePrice(nextZone)
        if price and price <= GetCurrency() then
            Network.Invoke("Zones_RequestPurchase", nextZone._id)
            return true
        end
    end
    return false
end

-- Ghi log khi quest dang lam thay doi (vd: co quest uu tien cao hon xuat hien)
local currentQuestKey, currentQuestName

local function NoteActiveQuest(quest, isZoneGate, lacking)
    local key = (isZoneGate and "gate:" or "goal:") .. tostring(quest.questname) .. ":" .. tostring(quest.slot)
    if key ~= currentQuestKey then
        dprint(
            "Switch quest: " .. tostring(currentQuestName) .. " -> " .. tostring(quest.questname)
                .. " (priority " .. tostring(quest.priority) .. ")"
                .. (lacking and " [thieu tai nguyen -> farm zone tot nhat]" or "")
        )
        currentQuestKey, currentQuestName = key, quest.questname
    end
end

-- false = luon lam quest co so uu tien NHO NHAT, du thieu tai nguyen hay khong
--         (thieu thi farm zone tot nhat de thu thap, khong chay handler cua quest)
-- true  = cach cu: bo qua quest thieu tai nguyen va lam quest ke tiep
-- Luu y: khi false, quest ma farm khong the dap ung (vd: BEST_RAINBOW_PET khi chua co pet gold)
-- se giu bot o quest do den khi du dieu kien.
local SKIP_QUESTS_WITHOUT_RESOURCES = false

local STATUS_INTERVAL = 10 -- giay
local lastStatusPrint = 0

-- In 1 dong tom tat tat ca quest: priority, can them, co du tai nguyen khong
local function PrintQuestStatus(sortedQuests)
    local now = os.clock()
    if now - lastStatusPrint < STATUS_INTERVAL then
        return
    end
    lastStatusPrint = now

    local parts = {}
    for _, quest in ipairs(sortedQuests) do
        local state = "no-check"
        local check = QuestChecks[quest.questname]
        if check then
            local success, can, _, have = pcall(check, quest)
            state = success and ("can=" .. tostring(can) .. ",have=" .. tostring(have)) or "check-error"
        end
        table.insert(
            parts,
            tostring(quest.questname) .. "(p" .. tostring(quest.priority) .. ",need=" .. tostring(quest.neededamount) .. "," .. state .. ")"
        )
    end
    dprint("STATUS: " .. table.concat(parts, " | "))
end

local function RunTopPriorityQuest(quests, isZoneGate)
    local sortedQuests = SortQuestsByPriority(quests)
    PrintQuestStatus(sortedQuests)

    for index, quest in pairs(sortedQuests) do
        if isZoneGate then
            dprint(index, quest.questname, "-- InitQuest")
        end

        local canDo, have = true, 0
        local check = QuestChecks[quest.questname]
        if check then
            local ok, _, amount = check(quest)
            canDo, have = ok, amount or 0
        end

        if canDo or not SKIP_QUESTS_WITHOUT_RESOURCES then
            NoteActiveQuest(quest, isZoneGate, not canDo)
            if not isZoneGate then
                HighlightQuest(quest, #quests)
            end

            if canDo then
                MakeQuest(quest.questname, {
                    amount = quest.amount,
                    potiontier = quest.potiontier,
                    neededamount = quest.neededamount,
                })
            else
                TeleportToZone(GetMaximumZoneInfo().Folder)
            end
            return
        end

        if isZoneGate then
            dprint(
                "You don't have enough resources for quest: " .. tostring(quest.questname)
                    .. " (have: " .. tostring(have) .. ", need: " .. tostring(quest.neededamount) .. "). Skipping."
            )
        end
    end
end

function InitQuest()
    if GetMaximumZoneInfo().Number == ZoneCmds.GetMaximumOverallZone().ZoneNumber then
        -- Dang o zone cao nhat: lam quest thuong
        RunTopPriorityQuest(GetActiveQuests(), false)
    elseif GetCurrentZoneQuests() then
        -- Co quest mo cong zone tiep theo
        dprint("MAKING ZONEGATEQUEST")
        TryRebirthOrBuyZone(GetMaximumZone(), GetNextZone())
        RunTopPriorityQuest(GetZoneGateQuests(), true)
    else
        -- Khong co quest: farm, mua zone, rebirth, doi world
        dprint("Farm Areas")
        local maxZone = GetMaximumZone()
        local nextZone = GetNextZone()

        if nextZone and maxZone.WorldNumber ~= nextZone.WorldNumber then
            Network.Invoke("World" .. nextZone.WorldNumber .. "Teleport")
        elseif not TryRebirthOrBuyZone(maxZone, nextZone) then
            TeleportToZone(maxZone.ZoneFolder)
        end
    end
end

return InitQuest
