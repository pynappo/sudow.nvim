local Health = {}

---@generic S : string
---@param expr S
---@return S? expr
local executable = function(expr)
  return vim.fn.executable(expr) == 1 and expr or nil
end

local has_nvim_08 = vim.fn.has("nvim-0.8") == 1

Health.check = function()
  vim.health.start("sudow.nvim")

  if has_nvim_08 then
    vim.health.ok("Neovim version is 0.8 or higher")
  else
    vim.health.error("Neovim version below 0.8")
  end

  if executable("sh") then
    vim.health.ok("`sh` available")
  else
    vim.health.ok("`sh` unavailable")
  end
end

return Health
