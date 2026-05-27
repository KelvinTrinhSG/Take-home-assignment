--!nocheck
-- SliderGui: programmatic ScreenGui with a horizontal slider + numeric readout.
-- No Studio asset; the UI is built entirely in code so it lives in version
-- control and doesn't drift from the codebase.
--
-- Returns a handle: { Gui, Changed, SetValue, Destroy }.
--   Changed:Connect(rate)  fired whenever the user moves the knob
--   SetValue(rate, silent) programmatic update (silent=true skips Changed)
--   Destroy()              cleans up

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Signal = require(ReplicatedStorage.Packages.signal)
local Trove = require(ReplicatedStorage.Packages.trove)

local SliderGui = {}

local TRACK_WIDTH = 280
local TRACK_HEIGHT = 8
local KNOB_SIZE = 22

local function clamp(value: number, min: number, max: number): number
	if value < min then return min end
	if value > max then return max end
	return value
end

function SliderGui.create(config: { Min: number, Max: number, Initial: number })
	local trove = Trove.new()

	local localPlayer = Players.LocalPlayer
	local playerGui = localPlayer:WaitForChild("PlayerGui")

	local gui = Instance.new("ScreenGui")
	gui.Name = "ConveyorSliderGui"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

	local frame = Instance.new("Frame")
	frame.Name = "Container"
	frame.AnchorPoint = Vector2.new(0, 0)
	frame.Position = UDim2.new(0, 16, 0, 16)
	frame.Size = UDim2.new(0, TRACK_WIDTH + 40, 0, 96)
	frame.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
	frame.BackgroundTransparency = 0.15
	frame.BorderSizePixel = 0
	frame.Parent = gui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = frame

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Position = UDim2.new(0, 16, 0, 8)
	title.Size = UDim2.new(1, -32, 0, 18)
	title.BackgroundTransparency = 1
	title.Text = "Bag spawn rate"
	title.Font = Enum.Font.GothamMedium
	title.TextSize = 14
	title.TextColor3 = Color3.fromRGB(220, 220, 230)
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Parent = frame

	local value = Instance.new("TextLabel")
	value.Name = "Value"
	value.Position = UDim2.new(0, 16, 0, 28)
	value.Size = UDim2.new(1, -32, 0, 20)
	value.BackgroundTransparency = 1
	value.Font = Enum.Font.GothamBold
	value.TextSize = 16
	value.TextColor3 = Color3.fromRGB(255, 255, 255)
	value.TextXAlignment = Enum.TextXAlignment.Left
	value.Text = string.format("%.2f bags/sec", config.Initial)
	value.Parent = frame

	local track = Instance.new("Frame")
	track.Name = "Track"
	track.Position = UDim2.new(0, 20, 1, -22)
	track.Size = UDim2.new(0, TRACK_WIDTH, 0, TRACK_HEIGHT)
	track.AnchorPoint = Vector2.new(0, 0.5)
	track.BackgroundColor3 = Color3.fromRGB(60, 60, 75)
	track.BorderSizePixel = 0
	track.Parent = frame

	local trackCorner = Instance.new("UICorner")
	trackCorner.CornerRadius = UDim.new(0, 4)
	trackCorner.Parent = track

	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.new(0, 0, 1, 0)
	fill.BackgroundColor3 = Color3.fromRGB(0, 170, 255)
	fill.BorderSizePixel = 0
	fill.Parent = track
	local fillCorner = Instance.new("UICorner")
	fillCorner.CornerRadius = UDim.new(0, 4)
	fillCorner.Parent = fill

	local knob = Instance.new("Frame")
	knob.Name = "Knob"
	knob.AnchorPoint = Vector2.new(0.5, 0.5)
	knob.Size = UDim2.new(0, KNOB_SIZE, 0, KNOB_SIZE)
	knob.Position = UDim2.new(0, 0, 0.5, 0)
	knob.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	knob.BorderSizePixel = 0
	knob.Parent = track
	local knobCorner = Instance.new("UICorner")
	knobCorner.CornerRadius = UDim.new(1, 0)
	knobCorner.Parent = knob

	trove:Add(gui)
	gui.Parent = playerGui

	local changed = Signal.new()
	trove:Add(changed)

	local currentValue = config.Initial
	local suppressEvent = false

	local function alphaFromValue(v: number): number
		return (v - config.Min) / (config.Max - config.Min)
	end

	local function valueFromAlpha(a: number): number
		return config.Min + a * (config.Max - config.Min)
	end

	local function applyVisual(v: number)
		local alpha = clamp(alphaFromValue(v), 0, 1)
		fill.Size = UDim2.new(alpha, 0, 1, 0)
		knob.Position = UDim2.new(alpha, 0, 0.5, 0)
		value.Text = string.format("%.2f bags/sec", v)
	end

	local function setValue(v: number, silent: boolean?)
		v = clamp(v, config.Min, config.Max)
		if math.abs(v - currentValue) < 1e-4 then
			return
		end
		currentValue = v
		applyVisual(v)
		if not silent then
			changed:Fire(v)
		end
	end

	applyVisual(currentValue)

	-- Dragging behavior. We detect mouse-down on the track or knob, then on
	-- every InputChanged update the value while the input is active.
	local dragging = false

	local function updateFromMouse(input: InputObject)
		local absPos = track.AbsolutePosition
		local absSize = track.AbsoluteSize
		local screenX = input.Position.X
		local alpha = clamp((screenX - absPos.X) / absSize.X, 0, 1)
		setValue(valueFromAlpha(alpha), false)
	end

	trove:Connect(track.InputBegan, function(input: InputObject)
		if input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		then
			dragging = true
			updateFromMouse(input)
		end
	end)
	trove:Connect(knob.InputBegan, function(input: InputObject)
		if input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		then
			dragging = true
		end
	end)
	trove:Connect(UserInputService.InputChanged, function(input: InputObject)
		if not dragging then return end
		if input.UserInputType == Enum.UserInputType.MouseMovement
			or input.UserInputType == Enum.UserInputType.Touch
		then
			updateFromMouse(input)
		end
	end)
	trove:Connect(UserInputService.InputEnded, function(input: InputObject)
		if input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		then
			dragging = false
		end
	end)

	return {
		Gui = gui,
		Changed = changed,
		SetValue = setValue,
		Destroy = function()
			trove:Destroy()
		end,
	}
end

return SliderGui
