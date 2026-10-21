-- =====================================================
-- VRT EXPEDITION DIAGNOSTIC v2 — Save to file (bulletproof)
-- Save -> VRT/VRT_Expedition.txt
-- Mỗi section đều flush ngay, lỗi 1 section không ảnh hưởng section khác
-- CHẠY KHI ĐANG Ở TRONG DIAMOND MOUNTAIN
-- =====================================================

local playersService = game:GetService("Players")
local replicatedStorage = game:GetService("ReplicatedStorage")

local localPlayer = playersService.LocalPlayer
local libraryFolder = replicatedStorage:WaitForChild("Library")
local clientFolder = libraryFolder:WaitForChild("Client")
local utilFolder = libraryFolder:FindFirstChild("Util")
local networkFolder = replicatedStorage:FindFirstChild("Network")

local DIAG_FOLDER = "VRT"
local DIAG_PATH = "VRT/VRT_Expedition.txt"

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
		print(("[VRT-DIAG] Saved -> %s (%d bytes, %d lines)"):format(
			DIAG_PATH, #content, #lines
		))
		return true
	else
		warn("[VRT-DIAG] writefile failed: " .. tostring(err))
		pcall(setclipboard, content)
		print("[VRT-DIAG] Copied to clipboard instead.")
		return false
	end
end

local function safeRequire(inst)
	if not inst or typeof(inst) ~= "Instance" then return nil end
	local ok, res = pcall(require, inst)
	return ok and res or nil
end

local function getRoot()
	local character = localPlayer.Character
	return character and character:FindFirstChild("HumanoidRootPart") or nil
end

local function serialize(value, depth, seen)
	depth = depth or 0
	seen = seen or {}
	if depth > 4 then return "..." end
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
			if count > 30 then
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

local function dumpFunction(label, fn, upDepth)
	upDepth = upDepth or 1
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
	if upDepth > 0 then
		local ok, ups = pcall(debug.getupvalues, fn)
		if ok and typeof(ups) == "table" then
			for i, uv in pairs(ups) do
				local tuv = typeof(uv)
				if tuv == "table" then
					local n = 0
					for _ in pairs(uv) do n += 1 end
					w(("  up[%d] = table(%d)"):format(i, n))
					if upDepth > 1 then
						local subkeys = {}
						for sk in pairs(uv) do subkeys[#subkeys + 1] = sk end
						table.sort(subkeys, function(a, b) return tostring(a) < tostring(b) end)
						local shown = 0
						for _, sk in ipairs(subkeys) do
							if shown >= 20 then
								w("      ...")
								break
							end
							shown += 1
							w(("      [%s] = %s"):format(tostring(sk), serialize(uv[sk])))
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

-- Wrap section in pcall để 1 section lỗi không kill cả script
local function section(name, fn)
	sep(name)
	local ok, err = pcall(fn)
	if not ok then
		w(("[ERROR] " .. tostring(err)))
	end
	flush()
end

-- -----------------------------------------------------
-- HEADER
-- -----------------------------------------------------
section("HEADER", function()
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
	w("Save path:", DIAG_PATH)
end)

-- -----------------------------------------------------
-- MODULES
-- -----------------------------------------------------
local Modules = {
	Network = safeRequire(clientFolder:FindFirstChild("Network")),
	DiamondMountainCmds = safeRequire(clientFolder:FindFirstChild("DiamondMountainCmds")),
	MachineScreens = safeRequire(clientFolder:FindFirstChild("MachineScreens")),
	MachineCmds = safeRequire(clientFolder:FindFirstChild("MachineCmds")),
}

-- -----------------------------------------------------
-- EXPEDITION STRUCTURE
-- -----------------------------------------------------
local expedition = nil
local mountain = nil
local summit = nil

section("EXPEDITION STRUCTURE", function()
	local things = workspace:FindFirstChild("__THINGS")
	local container = things and things:FindFirstChild("__INSTANCE_CONTAINER")
	local active = container and container:FindFirstChild("Active")
	mountain = active and active:FindFirstChild("DiamondMountain")
	summit = mountain and mountain:FindFirstChild("Summit")
	expedition = summit and summit:FindFirstChild("Expedition")

	if not expedition then
		w("Expedition NOT FOUND")
		return
	end

	w(("Expedition: %s"):format(expedition:GetFullName()))
	w("")
	w("-- Expedition children:")
	for _, child in ipairs(expedition:GetChildren()) do
		local extra = ""
		if child:IsA("BasePart") then
			extra = (" pos=%.1f,%.1f,%.1f"):format(
				child.Position.X, child.Position.Y, child.Position.Z
			)
		elseif child:IsA("Model") then
			local okP, pivot = pcall(function() return child:GetPivot() end)
			if okP and pivot then
				extra = (" pivot=%.1f,%.1f,%.1f"):format(
					pivot.Position.X, pivot.Position.Y, pivot.Position.Z
				)
			end
		end
		w(("  %s (%s)%s"):format(child.Name, child.ClassName, extra))
		w("    Attributes:")
		local attrs = child:GetAttributes()
		local n = 0
		for k, v in pairs(attrs) do
			n += 1
			w(("      %s = %s"):format(tostring(k), serialize(v)))
		end
		if n == 0 then w("      (none)") end
	end
end)

-- -----------------------------------------------------
-- CLAIMPILLAR STRUCTURE
-- -----------------------------------------------------
section("CLAIMPILLAR STRUCTURE", function()
	if not expedition then
		w("Expedition not found")
		return
	end
	local claim = expedition:FindFirstChild("ClaimPillar")
	if not claim then
		w("ClaimPillar NOT FOUND")
		return
	end

	w(("ClaimPillar: %s (%s)"):format(claim:GetFullName(), claim.ClassName))
	w("")
	w("-- ALL descendants:")
	for _, d in ipairs(claim:GetDescendants()) do
		local extra = ""
		if d:IsA("BasePart") then
			extra = (" pos=%.1f,%.1f,%.1f size=%.1f,%.1f,%.1f transparency=%.2f"):format(
				d.Position.X, d.Position.Y, d.Position.Z,
				d.Size.X, d.Size.Y, d.Size.Z,
				d.Transparency
			)
		elseif d:IsA("ProximityPrompt") then
			extra = (" enabled=%s actionText=%q objectText=%q holdDuration=%.1f maxDist=%.1f"):format(
				tostring(d.Enabled), tostring(d.ActionText),
				tostring(d.ObjectText), d.HoldDuration, d.MaxActivationDistance
			)
		elseif d:IsA("ClickDetector") then
			extra = (" MaxActivationDistance=%.1f"):format(d.MaxActivationDistance)
		elseif d:IsA("TextButton") or d:IsA("ImageButton") then
			extra = (" Visible=%s Active=%s"):format(tostring(d.Visible), tostring(d.Active))
		elseif d:IsA("BillboardGui") then
			extra = (" Enabled=%s"):format(tostring(d.Enabled))
		elseif d:IsA("SurfaceGui") then
			extra = (" Enabled=%s"):format(tostring(d.Enabled))
		end
		w(("  %s (%s)%s"):format(d.Name, d.ClassName, extra))
	end

	w("")
	w("-- ClaimPillar attributes:")
	local n = 0
	for k, v in pairs(claim:GetAttributes()) do
		n += 1
		w(("  %s = %s"):format(tostring(k), serialize(v)))
	end
	if n == 0 then w("  (none)") end
end)

-- -----------------------------------------------------
-- FEATURE('Expedition')
-- -----------------------------------------------------
local expeditionFeature = nil

section("FEATURE('Expedition') FULL DUMP", function()
	local dmCmds = Modules.DiamondMountainCmds
	if not dmCmds or typeof(dmCmds.Feature) ~= "function" then
		w("DiamondMountainCmds not available")
		return
	end

	w("DiamondMountainCmds.FEATURES:", dmCmds.FEATURES and table.concat(dmCmds.FEATURES, ",") or "nil")
	w("")

	local ok, feature = pcall(dmCmds.Feature, "Expedition")
	if not ok or typeof(feature) ~= "table" then
		w("Feature('Expedition') failed:", tostring(feature))
		return
	end

	expeditionFeature = feature
	local keys = {}
	for k in pairs(feature) do keys[#keys + 1] = k end
	table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
	w(("Feature('Expedition') table(%d)"):format(#keys))
	for _, k in ipairs(keys) do
		local v = feature[k]
		if typeof(v) == "function" then
			dumpFunction("  ." .. tostring(k), v, 2)
		elseif typeof(v) == "table" then
			local n = 0
			for _ in pairs(v) do n += 1 end
			w(("  .%s = table(%d)"):format(tostring(k), n))
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
				w(("      [%s] = %s"):format(tostring(sk), serialize(v[sk])))
			end
		else
			w(("  .%s = %s"):format(tostring(k), serialize(v)))
		end
	end
end)

-- -----------------------------------------------------
-- TRIP STATE
-- -----------------------------------------------------
section("TRIP STATE (Pedestals)", function()
	if not expedition then
		w("Expedition not found")
		return
	end
	for _, name in ipairs({ "Pedestal1", "Pedestal2", "Pedestal3", "Pedestal4" }) do
		local ped = expedition:FindFirstChild(name)
		if ped then
			w(("%s:"):format(name))
			for _, d in ipairs(ped:GetDescendants()) do
				if d:IsA("BasePart") then
					w(("  %s pos=%.1f,%.1f,%.1f transparency=%.2f"):format(
						d.Name, d.Position.X, d.Position.Y, d.Position.Z,
						d.Transparency
					))
				elseif d:IsA("ProximityPrompt") then
					w(("  %s [PROMPT] enabled=%s actionText=%q"):format(
						d.Name, tostring(d.Enabled), tostring(d.ActionText)
					))
				elseif d:IsA("ClickDetector") then
					w(("  %s [CLICK]"):format(d.Name))
				elseif d:IsA("BillboardGui") or d:IsA("SurfaceGui") then
					w(("  %s [GUI] enabled=%s"):format(d.Name, tostring(d.Enabled)))
				end
			end
			w(("  Attributes:"))
			local n = 0
			for k, v in pairs(ped:GetAttributes()) do
				n += 1
				w(("    %s = %s"):format(tostring(k), serialize(v)))
			end
			if n == 0 then w("    (none)") end
		end
	end
end)

-- -----------------------------------------------------
-- TEST 1: FEATURE METHODS (no args)
-- -----------------------------------------------------
section("TEST 1 — FEATURE METHODS (no args)", function()
	if not expeditionFeature then
		w("No feature")
		return
	end
	local methods = {
		"Claim", "ClaimAll", "ClaimRewards", "Collect", "CollectAll",
		"ClaimExpedition", "ClaimTrip", "ClaimTrips", "ClaimAllTrips",
		"GetTrips", "GetExpeditions", "GetState", "GetStatus", "GetData",
		"GetClaimable", "HasClaimable", "CanClaim", "IsClaimable",
		"Open", "Close",
	}
	for _, name in ipairs(methods) do
		if typeof(expeditionFeature[name]) == "function" then
			local ok, result = pcall(expeditionFeature[name])
			w(("[%s] ok=%s result=%s"):format(name, tostring(ok), serialize(result)))
			task.wait(0.2)
		end
	end
end)

-- -----------------------------------------------------
-- TEST 2: FEATURE METHODS (with args)
-- -----------------------------------------------------
section("TEST 2 — FEATURE METHODS (with args)", function()
	if not expeditionFeature then
		w("No feature")
		return
	end
	local args = { 1, 0, true, "1" }
	for _, name in ipairs({ "Claim", "ClaimTrip", "GetTrip", "GetExpedition" }) do
		if typeof(expeditionFeature[name]) == "function" then
			for _, arg in ipairs(args) do
				local ok, result = pcall(expeditionFeature[name], arg)
				w(("[%s(%s)] ok=%s result=%s"):format(
					name, serialize(arg), tostring(ok), serialize(result)
				))
				task.wait(0.15)
			end
		end
	end
end)

-- -----------------------------------------------------
-- TEST 3: REMOTES
-- -----------------------------------------------------
section("TEST 3 — REMOTE NAMES", function()
	if not networkFolder then
		w("Network folder not found")
		return
	end
	local candidates = {
		"Expedition_Claim", "Expedition_ClaimAll", "Expedition_Collect",
		"Expedition_Get", "Expedition_Request", "Expedition_Start",
		"DM_Expedition_Claim", "DM_Expedition_Get",
		"ClaimExpedition", "ClaimTrip", "ClaimExpeditions",
		"DiamondMountain_ExpeditionClaim",
		"EventUpgrades: Purchase",
		"Instancing_InvokeCustomFromClient",
		"Instancing_FireCustomFromClient",
	}

	w("-- Checking which remotes exist:")
	for _, name in ipairs(candidates) do
		local remote = networkFolder:FindFirstChild(name)
		w(("  %s -> %s"):format(name, remote and remote.ClassName or "NOT FOUND"))
	end

	w("")
	w("-- Searching Network folder for 'expedition'/'trip'/'dm_':")
	for _, child in ipairs(networkFolder:GetChildren()) do
		local lower = child.Name:lower()
		if lower:find("expedition") or lower:find("trip") or lower:find("dm_") then
			w(("  %s (%s)"):format(child.Name, child.ClassName))
		end
	end
end)

-- -----------------------------------------------------
-- TEST 4: INVOKE CUSTOM
-- -----------------------------------------------------
section("TEST 4 — INSTANCE.INVOKECUSTOM", function()
	local dmCmds = Modules.DiamondMountainCmds
	if not dmCmds or typeof(dmCmds.Instance) ~= "function" then
		w("Instance not available")
		return
	end
	local okI, inst = pcall(dmCmds.Instance)
	if not okI or typeof(inst) ~= "table" or typeof(inst.InvokeCustom) ~= "function" then
		w("InvokeCustom not available")
		return
	end

	local keys = {
		"ExpeditionClaim", "Expedition:Claim", "ClaimExpedition",
		"Expedition_Claim", "ClaimTrip", "TripClaim",
		"Expedition", "Claim",
	}
	for _, key in ipairs(keys) do
		local ok, result = pcall(inst.InvokeCustom, key)
		w(("[InvokeCustom(%q)] ok=%s result=%s"):format(
			key, tostring(ok), serialize(result)
		))
		task.wait(0.2)
	end
end)

-- -----------------------------------------------------
-- TEST 5: MACHINESCREENS
-- -----------------------------------------------------
section("TEST 5 — MACHINESCREENS", function()
	local machineScreens = Modules.MachineScreens
	if not machineScreens then
		w("MachineScreens not available")
		return
	end
	local ids = {
		"DiamondMountainExpeditionMachine", "ExpeditionMachine",
		"Expedition", "DM_Expedition", "ExpeditionMachine_1",
	}
	for _, id in ipairs(ids) do
		if typeof(machineScreens.Get) == "function" then
			local ok, result = pcall(machineScreens.Get, id)
			w(("[Get(%q)] ok=%s result=%s"):format(id, tostring(ok), serialize(result)))
		end
		if typeof(machineScreens.Has) == "function" then
			local ok, result = pcall(machineScreens.Has, id)
			w(("[Has(%q)] ok=%s result=%s"):format(id, tostring(ok), serialize(result)))
		end
		if typeof(machineScreens.IsHere) == "function" then
			local ok, result = pcall(machineScreens.IsHere, id)
			w(("[IsHere(%q)] ok=%s result=%s"):format(id, tostring(ok), serialize(result)))
		end
		task.wait(0.1)
	end
end)

-- -----------------------------------------------------
-- TEST 6: MACHINECMDS
-- -----------------------------------------------------
section("TEST 6 — MACHINECMDS", function()
	local machineCmds = Modules.MachineCmds
	if not machineCmds then
		w("MachineCmds not available")
		return
	end
	local ids = { "DiamondMountainExpeditionMachine", "ExpeditionMachine", "Expedition" }
	for _, id in ipairs(ids) do
		for _, method in ipairs({ "IsStandingOn", "CanUse", "AllowOpen", "IsAllowedToOpen", "GetUI", "GetModels" }) do
			if typeof(machineCmds[method]) == "function" then
				local ok, result = pcall(machineCmds[method], id)
				w(("[%s(%q)] ok=%s result=%s"):format(
					method, id, tostring(ok), serialize(result)
				))
			end
		end
		task.wait(0.1)
	end
end)

-- -----------------------------------------------------
-- TEST 7: UI SCAN
-- -----------------------------------------------------
section("TEST 7 — UI SCAN (_MACHINES)", function()
	local playerGui = localPlayer:FindFirstChild("PlayerGui")
	local machines = playerGui and playerGui:FindFirstChild("_MACHINES")
	if not machines then
		w("_MACHINES not found")
		return
	end
	w("-- _MACHINES children:")
	for _, child in ipairs(machines:GetChildren()) do
		w(("  %s (%s) enabled=%s"):format(
			child.Name, child.ClassName,
			child:IsA("ScreenGui") and tostring(child.Enabled) or "n/a"
		))
		if child.Name:lower():find("expedition") or child.Name:lower():find("trip") then
			w("    [EXPEDITION UI FOUND]")
			for _, d in ipairs(child:GetDescendants()) do
				if d:IsA("TextButton") or d:IsA("ImageButton") then
					w(("      %s (%s) Visible=%s Active=%s Text=%q"):format(
						d.Name, d.ClassName, tostring(d.Visible), tostring(d.Active),
						d:IsA("TextButton") and d.Text or ""
					))
				elseif d:IsA("Frame") and (d.Name:lower():find("claim") or d.Name:lower():find("trip")) then
					w(("      %s (Frame)"):format(d.Name))
				end
			end
		end
	end
end)

-- -----------------------------------------------------
-- TEST 8: OPEN EXPEDITION UI + FIRE
-- -----------------------------------------------------
section("TEST 8 — OPEN EXPEDITION + FIRE", function()
	local root = getRoot()
	if not root or not expedition then
		w("No root or expedition")
		return
	end

	local expeditionPos = nil
	local okP, pivot = pcall(function() return expedition:GetPivot() end)
	if okP and pivot then
		expeditionPos = pivot.Position
	end

	if not expeditionPos then
		w("No expedition position")
		return
	end

	local originalCFrame = root.CFrame
	local wasAnchored = root.Anchored
	root.Anchored = true
	root.CFrame = CFrame.new(expeditionPos + Vector3.new(0, 5, 0))
	task.wait(0.5)
	root.Anchored = wasAnchored
	w(("Teleported to Expedition: %.1f,%.1f,%.1f"):format(
		root.Position.X, root.Position.Y, root.Position.Z
	))

	if expeditionFeature and typeof(expeditionFeature.Open) == "function" then
		pcall(expeditionFeature.Open)
		task.wait(0.5)
		w("Called feature.Open()")
	end

	pcall(fire, "MachineScreens_Get", "DiamondMountainExpeditionMachine")
	task.wait(0.5)

	local playerGui = localPlayer:FindFirstChild("PlayerGui")
	local machines = playerGui and playerGui:FindFirstChild("_MACHINES")
	if machines then
		w("")
		w("-- _MACHINES after open (enabled only):")
		for _, child in ipairs(machines:GetChildren()) do
			if child:IsA("ScreenGui") and child.Enabled then
				w(("  %s (Enabled)"):format(child.Name))
				for _, d in ipairs(child:GetDescendants()) do
					if d:IsA("TextButton") or d:IsA("ImageButton") then
						w(("    %s (%s) Visible=%s Text=%q"):format(
							d.Name, d.ClassName, tostring(d.Visible),
							d:IsA("TextButton") and d.Text or ""
						))
					end
				end
			end
		end
	end

	w("")
	w("-- Fire all interactions in Expedition:")
	local fired = 0
	for _, d in ipairs(expedition:GetDescendants()) do
		if d:IsA("ProximityPrompt") then
			if not d.Enabled then pcall(function() d.Enabled = true end) end
			pcall(fireproximityprompt, d)
			w(("  Prompt: %s"):format(d:GetFullName()))
			fired += 1
		elseif d:IsA("ClickDetector") then
			pcall(fireclickdetector, d)
			w(("  Click: %s"):format(d:GetFullName()))
			fired += 1
		end
	end
	w(("Fired %d interactions"):format(fired))

	w("")
	w("-- Feature methods after UI open:")
	if expeditionFeature then
		for _, name in ipairs({ "Claim", "ClaimAll", "ClaimRewards", "Collect" }) do
			if typeof(expeditionFeature[name]) == "function" then
				local ok, result = pcall(expeditionFeature[name])
				w(("  [%s] ok=%s result=%s"):format(name, tostring(ok), serialize(result)))
			end
		end
	end

	root.Anchored = true
	root.CFrame = originalCFrame
	task.wait(0.3)
	root.Anchored = wasAnchored
	w("Returned to original position")
end)

-- -----------------------------------------------------
-- SUMMARY
-- -----------------------------------------------------
section("SUMMARY", function()
	w("File:", DIAG_PATH)
	w("Lines:", #lines)
	w("Expedition:", expedition and "found" or "nil")
	w("Feature('Expedition'):", expeditionFeature and "found" or "nil")
	w("")
	w("=== END ===")
end)

-- Final flush
local ok = flush()
if ok then
	print("")
	print("========================================")
	print("DIAGNOSTIC COMPLETE")
	print("File saved: " .. DIAG_PATH)
	print("Mở file này trong folder executor và gửi cho tôi")
	print("========================================")
else
	print("")
	print("========================================")
	print("writefile FAILED — content đã copy vào clipboard")
	print("Paste vào đâu đó và gửi cho tôi")
	print("========================================")
end
