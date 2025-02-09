local api = vim.api
local cfg = require("notifier.config")
local displayw = vim.fn.strdisplaywidth

local Message = {}







local Component = {}

local StatusModule = {}












StatusModule.buf_nr = nil
StatusModule.win_nr = nil
StatusModule.active = {}

local function get_status_width()
   local w = cfg.config.status_width
   if type(w) == "function" then
      return w()
   else
      return w
   end
end

function StatusModule._create_win()
   if not StatusModule.win_nr then
      if not StatusModule.buf_nr then
         StatusModule.buf_nr = api.nvim_create_buf(false, true);
      end
      StatusModule.win_nr = api.nvim_open_win(StatusModule.buf_nr, false, {
         focusable = false,
         style = "minimal",
         border = "none",
         noautocmd = true,
         relative = "editor",
         anchor = "SE",
         width = get_status_width(),
         height = 3,
         row = vim.o.lines - vim.o.cmdheight - 1,
         col = vim.o.columns,
         zindex = 10,
      })
      if api.nvim_win_set_hl_ns then
         api.nvim_win_set_hl_ns(StatusModule.win_nr, cfg.NS_ID)
      end
   end
end

function StatusModule._delete_win()
   api.nvim_win_close(StatusModule.win_nr, true)
   StatusModule.win_nr = nil
end

local function adjust_width(src, width)
   if displayw(src) > width then
      return string.sub(src, 1, width - 3) .. "..."
   else
      local acc = src
      while displayw(acc) < width do
         acc = " " .. acc
      end

      return acc
   end
end

local function format(name, msg, width)
   local inner_width = width - displayw(name) - 1
   if msg.icon then
      inner_width = inner_width - 2
   end


   local fmt_msg
   if msg.opt then
      local tmp = string.format("%s (%s)", msg.mandat, msg.opt)
      if displayw(tmp) > inner_width then
         fmt_msg = adjust_width(msg.mandat, inner_width)
      else
         fmt_msg = adjust_width(tmp, inner_width)
      end
   else
      fmt_msg = adjust_width(msg.mandat, inner_width)
   end

   if msg.icon then
      return string.format("%s %s %s", fmt_msg, name, msg.icon)
   else
      return string.format("%s %s", fmt_msg, name)
   end
end

function StatusModule.redraw()
   StatusModule._create_win()

   local lines = {}
   local hl_infos = {}
   local width = get_status_width()
   local function push_line(title, content)
      local formatted = format(title, content, width)
      if cfg.config.debug then
         vim.pretty_print(formatted)
      end
      table.insert(lines, formatted)
      table.insert(hl_infos, { name = title, dim = content.dim, icon = content.icon })
   end


   for _, compname in ipairs(cfg.config.components) do
      local msgs = StatusModule.active[compname] or {}
      local is_tbl = vim.tbl_islist(msgs)

      for name, msg in pairs(msgs) do

         local rname = msg.title
         if not rname and is_tbl then
            rname = compname
         elseif not is_tbl then
            rname = name
         end

         if cfg.config.component_name_recall and not is_tbl then
            rname = string.format("%s:%s", compname, rname)
         end

         push_line(rname, msg)
      end
   end


   if #lines > 0 then
      api.nvim_buf_clear_namespace(StatusModule.buf_nr, cfg.NS_ID, 0, -1)
      api.nvim_buf_set_lines(StatusModule.buf_nr, 0, -1, false, lines)

      for i = 1, #hl_infos do
         local hl_group
         if hl_infos[i].dim then
            hl_group = cfg.HL_CONTENT_DIM
         else
            hl_group = cfg.HL_CONTENT
         end



         local title_start_offset = #lines[i] - #hl_infos[i].name
         if hl_infos[i].icon then
            title_start_offset = title_start_offset - #hl_infos[i].icon - 1
         end

         local title_stop_offset
         if hl_infos[i].icon then
            title_stop_offset = #lines[i] - #hl_infos[i].icon - 1
         else
            title_stop_offset = -1
         end
         api.nvim_buf_add_highlight(StatusModule.buf_nr, cfg.NS_ID, hl_group, i - 1, 0, title_start_offset - 1)
         api.nvim_buf_add_highlight(StatusModule.buf_nr, cfg.NS_ID, cfg.HL_TITLE, i - 1, title_start_offset, title_stop_offset)

         if hl_infos[i].icon then
            api.nvim_buf_add_highlight(StatusModule.buf_nr, cfg.NS_ID, cfg.HL_ICON, i - 1, title_stop_offset + 1, -1)
         end
      end

      api.nvim_win_set_height(StatusModule.win_nr, #lines)
   else
      StatusModule._delete_win()
   end
end

function StatusModule.push(component, content, title)
   if not StatusModule.active[component] then
      StatusModule.active[component] = {}
   end

   if type(content) == "string" then
      content = { mandat = content }
   end

   content = content

   if content.icon and displayw(content.icon) > 1 then
      error("Message icon should be of length one screen cell.")
   end

   if title then
      StatusModule.active[component][title] = content
   else
      table.insert(StatusModule.active[component], content)
   end
   StatusModule.redraw()
end

function StatusModule.pop(component, title)
   if not StatusModule.active[component] then return end

   if title then
      StatusModule.active[component][title] = nil
   else
      table.remove(StatusModule.active[component])
   end
   StatusModule.redraw()
end

function StatusModule.clear(component)
   StatusModule.active[component] = nil
   StatusModule.redraw()
end

function StatusModule.handle(msg)
   if msg.done then
      StatusModule.pop("lsp", msg.name)
   else
      StatusModule.push("lsp", { mandat = msg.title, opt = msg.message, dim = true }, msg.name)
   end
end

return StatusModule
