local function get_tab_var(tab, name)
  local has_name, tab_var = pcall(vim.api.nvim_tabpage_get_var, tab, name)
  return has_name and tab_var
end

local function print_warn(str)
  vim.api.nvim_command('echohl WarningMsg')
  vim.api.nvim_command(('echomsg "%s"'):format(str))
  vim.api.nvim_command('echohl None')
end

local function print_error(str)
  vim.api.nvim_command('echohl Error')
  vim.api.nvim_command(('echomsg "%s"'):format(str))
  vim.api.nvim_command('echohl None')
end

local function get_available_width()
  return vim.o.columns
end

local function estimate_tab_width(filename, padding)
  padding = padding or 4
  local name_len = filename and #filename or 8
  return name_len + padding
end

return {
  get_tab_var = get_tab_var,
  print_warn = print_warn,
  print_error = print_error,
  get_available_width = get_available_width,
  estimate_tab_width = estimate_tab_width,
}
