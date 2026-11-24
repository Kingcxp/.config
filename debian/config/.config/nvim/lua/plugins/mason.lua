-- Prefer APT/Homebrew tools; retain Mason for explicit, on-demand installs.
---@type LazySpec
return {
  { "williamboman/mason.nvim", enabled = true, opts = { PATH = "append" } },
  {
    "williamboman/mason-lspconfig.nvim",
    enabled = true,
    opts = function(_, opts)
      opts.ensure_installed = {}
      opts.automatic_installation = false
    end,
  },
  { "WhoIsSethDaniel/mason-tool-installer.nvim", enabled = false },
  { "jay-babu/mason-null-ls.nvim", enabled = false },
  { "jay-babu/mason-nvim-dap.nvim", enabled = false },
}
