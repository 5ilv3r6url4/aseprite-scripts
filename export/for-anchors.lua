-- for-anchors.lua
-- Copyright (C) 2023  Silver Burla
--
-- This file is released under the terms of the MIT license.
--
-- Save and edit cel anchor points for single frame icons separated by layer.
-- Export a single png with size-optimal packing options.
-- Export an accompanying texture atlas JSON.

---------------------------------------------------------[ INIT CHECKS ]

local spr = app.sprite

if not spr then
    return print "No active sprite." 
end

if spr.colorMode ~= ColorMode.RGB and spr.colorMode ~= ColorMode.GRAY then
    return print "Sprite must be in RGBA or grayscale Color Mode." 
end

local valid_layers = {}
local valid_layer_names = {}

for _, layer in ipairs(spr.layers) do
    if layer.isVisible and layer.isImage and #layer.cels >= 1 then
        valid_layers[layer.name] = layer
        table.insert(valid_layer_names, layer.name)
    end
end

if #valid_layer_names == 0 then
    return print "No valid layers."
end

---------------------------------------------------------[ EXTERNAL SCRIPTS ]

local json = dofile("../ext/json.lua")

---------------------------------------------------------[ GLOBAL VARIABLES ]

local fs        = app.fs

local file      = { directory    = fs.filePath(spr.filename),
                    name         = fs.fileTitle(spr.filename) }

local current   = { layers       = valid_layers,
                    names        = valid_layer_names,
                    layer        = valid_layers[valid_layer_names[1]],
                    cel          = valid_layers[valid_layer_names[1]].cels[1] }

local canvas    = Size(160, 160) 

local position  = { screen       = Point(-1, -1), 
                    canvas       = Point(-1, -1) }

local transform = { translate    = Point(0, 0),
                    zoom         = math.min(math.floor(canvas.w / spr.width), 
                                            math.floor(canvas.h / spr.height)) }

local bounds    = { canvas       = Rectangle(0, 0, canvas.w, canvas.h), 
                    sprite       = Rectangle(0, 0, spr.width, spr.height),
                    transform    = Rectangle(0, 0, spr.width * transform.zoom, spr.height * transform.zoom) }

local colors    = { black        = Color{ r = 0,   g = 0,   b = 0   },
                    white        = Color{ r = 255, g = 255, b = 255 },
                    cursor       = Color{ r = 235, g = 64,  b = 52  },
                    anchor       = Color{ r = 141, g = 219, b = 72  },
                    uint_gray    = app.pixelColor.rgba(191, 191, 191) }

local dlg       = Dialog { title = "Export Animation" }

---------------------------------------------------------[ HELPER FUNCTIONS ]

function update_sep_current()
    dlg:modify {
        id      = "sep-current",
        text    = current.layer.name .. ": frame " .. current.cel.frameNumber
    }
end

function goto_cel(frame_number)
    local bounded_number = math.min(math.max(frame_number, 1), #current.layer.cels)
    current.cel = current.layer.cels[bounded_number]
    update_sep_current()
    dlg:repaint()
end

function goto_layer(layer_name)
    current.layer = current.layers[layer_name]
    current.cel = current.layer.cels[1]
    update_sep_current()
    dlg:repaint()
end

function generate_anchor_chk()
    for name, layer in pairs(current.layers) do
        local status = "C: " .. name
        for _, cel in ipairs(layer.cels) do
            if cel.properties.anchor_point == nil then
                status = "IN: " .. name 
                break
            end
        end

        dlg:label {
            id      = "anchor-chk-" .. string.gsub(name, "%s", "-"),
            text    = status
        }
        dlg:newrow()
    end
end

function update_anchor_chk(layer)
    local new_status = "C: " .. layer.name
    for _, cel in ipairs(layer.cels) do
        if cel.properties.anchor_point == nil then
            new_status = "IN: " .. layer.name 
            break
        end
    end

    dlg:modify {
        id      = "anchor-chk-" .. string.gsub(layer.name, "%s", "-"),
        text    = new_status
    }
end

function verify_anchor_chk()
    for name, layer in pairs(current.layers) do
        for _, cel in ipairs(layer.cels) do
            if cel.properties.anchor_point == nil then
                return false
            end
        end
    end
    return true
end

function clear_anchor_points() 
    for _, layer in pairs(current.layers) do
        for _, cel in ipairs(layer.cels) do
            cel.properties = {}
        end
        update_anchor_chk(layer)
    end
end

function reset_transform()
    transform.translate = Point()
    transform.zoom = math.min(math.floor(bounds.canvas.w / bounds.sprite.w), 
                              math.floor(bounds.canvas.h / bounds.sprite.h))
    bounds.transform.origin = Point(transform.translate.x, transform.translate.y)
    bounds.transform.size = Size(bounds.sprite.w * transform.zoom, bounds.sprite.h * transform.zoom)
end

function export_spritesheet(filepath)
    app.command.ExportSpriteSheet {
        ui              = false,
        askOverwrite    = false,
        type            = SpriteSheetType.ROWS,
        columns         = 0,
        rows            = 0,
        width           = 0,
        height          = 0,
        bestFit         = false,
        textureFilename = filepath,
        dataFilename    = "",
        dataFormat      = SpriteSheetDataFormat.JSON_ARRAY,
        filenameFormat  = "{layer}--{frame}",
        borderPadding   = 0,
        shapePadding    = 0,
        innerPadding    = 0,
        trimSprite      = false,
        trim            = true,
        trimByGrid      = false,
        extrude         = false,
        ignoreEmpty     = true,
        mergeDuplicates = false,
        openGenerated   = false,
        layer           = "",
        tag             = "",
        splitLayers     = true,
        splitTags       = false,
        splitGrid       = false,
        listLayers      = false,
        listTags        = false,
        listSlices      = false,
        fromTilesets    = false 
    }
end

function export_cel(cel, voff)
    local data = {
        texture = {
            u = 0,
            v = voff,
            w = cel.bounds.width,
            h = cel.bounds.height
        },
        anchor = {
            x = cel.properties.anchor_point.x - cel.bounds.x,
            y = cel.properties.anchor_point.y - cel.bounds.y
        },
    }
    return data
  end

function export_cels(layer, voff)
	local data = { data = {}, height = 0 }
	for _, cel in ipairs(layer.cels) do
		data.data = export_cel(cel, voff)
		if data.height < cel.bounds.height then 
			data.height = cel.bounds.height
		end
	end
	return data
end

function export_layers()
    local data = {}
    local voff = 0
	for _, name in ipairs(current.names) do
		local cels = export_cels(current.layers[name], voff)
        data[name] = cels.data 
        voff = voff + cels.height
    end
    return data
end

function export_json(filepath)
    if verify_anchor_chk() == false then
        return false
    end

    local data = export_layers()
    local file = io.open(filepath, "w")
    file:write(json.encode(data))
    file:close()
    return true
end

---------------------------------------------------------[ EVENT HANDLERS ]

function on_canvas_mousemove(ev)
    -- hold mouse wheel down and move mouse to pan canvas
    if ev.button == MouseButton.MIDDLE then
        transform.translate = Point(transform.translate.x + ev.x - position.screen.x,
                                    transform.translate.y + ev.y - position.screen.y)
        bounds.transform.origin = Point(transform.translate.x, transform.translate.y)
    end

    position.screen = Point(ev.x, ev.y)
    position.canvas = Point(math.floor((ev.x - transform.translate.x) / transform.zoom), 
                            math.floor((ev.y - transform.translate.y) / transform.zoom))
    dlg:repaint()
end

function on_canvas_mouseup(ev)
    -- right click to delete anchor point of current cel
    if ev.button == MouseButton.RIGHT then
        current.cel.properties = {}
        update_anchor_chk(current.layer)
        dlg:repaint()
    -- left click to set anchor point of current cel
    elseif ev.button == MouseButton.LEFT then
        local selection = Selection(bounds.transform)
        if selection:contains(position.screen) then
            current.cel.properties = { 
                anchor_point = { 
                    x = position.canvas.x, 
                    y = position.canvas.y
                }
            }
            update_anchor_chk(current.layer)
            dlg:repaint()
        end
    end
end

function on_canvas_dblclick(ev)
    -- double click mouse wheel to reset canvas
    if ev.button == MouseButton.MIDDLE then
        reset_transform()
        dlg:repaint()
    end
end

function on_canvas_wheel(ev)
    -- scroll mouse wheel to change zoom level
    if ev.button == MouseButton.NONE then
        transform.zoom = math.min(math.max(transform.zoom - ev.deltaY, 1), 16)
        bounds.transform.size = Size(bounds.sprite.w * transform.zoom, bounds.sprite.h * transform.zoom)
        dlg:repaint()
    end
end

---------------------------------------------------------[ MAIN FUNCTIONS ]

function draw(context) 
    local img = Image(bounds.sprite.w, bounds.sprite.h)

    for pixel in img:pixels() do
        pixel(colors.uint_gray)
    end

    img:drawImage(current.cel.image, Point(current.cel.bounds.x, current.cel.bounds.y))
    img:drawPixel(position.canvas.x, position.canvas.y, colors.cursor)
    
    if current.cel.properties.anchor_point ~= nil then
        local anchor_point = current.cel.properties.anchor_point
        img:drawPixel(anchor_point.x, anchor_point.y, colors.anchor)
    end
    
    context.color = colors.white
    context:fillRect(bounds.canvas)
    
    context:drawImage(img, bounds.sprite, bounds.transform)
    
    context.color = colors.black
    context:strokeRect(bounds.canvas)
end

function export()
    if file.directory == nil or file.directory == "" or file.name == nil or file.name == "" then
        return print "missing file name or file directory path."
    end

    local filepath = fs.joinPath(file.directory, file.name)

    if dlg.data["chk-spritesheet"] == true then
        export_spritesheet(filepath .. ".png")
    end

    if dlg.data["chk-json"] == true then
        if export_json(filepath .. ".json") == false then
            return print "JSON export aborted, layer exists with missing anchor points."
        end
    end

    dlg:close()
end

---------------------------------------------------------[ GUI ]

dlg:separator { 
    id          = "sep-current",
    text        = current.layer.name .. ": frame " .. current.cel.frameNumber
}

dlg:canvas {
    id          = "canvas",
    width       = bounds.canvas.w,
    height      = bounds.canvas.h,
    hexpand     = false,
    vexpand     = false,
    onpaint     = function(ev) draw(ev.context) end,
    onmousemove = function(ev) on_canvas_mousemove(ev) end,
    onmouseup   = function(ev) on_canvas_mouseup(ev) end,
    ondblclick  = function(ev) on_canvas_dblclick(ev) end,
    onwheel     = function(ev) on_canvas_wheel(ev) end
}

dlg:separator { 
    id          = "sep-navigation",
    text        = "navigation controls" 
}

dlg:combobox { 
    id          = "cbox-layers",
    option      = current.layer.name,
    options     = current.names,
    hexpand     = true,
    onchange    = function() goto_layer(dlg.data["cbox-layers"]) end
}

dlg:button {
    id          = "btn-first-cel",
    text        = "<<",
    hexpand     = false,
    onclick     = function() goto_cel(1) end
}

dlg:button {
    id          = "btn-prev-cel",
    text        = "<",
    hexpand     = false,
    onclick     = function() goto_cel(current.cel.frameNumber - 1) end
}

dlg:button {
    id          = "btn-next-cel",
    text        = ">",
    hexpand     = false,
    onclick     = function() goto_cel(current.cel.frameNumber + 1) end
}

dlg:button {
    id          = "btn-last-cel",
    text        = ">>",
    hexpand     = false,
    onclick     = function() goto_cel(#current.layer.cels) end
}

dlg:separator { 
    id          = "sep-anchor-points",
    text        = "anchor points" 
}

dlg:newrow()

generate_anchor_chk()

dlg:button {
    id          = "btn-clear",
    text        = "Clear",
    onclick     = function() clear_anchor_points() end
}

dlg:button {
    id          = "btn-save",
    text        = "Save",
    onclick     = function() app.command.SaveFile{} end
}

dlg:separator { 
    id          = "sep-export",
    text        = "export" 
}

dlg:entry { 
    id          = "txt-fdir",
    text        = file.directory,
    onchange    = function() file.directory = dlg.data["txt-fdir"] end
}

dlg:newrow()

dlg:entry { 
    id          = "txt-fname",
    text        = file.name,
    onchange    = function() file.name = dlg.data["txt-fname"] end 
}

dlg:check { 
    id          = "chk-spritesheet",
    text        = "spritesheet",
    selected    = true
}

dlg:check { 
    id          = "chk-json",
    text        = "json",
    selected    = true
}

dlg:button {
    id          = "btn-cancel",
    text        = "Cancel",
    onclick     = function() dlg:close() end
}

dlg:button {
    id          = "btn-export",
    text        = "Export",
    onclick     = function() export() end
}

dlg:show { wait = false }