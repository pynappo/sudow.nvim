local uv = vim.uv or vim.loop

---@param cmd string[]
---@param on_exit fun(id: integer, code: integer, eventtype: "exit")
---@return integer channel
local function run_sudo_in_floating_terminal(cmd, on_exit)
  -- 1. Create a buffer for the terminal
  local buf = vim.api.nvim_create_buf(false, true)

  local width = math.floor(vim.o.columns * 0.4)
  local height = math.floor(vim.o.lines * 0.2)
  local row = math.floor((vim.o.lines - height) / 1.2)
  local col = math.floor((vim.o.columns - width) / 5)

  local terminal_winid = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    width = width,
    height = height,
    row = row,
    col = col,
    style = "minimal",
  })

  local full_command = { "sudo", unpack(cmd) }

  local jobid = vim.fn.jobstart(full_command, {
    term = true,
    stdin = "pipe",
    on_exit = on_exit,
  })
  vim.api.nvim_create_autocmd("WinClosed", {
    callback = function(args)
      local winid = args.file
      if winid ~= terminal_winid then
        return false
      end
      vim.fn.jobstop(jobid)
    end,
  })

  vim.cmd("startinsert")
  return jobid
end

--- Writes a buffer's content to a temporary file
--- @param content string|string[]
--- @return string? filename The path to the temp file, or nil on error
--- @return string? error
local function write_to_temp(content)
  local temp_path = vim.fn.tempname()

  local open_perm = tonumber("666", 8)
  local fd = uv.fs_open(temp_path, "w", open_perm) -- 438 is octal 0666
  if not fd then
    vim.notify("Could not open temp file for writing", vim.log.levels.ERROR)
    return nil
  end

  local bytes = #content
  local bytes_written = assert(uv.fs_write(fd, content))
  assert(bytes_written == bytes)

  uv.fs_close(fd)

  return temp_path
end

local posix_templates = {
  move_tmp_to_dest_and_cp_attributes = [[
NVIM_SUWRITE_ORIGINAL=%s
NVIM_SUWRITE_TEMP=%s
if [ -f "$NVIM_SUWRITE_ORIGINAL" ]; then
		# File exists: clone attributes then overwrite
		cp -p --attributes-only "$NVIM_SUWRITE_ORIGINAL" "$NVIM_SUWRITE_TEMP" && mv -f "$NVIM_SUWRITE_TEMP" "$NVIM_SUWRITE_ORIGINAL"
else
		# New file: move directly (sudo will own it)
		mv -f "$NVIM_SUWRITE_TEMP" "$NVIM_SUWRITE_ORIGINAL"
fi
]],
}
vim.api.nvim_create_user_command("SuWrite", function(args)
  local buf = vim.api.nvim_get_current_buf()
  if vim.bo[buf].buftype ~= "" then
    return
  end
  local bufname = vim.api.nvim_buf_get_name(buf)
  local filename = #args.nargs > 0 and args.fargs[1] or bufname
  local stat = uv.fs_stat(filename)
  local parent_dir = vim.fs.dirname(filename)
  if stat then
    vim.notify("File is already writable, use :w", vim.log.levels.WARN)
    return
  end

  -- Prepare content and temp file
  local lines = vim.api.nvim_buf_get_lines(buf, args.line1 - 1, args.line2, false)
  local content = table.concat(lines, "\n") .. "\n"
  local temp_filename = assert(write_to_temp(content))

  vim.notify("Executing sudo write...", vim.log.levels.INFO)

  run_sudo_in_floating_terminal({
    "sh",
    "-c",
    posix_templates.move_tmp_to_dest_and_cp_attributes:format(
      vim.fn.shellescape(filename),
      vim.fn.shellescape(temp_filename)
    ),
  }, function(id, code, event)
    if code ~= 0 then
      vim.schedule(function()
        vim.notify("Sudo write failed with code " .. code, vim.log.levels.ERROR)
        local edit_temp = "Edit temp file w/ contents"
        local abort_temp = "Abort write attempt and remove temp file"
        vim.ui.select({ edit_temp, abort_temp }, {
          prompt = "Sudo write failed (code" .. code .. "), choose option:",
        }, function(choice)
          if not choice then
            vim.notify(
              "No choice made, will do nothing. Temp file w/ contents is at " .. temp_filename
            )
            return
          end
          if choice == edit_temp then
            vim.cmd.edit(temp_filename)
          elseif choice == abort_temp then
            os.remove(temp_filename)
          else
            error("Not implemented")
          end
        end)
      end)
      return
    end

    vim.schedule(function()
      vim.notify("File successfully written!", vim.log.levels.INFO)
      -- Clean up the temp file
      os.remove(temp_filename)
      vim.cmd("checktime " .. buf)
      vim.bo[buf].modified = false
    end)
  end)
end, { range = "%", complete = "file", nargs = "?" })
