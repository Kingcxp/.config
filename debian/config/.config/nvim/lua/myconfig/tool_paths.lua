-- GUI launches can inherit an older session PATH than a newly opened Fish shell.
local M = {}

function M.setup()
  if vim.fn.has "unix" ~= 1 then return end
  local home = vim.env.HOME or vim.fn.expand "~"
  local state = vim.env.XDG_STATE_HOME or (home .. "/.local/state")
  local prefix = vim.env.HOMEBREW_PREFIX or "/home/linuxbrew/.linuxbrew"
  local file = io.open(state .. "/myconfig-debian/brew-prefix", "r")
  if file then
    local recorded = file:read "*l"
    file:close()
    if recorded and recorded:match "^/" and not recorded:find "%s" then prefix = recorded end
  end
  if not prefix:match "^/" or prefix:find "%s" then prefix = "/home/linuxbrew/.linuxbrew" end
  local paths, seen = {}, {}
  local function add(path)
    if not seen[path] then
      seen[path] = true
      paths[#paths + 1] = path
    end
  end
  for _, path in ipairs { prefix .. "/opt/node@22/bin", prefix .. "/bin", prefix .. "/sbin", home .. "/.local/bin" } do
    if vim.fn.isdirectory(path) == 1 then add(path) end
  end
  for path in ((vim.env.PATH or "") .. ":"):gmatch "(.-):" do
    add(path)
  end
  vim.env.PATH = table.concat(paths, ":")
end

return M
