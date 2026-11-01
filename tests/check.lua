-- Run with nvim --headless -u NONE -i NONE -l tests/check.lua /path/to/snacks.nvim
local root = vim.fn.fnamemodify(arg[0], ":p:h:h")
vim.opt.rtp:prepend(root)
vim.opt.rtp:prepend(assert(arg[1], "Pass the snacks.nvim directory"))
vim.o.columns, vim.o.lines = 112, 34
require("snacks").setup({ dashboard = { enabled = false } })
local api = vim.api
local file = assert(io.open(root .. "/animations/n.mpack", "rb"))
local clip = vim.mpack.decode(file:read("*a"))
file:close()
local ns = api.nvim_create_namespace("Fadein")
local function marks(dashboard)
	return api.nvim_buf_get_extmarks(dashboard.buf, ns, 0, -1, { details = true })
end
local function final_frame(dashboard)
	local frame = marks(dashboard)
	if #frame ~= clip.height then
		return false
	end
	for row, mark in ipairs(frame) do
		if not vim.deep_equal(mark[4].virt_text, clip.frames[#clip.frames][row]) then
			return false
		end
	end
	return true
end
local section = require("fadein").section({ animation = "n" })
local sections = { section, { section = "keys", gap = 1, padding = 1 } }
local keys = {
	{ key = "n", desc = "New File", action = ":ene | startinsert" },
	{ key = "q", desc = "Quit", action = ":qa" },
}
local opts = { sections = sections, preset = { keys = keys } }

-- Startup waits for lazy.nvim, then keeps playing across dashboard updates.
package.loaded["lazy"] = {}
vim.g.did_very_lazy = nil
local dashboard = Snacks.dashboard(opts)
vim.wait(30)
assert(#marks(dashboard) == 0, "Playback started before VeryLazy")
vim.g.did_very_lazy = true
api.nvim_exec_autocmds("User", { pattern = "VeryLazy" })
package.loaded["lazy"] = nil
assert(
	vim.wait(500, function()
		return #marks(dashboard) == clip.height
	end, 5),
	"Missing first frame"
)
local first = marks(dashboard)
assert(
	vim.wait(500, function()
		return not vim.deep_equal(first, marks(dashboard))
	end, 5),
	"Animation is static"
)
dashboard:update()
assert(
	vim.wait(100, function()
		return #marks(dashboard) == clip.height
	end, 5),
	"Dashboard update lost the animation"
)
assert(
	vim.wait(math.ceil(clip.seconds * 1000) + 1000, function()
		return final_frame(dashboard)
	end, 5),
	"Playback did not finish on the final frame"
)
local completed = marks(dashboard)
dashboard:update()
assert(
	vim.wait(100, function()
		return vim.deep_equal(completed, marks(dashboard))
	end, 5),
	"Dashboard update replayed a completed intro"
)
assert(dashboard.opts.width == 60 and dashboard.opts.pane_gap == 4, "Animation changed the layout")
assert(vim.deep_equal(dashboard.opts.preset.keys, keys), "Animation changed the menu")

-- The final frame follows colorscheme changes without painting a background.
api.nvim_set_hl(0, "Normal", { fg = 0x123456, bg = 0x010203 })
api.nvim_set_hl(0, "SnacksDashboardNormal", { link = "Normal" })
api.nvim_exec_autocmds("ColorScheme", {})
assert(api.nvim_get_hl(0, { name = "FadeinTone32" }).fg == 0x123456, "Palette did not follow the theme")
assert(not api.nvim_get_hl(0, { name = "FadeinTone32" }).bg, "Artwork painted a background")
api.nvim_buf_delete(dashboard.buf, { force = true })

-- Returning after playback has elapsed restores the finished intro.
dashboard = Snacks.dashboard({
	sections = { require("fadein").section(), { section = "keys", gap = 1, padding = 1 } },
	preset = { keys = keys },
})
assert(vim.wait(100, function()
	return #marks(dashboard) == clip.height
end, 5))
local other = api.nvim_create_buf(true, false)
vim.bo[dashboard.buf].bufhidden = "hide"
api.nvim_win_set_buf(dashboard.win, other)
vim.wait(math.ceil(clip.seconds * 1000) + 50)
api.nvim_win_set_buf(dashboard.win, dashboard.buf)
assert(
	vim.wait(100, function()
		return final_frame(dashboard)
	end, 5),
	"Returning replayed a completed intro"
)
api.nvim_buf_delete(dashboard.buf, { force = true })

-- Closing during playback cleans up lifecycle callbacks.
dashboard = Snacks.dashboard(opts)
assert(vim.wait(100, function()
	return #marks(dashboard) == clip.height
end, 5))
api.nvim_buf_delete(dashboard.buf, { force = true })
assert(#api.nvim_get_autocmds({ event = "User", pattern = "SnacksDashboardClosed" }) == 0, "Cleanup callback leaked")

-- A narrow pane omits the artwork and leaves the user's sections intact.
dashboard = Snacks.dashboard({ width = 20, sections = sections, preset = { keys = keys } })
vim.wait(30)
assert(#marks(dashboard) == 0, "Artwork overflowed a narrow pane")
assert(dashboard.opts.width == 20 and #dashboard.items > 0, "Narrow pane lost its menu")
api.nvim_buf_delete(dashboard.buf, { force = true })
print("PASS: startup, playback, updates, layout, theme, leave/return, cleanup and narrow panes")
vim.cmd.qa()
