-- for-font.lua
-- Copyright (C) 2023  Silver Burla
--
-- This file is released under the terms of the MIT license.
--
-- Export a fontsheet.
-- Requires supplied element spacing, uniform element width and height, and dictionary.
-- Requires a single layer where all characters, numbers, and symbols are drawn.
-- Generates accompanying JSON font atlas structured for indexing by character.
-- * MAX 10 ROWS OF FONT ELEMENTS IN IMAGE

---------------------------------------------------------

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
	if layer.isVisible and layer.isImage and #layer.cels == 1 then
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

local current   = { layers       = valid_layer_names,
					layer        = valid_layer_names[2],
					max_rows	 = 10,
					rows		 = 3 }

local dlg 		= Dialog { title = "Export Fontsheet" }

---------------------------------------------------------[ HELPER FUNCTIONS ]

function write_json_data(filepath, data)
	local file = io.open(filepath, "w")
	file:write(json.encode(data))
	file:close()
end

function validate_text(widget)
	local text = dlg.data[widget];
	if text == nil or text == "" then
		return
	end
	
	dlg:modify {
		id = widget,
		text = string.gsub(text, "%s+", "")
	}
end

function generate_dictionary_entries()
	for i = 1, 10 do
		local widget = "txt-dictionary-" .. i 
		dlg:entry { 
			id        	= widget,
			label 	  	= "row " .. i .. ":",
			text      	= "",
			visible   	= i <= 3,	
			onchange  	= function() validate_text(widget) end
		}
		dlg:newrow()
	end
	dlg:modify {
		id = "txt-dictionary-1",
		text = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
	}
	dlg:modify {
		id = "txt-dictionary-2",
		text = "abcdefghijklmnopqrstuvwxyz"
	}
	dlg:modify {
		id = "txt-dictionary-3",
		text = "0123456789.,:'+-=_[]()~!?$"
	}
end

function toggle_dictionary_entries(change)
	local new_rows = math.min(math.max(current.rows + change, 1), 10)
	local shift = current.rows - new_rows

	if shift == -1 then
		dlg:modify { 
			id = "txt-dictionary-" .. new_rows,
			visible = true
		}
		current.rows = new_rows
	elseif shift == 1 then
		dlg:modify { 
			id = "txt-dictionary-" .. current.rows,
			text = "",
			visible = false
		}
		current.rows = new_rows
	end
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
		trim            = false,
		trimByGrid      = false,
		extrude         = false,
		ignoreEmpty     = true,
		mergeDuplicates = false,
		openGenerated   = false,
		layer           = current.layer,
		tag             = "",
		splitLayers     = false,
		splitTags       = false,
		splitGrid       = false,
		listLayers      = false,
		listTags        = false,
		listSlices      = false,
		fromTilesets    = false 
	}
end

function export_layer()
	local data  = {}
	local atlas = {}

	for i = 1, current.rows do
		local entry = dlg.data["txt-dictionary-" .. i]
		if entry == nil or entry == "" then
			print "JSON export aborted, please check dictionary for empty rows"
			return
		end
		atlas[i] = entry
	end

	local width  = dlg.data["num-width"]
	local height = dlg.data["num-height"]
	local hspace = dlg.data["num-hspace"]
	local vspace = dlg.data["num-vspace"]

	if width == nil or width <= 0 or height == nil or height <= 0 or 
			hspace == nil or hspace <= 0 or vspace == nil or vspace <= 0 then
		print "JSON export aborted, please check dimensions and spacing for zeros and negative numbers."
		return
	end

	for row = 1, #atlas do
		for col = 1, #atlas[row] do
			local char = atlas[row]:sub(col, col)
			data[char] = {
				texture = {
					u = ((col - 1) * width) + (col * hspace),
					v = ((row - 1) * height) + (row * vspace),
					w = width,
					h = height 
				}
			}
		end
	end

	return data
end

function export_json(filepath)
	local data = export_layer()
	if data == nil then
		return
	end
	local file = io.open(filepath, "w")
	file:write(json.encode(data))
	file:close()
end

---------------------------------------------------------[ MAIN FUNCTIONS ]

function export()
	local filepath = fs.joinPath(file.directory, file.name)
	export_spritesheet(filepath .. ".png")
	export_json(filepath .. ".json")
	dlg:close()
end

---------------------------------------------------------[ GUI ]

dlg:separator { 
    id          = "sep-layer",
    text        = "select layer"
}

dlg:combobox { 
	id        	= "cbox-layers",
	label 		= "font",
	option    	= current.layer,
	options   	= current.layers,
	onchange  	= function() current.layer = dlg.data["cbox-layers"] end
}

dlg:separator { 
    id          = "sep-dimensions",
    text        = "element dimensions"
}

dlg:number { 
	id        	= "num-width",
	label     	= "width:",
	text 		= "8",
	decimals  	= 0
}

dlg:number { 
	id        	= "num-height",
	label     	= "height:",
	text 		= "10",
	decimals  	= 0
}

dlg:separator { 
    id          = "sep-spacing",
    text        = "element spacing"
}

dlg:number { 
	id        = "num-vspace",
	label     = "vertical:",
	text 	  = "1",
	decimals  = 0
}

dlg:number { 
	id        = "num-hspace",
	label     = "horizontal:",
	text 	  = "1",
	decimals  = 0
}

dlg:separator { 
    id          = "sep-dictionary",
    text        = "font dictionary"
}

dlg:button {
	id      = "btn-increase-dictionary",
	text    = "+",
	onclick = function() toggle_dictionary_entries(1) end
}

dlg:button {
	id      = "btn-decrease-dictionary",
	text    = "-",
	onclick = function() toggle_dictionary_entries(-1) end
}

generate_dictionary_entries()

dlg:separator { 
    id          = "sep-export",
    text        = "export"
}

dlg:entry { 
    id          = "txt-fdir",
	label 		= "directory:",
    text        = file.directory,
    onchange    = function() file.directory = dlg.data["txt-fdir"] end
}

dlg:newrow()

dlg:entry { 
    id          = "txt-fname",
	label 		= "filename:",
    text        = file.name,
    onchange    = function() file.name = dlg.data["txt-fname"] end 
}

dlg:button {
	id      = "export",
	text    = "Export",
	onclick = function() export() end
}

dlg:button {
	id      = "cancel",
	text    = "Cancel",
	onclick = function() dlg:close() end
}

dlg:show { wait = false }