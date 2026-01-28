local Collector = {}
Collector.__index = Collector

function Collector:add(item)
  table.insert(self, item)
end

function Collector:clear()
  for i = #self, 1, -1 do
    self[i] = nil
  end
end

function Collector:get_width()
  local width = 0
  for _, item in ipairs(self) do
    local text = item[1] or ''
    -- Strip vim tabline format codes that don't contribute to visual width
    local stripped = text:gsub('%%[0-9]*[TXM]', '')
    stripped = stripped:gsub('%%@[^@]*@', '')
    stripped = stripped:gsub('%%#[^#]*#', '')
    stripped = stripped:gsub('%%%%', '%%')
    stripped = stripped:gsub('%%=', '')
    width = width + vim.fn.strdisplaywidth(stripped)
  end
  return width
end

Collector.__call = function()
  return setmetatable({}, Collector)
end

return setmetatable({}, Collector)
