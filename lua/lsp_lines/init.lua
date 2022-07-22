local M = {}

local highlight_groups = {
  [vim.diagnostic.severity.ERROR] = "DiagnosticVirtualTextError",
  [vim.diagnostic.severity.WARN] = "DiagnosticVirtualTextWarn",
  [vim.diagnostic.severity.INFO] = "DiagnosticVirtualTextInfo",
  [vim.diagnostic.severity.HINT] = "DiagnosticVirtualTextHint",
}

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

      table.sort(diagnostics, function(a, b)
        if a.lnum ~= b.lnum then
          return a.lnum < b.lnum
        else
          return a.col < b.col
        end
      end)

      local ns = vim.diagnostic.get_namespace(namespace)
      if not ns.user_data.virt_lines_ns then
        ns.user_data.virt_lines_ns = vim.api.nvim_create_namespace("")
      end
      local virt_lines_ns = ns.user_data.virt_lines_ns

      vim.api.nvim_buf_clear_namespace(bufnr, virt_lines_ns, 0, -1)

      local last_line = -1
      local last_prefix = {}
      local last_col = 0
      local virt_lines = {}
      for id, diagnostic in ipairs(diagnostics) do
        if diagnostic.lnum ~= last_line then
          if last_line ~= -1 then
            vim.api.nvim_buf_set_extmark(bufnr, virt_lines_ns, last_line, 0, {
              id = id,
              virt_lines = virt_lines,
              virt_lines_above = false,
            })
          end
          last_line = diagnostic.lnum
          last_col = -1
          last_prefix = {}
          virt_lines = {}
        end
        if not diagnostic.message:find("^%s*$") then
          local space = string.rep(" ", diagnostic.col - last_col - 1)
          -- Some diagnostics have multiple lines. Split those into multiple
          -- virtual lines, but only show the prefix for the first one.
          local current_prefix = { "└──── ", highlight_groups[diagnostic.severity] }
          if diagnostic.col == last_col then
            current_prefix = { "──── ", highlight_groups[diagnostic.severity] }
          end
          local current_lines = {}
          for diag_line in diagnostic.message:gmatch("([^\n]+)") do
            if not diagnostic.message:find("^%s*$") then
              local ln = {} -- Virtual lines for this diagnostic.
              for _, val in ipairs(last_prefix) do
                table.insert(ln, val)
              end
              -- Spaces are inserted separately to avoid applying the
              -- background colour of diagnostic highlight group.
              table.insert(ln, { space, "" })
              table.insert(ln, current_prefix)
              table.insert(ln, { diag_line, highlight_groups[diagnostic.severity] })
              table.insert(current_lines, 1, ln)
              current_prefix = { "      ", "" }
            end
          end
          for _, val in ipairs(current_lines) do
            table.insert(virt_lines, 1, val)
          end
          if diagnostic.col ~= last_col then
            table.insert(last_prefix, { space, "" })
            table.insert(last_prefix, { "│", highlight_groups[diagnostic.severity] })
          end
          last_col = diagnostic.col
        end
      end
      if last_line ~= -1 then
        vim.api.nvim_buf_set_extmark(bufnr, virt_lines_ns, last_line, 0, {
          id = id,
          virt_lines = virt_lines,
          virt_lines_above = false,
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
