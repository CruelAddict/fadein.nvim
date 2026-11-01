local M = {}
local api, uv = vim.api, vim.uv
local ns = api.nvim_create_namespace("Fadein")
local root = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h:h")
local clips = {}
local initialized = false

local function colors()
	local normal = api.nvim_get_hl(0, { name = "Normal", link = false })
	local dashboard = api.nvim_get_hl(0, { name = "SnacksDashboardNormal", link = false })
	local dark = vim.o.background == "dark"
	local fg = dashboard.fg or normal.fg or (dark and 0xdddddd or 0x222222)
	local bg = dashboard.bg or normal.bg or (dark and 0x111111 or 0xffffff)
	local accent = api.nvim_get_hl(0, { name = "String", link = false }).fg or fg
	local function mix(target, amount)
		local result = 0
		for _, shift in ipairs({ 65536, 256, 1 }) do
			local a, b = math.floor(bg / shift) % 256, math.floor(target / shift) % 256
			result = result + math.floor(a + (b - a) * amount + 0.5) * shift
		end
		return result
	end
	for level = 1, 32 do
		api.nvim_set_hl(0, "FadeinTone" .. level, { fg = mix(fg, (level - 1) / 31), bg = "NONE" })
		api.nvim_set_hl(0, "FadeinToneLogo" .. level, { fg = mix(accent, (level - 1) / 31), bg = "NONE" })
	end
end

local function load(name)
	if clips[name] then
		return clips[name]
	end
	local file = assert(io.open(root .. "/animations/" .. name .. ".mpack", "rb"))
	local clip = vim.mpack.decode(file:read("*a"))
	file:close()
	assert(clip.version == 1 and #clip.frames > 0, "Invalid fadein animation")
	clips[name] = clip
	if not initialized then
		initialized = true
		colors()
		api.nvim_create_autocmd("ColorScheme", {
			group = api.nvim_create_augroup("FadeinColors", { clear = true }),
			callback = colors,
		})
	end
	return clip
end

local function play(dashboard, pos, clip, name, speed)
	local timer, closed, previous
	local group = api.nvim_create_augroup("FadeinPlayback" .. dashboard.buf, { clear = true })
	local column = pos[2] + 1 + math.floor((dashboard.opts.width - clip.width) / 2)
	local function halt()
		if timer then
			timer:stop()
			timer:close()
			timer = nil
		end
	end
	local function visible()
		return not closed
			and api.nvim_win_is_valid(dashboard.win)
			and api.nvim_win_get_buf(dashboard.win) == dashboard.buf
			and api.nvim_win_get_tabpage(dashboard.win) == api.nvim_get_current_tabpage()
	end
	local function paint()
		if not visible() then
			halt()
			return
		end
		dashboard._fadein_started = dashboard._fadein_started or {}
		dashboard._fadein_started[name] = dashboard._fadein_started[name] or uv.hrtime()
		local elapsed = (uv.hrtime() - dashboard._fadein_started[name]) / 1e9 * speed
		local index = elapsed >= clip.seconds and #clip.frames or math.floor(elapsed * clip.fps) + 1
		if index ~= previous then
			for row, chunks in ipairs(clip.frames[index]) do
				api.nvim_buf_set_extmark(dashboard.buf, ns, pos[1] + row - 2, 0, {
					id = row,
					virt_text = chunks,
					virt_text_win_col = column,
					priority = 200,
				})
			end
			previous = index
			-- Command-line mode does not automatically redraw changed extmarks.
			if api.nvim_get_mode().mode:sub(1, 1) == "c" then
				api.nvim__redraw({ win = dashboard.win, valid = true, flush = true })
			end
		end
		if index == #clip.frames then
			halt()
		end
	end
	local function refresh()
		if package.loaded["lazy"] and not vim.g.did_very_lazy then
			return
		end
		if not visible() then
			halt()
			return
		end
		paint()
		if previous == #clip.frames then
			return
		end
		timer = timer or assert(uv.new_timer())
		local elapsed = (uv.hrtime() - dashboard._fadein_started[name]) / 1e9
		-- Schedule frame deadlines without rounding a repeating timer's interval.
		local deadline = math.min(clip.seconds, previous / clip.fps) / speed
		local delay = math.max(1, math.ceil((deadline - elapsed) * 1000))
		timer:start(delay, 0, vim.schedule_wrap(refresh))
	end
	local function close()
		if closed then
			return true
		end
		closed = true
		halt()
		api.nvim_del_augroup_by_id(group)
		if api.nvim_buf_is_valid(dashboard.buf) then
			api.nvim_buf_clear_namespace(dashboard.buf, ns, 0, -1)
		end
		return true
	end
	dashboard.on("UpdatePre", close, group)
	dashboard.on("Closed", close, group)
	api.nvim_create_autocmd("BufLeave", { group = group, buffer = dashboard.buf, callback = halt })
	api.nvim_create_autocmd("TabLeave", { group = group, callback = halt })
	api.nvim_create_autocmd({ "BufEnter", "TabEnter" }, {
		group = group,
		callback = function()
			vim.schedule(refresh)
		end,
	})
	api.nvim_create_autocmd("VimLeavePre", { group = group, callback = halt })
	if package.loaded["lazy"] and not vim.g.did_very_lazy then
		api.nvim_create_autocmd("User", {
			group = group,
			pattern = "VeryLazy",
			once = true,
			callback = function()
				vim.schedule(refresh)
			end,
		})
	end
	-- Snacks writes placeholder lines after calling this render callback.
	vim.schedule(refresh)
end

function M.section(opts)
	opts = opts or {}
	local name, speed = opts.animation or "n", opts.speed or 1
	assert(type(name) == "string" and name:match("^[%w_-]+$"), "Invalid fadein animation name")
	assert(type(speed) == "number" and speed > 0 and speed < math.huge, "Invalid fadein speed")
	return function(dashboard)
		local clip = load(name)
		local size = dashboard:size()
		if dashboard.opts.width < clip.width or size.width < clip.width or size.height < clip.height then
			return {}
		end
		api.nvim_win_call(dashboard.win, function()
			vim.fn.winrestview({ topline = 1, leftcol = 0 })
		end)
		return {
			text = ("\n"):rep(clip.height - 1),
			padding = 1,
			render = function(self, pos)
				play(self, pos, clip, name, speed)
			end,
		}
	end
end

return M
