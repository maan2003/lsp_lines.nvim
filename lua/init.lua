local util = require("trouble.util")

local M = {}

local indentation_regex = vim.regex([[^\s\+]])

-- @param bufnr integer
-- @param lnum integer
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

-- Update diagnostics for a given buffer.
-- @param bufnr integer
local function update_buf(bufnr)
  local ns_id = vim.api.nvim_create_namespace("nl.whynothugo.lsp-virtual-lines")
  vim.api.nvim_buf_clear_namespace(bufnr, ns_id, 0, -1)

  local diagnostics = vim.diagnostic.get(bufnr)
  if vim.tbl_isempty(diagnostics) then
    return
  end

  for i, diagnostic in ipairs(diagnostics) do
    vim.api.nvim_buf_set_extmark(bufnr, ns_id, diagnostic.lnum, 0, {
      id = i,
      virt_lines = {
        {
          {
            get_indentation_for_line(bufnr, diagnostic.lnum),
            "",
          },
          {
            "▼ " .. diagnostic.message,
            util.get_severity_label(util.severity[diagnostic.severity], "VirtualText"),
          },
        },
      },
      virt_lines_above = true,
    })
  end
end

-- Registers a wrapper-handler to render lsp lines.
-- This should usually only be called once, during initialisation.
M.register_lsp_virtual_lines = function()
  -- TODO: When a diagnostic changes for the current line, the cursor is not shifted properly.
  -- TODO: On LSP restart (e.g.: diagnostics cleared), errors don't go away.

  local orig_handler = vim.lsp.handlers["textDocument/publishDiagnostics"]

  -- Wrap the original diagnostics handler to add our own logic.
  vim.lsp.handlers["textDocument/publishDiagnostics"] = function(err, result, ctx, config)
    -- Call regular handler:
    orig_handler(err, result, ctx, config)

    -- TODO: maybe only re-render for current line.
    -- If so, the method that does rendering should be re-used to trigger on CursorHold or CursorHoldI

    local bufnr = vim.uri_to_bufnr(result.uri)
    if not bufnr then
      -- Ths can happen, but I've no idea why:
      return
    end

    if not vim.api.nvim_buf_is_loaded(bufnr) then
      -- Some LSPs will yeild diagnostics for files we've not loaded, so trying
      -- to access their buffers will fail.
      --
      -- XXX: Drawing should be done when they're loaded/attached. It's very
      -- likely the LSP triggers some event when that happens too (didChange?).
      return
    end

    update_buf(bufnr)
  end
end

return M
