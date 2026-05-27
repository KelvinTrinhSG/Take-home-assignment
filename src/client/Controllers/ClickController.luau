--!nocheck
-- ClickController: turns mouse / touch input into a server-validated click on
-- a bag. Bags are client-only parts (created by BagController), so we can't use
-- ClickDetector — it wouldn't replicate. Instead, we raycast against the
-- ActiveBags folder and fire the Knit method on the server.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Knit = require(ReplicatedStorage.Packages.knit)
local Trove = require(ReplicatedStorage.Packages.trove)

local BagConfig = require(ReplicatedStorage.Shared.BagConfig)

local ClickController = Knit.CreateController({ Name = "ClickController" })

function ClickController:KnitInit()
	self._trove = Trove.new()
end

function ClickController:KnitStart()
	local BagService = Knit.GetService("BagService")
	local camera = Workspace.CurrentCamera
	local localPlayer = Players.LocalPlayer

	self._trove:Connect(UserInputService.InputBegan, function(input: InputObject, gameProcessed: boolean)
		if gameProcessed then
			return
		end
		if input.UserInputType ~= Enum.UserInputType.MouseButton1
			and input.UserInputType ~= Enum.UserInputType.Touch
		then
			return
		end

		local folder = Workspace:FindFirstChild(BagConfig.ACTIVE_BAGS_FOLDER)
		if folder == nil then
			return
		end

		local screenPos = input.Position
		local unitRay = camera:ScreenPointToRay(screenPos.X, screenPos.Y)

		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Include
		params.FilterDescendantsInstances = { folder }
		params.IgnoreWater = true

		local result = Workspace:Raycast(unitRay.Origin, unitRay.Direction * 500, params)
		if result == nil or result.Instance == nil then
			return
		end

		local bagId = result.Instance:GetAttribute("BagId")
		if type(bagId) ~= "number" then
			return
		end

		print("[Client]", bagId)
		-- Knit method call returns a Promise; we don't care about the result,
		-- but :catch silences "unhandled rejection" warnings if the server
		-- happens to error.
		BagService:ClickedBag(bagId):catch(function() end)
	end)
end

return ClickController
