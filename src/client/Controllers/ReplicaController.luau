--!nocheck
-- ReplicaController: subscribes to the singleton World replica and translates
-- every change into a Rodux action. This is the only place in the client that
-- knows about the Replica API; everything else reads Rodux state.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.knit)
local ReplicaClient = require(ReplicatedStorage.Packages.ReplicaClient)
local Trove = require(ReplicatedStorage.Packages.trove)
local Log = require(ReplicatedStorage.Packages.log)

local BagConfig = require(ReplicatedStorage.Shared.BagConfig)
local store = require(script.Parent.Parent.Store)
local actions = require(script.Parent.Parent.Store.actions)

local log = Log.new()

local ReplicaController = Knit.CreateController({ Name = "ReplicaController" })

function ReplicaController:KnitInit()
	self._trove = Trove.new()
end

function ReplicaController:KnitStart()
	-- Listen for the world replica. OnNew is registered first, then we ask the
	-- server to start streaming so we don't miss the initial creation event.
	ReplicaClient.OnNew(BagConfig.REPLICA_TOKEN, function(replica)
		self:_bind(replica)
	end)

	ReplicaClient.RequestData()
	log:AtInfo():Log("ReplicaController requested initial data")
end

function ReplicaController:_bind(replica)
	-- Seed the store with whatever bags / rate / operator the snapshot already
	-- contains, then start listening for further deltas.
	store:dispatch(actions.bagsReset(replica.Data.Bags or {}))
	store:dispatch(actions.spawnRateChanged(replica.Data.SpawnRate or BagConfig.DEFAULT_RATE))
	store:dispatch(actions.operatorChanged(replica.Data.OperatorUserId or 0))

	-- OnChange fires for every :Set / :SetValues / :TableInsert / :TableRemove
	-- on the replica. We only care about :Set in this project.
	replica:OnChange(function(action, path, newValue, oldValue)
		if action ~= "Set" then
			return
		end

		local first = path[1]
		if first == "Bags" then
			-- path is {"Bags", "<bagId>"}; newValue is the bag data table or nil.
			local idStr = path[2]
			if idStr == nil then
				return
			end
			local idNum = tonumber(idStr)
			if idNum == nil then
				return
			end
			if newValue == nil then
				store:dispatch(actions.bagRemoved(idNum))
			else
				store:dispatch(actions.bagAdded(idNum, newValue))
			end
		elseif first == "SpawnRate" then
			store:dispatch(actions.spawnRateChanged(newValue))
		elseif first == "OperatorUserId" then
			store:dispatch(actions.operatorChanged(newValue))
		end
	end)
end

return ReplicaController
