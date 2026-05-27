--!strict
-- ConveyorModel: builds the static belt visual. Called once on the server
-- during KnitInit. The resulting model is a single anchored Part that Roblox
-- auto-replicates to every client. After replication it never changes, so it
-- carries no ongoing bandwidth cost.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BagConfig = require(ReplicatedStorage.Shared.BagConfig)

local ConveyorModel = {}

function ConveyorModel.build(parent: Instance): Model
	local model = Instance.new("Model")
	model.Name = "Conveyor"

	local belt = Instance.new("Part")
	belt.Name = "Belt"
	belt.Anchored = true
	belt.CanCollide = true
	belt.CanQuery = false
	belt.CastShadow = true
	belt.Material = Enum.Material.DiamondPlate
	belt.Color = Color3.fromRGB(60, 60, 65)
	belt.Size = Vector3.new(
		BagConfig.CONVEYOR_LENGTH,
		BagConfig.CONVEYOR_HEIGHT,
		BagConfig.CONVEYOR_WIDTH
	)
	-- Center the belt between CONVEYOR_START and CONVEYOR_END, with its top
	-- surface aligned to the bag travel plane.
	local center = (BagConfig.CONVEYOR_START + BagConfig.CONVEYOR_END) * 0.5
	belt.CFrame = CFrame.new(center - Vector3.new(0, BagConfig.CONVEYOR_HEIGHT * 0.5 + 1, 0))
	belt.Parent = model

	-- Tag for the client-side ConveyorVisualComponent (scrolling texture effect).
	CollectionService:AddTag(belt, BagConfig.TAG_CONVEYOR)

	-- Direction arrow texture on the top surface.
	local arrow = Instance.new("Texture")
	arrow.Face = Enum.NormalId.Top
	arrow.Texture = "rbxasset://textures/SurfacesDefault.png"
	arrow.StudsPerTileU = 4
	arrow.StudsPerTileV = 4
	arrow.Transparency = 0.5
	arrow.Parent = belt

	-- Endcap markers so it's obvious where bags enter and exit the belt.
	local function makeEndcap(name: string, position: Vector3, color: Color3)
		local cap = Instance.new("Part")
		cap.Name = name
		cap.Anchored = true
		cap.CanCollide = false
		cap.CanQuery = false
		cap.Material = Enum.Material.Neon
		cap.Color = color
		cap.Size = Vector3.new(0.5, BagConfig.CONVEYOR_HEIGHT + 0.2, BagConfig.CONVEYOR_WIDTH)
		cap.CFrame = CFrame.new(position - Vector3.new(0, BagConfig.CONVEYOR_HEIGHT * 0.5 + 1, 0))
		cap.Parent = model
	end
	makeEndcap("SpawnCap", BagConfig.CONVEYOR_START, Color3.fromRGB(0, 200, 120))
	makeEndcap("DespawnCap", BagConfig.CONVEYOR_END, Color3.fromRGB(200, 60, 60))

	model.Parent = parent
	return model
end

return ConveyorModel
