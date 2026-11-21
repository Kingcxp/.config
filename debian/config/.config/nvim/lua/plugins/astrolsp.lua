-- APT/Homebrew provide these servers; the original template left this file disabled.
---@type LazySpec
return {
  "AstroNvim/astrolsp",
  opts = {
    servers = {
      "lua_ls", "bashls", "yamlls", "jsonls", "html", "cssls",
      "gopls", "rust_analyzer", "clangd", "ts_ls", "pyright", "ruff", "texlab", "tinymist",
    },
    config = {
      lua_ls = {
        settings = {
          Lua = { diagnostics = { globals = { "vim" } }, workspace = { checkThirdParty = false } },
        },
      },
    },
  },
}
