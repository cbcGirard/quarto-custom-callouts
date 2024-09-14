local custom_callouts = nil
local callout_scss = nil

--- scss stylesheets
local sheets = {
  {
    path = "custom-callouts.scss",
    -- attribs = {
    --   type = "text/css",
    -- }
  },
}


--- Returns true if a file exists, false otherwise.
---@param path string
---@return boolean
local function fileExists(path)
  local file = io.open(path, "r")
  if file then
    file:close()
    return true
  end
  return false
end

--- Returns the directory part of a file's path.
---@param path any
---@return string
local function drop_file_from_path(path)
  local parts = pandoc.path.split(path)
  table.remove(parts)
  return pandoc.path.join(parts)
end

--- Returns full path to a file if it exists in a directory; nil otherwise.
---@param filename string
---@param directory string
---@return string?
local function tryDirectory(filename, directory)

  parts = pandoc.path.split(directory)
  table.insert(parts, filename)
  -- quarto.log.debug(parts)

  local path = pandoc.path.join(parts)
  if fileExists(path) then
    return path
  else
    return nil
  end
end

--- Returns the full path to a local dependency.
---@param filename string
---@return string
local function find_local_dep(filename)
  local localDep = quarto.utils.resolve_path(filename)

  if fileExists(localDep) then
      return localDep  
  else
    path = tryDirectory(filename, drop_file_from_path(quarto.doc.input_file))
    if path then
      return path
    else
      path = tryDirectory(filename, quarto.project.directory)
      if path then
        return path
      else
        quarto.log.error("Could not find local dependency: " .. filename)
      end
    end
    return pandoc.path.join(parts)
  end
end

local function make_css(callouts)
  -- css = "<style>\n"
  css = "/*-- scss:rules --*/\n"
  for i, my_callout in ipairs(callouts) do
    header_css = "div.callout.callout-style-default.callout-" ..
    pandoc.utils.stringify(my_callout.name) .. ">.callout-header {\n"

    callout_css = "div.callout.callout-style-default.callout-" .. pandoc.utils.stringify(my_callout.name) .. "{\n"

    if my_callout.color ~= nil then
      color = pandoc.utils.stringify(my_callout.color)
      if my_callout.left_color ~= nil then
        left_color = pandoc.utils.stringify(my_callout.left_color)
        header_color = color
      else
        left_color = color
        -- header_color = "rgba(" .. color .. ", 75%)"
        header_color = "color-mix(in srgb, " .. color .. ", transparent 75%)"
      end

      css = css .. header_css .. "background-color: " .. header_color .. ";\n"

      if my_callout.text_color ~= nil then
        text_color = pandoc.utils.stringify(my_callout.text_color)
        css = css .. "color: " .. text_color .. ";\n}\n"
      else
        css = css .. "}\n"
      end

      css = css .. callout_css .. "border-left-color: " .. left_color .. ";}\n"
    end
  end
  -- css = css .. "</style>"
  -- quarto.log.debug(css)
  return css
end

function Meta(meta)
  if meta.custom_callouts ~= nil then
    custom_callouts = meta.custom_callouts
    callout_scss = meta.callout_scss
    doc_path = quarto.doc.input_file
    if quarto.doc.is_format("html*") then
      css = make_css(custom_callouts)
      
      -- sheets = {
      --   {
      --     path = "custom-callouts.scss",
      --     attribs = {
      --       type = "text/css",
      --     }
      --   },
      -- }
      if callout_scss ~= nil then
        for i, sheet in ipairs(callout_scss) do
          sheetname = pandoc.utils.stringify(sheet)
          dep_path = find_local_dep(sheetname)
          -- quarto.log.debug(dep_path)


          -- add to theme
          -- if meta.theme~=nil then
          --   meta.theme:insert(sheet)
          -- else
          --   meta.theme = sheet
          -- end

          -- copy to extension directory
          -- dep_contents = io.open(dep_path, "r"):read("*a")
          -- -- quarto.log.debug(dep_contents)
          -- -- dest_path = quarto.utils.resolve_path(sheetname)
          -- dest_path = dep_path
          -- io.open(dest_path, "w"):write(dep_contents):close()

          -- add to dependencies
          table.insert(sheets, {
            -- path = pandoc.utils.stringify(sheet),
            path = dep_path,
            -- attribs = {
            --   type = "text/css",
            -- }
          })
          css = "@import './" .. sheetname .. "';\n\n" .. css
        end

      end

      path = quarto.utils.resolve_path("custom-callouts.scss")
      io.open(path, "w"):write(css):close()


      -- quarto.doc.add_html_dependency({
      --   name = 'custom-callouts',
      --   version = '0.0.0',
      --   stylesheets = sheets
      -- })
    end
  end
  return meta
end



local function ensure_html_deps()
  quarto.doc.add_html_dependency({
    name = 'iconify-icon',
    version = '2.1.0',
    scripts = {
      {
        path = "iconify-icon.min.js",
        -- path= "https://code.iconify.design/iconify-icon/2.1.0/iconify-icon.min.js",
        attribs = {
          type = "module",
        }
      }
    }
  })
end

function Div(el)
  -- quarto.log.debug(el.classes)
  if custom_callouts ~= nil then
    for i, custom in ipairs(custom_callouts) do
      custom_suffix = pandoc.utils.stringify(custom.name)
      custom_class = "callout-" .. custom_suffix
      -- quarto.log.debug(custom_class)
      -- quarto.log.debug(el.classes)
      if (el.classes:includes(custom_class)) then
        if custom.heading then
          custom_title = custom.heading:walk{}
        else
          custom_title = custom.name:walk{}
        end

        if custom.icon ~= nil then
          -- handle additional attributes (flip, rotate, etc.)
          attr = ""
          if custom.attr ~= nil then
            for key, value in pairs(custom.attr) do
              -- quarto.log.debug(key)
              -- quarto.log.debug(value)
              attr = attr .. " " .. key .. "='" .. pandoc.utils.stringify(value) .. "'"
              -- quarto.log.debug(attr)
            end
          end

          ico = pandoc.RawInline("html", "<iconify-icon inline icon='" ..
            pandoc.utils.stringify(custom.icon) .. "'" .. attr .. "></iconify-icon>&nbsp;")

          custom_title:insert(1, ico)
        else
          ico = pandoc.RawInline("html", "")
        end


        if custom.collapse ~= nil then
          collapse = custom.collapse
        else
          collapse = nil
        end

        -- quarto.log.debug(ico)
        -- quarto.log.debug(custom_title)
        callout = quarto.Callout({
          content = { el },
          -- title=pandoc.Inlines(ico, custom_title),
          title = custom_title,
          type = custom_suffix,
          collapse = collapse,
          icon = false
        })

        -- add Word styles
        if quarto.doc.is_format('docx') then
          stylename = custom_suffix:gsub("^%l", string.upper)
          if callout.attributes == nil then
            callout.attributes = { ["custom-style"] = stylename }
          else
            callout.attributes["custom-style"] = stylename
          end
        end
        -- quarto.log.debug(callout)
        return callout
      end
    end
  end

end

local function tst(m)
  custom_scss = pandoc.Inlines(pandoc.Str("custom-callouts.scss"))
  if m.theme==nil then
    m.theme = custom_scss
  -- else
  --   m.theme:insert(pandoc.Str("custom-callouts.scss"))
  end

  quarto.log.debug(sheets)
  
  for index, value in ipairs(sheets) do
    -- quarto.log.debug(value.path)
    if value.path~="custom-callouts.scss" then
      m.theme:insert(pandoc.Str(value.path))
    end
  end
  
  quarto.log.debug(m.theme)

  quarto.doc.add_html_dependency({
    name = 'custom-callouts',
    version = '0.0.0',
    stylesheets = sheets
  })

  return m
end

return {
  { ensure_html_deps() },
  { Meta = Meta },
  { Div = Div },
  {Meta=tst}
}
