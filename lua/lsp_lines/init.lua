local M = {}

local render = require("lsp_lines.render")

-- Registers a wrapper-handler to render lsp lines.
-- This should usually only be called once, during initialisation.
M.setup = function()
  -- TODO: On LSP restart (e.g.: diagnostics cleared), errors don't go away.
  vim.diagnostic.handlers.virtual_lines = {
    ---@param namespace number
    ---@param bufnr number
    ---@param diagnostics table
    ---@param opts boolean
    show = function(namespace, bufnr, diagnostics, opts)
      local ns = vim.diagnostic.get_namespace(namespace)
      if not ns.user_data.virt_lines_ns then
        ns.user_data.virt_lines_ns = vim.api.nvim_create_namespace("")
      end
      render.show(ns.user_data.virt_lines_ns, bufnr, diagnostics, opts)
    end,
    ---@param namespace number
    ---@param bufnr number
    hide = function(namespace, bufnr)
      local ns = vim.diagnostic.get_namespace(namespace)
      if ns.user_data.virt_lines_ns then
        render.hide(ns.user_data.virt_lines_ns, bufnr )
      end
    end,
  }
end

---@return boolean
M.toggle = function()
  local new_value = not vim.diagnostic.config().virtual_lines
  vim.diagnostic.config({ virtual_lines = new_value })
  return new_value
end

return M
