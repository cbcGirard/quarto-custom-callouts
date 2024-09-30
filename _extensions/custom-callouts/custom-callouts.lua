local custom_callouts = nil
local callout_scss = nil

--- scss stylesheets
local sheets = {}


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

--- Get name of file, without extension or path.
--- @param path string
--- @return string
local function get_filename(path)
  local parts = pandoc.path.split(path)
  local filename = parts[#parts]
  return filename:match("(.+)%..+")
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
    -- heading and border SCSS rules
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
  return css
end

function Meta(meta)
  if meta.custom_callouts ~= nil then
    quarto.log.info("Found custom callouts")
    custom_callouts = meta.custom_callouts
    callout_scss = meta.callout_scss
    doc_path = quarto.doc.input_file

    if quarto.doc.is_format("html:js") then
      css = make_css(custom_callouts)
      quarto.log.info("base css:\n" .. css)
      
      if meta.theme ~= nil then
        theme = pandoc.utils.stringify(meta.theme)
        if theme:sub(-5) ~= ".scss" then
          theme = theme .. ".scss"
        end
        dep_path = find_local_dep(theme)

        -- add to dependencies
        table.insert(sheets, {
          path = dep_path,
          attribs = {
            type = "text/css",
          }
        })
        css = "@import './" .. theme .. "';\n\n" .. css
      end

      if callout_scss ~= nil then
        for i, sheet in ipairs(callout_scss) do
          sheetname = pandoc.utils.stringify(sheet)
          dep_path = find_local_dep(sheetname)

          -- add to dependencies
          table.insert(sheets, {
            path = dep_path,
            attribs = {
              type = "text/css",
            }
          })
          css = "@import './" .. sheetname .. "';\n\n" .. css
        end
      end

      outname = get_filename(doc_path) .. "-callouts.scss"
      path = quarto.utils.resolve_path(outname)

      quarto.log.info("Writing custom callouts to " .. path)
      io.open(path, "w"):write(css):close()

      table.insert(sheets, {
        path = path,
        attribs = {
          type = "text/css",
        }
      })

      quarto.log.info("Adding custom callouts to dependencies")
      quarto.log.info(sheets)

      quarto.doc.add_html_dependency({
        name = outname,
        version = '0.0.0',
        stylesheets = sheets
      })
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
        attribs = {
          type = "module",
        }
      }
    }
  })
end

function Div(el)
  if custom_callouts ~= nil then
    for i, custom in ipairs(custom_callouts) do
      custom_suffix = pandoc.utils.stringify(custom.name)
      custom_class = "callout-" .. custom_suffix
      if (el.classes:includes(custom_class)) then
        if custom.heading then
          custom_title = custom.heading:walk{}
        else
          custom_title = custom.name:walk{}
        end

        if custom.icon ~= nil then
          attr = ""
          if custom.attr ~= nil then
            for key, value in pairs(custom.attr) do
              attr = attr .. " " .. key .. "='" .. pandoc.utils.stringify(value) .. "'"
            end
          end

          ico = pandoc.RawInline("html", "<iconify-icon inline icon='" ..
            pandoc.utils.stringify(custom.icon) .. "'" .. attr .. "></iconify-icon>&nbsp;")

          custom_title:insert(1, ico)
          quarto.log.info(custom_title)
        else
          ico = pandoc.RawInline("html", "")
        end


        if custom.collapse ~= nil then
          collapse = custom.collapse
        else
          collapse = nil
        end

        callout = quarto.Callout({
          content = { el },
          title = custom_title,
          type = custom_suffix,
          collapse = collapse,
          icon = ""
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
        return callout
      end
    end
  end

end


return {
  { ensure_html_deps() },
  { Meta = Meta },
  { Div = Div },
}
