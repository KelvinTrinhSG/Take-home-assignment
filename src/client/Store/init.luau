--!nocheck
-- Client Rodux store. The store is the source of truth for "what the UI and
-- the bag renderer should see right now"; the Replica is the source of truth
-- across the network. ReplicaController bridges Replica events into store
-- actions so the rest of the client code only needs to care about Rodux state.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Rodux = require(ReplicatedStorage.Packages.rodux)

local bagsReducer = require(script.reducers.bagsReducer)
local spawnRateReducer = require(script.reducers.spawnRateReducer)
local operatorReducer = require(script.reducers.operatorReducer)

local rootReducer = Rodux.combineReducers({
	bags = bagsReducer,
	spawnRate = spawnRateReducer,
	operator = operatorReducer,
})

local store = Rodux.Store.new(rootReducer)

return store
