--!nocheck
-- BagComponent: per-bag client visual. Attaches via CollectionService tag "Bag"
-- on Parts that BagController creates. Handles three jobs:
--   1) Spawn animation (fall + grow on Construct/Start)
--   2) Per-frame conveyor movement (RenderSteppedUpdate)
--   3) Despawn animation (triggered when the "Despawning" attribute flips true)
--
-- We never receive a movement update from the network. The Part's position is
-- a pure function of its SpawnClock attribute (set at creation) and the
-- current server time clock.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Component = require(ReplicatedStorage.Packages.component)
local Trove = require(ReplicatedStorage.Packages.trove)

local BagConfig = require(ReplicatedStorage.Shared.BagConfig)
local ConveyorMath = require(ReplicatedStorage.Shared.ConveyorMath)

local SPAWN_DURATION = 0.25
local DESPAWN_DURATION = 0.2

local BagComponent = Component.new({
	Tag = BagConfig.TAG_BAG,
	Ancestors = { Workspace },
})

function BagComponent:Construct()
	self._trove = Trove.new()
	self._spawnClock = self.Instance:GetAttribute("SpawnClock") or Workspace:GetServerTimeNow()
	self._spinPhase = math.random() * math.pi * 2 -- random initial spin so bags don't look mechanical
	self._despawning = false

	-- Set up the starting visual state for the spawn animation. The Part is
	-- already at the correct world XZ position (BagController seeded it above
	-- the belt); we shrink it and make it invisible so the tween "pops" it in.
	self.Instance.Size = BagConfig.BAG_SIZE * 0.3
	self.Instance.Transparency = 1
end

function BagComponent:Start()
	-- Spawn tween: fall to belt level, grow to full size, fade in.
	local now = Workspace:GetServerTimeNow()
	local targetPos = ConveyorMath.getPosition(self._spawnClock, now)
	local goal = {
		Size = BagConfig.BAG_SIZE,
		Transparency = 0,
		CFrame = CFrame.new(targetPos),
	}
	local info = TweenInfo.new(SPAWN_DURATION, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	local tween = TweenService:Create(self.Instance, info, goal)
	self._trove:Add(tween)
	tween:Play()

	-- Listen for the despawn signal from BagController.
	self._trove:Connect(self.Instance:GetAttributeChangedSignal("Despawning"), function()
		if self.Instance:GetAttribute("Despawning") == true then
			self:_despawn()
		end
	end)

	-- Edge case: BagController flipped Despawning before our Start ran.
	if self.Instance:GetAttribute("Despawning") == true then
		self:_despawn()
	end
end

function BagComponent:RenderSteppedUpdate(dt: number)
	if self._despawning then
		-- Tween owns the part's CFrame during despawn; don't fight it.
		return
	end
	local now = Workspace:GetServerTimeNow()
	local elapsed = now - self._spawnClock
	if elapsed < SPAWN_DURATION then
		-- Spawn tween is still playing; let it own the CFrame.
		return
	end
	local pos = ConveyorMath.getPosition(self._spawnClock, now)
	-- Small spin around Y so the bag isn't visually static.
	local angle = (elapsed + self._spinPhase) * 1.5
	self.Instance.CFrame = CFrame.new(pos) * CFrame.Angles(0, angle, 0)
end

function BagComponent:_despawn()
	if self._despawning then
		return
	end
	self._despawning = true

	local info = TweenInfo.new(DESPAWN_DURATION, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	local goal = {
		Size = Vector3.new(0.1, 0.1, 0.1),
		Transparency = 1,
	}
	local tween = TweenService:Create(self.Instance, info, goal)
	self._trove:Add(tween)
	tween.Completed:Connect(function()
		if self.Instance ~= nil and self.Instance.Parent ~= nil then
			self.Instance:Destroy()
		end
	end)
	tween:Play()
end

function BagComponent:Stop()
	self._trove:Destroy()
end

return BagComponent
