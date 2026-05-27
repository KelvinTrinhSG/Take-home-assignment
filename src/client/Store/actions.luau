--!strict
-- Rodux action creators. Centralized here so action type strings live in one
-- place and reducers stay in sync.

local actions = {}

actions.BAG_ADDED = "BAG_ADDED"
actions.BAG_REMOVED = "BAG_REMOVED"
actions.BAGS_RESET = "BAGS_RESET"
actions.SPAWN_RATE_CHANGED = "SPAWN_RATE_CHANGED"
actions.OPERATOR_CHANGED = "OPERATOR_CHANGED"

function actions.bagAdded(id: number, data: { c: number, m: number, t: number })
	return { type = actions.BAG_ADDED, id = id, data = data }
end

function actions.bagRemoved(id: number)
	return { type = actions.BAG_REMOVED, id = id }
end

-- Used to seed all existing bags when the replica first arrives.
function actions.bagsReset(bags: { [string]: { c: number, m: number, t: number } })
	return { type = actions.BAGS_RESET, bags = bags }
end

function actions.spawnRateChanged(rate: number)
	return { type = actions.SPAWN_RATE_CHANGED, rate = rate }
end

function actions.operatorChanged(userId: number)
	return { type = actions.OPERATOR_CHANGED, userId = userId }
end

return actions
