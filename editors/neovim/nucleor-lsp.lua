-- Neovim LSP config for Nucleor (.nr files).
--
-- Drop into your Neovim config (or import via :luafile) and the
-- Nucleor LSP will activate on .nr file open. Requires
-- nucleor-lsp.exe on PATH (or set the cmd path absolute below).

local lspconfig = require('lspconfig')
local configs = require('lspconfig.configs')

if not configs.nucleor then
  configs.nucleor = {
    default_config = {
      cmd = { 'nucleor-lsp.exe' },
      filetypes = { 'nucleor' },
      root_dir = function(fname)
        return vim.fs.dirname(vim.fs.find('Nucleor.toml', { upward = true, path = fname })[1])
          or vim.fn.getcwd()
      end,
      settings = {},
    },
  }
end

vim.filetype.add({ extension = { nr = 'nucleor' } })

lspconfig.nucleor.setup({})
