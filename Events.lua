-- =====================================================
-- VRT MERCHANT DIAGNOSTIC v1.0
-- Chuyên sâu về Traveling Merchant trong Diamond Mountain
-- Save -> VRT/VRT_Merchant.txt
-- CHẠY KHI ĐANG Ở TRONG DIAMOND MOUNTAIN, ĐỨNG GẦN MERCHANT
-- =====================================================

local CONFIG = {
	TEST_OPEN = true,
	TEST_PURCHASE = true,
	TEST_DEBUG_FN = true,
	TEST_LOOKATWAGON = true,
	MAX_TABLE_ENTRIES = 60,
	MAX_DEPTH = 5,
	WAIT = 0.4,
}

local playersService = game:GetService("Players")
local replicatedStorage = game:GetService("ReplicatedStorage")

local localPlayer = playersService.LocalPlayer
local libraryFolder = replicatedStorage:WaitForChild("Library")
local clientFolder = libraryFolder:WaitForChild("Client")
local utilFolder = libraryFolder:FindFirstChild("Util")
local directoryFolder = libraryFolder:FindFirstChild("Directory")
local networkFolder = replicatedStorage:WaitForChild("Network")

local DIAG_FOLDER = "VRT"
local DIAG_PATH = "VRT/VRT_Merchant.txt"

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
		if #value > 300 then
			return string.format("%q..(%d)", value:sub(1, 300), #value)
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

local function dumpFunction(label, fn, upvalueDepth)
	upvalueDepth = upvalueDepth or 1
	if typeof(fn) ~= "function" then
		w(("[%s] = %s"):format(label, typeof(fn)))
		return
	end
	local info = debug.getinfo(fn)
	w(("[%s] fn | what=%s params=%d nups=%d vararg=%s"):format(
		label, tostring(info and info.what),
		info and info.numparams or 0,
		info and info.nups or 0,
		tostring(info and info.is_vararg)
	))
	if upvalueDepth > 0 then
		local ok, ups = pcall(debug.getupvalues, fn)
		if ok and typeof(ups) == "table" then
			for i, uv in pairs(ups) do
				local tuv = typeof(uv)
				if tuv == "table" then
					local n = 0
					for _ in pairs(uv) do n += 1 end
					w(("  up[%d] = table(%d)"):format(i, n))
					if upvalueDepth > 1 then
						for k, v in pairs(uv) do
							local tk = typeof(k)
							local tv = typeof(v)
							if tk == "string" or tk == "number" then
								w(("    [%s] = %s"):format(tostring(k), serialize(v)))
							end
						end
					end
				elseif tuv == "function" then
					local ui = debug.getinfo(uv)
					w(("  up[%d] = fn(%s)"):format(i, ui and ui.what or "?"))
				elseif tuv == "Instance" then
					w(("  up[%d] = %s"):format(i, uv:GetFullName()))
				else
					w(("  up[%d] = %s"):format(i, serialize(uv)))
				end
			end
		end
	end
end

local function dumpTable(label, tbl, depth)
	depth = depth or 1
	if typeof(tbl) ~= "table" then
		w(("[%s] = %s"):format(label, typeof(tbl)))
		return
	end
	local n = 0
	for _ in pairs(tbl) do n += 1 end
	w(("[%s] table(%d)"):format(label, n))
	local keys = {}
	for k in pairs(tbl) do keys[#keys + 1] = k end
	table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
	for _, k in ipairs(keys) do
		local v = tbl[k]
		local tv = typeof(v)
		if tv == "function" then
			local info = debug.getinfo(v)
			w(("  .%s = fn | params=%d nups=%d"):format(
				tostring(k), info and info.numparams or 0, info and info.nups or 0
			))
			if depth > 1 then
				local ok, ups = pcall(debug.getupvalues, v)
				if ok and typeof(ups) == "table" then
					for i, uv in pairs(ups) do
						local tuv = typeof(uv)
						if tuv == "table" then
							local nn = 0
							for _ in pairs(uv) do nn += 1 end
							w(("      up[%d] = table(%d)"):format(i, nn))
						elseif tuv == "function" then
							local ui = debug.getinfo(uv)
							w(("      up[%d] = fn(%s)"):format(i, ui and ui.what or "?"))
						elseif tuv == "Instance" then
							w(("      up[%d] = %s"):format(i, uv:GetFullName()))
						else
							w(("      up[%d] = %s"):format(i, serialize(uv)))
						end
					end
				end
			end
		elseif tv == "table" then
			local nn = 0
			for _ in pairs(v) do nn += 1 end
			w(("  .%s = table(%d)"):format(tostring(k), nn))
			if depth > 1 then
				local subkeys = {}
				for sk in pairs(v) do subkeys[#subkeys + 1] = sk end
				table.sort(subkeys, function(a, b) return tostring(a) < tostring(b) end)
				local shown = 0
				for _, sk in ipairs(subkeys) do
					if shown >= 20 then
						w("      ...")
						break
					end
					shown += 1
					w(("      [%s] = %s"):format(tostring(sk), serialize(v[sk])))
				end
			end
		else
			w(("  .%s = %s"):format(tostring(k), serialize(v)))
		end
	end
end

local function invoke(name, ...)
	local network = safeRequire(clientFolder:FindFirstChild("Network"))
	if not network or not network.Invoke then return false, "no network" end
	local ok, result = pcall(network.Invoke, name, ...)
	return ok, result
end

local function fire(name, ...)
	local network = safeRequire(clientFolder:FindFirstChild("Network"))
	if not network or not network.Fire then return false, "no network" end
	local ok, result = pcall(network.Fire, name, ...)
	return ok, result
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
	DiamondMountainCmds = safeRequire(clientFolder:FindFirstChild("DiamondMountainCmds")),
	DiamondMountainMerchant = safeRequire(utilFolder and utilFolder:FindFirstChild("DiamondMountainMerchant")),
	MerchantUtil = safeRequire(utilFolder and utilFolder:FindFirstChild("MerchantUtil")),
	TravelingMerchantUtil = safeRequire(utilFolder and utilFolder:FindFirstChild("TravelingMerchantUtil")),
	MerchantsDir = safeRequire(directoryFolder and directoryFolder:FindFirstChild("Merchants")),
	MachineScreens = safeRequire(clientFolder:FindFirstChild("MachineScreens")),
	MachineCmds = safeRequire(clientFolder:FindFirstChild("MachineCmds")),
	ProximityPrompt = safeRequire(clientFolder:FindFirstChild("ProximityPrompt")),
}

-- -----------------------------------------------------
-- PHASE INFO
-- -----------------------------------------------------
sep("PHASE INFO")
local dmMerchant = Modules.DiamondMountainMerchant
local currentCamp = nil

if typeof(dmMerchant) == "table" then
	w("DiamondMountainMerchant:", typeof(dmMerchant))
	w("  CYCLE:", dmMerchant.CYCLE and table.concat(dmMerchant.CYCLE, ",") or "nil")
	w("  REACH:", tostring(dmMerchant.REACH))
	w("  TRAVEL_SECONDS:", tostring(dmMerchant.TRAVEL_SECONDS))
	w("  DEFAULT_MOVE:", tostring(dmMerchant.DEFAULT_MOVE))
	w("  OFFSET_ATTR:", tostring(dmMerchant.OFFSET_ATTR))
	w("")

	if typeof(dmMerchant.Phase) == "function" then
		local ok, phase = pcall(dmMerchant.Phase)
		w(("Phase() ok=%s"):format(tostring(ok)))
		if ok and typeof(phase) == "table" then
			for k, v in pairs(phase) do
				w(("  %s = %s"):format(tostring(k), serialize(v)))
			end
			if typeof(phase.Camp) == "number" then
				currentCamp = phase.Camp
			end
		end
	end

	w("")
	if typeof(dmMerchant.Offset) == "function" then
		local ok, offset = pcall(dmMerchant.Offset)
		w(("Offset() ok=%s value=%s"):format(tostring(ok), serialize(offset)))
	end
	if typeof(dmMerchant.MoveSeconds) == "function" then
		local ok, ms = pcall(dmMerchant.MoveSeconds)
		w(("MoveSeconds() ok=%s value=%s"):format(tostring(ok), serialize(ms)))
	end
	if typeof(dmMerchant.Folder) == "function" then
		local ok, folder = pcall(dmMerchant.Folder)
		w(("Folder() ok=%s value=%s"):format(tostring(ok), serialize(folder)))
	end
end

flushSafe()

-- -----------------------------------------------------
-- MERCHANT PART
-- -----------------------------------------------------
sep("MERCHANT PART + CAMP STRUCTURE")
local merchantPart = nil
local campModel = nil

if currentCamp then
	local things = workspace:FindFirstChild("__THINGS")
	local container = things and things:FindFirstChild("__INSTANCE_CONTAINER")
	local active = container and container:FindFirstChild("Active")
	local mountain = active and active:FindFirstChild("DiamondMountain")
	local camps = mountain and mountain:FindFirstChild("Camps")
	campModel = camps and camps:FindFirstChild(tostring(currentCamp))

	if campModel then
		w(("Camp %s found: %s"):format(tostring(currentCamp), campModel:GetFullName()))
		w("")
		w("-- Camp children:")
		for _, child in ipairs(campModel:GetChildren()) do
			local extra = ""
			if child:IsA("BasePart") then
				extra = (" pos=%.1f,%.1f,%.1f size=%.1f,%.1f,%.1f"):format(
					child.Position.X, child.Position.Y, child.Position.Z,
					child.Size.X, child.Size.Y, child.Size.Z
				)
			end
			w(("  %s (%s)%s"):format(child.Name, child.ClassName, extra))
		end

		merchantPart = campModel:FindFirstChild("Merchant")
		if merchantPart then
			w("")
			w(("-- Merchant part: %s"):format(merchantPart:GetFullName()))
			w(("  Size: %.1f,%.1f,%.1f"):format(
				merchantPart.Size.X, merchantPart.Size.Y, merchantPart.Size.Z
			))
			w(("  Transparency: %.2f"):format(merchantPart.Transparency))
			w(("  CanCollide: %s"):format(tostring(merchantPart.CanCollide)))
			w("")
			w("-- Merchant descendants:")
			local descCount = 0
			for _, d in ipairs(merchantPart:GetDescendants()) do
				descCount += 1
				local extra = ""
				if d:IsA("BasePart") then
					extra = (" pos=%.1f,%.1f,%.1f"):format(
						d.Position.X, d.Position.Y, d.Position.Z
					)
				elseif d:IsA("ProximityPrompt") then
					extra = (" enabled=%s actionText=%q objectText=%q holdDuration=%.1f"):format(
						tostring(d.Enabled), tostring(d.ActionText),
						tostring(d.ObjectText), d.HoldDuration
					)
				elseif d:IsA("ClickDetector") then
					extra = (" MaxActivationDistance=%.0f"):format(d.MaxActivationDistance)
				elseif d:IsA("Attachment") then
					extra = (" WorldPos=%.1f,%.1f,%.1f"):format(
						d.WorldPosition.X, d.WorldPosition.Y, d.WorldPosition.Z
					)
				elseif d:IsA("BillboardGui") then
					extra = (" enabled=%s"):format(tostring(d.Enabled))
				end
				w(("  %s (%s)%s"):format(d.Name, d.ClassName, extra))
			end
			if descCount == 0 then
				w("  (no descendants — Merchant là Part trơn)")
			end

			w("")
			w("-- Merchant attributes:")
			local attrs = merchantPart:GetAttributes()
			local attrCount = 0
			for k, v in pairs(attrs) do
				attrCount += 1
				w(("  %s = %s"):format(tostring(k), serialize(v)))
			end
			if attrCount == 0 then
				w("  (no attributes)")
			end
		end

		w("")
		w("-- Camp ALL descendants (ProximityPrompt/ClickDetector/Attachment/BillboardGui/SurfaceGui/TextButton):")
		for _, d in ipairs(campModel:GetDescendants()) do
			if d:IsA("ProximityPrompt") or d:IsA("ClickDetector")
				or d:IsA("BillboardGui") or d:IsA("SurfaceGui")
				or d:IsA("TextButton") or d:IsA("ImageButton")
				or d:IsA("Attachment")
			then
				local extra = ""
				if d:IsA("ProximityPrompt") then
					extra = (" enabled=%s actionText=%q"):format(
						tostring(d.Enabled), tostring(d.ActionText)
					)
				elseif d:IsA("Attachment") then
					extra = (" WorldPos=%.1f,%.1f,%.1f"):format(
						d.WorldPosition.X, d.WorldPosition.Y, d.WorldPosition.Z
					)
				end
				w(("  %s (%s)%s"):format(d:GetFullName(), d.ClassName, extra))
			end
		end
	end
end

flushSafe()

-- -----------------------------------------------------
-- FEATURE('Merchant') FULL
-- -----------------------------------------------------
sep("FEATURE('Merchant') FULL DUMP")
local dmCmds = Modules.DiamondMountainCmds
local merchantFeature = nil

if typeof(dmCmds) == "table" and typeof(dmCmds.Feature) == "function" then
	w("DiamondMountainCmds.FEATURES:", dmCmds.FEATURES and table.concat(dmCmds.FEATURES, ",") or "nil")
	w("")

	local ok, feature = pcall(dmCmds.Feature, "Merchant")
	if ok and typeof(feature) == "table" then
		merchantFeature = feature
		dumpTable("Feature('Merchant')", feature, 2)
	else
		w("Feature('Merchant') failed:", tostring(feature))
	end
end

flushSafe()

-- -----------------------------------------------------
-- LASTOPEN BEFORE Open()
-- -----------------------------------------------------
sep("LASTOPEN BEFORE Open()")
if merchantFeature then
	if typeof(merchantFeature.LastOpen) == "table" then
		local n = 0
		for _ in pairs(merchantFeature.LastOpen) do n += 1 end
		w(("LastOpen entries: %d"):format(n))
		for k, v in pairs(merchantFeature.LastOpen) do
			w(("  [%s] = %s"):format(tostring(k), serialize(v)))
		end
	else
		w("LastOpen type:", typeof(merchantFeature.LastOpen))
	end
end

flushSafe()

-- -----------------------------------------------------
-- TELEPORT + OPEN
-- -----------------------------------------------------
sep("TELEPORT TO MERCHANT + OPEN")
if merchantPart and root and CONFIG.TEST_OPEN then
	local originalCFrame = root.CFrame
	local originalAnchored = root.Anchored

	root.Anchored = true
	root.CFrame = CFrame.new(merchantPart.Position)
	task.wait(0.6)
	w(("Teleported: %.1f,%.1f,%.1f -> %.1f,%.1f,%.1f"):format(
		originalCFrame.Position.X, originalCFrame.Position.Y, originalCFrame.Position.Z,
		root.Position.X, root.Position.Y, root.Position.Z
	))
	root.Anchored = originalAnchored
	task.wait(0.3)

	if merchantFeature and typeof(merchantFeature.Open) == "function" then
		w("")
		w("-- Calling Feature('Merchant').Open()...")
		local ok, result = pcall(merchantFeature.Open)
		w(("Open() ok=%s result=%s"):format(tostring(ok), serialize(result)))
		task.wait(1)

		w("")
		w("-- LastOpen AFTER Open():")
		if typeof(merchantFeature.LastOpen) == "table" then
			local n = 0
			for _ in pairs(merchantFeature.LastOpen) do n += 1 end
			w(("LastOpen entries: %d"):format(n))
			for k, v in pairs(merchantFeature.LastOpen) do
				w(("  [%s] = %s"):format(tostring(k), serialize(v)))
				if typeof(v) == "table" then
					for k2, v2 in pairs(v) do
						if typeof(k2) == "string" or typeof(k2) == "number" then
							w(("    .%s = %s"):format(tostring(k2), serialize(v2)))
						end
					end
				end
			end
		end

		w("")
		w("-- PlayerGui after Open():")
		local playerGui = localPlayer:FindFirstChild("PlayerGui")
		if playerGui then
			for _, child in ipairs(playerGui:GetChildren()) do
				if child:IsA("ScreenGui") then
					w(("  %s (enabled=%s)"):format(child.Name, tostring(child.Enabled)))
				end
			end
			local machines = playerGui:FindFirstChild("_MACHINES")
			if machines then
				w("")
				w("-- _MACHINES children:")
				for _, child in ipairs(machines:GetChildren()) do
					w(("  %s (%s)"):format(child.Name, child.ClassName))
					if child.Name:lower():find("merchant") then
						w("    [MERCHANT MACHINE FOUND]")
						w("    Descendants:")
						for _, d in ipairs(child:GetDescendants()) do
							local extra = ""
							if d:IsA("TextButton") or d:IsA("ImageButton") then
								extra = (" [BUTTON]")
							elseif d:IsA("Frame") then
								extra = (" [FRAME]")
							end
							w(("      %s (%s)%s"):format(d.Name, d.ClassName, extra))
						end
					end
				end
			end
		end

		pcall(function() root.CFrame = originalCFrame end)
	end
end

flushSafe()

-- -----------------------------------------------------
-- MERCHANT_GETOFFERS AFTER OPEN
-- -----------------------------------------------------
sep("MERCHANT_GETOFFERS AFTER OPEN")
if CONFIG.TEST_OPEN then
	local combos = {
		{ label = "1.no-arg", args = {} },
		{ label = "2.merchantId", args = { "DiamondMountainMerchant" } },
		{ label = "3.merchantId,1", args = { "DiamondMountainMerchant", 1 } },
		{ label = "4.merchantId,camp", args = { "DiamondMountainMerchant", tostring(currentCamp or 1) } },
		{ label = "5.camp", args = { tostring(currentCamp or 1) } },
		{ label = "6.camp,1", args = { tostring(currentCamp or 1), 1 } },
		{ label = "7.number-camp", args = { currentCamp or 1 } },
		{ label = "8.number-camp,1", args = { currentCamp or 1, 1 } },
	}

	for _, combo in ipairs(combos) do
		local ok, result = invoke("Merchant_GetOffers", table.unpack(combo.args))
		w(("[%s] ok=%s type=%s"):format(combo.label, tostring(ok), typeof(result)))
		if ok and typeof(result) == "table" then
			for k, v in pairs(result) do
				w(("  [%s] = %s"):format(tostring(k), serialize(v)))
			end
		elseif ok and result ~= nil then
			w(("  result = %s"):format(serialize(result)))
		end
		task.wait(CONFIG.WAIT)
	end
end

flushSafe()

-- -----------------------------------------------------
-- MERCHANT_REQUESTPURCHASE
-- -----------------------------------------------------
sep("MERCHANT_REQUESTPURCHASE 20 COMBOS")
if CONFIG.TEST_PURCHASE then
	local merchantId = "DiamondMountainMerchant"
	local camp = currentCamp or 1

	local combos = {
		{ label = "1.merchantId", args = { merchantId } },
		{ label = "2.merchantId,1", args = { merchantId, 1 } },
		{ label = "3.merchantId,'1'", args = { merchantId, "1" } },
		{ label = "4.merchantId,1,1", args = { merchantId, 1, 1 } },
		{ label = "5.merchantId,'1',1", args = { merchantId, "1", 1 } },
		{ label = "6.merchantId,camp", args = { merchantId, tostring(camp) } },
		{ label = "7.merchantId,camp,1", args = { merchantId, tostring(camp), 1 } },
		{ label = "8.merchantId,camp,'1'", args = { merchantId, tostring(camp), "1" } },
		{ label = "9.camp,merchantId,1", args = { tostring(camp), merchantId, 1 } },
		{ label = "10.merchantId,{1}", args = { merchantId, { 1 } } },
		{ label = "11.merchantId,{1},1", args = { merchantId, { 1 }, 1 } },
		{ label = "12.merchantId,{Id=1}", args = { merchantId, { Id = 1 } } },
		{ label = "13.merchantId,{Slot=1}", args = { merchantId, { Slot = 1 } } },
		{ label = "14.merchantId,{Index=1}", args = { merchantId, { Index = 1 } } },
		{ label = "15.merchantId,{SlotIndex=1}", args = { merchantId, { SlotIndex = 1 } } },
		{ label = "16.merchantId,1,'Coins'", args = { merchantId, 1, "Coins" } },
		{ label = "17.merchantId,{slot=1,amount=1}", args = { merchantId, { slot = 1, amount = 1 } } },
		{ label = "18.merchantId,{Slot=1,Amount=1}", args = { merchantId, { Slot = 1, Amount = 1 } } },
		{ label = "19.merchantId,{Id=1,Amount=1}", args = { merchantId, { Id = 1, Amount = 1 } } },
		{ label = "20.merchantId,1,1,1", args = { merchantId, 1, 1, 1 } },
	}

	for _, combo in ipairs(combos) do
		local ok, result = invoke("Merchant_RequestPurchase", table.unpack(combo.args))
		w(("[%s] ok=%s result=%s"):format(combo.label, tostring(ok), serialize(result)))
		task.wait(CONFIG.WAIT)
	end
end

flushSafe()

-- -----------------------------------------------------
-- FEATURE.DEBUG() + LOOKATWAGON
-- -----------------------------------------------------
sep("FEATURE.DEBUG() + LOOKATWAGON()")
if merchantFeature then
	if CONFIG.TEST_DEBUG_FN and typeof(merchantFeature.Debug) == "function" then
		w("-- Calling Feature('Merchant').Debug()...")
		local ok, result = pcall(merchantFeature.Debug)
		w(("Debug() ok=%s result=%s"):format(tostring(ok), serialize(result)))
		task.wait(0.5)
	end

	if CONFIG.TEST_LOOKATWAGON and typeof(merchantFeature.LookAtWagon) == "function" then
		w("")
		w("-- Calling Feature('Merchant').LookAtWagon()...")
		local ok, result = pcall(merchantFeature.LookAtWagon)
		w(("LookAtWagon() ok=%s result=%s"):format(tostring(ok), serialize(result)))
		task.wait(0.5)
	end

	if typeof(merchantFeature.OnJoin) == "function" then
		w("")
		dumpFunction("Feature('Merchant').OnJoin", merchantFeature.OnJoin, 2)
	end
	if typeof(merchantFeature.OnLeave) == "function" then
		w("")
		dumpFunction("Feature('Merchant').OnLeave", merchantFeature.OnLeave, 2)
	end
end

flushSafe()

-- -----------------------------------------------------
-- FEATURE.NETWORKING FULL
-- -----------------------------------------------------
sep("FEATURE('Merchant').Networking FULL")
if merchantFeature and typeof(merchantFeature.Networking) == "table" then
	dumpTable("Feature('Merchant').Networking", merchantFeature.Networking, 1)
end

flushSafe()

-- -----------------------------------------------------
-- MACHINESCREENS MODULE
-- -----------------------------------------------------
sep("MACHINESCREENS MODULE")
local machineScreens = Modules.MachineScreens
if typeof(machineScreens) == "table" then
	dumpTable("MachineScreens", machineScreens, 2)
else
	w("MachineScreens:", typeof(machineScreens))
end

w("")
local machineCmds = Modules.MachineCmds
if typeof(machineCmds) == "table" then
	dumpTable("MachineCmds", machineCmds, 1)
else
	w("MachineCmds:", typeof(machineCmds))
end

flushSafe()

-- -----------------------------------------------------
-- MACHINESCREENS_GET REMOTE
-- -----------------------------------------------------
sep("MACHINESCREENS_GET REMOTE TEST")
if CONFIG.TEST_OPEN then
	local ids = {
		"DiamondMountainMerchant",
		"Merchant",
		tostring(currentCamp or 1),
		"TravelingMerchant",
		"DM_Merchant",
		"MerchantMachine",
	}

	for _, id in ipairs(ids) do
		local ok = fire("MachineScreens_Get", id)
		w(("MachineScreens_Get(%q) ok=%s"):format(id, tostring(ok)))
		task.wait(0.2)
	end

	w("")
	w("-- PlayerGui after MachineScreens_Get:")
	local playerGui = localPlayer:FindFirstChild("PlayerGui")
	if playerGui then
		for _, child in ipairs(playerGui:GetChildren()) do
			if child:IsA("ScreenGui") then
				w(("  %s (enabled=%s)"):format(child.Name, tostring(child.Enabled)))
			end
		end
	end
end

flushSafe()

-- -----------------------------------------------------
-- DIRECTORY.MERCHANTS DiamondMountainMerchant FULL
-- -----------------------------------------------------
sep("DIRECTORY.MERCHANTS.DiamondMountainMerchant")
local merchDir = Modules.MerchantsDir
if typeof(merchDir) == "table" then
	local dmMerchantDir = merchDir.DiamondMountainMerchant
	if typeof(dmMerchantDir) == "table" then
		dumpTable("DiamondMountainMerchant", dmMerchantDir, 2)
	else
		w("DiamondMountainMerchant dir:", typeof(dmMerchantDir))
	end
end

flushSafe()

-- -----------------------------------------------------
-- DIAMONDMOUNTAINCMDS.INSTANCE
-- -----------------------------------------------------
sep("DIAMONDMOUNTAINCMDS.Instance FULL")
if typeof(dmCmds) == "table" and typeof(dmCmds.Instance) == "function" then
	local ok, inst = pcall(dmCmds.Instance)
	if ok and typeof(inst) == "table" then
		dumpTable("Instance", inst, 1)

		if typeof(inst.InvokeCustom) == "function" then
			w("")
			dumpFunction("Instance.InvokeCustom", inst.InvokeCustom, 2)
		end
		if typeof(inst.FireCustom) == "function" then
			w("")
			dumpFunction("Instance.FireCustom", inst.FireCustom, 2)
		end
	end
end

flushSafe()

-- -----------------------------------------------------
-- MERCHANT_UTIL / TRAVELINGMERCHANTUTIL
-- -----------------------------------------------------
sep("MERCHANT_UTIL + TRAVELINGMERCHANTUTIL")
if typeof(Modules.MerchantUtil) == "table" then
	dumpTable("MerchantUtil", Modules.MerchantUtil, 1)
end
w("")
if typeof(Modules.TravelingMerchantUtil) == "table" then
	dumpTable("TravelingMerchantUtil", Modules.TravelingMerchantUtil, 1)
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
w("Current camp:", tostring(currentCamp))
w("Merchant part:", merchantPart and merchantPart:GetFullName() or "nil")
w("Feature('Merchant'):", merchantFeature ~= nil)
if merchantFeature and typeof(merchantFeature.LastOpen) == "table" then
	local n = 0
	for _ in pairs(merchantFeature.LastOpen) do n += 1 end
	w("LastOpen entries:", n)
end

flush()
