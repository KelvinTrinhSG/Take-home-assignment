--!nocheck
-- OperatorService: tracks join order so we can elect "the first player" as the
-- one allowed to drive the spawn-rate slider. When that player leaves, the role
-- transfers to whoever joined next.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.knit)
local Signal = require(ReplicatedStorage.Packages.signal)
local Log = require(ReplicatedStorage.Packages.log)

local WorldReplicaInit = require(script.Parent.Parent.Replicas.WorldReplicaInit)

local log = Log.new()

local OperatorService = Knit.CreateService({
	Name = "OperatorService",
	Client = {},
})

function OperatorService:KnitInit()
	self._queue = {} -- ordered array of Player, longest-resident first
	self._current = nil
	-- Internal signal so BagService can react to operator changes without
	-- importing the replica directly.
	self.OperatorChangedSignal = Signal.new()
end

function OperatorService:KnitStart()
	self._replica = WorldReplicaInit.get()

	Players.PlayerAdded:Connect(function(player)
		self:_addPlayer(player)
	end)
	for _, player in ipairs(Players:GetPlayers()) do
		self:_addPlayer(player)
	end

	Players.PlayerRemoving:Connect(function(player)
		self:_removePlayer(player)
	end)
end

function OperatorService:_addPlayer(player: Player)
	-- Avoid duplicate entries if PlayerAdded fires for an already-tracked player.
	for _, existing in ipairs(self._queue) do
		if existing == player then
			return
		end
	end
	table.insert(self._queue, player)
	self:_recompute()
end

function OperatorService:_removePlayer(player: Player)
	for i, existing in ipairs(self._queue) do
		if existing == player then
			table.remove(self._queue, i)
			break
		end
	end
	self:_recompute()
end

function OperatorService:_recompute()
	local newOperator = self._queue[1]
	if newOperator == self._current then
		return
	end
	self._current = newOperator

	local userId = if newOperator ~= nil then newOperator.UserId else 0
	self._replica:Set({ "OperatorUserId" }, userId)
	log:AtInfo():Log("Operator is now " .. tostring(newOperator and newOperator.Name or "<none>"))
	self.OperatorChangedSignal:Fire(newOperator)
end

-- Authoritative check used by BagService.Client.SetSpawnRate.
function OperatorService:IsOperator(player: Player): boolean
	return self._current == player
end

function OperatorService:GetCurrent(): Player?
	return self._current
end

return OperatorService
