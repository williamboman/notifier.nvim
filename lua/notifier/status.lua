local api = vim.api
local cfg = require("notifier.config")
local displayw = vim.fn.strdisplaywidth

local Message = {}







local Component = {}

local WinBuf = {}




function WinBuf.new()
   return setmetatable({}, { __index = WinBuf })
end

function WinBuf:set_buffer(buf_nr)
   self.buf_nr = buf_nr
   return self
end

function WinBuf:set_window(win_nr)
   self.win_nr = win_nr
   return self
end

function WinBuf:get_buffer()
   if self.buf_nr and api.nvim_buf_is_valid(self.buf_nr) then
      return self.buf_nr
   end
end

function WinBuf:get_window()
   if self.win_nr and api.nvim_win_is_valid(self.win_nr) then
      return self.win_nr
   end
end

function WinBuf:is_valid()
   return self:get_window() ~= nil and self:get_buffer() ~= nil
end

function WinBuf:delete()
   local buf_nr = self:get_buffer()
   local win_nr = self:get_window()
   if buf_nr then


   end
   if win_nr then
      api.nvim_win_close(win_nr, true)
   end
   return self
end

local StatusModule = {}














StatusModule.content = WinBuf.new()
StatusModule.title = WinBuf.new()
StatusModule.active = {}

local function scheduled(func)
   return function()
      vim.schedule(func)
   end
end

local function get_status_width()
   local w = cfg.config.status_width
   if type(w) == "function" then
      return w()
   else
      return w
   end
end

function StatusModule._create_win()
   if not StatusModule.content:get_buffer() then
      StatusModule.content:set_buffer(api.nvim_create_buf(false, true));
   end
   if not StatusModule.title:get_buffer() then
      StatusModule.title:set_buffer(api.nvim_create_buf(false, true));
   end

   if not StatusModule.content:get_window() then
      local border
      if cfg.config.debug then
         border = "single"
      else
         border = "none"
      end
      local win_nr = api.nvim_open_win(StatusModule.content:get_buffer(), false, {
         focusable = false,
         style = "minimal",
         border = border,
         noautocmd = true,
         relative = "editor",
         anchor = "SE",
         width = get_status_width(),
         height = 3,
         row = vim.o.lines - vim.o.cmdheight - 1,
         col = vim.o.columns,
         zindex = cfg.config.zindex,
      })
      api.nvim_win_set_option(win_nr, "wrap", false)
      StatusModule.content:set_window(win_nr)

      if api.nvim_win_set_hl_ns then
         api.nvim_win_set_hl_ns(win_nr, cfg.NS_ID)
      end
   end

   if not StatusModule.title:get_window() then
      local border
      if cfg.config.debug then
         border = "single"
      else
         border = "none"
      end
      local win_nr = api.nvim_open_win(StatusModule.title:get_buffer(), false, {
         focusable = false,
         style = "minimal",
         border = border,
         noautocmd = true,
         relative = "editor",
         anchor = "SE",
         width = 1,
         height = 3,
         row = vim.o.lines - vim.o.cmdheight - 1,
         col = vim.o.columns - get_status_width(),
         zindex = cfg.config.zindex,
      })
      api.nvim_win_set_option(win_nr, "wrap", false)
      StatusModule.title:set_window(win_nr)

      if api.nvim_win_set_hl_ns then
         api.nvim_win_set_hl_ns(win_nr, cfg.NS_ID)
      end
   end
end

function StatusModule._ui_valid()
   return StatusModule.content:is_valid() and StatusModule.title:is_valid()
end

function StatusModule._delete_win()
   StatusModule.content:delete()
   StatusModule.title:delete()
end

local function pad(str, width)
   if #str < width then
      return (" "):rep(width - #str - 1) .. str
   end
   return str
end

StatusModule.redraw = scheduled(function()
   StatusModule._create_win()

   if not StatusModule._ui_valid() then return end

   if cfg.config.debug then
      vim.pretty_print(StatusModule.content)
      vim.pretty_print(StatusModule.title)
   end

   local lines = {}
   local titles = {}
   local hl_infos = {}



   local function push_line(title, content)
      local message_lines = {}
      for _, line in ipairs(vim.split(content.mandat, '\n', { plain = true, trimempty = true })) do
         local content_width = get_status_width()
         if #line > content_width then
            for i = 1, #line, content_width do
               message_lines[#message_lines + 1] = line:sub(i, i + content_width - 1)
            end
         else
            message_lines[#message_lines + 1] = line
         end
      end

      if cfg.config.debug then
         vim.pretty_print(message_lines)
      end

      for i, line in ipairs(message_lines) do
         if i == 1 then
            titles[#lines + 1] = title
         end
         lines[#lines + 1] = line
         hl_infos[#hl_infos + 1] = { title = title, dim = content.dim, icon = content.icon, content = line, level = content.level }
      end
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

   local title_width = 0
   for _, title in pairs(titles) do
      title_width = math.max(#title + 1, title_width)
   end

   if #lines > 0 then
      local buf_nr = StatusModule.content:get_buffer()
      local win_nr = StatusModule.content:get_window()
      api.nvim_buf_clear_namespace(buf_nr, cfg.NS_ID, 0, -1)
      api.nvim_buf_set_lines(buf_nr, 0, -1, false, lines)

      for i = 1, #hl_infos do
         local hl_group
         if hl_infos[i].dim then
            hl_group = cfg.HL_CONTENT_DIM
         else
            hl_group = cfg.HL_CONTENT[hl_infos[i].level]
         end

         api.nvim_buf_add_highlight(buf_nr, cfg.NS_ID, hl_group, i - 1, 0, -1)

         if titles[i] then
            local title = titles[i] .. " "
            if hl_infos[i].icon then
               title = hl_infos[i].icon .. " " .. title
            end
            api.nvim_buf_set_lines(StatusModule.title:get_buffer(), i - 1, i, false, { pad(title, title_width + 1) })
            api.nvim_buf_add_highlight(StatusModule.title:get_buffer(), cfg.NS_ID, cfg.HL_TITLE, i - 1, 0, -1)
         else
            api.nvim_buf_set_lines(StatusModule.title:get_buffer(), i - 1, i, false, { "" })
         end
      end

      api.nvim_win_set_height(win_nr, #lines)
      api.nvim_win_set_height(StatusModule.title:get_window(), #lines)
      api.nvim_win_set_width(StatusModule.title:get_window(), title_width)
   else
      StatusModule._delete_win()
   end
end)

function StatusModule._ensure_valid(msg)
   if msg.icon and displayw(msg.icon) == 0 then
      msg.icon = nil
   end

   if msg.title and displayw(msg.title) == 0 then
      msg.title = nil
   end

   if msg.title and string.find(msg.title, "\n") then
      error("Message title cannot contain newlines")
   end

   if msg.icon and string.find(msg.icon, "\n") then
      error("Message icon cannot contain newlines")
   end

   return true
end

function StatusModule.push(component, content, title)
   if not StatusModule.active[component] then
      StatusModule.active[component] = {}
   end

   if type(content) == "string" then
      content = { mandat = content }
   end

   content = content
   if not cfg.config.debug or StatusModule._ensure_valid(content) then
      if title then
         StatusModule.active[component][title] = content
      else
         table.insert(StatusModule.active[component], content)
      end
      StatusModule.redraw()
   end
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
      local mandat = msg.title
      if msg.message then
         mandat = mandat .. " " .. msg.message
      end
      StatusModule.push("lsp", { mandat = mandat, title = msg.name, level = vim.log.levels.INFO, dim = true }, msg.name)
   end
end

return StatusModule
