local Format = {}

local SUFFIXES = { "", "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No", "Dc" }

-- 1234 -> "1.23K", 15300000 -> "15.3M"
function Format.short(n: number): string
	n = tonumber(n) or 0
	local neg = n < 0
	n = math.abs(n)
	if n < 1000 then
		local s = tostring(math.floor(n))
		return neg and "-" .. s or s
	end
	local i = 1
	while n >= 1000 and i < #SUFFIXES do
		n /= 1000
		i += 1
	end
	local s
	if n >= 100 then
		s = string.format("%d", math.floor(n))
	elseif n >= 10 then
		s = string.format("%.1f", math.floor(n * 10) / 10)
	else
		s = string.format("%.2f", math.floor(n * 100) / 100)
	end
	s = s:gsub("%.?0+$", "") .. SUFFIXES[i]
	return neg and "-" .. s or s
end

-- 1234567 -> "1,234,567"
function Format.commas(n: number): string
	local s = tostring(math.floor(tonumber(n) or 0))
	local neg = s:sub(1, 1) == "-"
	if neg then
		s = s:sub(2)
	end
	s = s:reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
	return neg and "-" .. s or s
end

-- 75 -> "1:15", 3725 -> "1:02:05"
function Format.clock(seconds: number): string
	seconds = math.max(0, math.floor(seconds))
	local h = math.floor(seconds / 3600)
	local m = math.floor(seconds % 3600 / 60)
	local s = seconds % 60
	if h > 0 then
		return string.format("%d:%02d:%02d", h, m, s)
	end
	return string.format("%d:%02d", m, s)
end

-- 75 -> "1m 15s", 3725 -> "1h 2m"
function Format.duration(seconds: number): string
	seconds = math.max(0, math.floor(seconds))
	if seconds < 60 then
		return seconds .. "s"
	elseif seconds < 3600 then
		local m, s = math.floor(seconds / 60), seconds % 60
		return s > 0 and string.format("%dm %ds", m, s) or m .. "m"
	else
		local h, m = math.floor(seconds / 3600), math.floor(seconds % 3600 / 60)
		return m > 0 and string.format("%dh %dm", h, m) or h .. "h"
	end
end

-- 1234.5 -> "$1.23K"
function Format.cash(n: number): string
	return "$" .. Format.short(n)
end

-- income per second -> "$1.2K/s"
function Format.rate(n: number): string
	if n > 0 and n < 10 then
		return (string.format("$%.1f/s", n):gsub("%.0/s", "/s"))
	end
	return "$" .. Format.short(n) .. "/s"
end

return Format
