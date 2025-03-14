--[[Slices have an internal reference to the frame on which they were
    created. This reference cannot be accessed via Lua script.
]]

-- TODO: Option to import slices to a sprite where each slice is a new frame?

local pivotOptions <const> = {
    "TOP_LEFT",
    "TOP_CENTER",
    "TOP_RIGHT",

    "CENTER_LEFT",
    "CENTER",
    "CENTER_RIGHT",

    "BOTTOM_LEFT",
    "BOTTOM_CENTER",
    "BOTTOM_RIGHT",
}

local defaults <const> = {
    showSelectButtons = true,
    showFocusButtons = false,
    showEditButtons = true,
    showConvertButtons = true,
    showNudgeButtons = true,
    showSizeButtons = true,
    showInsetButtons = true,
    showPivotButtons = true,
    showRecolorButtons = true,
    showRenameButtons = true,

    showNudgeChecks = true,
    useColorInvert = true,
    enableCopyWarning = false,
    nudgeStep = 1,
    wSliceMin = 3,
hSliceMin = 3,
}

---@param layer Layer
---@param array Layer[]
---@return Layer[]
local function appendLeaves(layer, array)
    if layer.isVisible then
        if layer.isGroup then
            -- Type annotation causes Github syntax highlighting problems.
            local childLayers <const> = layer.layers
            if childLayers then
                local lenChildLayers <const> = #childLayers
                local i = 0
                while i < lenChildLayers do
                    i = i + 1
                    appendLeaves(childLayers[i], array)
                end
            end
        elseif (not layer.isReference) then
            array[#array + 1] = layer
        end
    end
    return array
end

---@param orig number
---@param dest number
---@param t number
---@param range number
---@return number
local function lerpAngleCcw(orig, dest, t, range)
    local rangeVerif <const> = range or 360.0
    local o <const> = orig % rangeVerif
    local d <const> = dest % rangeVerif
    local diff <const> = d - o
    if diff == 0.0 then return o end

    local u <const> = 1.0 - t
    if o > d then
        return (u * o + t * (d + rangeVerif)) % rangeVerif
    else
        return u * o + t * d
    end
end

---@param pivotPreset string
---@param w integer
---@param h integer
---@return Point
local function pivotFromPreset(pivotPreset, w, h)
    if pivotPreset == "TOP_LEFT" then
        return Point(0, 0)
    elseif pivotPreset == "TOP_CENTER" then
        return Point(w // 2, 0)
    elseif pivotPreset == "TOP_RIGHT" then
        return Point(w - 1, 0)
    elseif pivotPreset == "CENTER_LEFT" then
        return Point(0, h // 2)
    elseif pivotPreset == "CENTER" then
        return Point(w // 2, h // 2)
    elseif pivotPreset == "CENTER_RIGHT" then
        return Point(w - 1, h // 2)
    elseif pivotPreset == "BOTTOM_LEFT" then
        return Point(0, h - 1)
    elseif pivotPreset == "BOTTOM_CENTER" then
        return Point(w // 2, h - 1)
    elseif pivotPreset == "BOTTOM_RIGHT" then
        return Point(w - 1, h - 1)
    else
        return Point(w // 2, h // 2)
    end
end

---@param x number
---@return integer
local function round(x)
    local ix <const>, fx <const> = math.modf(x)
    if ix <= 0 and fx <= -0.5 then
        return ix - 1
    elseif ix >= 0 and fx >= 0.5 then
        return ix + 1
    end
    return ix
end

---@param left Slice
---@param right Slice
---@return boolean
local function tlComparator(left, right)
    local aBounds <const> = left.bounds
    local bBounds <const> = right.bounds
    if aBounds and bBounds then
        local ay <const> = aBounds.y
        local by <const> = bBounds.y
        if ay == by then
            local ax <const> = aBounds.x
            local bx <const> = bBounds.x
            if ax == bx then
                return left.name < right.name
            end
            return ax < bx
        end
        return ay < by
    end
    return left.name < right.name
end

---@param step integer
local function changeActiveSlice(step)
    local sprite <const> = app.sprite
    if not sprite then return end

    local oldTool <const> = app.tool.id
    app.tool = "slice"

    local range <const> = app.range
    if range.sprite ~= sprite then
        app.tool = oldTool
        return
    end

    local spriteSlices <const> = sprite.slices
    local lenSpriteSlices <const> = #spriteSlices
    if lenSpriteSlices < 1 then
        app.tool = oldTool
        return
    end

    local actFrObj <const> = app.frame or sprite.frames[1]
    app.frame = sprite.frames[1]

    local rng <const> = math.random
    local mtype <const> = math.type
    math.randomseed(os.time())
    local minint64 <const> = 0x1000000000000000
    local maxint64 <const> = 0x7fffffffffffffff

    ---@type Slice[]
    local sortedSpriteSlices <const> = {}
    app.transaction("Check Slice IDs", function()
        local i = 0
        while i < lenSpriteSlices do
            i = i + 1
            local slice <const> = spriteSlices[i]

            local idSlice = slice.properties["id"] --[[@as integer|nil]]
            if idSlice == nil or (not (type(idSlice) == "number"
                    and mtype(idSlice) == "integer")) then
                idSlice = rng(minint64, maxint64)
                slice.properties["id"] = idSlice
            end

            sortedSpriteSlices[i] = slice
        end
    end)
    table.sort(sortedSpriteSlices, tlComparator)

    ---@type table<string, integer>
    local idToIndex <const> = {}
    local j = 0
    while j < lenSpriteSlices do
        j = j + 1
        local slice <const> = sortedSpriteSlices[j]
        local idSlice <const> = slice.properties["id"] --[[@as integer]]
        idToIndex[idSlice] = j
    end

    local activeSlice = sortedSpriteSlices[1]
    local rangeSlices <const> = range.slices
    local lenRangeSlices <const> = #rangeSlices
    if lenRangeSlices > 1 then
        ---@type Slice[]
        local sortedRangeSlices <const> = {}
        local k = 0
        while k < lenRangeSlices do
            k = k + 1
            sortedRangeSlices[k] = rangeSlices[k]
        end
        table.sort(sortedRangeSlices, tlComparator)
        activeSlice = sortedRangeSlices[1]
    elseif lenRangeSlices == 1 then
        activeSlice = rangeSlices[1]
    end

    local changeSlice = activeSlice
    local idActive <const> = activeSlice.properties["id"] --[[@as integer]]
    if idActive then
        local indexActive <const> = idToIndex[idActive]
        if indexActive then
            local indexChange <const> = 1 + (step + indexActive - 1)
                % lenSpriteSlices
            changeSlice = sortedSpriteSlices[indexChange]
        end
    end

    range.slices = { changeSlice }

    local toFrIdx <const> = changeSlice.properties["toFrame"] --[[@as integer|nil]]
    if toFrIdx then
        app.frame = sprite.frames[1 + toFrIdx]
    else
        app.frame = actFrObj
    end
    app.tool = oldTool
    app.refresh()
end

---@param dx integer
---@param dy integer
---@param moveBounds boolean
---@param movePivot boolean
---@param moveInset boolean
---@param pivotCombo string
---@param insetAmount integer
local function translateSlices(
    dx, dy,
    moveBounds, movePivot, moveInset,
    pivotCombo, insetAmount)
    local sprite <const> = app.sprite
    if not sprite then return end

    local oldTool <const> = app.tool.id
    app.tool = "slice"

    local range <const> = app.range
    if range.sprite ~= sprite then
        app.tool = oldTool
        return
    end

    local slices <const> = range.slices
    local lenSlices <const> = #slices
    if lenSlices < 1 then
        app.tool = oldTool
        return
    end

    local abs <const> = math.abs
    local max <const> = math.max

    local actFrObj <const> = app.frame or sprite.frames[1]
    app.frame = sprite.frames[1]

    if moveBounds then
        local dxNonZero <const> = dx ~= 0
        local dyNonZero <const> = dy ~= 0
        local wSprite <const> = sprite.width
        local hSprite <const> = sprite.height

        local xGrOff = 0
        local yGrOff = 0
        local xGrScl = 1
        local yGrScl = 1

        local appPrefs <const> = app.preferences
        if appPrefs then
            local docPrefs <const> = appPrefs.document(sprite)
            if docPrefs then
                local gridPrefs <const> = docPrefs.grid
                if gridPrefs then
                    local useSnap <const> = gridPrefs.snap --[[@as boolean]]
                    if useSnap then
                        local grid <const> = sprite.gridBounds
                        xGrOff = grid.x
                        yGrOff = grid.y
                        xGrScl = math.max(1, math.abs(grid.width))
                        yGrScl = math.max(1, math.abs(grid.height))
                    end
                end
            end
        end

        local trsName <const> = string.format("Nudge Slices (%d, %d)", dx, dy)
        app.transaction(trsName, function()
            local i = 0
            while i < lenSlices do
                i = i + 1
                local slice <const> = slices[i]
                local bounds <const> = slice.bounds
                if bounds then
                    local xSrc <const> = bounds.x
                    local ySrc <const> = bounds.y

                    local xTrg = xSrc + dx
                    if dxNonZero then
                        local xGrid <const> = round((xSrc - xGrOff) / xGrScl)
                        xTrg = xGrOff + (xGrid + dx) * xGrScl
                    end

                    local yTrg = ySrc + dy
                    if dyNonZero then
                        local yGrid <const> = round((ySrc - yGrOff) / yGrScl)
                        yTrg = yGrOff + (yGrid + dy) * yGrScl
                    end

                    local wTrg <const> = max(1, abs(bounds.width))
                    local hTrg <const> = max(1, abs(bounds.height))
                    local xBrTrg <const> = xTrg + wTrg - 1
                    local yBrTrg <const> = yTrg + hTrg - 1

                    if xTrg >= 0 and yTrg >= 0
                        and xBrTrg < wSprite and yBrTrg < hSprite then
                        slice.bounds = Rectangle(xTrg, yTrg, wTrg, hTrg)
                    end -- End bounds contained by sprite
                end     -- End bounds not nil
            end         -- End slices loop
        end)            -- End transaction
    end                 -- End move bounds check

    if movePivot then
        local trsName <const> = string.format("Nudge Pivots (%d, %d)", dx, dy)
        app.transaction(trsName, function()
            local j = 0
            while j < lenSlices do
                j = j + 1
                local slice <const> = slices[j]
                local xSrcPiv = 0
                local ySrcPiv = 0

                local srcPivot <const> = slice.pivot
                if srcPivot then
                    xSrcPiv = srcPivot.x
                    ySrcPiv = srcPivot.y
                else
                    local bounds <const> = slice.bounds
                    if bounds then
                        local wBounds <const> = max(1, abs(bounds.width))
                        local hBounds <const> = max(1, abs(bounds.height))
                        local pivPreset <const> = pivotFromPreset(
                            pivotCombo, wBounds, hBounds)
                        xSrcPiv = pivPreset.x
                        ySrcPiv = pivPreset.y
                    end
                end

                local xTrgPiv <const> = xSrcPiv + dx
                local yTrgPiv <const> = ySrcPiv + dy
                slice.pivot = Point(xTrgPiv, yTrgPiv)
            end -- End slices loop
        end)    -- End transaction
    end         -- End move pivot check

    if moveInset then
        local insVerif <const> = math.abs(insetAmount)
        local insVerif2 <const> = insVerif + insVerif
        local trsName <const> = string.format("Nudge Insets (%d, %d)", dx, dy)
        app.transaction(trsName, function()
            local k = 0
            while k < lenSlices do
                k = k + 1
                local slice <const> = slices[k]
                local bounds <const> = slice.bounds
                if bounds then
                    local wBounds <const> = max(1, abs(bounds.width))
                    local hBounds <const> = max(1, abs(bounds.height))

                    local xtlSrcInset = insVerif
                    local ytlSrcInset = insVerif
                    local wSrcInset = wBounds - insVerif2
                    local hSrcInset = hBounds - insVerif2

                    local srcInset <const> = slice.center
                    if srcInset then
                        xtlSrcInset = srcInset.x
                        ytlSrcInset = srcInset.y
                        wSrcInset = max(1, abs(srcInset.width))
                        hSrcInset = max(1, abs(srcInset.height))
                    end

                    local xtlTrgInset <const> = xtlSrcInset + dx
                    local ytlTrgInset <const> = ytlSrcInset + dy
                    local xbrTrgInset <const> = xtlTrgInset + wSrcInset - 1
                    local ybrTrgInset <const> = ytlTrgInset + hSrcInset - 1

                    if xtlTrgInset >= 0 and xtlTrgInset < wBounds
                        and ytlTrgInset >= 0 and ytlTrgInset < hBounds

                        and xbrTrgInset >= 0 and xbrTrgInset < wBounds
                        and ybrTrgInset >= 0 and ybrTrgInset < hBounds

                        and xtlTrgInset <= xbrTrgInset
                        and ytlTrgInset <= ybrTrgInset then
                        local wTrgInset <const> = 1 + xbrTrgInset - xtlTrgInset
                        local hTrgInset <const> = 1 + ybrTrgInset - ytlTrgInset
                        slice.center = Rectangle(
                            xtlTrgInset, ytlTrgInset,
                            wTrgInset, hTrgInset)
                    end -- End inset contained by bounds
                end     -- End bounds not nil
            end         -- End slices loop
        end)            -- End transaction
    end                 -- End move inset check

    app.frame = actFrObj
    app.tool = oldTool
    app.refresh()
end

local wSet = 24
local hSet = 24
local pivotSet = "TOP_LEFT"

if app.preferences then
    local newFilePrefs <const> = app.preferences.new_file
    if newFilePrefs then
        local wNewSprite <const> = newFilePrefs.width --[[@as integer]]
        local hNewSprite <const> = newFilePrefs.height --[[@as integer]]
        if wNewSprite and (wNewSprite // 10) > 0 then
            wSet = wNewSprite // 10
        end
        if hNewSprite and (hNewSprite // 10) > 0 then
            hSet = hNewSprite // 10
        end
    end

    local maskPrefs <const> = app.preferences.selection
    if maskPrefs then
        local maskIndex <const> = maskPrefs.pivot_position --[[@as integer]]
        pivotSet = pivotOptions[1 + maskIndex]
    end
end

local dlgMain <const> = Dialog {
    title = "Edit Slices"
}

local dlgOptions <const> = Dialog {
    title = "Slices Options",
    parent = dlgMain
}

-- region Main Dialog

dlgMain:button {
    id = "selectAllButton",
    text = "A&LL",
    label = "Select:",
    focus = false,
    visible = defaults.showSelectButtons,
    onclick = function()
        -- Aseprite UI already contains function for this, but slice context
        -- bar may not be visible.

        local sprite <const> = app.sprite
        if not sprite then return end

        local spriteSlices <const> = sprite.slices
        local lenSpriteSlices <const> = #spriteSlices
        if lenSpriteSlices < 1 then return end

        local oldTool <const> = app.tool.id
        app.tool = "slice"

        local range <const> = app.range
        if range.sprite ~= sprite then
            app.tool = oldTool
            return
        end

        local actFrObj <const> = app.frame or sprite.frames[1]
        app.frame = sprite.frames[1]

        ---@type Slice[]
        local assignSlices <const> = {}
        local i = 0
        while i < lenSpriteSlices do
            i = i + 1
            assignSlices[i] = spriteSlices[i]
        end

        range.slices = assignSlices
        app.frame = actFrObj
        app.tool = oldTool
        app.refresh()
    end
}

dlgMain:button {
    id = "selectMaskButton",
    text = "&MASK",
    focus = false,
    visible = defaults.showSelectButtons,
    onclick = function()
        local sprite <const> = app.sprite
        if not sprite then return end

        local spriteSlices <const> = sprite.slices
        local lenSpriteSlices <const> = #spriteSlices
        if lenSpriteSlices < 1 then return end

        local oldTool <const> = app.tool.id
        app.tool = "slice"

        local range <const> = app.range
        if range.sprite ~= sprite then
            app.tool = oldTool
            return
        end

        local actFrObj <const> = app.frame or sprite.frames[1]
        app.frame = sprite.frames[1]

        ---@type Slice[]
        local containedSlices <const> = {}

        -- This prevents errors when mask is in a transform preview state.
        app.command.InvertMask()
        app.command.InvertMask()

        -- If no mask, then select everything.
        local mask <const> = sprite.selection
        if mask == nil or mask.isEmpty then
            local h = 0
            while h < lenSpriteSlices do
                h = h + 1
                containedSlices[h] = spriteSlices[h]
            end
        else
            local abs <const> = math.abs
            local max <const> = math.max

            local i = 0
            while i < lenSpriteSlices do
                i = i + 1
                local slice <const> = spriteSlices[i]
                local sliceBounds <const> = slice.bounds
                if sliceBounds then
                    local xtlSlice <const> = sliceBounds.x
                    local ytlSlice <const> = sliceBounds.y
                    local wSlice <const> = max(1, abs(sliceBounds.width))
                    local hSlice <const> = max(1, abs(sliceBounds.height))
                    local areaSlice <const> = wSlice * hSlice

                    local isContained = true
                    local j = 0
                    while isContained and j < areaSlice do
                        local xSample <const> = xtlSlice + j % wSlice
                        local ySample <const> = ytlSlice + j // wSlice
                        isContained = isContained
                            and mask:contains(Point(xSample, ySample))
                        j = j + 1
                    end

                    if isContained then
                        containedSlices[#containedSlices + 1] = slice
                    end
                end
            end
        end

        range.slices = containedSlices
        app.frame = actFrObj
        app.tool = oldTool
        app.refresh()
    end
}

dlgMain:button {
    id = "deselectButton",
    text = "&NONE",
    focus = false,
    visible = defaults.showSelectButtons,
    onclick = function()
        -- Aseprite UI already contains function for this, but slice context
        -- bar may not be visible.

        local sprite <const> = app.sprite
        if not sprite then return end

        local oldTool <const> = app.tool.id
        app.tool = "slice"

        local actFrObj <const> = app.frame or sprite.frames[1]
        app.frame = sprite.frames[1]

        local range <const> = app.range
        if range.sprite ~= sprite then
            app.tool = oldTool
            return
        end

        range.slices = {}
        app.frame = actFrObj
        app.tool = oldTool
        app.refresh()
    end
}

dlgMain:newrow { always = false }

dlgMain:button {
    id = "prevButton",
    label = "Focus:",
    text = "&<",
    focus = false,
    visible = defaults.showFocusButtons,
    onclick = function()
        changeActiveSlice(-1)
    end
}

dlgMain:button {
    id = "nextButton",
    text = "&>",
    focus = false,
    visible = defaults.showFocusButtons,
    onclick = function()
        changeActiveSlice(1)
    end
}

dlgMain:newrow { always = false }

dlgMain:button {
    id = "copyButton",
    label = "Edit:",
    text = "COP&Y",
    focus = false,
    visible = defaults.showEditButtons,
    onclick = function()
        local sprite <const> = app.sprite
        if not sprite then return end

        local oldTool <const> = app.tool.id
        app.tool = "slice"

        local range <const> = app.range
        if range.sprite ~= sprite then
            app.tool = oldTool
            return
        end

        if defaults.enableCopyWarning then
            local response <const> = app.alert {
                title = "Warning",
                text = {
                    "Are you sure you want to copy these slices?",
                    "Custom data and properties will NOT be copied.",
                    "A slice's frame data cannot be copied."
                },
                buttons = { "&YES", "&NO" }
            }
            if response == 2 then
                app.tool = oldTool
                return
            end
        end

        local actFrObj <const> = app.frame or sprite.frames[1]
        local actFrIdx <const> = actFrObj.frameNumber
        app.frame = sprite.frames[1]

        local slices <const> = range.slices
        local lenSlices <const> = #slices
        if lenSlices < 1 then
            app.frame = actFrObj
            app.tool = oldTool
            app.alert {
                title = "Error",
                text = "No slices were selected."
            }
            return
        end

        ---@type Slice[]
        local slicesToDupe <const> = {}
        local i = 0
        while i < lenSlices do
            i = i + 1
            slicesToDupe[i] = slices[i]
        end

        table.sort(slicesToDupe, tlComparator)

        local abs <const> = math.abs
        local min <const> = math.min
        local max <const> = math.max

        local defaultColor = Color { r = 0, g = 0, b = 255, a = 255 }
        local appPrefs <const> = app.preferences
        if appPrefs then
            local slicePrefs <const> = appPrefs.slices
            if slicePrefs then
                local prefsColor <const> = slicePrefs.default_color --[[@as Color]]
                if prefsColor then
                    if prefsColor.alpha > 0 then
                        defaultColor = Color {
                            r = min(max(prefsColor.red, 0), 255),
                            g = min(max(prefsColor.green, 0), 255),
                            b = min(max(prefsColor.blue, 0), 255),
                            a = min(max(prefsColor.alpha, 0), 255)
                        }
                    end
                end
            end
        end

        ---@type Slice[]
        local duplicates <const> = {}

        app.transaction("Copy Slices", function()
            local j = 0
            while j < lenSlices do
                j = j + 1
                local srcSlice <const> = slicesToDupe[j]
                local srcBounds <const> = srcSlice.bounds
                if srcBounds then
                    local xBounds <const> = srcBounds.x
                    local yBounds <const> = srcBounds.y
                    local wBounds <const> = max(1, abs(srcBounds.width))
                    local hBounds <const> = max(1, abs(srcBounds.height))
                    local trgBounds <const> = Rectangle(
                        xBounds, yBounds, wBounds, hBounds)

                    local trgSlice <const> = sprite:newSlice(trgBounds)
                    duplicates[#duplicates + 1] = trgSlice

                    local fromFrIdx = actFrIdx - 1
                    if srcSlice.properties["fromFrame"] then
                        fromFrIdx = srcSlice.properties["fromFrame"] --[[@as integer]]
                    end

                    local toFrIdx = actFrIdx - 1
                    if srcSlice.properties["toFrame"] then
                        fromFrIdx = srcSlice.properties["toFrame"] --[[@as integer]]
                    end

                    -- Swap invalid from and to frames.
                    if toFrIdx < fromFrIdx then
                        fromFrIdx, toFrIdx = toFrIdx, fromFrIdx
                    end

                    trgSlice.properties["fromFrame"] = fromFrIdx
                    trgSlice.properties["toFrame"] = toFrIdx

                    local srcCenter <const> = srcSlice.center
                    if srcCenter and srcCenter ~= nil then
                        local xCenter <const> = srcCenter.x
                        local yCenter <const> = srcCenter.y
                        local wCenter <const> = max(1, abs(srcCenter.width))
                        local hCenter <const> = max(1, abs(srcCenter.height))
                        trgSlice.center = Rectangle(xCenter, yCenter,
                            wCenter, hCenter)
                    end

                    local trgColor = Color {
                        r = defaultColor.red,
                        g = defaultColor.green,
                        b = defaultColor.blue,
                        a = defaultColor.alpha
                    }
                    local srcColor <const> = srcSlice.color
                    if srcColor then
                        if srcColor.alpha > 0 then
                            local rSrc <const> = min(max(srcColor.red, 0), 255)
                            local gSrc <const> = min(max(srcColor.green, 0), 255)
                            local bSrc <const> = min(max(srcColor.blue, 0), 255)
                            local aSrc <const> = min(max(srcColor.alpha, 0), 255)

                            local rTrg = rSrc
                            local gTrg = gSrc
                            local bTrg = bSrc
                            local aTrg <const> = aSrc

                            if defaults.useColorInvert then
                                rTrg = 255 - rTrg
                                gTrg = 255 - gTrg
                                bTrg = 255 - bTrg
                            end

                            trgColor = Color {
                                r = rTrg,
                                g = gTrg,
                                b = bTrg,
                                a = aTrg
                            }
                        end
                    end
                    trgSlice.color = trgColor

                    local trgName = "Slice (Copy)"
                    local srcName <const> = srcSlice.name
                    if srcName then
                        if #srcName > 0 then
                            trgName = srcName .. " (Copy)"
                        end
                    end
                    trgSlice.name = trgName

                    local srcPivot <const> = srcSlice.pivot
                    if srcPivot and srcPivot ~= nil then
                        trgSlice.pivot = Point(srcPivot.x, srcPivot.y)
                    end
                end
            end
        end)

        app.frame = actFrObj
        range.slices = duplicates
        app.tool = oldTool
        app.refresh()
    end
}

dlgMain:button {
    id = "deleteButton",
    text = "DELE&TE",
    focus = false,
    visible = defaults.showEditButtons,
    onclick = function()
        local sprite <const> = app.sprite
        if not sprite then return end

        local oldTool <const> = app.tool.id
        app.tool = "slice"

        local range <const> = app.range
        if range.sprite ~= sprite then
            app.tool = oldTool
            return
        end

        local response <const> = app.alert {
            title = "Warning",
            text = "Are you sure you want to delete these slices?",
            buttons = { "&YES", "&NO" }
        }
        if response == 2 then
            app.tool = oldTool
            return
        end

        local actFrObj <const> = app.frame or sprite.frames[1]

        local slices <const> = range.slices
        local lenSlices <const> = #slices
        if lenSlices < 1 then
            app.frame = actFrObj
            app.tool = oldTool
            app.alert {
                title = "Error",
                text = "No slices were selected."
            }
            return
        end

        ---@type Slice[]
        local slicesToRemove <const> = {}
        local i = 0
        while i < lenSlices do
            i = i + 1
            slicesToRemove[i] = slices[i]
        end

        -- Empty range prior to deleting.
        range.slices = {}

        app.transaction("Delete Slices", function()
            local j = lenSlices + 1
            while j > 1 do
                j = j - 1
                local slice <const> = slicesToRemove[j]
                sprite:deleteSlice(slice)
            end
        end)

        app.frame = actFrObj
        app.tool = oldTool
        app.refresh()
    end
}

dlgMain:newrow { always = false }

dlgMain:button {
    id = "fromFramesButton",
    label = "Convert:",
    text = "&FRAME",
    focus = false,
    visible = defaults.showConvertButtons,
    onclick = function()
        local sprite <const> = app.sprite
        if not sprite then return end

        local actFrObj <const> = app.frame or sprite.frames[1]
        local actFrIdx <const> = actFrObj.frameNumber

        local tlHidden = true
        local trgColor = Color { r = 0, g = 0, b = 255, a = 255 }

        local appPrefs <const> = app.preferences
        if appPrefs then
            local gnrlPrefs <const> = appPrefs.general
            if gnrlPrefs then
                local visTimeline <const> = gnrlPrefs.visible_timeline --[[@as boolean]]
                if visTimeline and visTimeline == true then
                    tlHidden = false
                end
            end

            local slicePrefs <const> = appPrefs.slices
            if slicePrefs then
                local prefsColor <const> = slicePrefs.default_color --[[@as Color]]
                if prefsColor and prefsColor.alpha > 0 then
                    trgColor = Color {
                        r = math.min(math.max(prefsColor.red, 0), 255),
                        g = math.min(math.max(prefsColor.green, 0), 255),
                        b = math.min(math.max(prefsColor.blue, 0), 255),
                        a = math.min(math.max(prefsColor.alpha, 0), 255)
                    }
                end
            end
        end

        if tlHidden then
            app.command.Timeline { open = true }
        end

        ---@type Layer[]
        local chosenLayers = {}
        local range <const> = app.range
        if range.sprite == sprite then
            if range.isEmpty or range.type == RangeType.FRAMES then
                ---@type Layer[]
                local leaves <const> = {}
                local spriteLayers <const> = sprite.layers
                local lenSpriteLayers <const> = #spriteLayers
                local i = 0
                while i < lenSpriteLayers do
                    i = i + 1
                    appendLeaves(spriteLayers[i], leaves)
                end
                chosenLayers = leaves
            else
                local rangeLayers <const> = range.layers
                local lenRangeLayers <const> = #rangeLayers
                local h = 0
                while h < lenRangeLayers do
                    h = h + 1
                    local rangeLayer <const> = rangeLayers[h]
                    if rangeLayer.isVisible
                        and (not rangeLayer.isGroup)
                        and (not rangeLayer.isReference) then
                        chosenLayers[#chosenLayers + 1] = rangeLayer
                    end
                end
            end
        end

        if tlHidden then
            app.command.Timeline { close = true }
        end

        local lenChosenLayers <const> = #chosenLayers
        if lenChosenLayers < 1 then
            app.alert {
                title = "Error",
                text = "No visible layers selected at this frame."
            }
            return
        end

        table.sort(chosenLayers, function(a, b)
            if a.stackIndex == b.stackIndex then
                return a.name < b.name
            end
            return a.stackIndex < b.stackIndex
        end)

        local oldTool <const> = app.tool.id
        app.tool = "slice"

        local args <const> = dlgMain.data
        local inset <const> = args.insetAmount --[[@as integer]]
        local pivotCombo <const> = args.pivotCombo --[[@as string]]
        local newName <const> = args.nameEntry --[[@as string]]

        local newNameVrf = "Slice"
        if newName and #newName > 0 then
            newNameVrf = newName
        end

        local wSprite <const> = sprite.width
        local hSprite <const> = sprite.height
        local colorMode <const> = sprite.colorMode
        local alphaIndex <const> = sprite.transparentColor
        local alphaIndexVerif <const> = (colorMode == ColorMode.INDEXED
            and alphaIndex > 255) and 0 or alphaIndex

        local bkgHex = 0
        app.command.SwitchColors()
        local bkgColor <const> = app.fgColor
        if bkgColor.alpha > 0 then
            if colorMode == ColorMode.GRAY then
                local sr <const> = bkgColor.red
                local sg <const> = bkgColor.green
                local sb <const> = bkgColor.blue
                local gray <const> = (sr * 2126 + sg * 7152 + sb * 722) // 10000
                bkgHex = (bkgColor.alpha << 0x08) | gray
            elseif colorMode == ColorMode.INDEXED then
                bkgHex = bkgColor.index
            elseif colorMode == ColorMode.RGB then
                bkgHex = bkgColor.rgbaPixel
            end
        end
        app.command.SwitchColors()

        -- Frame base index could be negative.
        local frIdxDisplay = actFrIdx - 1
        local insVerif = math.abs(inset)
        local xtlInset <const> = insVerif
        local ytlInset <const> = insVerif
        -- This could be layer name instead of or in addition to number,
        -- but layer names are not unique identifiers.
        local format <const> = "%s Fr%d No%d"

        local strfmt <const> = string.format
        local max <const> = math.max
        local min <const> = math.min

        ---@type Slice[]
        local newSlices <const> = {}
        local lenNewSlices = 0

        app.frame = sprite.frames[1]

        app.transaction("New Slices From Frame", function()
            local i = 0
            while i < lenChosenLayers do
                i = i + 1
                local layer <const> = chosenLayers[i]
                local cel <const> = layer:cel(actFrIdx)
                if cel then
                    local xtlCel = 0
                    local ytlCel = 0
                    local wCel = 0
                    local hCel = 0

                    if layer.isTilemap then
                        -- Shrink bounds does not work with tile maps.
                        local celBounds <const> = cel.bounds
                        xtlCel = celBounds.x
                        ytlCel = celBounds.y
                        wCel = celBounds.width
                        hCel = celBounds.height
                    else
                        -- Cel image may not be trimmed of alpha.
                        -- Empty images will return zero size rectangle.
                        local celPos <const> = cel.position
                        local celImage <const> = cel.image
                        local ref <const> = layer.isBackground
                            and bkgHex or alphaIndexVerif
                        local trimRect <const> = celImage:shrinkBounds(ref)
                        xtlCel = celPos.x + trimRect.x
                        ytlCel = celPos.y + trimRect.y
                        wCel = trimRect.width
                        hCel = trimRect.height
                    end

                    if wCel > 0 and hCel > 0 then
                        -- Cel may be out of bounds, so it must be intersected
                        -- with sprite canvas.
                        local xbrCelCl <const> = min(wSprite - 1, xtlCel + wCel - 1)
                        local ybrCelCl <const> = min(hSprite - 1, ytlCel + hCel - 1)
                        local xtlCelCl <const> = max(0, xtlCel)
                        local ytlCelCl <const> = max(0, ytlCel)

                        if xtlCelCl <= xbrCelCl and ytlCelCl <= ybrCelCl then
                            local wSlice <const> = 1 + xbrCelCl - xtlCelCl
                            local hSlice <const> = 1 + ybrCelCl - ytlCelCl
                            if wSlice >= defaults.wSliceMin and hSlice >= defaults.hSliceMin then
                                local slice <const> = sprite:newSlice(Rectangle(
                                    xtlCelCl, ytlCelCl, wSlice, hSlice))

                                lenNewSlices = lenNewSlices + 1
                                newSlices[lenNewSlices] = slice

                                slice.color = trgColor
                                slice.name = strfmt(format, newNameVrf,
                                    frIdxDisplay, lenNewSlices)
                                slice.pivot = pivotFromPreset(pivotCombo,
                                    wSlice, hSlice)

                                slice.properties["fromFrame"] = actFrIdx - 1
                                slice.properties["toFrame"] = actFrIdx - 1

                                local xbrInset <const> = (wSlice - 1) - insVerif
                                local ybrInset <const> = (hSlice - 1) - insVerif
                                if xtlInset <= xbrInset and ytlInset <= ybrInset then
                                    local wInset <const> = 1 + xbrInset - xtlInset
                                    local hInset <const> = 1 + ybrInset - ytlInset
                                    slice.center = Rectangle(
                                        xtlInset, ytlInset, wInset, hInset)
                                end -- End inset corners are valid.
                            end     -- End slice size is gteq minimum.
                        end         -- End bounds corners are valid.
                    end             -- End cel nonzero bounds.
                end                 -- End cel exists.
            end                     -- End cels loop.
        end)

        range.slices = newSlices
        app.frame = actFrObj
        app.tool = oldTool
        app.refresh()
    end
}

dlgMain:button {
    id = "maskToSliceButton",
    text = "MAS&K",
    focus = false,
    visible = defaults.showConvertButtons,
    onclick = function()
        local sprite <const> = app.sprite
        if not sprite then return end

        -- This prevents errors when mask is in a transform preview state.
        app.command.InvertMask()
        app.command.InvertMask()

        local srcMask <const> = sprite.selection
        if srcMask and (not srcMask.isEmpty) then
            local maskBounds <const> = srcMask.bounds
            local x <const> = maskBounds.x
            local y <const> = maskBounds.y
            local w <const> = math.max(1, math.abs(maskBounds.width))
            local h <const> = math.max(1, math.abs(maskBounds.height))

            if w >= defaults.wSliceMin
                and h >= defaults.hSliceMin then
                local oldTool <const> = app.tool.id
                app.tool = "slice"

                local args <const> = dlgMain.data
                local inset <const> = args.insetAmount --[[@as integer]]
                local pivotCombo <const> = args.pivotCombo --[[@as string]]
                local newName <const> = args.nameEntry --[[@as string]]

                local newNameVrf = "Slice"
                if newName and #newName > 0 then
                    newNameVrf = newName
                end

                local insVerif = math.abs(inset)
                local xtlInset <const> = insVerif
                local ytlInset <const> = insVerif
                local xbrInset <const> = (w - 1) - insVerif
                local ybrInset <const> = (h - 1) - insVerif

                local trgColor = Color { r = 0, g = 0, b = 255, a = 255 }
                local appPrefs <const> = app.preferences
                if appPrefs then
                    local slicePrefs <const> = appPrefs.slices
                    if slicePrefs then
                        local prefsColor <const> = slicePrefs.default_color --[[@as Color]]
                        if prefsColor and prefsColor.alpha > 0 then
                            trgColor = Color {
                                r = math.min(math.max(prefsColor.red, 0), 255),
                                g = math.min(math.max(prefsColor.green, 0), 255),
                                b = math.min(math.max(prefsColor.blue, 0), 255),
                                a = math.min(math.max(prefsColor.alpha, 0), 255)
                            }
                        end
                    end
                end

                local actFrObj <const> = app.frame or sprite.frames[1]
                local actFrIdx <const> = actFrObj and actFrObj.frameNumber or 1
                app.frame = sprite.frames[1]

                app.transaction("New Slice From Mask", function()
                    local slice <const> = sprite:newSlice(
                        Rectangle(x, y, w, h))
                    slice.color = trgColor
                    slice.name = string.format("%s Fr%d", newNameVrf,
                        actFrIdx - 1)
                    slice.pivot = pivotFromPreset(pivotCombo, w, h)

                    slice.properties["fromFrame"] = actFrIdx - 1
                    slice.properties["toFrame"] = actFrIdx - 1

                    if xtlInset <= xbrInset and ytlInset <= ybrInset then
                        local wInset <const> = 1 + xbrInset - xtlInset
                        local hInset <const> = 1 + ybrInset - ytlInset
                        slice.center = Rectangle(
                            xtlInset, ytlInset, wInset, hInset)
                    end

                    local range <const> = app.range
                    if range.sprite == sprite then
                        range.slices = { slice }
                    end
                end)

                app.frame = actFrObj
                app.tool = oldTool
            end
        else
            app.alert {
                title = "Error",
                text = "Mask is empty."
            }
        end

        app.refresh()
    end
}

dlgMain:button {
    id = "sliceToMaskButton",
    text = "SLIC&E",
    focus = false,
    visible = defaults.showConvertButtons,
    onclick = function()
        local sprite <const> = app.sprite
        if not sprite then return end

        local oldTool <const> = app.tool.id
        app.tool = "slice"

        local range <const> = app.range
        if range.sprite ~= sprite then
            app.tool = oldTool
            return
        end

        local slices <const> = range.slices
        local lenSlices <const> = #slices
        if lenSlices < 1 then
            app.tool = oldTool
            app.alert {
                title = "Error",
                text = "No slices were selected."
            }
            return
        end

        local abs <const> = math.abs
        local max <const> = math.max

        local mask <const> = Selection()

        local actFrObj <const> = app.frame or sprite.frames[1]
        app.frame = sprite.frames[1]

        local i = 0
        while i < lenSlices do
            i = i + 1
            local slice <const> = slices[i]
            local sliceBounds <const> = slice.bounds
            if sliceBounds then
                local x <const> = sliceBounds.x
                local y <const> = sliceBounds.y
                local w <const> = max(1, abs(sliceBounds.width))
                local h <const> = max(1, abs(sliceBounds.height))
                mask:add(Rectangle(x, y, w, h))
            end
        end

        app.transaction("Set Mask From Slice", function()
            sprite.selection = mask
        end)

        app.frame = actFrObj
        app.tool = oldTool
        app.refresh()
    end
}

dlgMain:newrow { always = false }

dlgMain:button {
    id = "moveUpButton",
    text = "&W",
    label = "Nudge:",
    focus = false,
    visible = defaults.showNudgeButtons,
    onclick = function()
        local args <const> = dlgMain.data
        local moveBounds <const> = args.moveBounds --[[@as boolean]]
        local movePivot <const> = args.movePivot --[[@as boolean]]
        local moveInset <const> = args.moveInset --[[@as boolean]]
        local pivotCombo <const> = args.pivotCombo --[[@as string]]
        local insetAmount <const> = args.insetAmount --[[@as integer]]
        translateSlices(0, -defaults.nudgeStep,
            moveBounds, movePivot, moveInset,
            pivotCombo, insetAmount)
    end
}

dlgMain:button {
    id = "moveLeftButton",
    text = "&A",
    focus = false,
    visible = defaults.showNudgeButtons,
    onclick = function()
        local args <const> = dlgMain.data
        local moveBounds <const> = args.moveBounds --[[@as boolean]]
        local movePivot <const> = args.movePivot --[[@as boolean]]
        local moveInset <const> = args.moveInset --[[@as boolean]]
        local pivotCombo <const> = args.pivotCombo --[[@as string]]
        local insetAmount <const> = args.insetAmount --[[@as integer]]
        translateSlices(-defaults.nudgeStep, 0,
            moveBounds, movePivot, moveInset,
            pivotCombo, insetAmount)
    end
}

dlgMain:button {
    id = "moveDownButton",
    text = "&S",
    focus = false,
    visible = defaults.showNudgeButtons,
    onclick = function()
        local args <const> = dlgMain.data
        local moveBounds <const> = args.moveBounds --[[@as boolean]]
        local movePivot <const> = args.movePivot --[[@as boolean]]
        local moveInset <const> = args.moveInset --[[@as boolean]]
        local pivotCombo <const> = args.pivotCombo --[[@as string]]
        local insetAmount <const> = args.insetAmount --[[@as integer]]
        translateSlices(0, defaults.nudgeStep,
            moveBounds, movePivot, moveInset,
            pivotCombo, insetAmount)
    end
}

dlgMain:button {
    id = "moveRightButton",
    text = "&D",
    focus = false,
    visible = defaults.showNudgeButtons,
    onclick = function()
        local args <const> = dlgMain.data
        local moveBounds <const> = args.moveBounds --[[@as boolean]]
        local movePivot <const> = args.movePivot --[[@as boolean]]
        local moveInset <const> = args.moveInset --[[@as boolean]]
        local pivotCombo <const> = args.pivotCombo --[[@as string]]
        local insetAmount <const> = args.insetAmount --[[@as integer]]
        translateSlices(defaults.nudgeStep, 0,
            moveBounds, movePivot, moveInset,
            pivotCombo, insetAmount)
    end
}

dlgMain:newrow { always = false }

dlgMain:check {
    id = "moveBounds",
    text = "Bounds",
    selected = true,
    focus = false,
    visible = defaults.showNudgeButtons
        and defaults.showNudgeChecks
}

dlgMain:check {
    id = "movePivot",
    text = "Pivot",
    selected = false,
    focus = false,
    visible = defaults.showNudgeButtons
        and defaults.showNudgeChecks
}

dlgMain:check {
    id = "moveInset",
    text = "Inset",
    selected = false,
    focus = false,
    visible = defaults.showNudgeButtons
        and defaults.showNudgeChecks
}

dlgMain:newrow { always = false }

dlgMain:number {
    id = "width",
    -- label = "Pixels:",
    label = "Size:",
    text = string.format("%d", wSet),
    decimals = 0,
    visible = defaults.showSizeButtons,
    focus = false,
}

dlgMain:number {
    id = "height",
    text = string.format("%d", hSet),
    decimals = 0,
    visible = defaults.showSizeButtons,
    focus = false,
}

dlgMain:newrow { always = false }

dlgMain:button {
    id = "resizeButton",
    text = "RESI&ZE",
    visible = defaults.showSizeButtons,
    focus = false,
    onclick = function()
        local sprite <const> = app.sprite
        if not sprite then return end

        local oldTool <const> = app.tool.id
        app.tool = "slice"

        local range <const> = app.range
        if range.sprite ~= sprite then
            app.tool = oldTool
            return
        end

        local slices <const> = range.slices
        local lenSlices <const> = #slices
        if lenSlices < 1 then
            app.tool = oldTool
            app.alert {
                title = "Error",
                text = "No slices were selected."
            }
            return
        end

        local args <const> = dlgMain.data
        local width <const> = args.width --[[@as integer]]
        local height <const> = args.height --[[@as integer]]

        local wSprite <const> = sprite.width
        local hSprite <const> = sprite.height
        local wVerif <const> = math.max(
            defaults.wSliceMin, math.abs(width))
        local hVerif <const> = math.max(
            defaults.hSliceMin, math.abs(height))

        local actFrObj <const> = app.frame or sprite.frames[1]
        app.frame = sprite.frames[1]

        local abs <const> = math.abs
        local max <const> = math.max

        local trsName <const> = string.format(
            "Scale Slices (%d, %d)",
            wVerif, hVerif)
        app.transaction(trsName, function()
            local i = 0
            while i < lenSlices do
                i = i + 1
                local slice <const> = slices[i]
                local srcBounds <const> = slice.bounds
                if srcBounds then
                    local xtlSrc <const> = srcBounds.x
                    local ytlSrc <const> = srcBounds.y
                    local wSrc <const> = max(1, abs(srcBounds.width))
                    local hSrc <const> = max(1, abs(srcBounds.height))

                    -- In case you want to do percentage based scaling later.
                    local wTrg = wVerif
                    local hTrg = hVerif

                    local xPivSrc = 0
                    local yPivSrc = 0
                    local srcPivot <const> = slice.pivot
                    if srcPivot then
                        xPivSrc = srcPivot.x
                        yPivSrc = srcPivot.y
                    end

                    local xRatio <const> = wSrc > 1 and (wTrg - 1.0) / (wSrc - 1.0) or 0.0
                    local yRatio <const> = hSrc > 1 and (hTrg - 1.0) / (hSrc - 1.0) or 0.0

                    local xPivTrgf <const> = xPivSrc * xRatio
                    local yPivTrgf <const> = yPivSrc * yRatio

                    local xPivGlobal <const> = xtlSrc + xPivSrc
                    local yPivGlobal <const> = ytlSrc + yPivSrc

                    local xtlTrg <const> = round(xPivGlobal - xPivTrgf)
                    local ytlTrg <const> = round(yPivGlobal - yPivTrgf)
                    local xbrTrg <const> = xtlTrg + wTrg - 1
                    local ybrTrg <const> = ytlTrg + hTrg - 1

                    if ytlTrg >= 0 and ybrTrg < hSprite
                        and xtlTrg >= 0 and xbrTrg < wSprite then
                        slice.bounds = Rectangle(xtlTrg, ytlTrg, wTrg, hTrg)

                        if srcPivot then
                            local xPivTrg <const> = xPivGlobal - xtlTrg
                            local yPivTrg <const> = yPivGlobal - ytlTrg
                            slice.pivot = Point(xPivTrg, yPivTrg)
                        end

                        local srcInset <const> = slice.center
                        if srcInset then
                            local xtlInsetSrc <const> = srcInset.x
                            local ytlInsetSrc <const> = srcInset.y
                            local wInsetSrc <const> = max(1, abs(srcInset.width))
                            local hInsetSrc <const> = max(1, abs(srcInset.height))

                            local xbrInsetSrc <const> = xtlInsetSrc + wInsetSrc - 1
                            local ybrInsetSrc <const> = ytlInsetSrc + hInsetSrc - 1

                            local xtlInsetTrg = round(xtlInsetSrc * xRatio)
                            local ytlInsetTrg = round(ytlInsetSrc * yRatio)
                            local xbrInsetTrg = round(xbrInsetSrc * xRatio)
                            local ybrInsetTrg = round(ybrInsetSrc * yRatio)
                            if xtlInsetTrg <= xbrInsetTrg
                                and ytlInsetTrg <= ybrInsetTrg then
                                local wInsetTrg <const> = 1 + xbrInsetTrg - xtlInsetTrg
                                local hInsetTrg <const> = 1 + ybrInsetTrg - ytlInsetTrg
                                slice.center = Rectangle(
                                    xtlInsetTrg, ytlInsetTrg,
                                    wInsetTrg, hInsetTrg)
                            end -- End target inset is valid.
                        end     -- End source inset exists.
                    end         -- End target bounds is valid.
                end             -- End source bounds exists.
            end                 -- End loop.
        end)

        app.frame = actFrObj
        app.tool = oldTool
        app.refresh()
    end
}

dlgMain:newrow { always = false }

dlgMain:number {
    id = "insetAmount",
    label = "Amount:",
    text = string.format("%d", 0),
    decimals = 0,
    focus = false,
    visible = defaults.showInsetButtons
}

dlgMain:newrow { always = false }

dlgMain:combobox {
    id = "pivotCombo",
    label = "Preset:",
    option = pivotSet,
    options = pivotOptions,
    focus = false,
    visible = defaults.showPivotButtons
}

dlgMain:newrow { always = false }

dlgMain:button {
    id = "insetButton",
    text = "&INSET",
    focus = false,
    visible = defaults.showInsetButtons,
    onclick = function()
        local sprite <const> = app.sprite
        if not sprite then return end

        local oldTool <const> = app.tool.id
        app.tool = "slice"

        local range <const> = app.range
        if range.sprite ~= sprite then
            app.tool = oldTool
            return
        end

        local slices <const> = range.slices
        local lenSlices <const> = #slices
        if lenSlices < 1 then
            app.tool = oldTool
            app.alert {
                title = "Error",
                text = "No slices were selected."
            }
            return
        end

        local args <const> = dlgMain.data
        local inset <const> = args.insetAmount --[[@as integer]]
        local insVerif = math.abs(inset)

        local actFrObj <const> = app.frame or sprite.frames[1]
        app.frame = sprite.frames[1]

        local abs <const> = math.abs
        local max <const> = math.max

        app.transaction(string.format("Slice Inset %d", insVerif), function()
            local i = 0
            while i < lenSlices do
                i = i + 1
                local slice <const> = slices[i]
                local bounds <const> = slice.bounds
                if bounds then
                    local wSrc <const> = max(1, abs(bounds.width))
                    local hSrc <const> = max(1, abs(bounds.height))
                    local xbrSrc <const> = wSrc - 1
                    local ybrSrc <const> = hSrc - 1

                    local xtlTrg <const> = insVerif
                    local ytlTrg <const> = insVerif
                    local xbrTrg <const> = xbrSrc - insVerif
                    local ybrTrg <const> = ybrSrc - insVerif

                    if xtlTrg <= xbrTrg and ytlTrg <= ybrTrg then
                        local wTrg <const> = 1 + xbrTrg - xtlTrg
                        local hTrg <const> = 1 + ybrTrg - ytlTrg
                        slice.center = Rectangle(xtlTrg, ytlTrg, wTrg, hTrg)
                    end
                end
            end
        end)

        app.frame = actFrObj
        app.tool = oldTool
        app.refresh()
    end
}

dlgMain:button {
    id = "setPivotButton",
    text = "PI&VOT",
    focus = false,
    visible = defaults.showPivotButtons,
    onclick = function()
        local sprite <const> = app.sprite
        if not sprite then return end

        local oldTool <const> = app.tool.id
        app.tool = "slice"

        local range <const> = app.range
        if range.sprite ~= sprite then
            app.tool = oldTool
            return
        end

        local slices <const> = range.slices
        local lenSlices <const> = #slices
        if lenSlices < 1 then
            app.tool = oldTool
            app.alert {
                title = "Error",
                text = "No slices were selected."
            }
            return
        end

        local args <const> = dlgMain.data
        local pivotCombo <const> = args.pivotCombo --[[@as string]]

        local abs <const> = math.abs
        local max <const> = math.max

        local actFrObj <const> = app.frame or sprite.frames[1]
        app.frame = sprite.frames[1]

        if pivotCombo == "TOP_LEFT" then
            app.transaction("Slice Pivot Top Left", function()
                local i = 0
                while i < lenSlices do
                    i = i + 1
                    local slice <const> = slices[i]
                    local bounds <const> = slice.bounds
                    if bounds then
                        slice.pivot = Point(0, 0)
                    end
                end
            end)
        elseif pivotCombo == "TOP_CENTER" then
            app.transaction("Slice Pivot Top Center", function()
                local i = 0
                while i < lenSlices do
                    i = i + 1
                    local slice <const> = slices[i]
                    local bounds <const> = slice.bounds
                    if bounds then
                        local w <const> = max(1, abs(bounds.width))
                        slice.pivot = Point(w // 2, 0)
                    end
                end
            end)
        elseif pivotCombo == "TOP_RIGHT" then
            app.transaction("Slice Pivot Top Right", function()
                local i = 0
                while i < lenSlices do
                    i = i + 1
                    local slice <const> = slices[i]
                    local bounds <const> = slice.bounds
                    if bounds then
                        local w <const> = max(1, abs(bounds.width))
                        slice.pivot = Point(w - 1, 0)
                    end
                end
            end)
        elseif pivotCombo == "CENTER_LEFT" then
            app.transaction("Slice Pivot Center Left", function()
                local i = 0
                while i < lenSlices do
                    i = i + 1
                    local slice <const> = slices[i]
                    local bounds <const> = slice.bounds
                    if bounds then
                        local h <const> = max(1, abs(bounds.height))
                        slice.pivot = Point(0, h // 2)
                    end
                end
            end)
        elseif pivotCombo == "CENTER" then
            app.transaction("Slice Pivot Center", function()
                local i = 0
                while i < lenSlices do
                    i = i + 1
                    local slice <const> = slices[i]
                    local bounds <const> = slice.bounds
                    if bounds then
                        local w <const> = max(1, abs(bounds.width))
                        local h <const> = max(1, abs(bounds.height))
                        slice.pivot = Point(w // 2, h // 2)
                    end
                end
            end)
        elseif pivotCombo == "CENTER_RIGHT" then
            app.transaction("Slice Pivot Center Right", function()
                local i = 0
                while i < lenSlices do
                    i = i + 1
                    local slice <const> = slices[i]
                    local bounds <const> = slice.bounds
                    if bounds then
                        local w <const> = max(1, abs(bounds.width))
                        local h <const> = max(1, abs(bounds.height))
                        slice.pivot = Point(w - 1, h // 2)
                    end
                end
            end)
        elseif pivotCombo == "BOTTOM_LEFT" then
            app.transaction("Slice Pivot Bottom Left", function()
                local i = 0
                while i < lenSlices do
                    i = i + 1
                    local slice <const> = slices[i]
                    local bounds <const> = slice.bounds
                    if bounds then
                        local h <const> = max(1, abs(bounds.height))
                        slice.pivot = Point(0, h - 1)
                    end
                end
            end)
        elseif pivotCombo == "BOTTOM_CENTER" then
            app.transaction("Slice Pivot Bottom Center", function()
                local i = 0
                while i < lenSlices do
                    i = i + 1
                    local slice <const> = slices[i]
                    local bounds <const> = slice.bounds
                    if bounds then
                        local w <const> = max(1, abs(bounds.width))
                        local h <const> = max(1, abs(bounds.height))
                        slice.pivot = Point(w // 2, h - 1)
                    end
                end
            end)
        elseif pivotCombo == "BOTTOM_RIGHT" then
            app.transaction("Slice Pivot Bottom Right", function()
                local i = 0
                while i < lenSlices do
                    i = i + 1
                    local slice <const> = slices[i]
                    local bounds <const> = slice.bounds
                    if bounds then
                        local w <const> = max(1, abs(bounds.width))
                        local h <const> = max(1, abs(bounds.height))
                        slice.pivot = Point(w - 1, h - 1)
                    end
                end
            end)
        end

        app.frame = actFrObj
        app.tool = oldTool
        app.refresh()
    end
}

dlgMain:newrow { always = false }

dlgMain:entry {
    id = "nameEntry",
    label = "Name:",
    text = "Slice",
    focus = false,
    visible = defaults.showRenameButtons
}

dlgMain:newrow { always = false }

dlgMain:color {
    id = "origColor",
    label = "Mix:",
    color = Color { r = 254, g = 91, b = 89, a = 255 },
    focus = false,
    visible = defaults.showRecolorButtons
}

dlgMain:color {
    id = "destColor",
    color = Color { r = 106, g = 205, b = 91, a = 255 },
    focus = false,
    visible = defaults.showRecolorButtons
}

dlgMain:newrow { always = false }

dlgMain:button {
    id = "renameButton",
    text = "&RENAME",
    focus = false,
    visible = defaults.showRenameButtons,
    onclick = function()
        local sprite <const> = app.sprite
        if not sprite then return end

        local oldTool <const> = app.tool.id
        app.tool = "slice"

        local range <const> = app.range
        if range.sprite ~= sprite then
            app.tool = oldTool
            return
        end

        -- Should this raise an alert warning like copy and delete do, and
        -- point out in the second line of text that names should not be
        -- treated as unique identifiers?

        local rangeSlices <const> = range.slices
        local lenRangeSlices <const> = #rangeSlices
        if lenRangeSlices < 1 then
            app.tool = oldTool
            app.alert {
                title = "Error",
                text = "No slices were selected."
            }
            return
        end

        local args <const> = dlgMain.data
        local newName <const> = args.nameEntry --[[@as string]]

        local newNameVrf = "Slice"
        if newName and #newName > 0 then
            newNameVrf = newName
        end

        if lenRangeSlices == 1 then
            app.transaction("Rename Slice", function()
                local activeSlice <const> = rangeSlices[1]
                activeSlice.name = newNameVrf
            end)
            app.tool = oldTool
            app.refresh()
            return
        end

        ---@type Slice[]
        local sortedSlices <const> = {}
        local i = 0
        while i < lenRangeSlices do
            i = i + 1
            sortedSlices[i] = rangeSlices[i]
        end
        table.sort(sortedSlices, tlComparator)

        local format <const> = "%s %d"
        local strfmt <const> = string.format

        local actFrObj <const> = app.frame or sprite.frames[1]
        app.frame = sprite.frames[1]

        app.transaction("Rename Slices", function()
            local j = 0
            while j < lenRangeSlices do
                j = j + 1
                local slice <const> = sortedSlices[j]
                slice.name = strfmt(format, newNameVrf, j)
            end
        end)

        app.frame = actFrObj
        app.tool = oldTool
        app.refresh()
    end
}

dlgMain:button {
    id = "tintButton",
    text = "C&OLOR",
    focus = false,
    visible = defaults.showRecolorButtons,
    onclick = function()
        local sprite <const> = app.sprite
        if not sprite then return end

        local oldTool <const> = app.tool.id
        app.tool = "slice"

        local range <const> = app.range
        if range.sprite ~= sprite then
            app.tool = oldTool
            return
        end

        local rangeSlices <const> = range.slices
        local lenRangeSlices <const> = #rangeSlices
        if lenRangeSlices < 1 then
            app.tool = oldTool
            app.alert {
                title = "Error",
                text = "No slices were selected."
            }
            return
        end

        local args <const> = dlgMain.data
        local origColor <const> = args.origColor --[[@as Color]]
        local destColor <const> = args.destColor --[[@as Color]]

        local aOrig <const> = math.min(math.max(origColor.alpha, 0), 255)
        local aDest <const> = math.min(math.max(destColor.alpha, 0), 255)

        if aOrig <= 0 or aDest <= 0 then
            app.tool = oldTool
            app.alert {
                title = "Error",
                text = "Colors may not have zero alpha."
            }
            return
        end

        ---@type Slice[]
        local sortedSlices <const> = {}
        local i = 0
        while i < lenRangeSlices do
            i = i + 1
            sortedSlices[i] = rangeSlices[i]
        end
        table.sort(sortedSlices, tlComparator)

        local jScl <const> = lenRangeSlices > 1
            and 1.0 / (lenRangeSlices - 1.0) or 0.0
        local jOff <const> = lenRangeSlices > 1 and 0.0 or 0.5

        local sOrig <const> = math.min(math.max(origColor.hslSaturation, 0.0), 1.0)
        local lOrig <const> = math.min(math.max(origColor.hslLightness, 0.0), 1.0)

        local sDest <const> = math.min(math.max(destColor.hslSaturation, 0.0), 1.0)
        local lDest <const> = math.min(math.max(destColor.hslLightness, 0.0), 1.0)

        local useRgbLerp <const> = (lOrig <= 0.0 or lOrig >= 1.0)
            or (lDest <= 0.0 or lDest >= 1.0)
            or sOrig <= 0.0
            or sDest <= 0.0

        local actFrObj <const> = app.frame or sprite.frames[1]
        app.frame = sprite.frames[1]

        if useRgbLerp then
            local rOrig <const> = math.min(math.max(origColor.red, 0), 255)
            local gOrig <const> = math.min(math.max(origColor.green, 0), 255)
            local bOrig <const> = math.min(math.max(origColor.blue, 0), 255)

            local rDest <const> = math.min(math.max(destColor.red, 0), 255)
            local gDest <const> = math.min(math.max(destColor.green, 0), 255)
            local bDest <const> = math.min(math.max(destColor.blue, 0), 255)

            app.transaction("Slice Color RGB", function()
                local j = 0
                while j < lenRangeSlices do
                    local t <const> = j * jScl + jOff
                    local u <const> = 1.0 - t

                    local rTrg <const> = round(u * rOrig + t * rDest)
                    local gTrg <const> = round(u * gOrig + t * gDest)
                    local bTrg <const> = round(u * bOrig + t * bDest)
                    local aTrg <const> = round(u * aOrig + t * aDest)

                    j = j + 1
                    local slice <const> = sortedSlices[j]
                    slice.color = Color {
                        red = rTrg,
                        green = gTrg,
                        blue = bTrg,
                        alpha = aTrg
                    }
                end
            end)
        else
            local hOrig <const> = origColor.hslHue
            local hDest <const> = destColor.hslHue

            app.transaction("Slice Color HSL", function()
                local j = 0
                while j < lenRangeSlices do
                    local t <const> = j * jScl + jOff
                    local u <const> = 1.0 - t

                    local hTrg <const> = lerpAngleCcw(hOrig, hDest, t, 360.0)
                    local sTrg <const> = u * sOrig + t * sDest
                    local lTrg <const> = u * lOrig + t * lDest
                    local aTrg <const> = round(u * aOrig + t * aDest)

                    j = j + 1
                    local slice <const> = sortedSlices[j]
                    slice.color = Color {
                        hue = hTrg,
                        saturation = sTrg,
                        lightness = lTrg,
                        alpha = aTrg
                    }
                end
            end)
        end

        app.frame = actFrObj
        app.tool = oldTool
        app.refresh()
    end
}

dlgMain:button {
    id = "swapColorsButton",
    text = "SWA&P",
    focus = false,
    visible = defaults.showRecolorButtons,
    onclick = function()
        local args <const> = dlgMain.data

        local origColor <const> = args.origColor --[[@as Color]]
        local rOrig <const> = math.min(math.max(origColor.red, 0), 255)
        local gOrig <const> = math.min(math.max(origColor.green, 0), 255)
        local bOrig <const> = math.min(math.max(origColor.blue, 0), 255)
        local aOrig <const> = math.min(math.max(origColor.alpha, 0), 255)

        local destColor <const> = args.destColor --[[@as Color]]
        local rDest <const> = math.min(math.max(destColor.red, 0), 255)
        local gDest <const> = math.min(math.max(destColor.green, 0), 255)
        local bDest <const> = math.min(math.max(destColor.blue, 0), 255)
        local aDest <const> = math.min(math.max(destColor.alpha, 0), 255)

        dlgMain:modify {
            id = "origColor",
            color = Color { r = rDest, g = gDest, b = bDest, a = aDest }
        }

        dlgMain:modify {
            id = "destColor",
            color = Color { r = rOrig, g = gOrig, b = bOrig, a = aOrig }
        }

        app.refresh()
    end
}

dlgMain:newrow { always = false }

dlgMain:button {
    id = "optionsButton",
    text = "OPTIONS",
    focus = true,
    visible = true,
    onclick = function()
        dlgOptions:show { autoscrollbars = true, wait = true }
    end
}

dlgMain:button {
    id = "exitMainButton",
    text = "&CANCEL",
    focus = false,
    onclick = function()
        dlgMain:close()
    end
}

-- endregion

-- region Options Menu

dlgOptions:check {
    id = "showSelectButtons",
    label = "Show:",
    text = "Select",
    selected = defaults.showSelectButtons,
    focus = false,
    onclick = function()
        local args <const> = dlgOptions.data
        local state <const> = args.showSelectButtons --[[@as boolean]]
        dlgMain:modify { id = "selectAllButton", visible = state }
        dlgMain:modify { id = "selectMaskButton", visible = state }
        dlgMain:modify { id = "deselectButton", visible = state }
    end
}

dlgOptions:check {
    id = "showFocusButtons",
    text = "Focus",
    selected = defaults.showFocusButtons,
    focus = false,
    onclick = function()
        local args <const> = dlgOptions.data
        local state <const> = args.showFocusButtons --[[@as boolean]]
        dlgMain:modify { id = "prevButton", visible = state }
        dlgMain:modify { id = "nextButton", visible = state }
    end
}

dlgOptions:check {
    id = "showEditButtons",
    text = "Edit",
    selected = defaults.showEditButtons,
    focus = false,
    onclick = function()
        local args <const> = dlgOptions.data
        local state <const> = args.showEditButtons --[[@as boolean]]
        dlgMain:modify { id = "copyButton", visible = state }
        dlgMain:modify { id = "deleteButton", visible = state }
    end
}

dlgOptions:newrow { always = false }

dlgOptions:check {
    id = "showConvertButtons",
    text = "Convert",
    selected = defaults.showConvertButtons,
    focus = false,
    onclick = function()
        local args <const> = dlgOptions.data
        local state <const> = args.showConvertButtons --[[@as boolean]]
        dlgMain:modify { id = "fromFramesButton", visible = state }
        dlgMain:modify { id = "maskToSliceButton", visible = state }
        dlgMain:modify { id = "sliceToMaskButton", visible = state }
    end
}

dlgOptions:check {
    id = "showNudgeButtons",
    text = "Nudge",
    selected = defaults.showNudgeButtons,
    focus = false,
    onclick = function()
        local args <const> = dlgOptions.data
        local state <const> = args.showNudgeButtons --[[@as boolean]]
        dlgMain:modify { id = "moveUpButton", visible = state }
        dlgMain:modify { id = "moveLeftButton", visible = state }
        dlgMain:modify { id = "moveDownButton", visible = state }
        dlgMain:modify { id = "moveRightButton", visible = state }

        local showChecks <const> = defaults.showNudgeChecks
            and state
        dlgMain:modify { id = "moveBounds", visible = showChecks }
        dlgMain:modify { id = "movePivot", visible = showChecks }
        dlgMain:modify { id = "moveInset", visible = showChecks }
    end
}

dlgOptions:check {
    id = "showSizeButtons",
    text = "Size",
    selected = defaults.showSizeButtons,
    focus = false,
    onclick = function()
        local args <const> = dlgOptions.data
        local state <const> = args.showSizeButtons --[[@as boolean]]
        dlgMain:modify { id = "width", visible = state }
        dlgMain:modify { id = "height", visible = state }
        dlgMain:modify { id = "resizeButton", visible = state }
    end
}

dlgOptions:newrow { always = false }

dlgOptions:check {
    id = "showInsetButtons",
    text = "Inset",
    selected = defaults.showInsetButtons,
    focus = false,
    onclick = function()
        local args <const> = dlgOptions.data
        local state <const> = args.showInsetButtons --[[@as boolean]]
        dlgMain:modify { id = "insetAmount", visible = state }
        dlgMain:modify { id = "insetButton", visible = state }
    end
}

dlgOptions:check {
    id = "showPivotButtons",
    text = "Pivot",
    selected = defaults.showPivotButtons,
    focus = false,
    onclick = function()
        local args <const> = dlgOptions.data
        local state <const> = args.showPivotButtons --[[@as boolean]]
        dlgMain:modify { id = "pivotCombo", visible = state }
        dlgMain:modify { id = "setPivotButton", visible = state }
    end
}

dlgOptions:newrow { always = false }

dlgOptions:check {
    id = "showRenameButtons",
    text = "Name",
    selected = defaults.showRenameButtons,
    focus = false,
    onclick = function()
        local args <const> = dlgOptions.data
        local state <const> = args.showRenameButtons --[[@as boolean]]
        dlgMain:modify { id = "nameEntry", visible = state }
        dlgMain:modify { id = "renameButton", visible = state }
    end
}

dlgOptions:check {
    id = "showRecolorButtons",
    text = "Color",
    selected = defaults.showRecolorButtons,
    focus = false,
    onclick = function()
        local args <const> = dlgOptions.data
        local state <const> = args.showRecolorButtons --[[@as boolean]]
        dlgMain:modify { id = "origColor", visible = state }
        dlgMain:modify { id = "destColor", visible = state }
        dlgMain:modify { id = "tintButton", visible = state }
        dlgMain:modify { id = "swapColorsButton", visible = state }
    end
}

dlgOptions:newrow { always = false }

dlgOptions:button {
    id = "exitOptionsButton",
    text = "CLOSE",
    focus = true,
    onclick = function()
        dlgOptions:close()
    end
}

-- endregion

dlgMain:show {
    autoscrollbars = true,
    wait = false
}