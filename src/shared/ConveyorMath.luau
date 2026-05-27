--!strict
-- ConveyorMath: pure functions that derive bag position from elapsed time.
-- Both the server (for despawn timing) and the client (for per-frame rendering)
-- call into this so they agree on bag position without exchanging CFrames.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BagConfig = require(ReplicatedStorage.Shared.BagConfig)

local ConveyorMath = {}

-- Returns the world position of a bag whose spawnClock was `spawnClock`,
-- evaluated at `nowClock`. Both clocks are workspace:GetServerTimeNow() values
-- (synchronized server time available on both server and client).
function ConveyorMath.getPosition(spawnClock: number, nowClock: number): Vector3
	local elapsed = nowClock - spawnClock
	local distance = math.clamp(elapsed * BagConfig.CONVEYOR_SPEED, 0, BagConfig.CONVEYOR_LENGTH)
	local alpha = distance / BagConfig.CONVEYOR_LENGTH
	return BagConfig.CONVEYOR_START:Lerp(BagConfig.CONVEYOR_END, alpha)
end

-- Returns true when the bag has reached the end of the belt and should be despawned.
function ConveyorMath.isExpired(spawnClock: number, nowClock: number): boolean
	return (nowClock - spawnClock) >= (BagConfig.CONVEYOR_LENGTH / BagConfig.CONVEYOR_SPEED)
end

return ConveyorMath
