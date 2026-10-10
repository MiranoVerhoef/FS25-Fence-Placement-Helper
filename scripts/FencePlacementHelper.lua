-- FS25_FencePlacementHelper
-- Author: Verhoef
--
-- Adds a live heading/deviation guide to ConstructionBrushNewFence and can split
-- long fence placements into native FS25 fence segments. The split segments use
-- GIANTS' normal FenceNewSegmentEvent path, so they are saved, synchronized and
-- deleted by the normal fence demolition system.

FencePlacementHelper = {}
FencePlacementHelper.MOD_NAME = g_currentModName or "FS25_FencePlacementHelper"
FencePlacementHelper.VERSION = "1.0.0.0"

FencePlacementHelper.SECTION_LENGTHS = {0, 10, 25, 50, 100}
FencePlacementHelper.sectionIndex = 3
FencePlacementHelper.MAX_AUTO_SECTIONS = 512
FencePlacementHelper.MIN_REMAINING_LENGTH = 0.5
FencePlacementHelper.GUIDE_LOCK_DISTANCE = 3.0
FencePlacementHelper.CORNER_LOCK_DISTANCE = 0.75
FencePlacementHelper.GUIDE_RESET_DISTANCE = 0.10
FencePlacementHelper.guideSnapEnabled = true
FencePlacementHelper.enabled = true

-- Guide modes: local fence/free heading or nearest world 45°.
FencePlacementHelper.GUIDE_MODES = {"WORLD_90", "LOCAL", "WORLD_45"}
FencePlacementHelper.guideModeIndex = 1


function FencePlacementHelper:getMasterText()
    return self.enabled and "ON" or "OFF"
end

function FencePlacementHelper:setFeatureActionsActive(screen, active)
    if screen == nil or g_inputBinding == nil or g_inputBinding.setActionEventActive == nil then
        return
    end

    local featureEvents = {
        screen.fphSectionActionEventId,
        screen.fphGuideActionEventId,
        screen.fphGuideSnapActionEventId,
        screen.fphGuideModeActionEventId
    }

    for _, eventId in ipairs(featureEvents) do
        if eventId ~= nil then
            g_inputBinding:setActionEventActive(eventId, active)
        end
    end
end

function FencePlacementHelper:updateMasterActionText(screen)
    screen = screen or g_constructionScreen
    if screen == nil or screen.fphMasterActionEventId == nil then
        return
    end

    g_inputBinding:setActionEventText(
        screen.fphMasterActionEventId,
        string.format("Fence Placement Helper: %s", self:getMasterText())
    )
    g_inputBinding:setActionEventTextPriority(screen.fphMasterActionEventId, GS_PRIO_VERY_HIGH)
end

function FencePlacementHelper:onToggleMaster(actionName, inputValue, callbackState, isAnalog)
    self.enabled = not self.enabled

    local screen = g_constructionScreen
    if screen ~= nil and self:isNewFenceBrush(screen.brush) then
        if not self.enabled then
            self:clearGuideReference(screen.brush)
            screen.brush.fphRawCursorX = nil
            screen.brush.fphRawCursorY = nil
            screen.brush.fphRawCursorZ = nil
        end

        self:setFeatureActionsActive(screen, self.enabled)
    end

    self:updateMasterActionText(screen)
end

function FencePlacementHelper:registerMasterAction(screen)
    if screen == nil or not self:isNewFenceBrush(screen.brush) then
        return
    end

    local action = InputAction ~= nil and InputAction.FPH_TOGGLE_MASTER or nil
    if action == nil then
        return
    end

    local _, eventId = g_inputBinding:registerActionEvent(
        action,
        self,
        self.onToggleMaster,
        false,
        true,
        false,
        true
    )

    if eventId ~= nil then
        screen.fphMasterActionEventId = eventId
        table.insert(screen.brushEvents, eventId)
        self:updateMasterActionText(screen)
        self:setFeatureActionsActive(screen, self.enabled)
    end
end

function FencePlacementHelper:getSectionLength()
    return self.SECTION_LENGTHS[self.sectionIndex] or 0
end

function FencePlacementHelper:getSectionModeText()
    local length = self:getSectionLength()
    if length <= 0 then
        return "OFF"
    end
    return string.format("%d m", length)
end

function FencePlacementHelper:isNewFenceBrush(brush)
    if brush == nil or ConstructionBrushNewFence == nil then
        return false
    end

    if brush.isa ~= nil then
        return brush:isa(ConstructionBrushNewFence)
    end

    return brush.getLimitedSnappedCursorPosition ~= nil
        and brush.createNextSegment ~= nil
        and brush.onServerCreatedFenceCallback ~= nil
        and brush.supportsSnapping == true
end

function FencePlacementHelper:updateSectionActionText(screen)
    screen = screen or g_constructionScreen
    if screen == nil or screen.fphSectionActionEventId == nil then
        return
    end

    local text = string.format("Fence sections: %s", self:getSectionModeText())
    g_inputBinding:setActionEventText(screen.fphSectionActionEventId, text)
    g_inputBinding:setActionEventTextPriority(screen.fphSectionActionEventId, GS_PRIO_HIGH)
end

function FencePlacementHelper:onCycleSectionLength(actionName, inputValue, callbackState, isAnalog)
    if not self.enabled then
        return
    end

    self.sectionIndex = (self.sectionIndex % #self.SECTION_LENGTHS) + 1
    self:updateSectionActionText(g_constructionScreen)
end

function FencePlacementHelper:registerFenceHelperAction(screen)
    if screen == nil or not self:isNewFenceBrush(screen.brush) then
        return
    end

    local action = InputAction ~= nil and InputAction.FPH_CYCLE_SECTION_LENGTH or nil
    if action == nil then
        return
    end

    local _, eventId = g_inputBinding:registerActionEvent(
        action,
        self,
        self.onCycleSectionLength,
        false,
        true,
        false,
        true
    )

    if eventId ~= nil then
        screen.fphSectionActionEventId = eventId
        table.insert(screen.brushEvents, eventId)
        self:updateSectionActionText(screen)
    end
end

function FencePlacementHelper:clearFenceHelperAction(screen)
    if screen ~= nil then
        screen.fphSectionActionEventId = nil
    end
end


function FencePlacementHelper:getGuideSnapText()
    return self.guideSnapEnabled and "ON" or "OFF"
end

function FencePlacementHelper:updateGuideSnapActionText(screen)
    screen = screen or g_constructionScreen
    if screen == nil or screen.fphGuideSnapActionEventId == nil then
        return
    end

    g_inputBinding:setActionEventText(
        screen.fphGuideSnapActionEventId,
        string.format("Snap to fence guide: %s", self:getGuideSnapText())
    )
    g_inputBinding:setActionEventTextPriority(screen.fphGuideSnapActionEventId, GS_PRIO_HIGH)
end

function FencePlacementHelper:onToggleGuideSnap(actionName, inputValue, callbackState, isAnalog)
    if not self.enabled then
        return
    end

    self.guideSnapEnabled = not self.guideSnapEnabled
    self:updateGuideSnapActionText(g_constructionScreen)
end

function FencePlacementHelper:registerGuideSnapAction(screen)
    if screen == nil or not self:isNewFenceBrush(screen.brush) then
        return
    end

    local action = InputAction ~= nil and InputAction.FPH_TOGGLE_GUIDE_SNAP or nil
    if action == nil then
        return
    end

    local _, eventId = g_inputBinding:registerActionEvent(
        action,
        self,
        self.onToggleGuideSnap,
        false,
        true,
        false,
        true
    )

    if eventId ~= nil then
        screen.fphGuideSnapActionEventId = eventId
        table.insert(screen.brushEvents, eventId)
        self:updateGuideSnapActionText(screen)
    end
end


function FencePlacementHelper:getGuideMode()
    return self.GUIDE_MODES[self.guideModeIndex] or "LOCAL"
end

function FencePlacementHelper:getGuideModeText()
    local mode = self:getGuideMode()

    if mode == "WORLD_90" then
        return "World 0° / 90°"
    elseif mode == "WORLD_45" then
        return "World 45°"
    end

    return "Local / fence"
end

function FencePlacementHelper:updateGuideModeActionText(screen)
    screen = screen or g_constructionScreen
    if screen == nil or screen.fphGuideModeActionEventId == nil then
        return
    end

    g_inputBinding:setActionEventText(
        screen.fphGuideModeActionEventId,
        string.format("Fence guide mode: %s", self:getGuideModeText())
    )
    g_inputBinding:setActionEventTextPriority(screen.fphGuideModeActionEventId, GS_PRIO_HIGH)
end

function FencePlacementHelper:onCycleGuideMode(actionName, inputValue, callbackState, isAnalog)
    if not self.enabled then
        return
    end

    self.guideModeIndex = (self.guideModeIndex % #self.GUIDE_MODES) + 1

    local screen = g_constructionScreen
    if screen ~= nil and self:isNewFenceBrush(screen.brush) then
        self:clearGuideReference(screen.brush)
    end

    self:updateGuideModeActionText(screen)
end

function FencePlacementHelper:registerGuideModeAction(screen)
    if screen == nil or not self:isNewFenceBrush(screen.brush) then
        return
    end

    local action = InputAction ~= nil and InputAction.FPH_CYCLE_GUIDE_MODE or nil
    if action == nil then
        return
    end

    local _, eventId = g_inputBinding:registerActionEvent(
        action,
        self,
        self.onCycleGuideMode,
        false,
        true,
        false,
        true
    )

    if eventId ~= nil then
        screen.fphGuideModeActionEventId = eventId
        table.insert(screen.brushEvents, eventId)
        self:updateGuideModeActionText(screen)
    end
end

local function getTerrainY(x, z, fallbackY)
    if g_terrainNode ~= nil and g_terrainNode ~= 0 then
        return getTerrainHeightAtWorldPos(g_terrainNode, x, 0, z)
    end
    return fallbackY or 0
end

local function normalizeHeading(degrees)
    degrees = degrees % 360
    if degrees < 0 then
        degrees = degrees + 360
    end
    return degrees
end

local function signedAngleDifference(a, b)
    return ((a - b + 180) % 360) - 180
end

local function nearestWorld45Heading(heading)
    if heading == nil then
        return nil
    end

    return normalizeHeading(math.floor((heading + 22.5) / 45) * 45)
end

local function nearestWorld90Heading(heading)
    if heading == nil then
        return nil
    end

    return normalizeHeading(math.floor((heading + 45) / 90) * 90)
end

local function nearestRightAngleHeading(cursorHeading, baseHeading)
    if cursorHeading == nil or baseHeading == nil then
        return nil, nil
    end

    local bestHeading = nil
    local bestIndex = nil
    local bestDifference = math.huge

    for i = 0, 3 do
        local candidate = normalizeHeading(baseHeading + i * 90)
        local difference = math.abs(signedAngleDifference(cursorHeading, candidate))
        if difference < bestDifference then
            bestDifference = difference
            bestHeading = candidate
            bestIndex = i
        end
    end

    return bestHeading, bestIndex
end

local function getHeadingFromVector(dx, dz)
    if dx == nil or dz == nil or (math.abs(dx) < 0.0001 and math.abs(dz) < 0.0001) then
        return nil
    end
    return normalizeHeading(math.deg(math.atan2(dx, dz)))
end

local function getSegmentHeading(segment)
    if segment == nil or segment.getStartPos == nil or segment.getEndPos == nil then
        return nil
    end

    local sx, _, sz = segment:getStartPos()
    local ex, _, ez = segment:getEndPos()
    if sx == nil or ex == nil then
        return nil
    end

    return getHeadingFromVector(ex - sx, ez - sz)
end

function FencePlacementHelper:clearGuideReference(brush)
    if brush ~= nil then
        brush.fphGuideReference = nil
    end
end

function FencePlacementHelper:setGuideReference(brush, anchorX, anchorY, anchorZ, heading, source)
    if brush == nil or heading == nil then
        return false
    end

    brush.fphGuideReference = {
        anchorX = anchorX,
        anchorY = anchorY,
        anchorZ = anchorZ,
        heading = normalizeHeading(heading),
        source = source or "locked"
    }
    return true
end

function FencePlacementHelper:findExistingFenceReference(brush, sx, sy, sz)
    if brush.parallelSnappingSegment ~= nil then
        local heading = getSegmentHeading(brush.parallelSnappingSegment)
        if heading ~= nil then
            return heading, "parallel fence"
        end
    end

    if brush.fence ~= nil and brush.fence.getSegmentById ~= nil
        and brush.segmentIds ~= nil and #brush.segmentIds > 0 then
        local lastId = brush.segmentIds[#brush.segmentIds]
        local lastSegment = brush.fence:getSegmentById(lastId)
        if lastSegment ~= nil then
            local ex, ey, ez = lastSegment:getEndPos()
            local ssx, ssy, ssz = lastSegment:getStartPos()
            local touchesStart = false

            if ex ~= nil then
                touchesStart = math.sqrt((ex - sx) ^ 2 + (ez - sz) ^ 2) < 0.55
            end
            if not touchesStart and ssx ~= nil then
                touchesStart = math.sqrt((ssx - sx) ^ 2 + (ssz - sz) ^ 2) < 0.55
            end

            if touchesStart then
                local heading = getSegmentHeading(lastSegment)
                if heading ~= nil then
                    return heading, "previous fence"
                end
            end
        end
    end

    if brush.fence ~= nil and brush.fence.getNearPoleSegment ~= nil then
        local segment = brush.fence:getNearPoleSegment(sx, sy, sz, 0.5, nil)
        local heading = getSegmentHeading(segment)
        if heading ~= nil then
            return heading, "existing fence"
        end
    end

    return nil, nil
end

function FencePlacementHelper:getGuideGeometry(brush)
    if brush == nil then
        return nil
    end

    local state = brush.fphSectionState
    if state ~= nil then
        return state.originalStartX, state.originalStartY, state.originalStartZ,
            state.targetX, state.targetY, state.targetZ
    end

    local segment = brush.currentSegment
    if segment == nil then
        return nil
    end

    local sx, sy, sz = segment:getStartPos()
    if sx == nil then
        return nil
    end

    local ex, ey, ez = segment:getEndPos()
    if ex == nil then
        ex, ey, ez = brush:getLimitedSnappedCursorPosition()
    end

    if ex == nil then
        return nil
    end

    return sx, sy, sz, ex, ey, ez
end

function FencePlacementHelper:ensureGuideReference(brush, sx, sy, sz, ex, ey, ez)
    if brush == nil then
        return nil
    end

    local guideMode = self:getGuideMode()

    if guideMode == "WORLD_90" then
        local heading = getHeadingFromVector(ex - sx, ez - sz)
        local worldHeading = nearestWorld90Heading(heading)

        if worldHeading == nil then
            return nil
        end

        return {
            anchorX = sx,
            anchorY = sy,
            anchorZ = sz,
            heading = worldHeading,
            source = "world 0° / 90°"
        }
    end

    if guideMode == "WORLD_45" then
        local heading = getHeadingFromVector(ex - sx, ez - sz)
        local worldHeading = nearestWorld45Heading(heading)

        if worldHeading == nil then
            return nil
        end

        return {
            anchorX = sx,
            anchorY = sy,
            anchorZ = sz,
            heading = worldHeading,
            source = "world 45°"
        }
    end

    local dx = ex - sx
    local dz = ez - sz
    local length = math.sqrt(dx * dx + dz * dz)
    local cursorHeading = getHeadingFromVector(dx, dz)

    local ref = brush.fphGuideReference
    if ref ~= nil then
        if length < self.GUIDE_RESET_DISTANCE then
            brush.fphGuideReference = nil
            ref = nil
        else
            local anchorDistance = math.sqrt((sx - ref.anchorX) ^ 2 + (sz - ref.anchorZ) ^ 2)
            if anchorDistance < 0.15 then
                return ref
            end

            brush.fphGuideReference = nil
            ref = nil
        end
    end

    local existingHeading, source = self:findExistingFenceReference(brush, sx, sy, sz)
    if existingHeading ~= nil then
        if source == "parallel fence" then
            self:setGuideReference(brush, sx, sy, sz, existingHeading, source)
            return brush.fphGuideReference
        end

        if length >= self.CORNER_LOCK_DISTANCE and cursorHeading ~= nil then
            local chosenHeading, quarterIndex = nearestRightAngleHeading(cursorHeading, existingHeading)
            if chosenHeading ~= nil then
                local chosenSource
                if quarterIndex == 1 or quarterIndex == 3 then
                    chosenSource = "90° corner"
                else
                    chosenSource = "straight continuation"
                end

                self:setGuideReference(brush, sx, sy, sz, chosenHeading, chosenSource)
                return brush.fphGuideReference
            end
        end

        return nil
    end

    if length >= self.GUIDE_LOCK_DISTANCE and cursorHeading ~= nil then
        self:setGuideReference(brush, sx, sy, sz, cursorHeading, "free heading")
        return brush.fphGuideReference
    end

    return nil
end


function FencePlacementHelper:isMandatoryHusbandryEnd(brush, x, y, z)
    if brush == nil or not brush.hasSnapPositions or brush.snapEnd == nil or x == nil then
        return false
    end

    local ex = brush.snapEnd[1]
    local ey = brush.snapEnd[2]
    local ez = brush.snapEnd[3]
    if ex == nil or ez == nil then
        return false
    end

    local dy = 0
    if y ~= nil and ey ~= nil then
        dy = y - ey
    end

    local dx = x - ex
    local dz = z - ez
    return math.sqrt(dx * dx + dy * dy + dz * dz) < 0.11
end

function FencePlacementHelper:snapPositionToGuide(brush, x, y, z, isSnapped, snappedSegment)
    if not self.enabled
        or not self.guideSnapEnabled
        or brush == nil
        or x == nil
        or brush.gateIndex ~= nil
        or brush.fphSectionState ~= nil then
        return x, y, z, isSnapped, snappedSegment
    end

    local segment = brush.currentSegment
    if segment == nil then
        return x, y, z, isSnapped, snappedSegment
    end

    local sx, sy, sz = segment:getStartPos()
    if sx == nil then
        return x, y, z, isSnapped, snappedSegment
    end

    brush.fphRawCursorX = x
    brush.fphRawCursorY = y
    brush.fphRawCursorZ = z

    -- Husbandry fences must keep their native final snap point.
    brush.fphMandatoryEndSnap = self:isMandatoryHusbandryEnd(brush, x, y, z)
    if brush.fphMandatoryEndSnap then
        return x, y, z, isSnapped, snappedSegment
    end

    local ref = self:ensureGuideReference(brush, sx, sy, sz, x, y, z)
    if ref == nil then
        return x, y, z, isSnapped, snappedSegment
    end

    if snappedSegment ~= nil then
        return x, y, z, isSnapped, snappedSegment
    end

    local refRad = math.rad(ref.heading)
    local dirX = math.sin(refRad)
    local dirZ = math.cos(refRad)

    local fromAnchorX = x - ref.anchorX
    local fromAnchorZ = z - ref.anchorZ
    local along = fromAnchorX * dirX + fromAnchorZ * dirZ

    local snappedX = ref.anchorX + dirX * along
    local snappedZ = ref.anchorZ + dirZ * along
    local snappedY = getTerrainY(snappedX, snappedZ, y)

    return snappedX, snappedY, snappedZ, true, snappedSegment
end

function FencePlacementHelper:relockGuideToCurrent(brush)
    if brush == nil then
        return false
    end

    if self:getGuideMode() ~= "LOCAL" then
        self:clearGuideReference(brush)
        return true
    end

    local sx, sy, sz, ex, ey, ez = self:getGuideGeometry(brush)
    if sx == nil or ex == nil then
        return false
    end

    if brush.fphRawCursorX ~= nil then
        ex = brush.fphRawCursorX
        ey = brush.fphRawCursorY or ey
        ez = brush.fphRawCursorZ
    end

    local dx = ex - sx
    local dz = ez - sz
    local length = math.sqrt(dx * dx + dz * dz)
    if length < 0.5 then
        return false
    end

    local heading = getHeadingFromVector(dx, dz)
    if heading == nil then
        return false
    end

    self:setGuideReference(brush, sx, sy, sz, heading, "manual")
    return true
end

function FencePlacementHelper:onRelockGuide(actionName, inputValue, callbackState, isAnalog)
    if not self.enabled then
        return
    end

    local screen = g_constructionScreen
    if screen == nil or not self:isNewFenceBrush(screen.brush) then
        return
    end

    self:relockGuideToCurrent(screen.brush)
end

function FencePlacementHelper:updateGuideActionText(screen)
    screen = screen or g_constructionScreen
    if screen == nil or screen.fphGuideActionEventId == nil then
        return
    end

    g_inputBinding:setActionEventText(screen.fphGuideActionEventId, "Re-lock fence guide")
    g_inputBinding:setActionEventTextPriority(screen.fphGuideActionEventId, GS_PRIO_HIGH)
end

function FencePlacementHelper:registerGuideAction(screen)
    if screen == nil or not self:isNewFenceBrush(screen.brush) then
        return
    end

    local action = InputAction ~= nil and InputAction.FPH_RELOCK_GUIDE or nil
    if action == nil then
        return
    end

    local _, eventId = g_inputBinding:registerActionEvent(
        action,
        self,
        self.onRelockGuide,
        false,
        true,
        false,
        true
    )

    if eventId ~= nil then
        screen.fphGuideActionEventId = eventId
        table.insert(screen.brushEvents, eventId)
        self:updateGuideActionText(screen)
    end
end

function FencePlacementHelper:drawGuide(brush)
    if not self.enabled then
        return
    end

    local sx, sy, sz, ex, ey, ez = self:getGuideGeometry(brush)
    if sx == nil or ex == nil then
        return
    end

    local dx = ex - sx
    local dz = ez - sz
    local currentLength = math.sqrt(dx * dx + dz * dz)
    if currentLength < 0.05 then
        return
    end

    local heading = getHeadingFromVector(dx, dz)
    local ref
    if brush.fphMandatoryEndSnap then
        ref = {
            anchorX = sx,
            anchorY = sy,
            anchorZ = sz,
            heading = heading,
            source = "husbandry endpoint"
        }
    else
        ref = self:ensureGuideReference(brush, sx, sy, sz, ex, ey, ez)
    end

    local referenceText
    if self:getGuideMode() == "LOCAL" then
        local existingHeading = self:findExistingFenceReference(brush, sx, sy, sz)
        if existingHeading ~= nil then
            referenceText = string.format("choose straight / 90° (%.2f m)", self.CORNER_LOCK_DISTANCE)
        else
            referenceText = string.format("setting (locks at %.0f m)", self.GUIDE_LOCK_DISTANCE)
        end
    else
        referenceText = "world 45°"
    end
    local deviationText = "--"
    local driftText = "--"

    if ref ~= nil then
        local ax = ex - ref.anchorX
        local az = ez - ref.anchorZ
        local refHeading = ref.heading

        local oppositeHeading = normalizeHeading(refHeading + 180)
        local diffA = signedAngleDifference(heading, refHeading)
        local diffB = signedAngleDifference(heading, oppositeHeading)
        local effectiveHeading = refHeading
        local deviation = diffA
        if math.abs(diffB) < math.abs(diffA) then
            effectiveHeading = oppositeHeading
            deviation = diffB
        end

        local refRad = math.rad(effectiveHeading)
        local refX = math.sin(refRad)
        local refZ = math.cos(refRad)
        local projection = ax * refX + az * refZ
        local drift = refZ * ax - refX * az

        local guideLength = math.max(math.abs(projection), currentLength)
        local gx = ref.anchorX + refX * guideLength
        local gz = ref.anchorZ + refZ * guideLength
        local gy = getTerrainY(gx, gz, ey)

        if DebugUtil ~= nil and DebugUtil.drawDebugLine ~= nil then
            DebugUtil.drawDebugLine(
                ref.anchorX, (ref.anchorY or sy) + 0.12, ref.anchorZ,
                gx, gy + 0.12, gz,
                1.0, 1.0, 1.0, nil, true
            )
        end

        referenceText = string.format("%.2f° (%s)", effectiveHeading, ref.source or "locked")
        deviationText = string.format("%+.2f°", deviation)
        driftText = string.format("%+.2f m", drift)
    else
        if DebugUtil ~= nil and DebugUtil.drawDebugLine ~= nil then
            DebugUtil.drawDebugLine(sx, sy + 0.12, sz, ex, ey + 0.12, ez, 1.0, 1.0, 1.0, nil, true)
        end
    end

    if DebugUtil ~= nil and DebugUtil.drawDebugLine ~= nil then
        local sectionLength = self:getSectionLength()
        if sectionLength > 0 and currentLength > sectionLength then
            local dirX = dx / currentLength
            local dirZ = dz / currentLength
            local sideX = -dirZ
            local sideZ = dirX
            local markerDistance = sectionLength
            local markerCount = 0

            while markerDistance < currentLength - 0.05 and markerCount < 100 do
                local mx = sx + dirX * markerDistance
                local mz = sz + dirZ * markerDistance
                local my = getTerrainY(mx, mz, sy) + 0.14
                local halfWidth = 0.45

                DebugUtil.drawDebugLine(
                    mx - sideX * halfWidth, my, mz - sideZ * halfWidth,
                    mx + sideX * halfWidth, my, mz + sideZ * halfWidth,
                    1.0, 0.85, 0.15, nil, false
                )

                markerDistance = markerDistance + sectionLength
                markerCount = markerCount + 1
            end
        end
    end

    local sectionLength = self:getSectionLength()
    local sectionInfo
    if sectionLength > 0 then
        sectionInfo = string.format("%d m  (~%d sections)", sectionLength, math.max(1, math.ceil(currentLength / sectionLength)))
    else
        sectionInfo = "OFF"
    end

    setTextBold(true)
    setTextColor(1, 1, 1, 1)
    renderText(0.39, 0.935, 0.016,
        string.format("Fence heading: %.2f°   |   reference: %s   |   deviation: %s", heading, referenceText, deviationText))
    renderText(0.39, 0.912, 0.015,
        string.format("Length: %.1f m   |   lateral drift: %s   |   guide snap: %s   |   sections: %s",
            currentLength, driftText, self:getGuideSnapText(), sectionInfo))
    setTextBold(false)
end

function FencePlacementHelper:applySegmentState(brush, segment)
    local state = brush.fphSectionState
    if state == nil or segment == nil then
        return
    end

    if state.isReversed ~= nil and segment.setIsReversed ~= nil then
        segment:setIsReversed(state.isReversed)
    end
end

function FencePlacementHelper:finishSectionPlacement(brush, endX, endY, endZ)
    local state = brush.fphSectionState
    local reachedMandatoryEnd = self:isMandatoryHusbandryEnd(brush, endX, endY, endZ)

    if brush.currentSegment ~= nil and g_server == nil then
        brush.currentSegment:delete()
    end
    brush.currentSegment = nil

    brush.fphSectionState = nil
    brush.isValidating = false

    -- Husbandry fencing validates the enclosure after the required end snap.
    if reachedMandatoryEnd then
        if brush.validateCallbackFunc == nil then
            brush:finish(ConstructionBrushNewFence.STATUS.SUCCESS)
        else
            brush.isValidating = true
            brush.validateCallbackFunc(function(isValid)
                brush.isValidating = false
                if isValid then
                    brush:finish(ConstructionBrushNewFence.STATUS.SUCCESS)
                else
                    brush:deleteLastSeqment()
                end
            end)
        end
        return
    end

    if brush.fence ~= nil then
        brush:createNextSegment(endX, endY, endZ)
    end

    brush:setInputTextDirty()
end

function FencePlacementHelper:abortSectionPlacement(brush, reason)
    local state = brush.fphSectionState
    local resumeX, resumeY, resumeZ

    if state ~= nil then
        resumeX, resumeY, resumeZ = state.lastEndX, state.lastEndY, state.lastEndZ
    end

    if brush.currentSegment ~= nil then
        brush.currentSegment:delete()
        brush.currentSegment = nil
    end

    brush.fphSectionState = nil
    brush.isValidating = false

    if brush.fence ~= nil and resumeX ~= nil then
        brush:createNextSegment(resumeX, resumeY, resumeZ)
    end

    brush:setInputTextDirty()
end

function FencePlacementHelper:sendNextSection(brush)
    local state = brush.fphSectionState
    if state == nil or brush.fence == nil or brush.fenceParentObject == nil then
        self:abortSectionPlacement(brush, "fence no longer available")
        return
    end

    if state.createdCount >= self.MAX_AUTO_SECTIONS then
        self:abortSectionPlacement(brush, "maximum section count reached")
        return
    end

    if brush.currentSegment == nil then
        brush:createNextSegment(state.lastEndX, state.lastEndY, state.lastEndZ)
    end

    local segment = brush.currentSegment
    self:applySegmentState(brush, segment)

    local sx, sy, sz = segment:getStartPos()
    if sx == nil then
        self:abortSectionPlacement(brush, "section start position missing")
        return
    end

    local dx = state.targetX - sx
    local dz = state.targetZ - sz
    local remaining = math.sqrt(dx * dx + dz * dz)

    if remaining < self.MIN_REMAINING_LENGTH then
        if not state.targetIsMandatoryEnd or remaining < 0.10 then
            self:finishSectionPlacement(brush, sx, sy, sz)
            return
        end
    end

    local requestLength = math.min(state.sectionLength, remaining)
    local alpha = requestLength / remaining
    local ex = sx + dx * alpha
    local ez = sz + dz * alpha
    local ey

    if requestLength >= remaining - 0.001 then
        ey = state.targetY
    else
        ey = getTerrainY(ex, ez, sy)
    end

    segment:setEndPos(ex, ey, ez)

    if not segment:updateMeshes(true) then
        self:abortSectionPlacement(brush, "segment mesh validation failed")
        return
    end

    state.previousRemaining = remaining

    state.awaitingServer = true
    state.sendNextQueued = false
    g_messageCenter:subscribeOneshot(FenceNewSegmentEvent, self.onSectionCreated, brush)
    g_client:getServerConnection():sendEvent(FenceNewSegmentEvent.newClientToServer(brush.fenceParentObject, segment))
end

function FencePlacementHelper.onSectionCreated(brush, statusCode, segmentId, endX, endY, endZ)
    local helper = FencePlacementHelper
    local state = brush.fphSectionState
    if state == nil then
        return
    end

    if statusCode ~= FenceNewSegmentEvent.STATUS_CODE.SUCCESS then
        helper:abortSectionPlacement(brush, "server rejected a section")
        return
    end

    if brush.fenceParentObject ~= nil and brush.fenceParentObject.playPlaceSound ~= nil then
        brush.fenceParentObject:playPlaceSound()
    end

    -- Remote clients remove only their preview; the server owns the final segment.
    if brush.currentSegment ~= nil and g_server == nil then
        brush.currentSegment:delete()
    end
    brush.currentSegment = nil

    table.addElement(brush.segmentIds, segmentId)
    state.createdCount = state.createdCount + 1
    state.awaitingServer = false

    local moved = math.sqrt((endX - state.lastEndX) ^ 2 + (endZ - state.lastEndZ) ^ 2)
    state.lastEndX, state.lastEndY, state.lastEndZ = endX, endY, endZ

    local remaining = math.sqrt((state.targetX - endX) ^ 2 + (state.targetZ - endZ) ^ 2)

    if moved < 0.05 then
        helper:abortSectionPlacement(brush, "server endpoint did not advance")
        return
    end

    -- Fence panel geometry may finish slightly short; sub-0.5 m is complete.
    if state.targetIsMandatoryEnd then
        if remaining < 0.10 then
            helper:finishSectionPlacement(brush, endX, endY, endZ)
            return
        end
    elseif remaining < helper.MIN_REMAINING_LENGTH then
        helper:finishSectionPlacement(brush, endX, endY, endZ)
        return
    end

    if state.previousRemaining ~= nil and remaining >= state.previousRemaining - 0.05 then
        helper:abortSectionPlacement(brush, "remaining distance did not decrease")
        return
    end

    brush:createNextSegment(endX, endY, endZ)
    helper:applySegmentState(brush, brush.currentSegment)

    -- Defer the next section to avoid synchronous recursion on listen servers.
    state.sendNextQueued = true
end

function FencePlacementHelper:beginSectionPlacement(brush, targetX, targetY, targetZ, sectionLength)
    local sourceSegment = brush.currentSegment
    if sourceSegment == nil then
        return false
    end

    local sx, sy, sz = sourceSegment:getStartPos()
    if sx == nil then
        return false
    end

    local dx = targetX - sx
    local dz = targetZ - sz
    local totalLength = math.sqrt(dx * dx + dz * dz)
    if totalLength <= sectionLength + 0.05 then
        return false
    end

    local isReversed = nil
    if sourceSegment.getIsReversed ~= nil then
        isReversed = sourceSegment:getIsReversed()
    end

    sourceSegment:delete()
    brush.currentSegment = nil

    brush.fphSectionState = {
        targetX = targetX,
        targetY = targetY,
        targetZ = targetZ,
        originalStartX = sx,
        originalStartY = sy,
        originalStartZ = sz,
        originalLength = totalLength,
        sectionLength = sectionLength,
        createdCount = 0,
        lastEndX = sx,
        lastEndY = sy,
        lastEndZ = sz,
        isReversed = isReversed,
        targetIsMandatoryEnd = self:isMandatoryHusbandryEnd(brush, targetX, targetY, targetZ)
    }

    brush.isValidating = true
    brush:createNextSegment(sx, sy, sz)
    self:applySegmentState(brush, brush.currentSegment)
    brush:setInputTextDirty()
    self:sendNextSection(brush)
    return true
end

function FencePlacementHelper:updateSectionQueue(brush)
    local state = brush ~= nil and brush.fphSectionState or nil
    if state == nil or state.awaitingServer or not state.sendNextQueued then
        return
    end

    state.sendNextQueued = false
    self:sendNextSection(brush)
end

function FencePlacementHelper.installPatches()
    if FencePlacementHelper.patchesInstalled then
        return
    end

    if ConstructionBrushNewFence == nil or ConstructionScreen == nil then
        return
    end

    FencePlacementHelper.patchesInstalled = true

    -- Apply helper snapping after vanilla cursor/snapping.
    ConstructionBrushNewFence.getLimitedSnappedCursorPosition = Utils.overwrittenFunction(
        ConstructionBrushNewFence.getLimitedSnappedCursorPosition,
        function(brush, superFunc, ...)
            local x, y, z, isSnapped, snappedSegment = superFunc(brush, ...)
            if x == nil then
                return x, y, z, isSnapped, snappedSegment
            end

            brush.fphRawCursorX = x
            brush.fphRawCursorY = y
            brush.fphRawCursorZ = z

            return FencePlacementHelper:snapPositionToGuide(
                brush, x, y, z, isSnapped, snappedSegment
            )
        end
    )

    -- Only long primary placements are intercepted; vanilla actions stay intact.
    ConstructionBrushNewFence.onButtonPrimary = Utils.overwrittenFunction(
        ConstructionBrushNewFence.onButtonPrimary,
        function(brush, superFunc, ...)
            if brush.fphSectionState ~= nil then
                return
            end

            if not FencePlacementHelper.enabled then
                return superFunc(brush, ...)
            end

            local sectionLength = FencePlacementHelper:getSectionLength()
            if sectionLength <= 0
                or brush.gateIndex ~= nil
                or brush.fenceParentObject == nil
                or brush.fence == nil
                or brush.currentSegment == nil then
                return superFunc(brush, ...)
            end

            local sx, _, sz = brush.currentSegment:getStartPos()
            if sx == nil then
                return superFunc(brush, ...)
            end

            local x, y, z = brush:getLimitedSnappedCursorPosition()
            if x == nil then
                return
            end

            local distance = math.sqrt((x - sx) ^ 2 + (z - sz) ^ 2)
            if distance <= sectionLength + 0.05 then
                return superFunc(brush, ...)
            end

            if brush:verifyAccess(x, y, z) ~= nil then
                return
            end
            if not brush:validateCurrentSegment(x, z) then
                return
            end
            if next(brush.overlappingNodes) ~= nil then
                return
            end

            if FencePlacementHelper:beginSectionPlacement(brush, x, y, z, sectionLength) then
                return
            end

            return superFunc(brush, ...)
        end
    )

    ConstructionBrushNewFence.draw = Utils.appendedFunction(
        ConstructionBrushNewFence.draw,
        function(brush)
            FencePlacementHelper:drawGuide(brush)
        end
    )

    ConstructionBrushNewFence.update = Utils.appendedFunction(
        ConstructionBrushNewFence.update,
        function(brush, dt)
            FencePlacementHelper:updateSectionQueue(brush)
        end
    )

    ConstructionScreen.registerBrushActionEvents = Utils.appendedFunction(
        ConstructionScreen.registerBrushActionEvents,
        function(screen)
            FencePlacementHelper:registerFenceHelperAction(screen)
            FencePlacementHelper:registerGuideAction(screen)
            FencePlacementHelper:registerGuideSnapAction(screen)
            FencePlacementHelper:registerGuideModeAction(screen)
            FencePlacementHelper:registerMasterAction(screen)
        end
    )

    ConstructionScreen.removeBrushActionEvents = Utils.prependedFunction(
        ConstructionScreen.removeBrushActionEvents,
        function(screen)
            FencePlacementHelper:clearFenceHelperAction(screen)
            if screen ~= nil then
                screen.fphGuideActionEventId = nil
                screen.fphGuideSnapActionEventId = nil
                screen.fphGuideModeActionEventId = nil
                screen.fphMasterActionEventId = nil
            end
        end
    )

    ConstructionBrushNewFence.onButtonSecondary = Utils.appendedFunction(
        ConstructionBrushNewFence.onButtonSecondary,
        function(brush)
            if brush.fphSectionState == nil and brush.currentSegment == nil then
                FencePlacementHelper:clearGuideReference(brush)
            end
        end
    )

    ConstructionBrushNewFence.deactivate = Utils.appendedFunction(
        ConstructionBrushNewFence.deactivate,
        function(brush)
            FencePlacementHelper:clearGuideReference(brush)
            brush.fphRawCursorX = nil
            brush.fphRawCursorY = nil
            brush.fphRawCursorZ = nil
            brush.fphMandatoryEndSnap = nil
        end
    )
end

function FencePlacementHelper:loadMap(mapFilename)
    self:installPatches()
end

function FencePlacementHelper:deleteMap()
end

-- Retry patch installation at map load for unusual load orders.
FencePlacementHelper.installPatches()
addModEventListener(FencePlacementHelper)
