-- VRT HUB — Events module (Diamond Mountain + Time Trial)
-- v1.7.7

local Events = {}
Events.VERSION = "1.7.7"
Events.__index = Events

-- Constants.
local DM_INSTANCE_ID = "DiamondMountain"
local DM_MERCHANT_ID = "DiamondMountainMerchant"
local DM_EXPEDITION_ID = "DiamondMountainExpeditionMachine"
local DM_FARM_RADIUS = 250
local DM_CAMP_RADIUS = 150

local TT_INSTANCE_ID = "TimeTrial"
local TT_TELEPORT_PART = "Enter"
local TT_STOP_RADIUS = 15
local TT_FARM_INTERVAL = 0.1
local TT_JUMP_COOLDOWN = 0.2
local TT_ENTER_COOLDOWN = 3
local TT_DEFAULT_MOVE_RADIUS = 45
local SAVE_TTL = 2

local playersService = game:GetService("Players")
local replicatedStorage = game:GetService("ReplicatedStorage")
local virtualInputManager = game:GetService("VirtualInputManager")
local localPlayer = playersService.LocalPlayer

-- ══════════════════════════════════════════════════════════
--  SHARED HELPERS
-- ══════════════════════════════════════════════════════════

---Require a Library.Client module.
---@param name string
local function getClientModule(name)
	local library = replicatedStorage:FindFirstChild("Library")
	local client = library and library:FindFirstChild("Client")
	local target = client and client:FindFirstChild(name)
	if not target then
		return nil
	end
	local ok, module = pcall(require, target)
	return ok and module or nil
end

---Require a Library.Types module.
---@param name string
local function getTypeModule(name)
	local library = replicatedStorage:FindFirstChild("Library")
	local types = library and library:FindFirstChild("Types")
	local target = types and types:FindFirstChild(name)
	if not target then
		return nil
	end
	local ok, module = pcall(require, target)
	return ok and module or nil
end

---Return the character root part.
local function getRoot()
	local character = localPlayer.Character
	if not character then
		return nil
	end
	return character:FindFirstChild("HumanoidRootPart")
end

---Return the __THINGS instance folder.
local function getThings()
	return workspace:FindFirstChild("__THINGS")
end

---Return an instance folder by id.
---@param instanceId string
local function findInstanceFolder(instanceId)
	local things = getThings()
	if not things then
		return nil
	end
	local container = things:FindFirstChild("__INSTANCE_CONTAINER")
	local active = container and container:FindFirstChild("Active")
	local folder = active and active:FindFirstChild(instanceId)
	if folder then
		return folder
	end
	local instances = things:FindFirstChild("Instances")
	return instances and instances:FindFirstChild(instanceId) or nil
end

-- ══════════════════════════════════════════════════════════
--  DIAMOND MOUNTAIN
-- ══════════════════════════════════════════════════════════

local DiamondMountain = {}
DiamondMountain.__index = DiamondMountain

---Create a new DiamondMountain controller.
---@param context table
function DiamondMountain.new(context)
	local self = setmetatable({}, DiamondMountain)
	self.context = context
	self.features = {}
	return self
end

---Return the active mountain folder.
function DiamondMountain:getInstanceFolder()
	return findInstanceFolder(DM_INSTANCE_ID)
end

---Fire a remote safely.
function DiamondMountain:fire(name, ...)
	local network = getClientModule("Network")
	if not network then
		return false
	end
	return pcall(network.Fire, network, name, ...)
end

---Invoke a remote safely.
function DiamondMountain:invoke(name, ...)
	local network = getClientModule("Network")
	if not network then
		return false
	end
	return pcall(network.Invoke, network, name, ...)
end

---Return every breakable inside the mountain folder.
function DiamondMountain:getBreakables()
	local folder = self:getInstanceFolder()
	local breakables = folder and folder:FindFirstChild("Breakables")
	if not breakables then
		return {}
	end
	return breakables:GetChildren()
end

---Damage breakables matching a name filter.
---@param filter string?
function DiamondMountain:damageBreakables(filter)
	local network = getClientModule("Network")
	local root = getRoot()
	if not network or not root then
		return
	end
	local origin = root.Position
	for _, breakable in ipairs(self:getBreakables()) do
		if breakable:IsA("Model") then
			local matches = filter == nil or breakable.Name:find(filter, 1, true) ~= nil
			if matches then
				local ok, pivot = pcall(function()
					return breakable:GetPivot().Position
				end)
				if ok and pivot and (origin - pivot).Magnitude <= DM_FARM_RADIUS then
					pcall(network.UnreliableFire, network, "Breakables_PlayerDealDamage", breakable.Name)
				end
			end
		end
	end
end

---Damage every breakable in range.
function DiamondMountain:autoFarm()
	self:damageBreakables(nil)
end

---Damage trail breakables.
function DiamondMountain:breakTrail()
	self:damageBreakables("Trail")
end

---Damage wall breakables.
function DiamondMountain:fillWalls()
	self:damageBreakables("Wall")
end

---Damage the Yeti.
function DiamondMountain:fightYeti()
	local folder = self:getInstanceFolder()
	local yeti = folder and folder:FindFirstChild("Yeti", true)
	if yeti then
		self:fire("Breakables_PlayerDealDamage", yeti.Name)
	end
end

---Feed the Yeti.
function DiamondMountain:feedYeti()
	self:invoke("DiamondMountain: FeedYeti")
end

---Buy the mountain egg.
function DiamondMountain:buyEgg()
	local eggCmds = getClientModule("EggCmds")
	local maxHatch = 1
	if eggCmds then
		local ok, value = pcall(function()
			return eggCmds:GetMaxHatch()
		end)
		if ok and tonumber(value) then
			maxHatch = tonumber(value)
		end
	end
	self:invoke("Eggs_RequestPurchase", DM_INSTANCE_ID, maxHatch)
end

---Purchase merchant slots.
function DiamondMountain:merchant()
	for slot = 1, 6 do
		self:invoke("Merchant_RequestPurchase", DM_MERCHANT_ID, slot)
		task.wait(0.1)
	end
end

---Send the expedition.
function DiamondMountain:sendExpedition()
	self:invoke("Expedition_Send", DM_EXPEDITION_ID)
end

---Claim the expedition.
function DiamondMountain:claimExpedition()
	self:invoke("Expedition_Claim", DM_EXPEDITION_ID)
end

---Teleport to the next camp.
function DiamondMountain:teleportCamp()
	local root = getRoot()
	local folder = self:getInstanceFolder()
	if not root or not folder then
		return
	end
	local camps = folder:FindFirstChild("Camps")
	if not camps then
		return
	end
	local best, bestDist
	for _, camp in ipairs(camps:GetChildren()) do
		local ok, pivot = pcall(function()
			return camp:GetPivot().Position
		end)
		if ok and pivot then
			local dist = (root.Position - pivot).Magnitude
			if dist > DM_CAMP_RADIUS and (not bestDist or dist < bestDist) then
				bestDist = dist
				best = camp
			end
		end
	end
	if best then
		pcall(function()
			root.CFrame = best:GetPivot()
		end)
	end
end

---Collect artifacts in range.
function DiamondMountain:artifacts()
	local folder = self:getInstanceFolder()
	local root = getRoot()
	if not folder or not root then
		return
	end
	local artifacts = folder:FindFirstChild("Artifacts")
	if not artifacts then
		return
	end
	for _, artifact in ipairs(artifacts:GetChildren()) do
		local ok, pivot = pcall(function()
			return artifact:GetPivot().Position
		end)
		if ok and pivot and (root.Position - pivot).Magnitude <= DM_FARM_RADIUS then
			self:invoke("Artifact_Collect", artifact.Name)
		end
	end
end

---Buy the next mountain upgrade.
function DiamondMountain:buyUpgrades()
	self:invoke("DiamondMountain: RequestUpgrade")
end

---Use every available boost.
function DiamondMountain:useBoosts()
	self:invoke("DiamondMountain: UseBoost")
end

---Strip heavy visuals from mountain models.
function DiamondMountain:optimize()
	local folder = self:getInstanceFolder()
	if not folder then
		return
	end
	for _, descendant in ipairs(folder:GetDescendants()) do
		if descendant:IsA("ParticleEmitter")
			or descendant:IsA("Trail")
			or descendant:IsA("Beam")
			or descendant:IsA("Decal") then
			pcall(function()
				descendant:Destroy()
			end)
		end
	end
end

---Start a repeating feature loop.
---@param key string
---@param callback function
---@param interval number
function DiamondMountain:startFeature(key, callback, interval)
	if self.features[key] then
		return
	end
	self.features[key] = true
	task.spawn(function()
		while self.features[key] and self.context.isAlive() do
			pcall(callback, self)
			task.wait(interval or 1)
		end
		self.features[key] = false
	end)
end

---Stop a repeating feature loop.
---@param key string
function DiamondMountain:stopFeature(key)
	self.features[key] = false
end

---Build the Diamond Mountain tab.
---@param tab any
function DiamondMountain:build(tab)
	local function addToggle(name, key, callback, interval)
		tab:CreateToggle({
			Name = name,
			CurrentValue = false,
			Flag = "DM_" .. key,
			Callback = function(state)
				if state then
					self:startFeature(key, callback, interval)
				else
					self:stopFeature(key)
				end
			end,
		})
	end

	tab:CreateSection("Mountain Farm")
	addToggle("Auto Farm Mountain", "autoFarm", self.autoFarm, 0.2)
	addToggle("Break Trail", "breakTrail", self.breakTrail, 0.3)
	addToggle("Fill Walls", "fillWalls", self.fillWalls, 0.5)
	addToggle("Fight Yeti", "fightYeti", self.fightYeti, 0.3)
	addToggle("Feed Yeti", "feedYeti", self.feedYeti, 2)

	tab:CreateSection("Mountain Economy")
	addToggle("Buy Egg", "buyEgg", self.buyEgg, 1)
	addToggle("Merchant", "merchant", self.merchant, 5)
	addToggle("Send Expedition", "sendExpedition", self.sendExpedition, 10)
	addToggle("Claim Expedition", "claimExpedition", self.claimExpedition, 5)
	addToggle("Buy Upgrades", "buyUpgrades", self.buyUpgrades, 3)
	addToggle("Use Boosts", "useBoosts", self.useBoosts, 5)

	tab:CreateSection("Mountain Utility")
	addToggle("Collect Artifacts", "artifacts", self.artifacts, 1)
	addToggle("Optimize Visuals", "optimize", self.optimize, 10)

	tab:CreateButton({
		Name = "Teleport To Camp",
		Callback = function()
			pcall(self.teleportCamp, self)
		end,
	})

	tab:CreateLabel("DiamondMountain v" .. Events.VERSION, "mountain", Color3.fromRGB(120, 200, 255), false)
end

-- ══════════════════════════════════════════════════════════
--  TIME TRIAL
-- ══════════════════════════════════════════════════════════

local TimeTrial = {}
TimeTrial.__index = TimeTrial

---Create a new TimeTrial controller.
---@param context table
function TimeTrial.new(context)
	local self = setmetatable({}, TimeTrial)
	self.context = context
	self.enabled = false
	self.moveHooked = false
	self.originalMoveDirection = nil
	self.hoverboardInstance = nil
	self.summaryConnection = nil
	self.autoLeave = true
	self.moveRadius = TT_DEFAULT_MOVE_RADIUS
	self.saveCache = nil
	self.saveCacheAt = 0
	self.lastJumpAt = 0
	self.lastEnterAt = 0
	self.warnedNoRuns = false
	return self
end

---Return the cached save table.
function TimeTrial:getSave()
	local now = os.clock()
	if self.saveCache and now - self.saveCacheAt < SAVE_TTL then
		return self.saveCache
	end
	local saveModule = getClientModule("Save")
	if not saveModule then
		return nil
	end
	local ok, data = pcall(function()
		return saveModule:Get()
	end)
	self.saveCache = ok and data or nil
	self.saveCacheAt = now
	return self.saveCache
end

---Return the TimeTrial instance folder.
function TimeTrial:getInstanceFolder()
	return findInstanceFolder(TT_INSTANCE_ID)
end

---Return the daily runs left.
function TimeTrial:getDailyRunsLeft()
	local save = self:getSave()
	if not save or type(save.TimeTrialStats) ~= "table" then
		return 0
	end
	local used = tonumber(save.TimeTrialStats.DailyRuns) or 0
	local types = getTypeModule("TimeTrials")
	local max = types and tonumber(types.DailyRuns) or 0
	if max <= 0 then
		return 0
	end
	return math.max(0, max - used)
end

---Return true while inside a time trial.
function TimeTrial:isInTimeTrial()
	local save = self:getSave()
	if not save then
		return false
	end
	return save.instanceID == TT_INSTANCE_ID
end

---Return true when the character is spawned and alive.
function TimeTrial:isSpawned()
	local character = localPlayer.Character
	if not character then
		return false
	end
	local humanoid = character:FindFirstChild("Humanoid")
	if humanoid and humanoid.Health <= 0 then
		return false
	end
	return character:FindFirstChild("HumanoidRootPart") ~= nil
end

---Return the spawn part of the busiest breakable area.
function TimeTrial:getBestZone()
	local things = getThings()
	local breakables = things and things:FindFirstChild("Breakables")
	if not breakables then
		return nil
	end

	local counts = {}
	for _, breakable in ipairs(breakables:GetChildren()) do
		local areaId = breakable:GetAttribute("AreaID")
		if areaId then
			counts[areaId] = (counts[areaId] or 0) + 1
		end
	end

	local bestId, bestCount
	for id, count in pairs(counts) do
		if not bestCount or count > bestCount then
			bestCount = count
			bestId = id
		end
	end
	if not bestId then
		return nil
	end

	local instance = self:getInstanceFolder()
	local spawns = instance and instance:FindFirstChild("BREAKABLE_SPAWNS")
	local spawnPart = spawns and spawns:FindFirstChild(bestId)
	if spawnPart then
		return spawnPart
	end

	for _, breakable in ipairs(breakables:GetChildren()) do
		if breakable:GetAttribute("AreaID") == bestId then
			return breakable
		end
	end
	return nil
end

---Teleport into the time trial.
function TimeTrial:enter()
	if self:isInTimeTrial() then
		return false
	end
	local now = os.clock()
	if now - self.lastEnterAt < TT_ENTER_COOLDOWN then
		return false
	end
	local root = getRoot()
	if not root then
		return false
	end
	local instance = self:getInstanceFolder()
	local teleports = instance and instance:FindFirstChild("Teleports")
	local enterPart = teleports and teleports:FindFirstChild(TT_TELEPORT_PART)
	if not enterPart then
		return false
	end
	self.lastEnterAt = now
	pcall(function()
		root.CFrame = enterPart.CFrame
	end)
	return true
end

---Press space to keep the hoverboard moving.
function TimeTrial:jump()
	local now = os.clock()
	if now - self.lastJumpAt < TT_JUMP_COOLDOWN then
		return
	end
	self.lastJumpAt = now
	pcall(function()
		virtualInputManager:SendKeyEvent(true, Enum.KeyCode.Space, false, game)
	end)
	task.wait(0.05)
	pcall(function()
		virtualInputManager:SendKeyEvent(false, Enum.KeyCode.Space, false, game)
	end)
end

---Return the HoverboardInstance module.
function TimeTrial:getHoverboardInstance()
	if self.hoverboardInstance then
		return self.hoverboardInstance
	end
	local playerScripts = localPlayer:FindFirstChild("PlayerScripts")
	local scripts = playerScripts and playerScripts:FindFirstChild("Scripts")
	local gameFolder = scripts and scripts:FindFirstChild("Game")
	local manager = gameFolder and gameFolder:FindFirstChild("Hoverboard Manager")
	local module = manager and manager:FindFirstChild("HoverboardInstance")
	if not module then
		return nil
	end
	local ok, result = pcall(require, module)
	if not ok or type(result) ~= "table" then
		return nil
	end
	self.hoverboardInstance = result
	return result
end

---Compute the steering vector toward the busiest zone.
function TimeTrial:computeDirection()
	local root = getRoot()
	if not root then
		return Vector3.zero, Vector3.zero
	end
	local zone = self:getBestZone()
	if not zone then
		return Vector3.zero, Vector3.zero
	end
	local ok, target = pcall(function()
		return zone.Position
	end)
	if not ok or not target then
		return Vector3.zero, Vector3.zero
	end
	local delta = target - root.Position
	if delta.Magnitude <= TT_STOP_RADIUS then
		return Vector3.zero, Vector3.zero
	end
	return delta.Unit, Vector3.zero
end

---Install the hoverboard steering hook.
function TimeTrial:hookMove()
	if self.moveHooked then
		return true
	end
	local hoverboard = self:getHoverboardInstance()
	if not hoverboard then
		return false
	end
	local original = hoverboard.ComputeMoveDirection
	if type(original) ~= "function" then
		return false
	end

	pcall(setreadonly, hoverboard, false)

	local controller = self
	local replacement = function(boardSelf, ...)
		if not controller.enabled then
			return original(boardSelf, ...)
		end
		local ok, direction, extra = pcall(controller.computeDirection, controller)
		if not ok then
			return original(boardSelf, ...)
		end
		return direction, extra
	end

	local okSet = pcall(function()
		hoverboard.ComputeMoveDirection = replacement
	end)
	if not okSet then
		return false
	end

	self.originalMoveDirection = original
	self.moveHooked = true
	self.context.log("[TT] move hook installed")
	return true
end

---Remove the hoverboard steering hook.
function TimeTrial:unhookMove()
	if not self.moveHooked then
		return
	end
	local hoverboard = self.hoverboardInstance
	if hoverboard and self.originalMoveDirection then
		pcall(function()
			hoverboard.ComputeMoveDirection = self.originalMoveDirection
		end)
	end
	self.originalMoveDirection = nil
	self.moveHooked = false
end

---Leave the trial when the summary appears.
function TimeTrial:watchSummary()
	if self.summaryConnection then
		return
	end
	task.spawn(function()
		local playerGui = localPlayer:FindFirstChild("PlayerGui")
		if not playerGui then
			return
		end
		local summary = playerGui:WaitForChild("TimeTrialSummary", 30)
		if not summary then
			return
		end
		self.summaryConnection = summary:GetPropertyChangedSignal("Enabled"):Connect(function()
			if not summary.Enabled then
				return
			end
			if self.autoLeave then
				local hoverboardCmds = getClientModule("HoverboardCmds")
				if hoverboardCmds and type(hoverboardCmds.LeaveTimeTrial) == "function" then
					pcall(function()
						hoverboardCmds:LeaveTimeTrial()
					end)
				end
			end
			if self.context.notify then
				self.context.notify("Time Trial", "Run finished", 4)
			end
		end)
	end)
end

---Single farm tick.
function TimeTrial:tick()
	if not self:isSpawned() then
		return
	end

	if not self:isInTimeTrial() then
		if self:getDailyRunsLeft() <= 0 then
			if not self.warnedNoRuns then
				self.warnedNoRuns = true
				if self.context.notify then
					self.context.notify("Time Trial", "No daily runs left", 5)
				end
			end
			self:stop()
			return
		end
		self:enter()
		return
	end

	self.warnedNoRuns = false
	self:jump()
end

---Start the farm loop.
function TimeTrial:start()
	if self.enabled then
		return true
	end
	if self:getDailyRunsLeft() <= 0 then
		if self.context.notify then
			self.context.notify("Time Trial", "No daily runs left", 5)
		end
		return false
	end
	self.enabled = true
	self:hookMove()
	self:watchSummary()
	task.spawn(function()
		while self.enabled and self.context.isAlive() do
			pcall(self.tick, self)
			task.wait(TT_FARM_INTERVAL)
		end
		self.enabled = false
		self:unhookMove()
	end)
	self.context.log("[TT] farm started")
	return true
end

---Stop the farm loop.
function TimeTrial:stop()
	self.enabled = false
	self:unhookMove()
end

---Build the Time Trial section inside the Farm tab.
---@param tab any
function TimeTrial:build(tab)
	tab:CreateSection("Time Trial (Hoverboard)")

	local statusLabel = tab:CreateLabel("Daily runs left: ...", "timer", Color3.fromRGB(120, 200, 255), false)

	task.spawn(function()
		while self.context.isAlive() do
			local left = self:getDailyRunsLeft()
			local inside = self:isInTimeTrial()
			pcall(function()
				statusLabel:Set("Daily runs left: " .. tostring(left) .. (inside and "  |  IN TRIAL" or ""))
			end)
			task.wait(2)
		end
	end)

	tab:CreateToggle({
		Name = "Auto Farm Time Trial",
		CurrentValue = false,
		Flag = "TT_AutoFarm",
		Callback = function(state)
			if state then
				if not self:start() then
					if self.context.notify then
						self.context.notify("Time Trial", "Cannot start (no runs left)", 5)
					end
				end
			else
				self:stop()
			end
		end,
	})

	tab:CreateSlider({
		Name = "Steering Radius",
		Range = { 10, 200 },
		Increment = 1,
		Suffix = "Studs",
		CurrentValue = TT_DEFAULT_MOVE_RADIUS,
		Flag = "TT_MoveRadius",
		Callback = function(value)
			self.moveRadius = value
		end,
	})

	tab:CreateToggle({
		Name = "Auto Leave On Summary",
		CurrentValue = true,
		Flag = "TT_AutoLeave",
		Callback = function(state)
			self.autoLeave = state
		end,
	})

	tab:CreateSection("Time Trial — Manual")
	tab:CreateButton({
		Name = "Enter Time Trial",
		Callback = function()
			pcall(self.enter, self)
		end,
	})
	tab:CreateButton({
		Name = "Jump",
		Callback = function()
			pcall(self.jump, self)
		end,
	})
	tab:CreateButton({
		Name = "Leave Time Trial",
		Callback = function()
			local hoverboardCmds = getClientModule("HoverboardCmds")
			if hoverboardCmds and type(hoverboardCmds.LeaveTimeTrial) == "function" then
				pcall(function()
					hoverboardCmds:LeaveTimeTrial()
				end)
			end
		end,
	})

	tab:CreateLabel("TimeTrial v" .. Events.VERSION, "timer", Color3.fromRGB(120, 200, 255), false)
end

-- ══════════════════════════════════════════════════════════
--  PUBLIC API
-- ══════════════════════════════════════════════════════════

---Create a new Events controller.
---@param context table
function Events.new(context)
	local self = setmetatable({}, Events)
	self.context = context
	self.diamondMountain = DiamondMountain.new(context)
	self.timeTrial = TimeTrial.new(context)
	return self
end

---Build every event tab.
---@param tabs table
function Events:build(tabs)
	if not tabs then
		return
	end
	if tabs.mountain then
		self.diamondMountain:build(tabs.mountain)
	end
	if tabs.farm then
		self.timeTrial:build(tabs.farm)
	end
end

---Stop every running event loop.
function Events:destroy()
	self.diamondMountain.features = {}
	self.timeTrial:stop()
end

return Events