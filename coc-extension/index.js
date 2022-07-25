const { diagnosticManager, workspace, Disposable } = require('coc.nvim')

exports.activate = async context => {
  const { nvim } = workspace
  const NS = await nvim.createNamespace('coc-lsp-lines')
  const { subscriptions } = context
  subscriptions.push(
    diagnosticManager.onDidRefresh(e => {
      nvim.call('luaeval', [
        "require'lsp_lines.render'.show(_A[1], _A[2], _A[3], _A[4], _A[5])",
        [
          NS,
          e.bufnr,
          e.diagnostics.map(d => {
            const { start } = d.range
            d.lnum = start.line
            d.col = start.character
            return d
          }),
          {},
          'coc',
        ],
      ])
    }),
    Disposable.create(() => {
      nvim.lua(`
        for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
          vim.api.nvim_buf_clear_namespace(bufnr, ${NS}, 0, -1)
        end
        `)
    })
  )
}
