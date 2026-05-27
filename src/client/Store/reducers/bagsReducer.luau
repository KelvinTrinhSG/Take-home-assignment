--!strict
-- bagsReducer: state shape is { [bagIdString] = { c, m, t } }. Keys are strings
-- because that's what comes off the replica (Replica disallows gappy numeric
-- tables, so the server stores bag ids as strings).

local actions = require(script.Parent.Parent.actions)

type BagData = { c: number, m: number, t: number }
type State = { [string]: BagData }

local INITIAL: State = {}

local function bagsReducer(state: State?, action: any): State
	state = state or INITIAL

	if action.type == actions.BAG_ADDED then
		local newState = table.clone(state)
		newState[tostring(action.id)] = action.data
		return newState
	elseif action.type == actions.BAG_REMOVED then
		local newState = table.clone(state)
		newState[tostring(action.id)] = nil
		return newState
	elseif action.type == actions.BAGS_RESET then
		-- Defensive clone so external mutations to action.bags don't leak in.
		local copy: State = {}
		for k, v in pairs(action.bags) do
			copy[k] = v
		end
		return copy
	end

	return state
end

return bagsReducer
