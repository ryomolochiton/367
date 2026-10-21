-- =====================================================
-- VRT EXPEDITION DIAGNOSTIC v4 — Minimal Safe
-- KHÔNG gọi MachineScreens / MachineCmds / InvokeCustom
-- Chỉ dump structure + 1 lần Open() với timeout
-- Save -> VRT/VRT_Expedition.txt
-- =====================================================

local playersService = game:GetService("Players")
local replicatedStorage = game:GetService("ReplicatedStorage")

local localPlayer = playersService.LocalPlayer
local libraryFolder = replicatedStorage:WaitForChild("Library")
local clientFolder = libraryFolder:WaitForChild("Client")
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
	lines[#lines + 1] = table.concat(parts, " ")
end

local function flush()
	local ok = pcall(writefile, DIAG_PATH, table.concat(lines, "\n"))
	print(("[VRT] Flushed %d lines -> %s (ok=%s)"):format(#lines, DIAG_PATH, tostring(ok)))
end

local function sep(t)
	w("")
	w(string.rep("=", 78))
	w("=== " .. t)
	w(string.rep("=", 78))
end

local function safeRequire(inst)
	if not inst or typeof(inst) ~= "Instance" then return nil end
	local ok, res = pcall(require, inst)
	return ok and res or nil
end

local function serialize(v, depth, seen)
	depth = depth or 0
	seen = seen or {}
	if depth > 3 then return "..." end
	local t = typeof(v)
	if t == "string" then
		if #v > 150 then return string.format("%q..(%d)", v:sub(1, 150), #v) end
		return string.format("%q", v)
	elseif t == "number" or t == "boolean" or t == "nil" then
		return tostring(v)
	elseif t == "Instance" then
		return v:GetFullName()
	elseif t == "Vector3" then
		return string.format("Vector3(%.1f,%.1f,%.1f)", v.X, v.Y, v.Z)
	elseif t == "CFrame" then
		local p = v.Position
		return string.format("CFrame(%.1f,%.1f,%.1f)", p.X, p.Y, p.Z)
	elseif t == "Color3" then
		return string.format("Color3(%d,%d,%d)", v.R * 255, v.G * 255, v.B * 255)
	elseif t == "EnumItem" then
		return tostring(v)
	elseif t == "function" then
		local info = debug.getinfo(v)
		return string.format("<fn %s>", info and info.what or "?")
	elseif t == "table" then
		if seen[v] then return "<cycle>" end
		seen[v] = true
		local parts = {}
		local count = 0
		for k, val in pairs(v) do
			count += 1
			if count > 20 then
				parts[#parts + 1] = "..."
				break
			end
			parts[#parts + 1] = string.format("[%s]=%s",
				serialize(k, depth + 1, seen),
				serialize(val, depth + 1, seen))
		end
		seen[v] = nil
		return "{" .. table.concat(parts, ", ") .. "}"
	end
	return tostring(v)
end

-- -----------------------------------------------------
-- HEADER
-- -----------------------------------------------------
sep("HEADER")
w("Time:", os.date("%c"))
w("Player:", localPlayer.Name)
w("PlaceId:", tostring(game.PlaceId))
w("Save path:", DIAG_PATH)
flush()

-- -----------------------------------------------------
-- MODULES
-- -----------------------------------------------------
local dmCmds = safeRequire(clientFolder:FindFirstChild("DiamondMountainCmds"))

-- -----------------------------------------------------
-- EXPEDITION MODEL
-- -----------------------------------------------------
sep("EXPEDITION MODEL")
local things = workspace:FindFirstChild("__THINGS")
local container = things and things:FindFirstChild("__INSTANCE_CONTAINER")
local active = container and container:FindFirstChild("Active")
local mountain = active and active:FindFirstChild("DiamondMountain")
local summit = mountain and mountain:FindFirstChild("Summit")
local expedition = summit and summit:FindFirstChild("Expedition")

if not expedition then
	w("Expedition NOT FOUND")
	flush()
	print("[VRT] Expedition not found — không ở trong DM?")
	return
end

w("Expedition:", expedition:GetFullName())
w("")
w("Children:")
for _, child in ipairs(expedition:GetChildren()) do
	local extra = ""
	if child:IsA("BasePart") then
		extra = (" pos=%.1f,%.1f,%.1f"):format(
			child.Position.X, child.Position.Y, child.Position.Z
		)
	end
	w(("  %s (%s)%s"):format(child.Name, child.ClassName, extra))
	local n = 0
	for k, v in pairs(child:GetAttributes()) do
		n += 1
		w(("    attr %s = %s"):format(tostring(k), serialize(v)))
	end
	if n == 0 then w("    (no attributes)") end
end
flush()

-- -----------------------------------------------------
-- CLAIMPILLAR
-- -----------------------------------------------------
sep("CLAIMPILLAR")
local claim = expedition:FindFirstChild("ClaimPillar")
if claim then
	w("ClaimPillar:", claim:GetFullName())
	w("")
	w("Descendants:")
	for _, d in ipairs(claim:GetDescendants()) do
		local extra = ""
		if d:IsA("BasePart") then
			extra = (" pos=%.1f,%.1f,%.1f transparency=%.2f"):format(
				d.Position.X, d.Position.Y, d.Position.Z, d.Transparency
			)
		elseif d:IsA("ProximityPrompt") then
			extra = (" enabled=%s actionText=%q objectText=%q hold=%.1f maxDist=%.1f"):format(
				tostring(d.Enabled), tostring(d.ActionText),
				tostring(d.ObjectText), d.HoldDuration, d.MaxActivationDistance
			)
		elseif d:IsA("ClickDetector") then
			extra = (" maxDist=%.1f"):format(d.MaxActivationDistance)
		elseif d:IsA("TextButton") or d:IsA("ImageButton") then
			extra = (" visible=%s active=%s text=%q"):format(
				tostring(d.Visible), tostring(d.Active),
				d:IsA("TextButton") and d.Text or ""
			)
		elseif d:IsA("BillboardGui") or d:IsA("SurfaceGui") then
			extra = (" enabled=%s"):format(tostring(d.Enabled))
		end
		w(("  %s (%s)%s"):format(d.Name, d.ClassName, extra))
	end
	w("")
	w("Attributes:")
	local n = 0
	for k, v in pairs(claim:GetAttributes()) do
		n += 1
		w(("  %s = %s"):format(tostring(k), serialize(v)))
	end
	if n == 0 then w("  (none)") end
else
	w("ClaimPillar NOT FOUND")
end
flush()

-- -----------------------------------------------------
-- PEDESTALS
-- -----------------------------------------------------
sep("PEDESTALS")
for _, name in ipairs({ "Pedestal1", "Pedestal2", "Pedestal3", "Pedestal4" }) do
	local ped = expedition:FindFirstChild(name)
	if ped then
		w(name .. ":")
		for _, d in ipairs(ped:GetDescendants()) do
			local extra = ""
			if d:IsA("BasePart") then
				extra = (" pos=%.1f,%.1f,%.1f transparency=%.2f"):format(
					d.Position.X, d.Position.Y, d.Position.Z, d.Transparency
				)
			elseif d:IsA("ProximityPrompt") then
				extra = (" [PROMPT] enabled=%s actionText=%q"):format(
					tostring(d.Enabled), tostring(d.ActionText)
				)
			elseif d:IsA("ClickDetector") then
				extra = " [CLICK]"
			elseif d:IsA("BillboardGui") or d:IsA("SurfaceGui") then
				extra = (" [GUI] enabled=%s"):format(tostring(d.Enabled))
			end
			w(("  %s (%s)%s"):format(d.Name, d.ClassName, extra))
		end
		local n = 0
		for k, v in pairs(ped:GetAttributes()) do
			n += 1
			w(("  attr %s = %s"):format(tostring(k), serialize(v)))
		end
		if n == 0 then w("  (no attributes)") end
	end
end
flush()

-- -----------------------------------------------------
-- FEATURE('Expedition')
-- -----------------------------------------------------
sep("FEATURE('Expedition')")
local expeditionFeature = nil
if dmCmds and typeof(dmCmds.Feature) == "function" then
	local ok, feature = pcall(dmCmds.Feature, "Expedition")
	if ok and typeof(feature) == "table" then
		expeditionFeature = feature
		local keys = {}
		for k in pairs(feature) do keys[#keys + 1] = k end
		table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
		w(("Feature('Expedition') table(%d)"):format(#keys))
		for _, k in ipairs(keys) do
			local v = feature[k]
			local tv = typeof(v)
			if tv == "function" then
				local info = debug.getinfo(v)
				w(("  .%s = fn | params=%d nups=%d vararg=%s"):format(
					tostring(k), info and info.numparams or 0,
					info and info.nups or 0, tostring(info and info.is_vararg)
				))
				local okU, ups = pcall(debug.getupvalues, v)
				if okU and typeof(ups) == "table" then
					for i, uv in pairs(ups) do
						local tuv = typeof(uv)
						if tuv == "table" then
							local n = 0
							for _ in pairs(uv) do n += 1 end
							w(("      up[%d] = table(%d)"):format(i, n))
							local subkeys = {}
							for sk in pairs(uv) do subkeys[#subkeys + 1] = sk end
							table.sort(subkeys, function(a, b) return tostring(a) < tostring(b) end)
							local shown = 0
							for _, sk in ipairs(subkeys) do
								if shown >= 10 then
									w("        ...")
									break
								end
								shown += 1
								w(("        [%s] = %s"):format(tostring(sk), serialize(uv[sk])))
							end
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
			elseif tv == "table" then
				local n = 0
				for _ in pairs(v) do n += 1 end
				w(("  .%s = table(%d)"):format(tostring(k), n))
			else
				w(("  .%s = %s"):format(tostring(k), serialize(v)))
			end
		end
	else
		w("Feature('Expedition') failed:", tostring(feature))
	end
else
	w("DiamondMountainCmds not available")
end
flush()

-- -----------------------------------------------------
-- REMOTES
-- -----------------------------------------------------
sep("REMOTES (expedition/trip/dm)")
if networkFolder then
	for _, child in ipairs(networkFolder:GetChildren()) do
		local lower = child.Name:lower()
		if lower:find("expedition") or lower:find("trip") or lower:find("dm_") then
			w(("  %s (%s)"):format(child.Name, child.ClassName))
		end
	end
else
	w("Network folder not found")
end
flush()

-- -----------------------------------------------------
-- UI (_MACHINES)
-- -----------------------------------------------------
sep("UI (_MACHINES)")
local playerGui = localPlayer:FindFirstChild("PlayerGui")
local machines = playerGui and playerGui:FindFirstChild("_MACHINES")
if machines then
	for _, child in ipairs(machines:GetChildren()) do
		w(("  %s (%s) enabled=%s"):format(
			child.Name, child.ClassName,
			child:IsA("ScreenGui") and tostring(child.Enabled) or "n/a"
		))
		if child.Name:lower():find("expedition") or child.Name:lower():find("trip") then
			w("    [EXPEDITION UI]")
			for _, d in ipairs(child:GetDescendants()) do
				if d:IsA("TextButton") or d:IsA("ImageButton") then
					w(("      %s (%s) visible=%s text=%q"):format(
						d.Name, d.ClassName, tostring(d.Visible),
						d:IsA("TextButton") and d.Text or ""
					))
				end
			end
		end
	end
else
	w("_MACHINES not found")
end
flush()

-- -----------------------------------------------------
-- TRY Feature('Expedition').Open() (1 lần, timeout 3s)
-- -----------------------------------------------------
sep("TRY Feature('Expedition').Open()")
if expeditionFeature and typeof(expeditionFeature.Open) == "function" then
	local result = { done = false, ok = false, value = nil }
	task.spawn(function()
		local ok, res = pcall(expeditionFeature.Open)
		result.ok = ok
		result.value = res
		result.done = true
	end)
	local start = os.clock()
	while not result.done and (os.clock() - start) < 3 do
		task.wait(0.1)
	end
	if result.done then
		w(("Open() ok=%s result=%s"):format(tostring(result.ok), serialize(result.value)))
	else
		w("Open() TIMEOUT after 3s")
	end
	flush()

	task.wait(0.5)

	if machines then
		w("")
		w("_MACHINES after open (enabled only):")
		for _, child in ipairs(machines:GetChildren()) do
			if child:IsA("ScreenGui") and child.Enabled then
				w(("  %s (Enabled)"):format(child.Name))
				for _, d in ipairs(child:GetDescendants()) do
					if d:IsA("TextButton") or d:IsA("ImageButton") then
						w(("    %s (%s) visible=%s text=%q"):format(
							d.Name, d.ClassName, tostring(d.Visible),
							d:IsA("TextButton") and d.Text or ""
						))
					end
				end
			end
		end
	end
else
	w("No Open method")
end
flush()

-- -----------------------------------------------------
-- SUMMARY
-- -----------------------------------------------------
sep("SUMMARY")
w("File:", DIAG_PATH)
w("Lines:", #lines)
w("Expedition found:", expedition ~= nil)
w("Feature found:", expeditionFeature ~= nil)
w("=== END ===")
flush()

print("")
print("========================================")
print("DONE. File: " .. DIAG_PATH)
print("========================================")
