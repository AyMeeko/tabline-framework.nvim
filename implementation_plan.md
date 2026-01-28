# Implementation Plan: Sliding Viewport for Tabline Framework

## Overview
Add sliding viewport functionality to handle tab overflow in the tabline plugin. The viewport will dynamically adjust to show the active tab while hiding overflowed tabs, with arrow indicators to show when more tabs exist.

## Requirements Analysis
Based on user requirements:
- **Overflow indication**: Show arrow indicators when tabs overflow
- **Viewport sizing**: Use Neovim API to determine window width dynamically
- **Single tab behavior**: Hide tabline when only 1 tab exists

## Current Architecture
- Plugin uses Neovim's `tabline` option with dynamic expression: `%!v:lua.require'tabline_framework'.make_tabline()`
- `make_tabs()` function iterates through all tabs and renders them
- `Collector` builds the final tabline string
- Currently renders all tabs without viewport management

## Implementation Strategy

### 1. Viewport State Management
**File**: `lua/tabline_framework/config.lua`
- Add viewport state tracking to the Config module
- Track: `viewport_start`, `viewport_end`, `total_tabs`
- Store current viewport position for smooth transitions

```lua
-- Add to Config data structure
viewport = {
  start = 1,
  end = nil,
  cached_width = nil,
  last_active_tab = nil
}
```

### 2. Window Width Detection
**File**: `lua/tabline_framework/helpers.lua`
- Use `vim.api.nvim_win_get_width(0)` to get available window width
- Calculate dynamic viewport width based on actual tab content
- Account for padding, separators, and arrow indicators

```lua
local function get_available_width()
  return vim.api.nvim_win_get_width(0)
end

local function calculate_tab_width(tab_info)
  -- Calculate rendered width of individual tab
  -- Account for filename length, icons, modifiers, padding
end
```

### 3. Modified Tab Rendering Logic
**File**: `lua/tabline_framework/tabline.lua`
- Update `make_tabs()` to accept viewport parameters
- Only render tabs within current viewport range
- Add arrow indicators when overflow exists

```lua
function Tabline:make_tabs_with_viewport(callback, list)
  local tabs = list or vim.api.nvim_list_tabpages()
  local current_tab = vim.api.nvim_get_current_tabpage()
  local current_index = get_tab_index(current_tab, tabs)
  
  -- Return early if only one tab
  if #tabs <= 1 then
    return
  end
  
  local viewport = calculate_viewport(current_index, #tabs, get_available_width())
  
  -- Add left arrow if needed
  if viewport.start > 1 then
    self:add_arrow('left', viewport.start - 1)
  end
  
  -- Render only visible tabs
  for i = viewport.start, viewport.end do
    -- existing tab rendering logic...
  end
  
  -- Add right arrow if needed
  if viewport.end < #tabs then
    self:add_arrow('right', viewport.end + 1)
  end
end
```

### 4. Viewport Calculation Algorithm
**File**: `lua/tabline_framework/tabline.lua`

```lua
local function calculate_viewport(active_tab_index, total_tabs, available_width)
  local viewport = {
    start = 1,
    end = total_tabs
  }
  
  -- Calculate how many tabs can fit
  local fitting_tabs = estimate_fitting_tabs(available_width)
  
  if total_tabs <= fitting_tabs then
    -- All tabs fit, no need for viewport
    return viewport
  end
  
  -- Calculate viewport bounds to center active tab
  local half_viewport = math.floor(fitting_tabs / 2)
  viewport.start = math.max(1, active_tab_index - half_viewport)
  viewport.end = viewport.start + fitting_tabs - 1
  
  -- Adjust if viewport extends beyond bounds
  if viewport.end > total_tabs then
    viewport.end = total_tabs
    viewport.start = viewport.end - fitting_tabs + 1
    viewport.start = math.max(1, viewport.start)
  end
  
  return viewport
end
```

### 5. Arrow Indicators
**File**: `lua/tabline_framework/tabline.lua`

```lua
function Tabline:add_arrow(direction, target_tab)
  self:use_tabline_colors()
  
  local arrow_symbol = direction == 'left' and '◀' or '▶'
  
  self:add_btn(
    { ' ' .. arrow_symbol .. ' ' },
    function()
      -- Scroll viewport to show target_tab
      if direction == 'left' then
        Config.viewport.start = math.max(1, target_tab - Config.viewport_size + 1)
      else
        Config.viewport.start = target_tab
      end
      -- Trigger tabline redraw
      vim.cmd('redrawtabline')
    end
  )
end
```

### 6. Single Tab Visibility
**File**: `lua/tabline_framework.lua`

```lua
local function make_tabline()
  local tabs = vim.api.nvim_list_tabpages()
  
  -- Hide tabline when only one tab
  if #tabs <= 1 then
    return ''
  end
  
  return Tabline.run(Config.render)
end
```

### 7. Event Handling Setup
**File**: `lua/tabline_framework.lua`

```lua
local function setup_events()
  local group = vim.api.nvim_create_augroup('TablineFramework', { clear = true })
  
  vim.api.nvim_create_autocmd({ 'TabEnter', 'TabNew', 'TabClosed' }, {
    group = group,
    callback = function()
      -- Reset viewport cache on tab changes
      if Config.viewport then
        Config.viewport.last_active_tab = vim.api.nvim_get_current_tabpage()
      end
    end
  })
  
  vim.api.nvim_create_autocmd({ 'WinResized', 'VimResized' }, {
    group = group,
    callback = function()
      -- Clear width cache on resize
      if Config.viewport then
        Config.viewport.cached_width = nil
      end
    end
  })
end
```

## Files to Modify

### 1. `lua/tabline_framework/config.lua`
- Add viewport state management
- Merge viewport options from user config

### 2. `lua/tabline_framework/tabline.lua`
- Implement `make_tabs_with_viewport()` function
- Add viewport calculation algorithm
- Add arrow indicator functionality
- Add tab width estimation utilities

### 3. `lua/tabline_framework.lua`
- Update `make_tabline()` to handle single tab case
- Add event handling setup
- Hook viewport management into setup function

### 4. `lua/tabline_framework/helpers.lua`
- Add window width detection utilities
- Add tab width calculation functions
- Add viewport-related helper functions

## Key Implementation Challenges

### 1. Accurate Tab Width Calculation
- Need to estimate rendered width before actual rendering
- Account for varying filename lengths, icons, modifiers
- Handle different font sizes and configurations

### 2. Smooth Viewport Transitions
- Maintain viewport position during tab navigation
- Handle rapid tab switching gracefully
- Cache viewport calculations for performance

### 3. Edge Cases
- Very narrow windows (few or no tabs fit)
- Large numbers of tabs (performance considerations)
- Rapid tab creation/deletion
- Window resizing while tabs are overflowed

### 4. Backward Compatibility
- Ensure existing render functions continue to work
- Provide migration path for custom configurations
- Maintain current API surface

## Testing Strategy

### 1. Unit Tests
- Viewport calculation algorithm
- Tab width estimation
- Arrow indicator logic

### 2. Integration Tests
- Single tab visibility
- Multi-tab overflow scenarios
- Window resize handling
- Tab navigation behavior

### 3. Edge Case Tests
- Very narrow windows
- Large tab counts
- Rapid tab switching
- Mixed tab types (different filename lengths)

## Performance Considerations

### 1. Caching Strategy
- Cache tab width calculations
- Cache viewport calculations
- Only recalculate on window/tab changes

### 2. Minimal Redraws
- Only redraw tabline when viewport changes
- Debounce rapid tab switching
- Optimize arrow indicator rendering

## Configuration Options

```lua
require('tabline_framework').setup({
  render = your_render_function,
  viewport = {
    -- Minimum tabs to show in viewport
    min_tabs = 3,
    -- Maximum tabs to show in viewport
    max_tabs = 10,
    -- Show arrow indicators
    show_arrows = true,
    -- Hide tabline with single tab
    hide_single_tab = true,
    -- Animation/transition settings
    smooth_scroll = true
  }
})
```

## Timeline

### Phase 1: Core Viewport Logic
- Implement viewport calculation
- Modify tab rendering
- Add basic arrow indicators

### Phase 2: Integration & Polish
- Add event handling
- Implement single tab hiding
- Add configuration options

### Phase 3: Testing & Optimization
- Comprehensive testing
- Performance optimization
- Documentation updates

## Success Criteria

1. ✅ Viewport automatically adjusts to show active tab
2. ✅ Arrow indicators appear when tabs overflow
3. ✅ Single tab scenario hides tabline
4. ✅ Smooth navigation between tabs
5. ✅ Responsive to window resizing
6. ✅ Backward compatibility maintained
7. ✅ Performance acceptable for large tab counts