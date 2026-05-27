--!nocheck
-- ConveyorVisualComponent: attaches to the tagged conveyor Part. Animates a
-- subtle scrolling texture offset so the belt visually "moves" in the same
-- direction as the bags. Purely cosmetic; no network cost.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Component = require(ReplicatedStorage.Packages.component)
local Trove = require(ReplicatedStorage.Packages.trove)

local BagConfig = require(ReplicatedStorage.Shared.BagConfig)

local ConveyorVisualComponent = Component.new({
	Tag = BagConfig.TAG_CONVEYOR,
	Ancestors = { Workspace },
	AutoSetup = true,
})

function ConveyorVisualComponent:Construct()
	self._trove = Trove.new()
end

function ConveyorVisualComponent:Start()
	-- Find the top-face arrow texture and scroll it along U at belt speed.
	local texture: Texture? = nil
	for _, child in ipairs(self.Instance:GetChildren()) do
		if child:IsA("Texture") and child.Face == Enum.NormalId.Top then
			texture = child
			break
		end
	end
	if texture == nil then
		return
	end
	self._texture = texture
end

function ConveyorVisualComponent:HeartbeatUpdate(dt: number)
	if self._texture == nil then
		return
	end
	-- Scroll the texture U coordinate to give the illusion of the belt moving.
	local offset = self._texture.OffsetStudsU - BagConfig.CONVEYOR_SPEED * dt
	-- Keep the value bounded to avoid float drift over a long session.
	if offset < -1e6 then
		offset += 1e6
	end
	self._texture.OffsetStudsU = offset
end

function ConveyorVisualComponent:Stop()
	self._trove:Destroy()
end

return ConveyorVisualComponent
