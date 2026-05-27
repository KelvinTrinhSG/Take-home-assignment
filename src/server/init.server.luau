-- Server entry point. Boots Knit with every Service module inside Services/.
-- BagService creates the conveyor model and the world replica in its KnitInit,
-- OperatorService elects the operator, DataService backs the operator's
-- persisted rate with ProfileStore.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.knit)

Knit.AddServices(script.Services)

Knit.Start():andThen(function()
	print("[ConveyorServer] Knit started")
end):catch(warn)
