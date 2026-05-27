-- Client entry point. Components must be required before Knit.Start() so
-- their CollectionService tag listeners are active when the world replica
-- starts streaming parts to us; otherwise we could miss the conveyor's
-- ConveyorVisualComponent attachment on a cold join.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.knit)

require(script.Components.BagComponent)
require(script.Components.ConveyorVisualComponent)

Knit.AddControllers(script.Controllers)

Knit.Start():andThen(function()
	print("[ConveyorClient] Knit started")
end):catch(warn)
