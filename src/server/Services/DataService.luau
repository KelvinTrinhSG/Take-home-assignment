--!nocheck
-- DataService: thin ProfileStore wrapper. Persists the operator's last-set
-- spawn rate so the rate carries across sessions for that player.
-- Demonstrates ProfileStore usage; not strictly required by the task spec.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Knit = require(ReplicatedStorage.Packages.knit)
local ProfileStore = require(ServerScriptService.ServerPackages.profilestore)
local Log = require(ReplicatedStorage.Packages.log)

local BagConfig = require(ReplicatedStorage.Shared.BagConfig)

local log = Log.new()

local PROFILE_TEMPLATE = {
	LastSpawnRate = BagConfig.DEFAULT_RATE,
}

local DataService = Knit.CreateService({
	Name = "DataService",
	Client = {},
})

function DataService:KnitInit()
	self._store = ProfileStore.New("ConveyorPlayerData_v1", PROFILE_TEMPLATE)
	self._profiles = {} -- [player] = profile
end

function DataService:KnitStart()
	Players.PlayerAdded:Connect(function(player)
		self:_onPlayerAdded(player)
	end)
	for _, player in ipairs(Players:GetPlayers()) do
		task.spawn(function()
			self:_onPlayerAdded(player)
		end)
	end

	Players.PlayerRemoving:Connect(function(player)
		local profile = self._profiles[player]
		if profile ~= nil then
			profile:EndSession()
			self._profiles[player] = nil
		end
	end)
end

function DataService:_onPlayerAdded(player: Player)
	-- StartSessionAsync yields; guard against double-load if PlayerRemoving races.
	local profile = self._store:StartSessionAsync("Player_" .. player.UserId, {
		Cancel = function()
			return player.Parent ~= Players
		end,
	})
	if profile == nil then
		log:AtWarning():Log("Failed to load profile for " .. player.Name)
		player:Kick("Failed to load saved data. Please rejoin.")
		return
	end

	profile:AddUserId(player.UserId)
	profile:Reconcile()
	profile.OnSessionEnd:Connect(function()
		self._profiles[player] = nil
		if player.Parent == Players then
			player:Kick("Profile session ended.")
		end
	end)

	if player.Parent ~= Players then
		profile:EndSession()
		return
	end

	self._profiles[player] = profile
end

-- Returns the player's last persisted spawn rate, or the default if unloaded.
function DataService:GetLastRate(player: Player): number
	local profile = self._profiles[player]
	if profile == nil then
		return BagConfig.DEFAULT_RATE
	end
	return profile.Data.LastSpawnRate or BagConfig.DEFAULT_RATE
end

-- Persist the player's last-set rate. Silently no-ops if profile is unavailable.
function DataService:SetLastRate(player: Player, rate: number)
	local profile = self._profiles[player]
	if profile == nil or not profile:IsActive() then
		return
	end
	profile.Data.LastSpawnRate = rate
end

return DataService
