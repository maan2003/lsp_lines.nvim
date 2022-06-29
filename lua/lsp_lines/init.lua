local M = {}

local indentation_regex = vim.regex([[^\s\+]])

local highlight_groups = {
  [vim.diagnostic.severity.ERROR] = "DiagnosticVirtualTextError",
  [vim.diagnostic.severity.WARN] = "DiagnosticVirtualTextWarn",
  [vim.diagnostic.severity.INFO] = "DiagnosticVirtualTextInfo",
  [vim.diagnostic.severity.HINT] = "DiagnosticVirtualTextHint",
}

---@param bufnr integer
---@param lnum integer
---@return string
local function get_indentation_for_line(bufnr, lnum)
  local lines = vim.api.nvim_buf_get_lines(bufnr, lnum, lnum + 1, false)

  -- The line does not exist when a buffer is empty, though there may be
  -- additional situations. Fall back gracefully whenever this happens.
  if not vim.tbl_isempty(lines) then
    local istart, iend = indentation_regex:match_str(lines[1])

    if istart ~= nil then
      -- XXX: The docs say `tabstop` should be respected, but this doesn't seem
      -- to be happening (check this on go files).
      return string.sub(lines[1], istart, iend)
    end
  end

  return ""
end

-- Registers a wrapper-handler to render lsp lines.
-- This should usually only be called once, during initialisation.
M.register_lsp_virtual_lines = function()
  -- TODO: When a diagnostic changes for the current line, the cursor is not shifted properly.
  -- TODO: On LSP restart (e.g.: diagnostics cleared), errors don't go away.

  vim.diagnostic.handlers.virtual_lines = {
    ---@param namespace number
    ---@param bufnr number
    ---@param diagnostics table
    ---@param opts boolean
    show = function(namespace, bufnr, diagnostics, opts)
      vim.validate({
        namespace = { namespace, "n" },
        bufnr = { bufnr, "n" },
        diagnostics = {
          diagnostics,
          vim.tbl_islist,
          "a list of diagnostics",
        },
        opts = { opts, "t", true },
      })

      local ns = vim.diagnostic.get_namespace(namespace)
      if not ns.user_data.virt_lines_ns then
        ns.user_data.virt_lines_ns = vim.api.nvim_create_namespace("")
      end
      local virt_lines_ns = ns.user_data.virt_lines_ns

      vim.api.nvim_buf_clear_namespace(bufnr, virt_lines_ns, 0, -1)

      local prefix = opts.virtual_lines.prefix or "▼"

      for id, diagnostic in ipairs(diagnostics) do
        local virt_lines = {}
        local lprefix = prefix
        local indentation = get_indentation_for_line(bufnr, diagnostic.lnum)

        -- Some diagnostics have multiple lines. Split those into multiple
        -- virtual lines, but only show the prefix for the first one.
        for diag_line in diagnostic.message:gmatch("([^\n]+)") do
          table.insert(virt_lines, {
            {
              indentation,
              "",
            },
            {
              string.format("%s %s", lprefix, diag_line),
              highlight_groups[diagnostic.severity],
            },
          })
          lprefix = " "
        end

        vim.api.nvim_buf_set_extmark(bufnr, virt_lines_ns, diagnostic.lnum, 0, {
          id = id,
          virt_lines = virt_lines,
          virt_lines_above = true,
        })
      end
    end,
    ---@param namespace number
    ---@param bufnr number
    hide = function(namespace, bufnr)
      local ns = vim.diagnostic.get_namespace(namespace)
      if ns.user_data.virt_lines_ns then
        vim.api.nvim_buf_clear_namespace(bufnr, ns.user_data.virt_lines_ns, 0, -1)
      end
    end,
  }
end

return M
