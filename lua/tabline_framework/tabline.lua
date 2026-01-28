local helpers = require'tabline_framework.helpers'
local print_warn = helpers.print_warn
local Config = require'tabline_framework.config'
local hi = require'tabline_framework.highlights'
local functions = require'tabline_framework.functions'
local Collector = require'tabline_framework.collector'
local get_icon = require'nvim-web-devicons'.get_icon

local Tabline = {}
Tabline.__index = Tabline

local CurrentTab

local function calculate_viewport(active_index, total_tabs, available_width, tab_widths, arrow_width)
  local viewport = {
    start = 1,
    end_idx = total_tabs,
    has_left_overflow = false,
    has_right_overflow = false,
  }

  local total_width = 0
  for i = 1, total_tabs do
    total_width = total_width + tab_widths[i]
  end

  if total_width <= available_width then
    return viewport
  end

  local state = Config:get_viewport_state()
  local vp_start = state.start

  -- Ensure active tab is visible by adjusting start if needed
  if active_index < vp_start then
    vp_start = active_index
  end

  -- Calculate how many tabs fit starting from vp_start
  local vp_end = vp_start
  local current_width = 0
  local left_arrow_space = vp_start > 1 and arrow_width or 0

  for i = vp_start, total_tabs do
    local right_arrow_space = i < total_tabs and arrow_width or 0
    local tab_width = tab_widths[i]

    if current_width + tab_width + left_arrow_space + right_arrow_space <= available_width then
      current_width = current_width + tab_width
      vp_end = i
    else
      break
    end
  end

  -- If active tab is still not visible, scroll forward to show it
  if active_index > vp_end then
    vp_end = active_index
    current_width = tab_widths[active_index]
    vp_start = active_index

    local right_arrow_space = vp_end < total_tabs and arrow_width or 0

    -- Fill backwards from active tab
    for i = active_index - 1, 1, -1 do
      local left_arrow_space_needed = i > 1 and arrow_width or 0
      local tab_width = tab_widths[i]

      if current_width + tab_width + left_arrow_space_needed + right_arrow_space <= available_width then
        current_width = current_width + tab_width
        vp_start = i
      else
        break
      end
    end
  end

  state.start = vp_start

  viewport.start = vp_start
  viewport.end_idx = vp_end
  viewport.has_left_overflow = vp_start > 1
  viewport.has_right_overflow = vp_end < total_tabs

  return viewport
end

-- Render a single tab to a temporary collector and return its info
local function measure_tab(tabline_instance, callback, tab_info, tabs, current_tab)
  local temp_collector = Collector()
  local original_collector = tabline_instance.collector
  tabline_instance.collector = temp_collector

  local i = tab_info.index
  local v = tab_info.tab
  local current = v == current_tab

  if current then
    tabline_instance:use_tabline_sel_colors()
  else
    tabline_instance:use_tabline_colors()
  end

  tabline_instance:add('%' .. i .. 'T')

  CurrentTab = i
  callback({
    before_current = tabs[i + 1] and tabs[i + 1] == current_tab,
    after_current  = tabs[i - 1] and tabs[i - 1] == current_tab,
    first = i == 1,
    last = i == #tabs,
    index = i,
    tab = v,
    current = current,
    win = tab_info.win,
    buf = tab_info.buf,
    buf_nr = tab_info.buf,
    buf_name = tab_info.buf_name,
    filename = tab_info.filename,
    modified = tab_info.modified,
  })
  CurrentTab = nil

  local width = temp_collector:get_width()

  tabline_instance.collector = original_collector
  return width
end

function Tabline:use_tabline_colors()
  self.fg = Config.hl.fg
  self.bg = Config.hl.bg
  self.gui = Config.hl.gui
end

function Tabline:use_tabline_sel_colors()
  self.fg = Config.hl_sel.fg
  self.bg = Config.hl_sel.bg
  self.gui = Config.hl_sel.gui
end

function Tabline:use_tabline_fill_colors()
  self.fg = Config.hl_fill.fg
  self.bg = Config.hl_fill.bg
  self.gui = Config.hl_fill.gui
end


function Tabline:make_tabs(callback, list)
  local tabs = list or vim.api.nvim_list_tabpages()
  local current_tab = vim.api.nvim_get_current_tabpage()
  local current_index = 1

  local opts = Config:get_viewport_opts()
  local available_width = helpers.get_available_width()
  local tab_widths = {}
  local tab_info_cache = {}

  -- First pass: gather tab info and measure widths
  for i, v in ipairs(tabs) do
    if v == current_tab then
      current_index = i
    end

    local win = vim.api.nvim_tabpage_get_win(v)
    local buf = vim.api.nvim_win_get_buf(win)
    local buf_name = vim.api.nvim_buf_get_name(buf)
    local filename = vim.fn.fnamemodify(buf_name, ":t")
    local modified = vim.api.nvim_buf_get_option(buf, 'modified')

    tab_info_cache[i] = {
      index = i,
      tab = v,
      win = win,
      buf = buf,
      buf_name = buf_name,
      filename = #filename > 0 and filename or nil,
      modified = modified,
    }

    -- Measure actual rendered width using temporary collector
    tab_widths[i] = measure_tab(self, callback, tab_info_cache[i], tabs, current_tab)
  end

  local arrow_text = opts.arrow_padding .. opts.left_arrow .. opts.arrow_padding
  local arrow_width = vim.fn.strdisplaywidth(arrow_text)

  local viewport = calculate_viewport(current_index, #tabs, available_width, tab_widths, arrow_width)

  -- Second pass: render only visible tabs
  if viewport.has_left_overflow then
    self:use_tabline_colors()
    self:add(opts.arrow_padding .. opts.left_arrow .. opts.arrow_padding)
  end

  for i = viewport.start, viewport.end_idx do
    local v = tabs[i]
    local info = tab_info_cache[i]
    local current = v == current_tab

    if current then
      self:use_tabline_sel_colors()
    else
      self:use_tabline_colors()
    end

    self:add('%' .. i .. 'T')

    CurrentTab = i
    callback({
      before_current = tabs[i + 1] and tabs[i + 1] == current_tab,
      after_current  = tabs[i - 1] and tabs[i - 1] == current_tab,
      first = i == 1,
      last = i == #tabs,
      index = i,
      tab = v,
      current = current,
      win = info.win,
      buf = info.buf,
      buf_nr = info.buf,
      buf_name = info.buf_name,
      filename = info.filename,
      modified = info.modified,
    })
    CurrentTab = nil
  end
  self:add('%T')

  if viewport.has_right_overflow then
    self:use_tabline_colors()
    self:add(opts.arrow_padding .. opts.right_arrow .. opts.arrow_padding)
  end

  self:use_tabline_fill_colors()
  self:add('')
end

function Tabline:__make_bufs(buf_list, callback)
  local bufs = {}

  for _, buf in ipairs(buf_list) do
    if vim.api.nvim_buf_is_valid(buf) and vim.api.nvim_buf_get_option(buf, 'buflisted') then
      table.insert(bufs, buf)
    end
  end

  for i, buf in ipairs(bufs) do
    local current_buf = vim.api.nvim_get_current_buf()
    local current = vim.api.nvim_get_current_buf() == buf

    if current then
      self:use_tabline_sel_colors()
    else
      self:use_tabline_colors()
    end

    local buf_name = vim.api.nvim_buf_get_name(buf)
    local filename = vim.fn.fnamemodify(buf_name, ":t")
    local modified = vim.api.nvim_buf_get_option(buf, 'modified')

    callback({
      before_current = bufs[i + 1] and bufs[i + 1] == current_buf,
      after_current =  bufs[i - 1] and bufs[i - 1] == current_buf,
      first = i == 1,
      last = i == #bufs,
      index = i,
      current = current,
      buf = buf,
      buf_nr = buf,
      buf_name = buf_name,
      filename = #filename > 0 and filename or nil,
      modified = modified,
    })
  end

  self:use_tabline_fill_colors()
  self:add('')
end

function Tabline:make_bufs(callback, list)
  return self:__make_bufs(list or vim.api.nvim_list_bufs(), callback)
end

function Tabline:make_tab_bufs(callback)
  local bufs = {}
  local wins = vim.api.nvim_tabpage_list_wins(0)

  for _, win in ipairs(wins) do
    table.insert(bufs, vim.api.nvim_win_get_buf(win))
  end

  return self:__make_bufs(bufs, callback)
end

function Tabline:add(item, closure)
  if type(item) == 'string' then item = { item }
  elseif type(item) == 'number' then item = { string(item) }
  elseif type(item) == 'table' then
    if not item[1] then return end
  else
    return
  end

  if closure then closure(item) end

  item.fg = item.fg or self.fg
  item.bg = item.bg or self.bg
  item.gui = item.gui or self.gui

  self.collector:add(item)
end

function Tabline:close_tab_btn(item)
  if not CurrentTab then
    print_warn 'TablineFramework: close_tab_btn function used outside the tab'
    return
  end

  self:add(item, function(tbl)
    tbl[1] = '%' .. CurrentTab .. 'X' .. tbl[1] .. '%X'
  end)
end

function Tabline:add_btn(item, callback)
  if not callback then
    print_warn 'TablineFramework: callback function not provided'
    return
  end

  self:add(item, function(tbl)
    local name = functions.register(function(minwid, clicks, mouse_btn, modifiers)
      callback({
        minwid = minwid,
        clicks = clicks,
        mouse_btn = mouse_btn,
        modifiers = modifiers
      })
    end)
    tbl[1] = '%@' .. name .. '@' .. tbl[1] .. '%T'
  end)
end

local function icon(name)
  if not name then return end
  local i = get_icon(name, nil, {default = true})
  return i
end

local function icon_color(name)
  if not name then return end

  local _, hl = get_icon(name, nil, {default = true})
  return hi.get_hl(hl).fg
end

function Tabline:render(render_func)
  local content = {}

  functions.clear()
  self:use_tabline_fill_colors()

  render_func({
    icon = icon,
    icon_color = icon_color,
    set_colors = function(opts)
      self.fg = opts.fg or self.fg
      self.bg = opts.bg or self.bg
      self.gui = opts.gui or self.gui
    end,
    set_fg = function(arg_fg) self.fg = arg_fg or self.fg end,
    set_bg = function(arg_bg) self.bg = arg_bg or self.bg end,
    set_gui = function(arg_gui) self.gui = arg_gui or self.gui end,
    add = function(arg) self:add(arg) end,
    add_spacer = function() self:add('%=') end,
    make_tabs = function(callback, list) self:make_tabs(callback, list) end,
    make_bufs = function(callback, list) self:make_bufs(callback, list) end,
    close_tab_btn = function(arg) self:close_tab_btn(arg) end,
    add_btn = function(arg, callback) self:add_btn(arg, callback) end,
    -- make_tab_bufs = function(callback) self:make_tab_bufs(callback) end,
  })

  for _, item in ipairs(self.collector) do
    table.insert(content, ('%%#%s#%s'):format(hi.set_hl(item.fg, item.bg, item.gui), item[1]))
  end

  return table.concat(content)
end

Tabline.run = function(callback)
  local new_obj = setmetatable({
    collector = Collector()
  }, Tabline)
  return new_obj:render(callback)
end


return Tabline
