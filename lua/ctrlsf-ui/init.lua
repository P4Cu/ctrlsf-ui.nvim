-- TODO: g:ctrlsf_mapping to show mappings

local Popup = require("nui.popup")
local event = require("nui.utils.autocmd").event

local M = {}

local original_lines = {
	"-- multiple glob can be provided like '{plugins,lsp}/*'",
	"-- <C-c> to cancel, close window to confirm",
	"return {",
	"  pattern = [[]],",
	"  filetype = '',      -- eg. lua, cpp, js",
	"  filematch = '',     -- GLOB pattern that only files whose name is matching will be searched",
	"  includedir = {'',}, -- list of GLOB pattern of directories to be searched",
	"  ignoredir = '',     -- GLOB pattern of directories to be ignored",
	"  hidden = false,",
	"  case = 'smart',     -- ignore, match, regex, literal, word",
	"  before = 0,",
	"  after = 0,",
	"}",
}

local lines = vim.deepcopy(original_lines)

local function produce_command(opts)
	local command = { "CtrlSF" }

	if opts.case == "smart" then
		table.insert(command, "-smartcase")
	elseif opts.case == "ignore" then
		table.insert(command, "-ignorecase")
	elseif opts.case == "match" then
		table.insert(command, "-matchcase")
	elseif opts.case == "regex" then
		table.insert(command, "-regex")
	elseif opts.case == "literal" then
		table.insert(command, "-literal")
	elseif opts.case == "word" then
		table.insert(command, "-word")
	else
		table.insert(command, "-smartcase")
	end

	if opts.after then
		table.insert(command, "-after")
		table.insert(command, opts.after)
	end

	if opts.before then
		table.insert(command, "-before")
		table.insert(command, opts.before)
	end

	if opts.filetype and opts.filetype ~= "" then
		table.insert(command, "-filetype")
		table.insert(command, "'" .. opts.filetype .. "'")
	end

	if opts.hidden then
		table.insert(command, "-hidden")
	end

	if opts.filematch and opts.filematch ~= "" then
		table.insert(command, "-filematch")
		table.insert(command, "'" .. opts.filematch .. "'")
	end

	if opts.ignoredir and opts.ignoredir ~= "" then
		table.insert(command, "-ignoredir")
		table.insert(command, "'" .. opts.ignoredir .. "'")
	end

	table.insert(command, "--")
	if opts.pattern and opts.pattern ~= "" then
		table.insert(command, "'" .. opts.pattern .. "'")
	else
		table.insert(command, "''")
		if opts.includedir then
			vim.notify("CtrlSF: specifying dirs without pattern won't work.", vim.log.levels.WARN)
		end
	end

	-- and finally after pattern we can specify a list of directories to include
	if opts.includedir then
		for _, e in ipairs(opts.includedir) do
			table.insert(command, "'" .. e .. "'")
		end
	end

	return table.concat(command, " ")
end

local function widget_execute_ctrlsf(popup)
	-- get popup text and remember it for next time use
	lines = vim.api.nvim_buf_get_lines(popup.bufnr, 0, -1, false)
	-- process it by running as lua code
	local callable = load(table.concat(lines, "\n"))
	assert(callable, "Invalid input.")
	local result = callable()
	-- turn it inco CtrlSF command
	local command = produce_command(result)
	-- notify and call it
	vim.notify(command)
	vim.api.nvim_command(command)
end

function M.show()
	local popup = Popup({
		enter = true,
		focusable = true,
		border = {
			style = "rounded",
		},
		position = "50%",
		relative = "editor",
		size = {
			width = "80%",
			height = #lines,
		},
		text = {
			top = "CtrlSF",
		},
	})
	-- mount/open the component
	popup:mount()

	-- unmount and execute CtrlSF when cursor leaves buffer
	popup:on(event.BufLeave, function()
		local success, result = pcall(widget_execute_ctrlsf, popup)
		if not success then
			-- reset to initial text if it failed to process
			lines = vim.deepcopy(original_lines)
			vim.notify("CtrlSF: " .. result, vim.log.levels.ERROR)
		end
		popup:unmount()
	end)

	-- set cancel key
	popup:map("n", "<C-c>", function()
		popup:off(event.BufLeave)
		popup:on(event.BufLeave, function()
			vim.notify("CtrlSF: canceled", vim.log.levels.INFO)
			popup:unmount()
		end)
		vim.api.nvim_win_close(popup.winid, true)
	end, {})

	-- set content
	vim.bo[popup.bufnr].filetype = "lua"
	vim.api.nvim_buf_set_lines(popup.bufnr, 0, 1, false, lines)
end

return M
