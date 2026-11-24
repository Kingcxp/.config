-- Run in an isolated copy of the profile, with a JSON file and the real server.
local ok, error_message = pcall(function()
  require("lazy").load { plugins = { "nvim-lspconfig", "mason.nvim", "mason-lspconfig.nvim" } }
  for _, command_name in ipairs { "Mason", "MasonInstall", "LspInstall", "LspUninstall" } do
    assert(vim.fn.exists(":" .. command_name) > 0, command_name .. " must be available")
  end
  assert(require("mason.settings").current.PATH == "append", "Mason must prefer existing system tools")
  local mason_lsp = require("mason-lspconfig.settings").current
  assert(#mason_lsp.ensure_installed == 0, "Do not automatically reinstall system language servers")
  assert(mason_lsp.automatic_installation == false, "On-demand installation must remain manual")
  local packages = require("mason.settings").current.install_root_dir .. "/packages"
  assert(#vim.fn.globpath(packages, "*", false, true) == 0, "Startup must not download a duplicate toolchain")
  assert(vim.fn.executable "vscode-json-language-server" == 1, "JSON server must be in Neovim's PATH")
  assert(vim.wait(20000, function() return #vim.lsp.get_clients { bufnr = 0, name = "jsonls" } == 1 end, 100))
  local client = vim.lsp.get_clients { bufnr = 0, name = "jsonls" }[1]
  assert(
    vim.fn.fnamemodify(client.config.cmd[1], ":t") == "vscode-json-language-server",
    "Use the extracted server's actual executable"
  )
  local response = client:request_sync(
    "textDocument/documentSymbol",
    { textDocument = vim.lsp.util.make_text_document_params(0) },
    5000,
    0
  )
  assert(response and not response.err and response.result, "The real JSON language server must answer LSP requests")
  print "PASS: AstroNvim registers Mason/LspInstall, keeps installation manual, and connects to the real JSON server"
end)
if not ok then
  vim.api.nvim_err_writeln(tostring(error_message))
  vim.cmd "cquit 1"
else
  vim.cmd "qa!"
end
