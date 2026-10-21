-- =====================================================
-- VRT MERCHANT FIX — Standalone Test Script
-- Test mua từ xa + teleport tới PAD chính xác + click Buy
-- Save -> VRT/VRT_MerchantFix.txt
-- CHẠY KHI ĐANG Ở TRONG DIAMOND MOUNTAIN
-- =====================================================

local playersService = game:GetService("Players")
local replicatedStorage = game:GetService("ReplicatedStorage")

local localPlayer = playersService.LocalPlayer
local libraryFolder = replicatedStorage:WaitForChild("Library")
local clientFolder = libraryFolder:WaitForChild("Client")
local utilFolder = libraryFolder:FindFirstChild("Util")
local networkFolder = replicatedStorage:WaitForChild("Network")

local DIAG_FOLDER = "VRT"
local DIAG_PATH = "VRT/VRT_MerchantFix.txt"

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
		print(("[VRT] Saved -> %s (%d bytes)"):format(DIAG_PATH, #content))
	else
		warn("[VRT] writefile failed: " .. tostring(err))
		pcall(setclipboard, content)
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

local function invoke(name, ...)
	local network = safeRequire(clientFolder:FindFirstChild("Network"))
	if not network or not network.Invoke then return false, "no network" end
	local ok, result = pcall(network.Invoke, name, ...)
	return ok, result
end

-- -----------------------------------------------------
-- MODULES
-- -----------------------------------------------------
local Modules = {
	Network = safeRequire(clientFolder:FindFirstChild("Network")),
	DiamondMountainCmds = safeRequire(clientFolder:FindFirstChild("DiamondMountainCmds")),
	DiamondMountainMerchant = safeRequire(utilFolder and utilFolder:FindFirstChild("DiamondMountainMerchant")),
	MerchantsDir = safeRequire(libraryFolder:FindFirstChild("Directory") and libraryFolder.Directory:FindFirstChild("Merchants")),
	MachineScreens = safeRequire(clientFolder:FindFirstChild("MachineScreens")),
	MachineCmds = safeRequire(clientFolder:FindFirstChild("MachineCmds")),
}

-- -----------------------------------------------------
-- HEADER
-- -----------------------------------------------------
sep("HEADER")
w("Time:", os.date("%c"))
w("Player:", localPlayer.Name, "|", tostring(localPlayer.UserId))

local root = getRoot()
if root then
	local p = root.Position
	w(("Position: %.1f, %.1f, %.1f"):format(p.X, p.Y, p.Z))
end

-- -----------------------------------------------------
-- PHASE + PAD INFO
-- -----------------------------------------------------
sep("PHASE + PAD INFO")
local dmMerchant = Modules.DiamondMountainMerchant
local currentCamp = nil
local padPart = nil
local padObject = nil
local padTargetPos = nil

if typeof(dmMerchant) == "table" then
	local ok, phase = pcall(dmMerchant.Phase)
	if ok and typeof(phase) == "table" then
		currentCamp = phase.Camp
		w(("Phase.Camp = %s | Arrived = %s | From = %s"):format(
			tostring(phase.Camp), tostring(phase.Arrived), tostring(phase.From)
		))
		for k, v in pairs(phase) do
			w(("  %s = %s"):format(tostring(k), tostring(v)))
		end
	end
end

if currentCamp then
	local modelName = "TravelingMerchant" .. tostring(currentCamp)
	local model = workspace:FindFirstChild(modelName, true)
	if model then
		w(("Wagon model: %s"):format(model:GetFullName()))
		padPart = model:FindFirstChild("Pad")
		if padPart and padPart:IsA("BasePart") then
			w(("Pad Part: %s"):format(padPart:GetFullName()))
			w(("  Position: %.2f,%.2f,%.2f"):format(
				padPart.Position.X, padPart.Position.Y, padPart.Position.Z
			))
			w(("  Size: %.2f,%.2f,%.2f"):format(
				padPart.Size.X, padPart.Size.Y, padPart.Size.Z
			))
			w(("  CanCollide: %s | Anchored: %s | Transparency: %.2f"):format(
				tostring(padPart.CanCollide), tostring(padPart.Anchored),
				padPart.Transparency
			))
			w(("  Attributes:"))
			for k, v in pairs(padPart:GetAttributes()) do
				w(("    %s = %s"):format(tostring(k), tostring(v)))
			end
		end
	end

	-- Get pad object from feature upvalue
	local dmCmds = Modules.DiamondMountainCmds
	if dmCmds and typeof(dmCmds.Feature) == "function" then
		local okF, feature = pcall(dmCmds.Feature, "Merchant")
		if okF and typeof(feature) == "table" then
			local okU, wagons = pcall(debug.getupvalue, feature.OnLeave, 4)
			if okU and typeof(wagons) == "table" then
				for _, wagon in pairs(wagons) do
					if typeof(wagon) == "table" and wagon.camp == currentCamp then
						padObject = wagon.pad
						if padObject then
							w(("Pad object found for camp %d"):format(currentCamp))
							w(("  padPosition: %s"):format(tostring(padObject.padPosition)))
							w(("  hitRadius: %s"):format(tostring(padObject.hitRadius)))
							w(("  uid: %s"):format(tostring(padObject.uid)))
							padTargetPos = padObject.padPosition
						end
						break
					end
				end
			end
		end
	end
end

-- -----------------------------------------------------
-- TEST 1: BUY FROM FAR (current position)
-- -----------------------------------------------------
sep("TEST 1 — BUY FROM FAR (current position)")

if root and padTargetPos then
	local dist = (root.Position - padTargetPos).Magnitude
	w(("Current distance to pad: %.2f studs"):format(dist))
	w("")
	w("-- Trying Merchant_RequestPurchase from FAR:")
	for slot = 0, 6 do
		local ok, result = invoke("Merchant_RequestPurchase", "DiamondMountainMerchant", slot)
		w(("  slot=%d ok=%s result=%s"):format(slot, tostring(ok), tostring(result)))
		task.wait(0.2)
	end
else
	w("(skip — no pad target)")
end

-- -----------------------------------------------------
-- TEST 2: TELEPORT TO PAD EXACT
-- -----------------------------------------------------
sep("TEST 2 — TELEPORT TO PAD EXACT")

if root and padTargetPos then
	local originalAnchored = root.Anchored

	-- Method 1: Teleport to exact padPosition (no Y offset)
	w("-- Method 1: CFrame.new(padPosition) exact")
	root.Anchored = true
	root.CFrame = CFrame.new(padTargetPos)
	task.wait(0.5)
	root.Anchored = originalAnchored
	task.wait(0.3)
	local dist1 = (root.Position - padTargetPos).Magnitude
	w(("  Player now: %.2f,%.2f,%.2f | dist=%.2f"):format(
		root.Position.X, root.Position.Y, root.Position.Z, dist1
	))

	-- Check IsStandingOn
	if padObject and typeof(padObject.IsStandingOn) == "function" then
		local ok, standing = pcall(padObject.IsStandingOn)
		w(("  IsStandingOn() = %s"):format(tostring(standing)))
		ok, standing = pcall(function() return padObject:IsStandingOn() end)
		w(("  padObject:IsStandingOn() = %s"):format(tostring(standing)))
	end

	-- Method 2: If not standing, teleport to padPart.Position + (0, 3, 0)
	if padPart then
		w("")
		w("-- Method 2: CFrame.new(padPart.Position + (0,3,0))")
		root.Anchored = true
		root.CFrame = CFrame.new(padPart.Position + Vector3.new(0, 3, 0))
		task.wait(0.5)
		root.Anchored = originalAnchored
		task.wait(0.3)
		local dist2 = (root.Position - padTargetPos).Magnitude
		w(("  Player now: %.2f,%.2f,%.2f | dist=%.2f"):format(
			root.Position.X, root.Position.Y, root.Position.Z, dist2
		))
		if padObject and typeof(padObject.IsStandingOn) == "function" then
			local ok, standing = pcall(padObject.IsStandingOn)
			w(("  IsStandingOn() = %s"):format(tostring(standing)))
		end
	end

	-- Method 3: PivotTo
	w("")
	w("-- Method 3: Character:PivotTo(padPosition)")
	if localPlayer.Character then
		pcall(function()
			localPlayer.Character:PivotTo(CFrame.new(padTargetPos))
		end)
		task.wait(0.5)
		local dist3 = (root.Position - padTargetPos).Magnitude
		w(("  Player now: %.2f,%.2f,%.2f | dist=%.2f"):format(
			root.Position.X, root.Position.Y, root.Position.Z, dist3
		))
		if padObject and typeof(padObject.IsStandingOn) == "function" then
			local ok, standing = pcall(padObject.IsStandingOn)
			w(("  IsStandingOn() = %s"):format(tostring(standing)))
		end
	end
else
	w("(skip — no pad target)")
end

-- -----------------------------------------------------
-- TEST 3: BUY FROM PAD (after teleport)
-- -----------------------------------------------------
sep("TEST 3 — BUY FROM PAD (after teleport)")

if root and padTargetPos then
	local dist = (root.Position - padTargetPos).Magnitude
	w(("Current distance to pad: %.2f studs"):format(dist))
	w("")
	w("-- Trying Merchant_RequestPurchase from PAD:")
	for slot = 0, 6 do
		local ok, result = invoke("Merchant_RequestPurchase", "DiamondMountainMerchant", slot)
		w(("  slot=%d ok=%s result=%s"):format(slot, tostring(ok), tostring(result)))
		task.wait(0.2)
	end
end

-- -----------------------------------------------------
-- TEST 4: OPEN SHOP + INSPECT SLOTS
-- -----------------------------------------------------
sep("TEST 4 — OPEN SHOP + INSPECT SLOTS")

local dmCmds = Modules.DiamondMountainCmds
local feature = nil
if dmCmds and typeof(dmCmds.Feature) == "function" then
	local okF, f = pcall(dmCmds.Feature, "Merchant")
	if okF and typeof(f) == "table" then
		feature = f
	end
end

if feature and typeof(feature.Open) == "function" then
	w("-- Calling Feature('Merchant').Open()...")
	local ok, result = pcall(feature.Open)
	w(("  Open() ok=%s result=%s"):format(tostring(ok), tostring(result)))
	task.wait(1)
end

-- Inspect GUI slots
local playerGui = localPlayer:FindFirstChild("PlayerGui")
local machines = playerGui and playerGui:FindFirstChild("_MACHINES")
local merchantGui = machines and machines:FindFirstChild("Merchant")

if merchantGui then
	w("")
	w(("Merchant GUI found: %s (Enabled=%s)"):format(
		merchantGui:GetFullName(), tostring(merchantGui.Enabled)
	))

	-- Find Slots frame
	local slots
	local node = merchantGui
	for _, name in ipairs({ "Frame", "ItemsFrame", "ScrollingItems", "Slots" }) do
		node = node and node:FindFirstChild(name)
	end
	slots = node

	if slots then
		w(("Slots frame: %s"):format(slots:GetFullName()))
		w("")
		for i = 1, 6 do
			local slot = slots:FindFirstChild(tostring(i))
			if slot then
				w(("Slot %d:"):format(i))
				local buy = slot:FindFirstChild("Buy")
				local item = slot:FindFirstChild("ITEM")
				local cost = slot:FindFirstChild("Cost")
				local locked = slot:FindFirstChild("Locked") or (item and item:FindFirstChild("Locked"))

				if buy then
					w(("  Buy: Visible=%s Active=%s"):format(
						tostring(buy.Visible), tostring(buy.Active)
					))
				else
					w("  Buy: NIL")
				end
				if cost then
					local amount = cost:FindFirstChild("Amount")
					w(("  Cost: %s"):format(amount and amount.Text or "?"))
				end
				if item then
					local qty = item:FindFirstChild("Quantity")
					local pts = item:FindFirstChild("Points")
					w(("  Quantity: %s | Points: %s"):format(
						qty and qty.Text or "?", pts and pts.Text or "?"
					))
					w("  Item attributes:")
					for k, v in pairs(item:GetAttributes()) do
						w(("    %s = %s"):format(tostring(k), tostring(v)))
					end
				end
				if locked then
					w(("  Locked.Visible = %s"):format(tostring(locked.Visible)))
				end

				-- Try clicking Buy
				if buy and buy.Visible then
					local clicked = false
					for _, signal in ipairs({ buy.Activated, buy.MouseButton1Click }) do
						local okC, conns = pcall(getconnections, signal)
						if okC and conns then
							for _, conn in ipairs(conns) do
								if conn.Function then
									pcall(conn.Function)
									clicked = true
								end
							end
						end
					end
					w(("  Clicked Buy: %s"):format(tostring(clicked)))
					task.wait(0.3)
				end
			end
		end
	else
		w("Slots frame NOT FOUND")
	end
else
	w("Merchant GUI NOT FOUND")
end

-- -----------------------------------------------------
-- TEST 5: TRY REMOTE AFTER CLICK
-- -----------------------------------------------------
sep("TEST 5 — TRY REMOTE AFTER CLICK")

w("-- Trying Merchant_RequestPurchase after click:")
for slot = 0, 6 do
	local ok, result = invoke("Merchant_RequestPurchase", "DiamondMountainMerchant", slot)
	w(("  slot=%d ok=%s result=%s"):format(slot, tostring(ok), tostring(result)))
	task.wait(0.2)
end

w("")
w("-- Trying with amount arg:")
for slot = 1, 6 do
	local ok, result = invoke("Merchant_RequestPurchase", "DiamondMountainMerchant", slot, 1)
	w(("  slot=%d amount=1 ok=%s result=%s"):format(slot, tostring(ok), tostring(result)))
	task.wait(0.2)
end

-- -----------------------------------------------------
-- TEST 6: MACHINESCREENS + MACHINECMDS
-- -----------------------------------------------------
sep("TEST 6 — MACHINESCREENS + MACHINECMDS")

local machineScreens = Modules.MachineScreens
if machineScreens then
	w("MachineScreens module: table")
	if typeof(machineScreens.Get) == "function" then
		w("-- MachineScreens.Get('DiamondMountainMerchant')")
		local ok, result = pcall(machineScreens.Get, "DiamondMountainMerchant")
		w(("  ok=%s result=%s"):format(tostring(ok), tostring(result)))
	end
	if typeof(machineScreens.Has) == "function" then
		local ok, result = pcall(machineScreens.Has, "DiamondMountainMerchant")
		w(("MachineScreens.Has: ok=%s result=%s"):format(tostring(ok), tostring(result)))
	end
	if typeof(machineScreens.IsHere) == "function" then
		local ok, result = pcall(machineScreens.IsHere, "DiamondMountainMerchant")
		w(("MachineScreens.IsHere: ok=%s result=%s"):format(tostring(ok), tostring(result)))
	end
end

local machineCmds = Modules.MachineCmds
if machineCmds then
	w("")
	w("MachineCmds module: table")
	if typeof(machineCmds.MarkApproached) == "function" then
		local ok, result = pcall(machineCmds.MarkApproached, "DiamondMountainMerchant")
		w(("MachineCmds.MarkApproached: ok=%s result=%s"):format(tostring(ok), tostring(result)))
	end
	if typeof(machineCmds.IsStandingOn) == "function" then
		local ok, result = pcall(machineCmds.IsStandingOn, "DiamondMountainMerchant")
		w(("MachineCmds.IsStandingOn: ok=%s result=%s"):format(tostring(ok), tostring(result)))
	end
	if typeof(machineCmds.CanUse) == "function" then
		local ok, result = pcall(machineCmds.CanUse, "DiamondMountainMerchant")
		w(("MachineCmds.CanUse: ok=%s result=%s"):format(tostring(ok), tostring(result)))
	end
end

-- -----------------------------------------------------
-- TEST 7: DIRECTORY.MERCHANTS.GetOffers
-- -----------------------------------------------------
sep("TEST 7 — DIRECTORY.MERCHANTS.GetOffers")

local merchDir = Modules.MerchantsDir
if merchDir and merchDir.DiamondMountainMerchant then
	local dmDir = merchDir.DiamondMountainMerchant
	w("Directory.Merchants.DiamondMountainMerchant: table")
	if typeof(dmDir.GetOffers) == "function" then
		w("-- Trying GetOffers with different args:")
		local args = {
			{ "no-arg", {} },
			{ "camp", { currentCamp or 1 } },
			{ "camp-string", { tostring(currentCamp or 1) } },
			{ "camp,visit", { currentCamp or 1, 1 } },
		}
		for _, combo in ipairs(args) do
			local ok, result = pcall(dmDir.GetOffers, table.unpack(combo[2]))
			w(("  [%s] ok=%s result=%s"):format(combo[1], tostring(ok), tostring(result)))
			if ok and typeof(result) == "table" then
				for k, v in pairs(result) do
					w(("    [%s] = %s"):format(tostring(k), typeof(v)))
				end
			end
			task.wait(0.2)
		end
	end
end

-- -----------------------------------------------------
-- TEST 8: FEATURE.DEBUG
-- -----------------------------------------------------
sep("TEST 8 — FEATURE.DEBUG")
if feature and typeof(feature.Debug) == "function" then
	local ok, result = pcall(feature.Debug)
	w(("Feature('Merchant').Debug(): ok=%s"):format(tostring(ok)))
	w(("  result: %s"):format(tostring(result)))
end

-- -----------------------------------------------------
-- SUMMARY
-- -----------------------------------------------------
sep("SUMMARY")
w("File:", DIAG_PATH)
w("Lines:", #lines)
w("Current camp:", tostring(currentCamp))
w("Pad target pos:", tostring(padTargetPos))
if root then
	w(("Final player pos: %.2f,%.2f,%.2f"):format(
		root.Position.X, root.Position.Y, root.Position.Z
	))
end

flush()
