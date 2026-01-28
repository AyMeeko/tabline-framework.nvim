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

-- UTF-8 aware character iterator
local function utf8_chars(str)
  local i = 1
  return function()
    if i > #str then return nil end
    local byte = str:byte(i)
    local char_len = 1
    if byte >= 0xF0 then char_len = 4
    elseif byte >= 0xE0 then char_len = 3
    elseif byte >= 0xC0 then char_len = 2
    end
    local char = str:sub(i, i + char_len - 1)
    i = i + char_len
    return char
  end
end

-- Truncate collector content to fit within max_width, adding ellipsis
function Collector:truncate(max_width, ellipsis)
  ellipsis = ellipsis or '…'
  local ellipsis_width = vim.fn.strdisplaywidth(ellipsis)

  if max_width <= ellipsis_width then
    -- Not enough space even for ellipsis, clear everything
    self:clear()
    return
  end

  local current_width = 0
  local truncate_at_item = nil
  local truncate_at_byte = nil

  for idx, item in ipairs(self) do
    local text = item[1] or ''
    -- Strip format codes for width calculation
    local stripped = text:gsub('%%[0-9]*[TXM]', '')
    stripped = stripped:gsub('%%@[^@]*@', '')
    stripped = stripped:gsub('%%#[^#]*#', '')
    stripped = stripped:gsub('%%%%', '%%')
    stripped = stripped:gsub('%%=', '')

    local item_width = vim.fn.strdisplaywidth(stripped)

    if current_width + item_width > max_width - ellipsis_width then
      truncate_at_item = idx
      -- Find byte position to truncate at
      local remaining = max_width - ellipsis_width - current_width
      truncate_at_byte = 0
      local char_width = 0
      for char in utf8_chars(stripped) do
        local w = vim.fn.strdisplaywidth(char)
        if char_width + w > remaining then
          break
        end
        char_width = char_width + w
        truncate_at_byte = truncate_at_byte + #char
      end
      break
    end
    current_width = current_width + item_width
  end

  if truncate_at_item then
    -- Remove items after truncation point
    for i = #self, truncate_at_item + 1, -1 do
      self[i] = nil
    end

    -- Truncate the item at truncation point
    local item = self[truncate_at_item]
    if item then
      local text = item[1] or ''
      -- Extract format codes at the start
      local prefix_codes = ''
      local content = text

      -- Handle %nT at start
      local click_handler = text:match('^(%%[0-9]*T)')
      if click_handler then
        prefix_codes = click_handler
        content = text:sub(#click_handler + 1)
      end

      -- Truncate the content portion by byte position
      local truncated = content:sub(1, truncate_at_byte)

      item[1] = prefix_codes .. truncated .. ellipsis
    end
  end
end

Collector.__call = function()
  return setmetatable({}, Collector)
end

return setmetatable({}, Collector)
