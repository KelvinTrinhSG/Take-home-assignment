--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local actions = require(script.Parent.Parent.actions)
local BagConfig = require(ReplicatedStorage.Shared.BagConfig)

local function spawnRateReducer(state: number?, action: any): number
	if state == nil then
		state = BagConfig.DEFAULT_RATE
	end

	if action.type == actions.SPAWN_RATE_CHANGED then
		return action.rate
	end

	return state
end

return spawnRateReducer
