local ai = {}

AI_COMP_OVERRIDE = false
AI_THROTTLE_LIMIT = 0.8
AI_LEVEL = 0.9
AI_AGGRESSION = 0.25

--- Returns whether driver's average tyre life is below
--- the limit or not
---@param driver Driver
---@return bool
local function avgTyreWearBelowLimit(driver)
    local avgTyreLimit = 1 -
                             (RARECONFIG.data.AI.AI_AVG_TYRE_LIFE +
                                 driver.aiTyreAvgRandom) / 100
    local avgTyreWear = (driver.car.wheels[0].tyreWear +
                            driver.car.wheels[1].tyreWear +
                            driver.car.wheels[2].tyreWear +
                            driver.car.wheels[3].tyreWear) / 4
    return avgTyreWear > avgTyreLimit and true or false
end

---@alias ai.QualifyLap
---| `ai.QualifyLap.OutLap` @Value: 0.
---| `ai.QualifyLap.FlyingLap` @Value: 1.
---| `ai.QualifyLap.InLap` @Value: 2.
ai.QualifyLap = {OutLap = 0, FlyingLap = 1, InLap = 2}

--- Returns whether one of a driver's tyre life is below
--- the limit or not
---@param driver Driver
---@return bool
local function singleTyreWearBelowLimit(driver)
    local singleTyreLimit = 1 -
                                (RARECONFIG.data.AI.AI_SINGLE_TYRE_LIFE +
                                    driver.aiTyreSingleRandom) / 100

    if driver.car.wheels[0].tyreWear > singleTyreLimit or
        driver.car.wheels[1].tyreWear > singleTyreLimit or
        driver.car.wheels[2].tyreWear > singleTyreLimit or
        driver.car.wheels[3].tyreWear > singleTyreLimit then
        return true
    else
        return false
    end
end

local function availableTyreCompound(driver)
    local compoundsAvailable = {2, 3, 4}
    local nextCompound = driver.car.compoundIndex

    if not driver.tyreCompoundChange then
        table.removeItem(compoundsAvailable, driver.car.compoundIndex)
        nextCompound = compoundsAvailable[math.random(1, 2)]
    else
        nextCompound = compoundsAvailable[math.random(1, 3)]
    end

    return nextCompound
end

--- Force AI driver to drive to the pits
--- @param driver Driver
local function triggerPitStopRequest(driver, trigger)
    physics.setAIPitStopRequest(driver.index, trigger)
    driver.aiPitting = trigger
    if trigger then driver.tyreCompoundNext = availableTyreCompound(driver) end
end

--- Determine if going to the pits is advantageous or not
--- @param driver Driver
--- @param forced boolean
local function pitStrategyCall(driver, forced)
    local carAhead = DRIVERS[driver.carAhead]
    local trigger = true
    local lapsTotal = ac.getSession(ac.getSim().currentSessionIndex).laps
    local lapsRemaining = lapsTotal - driver.lapsCompleted

    if not forced then
        if (not carAhead.aiPitCall and driver.carAheadDelta < 1) or
            lapsRemaining <= 5 or driver.car.splinePosition > 0.8 then
            trigger = false
        end
    end

    triggerPitStopRequest(driver, trigger)
end
--- Occurs when a driver is in the pit
---@param driver Driver
local function pitstop(driver)
    if driver.aiPitting then
        driver.tyreLaps = 0
        driver.tyreCompoundChange = true
        physics.setAITyres(driver.index, driver.tyreCompoundNext)
    end

    driver.aiPitting = false
end

--- Determines when an AI driver should pit for new tyres
--- @param driver Driver
function ai.pitNewTyres(driver)
    if not driver.car.isInPitlane and not driver.aiPitting then
        if singleTyreWearBelowLimit(driver) then
            pitStrategyCall(driver, true)
        elseif avgTyreWearBelowLimit(driver) then
            pitStrategyCall(driver, false)
        end
    else
        if driver.car.isInPit then pitstop(driver) end
    end
end

local function moveOffRacingLine(driver)
    local delta = driver.carAheadDelta
    local driverAhead = DRIVERS[driver.carAhead]
    local splineSideLeft = ac.getTrackAISplineSides(driverAhead.splinePosition)
                               .x
    local splineSideRight = ac.getTrackAISplineSides(driverAhead.splinePosition)
                                .y
    local offset = splineSideLeft > splineSideLeft and -3 or 3

    if not driverAhead.flyingLap then

        if delta < 2 and delta > 0.1 then
            if driverAhead.car.isInPitlane then
                physics.setAITopSpeed(driverAhead.index, 0)
            else
                if ac.getTrackUpcomingTurn(driverAhead.index).x > 100 then
                    physics.setAISplineOffset(driverAhead.index, math.lerp(0,
                                                                           offset,
                                                                           driverAhead.aiSplineOffset))
                    physics.setAISplineOffset(driver.index, math.lerp(0,
                                                                      -offset,
                                                                      driver.aiSplineOffset))
                    physics.setAITopSpeed(driverAhead.index, 200)
                    driverAhead.aiMoveAside = true
                    driverAhead.aiSpeedUp = false
                else
                    driverAhead.aiSplineOffset =
                        math.lerp(offset, 0, driverAhead.aiSplineOffset)
                    driver.aiSplineOffset =
                        math.lerp(-offset, 0, driver.aiSplineOffset)
                    physics.setAISplineOffset(driverAhead.index,
                                              driverAhead.aiSplineOffset)
                    physics.setAISplineOffset(driver.index,
                                              driver.aiSplineOffset)
                    physics.setAITopSpeed(driverAhead.index, 1e9)
                    driverAhead.aiMoveAside = false
                    driverAhead.aiSpeedUp = true
                end
            end
        else
            driverAhead.aiSplineOffset =
                math.lerp(offset, 0, driverAhead.aiSplineOffset)
            driver.aiSplineOffset = math.lerp(-offset, 0, driver.aiSplineOffset)
            physics.setAISplineOffset(driverAhead.index,
                                      driverAhead.aiSplineOffset)
            physics.setAISplineOffset(driver.index, driver.aiSplineOffset)
            driverAhead.aiMoveAside = false
            driverAhead.aiSpeedUp = false
        end
    end
end

function ai.qualifying(driver)
    if driver.car.isInPitlane then
        physics.allowCarDRS(driver.index, true)
        if driver.car.isInPit then
            local qualiRunFuel = driver.fuelPerLap * 3.5
            physics.setCarFuel(driver.index, qualiRunFuel)
        end
        driver.inLap = false
        driver.flyingLap = false
        driver.outLap = true
    else
        if driver.flyingLap then
            moveOffRacingLine(driver)
            if ac.getTrackUpcomingTurn(driver.index).x > 200 then
                physics.setAIAggression(driver.index, 1)
            else
                physics.setAIAggression(driver.index, 0.25)
            end

            if driver.car.lapCount >= driver.inLapCount then
                driver.outLap = false
                driver.flyingLap = false
                driver.inLap = true
            end
        elseif driver.outLap then
            if driver.car.splinePosition <= 0.8 then
                if not driver.aiMoveAside and not driver.aiSpeedUp then
                    physics.setAITopSpeed(driver.index, 250)
                    physics.setAILevel(driver.index, 0.8)
                    physics.setAIAggression(driver.index, 1)
                    physics.allowCarDRS(driver.index, true)

                    if driver.carAheadDelta < 5 then
                        physics.setAITopSpeed(driver.index, 200)
                    end
                elseif driver.aiSpeedUp then
                    moveOffRacingLine(driver)
                end
            else
                physics.setAITopSpeed(driver.index, 1e9)
                physics.setAILevel(driver.index, 1)
                physics.setAIAggression(driver.index, 1)
                physics.allowCarDRS(driver.index, false)
                driver.outLap = false
                driver.flyingLap = true
                driver.inLapCount = driver.car.lapCount + 2
            end
        elseif driver.inLap then
            if not driver.aiMoveAside and not driver.aiSpeedUp then
                physics.setAITopSpeed(driver.index, 200)
                physics.setAILevel(driver.index, 0.65)
                physics.setAIAggression(driver.index, 0)
            elseif driver.aiSpeedUp then
                moveOffRacingLine(driver)
            end
        end
    end
end

--- Variable aggression function for AI drivers
--- @param driver Driver
function ai.alternateAttack(driver)
    local override = AI_COMP_OVERRIDE
    local delta = driver.carAheadDelta
    local speedMod = math.clamp(200 / (driver.car.speedKmh or 200), 1, 2)
    local maxAggression = driver.aiAggression
    local upcomingTurn = ac.getTrackUpcomingTurn(driver.index)
    local upcomingTurnDistance = upcomingTurn.x
    local upcomingTurnAngle = upcomingTurn.y

    -- if upcomingTurnDistance >= 250 then
    --     maxAggression = maxAggression + (maxAggression*0.25)
    -- else
    --     if upcomingTurnAngle < 90 then
    --         maxAggression = maxAggression / speedMod
    --     end
    -- end

    if upcomingTurnDistance > 200 and delta < 0.5 then
        physics.setAIAggression(driver.index, 1)
    elseif delta > 0.5 then
        physics.setAIAggression(driver.index, 0.25)
    else
        physics.setAIAggression(driver.index, 0)
    end

    local carAhead = ac.getCar(driver.carAhead)
    local turnType = upcomingTurnAngle < 0 and 1 or -1
    driver.aiSplineOffset = 0.5 * turnType

    if upcomingTurnDistance > 150 and delta > 0.05 and delta < 0.35 and
        driver.car.speedKmh > 100 and carAhead.speedKmh > 100 then
        physics.setAISplineOffset(driver.carAhead, driver.aiSplineOffset)
        physics.setAISplineOffset(driver.index, driver.aiSplineOffset)
        physics.setAIAggression(driver.index, 1)
    else
        physics.setAISplineOffset(driver.index, 0)
    end

    if upcomingTurnDistance > 50 then
        driver.aiThrottleLimit = math.applyLag(driver.aiThrottleLimit, 1, 0.99,
                                               ac.getScriptDeltaT())
    else
        if not override then
            driver.aiThrottleLimit = math.applyLag(driver.aiThrottleLimit,
                                                   driver.aiThrottleLimitBase,
                                                   0.96, ac.getScriptDeltaT())
        else
            driver.aiThrottleLimit = AI_THROTTLE_LIMIT
        end
    end
    if upcomingTurnDistance < 100 and upcomingTurnDistance < 0 and
        upcomingTurnAngle > 30 then
        if delta < 1 then
            physics.setAILevel(driver.index,
                               math.clamp(driver.aiLevel, 0, 0.9) + 0.1)
        else
            if not override then
                physics.setAILevel(driver.index, driver.aiLevel)
            else
                physics.setAILevel(driver.index, AI_LEVEL)
            end
        end
    else
        if delta < 1 then
            physics.setAILevel(driver.index, 1)
        else
            physics.setAILevel(driver.index, 0.9)
        end
    end

    physics.setAIThrottleLimit(driver.index, driver.aiThrottleLimit)
end

local function mgukBuild(driver)
    if driver.aiMgukDelivery ~= 1 then
        driver.aiMgukDelivery = 1
        physics.setMGUKDelivery(driver.index, driver.aiMgukDelivery)
    end

    if driver.aiMgukRecovery ~= 10 then
        driver.aiMgukRecovery = 10
        physics.setMGUKRecovery(driver.index, driver.aiMgukRecovery)
    end
end

local function mgukLow(driver)
    if driver.aiMgukDelivery ~= 2 then
        driver.aiMgukDelivery = 2
        physics.setMGUKDelivery(driver.index, driver.aiMgukDelivery)
    end

    -- driver.car.kersCurrentKJ
    if driver.car.kersCharge > 0.8 then
        if driver.aiMgukRecovery ~= 0 then
            driver.aiMgukRecovery = 0
            physics.setMGUKRecovery(driver.index, driver.aiMgukRecovery)
        end
    elseif driver.car.kersCharge > 0.15 then
        if driver.aiMgukRecovery ~= 7 then
            driver.aiMgukRecovery = 7
            physics.setMGUKRecovery(driver.index, driver.aiMgukRecovery)
        end
    else
        mgukBuild(driver)
    end
end

local function mgukBalanced(driver)
    if driver.aiMgukDelivery ~= 3 then
        driver.aiMgukDelivery = 3
        physics.setMGUKDelivery(driver.index, driver.aiMgukDelivery)
    end

    -- driver.car.kersCurrentKJ
    if driver.car.kersCharge > 0.8 then
        if driver.aiMgukRecovery ~= 0 then
            driver.aiMgukRecovery = 0
            physics.setMGUKRecovery(driver.index, driver.aiMgukRecovery)
        end
    elseif driver.car.kersCharge > 0.25 then
        if driver.aiMgukRecovery ~= 7 then
            driver.aiMgukRecovery = 7
            physics.setMGUKRecovery(driver.index, driver.aiMgukRecovery)
        end
    else
        mgukLow(driver)
    end
end

local function mgukHigh(driver)
    if driver.aiMgukDelivery ~= 4 then
        driver.aiMgukDelivery = 4
        physics.setMGUKDelivery(driver.index, driver.aiMgukDelivery)
    end

    -- driver.car.kersCurrentKJ
    if driver.car.kersCharge > 0.8 then
        if driver.aiMgukRecovery ~= 0 then
            driver.aiMgukRecovery = 0
            physics.setMGUKRecovery(driver.index, driver.aiMgukRecovery)
        end
    elseif driver.car.kersCharge > 0.45 then
        if driver.aiMgukRecovery ~= 7 then
            driver.aiMgukRecovery = 7
            physics.setMGUKRecovery(driver.index, driver.aiMgukRecovery)
        end
    else
        mgukBalanced(driver)
    end
end

local function mgukAttack(driver)
    if driver.aiMgukDelivery ~= 5 then
        driver.aiMgukDelivery = 5
        physics.setMGUKDelivery(driver.index, driver.aiMgukDelivery)
    end

    if driver.aiMgukRecovery ~= 0 then
        driver.aiMgukRecovery = 0
        physics.setMGUKRecovery(driver.index, driver.aiMgukRecovery)
    end
end

function ai.mgukController(driver)
    if driver.carAheadDelta < 0.5 and driver.car.kersCharge > 0.25 then
        mgukAttack(driver)
    elseif driver.carAheadDelta < 1.5 then
        mgukHigh(driver)
    else
        mgukBalanced(driver)
    end
end

function ai.controller(aiRules, driver)
    if aiRules.AI_FORCE_PIT_TYRES == 1 then ai.pitNewTyres(driver) end
    if aiRules.AI_ALTERNATE_LEVEL == 1 then ai.alternateAttack(driver) end
    if aiRules.AI_MGUK_CONTROL == 1 then ai.mgukController(driver) end
end

return ai
