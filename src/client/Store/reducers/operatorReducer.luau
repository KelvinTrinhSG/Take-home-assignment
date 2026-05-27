--!strict
local actions = require(script.Parent.Parent.actions)

-- State is the operator's UserId, or 0 when no operator is assigned.
local function operatorReducer(state: number?, action: any): number
	state = state or 0
	if action.type == actions.OPERATOR_CHANGED then
		return action.userId
	end
	return state
end

return operatorReducer
