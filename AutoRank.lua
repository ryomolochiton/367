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

    local interact = zoneFolder:FindFirstChild("INTERACT")
    local spawnPosition = interact and interact.BREAKABLE_SPAWNS.Main.Position

    if not spawnPosition or (root.Position - spawnPosition).Magnitude > 30 then
        root.CFrame = zoneFolder.PERSISTENT.Teleport.CFrame

        repeat
            task.wait()
        until not LocalPlayer.Character or IsGrounded()

        if interact then
            root.CFrame = interact.BREAKABLE_SPAWNS.Main.CFrame
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
function UseMiscItem(itemId, remoteName)
    local foundUid
    for uid, item in pairs(Inventory().Misc or {}) do
        if item.id == itemId then
            foundUid = uid
        end
    end

    if foundUid then
        Network.Invoke(remoteName, tostring(foundUid))
    end
end

function UsePotion(minTier, amount)
    for uid, potion in pairs(Inventory().Potion) do
        if minTier <= potion.tn and amount <= (potion._am or 1) then
            Network.Fire("Potions: Consume", tostring(uid), amount)
            break
        end
    end
end

local function IsCombinablePotion(potion)
    return potion.tn > 1 and potion.tn <= 4 and potion.id ~= "Walkspeed" and potion.tn ~= 3
end

local EXCLUDED_ENCHANTS = { "Magnet 3" } -- khong gop cac enchant nay

local function IsCombinableEnchant(enchant)
    return enchant.tn > 1 and enchant.tn <= 4 and not table.find(EXCLUDED_ENCHANTS, enchant.id .. " " .. enchant.tn)
end

-- Gop potion len tier (dung may Upgrade Potions). Chi gop 1 loai moi lan goi.
local function CombinePotions(amount)
    if not amount then
        return
    end

    for uid, potion in pairs(Inventory().Potion) do
        if IsCombinablePotion(potion) then
            setthreadidentity(4)
            local required = CalcPotionsPerTierRequired(potion.tn) * amount
            if required < (potion._am or 1) then
                print("Combining:", potion.id, potion.tn, required)
                Network.Invoke("UpgradePotionsMachine_Activate", uid, amount)
                break
            end
        end
    end
end

-- Gop enchant len tier (dung may Upgrade Enchants). Chi gop 1 loai moi lan goi.
local function CombineEnchants(amount)
    if not amount then
        return
    end

    for uid, enchant in pairs(Inventory().Enchant) do
        if IsCombinableEnchant(enchant) then
            setthreadidentity(4)
            local required = CalcEnchantsPerTierRequired(enchant.tn) * amount
            local have = enchant._am or 1
            dprint("Enchant DEBUG PRINT", enchant.id, enchant.tn, have, required)
            if required < have then
                print("Combining:", enchant.id, enchant.tn, math.floor(required))
                Network.Invoke("UpgradeEnchantsMachine_Activate", uid, amount)
                break
            end
        end
    end
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
-- Do uu tien: so nho chay truoc. Quest khong co trong bang = 4.
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
    BEST_PINATA = 2,
    BEST_EGG = 3,
    CURRENT_BREAKABLE = 3,
    BEST_SUPERIOR_MINI_CHEST = 4,
    DIAMOND_BREAKABLE = 4,
    BEST_MINI_CHEST = 4,
    HATCH_RARE_PET = 1,
    CURRENCY = 5,
}

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
            priority = QUEST_PRIORITY[questName] or 4,
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
        priority = QUEST_PRIORITY[questName] or 4,
        amount = quest.Amount,
        neededamount = quest.Amount - quest.Progress,
        id = quest.Type,
        potiontier = quest.PotionTier or nil,
    })
    return zoneGateQuests
end

function SortQuestsByPriority(quests)
    table.sort(quests, function(a, b)
        return a.priority < b.priority
    end)
    return quests
end

------------------------------------------------------------------------
-- Quest: kiem tra tai nguyen (tra ve: du?, uid, soLuongDangCo)
------------------------------------------------------------------------
local function CheckMisc(itemId, needed)
    for uid, item in pairs(Inventory().Misc or {}) do
        if item.id == itemId then
            local have = item._am or 1
            return needed <= have, uid, have
        end
    end
    return false, nil, 0
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

    for uid, potion in pairs(Inventory().Potion) do
        if IsCombinablePotion(potion) then
            setthreadidentity(4)
            local required = CalcPotionsPerTierRequired(potion.tn) * amount
            local have = potion._am or 1
            dprint("Potion Amount Check DEBUG PRINT", required, have, potion.id, potion.tn)
            if required <= have then
                return true, uid, have
            end
        end
    end
    return false, nil, 0
end

local function CheckCollectEnchant(amount)
    if not amount then
        return
    end

    for uid, enchant in pairs(Inventory().Enchant) do
        if IsCombinableEnchant(enchant) then
            setthreadidentity(4)
            local required = CalcEnchantsPerTierRequired(enchant.tn) * amount
            local have = enchant._am or 1
            dprint("Enchant Amount Check DEBUG PRINT", required, have, enchant.id, enchant.tn)
            if required <= have then
                return true, uid, have
            end
        end
    end
    return false, nil, 0
end

local QuestChecks = {
    BEST_COMET = function(quest)
        return CheckMisc("Comet", quest.neededamount)
    end,
    BEST_COIN_JAR = function(quest)
        return CheckMisc("Basic Coin Jar", quest.neededamount)
    end,
    BEST_LUCKYBLOCK = function(quest)
        return CheckMisc("Mini Lucky Block", quest.neededamount)
    end,
    BEST_PINATA = function(quest)
        return CheckMisc("Mini Pinata", quest.neededamount)
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
        CombinePotions(quest.neededamount)
    end,

    COLLECT_ENCHANT = function(quest)
        CombineEnchants(quest.neededamount)
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

    HATCH_RARE_PET = function()
        local worldNumber = GetWorldNumber()
        local capsuleName = RARE_EGG_CAPSULES[worldNumber]
        local root = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        if not capsuleName or not root then
            return
        end

        local capsule = Workspace.__THINGS.Eggs["World" .. worldNumber]:FindFirstChild(capsuleName)
        if capsule then
            root.CFrame = capsule.Tier.CFrame
            HatchClosestEgg()
        end
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

-- Lam quest dau tien du tai nguyen (da sap theo uu tien), bo qua quest thieu tai nguyen
local function RunFirstDoableQuest(quests, isZoneGate)
    for index, quest in pairs(SortQuestsByPriority(quests)) do
        if isZoneGate then
            dprint(index, quest.questname, "-- InitQuest")
        end

        local canDo, have = true, 0
        local check = QuestChecks[quest.questname]
        if check then
            local ok, _, amount = check(quest)
            canDo, have = ok, amount or 0
        end

        if canDo then
            if not isZoneGate then
                HighlightQuest(quest, #quests)
            end
            MakeQuest(quest.questname, {
                amount = quest.amount,
                potiontier = quest.potiontier,
                neededamount = quest.neededamount,
            })
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
        RunFirstDoableQuest(GetActiveQuests(), false)
    elseif GetCurrentZoneQuests() then
        -- Co quest mo cong zone tiep theo
        dprint("MAKING ZONEGATEQUEST")
        TryRebirthOrBuyZone(GetMaximumZone(), GetNextZone())
        RunFirstDoableQuest(GetZoneGateQuests(), true)
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
