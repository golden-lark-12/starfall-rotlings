--!strict
-- Starfall Rotlings: number and time formatting for the HUD.
-- One place for the K/M/B coin counters, the per-second lines and the
-- countdown clocks, so every label on screen reads the same way.

local Formatting = {}

-- Short money: 999 -> "$999", 1,250 -> "$1.25K", 2,400,000 -> "$2.40M".
function Formatting.formatMoney(n: number): string
	local value = math.floor(n)
	if value < 1000 then
		return "$" .. tostring(value)
	elseif value < 1_000_000 then
		return string.format("$%.2fK", value / 1000)
	elseif value < 1_000_000_000 then
		return string.format("$%.2fM", value / 1_000_000)
	else
		return string.format("$%.2fB", value / 1_000_000_000)
	end
end

-- Long money with commas: 1,250,000 -> "$1,250,000".
function Formatting.formatMoneyLong(n: number): string
	local s = tostring(math.floor(n))
	local out = ""
	while #s > 3 do
		out = "," .. string.sub(s, -3) .. out
		s = string.sub(s, 1, -4)
	end
	return "$" .. s .. out
end

-- Income line: "+$1.2K/s" for the HUD, "$300/s" for small labels.
function Formatting.formatCps(n: number): string
	return "+" .. Formatting.formatMoney(n) .. "/s"
end

-- Countdown: 75 -> "1:15", 8 -> "0:08".
function Formatting.formatClock(seconds: number): string
	local total = math.max(0, math.floor(seconds))
	local minutes = math.floor(total / 60)
	local secs = total % 60
	return string.format("%d:%02d", minutes, secs)
end

return Formatting
