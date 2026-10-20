-- =====================================================
-- VRT DIAGNOSTIC v2.0 — Deep Dive
-- Flag / Fruit / Custom Egg / Traveling Merchant
-- Save -> VRT/VRT_Diag2.txt
-- CHẠY KHI ĐANG Ở TRONG DIAMOND MOUNTAIN (quan trọng cho merchant)
-- =====================================================

local CONFIG = {
	-- Đặt true nếu muốn test thực sự (tốn tài nguyên)
	TEST_FLAG_CONSUME = false,
	TEST_FRUIT_CONSUME = false,
	TEST_HATCH_BATCH = true,
	TEST_HATCH_LOOP = false,

	-- Để nil = tự pick egg đầu tiên / GetMaxHatch()
	HATCH_EGG_UUID = nil,
	HATCH_MAX = nil,

	-- Giới hạn serialize (tránh file quá lớn)
	MAX_TABLE_ENTRIES = 40,
	MAX_DEPTH = 4,
}

local playersService = game:GetService("Players")
local replicatedStorage = game:GetService("ReplicatedStorage")

local localPlayer = playersService.LocalPlayer
local libraryFolder = replicatedStorage:WaitForChild("Library")
local clientFolder = libraryFolder:WaitForChild("Client")
local directoryFolder = libraryFolder:FindFirstChild("Directory")
local utilFolder = libraryFolder:FindFirstChild("Util")
local networkFolder = replicatedStorage:FindFirstChild("Network")

local DIAG_FOLDER = "VRT"
local DIAG_PATH = "VRT/VRT_Diag2.txt"

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

-- -----------------------------------------------------
-- Serializer
-- -----------------------------------------------------
local function serialize(value, depth, seen)
	depth = depth or 0
	seen = seen or {}
	if depth > CONFIG.MAX_DEPTH then return "..." end
	local t = typeof(value)
	if t == "string" then
		if #value > 300 then
			return string.format("%q..(%d)", value:sub(1, 300), #value)
		end
		return string.format("%q", value)
	elseif t == "number" or t == "boolean" or t == "nil" then
		return tostring(value)
	elseif t == "Instance" then
		return value:GetFullName()
	elseif t == "Vector3" then
		return string.format("Vector3(%.1f, %.1f, %.1f)", value.X, value.Y, value.Z)
	elseif t == "Vector2" then
		return string.format("Vector2(%.1f, %.1f)", value.X, value.Y)
	elseif t == "CFrame" then
		local p = value.Position
		return string.format("CFrame(%.1f, %.1f, %.1f)", p.X, p.Y, p.Z)
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

local function dumpModule(name, mod, upvalueDepth)
	upvalueDepth = upvalueDepth or 1
	if typeof(mod) ~= "table" then
		w(("[%s] type = %s | value = %s"):format(name, typeof(mod), serialize(mod)))
		return
	end
	w(("[%s] type = table"):format(name))
	local keys = {}
	for k in pairs(mod) do keys[#keys + 1] = k end
	table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
	for _, k in ipairs(keys) do
		local v = mod[k]
		local tv = typeof(v)
		if tv == "function" then
			local info = debug.getinfo(v)
			w(("  .%-32s = fn | what=%s nups=%d params=%d vararg=%s"):format(
				tostring(k), tostring(info and info.what),
				info and info.nups or 0, info and info.numparams or 0,
				tostring(info and info.is_vararg)
			))
			if upvalueDepth > 0 then
				local ok, ups = pcall(debug.getupvalues, v)
				if ok and type(ups) == "table" then
					for i, uv in pairs(ups) do
						local tuv = typeof(uv)
						if tuv == "table" then
							local n = 0
							for _ in pairs(uv) do n += 1 end
							w(("      up[%d] = table(%d)"):format(i, n))
						elseif tuv == "function" then
							local ui = debug.getinfo(uv)
							w(("      up[%d] = fn(%s)"):format(i, ui and ui.what or "?"))
						else
							w(("      up[%d] = %s"):format(i, serialize(uv)))
						end
					end
				end
			end
		elseif tv == "table" then
			local n = 0
			for _ in pairs(v) do n += 1 end
			w(("  .%-32s = table(%d)"):format(tostring(k), n))
			local subkeys = {}
			for sk in pairs(v) do subkeys[#subkeys + 1] = sk end
			table.sort(subkeys, function(a, b) return tostring(a) < tostring(b) end)
			local shown = 0
			for _, sk in ipairs(subkeys) do
				if shown >= 15 then
					w("      ...")
					break
				end
				shown += 1
				w(("      [%s] = %s"):format(tostring(sk), serialize(v[sk])))
			end
		else
			w(("  .%-32s = %s | %s"):format(tostring(k), tv, serialize(v)))
		end
	end
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
-- HEADER
-- -----------------------------------------------------
sep("HEADER")
w("Time:", os.date("%c"))
w("Player:", localPlayer.Name, "|", localPlayer.DisplayName, "|", tostring(localPlayer.UserId))
w("PlaceId:", tostring(game.PlaceId))
w("JobId:", tostring(game.JobId))
pcall(function()
	local a, b = identifyexecutor()
	w("Executor:", tostring(a), tostring(b))
end)
pcall(function()
	w("ThreadIdentity:", tostring(getthreadidentity()))
end)
w("")
w("CONFIG:")
w("  TEST_FLAG_CONSUME:", tostring(CONFIG.TEST_FLAG_CONSUME))
w("  TEST_FRUIT_CONSUME:", tostring(CONFIG.TEST_FRUIT_CONSUME))
w("  TEST_HATCH_BATCH:", tostring(CONFIG.TEST_HATCH_BATCH))
w("  TEST_HATCH_LOOP:", tostring(CONFIG.TEST_HATCH_LOOP))

local root = getRoot()
if root then
	local p = root.Position
	w(("Position: %.1f, %.1f, %.1f"):format(p.X, p.Y, p.Z))
else
	w("Position: no character")
end

-- -----------------------------------------------------
-- MAP / INSTANCE INFO
-- -----------------------------------------------------
sep("MAP / INSTANCE INFO")
local mapCmds = safeRequire(clientFolder and clientFolder:FindFirstChild("MapCmds"))
if mapCmds then
	if mapCmds.GetCurrentInstanceInfo then
		tryCall("GetCurrentInstanceInfo", mapCmds.GetCurrentInstanceInfo)
	end
	if mapCmds.GetCurrentZone then
		tryCall("GetCurrentZone", mapCmds.GetCurrentZone)
	end
	if mapCmds.GetCurrentBreakZone then
		tryCall("GetCurrentBreakZone", mapCmds.GetCurrentBreakZone)
	end
	if mapCmds.IsInSpawn then
		tryCall("IsInSpawn", mapCmds.IsInSpawn)
	end
end

-- -----------------------------------------------------
-- FLAG DEEP DIVE
-- -----------------------------------------------------
sep("FLAG 1 — FlexibleFlagCmds FULL")
local flagCmds = safeRequire(clientFolder and clientFolder:FindFirstChild("FlexibleFlagCmds"))
if flagCmds then
	dumpModule("FlexibleFlagCmds", flagCmds, 1)
else
	w("require(FlexibleFlagCmds) failed")
end

sep("FLAG 2 — SpatialQuery / GetMaxPlace")
if flagCmds and root then
	local pos = root.Position
	if typeof(flagCmds.SpatialQuery) == "function" then
		tryCall("SpatialQuery(pos)", flagCmds.SpatialQuery, pos)
	end
	if typeof(flagCmds.GetMaxPlaceAutomaticContext) == "function" then
		tryCall("GetMaxPlaceAutomaticContext(pos)", flagCmds.GetMaxPlaceAutomaticContext, pos)
	end
	if typeof(flagCmds.GetMaxPlace) == "function" then
		tryCall("GetMaxPlace('Coins Flag')", flagCmds.GetMaxPlace, "Coins Flag")
		local ok, ctx = pcall(flagCmds.SpatialQuery, pos)
		if ok then
			tryCall("GetMaxPlace('Coins Flag', ctx)", flagCmds.GetMaxPlace, "Coins Flag", ctx)
		end
	end
end

sep("FLAG 3 — Active Flag State")
if flagCmds then
	if typeof(flagCmds.GetActiveFlag) == "function" then
		tryCall("GetActiveFlag()", flagCmds.GetActiveFlag)
	end
	if typeof(flagCmds.HasActiveFlag) == "function" then
		tryCall("HasActiveFlag('Coins Flag')", flagCmds.HasActiveFlag, "Coins Flag")
	end
	if typeof(flagCmds.PlayerHasActiveFlag) == "function" then
		tryCall("PlayerHasActiveFlag(localPlayer)", flagCmds.PlayerHasActiveFlag, localPlayer)
	end
end

sep("FLAG 4 — Consume Signature Test (dry run)")
if flagCmds and typeof(flagCmds.Consume) == "function" and root then
	local pos = root.Position
	local ctx = nil
	if typeof(flagCmds.SpatialQuery) == "function" then
		local ok, value = pcall(flagCmds.SpatialQuery, pos)
		if ok then ctx = value end
	end
	w("SpatialContext:", serialize(ctx))
	w("")
	w("-- Test each signature (only 1 flag each, amount=1):")
	local saved = CONFIG.TEST_FLAG_CONSUME
	CONFIG.TEST_FLAG_CONSUME = true
	if CONFIG.TEST_FLAG_CONSUME then
		-- 3 args with spatial
		tryCall("Consume(flagId, 1, ctx)", flagCmds.Consume, "Coins Flag", 1, ctx)
		task.wait(0.3)
		-- 3 args with position
		tryCall("Consume(flagId, 1, pos)", flagCmds.Consume, "Coins Flag", 1, pos)
		task.wait(0.3)
		-- 2 args
		tryCall("Consume(flagId, 1)", flagCmds.Consume, "Coins Flag", 1)
		task.wait(0.3)
		-- colon style
		tryCall("Consume(self, flagId, 1)", function()
			return flagCmds:Consume("Coins Flag", 1)
		end)
	end
	CONFIG.TEST_FLAG_CONSUME = saved
end

sep("FLAG 5 — ZoneFlagCmds module")
local zoneFlagCmds = safeRequire(clientFolder and clientFolder:FindFirstChild("ZoneFlagCmds"))
if zoneFlagCmds then
	dumpModule("ZoneFlagCmds", zoneFlagCmds, 1)
else
	w("require(ZoneFlagCmds) failed")
end

sep("FLAG 6 — Inventory Flag entries")
local saveMod = safeRequire(clientFolder and clientFolder:FindFirstChild("Save"))
if saveMod and saveMod.Get then
	local ok, save = pcall(saveMod.Get)
	if ok and type(save) == "table" and type(save.Inventory) == "table" then
		for bucketName, bucket in pairs(save.Inventory) do
			if type(bucket) == "table" then
				for uid, entry in pairs(bucket) do
					if type(entry) == "table" and type(entry.id) == "string" then
						if entry.id:lower():find("flag", 1, true) then
							w(("  [%s] uid=%s id=%q am=%s"):format(
								bucketName, tostring(uid), entry.id, tostring(entry._am)
							))
						end
					end
				end
			end
		end
	end
end

-- -----------------------------------------------------
-- FRUIT DEEP DIVE
-- -----------------------------------------------------
sep("FRUIT 1 — FruitCmds FULL")
local fruitCmds = safeRequire(clientFolder and clientFolder:FindFirstChild("FruitCmds"))
if fruitCmds then
	dumpModule("FruitCmds", fruitCmds, 1)
else
	w("require(FruitCmds) failed")
end

sep("FRUIT 2 — Queue / Power limits")
if fruitCmds then
	if typeof(fruitCmds.ComputeFruitQueueLimit) == "function" then
		tryCall("ComputeFruitQueueLimit()", fruitCmds.ComputeFruitQueueLimit)
	end
	if typeof(fruitCmds.ComputeFruitPowerLimit) == "function" then
		tryCall("ComputeFruitPowerLimit()", fruitCmds.ComputeFruitPowerLimit)
	end
	if typeof(fruitCmds.ComputeDuration) == "function" then
		tryCall("ComputeDuration('Apple')", fruitCmds.ComputeDuration, "Apple")
	end
end

sep("FRUIT 3 — GetActiveFruits FULL")
local activeFruits = nil
if fruitCmds and typeof(fruitCmds.GetActiveFruits) == "function" then
	local ok, value = pcall(fruitCmds.GetActiveFruits)
	w(("GetActiveFruits ok=%s type=%s"):format(tostring(ok), typeof(value)))
	if ok and type(value) == "table" then
		activeFruits = value
		for fruitId, stacks in pairs(value) do
			w(("[%s] type=%s"):format(tostring(fruitId), typeof(stacks)))
			if type(stacks) == "table" then
				for stackKey, list in pairs(stacks) do
					if type(list) == "table" then
						w(("  .%s = table #%d"):format(tostring(stackKey), #list))
						local shown = 0
						for i, item in ipairs(list) do
							if shown >= 3 then break end
							shown += 1
							w(("    [%d] = %s"):format(i, serialize(item)))
						end
					else
						w(("  .%s = %s"):format(tostring(stackKey), serialize(list)))
					end
				end
			end
		end
	end
end

sep("FRUIT 4 — GetMaxConsume per uid")
if fruitCmds and saveMod and saveMod.Get then
	local ok, save = pcall(saveMod.Get)
	if ok and type(save) == "table" and type(save.Inventory) == "table" and type(save.Inventory.Fruit) == "table" then
		for uid, entry in pairs(save.Inventory.Fruit) do
			if type(entry) == "table" then
				local stackKey = entry.sh == true and "Shiny" or "Normal"
				local getMax = "n/a"
				if typeof(fruitCmds.GetMaxConsume) == "function" then
					local okMax, value = pcall(fruitCmds.GetMaxConsume, uid)
					getMax = okMax and tostring(value) or ("err: " .. tostring(value))
				end
				local manual = "n/a"
				if activeFruits then
					local fruitEntry = activeFruits[entry.id]
					local activeCount = 0
					if type(fruitEntry) == "table" and type(fruitEntry[stackKey]) == "table" then
						activeCount = #fruitEntry[stackKey]
					end
					manual = tostring(50 - activeCount)
				end
				w(("uid=%s id=%q sh=%s am=%s | GetMaxConsume=%s | manual=%s"):format(
					tostring(uid), tostring(entry.id), tostring(entry.sh),
					tostring(entry._am), getMax, manual
				))
			end
		end
	end
end

sep("FRUIT 5 — Consume Signature Test (dry run)")
if fruitCmds and typeof(fruitCmds.Consume) == "function" then
	w("Consume signature test — chỉ chạy nếu TEST_FRUIT_CONSUME=true")
	if CONFIG.TEST_FRUIT_CONSUME and saveMod and saveMod.Get then
		local ok, save = pcall(saveMod.Get)
		if ok and type(save) == "table" and type(save.Inventory) == "table" and type(save.Inventory.Fruit) == "table" then
			local firstUid, firstEntry
			for uid, entry in pairs(save.Inventory.Fruit) do
				if type(entry) == "table" and (entry._am or 0) > 0 then
					firstUid, firstEntry = uid, entry
					break
				end
			end
			if firstUid then
				w(("Test uid=%s id=%q"):format(tostring(firstUid), tostring(firstEntry.id)))
				tryCall("Consume(uid, 1)", fruitCmds.Consume, firstUid, 1)
				task.wait(0.3)
				tryCall("Consume(entry, 1)", fruitCmds.Consume, firstEntry, 1)
				task.wait(0.3)
				tryCall("Consume(self, uid)", function()
					return fruitCmds:Consume(firstUid)
				end)
			end
		end
	else
		w("(skipped — set TEST_FRUIT_CONSUME=true to test)")
	end
end

-- -----------------------------------------------------
-- CUSTOM EGG DEEP DIVE
-- -----------------------------------------------------
sep("EGG 1 — CustomEggsCmds FULL")
local customCmds = safeRequire(clientFolder and clientFolder:FindFirstChild("CustomEggsCmds"))
if customCmds then
	dumpModule("CustomEggsCmds", customCmds, 1)
else
	w("require(CustomEggsCmds) failed")
end

sep("EGG 2 — CustomEggsCmds.All() / GetById()")
if customCmds then
	if typeof(customCmds.All) == "function" then
		local ok, list = pcall(customCmds.All)
		w(("All() ok=%s type=%s"):format(tostring(ok), typeof(list)))
		if ok and type(list) == "table" then
			local n = 0
			for k, v in pairs(list) do
				n += 1
				if n <= 20 then
					w(("  [%s] = %s"):format(tostring(k), serialize(v)))
				end
			end
			w(("  total: %d"):format(n))
		end
	end
end

sep("EGG 3 — CustomEggs_Get remote")
local customGet = networkFolder and networkFolder:FindFirstChild("CustomEggs_Get")
if customGet then
	local network = safeRequire(clientFolder and clientFolder:FindFirstChild("Network"))
	if network and network.Invoke then
		local ok, result = pcall(network.Invoke, "CustomEggs_Get")
		w(("CustomEggs_Get() ok=%s type=%s"):format(tostring(ok), typeof(result)))
		if ok and type(result) == "table" then
			local n = 0
			for k, v in pairs(result) do
				n += 1
				if n <= 20 then
					w(("  [%s] = %s"):format(tostring(k), serialize(v)))
				end
			end
			w(("  total: %d"):format(n))
		end
	end
else
	w("CustomEggs_Get remote NOT FOUND")
end

sep("EGG 4 — GetMaxHatch")
local eggCmds = safeRequire(clientFolder and clientFolder:FindFirstChild("EggCmds"))
if eggCmds and typeof(eggCmds.GetMaxHatch) == "function" then
	tryCall("GetMaxHatch()", eggCmds.GetMaxHatch)
	tryCall("GetMaxHatch('Apple Egg')", eggCmds.GetMaxHatch, "Apple Egg")
end

sep("EGG 5 — World CustomEggs")
local things = workspace:FindFirstChild("__THINGS")
local customFolder = things and things:FindFirstChild("CustomEggs")
local firstUuid = nil
if customFolder then
	w(("CustomEggs children: %d"):format(#customFolder:GetChildren()))
	for _, m in ipairs(customFolder:GetChildren()) do
		if m:IsA("Model") then
			local eggPart = m:FindFirstChild("Egg")
			local posStr = "nil"
			local distStr = "nil"
			if eggPart and eggPart:IsA("BasePart") then
				posStr = string.format("%.1f, %.1f, %.1f",
					eggPart.Position.X, eggPart.Position.Y, eggPart.Position.Z)
				if root then
					distStr = string.format("%.0f", (eggPart.Position - root.Position).Magnitude)
				end
			end
			w(("  %s (%s) pos=%s dist=%s"):format(m.Name, m.ClassName, posStr, distStr))
			if not firstUuid then firstUuid = m.Name end
		end
	end
else
	w("CustomEggs folder NOT FOUND")
end

sep("EGG 6 — HATCH TEST")
local hatchUuid = CONFIG.HATCH_EGG_UUID or firstUuid
local hatchMax = CONFIG.HATCH_MAX
if not hatchMax and eggCmds and typeof(eggCmds.GetMaxHatch) == "function" then
	local ok, value = pcall(eggCmds.GetMaxHatch)
	if ok and type(value) == "number" then hatchMax = value end
end
if not hatchMax then hatchMax = 1 end

w(("UUID: %s | maxHatch: %d"):format(tostring(hatchUuid), hatchMax))

if hatchUuid then
	local network = safeRequire(clientFolder and clientFolder:FindFirstChild("Network"))
	if network and network.Invoke then
		if CONFIG.TEST_HATCH_BATCH then
			w("")
			w("-- TEST_HATCH_BATCH: CustomEggs_Hatch(uuid, maxHatch)")
			local ok, result = pcall(network.Invoke, "CustomEggs_Hatch", hatchUuid, hatchMax)
			w(("  ok=%s | result=%s"):format(tostring(ok), serialize(result)))
			task.wait(1)
		end
		if CONFIG.TEST_HATCH_LOOP then
			w("")
			w(("-- TEST_HATCH_LOOP: CustomEggs_Hatch(uuid) x %d"):format(hatchMax))
			local total = 0
			for i = 1, hatchMax do
				local ok, result = pcall(network.Invoke, "CustomEggs_Hatch", hatchUuid)
				if ok then
					total += 1
					w(("  [%d] ok=true | result=%s"):format(i, serialize(result)))
				else
					w(("  [%d] ok=false | err=%s"):format(i, tostring(result)))
					break
				end
				task.wait(0.1)
			end
			w(("  total: %d/%d"):format(total, hatchMax))
		end
	else
		w("Network module not available")
	end
else
	w("No custom egg uuid — skip hatch test")
end

-- -----------------------------------------------------
-- TRAVELING MERCHANT DEEP DIVE
-- -----------------------------------------------------
sep("MERCHANT 1 — TravelingMerchant_GetState")
local network = safeRequire(clientFolder and clientFolder:FindFirstChild("Network"))
if network and network.Invoke then
	local ok, result = pcall(network.Invoke, "TravelingMerchant_GetState")
	w(("TravelingMerchant_GetState() ok=%s type=%s"):format(tostring(ok), typeof(result)))
	if ok and type(result) == "table" then
		for k, v in pairs(result) do
			w(("  %s = %s"):format(tostring(k), serialize(v)))
		end
	end
end

sep("MERCHANT 2 — Merchant_GetOffers")
if network and network.Invoke then
	tryCall("Merchant_GetOffers()", function()
		return network.Invoke("Merchant_GetOffers")
	end)
end

sep("MERCHANT 3 — TravelingMerchantUtil")
local tMerchantUtil = safeRequire(utilFolder and utilFolder:FindFirstChild("TravelingMerchantUtil"))
if tMerchantUtil then
	dumpModule("TravelingMerchantUtil", tMerchantUtil, 2)
else
	w("require(TravelingMerchantUtil) failed")
end

sep("MERCHANT 4 — DiamondMountainMerchant util")
local dmMerchant = safeRequire(utilFolder and utilFolder:FindFirstChild("DiamondMountainMerchant"))
if dmMerchant then
	dumpModule("DiamondMountainMerchant", dmMerchant, 2)
else
	w("require(DiamondMountainMerchant) failed")
end

sep("MERCHANT 5 — MerchantUtil")
local merchantUtil = safeRequire(utilFolder and utilFolder:FindFirstChild("MerchantUtil"))
if merchantUtil then
	dumpModule("MerchantUtil", merchantUtil, 1)
else
	w("require(MerchantUtil) failed")
end

sep("MERCHANT 6 — DiamondMountainCmds")
local dmCmds = safeRequire(clientFolder and clientFolder:FindFirstChild("DiamondMountainCmds"))
if dmCmds then
	dumpModule("DiamondMountainCmds", dmCmds, 2)
else
	w("require(DiamondMountainCmds) failed")
end

-- -----------------------------------------------------
-- DM INSTANCE STRUCTURE
-- -----------------------------------------------------
sep("DM INSTANCE — __INSTANCE_CONTAINER.Active")
if things then
	local container = things:FindFirstChild("__INSTANCE_CONTAINER")
	local active = container and container:FindFirstChild("Active")
	if active then
		w("Active children:", #active:GetChildren())
		for _, c in ipairs(active:GetChildren()) do
			w(("  %s (%s) children=%d"):format(c.Name, c.ClassName, #c:GetChildren()))
		end
		local dm = active:FindFirstChild("DiamondMountain")
		if dm then
			w("")
			w("-- DiamondMountain tree (depth 3):")
			local function walk(inst, depth)
				if depth > 3 then return end
				for _, child in ipairs(inst:GetChildren()) do
					local extra = ""
					if child:IsA("BasePart") then
						extra = string.format(" pos=%.1f,%.1f,%.1f",
							child.Position.X, child.Position.Y, child.Position.Z)
					end
					w(("%s%s (%s)%s"):format(
						string.rep("  ", depth), child.Name, child.ClassName, extra
					))
					walk(child, depth + 1)
				end
			end
			walk(dm, 1)
		end
	else
		w("__INSTANCE_CONTAINER.Active NOT FOUND")
	end
else
	w("__THINGS NOT FOUND")
end

sep("DM INSTANCE — __THINGS.Instances")
if things then
	local instances = things:FindFirstChild("Instances")
	if instances then
		w("Instances children:", #instances:GetChildren())
		for _, c in ipairs(instances:GetChildren()) do
			w(("  %s (%s) children=%d"):format(c.Name, c.ClassName, #c:GetChildren()))
		end
		local dm = instances:FindFirstChild("DiamondMountain")
		if dm then
			w("")
			w("-- DiamondMountain tree (depth 3):")
			local function walk(inst, depth)
				if depth > 3 then return end
				for _, child in ipairs(inst:GetChildren()) do
					local extra = ""
					if child:IsA("BasePart") then
						extra = string.format(" pos=%.1f,%.1f,%.1f",
							child.Position.X, child.Position.Y, child.Position.Z)
					end
					w(("%s%s (%s)%s"):format(
						string.rep("  ", depth), child.Name, child.ClassName, extra
					))
					walk(child, depth + 1)
				end
			end
			walk(dm, 1)
		end
	else
		w("Instances NOT FOUND")
	end
end

sep("DM INSTANCE — Merchant search anywhere")
if things then
	local found = 0
	for _, d in ipairs(things:GetDescendants()) do
		if d.Name:lower():find("merchant", 1, true) then
			if d:IsA("Model") or d:IsA("BasePart") or d:IsA("Folder") then
				found += 1
				if found <= 30 then
					local extra = ""
					if d:IsA("BasePart") then
						extra = string.format(" pos=%.1f,%.1f,%.1f",
							d.Position.X, d.Position.Y, d.Position.Z)
					end
					w(("  %s (%s)%s"):format(d:GetFullName(), d.ClassName, extra))
				end
			end
		end
	end
	w(("Total merchant-named: %d"):format(found))
end

-- -----------------------------------------------------
-- SUMMARY
-- -----------------------------------------------------
sep("SUMMARY")
w("Diagnostic complete.")
w("File:", DIAG_PATH)
w("Lines:", #lines)

flush()
