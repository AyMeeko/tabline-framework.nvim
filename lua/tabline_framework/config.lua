local Config = {data = {}}

Config.new = function(t, tbl) rawset(t, 'data', tbl) end

Config.merge = function(t, tbl)
  for k, v in pairs(tbl) do
    rawget(t, 'data')[k] = v
  end
end

Config.get_viewport_opts = function(t)
  local data = rawget(t, 'data')
  local viewport = data.viewport or {}
  return {
    hide_single_tab = viewport.hide_single_tab ~= false,
    left_arrow = viewport.left_arrow or '◀',
    right_arrow = viewport.right_arrow or '▶',
    arrow_padding = viewport.arrow_padding or ' ',
  }
end

Config.get_viewport_state = function(t)
  local data = rawget(t, 'data')
  if not data._viewport_state then
    data._viewport_state = {
      start = 1,
      cached_width = nil,
    }
  end
  return data._viewport_state
end

Config.reset_viewport_cache = function(t)
  local data = rawget(t, 'data')
  if data._viewport_state then
    data._viewport_state.cached_width = nil
  end
end

local functions = {
  new = true,
  merge = true,
  get_viewport_opts = true,
  get_viewport_state = true,
  reset_viewport_cache = true,
}

return setmetatable(Config, {
  __index = function(t, k)
    if functions[k] then
      return rawget(t, k)
    else
      return rawget(t, 'data')[k]
    end
  end,
  __newindex = function(t, k, v) rawget(t, 'data')[k] = v end,
})
