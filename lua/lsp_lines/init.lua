local M = {}

local highlight_groups = {
  [vim.diagnostic.severity.ERROR] = "DiagnosticVirtualTextError",
  [vim.diagnostic.severity.WARN] = "DiagnosticVirtualTextWarn",
  [vim.diagnostic.severity.INFO] = "DiagnosticVirtualTextInfo",
  [vim.diagnostic.severity.HINT] = "DiagnosticVirtualTextHint",
}

local SPACE = 0
local DIAGNOSTIC = 1
local OVERLAP = 2

-- Deprecated. Use `setup()` instead.
M.register_lsp_virtual_lines = function()
  print("lsp_lines.register_lsp_virtual_lines() is deprecated. use lsp_lines.setup() instead.")
  M.setup()
end

-- Registers a wrapper-handler to render lsp lines.
-- This should usually only be called once, during initialisation.
M.setup = function()
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

      local line_stacks = {}
      local prev_lnum = -1
      local prev_col = -1
      for id, diagnostic in ipairs(diagnostics) do
        diagnostic.id = id -- Tie the id to the actual object.

        if line_stacks[diagnostic.lnum] == nil then
          line_stacks[diagnostic.lnum] = {}
        end

        local stack = line_stacks[diagnostic.lnum]

        if diagnostic.lnum ~= prev_lnum then
          table.insert(stack, { SPACE, string.rep(" ", diagnostic.col) })
          table.insert(stack, { DIAGNOSTIC, diagnostic })
        elseif diagnostic.col ~= prev_col then
          table.insert(stack, { SPACE, string.rep(" ", diagnostic.col - prev_col - 1) })
          table.insert(stack, { DIAGNOSTIC, diagnostic })
        else
          table.insert(stack, { OVERLAP, diagnostic.severity })
          table.insert(stack, { DIAGNOSTIC, diagnostic })
        end

        prev_lnum = diagnostic.lnum
        prev_col = diagnostic.col
      end

      for lnum, lelements in pairs(line_stacks) do
        local virt_lines = {}
        for i = #lelements, 1, -1 do -- last element goes on top
          if lelements[i][1] == DIAGNOSTIC then
            local diagnostic = lelements[i][2]

            local left = {}
            local overlap = false

            -- Iterate the stack for this line to find elements on the left.
            for j = 1, i - 1 do
              local type = lelements[j][1]
              local data = lelements[j][2]
              if type == SPACE then
                table.insert(left, { data, "" })
              elseif type == DIAGNOSTIC then
                -- If an overlap follows this, don't add an extra column.
                if lelements[j + 1][1] ~= OVERLAP then
                  table.insert(left, { "│", highlight_groups[data.severity] })
                end
                overlap = false
              elseif type == OVERLAP then
                overlap = true
              end
            end

            local center
            if overlap then
              center = { { "├──── ", highlight_groups[diagnostic.severity] } }
            else
              center = { { "└──── ", highlight_groups[diagnostic.severity] } }
            end

            for msg_line in diagnostic.message:gmatch("([^\n]+)") do
              local vline = {}
              vim.list_extend(vline, left)
              vim.list_extend(vline, center)
              vim.list_extend(vline, { { msg_line, highlight_groups[diagnostic.severity] } })

              table.insert(virt_lines, vline)

              -- Special-case for continuation lines:
              if overlap then
                center = { { "│", highlight_groups[diagnostic.severity] }, { "     ", "" } }
              else
                center = { { "      ", "" } }
              end
            end
          end
        end

        vim.api.nvim_buf_set_extmark(bufnr, virt_lines_ns, lnum, 0, {
          id = lnum,
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
