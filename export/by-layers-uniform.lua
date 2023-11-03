-- by-layers-uniform.lua
-- Copyright (C) 2023  Silver Burla
--
-- This file is released under the terms of the MIT license.
--
-- Minimal spritesheet export by layers for uniform cel dimensions.
-- Export a single png with uniform-size packing options.
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
                    names        = valid_layer_names }

---------------------------------------------------------[ HELPER FUNCTIONS ]

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
		trim            = false,
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

function export_cel(row, col, cel)
  	local data = {
		texture = {
			u = col * spr.width,
			v = row * spr.height,
			w = spr.width,
			h = spr.height
		}
  	}
  	return data
end

function export_cels(row, layer)
	local data = {}
	local col = 0
	for i, cel in ipairs(layer.cels) do
		data[i] = export_cel(row, col, cel)
		col = col + 1
	end
	return data
end

function export_layers()
	local data = {}
	local row = 0
	for _, name in ipairs(current.names) do
		data[name] = export_cels(row, current.layers[name])
		row = row + 1
	end
	return data
end

function export_json(filepath)
    local data = export_layers()
    local file = io.open(filepath, "w")
    file:write(json.encode(data))
    file:close()
end

---------------------------------------------------------[ MAIN FUNCTIONS ]

function export()
	local filepath = fs.joinPath(file.directory, file.name)
	export_spritesheet(filepath .. ".png")
	export_json(filepath .. ".json")
end

---------------------------------------------------------[ START ]

export()
