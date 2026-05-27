--!nocheck
-- OperatorController: mounts the slider UI iff the local player is the
-- designated operator. Subscribes to the Rodux operator slice so we react
-- automatically when the server transfers ownership on player leave.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.knit)
local Trove = require(ReplicatedStorage.Packages.trove)
local Promise = require(ReplicatedStorage.Packages.promise)

local BagConfig = require(ReplicatedStorage.Shared.BagConfig)
local SliderGui = require(script.Parent.Parent.UI.SliderGui)
local store = require(script.Parent.Parent.Store)

local DEBOUNCE_SECONDS = 0.1

local OperatorController = Knit.CreateController({ Name = "OperatorController" })

function OperatorController:KnitInit()
	self._trove = Trove.new()
	self._sliderHandle = nil -- { Gui, Changed, SetValue, Destroy, _trove }
	self._pendingDispatch = nil -- Promise instance for the debounced server call
end

function OperatorController:KnitStart()
	local BagService = Knit.GetService("BagService")
	local localPlayer = Players.LocalPlayer

	local lastOperator = -1
	self._trove:Add(store.changed:connect(function(newState, _oldState)
		local op = newState.operator
		if op == lastOperator then
			-- Still relevant: keep the slider value synced even if operator unchanged.
			if self._sliderHandle ~= nil then
				self._sliderHandle.SetValue(newState.spawnRate, true)
			end
			return
		end
		lastOperator = op

		if op == localPlayer.UserId then
			self:_mountSlider(BagService, newState.spawnRate)
		else
			self:_unmountSlider()
		end
	end))

	-- Cover the case where the operator was already us before this subscription
	-- attached.
	local current = store:getState()
	if current.operator == localPlayer.UserId then
		self:_mountSlider(BagService, current.spawnRate)
		lastOperator = current.operator
	end
end

function OperatorController:_mountSlider(BagService, initialRate: number)
	if self._sliderHandle ~= nil then
		self._sliderHandle.SetValue(initialRate, true)
		return
	end
	local handle = SliderGui.create({
		Min = BagConfig.MIN_RATE,
		Max = BagConfig.MAX_RATE,
		Initial = initialRate,
	})
	handle.Changed:Connect(function(rate)
		self:_scheduleDispatch(BagService, rate)
	end)
	self._sliderHandle = handle
end

function OperatorController:_unmountSlider()
	if self._sliderHandle == nil then
		return
	end
	self._sliderHandle.Destroy()
	self._sliderHandle = nil
end

-- Debounce slider updates with Promise.delay so we don't spam the server while
-- the user is dragging. Each new value cancels the previous pending promise.
function OperatorController:_scheduleDispatch(BagService, rate: number)
	if self._pendingDispatch ~= nil then
		self._pendingDispatch:cancel()
	end
	self._pendingDispatch = Promise.delay(DEBOUNCE_SECONDS):andThen(function()
		self._pendingDispatch = nil
		BagService:SetSpawnRate(rate):catch(function() end)
	end)
end

return OperatorController
