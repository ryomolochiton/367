-- =====================================================
-- VRT DIAGNOSTIC v1.0
-- Dump toàn bộ debug info -> VRT/VRT_Diag.txt
-- Chạy độc lập, không cần VRT Hub đang chạy
-- =====================================================

local playersService = game:GetService("Players")
local replicatedStorage = game:GetService("ReplicatedStorage")

local localPlayer = playersService.LocalPlayer

local DIAG_FOLDER = "VRT"
local DIAG_PATH = "VRT/VRT_Diag.txt"

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
	if depth > 5 then return "..." end
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
		return string.format("Vector3(%.1f, %.1f, %.1f)", value.X, value.Y, value.Z)
	elseif t == "Vector2" then
		return string.format("Vector2(%.1f, %.1f)", value.X, value.Y)
	elseif t == "CFrame" then
		local p = value.Position
		return string.format("CFrame(%.1f, %.1f, %.1f)", p.X, p.Y, p.Z)
	elseif t == "Color3" then
		return string.format("Color3(%d, %d, %d)", value.R * 255, value.G * 255, value.B * 255)
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
			if count > 40 then
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

-- -----------------------------------------------------
-- Module dump
-- -----------------------------------------------------
local function dumpModule(name, mod, maxDepth)
	maxDepth = maxDepth or 1
	if typeof(mod) ~= "table" then
		w(("[%s] type = %s | value = %s"):format(name, typeof(mod), serialize(mod)))
		return
	end
	w(("[%s] type = table"):format(name))
	local keys = {}
	for k in pairs(mod) do
		keys[#keys + 1] = k
	end
	table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
	for _, k in ipairs(keys) do
		local v = mod[k]
		local tv = typeof(v)
		w(("  .%-32s = %s"):format(tostring(k), tv))
		if tv == "function" then
			local info = debug.getinfo(v)
			if info then
				w(("      what=%s nups=%d params=%d vararg=%s"):format(
					tostring(info.what), info.nups or 0,
					info.numparams or 0, tostring(info.is_vararg)
				))
			end
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
		elseif tv == "table" and maxDepth > 0 then
			local n = 0
			for _ in pairs(v) do n += 1 end
			w(("      table(%d)"):format(n))
			local subkeys = {}
			for sk in pairs(v) do subkeys[#subkeys + 1] = sk end
			table.sort(subkeys, function(a, b) return tostring(a) < tostring(b) end)
			local shown = 0
			for _, sk in ipairs(subkeys) do
				if shown >= 25 then
					w("      ...")
					break
				end
				shown += 1
				local sv = v[sk]
				w(("      [%s] = %s"):format(tostring(sk), serialize(sv)))
			end
		end
	end
end

local function safeRequire(inst)
	if not inst or typeof(inst) ~= "Instance" then return nil, "not Instance" end
	local ok, res = pcall(require, inst)
	if ok then return res end
	return nil, tostring(res)
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

-- -----------------------------------------------------
-- FOLDERS
-- -----------------------------------------------------
sep("FOLDERS")
local libraryFolder = replicatedStorage:FindFirstChild("Library")
local clientFolder = libraryFolder and libraryFolder:FindFirstChild("Client")
local directoryFolder = libraryFolder and libraryFolder:FindFirstChild("Directory")
local utilFolder = libraryFolder and libraryFolder:FindFirstChild("Util")
local itemsFolder = libraryFolder and libraryFolder:FindFirstChild("Items")
local networkFolder = replicatedStorage:FindFirstChild("Network")
local directFolder = replicatedStorage:FindFirstChild("__DIRECTORY")

w("Library:", tostring(libraryFolder ~= nil))
w("Library.Client:", tostring(clientFolder ~= nil))
w("Library.Directory:", tostring(directoryFolder ~= nil))
w("Library.Util:", tostring(utilFolder ~= nil))
w("Library.Items:", tostring(itemsFolder ~= nil))
w("ReplicatedStorage.Network:", tostring(networkFolder ~= nil))
w("ReplicatedStorage.__DIRECTORY:", tostring(directFolder ~= nil))

if clientFolder then
	w("")
	w("-- Library.Client children:")
	for _, c in ipairs(clientFolder:GetChildren()) do
		w(("  %-32s %s"):format(c.Name, c.ClassName))
	end
end

if directoryFolder then
	w("")
	w("-- Library.Directory children:")
	for _, c in ipairs(directoryFolder:GetChildren()) do
		w(("  %-32s %s"):format(c.Name, c.ClassName))
	end
end

if utilFolder then
	w("")
	w("-- Library.Util children:")
	for _, c in ipairs(utilFolder:GetChildren()) do
		w(("  %-32s %s"):format(c.Name, c.ClassName))
	end
end

if directFolder then
	w("")
	w("-- __DIRECTORY children:")
	for _, c in ipairs(directFolder:GetChildren()) do
		local count = "-"
		if c:IsA("Folder") then count = tostring(#c:GetChildren()) end
		w(("  %-32s %s (%s)"):format(c.Name, c.ClassName, count))
	end
end

-- -----------------------------------------------------
-- NETWORK
-- -----------------------------------------------------
sep("NETWORK FOLDER")
if networkFolder then
	local children = networkFolder:GetChildren()
	w("Total children:", #children)
	w("")
	table.sort(children, function(a, b) return a.Name < b.Name end)
	for _, c in ipairs(children) do
		w(("  %-50s %s"):format(c.Name, c.ClassName))
	end
else
	w("Network folder NOT FOUND")
end

sep("MODULES.Network")
local networkMod, networkErr = safeRequire(clientFolder and clientFolder:FindFirstChild("Network"))
if networkMod then
	local keys = {}
	for k in pairs(networkMod) do keys[#keys + 1] = k end
	table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
	w("Keys:", #keys)
	for _, k in ipairs(keys) do
		w(("  .%-30s = %s"):format(tostring(k), typeof(networkMod[k])))
	end
else
	w("require(Network) failed:", tostring(networkErr))
end

-- -----------------------------------------------------
-- INSTANCE INFO
-- -----------------------------------------------------
sep("INSTANCE INFO (MapCmds)")
local mapCmds, mapErr = safeRequire(clientFolder and clientFolder:FindFirstChild("MapCmds"))
if mapCmds then
	dumpModule("MapCmds", mapCmds, 0)
	if mapCmds.GetCurrentInstanceInfo then
		local ok, info = pcall(mapCmds.GetCurrentInstanceInfo)
		w("")
		w("GetCurrentInstanceInfo ok=", ok)
		if ok and type(info) == "table" then
			for k, v in pairs(info) do
				w(("  %s = %s"):format(tostring(k), serialize(v)))
			end
		end
	end
	if mapCmds.GetCurrentZone then
		local ok, zone = pcall(mapCmds.GetCurrentZone)
		w("GetCurrentZone ok=", ok, "value=", serialize(zone))
	end
else
	w("require(MapCmds) failed:", tostring(mapErr))
end

-- -----------------------------------------------------
-- FLAG
-- -----------------------------------------------------
sep("FLAG - FlexibleFlagCmds")
local flagCmds, flagErr = safeRequire(clientFolder and clientFolder:FindFirstChild("FlexibleFlagCmds"))
if flagCmds then
	dumpModule("FlexibleFlagCmds", flagCmds, 2)
	w("")
	w("-- Deep search for 'Consume':")
	local function deepFind(root, name, depth, path)
		depth = depth or 0
		path = path or "root"
		if depth > 5 or typeof(root) ~= "table" then return nil end
		if typeof(root[name]) == "function" then
			return root[name], path .. "." .. name
		end
		for k, v in pairs(root) do
			if typeof(v) == "table" then
				local fn, p = deepFind(v, name, depth + 1, path .. "." .. tostring(k))
				if fn then return fn, p end
			end
		end
		return nil
	end
	local consumeFn, consumePath = deepFind(flagCmds, "Consume")
	w("Consume found:", tostring(consumeFn ~= nil), "path:", tostring(consumePath))
	if consumeFn then
		local info = debug.getinfo(consumeFn)
		w("  what:", info and info.what, "nups:", info and info.nups, "params:", info and info.numparams)
		local ok, ups = pcall(debug.getupvalues, consumeFn)
		if ok then
			for i, uv in pairs(ups) do
				w(("  up[%d] = %s"):format(i, serialize(uv)))
			end
		end
	end
else
	w("require(FlexibleFlagCmds) failed:", tostring(flagErr))
end

sep("FLAG - FlagUtil")
local flagUtil, flagUtilErr = safeRequire(utilFolder and utilFolder:FindFirstChild("FlagUtil"))
if flagUtil then
	dumpModule("FlagUtil", flagUtil, 1)
	if flagUtil.computeMaxFlags then
		local ok, v = pcall(flagUtil.computeMaxFlags)
		w("computeMaxFlags ok=", ok, "value=", serialize(v))
	end
else
	w("require(FlagUtil) failed:", tostring(flagUtilErr))
end

sep("FLAG - Directory.ZoneFlags")
local zoneFlags, zfErr = safeRequire(directoryFolder and directoryFolder:FindFirstChild("ZoneFlags"))
if zoneFlags then
	dumpModule("ZoneFlags", zoneFlags, 1)
else
	w("require(ZoneFlags) failed:", tostring(zfErr))
end

sep("FLAG - Inventory entries (contains 'flag')")
local saveMod, saveErr = safeRequire(clientFolder and clientFolder:FindFirstChild("Save"))
if saveMod and saveMod.Get then
	local ok, save = pcall(saveMod.Get)
	if ok and type(save) == "table" and type(save.Inventory) == "table" then
		for bucketName, bucket in pairs(save.Inventory) do
			if type(bucket) == "table" then
				local hits = {}
				for uid, entry in pairs(bucket) do
					if type(entry) == "table" and type(entry.id) == "string" then
						if entry.id:lower():find("flag", 1, true) then
							hits[#hits + 1] = {
								uid = uid,
								id = entry.id,
								am = entry._am,
							}
						end
					end
				end
				if #hits > 0 then
					w(("Bucket [%s] - %d flag entries:"):format(bucketName, #hits))
					for _, h in ipairs(hits) do
						w(("  uid=%s id=%q am=%s"):format(
							tostring(h.uid), tostring(h.id), tostring(h.am)
						))
					end
				end
			end
		end
	else
		w("Save.Get failed or empty")
	end
else
	w("require(Save) failed:", tostring(saveErr))
end

-- -----------------------------------------------------
-- MERCHANT
-- -----------------------------------------------------
sep("MERCHANT SEARCH")
do
	local things = workspace:FindFirstChild("__THINGS")
	w("__THINGS:", tostring(things ~= nil))

	local function scan(container, label)
		if not container then
			w(("[%s] nil"):format(label))
			return
		end
		local found = 0
		for _, d in ipairs(container:GetDescendants()) do
			if d.Name:lower():find("merchant", 1, true) then
				if d:IsA("Model") or d:IsA("BasePart") then
					found += 1
					local part = d:IsA("BasePart") and d or d:FindFirstChildWhichIsA("BasePart", true)
					local posStr = "nil"
					if part then
						posStr = string.format("%.1f, %.1f, %.1f",
							part.Position.X, part.Position.Y, part.Position.Z)
					end
					w(("[%s] %s (%s) pos=%s"):format(label, d:GetFullName(), d.ClassName, posStr))
					local okAttr, attrs = pcall(function() return d:GetAttributes() end)
					if okAttr and type(attrs) == "table" then
						for k, v in pairs(attrs) do
							w(("    attr %s = %s"):format(tostring(k), serialize(v)))
						end
					end
					for _, desc in ipairs(d:GetDescendants()) do
						if desc:IsA("ProximityPrompt") then
							w(("    ProximityPrompt: %s enabled=%s actionText=%q"):format(
								desc:GetFullName(), tostring(desc.Enabled), tostring(desc.ActionText)
							))
						end
					end
				end
			end
		end
		w(("[%s] total: %d"):format(label, found))
	end

	if things then
		local container = things:FindFirstChild("__INSTANCE_CONTAINER")
		local active = container and container:FindFirstChild("Active")
		scan(active, "Active")
		local instances = things:FindFirstChild("Instances")
		scan(instances, "Instances")
		local dm = instances and instances:FindFirstChild("DiamondMountain")
		if dm then
			w("")
			w("-- DiamondMountain instance children:")
			for _, c in ipairs(dm:GetChildren()) do
				w(("  %-40s %s"):format(c.Name, c.ClassName))
			end
		end
	end
end

-- -----------------------------------------------------
-- FRUIT
-- -----------------------------------------------------
sep("FRUIT - FruitCmds")
local fruitCmds, fruitErr = safeRequire(clientFolder and clientFolder:FindFirstChild("FruitCmds"))
if fruitCmds then
	dumpModule("FruitCmds", fruitCmds, 2)
	w("")
	if fruitCmds.ComputeFruitQueueLimit then
		local ok, v = pcall(fruitCmds.ComputeFruitQueueLimit)
		w("ComputeFruitQueueLimit ok=", ok, "value=", serialize(v))
	end
	if fruitCmds.GetActiveFruits then
		local ok, active = pcall(fruitCmds.GetActiveFruits)
		w("GetActiveFruits ok=", ok, "type=", typeof(active))
		if ok and type(active) == "table" then
			for k, v in pairs(active) do
				w(("  [%s] = %s"):format(tostring(k), typeof(v)))
				if type(v) == "table" then
					for k2, v2 in pairs(v) do
						w(("    .%s = %s"):format(tostring(k2), typeof(v2)))
						if type(v2) == "table" then
							w(("      # = %d"):format(#v2))
							local shown = 0
							for i, item in ipairs(v2) do
								if shown >= 3 then break end
								shown += 1
								w(("      [%d] = %s"):format(i, serialize(item)))
							end
						else
							w(("      = %s"):format(serialize(v2)))
						end
					end
				end
			end
		end
	end
	if fruitCmds.Consume then
		local info = debug.getinfo(fruitCmds.Consume)
		w("Consume: what=", info and info.what, "nups=", info and info.nups,
			"params=", info and info.numparams)
		local ok, ups = pcall(debug.getupvalues, fruitCmds.Consume)
		if ok then
			for i, uv in pairs(ups) do
				w(("  up[%d] = %s"):format(i, serialize(uv)))
			end
		end
	end
else
	w("require(FruitCmds) failed:", tostring(fruitErr))
end

sep("FRUIT - Inventory")
if saveMod and saveMod.Get then
	local ok, save = pcall(saveMod.Get)
	if ok and type(save) == "table" and type(save.Inventory) == "table" then
		local fruitBucket = save.Inventory.Fruit
		if type(fruitBucket) == "table" then
			local n = 0
			local shown = 0
			for uid, entry in pairs(fruitBucket) do
				n += 1
				if shown < 30 then
					shown += 1
					w(("  uid=%s entry=%s"):format(tostring(uid), serialize(entry)))
				end
			end
			w("Total Fruit entries:", n)
		else
			w("Inventory.Fruit is not a table")
		end
	end
end

-- -----------------------------------------------------
-- CUSTOM EGGS
-- -----------------------------------------------------
sep("CUSTOM EGGS - CustomEggsCmds")
local customCmds, customErr = safeRequire(clientFolder and clientFolder:FindFirstChild("CustomEggsCmds"))
if customCmds then
	dumpModule("CustomEggsCmds", customCmds, 2)
else
	w("require(CustomEggsCmds) failed:", tostring(customErr))
end

sep("CUSTOM EGGS - World models")
do
	local things = workspace:FindFirstChild("__THINGS")
	local folder = things and things:FindFirstChild("CustomEggs")
	if folder then
		local children = folder:GetChildren()
		w("CustomEggs folder children:", #children)
		for _, m in ipairs(children) do
			local eggPart = m:FindFirstChild("Egg")
			local posStr = "nil"
			if eggPart and eggPart:IsA("BasePart") then
				posStr = string.format("%.1f, %.1f, %.1f",
					eggPart.Position.X, eggPart.Position.Y, eggPart.Position.Z)
			end
			w(("  %s (%s) eggPart=%s pos=%s"):format(
				m.Name, m.ClassName, tostring(eggPart ~= nil), posStr
			))
		end
	else
		w("__THINGS.CustomEggs NOT FOUND")
	end
end

-- -----------------------------------------------------
-- EGG CMDS
-- -----------------------------------------------------
sep("EGG - EggCmds")
local eggCmds, eggErr = safeRequire(clientFolder and clientFolder:FindFirstChild("EggCmds"))
if eggCmds then
	dumpModule("EggCmds", eggCmds, 1)
	if eggCmds.GetMaxHatch then
		local ok, v = pcall(eggCmds.GetMaxHatch)
		w("GetMaxHatch ok=", ok, "value=", serialize(v))
	end
else
	w("require(EggCmds) failed:", tostring(eggErr))
end

-- -----------------------------------------------------
-- DIRECTORY.EGGS
-- -----------------------------------------------------
sep("DIRECTORY.Eggs")
local eggsDir, eggsErr = safeRequire(directoryFolder and directoryFolder:FindFirstChild("Eggs"))
if eggsDir then
	local count = 0
	local maxNum = 0
	local samples = {}
	for _, egg in pairs(eggsDir) do
		if type(egg) == "table" then
			count += 1
			if egg.eggNumber and egg.eggNumber > maxNum then
				maxNum = egg.eggNumber
			end
			if #samples < 5 then
				samples[#samples + 1] = egg
			end
		end
	end
	w("Total eggs:", count)
	w("Max eggNumber:", maxNum)
	w("")
	w("-- Sample entries:")
	for _, egg in ipairs(samples) do
		w("  " .. serialize(egg))
	end
else
	w("require(Eggs) failed:", tostring(eggsErr))
end

-- -----------------------------------------------------
-- __THINGS
-- -----------------------------------------------------
sep("WORKSPACE.__THINGS")
do
	local things = workspace:FindFirstChild("__THINGS")
	if things then
		for _, c in ipairs(things:GetChildren()) do
			local count = "-"
			if c:IsA("Folder") or c:IsA("Model") then
				count = tostring(#c:GetChildren())
			end
			w(("  %-40s %s (%s)"):format(c.Name, c.ClassName, count))
		end
	else
		w("__THINGS NOT FOUND")
	end
end

-- -----------------------------------------------------
-- PETS
-- -----------------------------------------------------
sep("PETS")
local petCmds, petErr = safeRequire(clientFolder and clientFolder:FindFirstChild("PlayerPet"))
if petCmds then
	dumpModule("PlayerPet", petCmds, 1)
	if petCmds.GetAll then
		local ok, pets = pcall(petCmds.GetAll)
		if ok and type(pets) == "table" then
			local n = 0
			local owned = 0
			for _, pet in pairs(pets) do
				n += 1
				if type(pet) == "table" and pet.owner == localPlayer then
					owned += 1
				end
			end
			w("Total pets:", n, "| owned by me:", owned)
		end
	end
else
	w("require(PlayerPet) failed:", tostring(petErr))
end

-- -----------------------------------------------------
-- SUMMARY
-- -----------------------------------------------------
sep("SUMMARY")
w("Diagnostic complete.")
w("File:", DIAG_PATH)
w("Lines:", #lines)

flush()
