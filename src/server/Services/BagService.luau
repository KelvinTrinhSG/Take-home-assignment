--!nocheck
-- BagService: the authoritative bag lifecycle.
--
-- Responsibilities:
--   * Build the static conveyor model once.
--   * Drive spawn/despawn loops at a configurable rate.
--   * Mutate the world replica (Bags map + SpawnRate) so all clients see the
--     same state. Clients render position locally from spawnClock; we never
--     replicate per-frame CFrames.
--   * Validate click events from clients and print the bag id.
--
-- Network strategy: the only per-bag traffic is two Replica deltas per bag
-- (one Set for spawn, one Set-to-nil for despawn). Each delta is a small dict
-- {c, m, t} plus framing. At max rate (10 bags/sec) per-client receive should
-- sit well under 4 KB/s.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Knit = require(ReplicatedStorage.Packages.knit)
local Trove = require(ReplicatedStorage.Packages.trove)
local Log = require(ReplicatedStorage.Packages.log)

local BagConfig = require(ReplicatedStorage.Shared.BagConfig)
local ConveyorMath = require(ReplicatedStorage.Shared.ConveyorMath)
local ConveyorModel = require(ReplicatedStorage.Shared.ConveyorModel)

local WorldReplicaInit = require(script.Parent.Parent.Replicas.WorldReplicaInit)

local log = Log.new()
local MAX_BAG_ID = 65535

local BagService = Knit.CreateService({
	Name = "BagService",
	Client = {},
})

function BagService:KnitInit()
	self._trove = Trove.new()
	self._nextId = 1
	self._spawnAccumulator = 0
	-- Authoritative set of live bag ids (mirrors replica.Data.Bags but indexed
	-- by number for fast iteration during the despawn sweep).
	self._activeIds = {}

	self._replica = WorldReplicaInit.get()
	ConveyorModel.build(Workspace)
end

function BagService:KnitStart()
	local OperatorService = Knit.GetService("OperatorService")
	local DataService = Knit.GetService("DataService")
	self._operatorService = OperatorService
	self._dataService = DataService

	-- When the operator changes, apply that player's persisted rate (if any).
	self._trove:Connect(OperatorService.OperatorChangedSignal, function(player: Player?)
		if player == nil then
			-- Server runs idle when nobody is around; keep rate as-is.
			return
		end
		local stored = DataService:GetLastRate(player)
		self._replica:Set({ "SpawnRate" }, math.clamp(stored, BagConfig.MIN_RATE, BagConfig.MAX_RATE))
	end)

	-- Single Heartbeat connection drives both spawn and despawn loops.
	self._trove:Connect(RunService.Heartbeat, function(dt: number)
		self:_tick(dt)
	end)
end

function BagService:_tick(dt: number)
	local rate = self._replica.Data.SpawnRate
	if rate <= 0 then
		rate = BagConfig.MIN_RATE
	end

	-- Spawn pass. We accumulate dt and emit as many bags as the rate allows
	-- this tick, carrying residual time forward so rate changes don't cause jitter.
	self._spawnAccumulator += dt
	local interval = 1 / rate
	while self._spawnAccumulator >= interval do
		self._spawnAccumulator -= interval
		self:_spawnBag()
		-- Re-read interval in case SpawnRate changes mid-loop (rare but harmless).
		rate = self._replica.Data.SpawnRate
		if rate <= 0 then
			rate = BagConfig.MIN_RATE
		end
		interval = 1 / rate
	end

	-- Despawn pass.
	local now = Workspace:GetServerTimeNow()
	-- Iterate over a snapshot to allow mutation during the loop.
	for id in pairs(self._activeIds) do
		local bagData = self._replica.Data.Bags[tostring(id)]
		if bagData == nil or ConveyorMath.isExpired(bagData.t, now) then
			self:_despawnBag(id)
		end
	end
end

function BagService:_spawnBag()
	local id = self._nextId
	self._nextId += 1
	if self._nextId > MAX_BAG_ID then
		self._nextId = 1
	end

	local payload = {
		c = math.random(1, #BagConfig.COLOR_PALETTE),
		m = math.random(1, #BagConfig.MATERIAL_PALETTE),
		t = Workspace:GetServerTimeNow(),
	}

	self._replica:Set({ "Bags", tostring(id) }, payload)
	self._activeIds[id] = true
end

function BagService:_despawnBag(id: number)
	self._replica:Set({ "Bags", tostring(id) }, nil)
	self._activeIds[id] = nil
end

-- Client-callable: validate and print on the server. Returns nothing; client
-- ignores the Promise result.
function BagService.Client:ClickedBag(player: Player, bagId: number)
	if type(bagId) ~= "number" then
		return
	end
	local service = self.Server
	if service._activeIds[bagId] == nil then
		-- Bag already despawned by the time the click reached us; silently ignore.
		return
	end
	print("[Server]", bagId)
end

-- Client-callable: only the current operator may change the rate.
function BagService.Client:SetSpawnRate(player: Player, rate: number)
	if type(rate) ~= "number" or rate ~= rate then -- NaN guard
		return
	end
	local service = self.Server
	if not service._operatorService:IsOperator(player) then
		log:AtWarning():Log("Non-operator " .. player.Name .. " attempted to set rate")
		return
	end
	local clamped = math.clamp(rate, BagConfig.MIN_RATE, BagConfig.MAX_RATE)
	service._replica:Set({ "SpawnRate" }, clamped)
	service._dataService:SetLastRate(player, clamped)
end

return BagService
