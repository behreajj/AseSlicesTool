local packetFormat <const> = table.concat({
    "{\"frame\":%d",
    "\"id\":%d",
    "\"path\":\"%s\"}"
}, ",")

local sliceFormat <const> = table.concat({
    "{\"name\":\"%s\"",
    "\"color\":%s",
    "\"data\":\"%s\"",
    "\"bounds\":%s",
    "\"center\":%s",
    "\"pivot\":%s",
    "\"properties\":{%s}}",
}, ",")

local jsonFormat <const> = table.concat({
    "{\"files\":[%s]",
    "\"slices\":[%s]",
    "\"apiVersion\":%d",
    "\"frameBaseIndex\":%d",
    "\"padding\":%d",
    "\"scale\":%d",
    "\"space\":{\"bounds\":\"%s\",\"center\":\"%s\",\"pivot\":\"%s\"}",
    "\"version\":%s}",
}, ",")

local versionFormat <const> = table.concat({
    "{\"major\":%d",
    "\"minor\":%d",
    "\"patch\":%d",
    "\"prerelease\":\"%s\"",
    "\"prNo\":%d}",
}, ",")

---@param r integer
---@param g integer
---@param b integer
---@param a integer
---@return string
local function colorToJson(r, g, b, a)
    return string.format(
        "{\"r\":%d, \"g\":%d, \"b\":%d, \"a\":%d}",
        r, g, b, a)
end

---@param x integer
---@param y integer
---@return string
local function pointToJson(x, y)
    return string.format("{\"x\":%d,\"y\":%d}", x, y)
end

---@param properties table<string, any>
---@return string
local function propsToJson(properties)
    ---@type string[]
    local propStrs <const> = {}
    local strfmt <const> = string.format
    local mathtype <const> = math.type
    for k, v in pairs(properties) do
        local vStr = ""
        local typev <const> = type(v)
        if typev == "boolean" then
            vStr = v and "true" or "false"
        elseif typev == "nil" then
            vStr = "null"
        elseif typev == "number" then
            vStr = mathtype(v) == "integer"
                and strfmt("%d", v)
                or strfmt("%.6f", v)
        elseif typev == "string" then
            vStr = strfmt("\"%s\"", v)
        elseif typev == "table" then
            vStr = strfmt("{%s}", propsToJson(v))
        end

        local propStr <const> = strfmt("\"%s\":%s", k, vStr)
        propStrs[#propStrs + 1] = propStr
    end

    return table.concat(propStrs, ",")
end

---@param x integer
---@param y integer
---@param w integer
---@param h integer
---@return string
local function rectToJson(x, y, w, h)
    return string.format(
        "{\"topLeft\":%s,\"size\":%s}",
        pointToJson(x, y),
        pointToJson(w, h))
end

---@param slice Slice
---@param useGlobalBounds boolean
---@param useGlobalPivot boolean
---@param useGlobalInset boolean
---@param scale integer
---@param padding integer
local function sliceToJson(
    slice,
    useGlobalBounds, useGlobalPivot, useGlobalInset,
    scale, padding)
    local bounds <const> = slice.bounds or Rectangle(0, 0, 0, 0)
    local xtlBounds = padding
    local ytlBounds = padding
    local wBounds = bounds.w * scale
    local hBounds = bounds.h * scale

    local pivot <const> = slice.pivot or Point(0, 0)
    local xPivot = pivot.x * scale
    local yPivot = pivot.y * scale

    local inset <const> = slice.center or bounds
    local xtlInset = inset.x * scale
    local ytlInset = inset.y * scale
    local wInset = inset.w * scale
    local hInset = inset.h * scale

    if useGlobalBounds then
        xtlBounds = padding + bounds.x * scale
        ytlBounds = padding + bounds.y * scale
    end

    if useGlobalPivot then
        xPivot = xtlBounds + xPivot
        yPivot = ytlBounds + yPivot
    end

    if useGlobalInset then
        xtlInset = xtlBounds + xtlInset
        ytlInset = ytlBounds + ytlInset
    end

    local boundsStr <const> = rectToJson(
        xtlBounds, ytlBounds, wBounds, hBounds)

    local insetStr <const> = rectToJson(
        xtlInset, ytlInset, wInset, hInset)
    local pivotStr <const> = pointToJson(xPivot, yPivot)

    local color <const> = slice.color
    local colorStr <const> = colorToJson(
        color.red, color.green, color.blue, color.alpha)

    local userDataVrf = "null"
    local userData <const> = slice.data
    if userData and #userData > 0 then
        userDataVrf = userData
    end

    local propsStr <const> = propsToJson(slice.properties)

    return string.format(
        sliceFormat,
        slice.name,
        colorStr,
        userDataVrf,
        boundsStr,
        insetStr,
        pivotStr,
        propsStr)
end

---@param version Version
---@return string
local function versionToJson(version)
    return string.format(
        versionFormat,
        version.major, version.minor, version.patch,
        version.prereleaseLabel,
        version.prereleaseNumber)
end

local dlg <const> = Dialog { title = "Export Slices" }

dlg:combobox {
    id = "target",
    label = "Target:",
    option = "ALL",
    options = { "ALL", "SELECTED" }
}

dlg:separator { id = "imageParamsSep" }

dlg:check {
    id = "indivImages",
    label = "Images:",
    text = "Split",
    selected = false,
    focus = false
}

dlg:newrow { always = false }

dlg:slider {
    id = "scale",
    label = "Scale:",
    min = 1,
    max = 10,
    value = 1
}

dlg:newrow { always = false }

dlg:slider {
    id = "padding",
    label = "Padding:",
    min = 0,
    max = 32,
    value = 0
}

dlg:separator { id = "metaParamsSep" }

dlg:combobox {
    id = "boundsSpace",
    label = "Bounds:",
    option = "GLOBAL",
    options = { "GLOBAL", "LOCAL" }
}

dlg:combobox {
    id = "insetSpace",
    label = "Inset:",
    option = "LOCAL",
    options = { "GLOBAL", "LOCAL" }
}

dlg:combobox {
    id = "pivotSpace",
    label = "Pivot:",
    option = "LOCAL",
    options = { "GLOBAL", "LOCAL" }
}

dlg:separator { id = "filePathSep" }

dlg:file {
    id = "imageFilePath",
    label = "Image:",
    filetypes = {
        "aseprite", "bmp", "flc", "fli",
        "gif", "ico", "pcc", "pcx",
        "png", "tga", "webp"
    },
    save = true,
    focus = true
}

dlg:newrow { always = false }

dlg:file {
    id = "jsonFilePath",
    label = "Meta:",
    filetypes = { "json" },
    save = true,
    focus = true
}

dlg:button {
    id = "confirm",
    text = "&OK",
    focus = true,
    onclick = function()
        local sprite <const> = app.sprite
        if not sprite then return end

        local spriteSlices <const> = sprite.slices
        local lenSpriteSlices <const> = #spriteSlices
        if lenSpriteSlices < 1 then
            app.alert {
                title = "Error",
                text = "The sprite contains no slices."
            }
            return
        end

        -- Unpack arguments.
        local args <const> = dlg.data
        local target <const> = args.target --[[@as string]]

        local indivImages <const> = args.indivImages --[[@as boolean]]
        local scale <const> = args.scale --[[@as integer]]
        local padding <const> = args.padding --[[@as integer]]

        local boundsSpace <const> = args.boundsSpace --[[@as string]]
        local insetSpace <const> = args.insetSpace --[[@as string]]
        local pivotSpace <const> = args.pivotSpace --[[@as string]]

        local jsonFilePath <const> = args.jsonFilePath --[[@as string]]
        local imageFilePath <const> = args.imageFilePath --[[@as string]]

        -- Validation for file paths and extensions.
        local fileSys <const> = app.fs
        local imagePrefix <const> = fileSys.filePathAndTitle(imageFilePath)
        local imageSuffix <const> = fileSys.fileExtension(imageFilePath)

        local spriteSpec <const> = sprite.spec
        local colorMode <const> = spriteSpec.colorMode
        local alphaIndex <const> = spriteSpec.transparentColor
        local colorSpace <const> = spriteSpec.colorSpace

        local validImageExport <const> = imageFilePath and #imageFilePath > 0
        local validMetaExport <const> = jsonFilePath and #jsonFilePath > 0
            and string.lower(fileSys.fileExtension(jsonFilePath)) == "json"

        if (not validImageExport) and (not validMetaExport) then
            app.alert {
                title = "Error",
                text = "No valid export paths."
            }
            return
        end

        if validImageExport then
            -- Because Aseprite may issue multiple warnings when individual images
            -- is selected for these combinations of images and color modes, the
            -- dialog has to pre-empt with errors of its own.
            if colorMode == ColorMode.INDEXED then
                local lcFileExt <const> = string.lower(imageSuffix)
                if lcFileExt == "webp"
                    or lcFileExt == "jpg"
                    or lcFileExt == "jpeg"
                    or lcFileExt == "tga" then
                    app.alert {
                        title = "Error",
                        text = "Indexed color not supported for jpeg, jpg, tga or webp."
                    }
                    return
                end
            elseif colorMode == ColorMode.GRAY then
                local lcFileExt <const> = string.lower(imageSuffix)
                if lcFileExt == "bmp" then
                    app.alert {
                        title = "Error",
                        text = "Grayscale not supported for bmp."
                    }
                    return
                end
            end
        end

        -- Reduce strings to booleans
        local useSelected <const> = target == "SELECTED"
        local useGlobalBounds <const> = boundsSpace == "GLOBAL"
        local useGlobalInset <const> = insetSpace == "GLOBAL"
        local useGlobalPivot <const> = pivotSpace == "GLOBAL"
        local useImageResize <const> = scale > 1
        local useImagePad <const> = padding > 0

        local trgSlices = spriteSlices
        if useSelected then
            local oldTool <const> = app.tool.id
            app.tool = "slice"

            local range <const> = app.range
            if range.sprite == sprite then
                local rangeSlices <const> = range.slices
                local lenRangeSlices <const> = #rangeSlices
                if lenRangeSlices > 0 then
                    trgSlices = rangeSlices
                end
            end

            app.tool = oldTool
        end

        -- Cache global methods used in for loops to local.
        local abs <const> = math.abs
        local max <const> = math.max
        local min <const> = math.min
        local rng <const> = math.random
        local mtype <const> = math.type
        local strfmt <const> = string.format
        local strgsub <const> = string.gsub

        math.randomseed(os.time())
        local minint64 <const> = 0x1000000000000000
        local maxint64 <const> = 0x7fffffffffffffff

        ---@type Slice[]
        local sortedSlices <const> = {}
        local lenTrgSlices <const> = #trgSlices
        app.transaction("Validate Slices", function()
            local h = 0
            while h < lenTrgSlices do
                h = h + 1
                local slice <const> = trgSlices[h]
                sortedSlices[h] = trgSlices[h]

                -- Correct id and name in first loop so you have
                -- the option to sort by name, sort by id, etc.
                local idSlice = slice.properties["id"] --[[@as integer|nil]]
                if idSlice == nil or (not (type(idSlice) == "number"
                        and mtype(idSlice) == "integer")) then
                    idSlice = rng(minint64, maxint64)
                    slice.properties["id"] = idSlice
                end

                if #slice.name <= 0 then
                    slice.name = strfmt("%16x", idSlice)
                end
            end
        end)

        table.sort(sortedSlices, function(a, b)
            return a.properties["id"] < b.properties["id"]
        end)

        local spritePalettes <const> = sprite.palettes
        local lenSpritePalettes <const> = #spritePalettes

        local spriteFrames <const> = sprite.frames
        local lenSpriteFrames <const> = #spriteFrames

        local actFrObj <const> = app.frame or spriteFrames[1]
        local actFrIdx <const> = actFrObj.frameNumber
        app.frame = sprite.frames[1]

        ---@type string[]
        local sliceStrs <const> = {}
        ---@type string[]
        local fileStrs <const> = {}

        local lenSortedSlices <const> = #sortedSlices
        local i = 0
        while i < lenSortedSlices do
            i = i + 1
            local slice <const> = sortedSlices[i]
            local idSlice <const> = slice.properties["id"] --[[@as integer]]
            local idSliceStr <const> = strfmt("%16x", idSlice)

            local sliceStr <const> = sliceToJson(slice,
                useGlobalBounds, useGlobalPivot, useGlobalInset,
                scale, padding)
            sliceStrs[#sliceStrs + 1] = sliceStr

            if indivImages then
                local sliceBounds <const> = slice.bounds
                if sliceBounds
                    and sliceBounds.width > 0
                    and sliceBounds.height > 0 then
                    local xSlice <const> = sliceBounds.x
                    local ySlice <const> = sliceBounds.y
                    local wSlice <const> = sliceBounds.width
                    local hSlice <const> = sliceBounds.height

                    local fromFrIdx = actFrIdx
                    local toFrIdx = actFrIdx

                    local sliceProps <const> = slice.properties
                    if sliceProps["fromFrame"] then
                        local fromProp <const> = sliceProps["fromFrame"] --[[@as integer]]
                        fromFrIdx = 1 + min(max(abs(fromProp), 0), lenSpriteFrames - 1)
                    end
                    if sliceProps["toFrame"] then
                        local toProp <const> = sliceProps["toFrame"] --[[@as integer]]
                        toFrIdx = 1 + min(max(abs(toProp), 0), lenSpriteFrames - 1)
                    end

                    -- Swap invalid from and to frames.
                    if toFrIdx < fromFrIdx then
                        fromFrIdx, toFrIdx = toFrIdx, fromFrIdx
                    end

                    local frameCount <const> = 1 + toFrIdx - fromFrIdx
                    local j = 0
                    while j < frameCount do
                        local frIdx <const> = fromFrIdx + j
                        j = j + 1

                        if validImageExport then
                            local palIdx = 1
                            if frIdx <= lenSpritePalettes then palIdx = frIdx end
                            local palette <const> = spritePalettes[palIdx]

                            local flatSpec <const> = ImageSpec {
                                width = wSlice,
                                height = hSlice,
                                colorMode = colorMode,
                                transparentColor = alphaIndex
                            }
                            flatSpec.colorSpace = colorSpace

                            local flat = Image(flatSpec)
                            flat:drawSprite(sprite, frIdx,
                                Point(-xSlice, -ySlice))

                            if not flat:isEmpty() then
                                if useImageResize then
                                    flat:resize {
                                        width = wSlice * scale,
                                        height = hSlice * scale
                                    }
                                end

                                if useImagePad then
                                    -- TODO: Create a separate function for this?
                                    -- Special case for background layers where
                                    -- the pad color needs to be opaque for 24 bit RGB?
                                    local padSpec <const> = ImageSpec {
                                        width = flat.width + padding * 2,
                                        height = flat.height + padding * 2,
                                        colorMode = colorMode,
                                        transparentColor = alphaIndex
                                    }
                                    padSpec.colorSpace = colorSpace
                                    local padded <const> = Image(padSpec)
                                    padded:drawImage(flat, Point(padding, padding))
                                    flat = padded
                                end

                                local sepImageFilepath = strfmt(
                                    "%s_%s_%d.%s",
                                    imagePrefix,
                                    idSliceStr,
                                    frIdx - 1,
                                    imageSuffix)
                                local escapedPath <const> = strgsub(
                                    sepImageFilepath, "\\", "\\\\")
                                local fileStr <const> = strfmt(
                                    packetFormat, frIdx - 1, idSlice, escapedPath)
                                fileStrs[#fileStrs + 1] = fileStr

                                flat:saveAs {
                                    filename = sepImageFilepath,
                                    palette = palette
                                }
                            end -- Image is not empty.
                        end     -- Image export path valid.
                    end         -- End frame loop.
                end             -- Slice bounds exists.
            end                 -- Individual images check.
        end                     -- End slices loop.

        -- Export the image even if it is empty.
        if (not indivImages) and validImageExport then
            local palIdx = 1
            if actFrIdx <= lenSpritePalettes then palIdx = actFrIdx end
            local palette <const> = spritePalettes[palIdx]

            local flat = Image(spriteSpec)
            flat:drawSprite(sprite, actFrObj, Point(0, 0))

            if useImageResize then
                flat:resize {
                    width = spriteSpec.width * scale,
                    height = spriteSpec.height * scale
                }
            end

            if useImagePad then
                local padSpec <const> = ImageSpec {
                    width = flat.width + padding * 2,
                    height = flat.height + padding * 2,
                    colorMode = colorMode,
                    transparentColor = alphaIndex
                }
                padSpec.colorSpace = colorSpace
                local padded <const> = Image(padSpec)
                padded:drawImage(flat, Point(padding, padding))
                flat = padded
            end

            local escapedPath <const> = string.gsub(
                imageFilePath, "\\", "\\\\")
            local packetStr <const> = string.format(
                packetFormat, actFrIdx - 1, -1, escapedPath)
            fileStrs[#fileStrs + 1] = packetStr

            flat:saveAs {
                filename = imageFilePath,
                palette = palette
            }
        end

        if validMetaExport then
            local version <const> = app.version
            local apiVersion <const> = app.apiVersion
            local versionStr <const> = versionToJson(version)

            local frBaseIdx = 1
            local appPrefs <const> = app.preferences
            if appPrefs then
                local docPrefs <const> = appPrefs.document(sprite)
                if docPrefs then
                    local tlPrefs <const> = docPrefs.timeline
                    if tlPrefs then
                        if tlPrefs.first_frame then
                            frBaseIdx = tlPrefs.first_frame --[[@as integer]]
                        end
                    end
                end
            end

            local jsonStr <const> = string.format(
                jsonFormat,
                table.concat(fileStrs, ","),
                table.concat(sliceStrs, ","),
                apiVersion,
                frBaseIdx,
                padding,
                scale,
                useGlobalBounds and "global" or "local",
                useGlobalInset and "global" or "local",
                useGlobalPivot and "global" or "local",
                versionStr)

            local file <const>, err <const> = io.open(jsonFilePath, "w")
            if file then
                file:write(jsonStr)
                file:close()
            end

            if err then
                app.frame = actFrObj
                app.refresh()
                app.alert { title = "Error", text = err }
                return
            end
        end

        app.frame = actFrObj
        app.refresh()
        app.alert { title = "Success", text = "Slice data exported." }
    end
}

dlg:button {
    id = "cancel",
    text = "&CANCEL",
    focus = false,
    onclick = function()
        dlg:close()
    end
}

dlg:show {
    autoscrollbars = true,
    wait = false
}