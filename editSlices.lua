-- TODO: Duplicate slice feature?
-- TODO: Expand slice size?

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

---@param dx integer
---@param dy integer
local function translateSlices(dx, dy)
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

    local dxNonZero <const> = dx ~= 0
    local dyNonZero <const> = dy ~= 0
    local wSprite <const> = sprite.width
    local hSprite <const> = sprite.height

    local xGrOff = 0
    local yGrOff = 0
    local xGrScl = 1
    local yGrScl = 1
    local docPrefs <const> = app.preferences.document(sprite)
    local useSnap <const> = docPrefs.grid.snap --[[@as boolean]]
    if useSnap then
        local grid <const> = sprite.gridBounds
        xGrOff = grid.x
        yGrOff = grid.y
        xGrScl = math.max(1, math.abs(grid.width))
        yGrScl = math.max(1, math.abs(grid.height))
    end

    local abs <const> = math.abs
    local max <const> = math.max

    app.transaction(string.format("Move Slices (%d, %d)", dx, dy), function()
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
                end
            end
        end
    end)

    app.tool = oldTool
    app.refresh()
end

local dlg <const> = Dialog { title = "Edit Slices" }

dlg:button {
    id = "selectAllButton",
    text = "A&LL",
    label = "Select:",
    focus = true,
    visible = true,
    onclick = function()
        -- Aseprite UI already contains function for this, but slice context
        -- toolbar may not be visible.

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

        ---@type Slice[]
        local assignSlices <const> = {}
        local i = 0
        while i < lenSpriteSlices do
            i = i + 1
            local spriteSlice <const> = spriteSlices[i]
            assignSlices[i] = spriteSlice
        end

        range.slices = assignSlices
        app.tool = oldTool
        app.refresh()
    end
}

dlg:button {
    id = "selectMaskButton",
    text = "&MASK",
    focus = false,
    visible = true,
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
        app.tool = oldTool
        app.refresh()
    end
}

dlg:button {
    id = "selectNoneButton",
    text = "&NONE",
    focus = false,
    visible = true,
    onclick = function()
        -- Aseprite UI already contains function for this, but slice context
        -- toolbar may not be visible.

        local sprite <const> = app.sprite
        if not sprite then return end

        local oldTool <const> = app.tool.id
        app.tool = "slice"

        local range <const> = app.range
        if range.sprite ~= sprite then
            app.tool = oldTool
            return
        end

        range.slices = {}

        app.tool = oldTool
        app.refresh()
    end
}

dlg:newrow { always = false }

dlg:button {
    id = "deleteButton",
    text = "D&ELETE",
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

        local response <const> = app.alert {
            title = "Warning",
            text = "Are you sure you want to delete these slices?",
            buttons = { "&YES", "&NO" }
        }
        if response == 2 then
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

        app.tool = oldTool
        app.refresh()
    end
}

dlg:newrow { always = false }

dlg:button {
    id = "fromMaskButton",
    text = "&FROM",
    label = "Mask:",
    focus = false,
    onclick = function()
        local sprite <const> = app.sprite
        if not sprite then return end

        -- This prevents errors when mask is in a transform preview state.
        app.command.InvertMask()
        app.command.InvertMask()

        local srcMask <const> = sprite.selection
        if srcMask and (not srcMask.isEmpty) then
            local oldTool <const> = app.tool.id
            app.tool = "slice"

            local maskBounds <const> = srcMask.bounds
            local x <const> = maskBounds.x
            local y <const> = maskBounds.y
            local w <const> = math.max(1, math.abs(maskBounds.width))
            local h <const> = math.max(1, math.abs(maskBounds.height))

            app.transaction("New Slice From Mask", function()
                local slice <const> = sprite:newSlice(
                    Rectangle(x, y, w, h))
                local appPrefs <const> = app.preferences
                local slicePrefs <const> = appPrefs.slices
                local defaultColor <const> = slicePrefs.default_color --[[@as Color]]
                if defaultColor then
                    slice.color = defaultColor
                end

                local range <const> = app.range
                if range.sprite == sprite then
                    range.slices = { slice }
                end
            end)

            app.tool = oldTool
        else
            app.alert {
                title = "Error",
                text = "Mask is empty."
            }
        end

        app.refresh()
    end
}

dlg:button {
    id = "toMaskButton",
    text = "&TO",
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

        local abs <const> = math.abs
        local max <const> = math.max

        local mask <const> = Selection()

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

        app.tool = oldTool
        app.refresh()
    end
}

dlg:newrow { always = false }

dlg:button {
    id = "moveUpButton",
    text = "&W",
    label = "Nudge:",
    focus = false,
    onclick = function()
        translateSlices(0, -1)
    end
}

dlg:button {
    id = "moveLeftButton",
    text = "&A",
    focus = false,
    onclick = function()
        translateSlices(-1, 0)
    end
}

dlg:button {
    id = "moveDownButton",
    text = "&S",
    focus = false,
    onclick = function()
        translateSlices(0, 1)
    end
}

dlg:button {
    id = "moveRightButton",
    text = "&D",
    focus = false,
    onclick = function()
        translateSlices(1, 0)
    end
}

dlg:newrow { always = false }

dlg:entry {
    id = "nameEntry",
    label = "Name:",
    focus = false,
    text = "Slice"
}

dlg:button {
    id = "renameButton",
    text = "&RENAME",
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

        local args <const> = dlg.data
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

        app.transaction("Rename Slices", function()
            local j = 0
            while j < lenRangeSlices do
                j = j + 1
                local slice <const> = sortedSlices[j]
                slice.name = strfmt(format, newNameVrf, j)
            end
        end)

        app.tool = oldTool
        app.refresh()
    end
}

dlg:newrow { always = false }

dlg:slider {
    id = "insetAmount",
    label = "Amount:",
    min = 0,
    max = 96,
    value = 0,
    focus = false
}

dlg:button {
    id = "insetButton",
    text = "&INSET",
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

        local args <const> = dlg.data
        local inset <const> = args.insetAmount --[[@as integer]]

        local abs <const> = math.abs
        local max <const> = math.max

        app.transaction(string.format("Slice Inset %d", inset), function()
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

                    local xtlTrg <const> = inset
                    local ytlTrg <const> = inset
                    local xbrTrg <const> = xbrSrc - inset
                    local ybrTrg <const> = ybrSrc - inset

                    if xtlTrg < xbrTrg and ytlTrg < ybrTrg then
                        local wTrg <const> = 1 + xbrTrg - xtlTrg
                        local hTrg <const> = 1 + ybrTrg - ytlTrg
                        slice.center = Rectangle(xtlTrg, ytlTrg, wTrg, hTrg)
                    end
                end
            end
        end)

        app.tool = oldTool
        app.refresh()
    end
}

dlg:newrow { always = false }

dlg:combobox {
    id = "pivotCombo",
    label = "Preset:",
    option = "TOP_LEFT",
    options = {
        "TOP_LEFT", "TOP_CENTER", "TOP_RIGHT",
        "CENTER_LEFT", "CENTER", "CENTER_RIGHT",
        "BOTTOM_LEFT", "BOTTOM_CENTER", "BOTTOM_RIGHT"
    }
}

dlg:button {
    id = "setPivotButton",
    text = "PI&VOT",
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

        local args <const> = dlg.data
        local pivotCombo <const> = args.pivotCombo --[[@as string]]

        local abs <const> = math.abs
        local max <const> = math.max

        if pivotCombo == "TOP_LEFT" then
            app.transaction("Slice Pivot Top Left", function()
                local i = 0
                while i < lenSlices do
                    i = i + 1
                    local slice <const> = slices[i]
                    slice.pivot = Point(0, 0)
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

        app.tool = oldTool
        app.refresh()
    end
}

dlg:newrow { always = false }

dlg:color {
    id = "origColor",
    label = "Orig:",
    color = Color { r = 254, g = 91, b = 89, a = 255 }
}

dlg:color {
    id = "destColor",
    label = "Dest:",
    color = Color { r = 106, g = 205, b = 91, a = 255 }
}

dlg:newrow { always = false }

dlg:button {
    id = "swapColorsButton",
    text = "SWA&P",
    focus = false,
    onclick = function()
        local args <const> = dlg.data

        local origColor <const> = args.origColor --[[@as Color]]
        local rOrig <const> = origColor.red
        local gOrig <const> = origColor.green
        local bOrig <const> = origColor.blue
        local aOrig <const> = origColor.alpha

        local destColor <const> = args.destColor --[[@as Color]]
        local rDest <const> = destColor.red
        local gDest <const> = destColor.green
        local bDest <const> = destColor.blue
        local aDest <const> = destColor.alpha

        dlg:modify {
            id = "origColor",
            color = Color { r = rDest, g = gDest, b = bDest, a = aDest }
        }

        dlg:modify {
            id = "destColor",
            color = Color { r = rOrig, g = gOrig, b = bOrig, a = aOrig }
        }

        app.refresh()
    end
}

dlg:button {
    id = "tintButton",
    text = "C&OLOR",
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

        local args <const> = dlg.data
        local origColor <const> = args.origColor --[[@as Color]]
        local destColor <const> = args.destColor --[[@as Color]]

        if origColor.alpha <= 0 or destColor.alpha <= 0 then return end

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

        local hOrig <const> = origColor.hslHue % 360.0
        local sOrig <const> = math.min(math.max(origColor.hslSaturation, 0.0), 1.0)
        local lOrig <const> = math.min(math.max(origColor.hslLightness, 0.0), 1.0)
        local aOrig <const> = math.min(math.max(origColor.alpha, 0), 255)

        local hDest <const> = destColor.hslHue % 360.0
        local sDest <const> = math.min(math.max(destColor.hslSaturation, 0.0), 1.0)
        local lDest <const> = math.min(math.max(destColor.hslLightness, 0.0), 1.0)
        local aDest <const> = math.min(math.max(destColor.alpha, 0), 255)

        app.transaction("Slice Color", function()
            local j = 0
            while j < lenRangeSlices do
                local t <const> = j * jScl + jOff
                local u <const> = 1.0 - t

                local hTrg <const> = (u * hOrig + t * hDest) % 360.0
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

        app.tool = oldTool
        app.refresh()
    end
}

dlg:newrow { always = false }

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
