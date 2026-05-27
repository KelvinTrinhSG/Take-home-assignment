--!nocheck
-- BagController: reflects the Rodux bags slice into concrete client-side Parts.
-- The actual rendering (spawn anim, per-frame movement, despawn anim) lives in
-- BagComponent; this controller only diffs the state and creates/destroys
-- tagged Parts so the Component framework picks them up.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Knit = require(ReplicatedStorage.Packages.knit)
local Trove = require(ReplicatedStorage.Packages.trove)

local BagConfig = require(ReplicatedStorage.Shared.BagConfig)
local store = require(script.Parent.Parent.Store)

local BagController = Knit.CreateController({ Name = "BagController" })

function BagController:KnitInit()
	self._trove = Trove.new()
	self._parts = {} -- [idString] = Part
end

function BagController:KnitStart()
	-- Folder that holds every live bag part. Raycasts in ClickController filter
	-- on this folder so the conveyor belt and the avatar never produce hits.
	local folder = self._trove:Add(Instance.new("Folder"))
	folder.Name = BagConfig.ACTIVE_BAGS_FOLDER
	folder.Parent = Workspace
	self._folder = folder

	-- Subscribe to the bags slice. Rodux's store.changed fires (newState, oldState)
	-- on every dispatched action, so we diff to detect adds and removes. The
	-- returned table uses lowercase `disconnect`, which Trove 0.0.1 doesn't
	-- auto-detect — pass the function directly so Trove treats it as a callable.
	local lastBags = store:getState().bags
	local subscription = store.changed:connect(function(newState)
		local newBags = newState.bags
		if newBags == lastBags then
			return
		end

		-- Detect additions.
		for idStr, data in pairs(newBags) do
			if lastBags[idStr] == nil and self._parts[idStr] == nil then
				self:_createBag(idStr, data)
			end
		end

		-- Detect removals.
		for idStr in pairs(lastBags) do
			if newBags[idStr] == nil and self._parts[idStr] ~= nil then
				self:_removeBag(idStr)
			end
		end

		lastBags = newBags
	end)
	self._trove:Add(subscription.disconnect)

	-- Handle bags that were already present when the controller started (e.g.
	-- BAGS_RESET dispatched from ReplicaController before this subscription).
	for idStr, data in pairs(lastBags) do
		if self._parts[idStr] == nil then
			self:_createBag(idStr, data)
		end
	end
end

function BagController:_createBag(idStr: string, data: { c: number, m: number, t: number })
	local part = Instance.new("Part")
	part.Name = "Bag_" .. idStr
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = true -- clicks need to be able to raycast into this part
	part.CanTouch = false
	part.CastShadow = false
	part.Size = BagConfig.BAG_SIZE
	part.Color = BagConfig.COLOR_PALETTE[data.c] or Color3.new(1, 1, 1)
	part.Material = BagConfig.MATERIAL_PALETTE[data.m] or Enum.Material.Plastic

	-- Attributes drive the BagComponent. Using attributes (instead of a side
	-- table or constructor args) means BagComponent stays self-sufficient if
	-- the part is ever inspected in isolation.
	part:SetAttribute("BagId", tonumber(idStr))
	part:SetAttribute("SpawnClock", data.t)
	part:SetAttribute("Despawning", false)

	-- Position at spawn point with the spawn-animation starting offset; the
	-- BagComponent's :Start() will tween it to the on-belt position.
	part.CFrame = CFrame.new(BagConfig.CONVEYOR_START + Vector3.new(0, 6, 0))

	part.Parent = self._folder
	CollectionService:AddTag(part, BagConfig.TAG_BAG)

	self._parts[idStr] = part
end

function BagController:_removeBag(idStr: string)
	local part = self._parts[idStr]
	if part == nil then
		return
	end
	self._parts[idStr] = nil
	-- BagComponent watches the "Despawning" attribute and runs the destroy
	-- animation + tear-down itself. We don't destroy the part here.
	if part.Parent ~= nil then
		part:SetAttribute("Despawning", true)
	end
end

return BagController
