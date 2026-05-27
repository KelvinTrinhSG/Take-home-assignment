--!strict
-- BagConfig: shared constants for the conveyor belt.
-- Lives in ReplicatedStorage so server and client stay in lockstep on speed,
-- palette indices, and rate bounds without sending these over the network.

local BagConfig = {}

-- Conveyor geometry: bags travel along +X.
BagConfig.CONVEYOR_START = Vector3.new(0, 5, 0)
BagConfig.CONVEYOR_END = Vector3.new(50, 5, 0)
BagConfig.CONVEYOR_LENGTH = 50
BagConfig.CONVEYOR_WIDTH = 4
BagConfig.CONVEYOR_HEIGHT = 1
BagConfig.CONVEYOR_SPEED = 8 -- studs/sec; full traversal ~6.25s
BagConfig.BAG_SIZE = Vector3.new(2, 2, 2)

-- Spawn rate bounds (bags/sec). Clamped server-side on every SetSpawnRate call.
BagConfig.MIN_RATE = 0.1
BagConfig.MAX_RATE = 10
BagConfig.DEFAULT_RATE = 1

-- Color palette. Index sent over the wire as a uint8 so each bag spawn payload
-- carries 1 byte for color instead of a full Color3 (3 floats).
BagConfig.COLOR_PALETTE = {
	Color3.fromRGB(231, 76, 60),
	Color3.fromRGB(230, 126, 34),
	Color3.fromRGB(241, 196, 15),
	Color3.fromRGB(46, 204, 113),
	Color3.fromRGB(26, 188, 156),
	Color3.fromRGB(52, 152, 219),
	Color3.fromRGB(155, 89, 182),
	Color3.fromRGB(231, 76, 134),
	Color3.fromRGB(149, 165, 166),
	Color3.fromRGB(52, 73, 94),
	Color3.fromRGB(243, 156, 18),
	Color3.fromRGB(192, 57, 43),
	Color3.fromRGB(22, 160, 133),
	Color3.fromRGB(39, 174, 96),
	Color3.fromRGB(41, 128, 185),
	Color3.fromRGB(142, 68, 173),
}

-- Material palette. Same uint8-index trick.
BagConfig.MATERIAL_PALETTE = {
	Enum.Material.Plastic,
	Enum.Material.Wood,
	Enum.Material.Metal,
	Enum.Material.Slate,
	Enum.Material.Concrete,
	Enum.Material.Granite,
	Enum.Material.Marble,
	Enum.Material.Pebble,
	Enum.Material.Fabric,
	Enum.Material.Sand,
	Enum.Material.Brick,
	Enum.Material.Cobblestone,
}

-- CollectionService tags used to attach client-side Components.
BagConfig.TAG_BAG = "Bag"
BagConfig.TAG_CONVEYOR = "ConveyorBelt"

-- Replica token name. Server creates the token, client listens for replicas with
-- this name.
BagConfig.REPLICA_TOKEN = "World"

-- Folder name in workspace that holds client-rendered bag parts.
BagConfig.ACTIVE_BAGS_FOLDER = "ActiveBags"

return BagConfig
