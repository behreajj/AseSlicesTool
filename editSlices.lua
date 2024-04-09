-- TODO: Option to create a slice for each cel in a range at the active frame
-- &FRAME, get layers from range if the range is not of type frame and is not
-- empty, otherwise get all layers in hierarchy. Then change label to Convert
-- and change names of &FROM and &TO to MAS&K and something else... maybe
-- SLIC&E, then change E shortcut to T shortcut for DELE&TE.

--[[Slices have an internal reference to the frame on which they were
    created. This reference cannot be accessed via Lua script.
]]

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
        -- TODO: Might be nice to sort by tl + pivot, if pivot is set.
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

    local abs <const> = math.abs
    local max <const> = math.max

    app.transaction(string.format("Nudge Slices (%d, %d)", dx, dy), function()
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

local wSet = 24
local hSet = 24
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
        -- bar may not be visible.

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
    id = "copyButton",
    label = "Edit:",
    text = "COP&Y",
    focus = false,
    onclick = function()
        local useColorInvert <const> = true

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
            text = {
                "Are you sure you want to copy these slices?",
                "Custom data and properties will NOT be copied.",
                "A slice's frame cannot be copied."
            },
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

        local defaultColor = Color {
            r = 255,
            g = 255,
            b = 255,
            a = 255
        }
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

        local oldActiveFrame <const> = app.frame
        app.frame = 1

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

                            if useColorInvert then
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

        app.frame = oldActiveFrame
        range.slices = duplicates
        app.tool = oldTool
        app.refresh()
    end
}

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

            local args <const> = dlg.data
            local inset <const> = args.insetAmount --[[@as integer]]
            local pivotCombo <const> = args.pivotCombo --[[@as string]]
            local newName <const> = args.nameEntry --[[@as string]]

            local newNameVrf = "Slice"
            if newName and #newName > 0 then
                newNameVrf = newName
            end

            local xtlInset <const> = inset
            local ytlInset <const> = inset
            local xbrInset <const> = (w - 1) - inset
            local ybrInset <const> = (h - 1) - inset

            local trgColor = Color {
                r = 255,
                g = 255,
                b = 255,
                a = 255
            }
            local appPrefs <const> = app.preferences
            if appPrefs then
                local slicePrefs <const> = appPrefs.slices
                if slicePrefs then
                    local prefsColor <const> = slicePrefs.default_color --[[@as Color]]
                    if prefsColor then
                        if prefsColor.alpha > 0 then
                            trgColor = Color {
                                r = math.min(math.max(prefsColor.red, 0), 255),
                                g = math.min(math.max(prefsColor.green, 0), 255),
                                b = math.min(math.max(prefsColor.blue, 0), 255),
                                a = math.min(math.max(prefsColor.alpha, 0), 255)
                            }
                        end
                    end
                end
            end

            local oldActiveFrame <const> = app.frame
            app.frame = 1

            app.transaction("New Slice From Mask", function()
                local slice <const> = sprite:newSlice(
                    Rectangle(x, y, w, h))
                slice.color = trgColor
                slice.name = newNameVrf

                if xtlInset < xbrInset and ytlInset < ybrInset then
                    local wInset <const> = 1 + xbrInset - xtlInset
                    local hInset <const> = 1 + ybrInset - ytlInset
                    slice.center = Rectangle(xtlInset, ytlInset, wInset, hInset)
                end

                if pivotCombo == "TOP_LEFT" then
                    slice.pivot = Point(0, 0)
                elseif pivotCombo == "TOP_CENTER" then
                    slice.pivot = Point(w // 2, 0)
                elseif pivotCombo == "TOP_RIGHT" then
                    slice.pivot = Point(w - 1, 0)
                elseif pivotCombo == "CENTER_LEFT" then
                    slice.pivot = Point(0, h // 2)
                elseif pivotCombo == "CENTER" then
                    slice.pivot = Point(w // 2, h // 2)
                elseif pivotCombo == "CENTER_RIGHT" then
                    slice.pivot = Point(w - 1, h // 2)
                elseif pivotCombo == "BOTTOM_LEFT" then
                    slice.pivot = Point(0, h - 1)
                elseif pivotCombo == "BOTTOM_CENTER" then
                    slice.pivot = Point(w // 2, h - 1)
                elseif pivotCombo == "BOTTOM_RIGHT" then
                    slice.pivot = Point(w - 1, h - 1)
                end

                local range <const> = app.range
                if range.sprite == sprite then
                    range.slices = { slice }
                end
            end)

            app.frame = oldActiveFrame
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

dlg:number {
    id = "width",
    -- label = "Pixels:",
    label = "Size:",
    text = string.format("%d", wSet),
    decimals = 0,
    visible = true
}

dlg:number {
    id = "height",
    text = string.format("%d", hSet),
    decimals = 0,
    visible = true
}

dlg:newrow { always = false }

dlg:button {
    id = "resizeButton",
    text = "RESI&ZE",
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
        local width <const> = args.width --[[@as integer]]
        local height <const> = args.height --[[@as integer]]

        local wSprite <const> = sprite.width
        local hSprite <const> = sprite.height
        local wVerif <const> = math.max(2, math.abs(width))
        local hVerif <const> = math.max(2, math.abs(height))

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
                    local wSrc <const> = max(2, abs(srcBounds.width))
                    local hSrc <const> = max(2, abs(srcBounds.height))

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

                    local xRatio <const> = (wTrg - 1.0) / (wSrc - 1.0)
                    local yRatio <const> = (hTrg - 1.0) / (hSrc - 1.0)

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
                            local wInsetSrc <const> = max(2, abs(srcInset.width))
                            local hInsetSrc <const> = max(2, abs(srcInset.height))

                            local xbrInsetSrc <const> = xtlInsetSrc + wInsetSrc - 1
                            local ybrInsetSrc <const> = ytlInsetSrc + hInsetSrc - 1

                            local xtlInsetTrg = round(xtlInsetSrc * xRatio)
                            local ytlInsetTrg = round(ytlInsetSrc * yRatio)
                            local xbrInsetTrg = round(xbrInsetSrc * xRatio)
                            local ybrInsetTrg = round(ybrInsetSrc * yRatio)
                            if xtlInsetTrg < xbrInsetTrg
                                and ytlInsetTrg < ybrInsetTrg then
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

dlg:newrow { always = false }

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

dlg:entry {
    id = "nameEntry",
    label = "Name:",
    focus = false,
    text = "Slice"
}

dlg:newrow { always = false }

dlg:color {
    id = "origColor",
    label = "Mix:",
    color = Color { r = 254, g = 91, b = 89, a = 255 }
}

dlg:color {
    id = "destColor",
    color = Color { r = 106, g = 205, b = 91, a = 255 }
}

dlg:newrow { always = false }

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

        app.tool = oldTool
        app.refresh()
    end
}

dlg:button {
    id = "swapColorsButton",
    text = "SWA&P",
    focus = false,
    visible = true,
    onclick = function()
        local args <const> = dlg.data

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
