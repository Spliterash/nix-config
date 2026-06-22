-- https://github.com/barbanevosa/linemode-plus.yazi

local SIZE_WIDTH = 7
local DATE_WIDTH = 16 -- "22.06.2026 14:37"

local function format_date(ts)
	local time = math.floor(ts or 0)
	if time == 0 then
		return ""
	end

	return os.date("%d.%m.%Y %H:%M", time)
end

function Linemode:btime()
	return format_date(self._file.cha.btime)
end

function Linemode:mtime()
	return format_date(self._file.cha.mtime)
end

function Linemode:size_mtime()
	local format_str = "%" .. SIZE_WIDTH .. "s  %" .. DATE_WIDTH .. "s"
	return string.format(format_str, self:size(), self:mtime())
end

function ya.readable_size(size)
	local units = { "B", "K", "M", "G", "T", "P", "E", "Z", "Y", "R", "Q" }
	local i = 1

	while size > 1024 and i < #units do
		size = size / 1024
		i = i + 1
	end

	return string.format("%.1f%s", size, " " .. units[i]):gsub("[.,]0", "", 1)
end