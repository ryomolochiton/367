-- =====================================================
-- VRT DIAGNOSTIC v4.1 — MERCHANT PRECISE TELEPORT
-- Tele chính xác vào Merchant part + verify distance + retry
-- Save -> VRT/VRT_Diag4.txt
-- CHẠY KHI ĐANG Ở TRONG DIAMOND MOUNTAIN
-- =====================================================

local CONFIG = {
	TEST_FLAG = true,
	TEST_FLAG_ALL_SIGNATURES = true,
	TEST_FLAG_ALL_TYPES = true,
	FLAG_SIGNATURE_PROBE = "Coins Flag",

	TEST_FRUIT = true,
	TEST_FRUIT_ALL_SIGNATURES = true,
	TEST_FRUIT_ALL_TYPES = true,
	FRUIT_AMOUNT = 1,

	TEST_EGG = true,
	TEST_EGG_BATCH = true,
	TEST_EGG_LOOP = true,
	EGG_BATCH_MAX = 58,
	EGG_LOOP_MAX = 5,

	TEST_MERCHANT = true,
	TEST_MERCHANT_PURCHASE = true,
	MERCHANT_PURCHASE_IDS = { "1", "2", "3", "4", "5", "6", "7", "8" },

	-- Teleport verify threshold (studs)
	TELEPORT_VERIFY_DIST = 8,
	TELEPORT_RETRY = 3,

	MAX_TABLE_ENTRIES = 40,
	MAX_DEPTH = 4,
	WAIT_BETWEEN_TESTS = 0.4,
}

local playersService = game:GetService("Players")
local replicatedStorage = game:GetService("ReplicatedStorage")

local localPlayer = playersService.LocalPlayer
local libraryFolder = replicatedStorage:WaitForChild("Library")
local clientFolder = libraryFolder:WaitForChild("Client")
local utilFolder = libraryFolder:FindFirstChild("Util")
local networkFolder = replicatedStorage:FindFirstChild("Network")

local DIAG_FOLDER = "VRT"
local DIAG_PATH = "VRT/VRT_Diag4.txt"

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

local function tryCall(label, fn, ...)
	local ok, result = pcall(fn, ...)
	w(("[%s] ok=%s | result=%s"):format(label, tostring(ok), serialize(result)))
	return ok, result
end

-- -----------------------------------------------------
-- PRECISE TELEPORT
-- -----------------------------------------------------
local function teleportExact(targetPos, label)
	local root = getRoot()
	if not root then return false, "no root" end
	if not targetPos then return false, "no target" end

	local before = root.Position
	local humanoid = localPlayer.Character and localPlayer.Character:FindFirstChildOfClass("Humanoid")

	for attempt = 1, CONFIG.TELEPORT_RETRY do
		-- Method 1: CFrame trực tiếp
		root.CFrame = CFrame.new(targetPos)

		-- Method 2: PivotTo (nếu có)
		if localPlayer.Character then
			pcall(function()
				localPlayer.Character:PivotTo(CFrame.new(targetPos))
			end)
		end

		-- Method 3: Humanoid MoveTo
		if humanoid then
			pcall(function() humanoid:MoveTo(targetPos) end)
		end

		task.wait(0.3)

		local after = root.Position
		local dist = (after - targetPos).Magnitude
		w(("    [%s] attempt %d: %.1f,%.1f,%.1f -> %.1f,%.1f,%.1f | dist=%.1f"):format(
			label, attempt,
			before.X, before.Y, before.Z,
			after.X, after.Y, after.Z,
			dist
		))

		if dist < CONFIG.TELEPORT_VERIFY_DIST then
			return true, dist
		end
		task.wait(0.2)
	end

	return false, "verify failed"
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
w("")
w("CONFIG:")
for k, v in pairs(CONFIG) do
	if typeof(v) ~= "table" then
		w(("  %s = %s"):format(tostring(k), tostring(v)))
	end
end

local root = getRoot()
if root then
	local p = root.Position
	w(("Position: %.1f, %.1f, %.1f"):format(p.X, p.Y, p.Z))
else
	w("Position: no character")
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
	DiamondMountainMerchant = safeRequire(utilFolder and utilFolder:FindFirstChild("DiamondMountainMerchant")),
	MerchantUtil = safeRequire(utilFolder and utilFolder:FindFirstChild("MerchantUtil")),
	TravelingMerchantUtil = safeRequire(utilFolder and utilFolder:FindFirstChild("TravelingMerchantUtil")),
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

local function getInventoryFlagEntries()
	local entries = {}
	local save = getSave()
	if not save or typeof(save.Inventory) ~= "table" then return entries end
	for bucketName, bucket in pairs(save.Inventory) do
		if typeof(bucket) == "table" then
			for uid, entry in pairs(bucket) do
				if typeof(entry) == "table" and typeof(entry.id) == "string" then
					if entry.id:lower():find("flag", 1, true) and (entry._am or 0) > 0 then
						table.insert(entries, {
							uid = uid, id = entry.id, amount = entry._am,
							bucket = bucketName,
						})
					end
				end
			end
		end
	end
	return entries
end

local function getAllFruits()
	local fruits = {}
	local save = getSave()
	if not save or typeof(save.Inventory) ~= "table" or typeof(save.Inventory.Fruit) ~= "table" then
		return fruits
	end
	for uid, entry in pairs(save.Inventory.Fruit) do
		if typeof(entry) == "table" and (entry._am or 0) > 0 then
			table.insert(fruits, {
				uid = uid, id = entry.id, amount = entry._am,
				shiny = entry.sh == true,
			})
		end
	end
	return fruits
end

-- -----------------------------------------------------
-- INSTANCE INFO
-- -----------------------------------------------------
sep("INSTANCE INFO")
local instanceInfo = getInstanceInfo()
w("GetCurrentInstanceInfo():", serialize(instanceInfo))
if Modules.MapCmds and Modules.MapCmds.GetCurrentZone then
	tryCall("GetCurrentZone", Modules.MapCmds.GetCurrentZone)
end

flushSafe()

-- =====================================================
-- FLAG
-- =====================================================
sep("FLAG 1 — Module Signatures")
local flagCmds = Modules.FlexibleFlagCmds
local zoneFlagCmds = Modules.ZoneFlagCmds
w("FlexibleFlagCmds:", typeof(flagCmds))
w("ZoneFlagCmds:", typeof(zoneFlagCmds))

if typeof(flagCmds) == "table" then
	for _, name in ipairs({ "Consume", "ActivateFlag", "DeactivateFlag", "GetActiveFlag", "GetMaxPlace", "GetMaxPlaceAutomaticContext", "SpatialQuery", "HasActiveFlag", "PlayerHasActiveFlag" }) do
		local fn = flagCmds[name]
		if typeof(fn) == "function" then
			local info = debug.getinfo(fn)
			w(("  FlexibleFlagCmds.%s | params=%d vararg=%s nups=%d"):format(
				name, info and info.numparams or 0,
				tostring(info and info.is_vararg), info and info.nups or 0
			))
		else
			w(("  FlexibleFlagCmds.%s = %s"):format(name, typeof(fn)))
		end
	end
end

if typeof(zoneFlagCmds) == "table" then
	for _, name in ipairs({ "Consume", "ActivateFlag", "DeactivateFlag", "GetActiveFlag", "GetActiveFlags", "GetMaxPlace", "HasActiveFlag", "PlayerHasActiveFlag" }) do
		local fn = zoneFlagCmds[name]
		if typeof(fn) == "function" then
			local info = debug.getinfo(fn)
			w(("  ZoneFlagCmds.%s | params=%d vararg=%s nups=%d"):format(
				name, info and info.numparams or 0,
				tostring(info and info.is_vararg), info and info.nups or 0
			))
		else
			w(("  ZoneFlagCmds.%s = %s"):format(name, typeof(fn)))
		end
	end
end

sep("FLAG 2 — Current State")
if typeof(flagCmds) == "table" then
	if flagCmds.GetActiveFlag then
		tryCall("FlexibleFlagCmds.GetActiveFlag()", flagCmds.GetActiveFlag)
	end
	if flagCmds.HasActiveFlag then
		tryCall("FlexibleFlagCmds.HasActiveFlag('Coins Flag')", flagCmds.HasActiveFlag, "Coins Flag")
	end
	if flagCmds.GetMaxPlaceAutomaticContext and root then
		tryCall("GetMaxPlaceAutomaticContext(pos)", flagCmds.GetMaxPlaceAutomaticContext, root.Position)
	end
	if flagCmds.SpatialQuery and root then
		tryCall("SpatialQuery(pos)", flagCmds.SpatialQuery, root.Position)
	end
end
if typeof(zoneFlagCmds) == "table" then
	if zoneFlagCmds.GetActiveFlag then
		tryCall("ZoneFlagCmds.GetActiveFlag()", zoneFlagCmds.GetActiveFlag)
	end
	if zoneFlagCmds.GetActiveFlags then
		tryCall("ZoneFlagCmds.GetActiveFlags()", zoneFlagCmds.GetActiveFlags)
	end
end

sep("FLAG 3 — Inventory")
local flagEntries = getInventoryFlagEntries()
w(("Found %d flag entries"):format(#flagEntries))
for _, e in ipairs(flagEntries) do
	w(("  [%s] %q am=%d"):format(e.bucket, e.id, e.amount))
end

flushSafe()

sep("FLAG 4 — 9 SIGNATURE PROBE")
local workingSignature = nil
local signatureResults = {}

if CONFIG.TEST_FLAG and CONFIG.TEST_FLAG_ALL_SIGNATURES then
	local flagId = CONFIG.FLAG_SIGNATURE_PROBE
	w(("Probe flag: %q amount=1"):format(flagId))
	w("")

	local info = instanceInfo
	local instanceId = info and info.InstanceId
	local areaId = info and info.AreaId
	local zoneNumber = info and info.ZoneNumber
	local pos = root and root.Position

	w("Context:")
	w("  instanceId:", tostring(instanceId))
	w("  areaId:", tostring(areaId))
	w("  zoneNumber:", tostring(zoneNumber))
	w("  pos:", serialize(pos))
	w("")

	local function test(label, fn, ...)
		local ok, result = pcall(fn, ...)
		local success = ok and result ~= false
		table.insert(signatureResults, { label = label, ok = ok, result = result, success = success })
		w(("[%s] ok=%s result=%s"):format(label, tostring(ok), serialize(result)))
		task.wait(CONFIG.WAIT_BETWEEN_TESTS)
		if success and not workingSignature then
			workingSignature = label
		end
		return success
	end

	if typeof(flagCmds) == "table" and flagCmds.Consume then
		if instanceId then
			test("1.flex-instanceId", flagCmds.Consume, flagId, 1, instanceId)
		end
		if areaId then
			test("2.flex-areaId", flagCmds.Consume, flagId, 1, areaId)
		end
		if info then
			test("3.flex-info", flagCmds.Consume, flagId, 1, info)
		end
		if zoneNumber then
			test("4.flex-zone", flagCmds.Consume, flagId, 1, zoneNumber)
		end
		if pos then
			test("4b.flex-pos", flagCmds.Consume, flagId, 1, pos)
		end
		test("4c.flex-2args", flagCmds.Consume, flagId, 1)
	end

	if typeof(zoneFlagCmds) == "table" and zoneFlagCmds.Consume then
		if instanceId then
			test("5.zone-instanceId", zoneFlagCmds.Consume, flagId, 1, instanceId)
		end
		if areaId then
			test("6.zone-areaId", zoneFlagCmds.Consume, flagId, 1, areaId)
		end
		if info then
			test("7.zone-info", zoneFlagCmds.Consume, flagId, 1, info)
		end
		test("7b.zone-2args", zoneFlagCmds.Consume, flagId, 1)
	end

	if instanceId then
		test("8.remote-flex-instanceId", function()
			return invoke("FlexibleFlags_Consume", flagId, 1, instanceId)
		end)
		test("9.remote-flags-instanceId", function()
			return invoke("Flags: Consume", flagId, 1, instanceId)
		end)
	end
	test("10.remote-flex-2args", function()
		return invoke("FlexibleFlags_Consume", flagId, 1)
	end)
	test("11.remote-flags-2args", function()
		return invoke("Flags: Consume", flagId, 1)
	end)

	w("")
	w("-- Signature summary:")
	local successCount = 0
	for _, r in ipairs(signatureResults) do
		w(("  %-30s %s"):format(r.label, r.success and "SUCCESS" or "FAIL"))
		if r.success then successCount += 1 end
	end
	w(("  Total success: %d/%d"):format(successCount, #signatureResults))
	w(("  First working: %s"):format(tostring(workingSignature)))
end

flushSafe()

sep("FLAG 5 — ALL FLAGS × WORKING SIGNATURE")
if CONFIG.TEST_FLAG and CONFIG.TEST_FLAG_ALL_TYPES and workingSignature then
	w(("Using signature: %s"):format(workingSignature))
	w("")

	local info = instanceInfo
	local instanceId = info and info.InstanceId
	local areaId = info and info.AreaId
	local zoneNumber = info and info.ZoneNumber
	local pos = root and root.Position

	local function runSignature(flagId, amount)
		if workingSignature == "1.flex-instanceId" then
			return pcall(flagCmds.Consume, flagId, amount, instanceId)
		elseif workingSignature == "2.flex-areaId" then
			return pcall(flagCmds.Consume, flagId, amount, areaId)
		elseif workingSignature == "3.flex-info" then
			return pcall(flagCmds.Consume, flagId, amount, info)
		elseif workingSignature == "4.flex-zone" then
			return pcall(flagCmds.Consume, flagId, amount, zoneNumber)
		elseif workingSignature == "4b.flex-pos" then
			return pcall(flagCmds.Consume, flagId, amount, pos)
		elseif workingSignature == "4c.flex-2args" then
			return pcall(flagCmds.Consume, flagId, amount)
		elseif workingSignature == "5.zone-instanceId" then
			return pcall(zoneFlagCmds.Consume, flagId, amount, instanceId)
		elseif workingSignature == "6.zone-areaId" then
			return pcall(zoneFlagCmds.Consume, flagId, amount, areaId)
		elseif workingSignature == "7.zone-info" then
			return pcall(zoneFlagCmds.Consume, flagId, amount, info)
		elseif workingSignature == "7b.zone-2args" then
			return pcall(zoneFlagCmds.Consume, flagId, amount)
		elseif workingSignature == "8.remote-flex-instanceId" then
			return invoke("FlexibleFlags_Consume", flagId, amount, instanceId)
		elseif workingSignature == "9.remote-flags-instanceId" then
			return invoke("Flags: Consume", flagId, amount, instanceId)
		elseif workingSignature == "10.remote-flex-2args" then
			return invoke("FlexibleFlags_Consume", flagId, amount)
		elseif workingSignature == "11.remote-flags-2args" then
			return invoke("Flags: Consume", flagId, amount)
		end
		return false, "unknown signature"
	end

	for _, e in ipairs(flagEntries) do
		local ok, result = runSignature(e.id, 1)
		w(("[%s] ok=%s result=%s"):format(e.id, tostring(ok), serialize(result)))
		task.wait(CONFIG.WAIT_BETWEEN_TESTS)
	end
end

flushSafe()

-- =====================================================
-- FRUIT
-- =====================================================
sep("FRUIT 1 — Module Signatures")
local fruitCmds = Modules.FruitCmds
w("FruitCmds:", typeof(fruitCmds))
if typeof(fruitCmds) == "table" then
	for _, name in ipairs({ "Consume", "GetActiveFruits", "GetMaxConsume", "ComputeFruitQueueLimit", "ComputeFruitPowerLimit", "ComputeDuration", "GetPower" }) do
		local fn = fruitCmds[name]
		if typeof(fn) == "function" then
			local info = debug.getinfo(fn)
			w(("  FruitCmds.%s | params=%d vararg=%s nups=%d"):format(
				name, info and info.numparams or 0,
				tostring(info and info.is_vararg), info and info.nups or 0
			))
		else
			w(("  FruitCmds.%s = %s"):format(name, typeof(fn)))
		end
	end
end

sep("FRUIT 2 — Queue / Power / Active")
if typeof(fruitCmds) == "table" then
	if fruitCmds.ComputeFruitQueueLimit then
		tryCall("ComputeFruitQueueLimit", fruitCmds.ComputeFruitQueueLimit)
	end
	if fruitCmds.ComputeFruitPowerLimit then
		tryCall("ComputeFruitPowerLimit", fruitCmds.ComputeFruitPowerLimit)
	end
	if fruitCmds.GetActiveFruits then
		local ok, active = pcall(fruitCmds.GetActiveFruits)
		w(("GetActiveFruits ok=%s type=%s"):format(tostring(ok), typeof(active)))
		if ok and typeof(active) == "table" then
			for fruitId, stacks in pairs(active) do
				if typeof(stacks) == "table" then
					local normal = stacks.Normal and #stacks.Normal or 0
					local shiny = stacks.Shiny and #stacks.Shiny or 0
					w(("  %s | Normal=%d Shiny=%d"):format(tostring(fruitId), normal, shiny))
				end
			end
		end
	end
end

sep("FRUIT 3 — Inventory + GetMaxConsume")
local allFruits = getAllFruits()
w(("Found %d fruit entries"):format(#allFruits))
for _, f in ipairs(allFruits) do
	local maxConsume = "n/a"
	if fruitCmds and fruitCmds.GetMaxConsume then
		local ok, value = pcall(fruitCmds.GetMaxConsume, f.uid)
		maxConsume = ok and tostring(value) or ("err: " .. tostring(value))
	end
	w(("  uid=%s id=%q shiny=%s am=%d | GetMaxConsume=%s"):format(
		tostring(f.uid), tostring(f.id), tostring(f.shiny),
		f.amount, maxConsume
	))
end

flushSafe()

sep("FRUIT 4 — 4 SIGNATURE PROBE")
local workingFruitSignature = nil
local fruitSignatureResults = {}

if CONFIG.TEST_FRUIT and CONFIG.TEST_FRUIT_ALL_SIGNATURES and #allFruits > 0 then
	local probe = allFruits[1]
	w(("Probe fruit: %q (%s) amount=%d"):format(
		tostring(probe.id), probe.shiny and "Shiny" or "Normal", CONFIG.FRUIT_AMOUNT
	))
	w("")

	local function testFruit(label, fn, ...)
		local ok, result = pcall(fn, ...)
		local success = ok
		table.insert(fruitSignatureResults, { label = label, ok = ok, result = result, success = success })
		w(("[%s] ok=%s result=%s"):format(label, tostring(ok), serialize(result)))
		task.wait(CONFIG.WAIT_BETWEEN_TESTS)
		if success and not workingFruitSignature then
			workingFruitSignature = label
		end
		return success
	end

	if fruitCmds and fruitCmds.Consume then
		testFruit("1.uid+amount", fruitCmds.Consume, probe.uid, CONFIG.FRUIT_AMOUNT)
		testFruit("2.entry+amount", fruitCmds.Consume, {
			id = probe.id, sh = probe.shiny, _am = probe.amount,
		}, CONFIG.FRUIT_AMOUNT)
		testFruit("3.colon(uid)", function()
			return fruitCmds:Consume(probe.uid)
		end)
		testFruit("4.colon(uid,amount)", function()
			return fruitCmds:Consume(probe.uid, CONFIG.FRUIT_AMOUNT)
		end)
	end

	w("")
	w("-- Fruit signature summary:")
	for _, r in ipairs(fruitSignatureResults) do
		w(("  %-30s %s"):format(r.label, r.success and "SUCCESS" or "FAIL"))
	end
	w(("  First working: %s"):format(tostring(workingFruitSignature)))
end

flushSafe()

sep("FRUIT 5 — ALL FRUITS × WORKING SIGNATURE")
if CONFIG.TEST_FRUIT and CONFIG.TEST_FRUIT_ALL_TYPES and workingFruitSignature then
	w(("Using signature: %s"):format(workingFruitSignature))
	w("")

	local function runFruitSignature(probe, amount)
		if workingFruitSignature == "1.uid+amount" then
			return pcall(fruitCmds.Consume, probe.uid, amount)
		elseif workingFruitSignature == "2.entry+amount" then
			return pcall(fruitCmds.Consume, {
				id = probe.id, sh = probe.shiny, _am = probe.amount,
			}, amount)
		elseif workingFruitSignature == "3.colon(uid)" then
			return pcall(function() return fruitCmds:Consume(probe.uid) end)
		elseif workingFruitSignature == "4.colon(uid,amount)" then
			return pcall(function() return fruitCmds:Consume(probe.uid, amount) end)
		end
		return false, "unknown"
	end

	for _, f in ipairs(allFruits) do
		local ok, result = runFruitSignature(f, CONFIG.FRUIT_AMOUNT)
		w(("[%s %s] ok=%s result=%s"):format(
			f.id, f.shiny and "Shiny" or "Normal", tostring(ok), serialize(result)
		))
		task.wait(CONFIG.WAIT_BETWEEN_TESTS)
	end
end

flushSafe()

-- =====================================================
-- CUSTOM EGG
-- =====================================================
sep("EGG 1 — CustomEggsCmds.All()")
local customCmds = Modules.CustomEggsCmds
w("CustomEggsCmds:", typeof(customCmds))

local hatchableEggs = {}
if typeof(customCmds) == "table" and customCmds.All then
	local ok, list = pcall(customCmds.All)
	w(("All() ok=%s type=%s"):format(tostring(ok), typeof(list)))
	if ok and typeof(list) == "table" then
		local total, hatchable = 0, 0
		local rootPos = root and root.Position
		for uid, egg in pairs(list) do
			total += 1
			if typeof(egg) == "table" then
				local isHatch = egg._hatchable == true
				local name = egg._id or egg.name or uid
				local pos = egg._position
				local dist = "n/a"
				if pos and rootPos then
					dist = ("%.0f"):format((pos - rootPos).Magnitude)
				end
				if isHatch then
					hatchable += 1
					table.insert(hatchableEggs, {
						uid = uid, name = name, pos = pos,
						dist = dist, distNum = pos and rootPos and (pos - rootPos).Magnitude or math.huge,
					})
					w(("  [HATCH] %s | %s | dist=%s | pos=%s"):format(
						tostring(name), tostring(uid), dist, serialize(pos)
					))
				else
					w(("  [no]    %s | %s | dist=%s"):format(
						tostring(name), tostring(uid), dist
					))
				end
			end
		end
		w(("  total=%d hatchable=%d"):format(total, hatchable))
	end
end

sep("EGG 2 — GetMaxHatch")
local eggCmds = Modules.EggCmds
local maxHatch = 1
if eggCmds and eggCmds.GetMaxHatch then
	local ok, value = tryCall("GetMaxHatch()", eggCmds.GetMaxHatch)
	if ok and typeof(value) == "number" and value > 0 then
		maxHatch = value
	end
end
w("Max hatch:", maxHatch)

flushSafe()

sep("EGG 3 — HATCH TEST ALL EGGS")
if CONFIG.TEST_EGG and #hatchableEggs > 0 then
	table.sort(hatchableEggs, function(a, b)
		return a.distNum < b.distNum
	end)

	for _, egg in ipairs(hatchableEggs) do
		w("")
		w(("=== Egg: %s | %s | dist=%s"):format(egg.name, egg.uid, egg.dist))

		if egg.pos and root then
			local ok, dist = teleportExact(egg.pos, "egg-" .. egg.name)
			if ok then
				w(("  Teleport OK (dist=%.1f)"):format(dist))
			else
				w(("  Teleport FAIL: %s"):format(tostring(dist)))
			end
		end

		if CONFIG.TEST_EGG_BATCH then
			local batchMax = math.min(CONFIG.EGG_BATCH_MAX, maxHatch)
			w(("  -- Batch: CustomEggs_Hatch(%s, %d)"):format(egg.uid, batchMax))
			local ok, result = invoke("CustomEggs_Hatch", egg.uid, batchMax)
			w(("    ok=%s result=%s"):format(tostring(ok), serialize(result)))
			task.wait(1)
		end

		if CONFIG.TEST_EGG_LOOP then
			w(("  -- Loop: CustomEggs_Hatch(%s) x %d"):format(egg.uid, CONFIG.EGG_LOOP_MAX))
			local total = 0
			for i = 1, CONFIG.EGG_LOOP_MAX do
				local ok, result = invoke("CustomEggs_Hatch", egg.uid)
				w(("    [%d] ok=%s result=%s"):format(i, tostring(ok), serialize(result)))
				if ok then total += 1 else break end
				task.wait(0.15)
			end
			w(("    total: %d/%d"):format(total, CONFIG.EGG_LOOP_MAX))
		end

		flushSafe()
	end
end

flushSafe()

-- =====================================================
-- MERCHANT — PRECISE TELEPORT
-- =====================================================
sep("MERCHANT 1 — DiamondMountainMerchant Util")
local dmMerchant = Modules.DiamondMountainMerchant
w("DiamondMountainMerchant:", typeof(dmMerchant))

local currentPhase = nil
local currentCamp = nil
local visitAt = nil

if typeof(dmMerchant) == "table" then
	w("  CYCLE:", dmMerchant.CYCLE and table.concat(dmMerchant.CYCLE, ",") or "nil")
	w("  REACH:", tostring(dmMerchant.REACH))
	w("  TRAVEL_SECONDS:", tostring(dmMerchant.TRAVEL_SECONDS))
	w("  DEFAULT_MOVE:", tostring(dmMerchant.DEFAULT_MOVE))
	w("  OFFSET_ATTR:", tostring(dmMerchant.OFFSET_ATTR))
	w("")

	if typeof(dmMerchant.Phase) == "function" then
		local ok, value = pcall(dmMerchant.Phase)
		w(("  Phase() ok=%s value=%s"):format(tostring(ok), serialize(value)))
		if ok then currentPhase = value end
	end
	if typeof(dmMerchant.Offset) == "function" then
		local ok, value = pcall(dmMerchant.Offset)
		w(("  Offset() ok=%s value=%s"):format(tostring(ok), serialize(value)))
	end
	if typeof(dmMerchant.MoveSeconds) == "function" then
		local ok, value = pcall(dmMerchant.MoveSeconds)
		w(("  MoveSeconds() ok=%s value=%s"):format(tostring(ok), serialize(value)))
	end
	if typeof(dmMerchant.Folder) == "function" then
		local ok, value = pcall(dmMerchant.Folder)
		w(("  Folder() ok=%s value=%s"):format(tostring(ok), serialize(value)))
	end

	if currentPhase ~= nil then
		if typeof(dmMerchant.CampOf) == "function" then
			local ok, value = pcall(dmMerchant.CampOf, currentPhase)
			w(("  CampOf(%s) ok=%s value=%s"):format(
				tostring(currentPhase), tostring(ok), serialize(value)
			))
			if ok then currentCamp = value end
		end
		if typeof(dmMerchant.VisitAt) == "function" then
			local ok, value = pcall(dmMerchant.VisitAt, currentPhase)
			w(("  VisitAt(%s) ok=%s value=%s"):format(
				tostring(currentPhase), tostring(ok), serialize(value)
			))
			if ok then visitAt = value end
		end
		if typeof(dmMerchant.NextVisitAt) == "function" then
			local ok, value = pcall(dmMerchant.NextVisitAt, currentPhase)
			w(("  NextVisitAt(%s) ok=%s value=%s"):format(
				tostring(currentPhase), tostring(ok), serialize(value)
			))
		end
	end

	w("")
	w("-- Test all phases 1-10:")
	for i = 1, 10 do
		if typeof(dmMerchant.CampOf) == "function" then
			local ok, camp = pcall(dmMerchant.CampOf, i)
			local ok2, visit = false, nil
			if typeof(dmMerchant.VisitAt) == "function" then
				ok2, visit = pcall(dmMerchant.VisitAt, i)
			end
			w(("  phase=%d | CampOf=%s | VisitAt=%s"):format(
				i, tostring(camp), tostring(visit)
			))
		end
	end
end

flushSafe()

sep("MERCHANT 2 — Camp Structure + All Merchant Parts")
local things = workspace:FindFirstChild("__THINGS")
local container = things and things:FindFirstChild("__INSTANCE_CONTAINER")
local active = container and container:FindFirstChild("Active")
local mountain = active and active:FindFirstChild("DiamondMountain")
local camps = mountain and mountain:FindFirstChild("Camps")

local campInfo = {}

if camps then
	for _, camp in ipairs(camps:GetChildren()) do
		w("")
		w(("=== Camp %s (%s)"):format(camp.Name, camp.ClassName))
		local entry = { name = camp.Name, model = camp, candidates = {} }

		for _, child in ipairs(camp:GetChildren()) do
			local extra = ""
			if child:IsA("BasePart") then
				extra = (" pos=%.1f,%.1f,%.1f"):format(
					child.Position.X, child.Position.Y, child.Position.Z
				)
			end
			w(("  %s (%s)%s"):format(child.Name, child.ClassName, extra))

			-- Collect merchant-related candidates
			if child.Name:lower():find("merchant", 1, true) then
				if child:IsA("BasePart") then
					table.insert(entry.candidates, {
						pos = child.Position,
						label = child.Name .. " (BasePart)",
						instance = child,
					})
				elseif child:IsA("Model") then
					local part = child:FindFirstChildWhichIsA("BasePart", true)
					if part then
						table.insert(entry.candidates, {
							pos = part.Position,
							label = child.Name .. " (Model first part)",
							instance = part,
						})
					end
				end
			end
		end

		-- Deep search for merchant + attachments
		for _, d in ipairs(camp:GetDescendants()) do
			if d.Name:lower():find("merchant", 1, true) then
				if d:IsA("Attachment") then
					table.insert(entry.candidates, {
						pos = d.WorldPosition,
						label = "Attachment " .. d.Name,
						instance = d,
					})
					w(("  [ATTACHMENT] %s pos=%.1f,%.1f,%.1f"):format(
						d:GetFullName(),
						d.WorldPosition.X, d.WorldPosition.Y, d.WorldPosition.Z
					))
				elseif d:IsA("Seat") or d:IsA("VehicleSeat") then
					table.insert(entry.candidates, {
						pos = d.Position,
						label = "Seat " .. d.Name,
						instance = d,
					})
				elseif d:IsA("ProximityPrompt") then
					w(("  [PROMPT] %s | enabled=%s actionText=%q objectText=%q"):format(
						d:GetFullName(), tostring(d.Enabled),
						tostring(d.ActionText), tostring(d.ObjectText)
					))
				end
			end
		end

		-- Also add Spawn as fallback
		local spawnPart = camp:FindFirstChild("Spawn")
		if spawnPart and spawnPart:IsA("BasePart") then
			table.insert(entry.candidates, {
				pos = spawnPart.Position,
				label = "Spawn (fallback)",
				instance = spawnPart,
			})
		end

		table.insert(campInfo, entry)
	end
else
	w("Camps NOT FOUND")
end

flushSafe()

sep("MERCHANT 3 — Remotes + GetState")
if Modules.Network then
	local getState = networkFolder:FindFirstChild("TravelingMerchant_GetState")
	local purchase = networkFolder:FindFirstChild("TravelingMerchant_RequestPurchase")
	local merchantOffers = networkFolder:FindFirstChild("Merchant_GetOffers")
	local merchantPurchase = networkFolder:FindFirstChild("Merchant_RequestPurchase")
	w("TravelingMerchant_GetState:", tostring(getState ~= nil))
	w("TravelingMerchant_RequestPurchase:", tostring(purchase ~= nil))
	w("Merchant_GetOffers:", tostring(merchantOffers ~= nil))
	w("Merchant_RequestPurchase:", tostring(merchantPurchase ~= nil))
	w("")
	if getState then
		local ok, state = invoke("TravelingMerchant_GetState")
		w(("GetState() ok=%s type=%s"):format(tostring(ok), typeof(state)))
		if ok and typeof(state) == "table" then
			for k, v in pairs(state) do
				w(("  %s = %s"):format(tostring(k), serialize(v)))
			end
		end
	end
	if merchantOffers then
		local ok, offers = invoke("Merchant_GetOffers")
		w(("GetOffers() ok=%s type=%s"):format(tostring(ok), typeof(offers)))
		if ok and typeof(offers) == "table" then
			for k, v in pairs(offers) do
				w(("  %s = %s"):format(tostring(k), serialize(v)))
			end
		end
	end
end

flushSafe()

sep("MERCHANT 4 — PRECISE TELEPORT + PURCHASE TEST")
if CONFIG.TEST_MERCHANT and CONFIG.TEST_MERCHANT_PURCHASE and #campInfo > 0 and root then
	for _, entry in ipairs(campInfo) do
		if #entry.candidates == 0 then
			w(("=== Camp %s | no candidates — skip"):format(entry.name))
		else
			w("")
			w(("=== Camp %s | %d candidate positions"):format(entry.name, #entry.candidates))

			for idx, candidate in ipairs(entry.candidates) do
				w("")
				w(("  -- Candidate %d: %s | pos=%.1f,%.1f,%.1f"):format(
					idx, candidate.label,
					candidate.pos.X, candidate.pos.Y, candidate.pos.Z
				))

				-- Precise teleport
				local ok, dist = teleportExact(candidate.pos, "camp-" .. entry.name .. "-" .. idx)
				if not ok then
					w(("    Teleport FAILED: %s"):format(tostring(dist)))
				else
					w(("    Teleport OK (dist=%.1f)"):format(dist))

					-- Fire all prompts in camp
					local promptCount = 0
					for _, d in ipairs(entry.model:GetDescendants()) do
						if d:IsA("ProximityPrompt") then
							if not d.Enabled then pcall(function() d.Enabled = true end) end
							pcall(fireproximityprompt, d)
							promptCount += 1
							task.wait(0.15)
						end
					end
					w(("    Fired %d prompts"):format(promptCount))

					-- MachineScreens_Get
					local screens = networkFolder:FindFirstChild("MachineScreens_Get")
					if screens then
						for _, id in ipairs({ entry.name, "Merchant", "DiamondMountainMerchant", "DM_Merchant", "TravelingMerchant" }) do
							pcall(fire, "MachineScreens_Get", id)
							task.wait(0.1)
						end
						w("    Fired MachineScreens_Get")
					end

					-- GetState after teleport
					local okS, state = invoke("TravelingMerchant_GetState")
					w(("    GetState() ok=%s type=%s"):format(tostring(okS), typeof(state)))
					if okS and typeof(state) == "table" then
						for k, v in pairs(state) do
							w(("      %s = %s"):format(tostring(k), serialize(v)))
						end
					end

					-- Purchase attempts
					local purchase = networkFolder:FindFirstChild("TravelingMerchant_RequestPurchase")
					local merchantPurchase = networkFolder:FindFirstChild("Merchant_RequestPurchase")
					if purchase then
						w("    -- TravelingMerchant_RequestPurchase:")
						for _, id in ipairs(CONFIG.MERCHANT_PURCHASE_IDS) do
							local okP, resultP = invoke("TravelingMerchant_RequestPurchase", id)
							w(("      id=%q ok=%s result=%s"):format(
								tostring(id), tostring(okP), serialize(resultP)
							))
							task.wait(0.2)
						end
					end
					if merchantPurchase then
						w("    -- Merchant_RequestPurchase:")
						for _, id in ipairs(CONFIG.MERCHANT_PURCHASE_IDS) do
							local okP, resultP = invoke("Merchant_RequestPurchase", id)
							w(("      id=%q ok=%s result=%s"):format(
								tostring(id), tostring(okP), serialize(resultP)
							))
							task.wait(0.2)
						end
					end
				end

				flushSafe()
			end
		end
	end
elseif CONFIG.TEST_MERCHANT then
	w("(skip — no camps or merchant purchase disabled)")
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
w("Working flag signature:", tostring(workingSignature))
w("Working fruit signature:", tostring(workingFruitSignature))
w("Hatchable eggs:", #hatchableEggs)
w("Current merchant phase:", tostring(currentPhase))
w("Current merchant camp:", tostring(currentCamp))
w("Visit at:", tostring(visitAt))
w("Camp candidates:", (function()
	local n = 0
	for _, e in ipairs(campInfo) do n += #e.candidates end
	return n
end)())

flush()
