--!nocheck
-- WorldReplicaInit: lazily constructs and returns the single world Replica that
-- holds Bags, SpawnRate, and OperatorUserId. Replica.Token can only be created
-- once per name, so this module memoizes both the token and the replica.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Replica = require(ServerScriptService.ServerPackages.replicaserver)
local BagConfig = require(ReplicatedStorage.Shared.BagConfig)

local WorldReplicaInit = {}

local replica = nil

function WorldReplicaInit.get()
	if replica ~= nil then
		return replica
	end

	local token = Replica.Token(BagConfig.REPLICA_TOKEN)
	replica = Replica.New({
		Token = token,
		Data = {
			-- Bags is keyed by tostring(bagId). Replica disallows numeric tables with
			-- gaps; string keys avoid that pitfall entirely.
			Bags = {},
			SpawnRate = BagConfig.DEFAULT_RATE,
			OperatorUserId = 0,
		},
	})
	-- Make the replica visible to every ready and future-ready player.
	replica:Replicate()

	return replica
end

return WorldReplicaInit
