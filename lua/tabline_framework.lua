local print_warn = require'tabline_framework.helpers'.print_warn
local hi = require'tabline_framework.highlights'
local functions = require'tabline_framework.functions'
local Config = require'tabline_framework.config'
local Tabline = require'tabline_framework.tabline'

local function make_tabline()
  local opts = Config:get_viewport_opts()

  if opts.hide_single_tab then
    local tabs = vim.api.nvim_list_tabpages()
    if #tabs <= 1 then
      return ''
    end
  end

  return Tabline.run(Config.render)
end

local function setup_events()
  local group = vim.api.nvim_create_augroup('TablineFramework', { clear = true })

  vim.api.nvim_create_autocmd({ 'VimResized' }, {
    group = group,
    callback = function()
      Config:reset_viewport_cache()
    end
  })
end

local function setup(opts)
  opts = opts or {}

  if not opts.render then
    print_warn 'TablineFramework: Render function not defined'
    return
  end

  hi.clear()
  functions.clear()

  Config:new {
    hl = hi.tabline(),
    hl_sel = hi.tabline_sel(),
    hl_fill = hi.tabline_fill()
  }

  Config:merge(opts)

  setup_events()

  vim.opt.tabline = [[%!v:lua.require'tabline_framework'.make_tabline()]]
end

return {
  make_tabline = make_tabline,
  setup = setup
}
