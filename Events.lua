-- =====================================================
-- VRT DIAGNOSTIC v5.0 — Flag SpatialQuery hunt / Fruit verify / Merchant deep
-- Save -> VRT/VRT_Diag5.txt
-- CHẠY KHI ĐANG Ở TRONG DIAMOND MOUNTAIN
-- =====================================================

local CONFIG = {
	-- FLAG: scan 100+ positions để tìm chỗ SpatialQuery non-nil
	TEST_FLAG_SCAN = true,
	TEST_FLAG_CONSUME = true,
	TEST_FLAG_ACTIVATE = true,
	FLAG_TO_TEST = "Coins Flag",

	-- FRUIT: verify inventory diff trước/sau
	TEST_FRUIT = true,
	FRUIT_AMOUNT = 5,

	-- MERCHANT: deep inspect + all remote signatures
	TEST_MERCHANT = true,
	TEST_MERCHANT_PURCHASE = true,

	MAX_TABLE_ENTRIES = 40,
	MAX_DEPTH = 4,
	WAIT = 0.35,
}

local playersService = game:GetService("Players")
local replicatedStorage = game:GetService("ReplicatedStorage")

local localPlayer = playersService.LocalPlayer
local libraryFolder = replicatedStorage:WaitForChild("Library")
local clientFolder = libraryFolder:WaitForChild("Client")
local utilFolder = libraryFolder:FindFirstChild("Util")
local directoryFolder = libraryFolder:FindFirstChild("Directory")
local networkFolder = replicatedStorage:FindFirstChild("Network")

local DIAG_FOLDER = "VRT"
local DIAG_PATH = "VRT/VRT_Diag5.txt"

pcall(function()
	if not isfolder(DIAG_FOLDER) then
		makefolder(DIAG_FOLDER)
	end
end)

local lines = {}

local function w(...)
	local parts = {}
	for i = 1, select("#", ...) do
		parts[#parts + 1] = tostring(select(i, ...))
	end
	local line = table.concat(parts, " ")
	lines[#lines + 1] = line
	print(line)
end

local function sep(title)
	w("")
	w(string.rep("=", 78))
	w("=== " .. title)
	w(string.rep("=", 78))
end

local function flush()
	local content = table.concat(lines, "\n")
	local ok, err = pcall(writefile, DIAG_PATH, content)
	if ok then
		print(("[VRT-DIAG] Saved -> %s (%d bytes)"):format(DIAG_PATH, #content))
	else
		warn("[VRT-DIAG] writefile failed: " .. tostring(err))
		pcall(setclipboard, content)
		print("[VRT-DIAG] Copied to clipboard instead.")
	end
end

local function flushSafe()
	pcall(flush)
end

local function serialize(value, depth, seen)
	depth = depth or 0
	seen = seen or {}
	if depth > CONFIG.MAX_DEPTH then return "..." end
	local t = typeof(value)
	if t == "string" then
		if #value > 200 then
			return string.format("%q..(%d)", value:sub(1, 200), #value)
		end
		return string.format("%q", value)
	elseif t == "number" or t == "boolean" or t == "nil" then
		return tostring(value)
	elseif t == "Instance" then
		return value:GetFullName()
	elseif t == "Vector3" then
		return string.format("Vector3(%.1f,%.1f,%.1f)", value.X, value.Y, value.Z)
	elseif t == "CFrame" then
		local p = value.Position
		return string.format("CFrame(%.1f,%.1f,%.1f)", p.X, p.Y, p.Z)
	elseif t == "Color3" then
		return string.format("Color3(%d,%d,%d)", value.R * 255, value.G * 255, value.B * 255)
	elseif t == "EnumItem" then
		return tostring(value)
	elseif t == "function" then
		local info = debug.getinfo(value)
		return string.format("<fn %s>", info and info.what or "?")
	elseif t == "table" then
		if seen[value] then return "<cycle>" end
		seen[value] = true
		local parts = {}
		local count = 0
		for k, v in pairs(value) do
			count += 1
			if count > CONFIG.MAX_TABLE_ENTRIES then
				parts[#parts + 1] = "..."
				break
			end
			parts[#parts + 1] = string.format("[%s]=%s",
				serialize(k, depth + 1, seen),
				serialize(v, depth + 1, seen))
		end
		seen[value] = nil
		return "{" .. table.concat(parts, ", ") .. "}"
	end
	return tostring(value)
end

local function safeRequire(inst)
	if not inst or typeof(inst) ~= "Instance" then return nil, "not Instance" end
	local ok, res = pcall(require, inst)
	if ok then return res end
	return nil, tostring(res)
end

local function getRoot()
	local character = localPlayer.Character
	return character and character:FindFirstChild("HumanoidRootPart") or nil
end

-- -----------------------------------------------------
-- HEADER
-- -----------------------------------------------------
sep("HEADER")
w("Time:", os.date("%c"))
w("Player:", localPlayer.Name, "|", tostring(localPlayer.UserId))
w("PlaceId:", tostring(game.PlaceId))
w("JobId:", tostring(game.JobId))
pcall(function()
	local a, b = identifyexecutor()
	w("Executor:", tostring(a), tostring(b))
end)

local root = getRoot()
if root then
	local p = root.Position
	w(("Position: %.1f, %.1f, %.1f"):format(p.X, p.Y, p.Z))
end

-- -----------------------------------------------------
-- MODULES
-- -----------------------------------------------------
local Modules = {
	Network = safeRequire(clientFolder:FindFirstChild("Network")),
	Save = safeRequire(clientFolder:FindFirstChild("Save")),
	MapCmds = safeRequire(clientFolder:FindFirstChild("MapCmds")),
	FlexibleFlagCmds = safeRequire(clientFolder:FindFirstChild("FlexibleFlagCmds")),
	ZoneFlagCmds = safeRequire(clientFolder:FindFirstChild("ZoneFlagCmds")),
	FruitCmds = safeRequire(clientFolder:FindFirstChild("FruitCmds")),
	CustomEggsCmds = safeRequire(clientFolder:FindFirstChild("CustomEggsCmds")),
	EggCmds = safeRequire(clientFolder:FindFirstChild("EggCmds")),
	DiamondMountainCmds = safeRequire(clientFolder:FindFirstChild("DiamondMountainCmds")),
	DiamondMountainMerchant = safeRequire(utilFolder and utilFolder:FindFirstChild("DiamondMountainMerchant")),
	MerchantUtil = safeRequire(utilFolder and utilFolder:FindFirstChild("MerchantUtil")),
	TravelingMerchantUtil = safeRequire(utilFolder and utilFolder:FindFirstChild("TravelingMerchantUtil")),
	MerchantsDir = safeRequire(directoryFolder and directoryFolder:FindFirstChild("Merchants")),
	ZoneFlagsDir = safeRequire(directoryFolder and directoryFolder:FindFirstChild("ZoneFlags")),
}

local function invoke(name, ...)
	local network = Modules.Network
	if not network or not network.Invoke then return false, "no network" end
	local ok, result = pcall(network.Invoke, name, ...)
	return ok, result
end

local function fire(name, ...)
	local network = Modules.Network
	if not network or not network.Fire then return false, "no network" end
	local ok, result = pcall(network.Fire, name, ...)
	return ok, result
end

local function getInstanceInfo()
	local mapCmds = Modules.MapCmds
	if mapCmds and mapCmds.GetCurrentInstanceInfo then
		local ok, info = pcall(mapCmds.GetCurrentInstanceInfo)
		if ok and typeof(info) == "table" then return info end
	end
	return nil
end

local function getSave()
	local saveMod = Modules.Save
	if saveMod and saveMod.Get then
		local ok, save = pcall(saveMod.Get)
		if ok and typeof(save) == "table" then return save end
	end
	return nil
end

-- -----------------------------------------------------
-- INSTANCE INFO
-- -----------------------------------------------------
sep("INSTANCE INFO")
local instanceInfo = getInstanceInfo()
w("GetCurrentInstanceInfo():", serialize(instanceInfo))
if Modules.MapCmds and Modules.MapCmds.GetCurrentZone then
	local ok, zone = pcall(Modules.MapCmds.GetCurrentZone)
	w(("GetCurrentZone(): ok=%s value=%s"):format(tostring(ok), serialize(zone)))
end

flushSafe()

-- =====================================================
-- FLAG DEEP DIVE
-- =====================================================
sep("FLAG 1 — SpatialQuery 11 ARG TYPES")
local flagCmds = Modules.FlexibleFlagCmds
local zoneFlagCmds = Modules.ZoneFlagCmds

if typeof(flagCmds) == "table" and typeof(flagCmds.SpatialQuery) == "function" and root then
	local pos = root.Position

	local argTests = {
		{ label = "no-arg", fn = function() return flagCmds.SpatialQuery() end },
		{ label = "nil", fn = function() return flagCmds.SpatialQuery(nil) end },
		{ label = "Vector3", fn = function() return flagCmds.SpatialQuery(pos) end },
		{ label = "CFrame", fn = function() return flagCmds.SpatialQuery(CFrame.new(pos)) end },
		{ label = "Part", fn = function() return flagCmds.SpatialQuery(root) end },
		{ label = "table.Position", fn = function() return flagCmds.SpatialQuery({ Position = pos }) end },
		{ label = "table.CFrame", fn = function() return flagCmds.SpatialQuery({ CFrame = CFrame.new(pos) }) end },
		{ label = "instanceInfo", fn = function() return flagCmds.SpatialQuery(instanceInfo) end },
		{ label = "instanceId", fn = function() return flagCmds.SpatialQuery(instanceInfo and instanceInfo.InstanceId) end },
		{ label = "areaId", fn = function() return flagCmds.SpatialQuery(instanceInfo and instanceInfo.AreaId) end },
		{ label = "zoneNumber", fn = function() return flagCmds.SpatialQuery(instanceInfo and instanceInfo.ZoneNumber) end },
	}

	for _, test in ipairs(argTests) do
		local ok, result = pcall(test.fn)
		w(("[%s] ok=%s result=%s"):format(test.label, tostring(ok), serialize(result)))
		task.wait(0.1)
	end
else
	w("SpatialQuery not available")
end

flushSafe()

sep("FLAG 2 — SpatialQuery SCAN 100+ POSITIONS")
local workingPositions = {}

if typeof(flagCmds) == "table" and typeof(flagCmds.SpatialQuery) == "function" and root then
	local positions = {}

	-- Current
	table.insert(positions, { pos = root.Position, label = "current" })

	-- Ground raycast
	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	rayParams.FilterDescendantsInstances = { localPlayer.Character }
	local rayResult = workspace:Raycast(root.Position, Vector3.new(0, -100, 0), rayParams)
	if rayResult then
		table.insert(positions, { pos = rayResult.Position, label = "ground" })
	end

	-- Grid ±60 (step 15) = 81 positions
	for dx = -60, 60, 15 do
		for dz = -60, 60, 15 do
			table.insert(positions, {
				pos = root.Position + Vector3.new(dx, 0, dz),
				label = ("grid(%d,%d)"):format(dx, dz),
			})
		end
	end

	-- Camp parts
	local things = workspace:FindFirstChild("__THINGS")
	local container = things and things:FindFirstChild("__INSTANCE_CONTAINER")
	local active = container and container:FindFirstChild("Active")
	local mountain = active and active:FindFirstChild("DiamondMountain")
	local camps = mountain and mountain:FindFirstChild("Camps")
	if camps then
		for _, camp in ipairs(camps:GetChildren()) do
			for _, partName in ipairs({ "Spawn", "Landing", "Merchant", "WallFront" }) do
				local part = camp:FindFirstChild(partName)
				if part and part:IsA("BasePart") then
					table.insert(positions, {
						pos = part.Position,
						label = ("camp%s-%s"):format(camp.Name, partName),
					})
				end
			end
		end
	end

	-- Break zones
	local breakZones = mountain and mountain:FindFirstChild("BREAK_ZONES")
	if breakZones then
		for _, zone in ipairs(breakZones:GetChildren()) do
			if zone:IsA("BasePart") then
				table.insert(positions, {
					pos = zone.Position,
					label = "zone-" .. zone.Name,
				})
			end
		end
	end

	-- Breakable spawns
	local instances = things and things:FindFirstChild("Instances")
	local dm = instances and instances:FindFirstChild("DiamondMountain")
	local breakableSpawns = dm and dm:FindFirstChild("BREAKABLE_SPAWNS")
	if breakableSpawns then
		for _, spawn in ipairs(breakableSpawns:GetChildren()) do
			if spawn:IsA("BasePart") then
				table.insert(positions, {
					pos = spawn.Position,
					label = "breakable-" .. spawn.Name,
				})
			end
		end
	end

	-- Teleports
	local teleports = dm and dm:FindFirstChild("Teleports")
	if teleports then
		for _, tp in ipairs(teleports:GetChildren()) do
			if tp:IsA("BasePart") then
				table.insert(positions, {
					pos = tp.Position,
					label = "tp-" .. tp.Name .. "-" .. tostring(tp:GetAttribute("Id") or "?"),
				})
			end
		end
	end

	w(("Scanning %d positions..."):format(#positions))
	w("")

	for _, entry in ipairs(positions) do
		local ok, ctx = pcall(flagCmds.SpatialQuery, entry.pos)
		if ok and ctx ~= nil then
			table.insert(workingPositions, {
				pos = entry.pos,
				label = entry.label,
				ctx = ctx,
			})
			w(("[VALID] %s pos=%.1f,%.1f,%.1f ctx=%s"):format(
				entry.label,
				entry.pos.X, entry.pos.Y, entry.pos.Z,
				serialize(ctx)
			))
		end
	end

	w("")
	w(("Total valid positions: %d / %d"):format(#workingPositions, #positions))
else
	w("SpatialQuery not available")
end

flushSafe()

sep("FLAG 3 — CONSUME 5 SIGNATURES (with valid spatial)")
if CONFIG.TEST_FLAG_CONSUME and #workingPositions > 0 then
	local target = workingPositions[1]
	w(("Using position: %s | ctx=%s"):format(target.label, serialize(target.ctx)))
	w("")

	-- Save original position
	local originalCFrame = root.CFrame
	root.CFrame = CFrame.new(target.pos)
	task.wait(0.4)

	local flagId = CONFIG.FLAG_TO_TEST
	local info = instanceInfo

	local function test(label, fn, ...)
		local ok, result = pcall(fn, ...)
		w(("[%s] ok=%s result=%s"):format(label, tostring(ok), serialize(result)))
		task.wait(CONFIG.WAIT)
	end

	if typeof(flagCmds) == "table" and flagCmds.Consume then
		test("1.flex-flag,amt,ctx", flagCmds.Consume, flagId, 1, target.ctx)
		test("2.flex-flag,amt,pos", flagCmds.Consume, flagId, 1, target.pos)
		test("3.flex-flag,amt,info", flagCmds.Consume, flagId, 1, info)
		test("4.flex-flag,amt", flagCmds.Consume, flagId, 1)
		test("5.flex-flag", flagCmds.Consume, flagId)
	end

	if typeof(zoneFlagCmds) == "table" and zoneFlagCmds.Consume then
		test("6.zone-flag,amt,ctx", zoneFlagCmds.Consume, flagId, 1, target.ctx)
		test("7.zone-flag,amt,pos", zoneFlagCmds.Consume, flagId, 1, target.pos)
		test("8.zone-flag,amt,info", zoneFlagCmds.Consume, flagId, 1, info)
		test("9.zone-flag,amt", zoneFlagCmds.Consume, flagId, 1)
	end

	pcall(function() root.CFrame = originalCFrame end)
elseif CONFIG.TEST_FLAG_CONSUME then
	w("(no valid positions — skip consume test)")
end

flushSafe()

sep("FLAG 4 — ACTIVATE 3 SIGNATURES")
if CONFIG.TEST_FLAG_ACTIVATE and typeof(flagCmds) == "table" and flagCmds.ActivateFlag then
	local flagId = CONFIG.FLAG_TO_TEST
	local ctx = #workingPositions > 0 and workingPositions[1].ctx or nil
	local pos = #workingPositions > 0 and workingPositions[1].pos or (root and root.Position)

	if pos and root then
		local original = root.CFrame
		root.CFrame = CFrame.new(pos)
		task.wait(0.4)
	end

	local function test(label, fn, ...)
		local ok, result = pcall(fn, ...)
		w(("[%s] ok=%s result=%s"):format(label, tostring(ok), serialize(result)))
		task.wait(CONFIG.WAIT)
	end

	test("1.flex-activate(flag,ctx)", flagCmds.ActivateFlag, flagId, ctx)
	test("2.flex-activate(flag,pos)", flagCmds.ActivateFlag, flagId, pos)
	test("3.flex-activate(flag)", flagCmds.ActivateFlag, flagId)

	if typeof(zoneFlagCmds) == "table" and zoneFlagCmds.ActivateFlag then
		test("4.zone-activate(flag,ctx)", zoneFlagCmds.ActivateFlag, flagId, ctx)
		test("5.zone-activate(flag,pos)", zoneFlagCmds.ActivateFlag, flagId, pos)
	end

	-- Check active
	if flagCmds.GetActiveFlag then
		test("GetActiveFlag after", flagCmds.GetActiveFlag)
	end
	if zoneFlagCmds.GetActiveFlags then
		test("ZoneFlagCmds.GetActiveFlags after", zoneFlagCmds.GetActiveFlags)
	end
end

flushSafe()

sep("FLAG 5 — __THINGS.Flags + Directory.ZoneFlags")
local things = workspace:FindFirstChild("__THINGS")
local flagsFolder = things and things:FindFirstChild("Flags")
if flagsFolder then
	w(("__THINGS.Flags children: %d"):format(#flagsFolder:GetChildren()))
	for _, child in ipairs(flagsFolder:GetChildren()) do
		local extra = ""
		if child:IsA("BasePart") then
			extra = (" pos=%.1f,%.1f,%.1f"):format(
				child.Position.X, child.Position.Y, child.Position.Z
			)
		end
		w(("  %s (%s)%s"):format(child.Name, child.ClassName, extra))
	end
else
	w("__THINGS.Flags NOT FOUND")
end

w("")
w("-- Directory.ZoneFlags:")
local zfDir = Modules.ZoneFlagsDir
if typeof(zfDir) == "table" then
	for k, v in pairs(zfDir) do
		if typeof(v) == "table" then
			w(("  [%s] _id=%s Name=%s Duration=%s"):format(
				tostring(k), tostring(v._id), tostring(v.Name), tostring(v.Duration)
			))
		end
	end
end

flushSafe()

-- =====================================================
-- FRUIT DEEP VERIFY
-- =====================================================
sep("FRUIT 1 — INVENTORY BEFORE")
local fruitCmds = Modules.FruitCmds
local save = getSave()

local function getFruitSnapshot()
	local snap = {}
	if save and typeof(save.Inventory) == "table" and typeof(save.Inventory.Fruit) == "table" then
		for uid, entry in pairs(save.Inventory.Fruit) do
			if typeof(entry) == "table" then
				local maxConsume = -1
				if fruitCmds and fruitCmds.GetMaxConsume then
					local ok, value = pcall(fruitCmds.GetMaxConsume, uid)
					if ok and typeof(value) == "number" then maxConsume = value end
				end
				snap[uid] = {
					id = entry.id,
					shiny = entry.sh == true,
					amount = entry._am or 0,
					maxConsume = maxConsume,
				}
			end
		end
	end
	return snap
end

local function getActiveSnapshot()
	local snap = {}
	if fruitCmds and fruitCmds.GetActiveFruits then
		local ok, active = pcall(fruitCmds.GetActiveFruits)
		if ok and typeof(active) == "table" then
			for fruitId, stacks in pairs(active) do
				if typeof(stacks) == "table" then
					snap[fruitId] = {
						Normal = stacks.Normal and #stacks.Normal or 0,
						Shiny = stacks.Shiny and #stacks.Shiny or 0,
					}
				end
			end
		end
	end
	return snap
end

local fruitBefore = getFruitSnapshot()
local activeBefore = getActiveSnapshot()

w("Inventory:")
for uid, data in pairs(fruitBefore) do
	w(("  %s %s am=%d maxConsume=%d"):format(
		data.id, data.shiny and "Shiny" or "Normal", data.amount, data.maxConsume
	))
end
w("")
w("Active:")
for fruitId, data in pairs(activeBefore) do
	w(("  %s | Normal=%d Shiny=%d"):format(fruitId, data.Normal, data.Shiny))
end

flushSafe()

sep("FRUIT 2 — CONSUME 4 SIGNATURES WITH VERIFY")
if CONFIG.TEST_FRUIT and fruitCmds and fruitCmds.Consume then
	-- Pick first fruit
	local targetUid, targetData
	for uid, data in pairs(fruitBefore) do
		if data.amount > 0 then
			targetUid, targetData = uid, data
			break
		end
	end

	if targetUid then
		w(("Test fruit: %s %s | uid=%s | am=%d"):format(
			targetData.id, targetData.shiny and "Shiny" or "Normal",
			targetUid, targetData.amount
		))
		w("")

		local function verifyConsume(label, fn, ...)
			local before = getFruitSnapshot()
			local beforeActive = getActiveSnapshot()
			local beforeAmt = before[targetUid] and before[targetUid].amount or 0
			local beforeMax = before[targetUid] and before[targetUid].maxConsume or -1
			local beforeActiveAmt = beforeActive[targetData.id]
				and ((targetData.shiny and beforeActive[targetData.id].Shiny or beforeActive[targetData.id].Normal))
				or 0

			local ok, result = pcall(fn, ...)
			task.wait(0.6)

			local after = getFruitSnapshot()
			local afterActive = getActiveSnapshot()
			local afterAmt = after[targetUid] and after[targetUid].amount or 0
			local afterMax = after[targetUid] and after[targetUid].maxConsume or -1
			local afterActiveAmt = afterActive[targetData.id]
				and ((targetData.shiny and afterActive[targetData.id].Shiny or afterActive[targetData.id].Normal))
				or 0

			local inventoryChanged = afterAmt ~= beforeAmt
			local maxChanged = afterMax ~= beforeMax
			local activeChanged = afterActiveAmt ~= beforeActiveAmt

			w(("[%s] ok=%s result=%s"):format(label, tostring(ok), serialize(result)))
			w(("  inventory: %d -> %d (%s)"):format(
				beforeAmt, afterAmt, inventoryChanged and "CHANGED" or "same"
			))
			w(("  maxConsume: %d -> %d (%s)"):format(
				beforeMax, afterMax, maxChanged and "CHANGED" or "same"
			))
			w(("  active: %d -> %d (%s)"):format(
				beforeActiveAmt, afterActiveAmt, activeChanged and "CHANGED" or "same"
			))
			w("")
			task.wait(CONFIG.WAIT)
		end

		verifyConsume("1.uid+amount", fruitCmds.Consume, targetUid, CONFIG.FRUIT_AMOUNT)
		verifyConsume("2.entry+amount", fruitCmds.Consume, {
			id = targetData.id, sh = targetData.shiny, _am = targetData.amount,
		}, CONFIG.FRUIT_AMOUNT)
		verifyConsume("3.colon(uid)", function()
			return fruitCmds:Consume(targetUid)
		end)
		verifyConsume("4.colon(uid,amount)", function()
			return fruitCmds:Consume(targetUid, CONFIG.FRUIT_AMOUNT)
		end)
	else
		w("No fruit in inventory")
	end
end

flushSafe()

sep("FRUIT 3 — INVENTORY AFTER")
local fruitAfter = getFruitSnapshot()
local activeAfter = getActiveSnapshot()

w("Inventory:")
for uid, data in pairs(fruitAfter) do
	local before = fruitBefore[uid]
	local diff = before and (data.amount - before.amount) or data.amount
	w(("  %s %s am=%d (diff=%+d) maxConsume=%d"):format(
		data.id, data.shiny and "Shiny" or "Normal",
		data.amount, diff, data.maxConsume
	))
end
w("")
w("Active:")
for fruitId, data in pairs(activeAfter) do
	local before = activeBefore[fruitId]
	local diffN = data.Normal - (before and before.Normal or 0)
	local diffS = data.Shiny - (before and before.Shiny or 0)
	w(("  %s | Normal=%d (diff=%+d) Shiny=%d (diff=%+d)"):format(
		fruitId, data.Normal, diffN, data.Shiny, diffS
	))
end

flushSafe()

-- =====================================================
-- MERCHANT DEEP INSPECT
-- =====================================================
sep("MERCHANT 1 — Phase() + Directory.Merchants")
local dmMerchant = Modules.DiamondMountainMerchant
local currentPhase = nil
local currentCamp = nil

if typeof(dmMerchant) == "table" then
	local ok, phase = pcall(dmMerchant.Phase)
	w(("Phase() ok=%s"):format(tostring(ok)))
	if ok and typeof(phase) == "table" then
		currentPhase = phase
		for k, v in pairs(phase) do
			w(("  %s = %s"):format(tostring(k), serialize(v)))
		end
		if typeof(phase.Camp) == "number" then
			currentCamp = phase.Camp
		end
	end
end

w("")
w("-- Directory.Merchants:")
local merchDir = Modules.MerchantsDir
if typeof(merchDir) == "table" then
	for k, v in pairs(merchDir) do
		if typeof(v) == "table" then
			w(("  [%s]"):format(tostring(k)))
			for mk, mv in pairs(v) do
				if typeof(mv) ~= "function" then
					w(("    .%s = %s"):format(tostring(mk), serialize(mv)))
				end
			end
		end
	end
else
	w("  not loaded")
end

flushSafe()

sep("MERCHANT 2 — Camp Merchant Part FULL INSPECT")
local things2 = workspace:FindFirstChild("__THINGS")
local container2 = things2 and things2:FindFirstChild("__INSTANCE_CONTAINER")
local active2 = container2 and container2:FindFirstChild("Active")
local mountain2 = active2 and active2:FindFirstChild("DiamondMountain")
local camps2 = mountain2 and mountain2:FindFirstChild("Camps")

if camps2 and currentCamp then
	local campModel = camps2:FindFirstChild(tostring(currentCamp))
	w(("Camp %s: %s"):format(tostring(currentCamp), campModel and "found" or "NOT FOUND"))
	if campModel then
		local merchant = campModel:FindFirstChild("Merchant")
		if merchant then
			w(("Merchant: %s (%s)"):format(merchant:GetFullName(), merchant.ClassName))
			w("")
			w("-- Merchant ALL descendants:")
			for _, d in ipairs(merchant:GetDescendants()) do
				local extra = ""
				if d:IsA("BasePart") then
					extra = (" pos=%.1f,%.1f,%.1f"):format(
						d.Position.X, d.Position.Y, d.Position.Z
					)
				elseif d:IsA("ProximityPrompt") then
					extra = (" enabled=%s actionText=%q objectText=%q"):format(
						tostring(d.Enabled), tostring(d.ActionText), tostring(d.ObjectText)
					)
				elseif d:IsA("ClickDetector") then
					extra = (" MaxActivationDistance=%.0f"):format(d.MaxActivationDistance)
				elseif d:IsA("Attachment") then
					extra = (" WorldPos=%.1f,%.1f,%.1f"):format(
						d.WorldPosition.X, d.WorldPosition.Y, d.WorldPosition.Z
					)
				end
				w(("  %s (%s)%s"):format(d.Name, d.ClassName, extra))
			end

			w("")
			w("-- Merchant attributes:")
			for k, v in pairs(merchant:GetAttributes()) do
				w(("  %s = %s"):format(tostring(k), serialize(v)))
			end

			w("")
			w("-- Camp ALL descendants with prompts/detectors:")
			for _, d in ipairs(campModel:GetDescendants()) do
				if d:IsA("ProximityPrompt") or d:IsA("ClickDetector")
					or d:IsA("BillboardGui") or d:IsA("SurfaceGui")
					or d:IsA("TextButton") or d:IsA("ImageButton")
				then
					local extra = ""
					if d:IsA("ProximityPrompt") then
						extra = (" enabled=%s actionText=%q"):format(
							tostring(d.Enabled), tostring(d.ActionText)
						)
					end
					w(("  %s (%s)%s"):format(d:GetFullName(), d.ClassName, extra))
				end
			end
		else
			w("Merchant part NOT FOUND")
		end
	end
else
	w("Camps NOT FOUND or no current camp")
end

flushSafe()

sep("MERCHANT 3 — Merchant_GetOffers 4 ARG COMBOS")
if CONFIG.TEST_MERCHANT then
	local info = instanceInfo
	local camp = currentCamp
	local merchantId = "DiamondMountainMerchant"

	local function test(label, ...)
		local ok, result = invoke("Merchant_GetOffers", ...)
		w(("[%s] ok=%s result=%s"):format(label, tostring(ok), serialize(result)))
		task.wait(CONFIG.WAIT)
	end

	test("1.no-arg")
	if camp then test("2.camp", tostring(camp)) end
	test("3.merchantId", merchantId)
	if camp then test("4.merchantId,camp", merchantId, tostring(camp)) end
	if camp then test("5.camp,merchantId", tostring(camp), merchantId) end
end

flushSafe()

sep("MERCHANT 4 — TravelingMerchant_GetState 4 ARG COMBOS")
if CONFIG.TEST_MERCHANT then
	local camp = currentCamp
	local merchantId = "DiamondMountainMerchant"

	local function test(label, ...)
		local ok, result = invoke("TravelingMerchant_GetState", ...)
		w(("[%s] ok=%s result=%s"):format(label, tostring(ok), serialize(result)))
		task.wait(CONFIG.WAIT)
	end

	test("1.no-arg")
	if camp then test("2.camp", tostring(camp)) end
	test("3.merchantId", merchantId)
	if camp then test("4.merchantId,camp", merchantId, tostring(camp)) end
end

flushSafe()

sep("MERCHANT 5 — Teleport + Fire Prompts + GetState")
if CONFIG.TEST_MERCHANT and camps2 and currentCamp and root then
	local campModel = camps2:FindFirstChild(tostring(currentCamp))
	local merchant = campModel and campModel:FindFirstChild("Merchant")
	if merchant and merchant:IsA("BasePart") then
		local originalCFrame = root.CFrame
		root.CFrame = CFrame.new(merchant.Position)
		task.wait(0.6)
		w(("Teleported to merchant pos=%.1f,%.1f,%.1f"):format(
			merchant.Position.X, merchant.Position.Y, merchant.Position.Z
		))
		w(("Player now at: %.1f,%.1f,%.1f"):format(
			root.Position.X, root.Position.Y, root.Position.Z
		))

		-- Fire all prompts
		local promptCount = 0
		for _, d in ipairs(campModel:GetDescendants()) do
			if d:IsA("ProximityPrompt") then
				if not d.Enabled then pcall(function() d.Enabled = true end) end
				pcall(fireproximityprompt, d)
				promptCount += 1
				w(("Fired prompt: %s"):format(d:GetFullName()))
				task.wait(0.2)
			end
		end
		w(("Total prompts fired: %d"):format(promptCount))

		-- Fire click detectors
		local clickCount = 0
		for _, d in ipairs(campModel:GetDescendants()) do
			if d:IsA("ClickDetector") then
				pcall(fireclickdetector, d)
				clickCount += 1
				w(("Fired clickdetector: %s"):format(d:GetFullName()))
				task.wait(0.2)
			end
		end
		w(("Total clickdetectors fired: %d"):format(clickCount))

		-- MachineScreens_Get
		for _, id in ipairs({ tostring(currentCamp), "Merchant", "DiamondMountainMerchant", "TravelingMerchant" }) do
			pcall(fire, "MachineScreens_Get", id)
			task.wait(0.1)
		end

		-- GetState after
		local ok, state = invoke("TravelingMerchant_GetState")
		w(("GetState() after: ok=%s type=%s"):format(tostring(ok), typeof(state)))
		if ok and typeof(state) == "table" then
			for k, v in pairs(state) do
				w(("  %s = %s"):format(tostring(k), serialize(v)))
			end
		end

		-- GetOffers after
		local ok2, offers = invoke("Merchant_GetOffers", "DiamondMountainMerchant")
		w(("GetOffers(merchantId) after: ok=%s type=%s"):format(tostring(ok2), typeof(offers)))
		if ok2 and typeof(offers) == "table" then
			for k, v in pairs(offers) do
				w(("  %s = %s"):format(tostring(k), serialize(v)))
			end
		end

		pcall(function() root.CFrame = originalCFrame end)
	end
end

flushSafe()

sep("MERCHANT 6 — PURCHASE 8 ARG COMBOS")
if CONFIG.TEST_MERCHANT and CONFIG.TEST_MERCHANT_PURCHASE then
	local camp = currentCamp
	local merchantId = "DiamondMountainMerchant"

	local function test(label, remoteName, ...)
		local ok, result = invoke(remoteName, ...)
		w(("[%s] %s ok=%s result=%s"):format(
			label, remoteName, tostring(ok), serialize(result)
		))
		task.wait(CONFIG.WAIT)
	end

	-- TravelingMerchant_RequestPurchase
	test("1", "TravelingMerchant_RequestPurchase", "1")
	test("2", "TravelingMerchant_RequestPurchase", 1)
	test("3", "TravelingMerchant_RequestPurchase", "1", 1)
	if camp then
		test("4", "TravelingMerchant_RequestPurchase", tostring(camp), "1")
		test("5", "TravelingMerchant_RequestPurchase", tostring(camp), "1", 1)
	end
	test("6", "TravelingMerchant_RequestPurchase", merchantId, "1")
	test("7", "TravelingMerchant_RequestPurchase", merchantId, "1", 1)
	test("8", "TravelingMerchant_RequestPurchase", merchantId, tostring(camp or 1), "1")

	w("")
	w("-- Merchant_RequestPurchase:")
	test("M1", "Merchant_RequestPurchase", "1")
	test("M2", "Merchant_RequestPurchase", 1)
	test("M3", "Merchant_RequestPurchase", "1", 1)
	test("M4", "Merchant_RequestPurchase", merchantId, "1")
	test("M5", "Merchant_RequestPurchase", merchantId, "1", 1)
	if camp then
		test("M6", "Merchant_RequestPurchase", tostring(camp), "1")
		test("M7", "Merchant_RequestPurchase", tostring(camp), "1", 1)
	end
end

flushSafe()

sep("MERCHANT 7 — DiamondMountainCmds Feature + Networking")
local dmCmds = Modules.DiamondMountainCmds
if typeof(dmCmds) == "table" then
	w("DiamondMountainCmds:", typeof(dmCmds))
	w("  FEATURES:", dmCmds.FEATURES and table.concat(dmCmds.FEATURES, ",") or "nil")
	w("")

	if typeof(dmCmds.Feature) == "function" then
		local ok, feature = pcall(dmCmds.Feature, "Merchant")
		w(("Feature('Merchant') ok=%s type=%s"):format(tostring(ok), typeof(feature)))
		if ok and typeof(feature) == "table" then
			for k, v in pairs(feature) do
				w(("  .%s = %s"):format(tostring(k), typeof(v)))
			end
		end
	end

	w("")
	if typeof(dmCmds.Networking) == "function" then
		local ok, networking = pcall(dmCmds.Networking)
		w(("Networking() ok=%s type=%s"):format(tostring(ok), typeof(networking)))
		if ok and typeof(networking) == "table" then
			for k, v in pairs(networking) do
				w(("  .%s = %s"):format(tostring(k), typeof(v)))
			end
		end
	end

	w("")
	if typeof(dmCmds.Instance) == "function" then
		local ok, inst = pcall(dmCmds.Instance)
		w(("Instance() ok=%s type=%s"):format(tostring(ok), typeof(inst)))
		if ok and typeof(inst) == "table" then
			for k, v in pairs(inst) do
				w(("  .%s = %s"):format(tostring(k), typeof(v)))
			end
		end
	end
end

flushSafe()

sep("MERCHANT 8 — DiamondMountainMerchant Upvalues")
if typeof(dmMerchant) == "table" then
	for _, fnName in ipairs({ "Phase", "Offset", "CampOf", "VisitAt", "NextVisitAt", "MoveSeconds", "Folder", "Stop" }) do
		local fn = dmMerchant[fnName]
		if typeof(fn) == "function" then
			w(("-- %s:"):format(fnName))
			local info = debug.getinfo(fn)
			w(("  params=%d nups=%d"):format(
				info and info.numparams or 0, info and info.nups or 0
			))
			local ok, ups = pcall(debug.getupvalues, fn)
			if ok and typeof(ups) == "table" then
				for i, uv in pairs(ups) do
					local tuv = typeof(uv)
					if tuv == "table" then
						local n = 0
						for _ in pairs(uv) do n += 1 end
						w(("    up[%d] = table(%d)"):format(i, n))
					elseif tuv == "Instance" then
						w(("    up[%d] = %s"):format(i, uv:GetFullName()))
					else
						w(("    up[%d] = %s"):format(i, serialize(uv)))
					end
				end
			end
		end
	end
end

flushSafe()

sep("MERCHANT 9 — Folder() children")
if typeof(dmMerchant) == "table" and typeof(dmMerchant.Folder) == "function" then
	local ok, folder = pcall(dmMerchant.Folder)
	if ok and typeof(folder) == "Instance" then
		w(("Folder(): %s"):format(folder:GetFullName()))
		w("Children:")
		for _, child in ipairs(folder:GetChildren()) do
			local extra = ""
			if child:IsA("BasePart") then
				extra = (" pos=%.1f,%.1f,%.1f"):format(
					child.Position.X, child.Position.Y, child.Position.Z
				)
			end
			w(("  %s (%s)%s"):format(child.Name, child.ClassName, extra))
		end
		w("Descendants with 'merchant':")
		for _, d in ipairs(folder:GetDescendants()) do
			if d.Name:lower():find("merchant", 1, true) then
				w(("  %s (%s)"):format(d:GetFullName(), d.ClassName))
			end
		end
	end
end

flushSafe()

-- -----------------------------------------------------
-- SUMMARY
-- -----------------------------------------------------
sep("SUMMARY")
w("Diagnostic complete.")
w("File:", DIAG_PATH)
w("Lines:", #lines)
w("")
w("Flag valid positions:", #workingPositions)
w("Flag consume tested:", CONFIG.TEST_FLAG_CONSUME and #workingPositions > 0)
w("Fruit tested:", CONFIG.TEST_FRUIT)
w("Merchant phase camp:", tostring(currentCamp))

flush()
