require 'src/driver'

local function setAIFuelTankMax(sim, driver)
    local fuelcons = ac.INIConfig.carData(driver.index, 'fuel_cons.ini'):get(
                         'FUEL_EVAL', 'KM_PER_LITER', 0.0)
    local fuelload = 0
    local fuelPerLap = (sim.trackLengthM / 1000) / (fuelcons - (fuelcons * 0.1))

    if sim.raceSessionType == ac.SessionType.Race then
        fuelload = ((ac.getSession(sim.currentSessionIndex).laps + 2) *
                       fuelPerLap)
    elseif sim.raceSessionType == ac.SessionType.Qualify then
        fuelload = 3.5 * fuelPerLap
    end

    physics.setCarFuel(driver.index, fuelload)
end

local function setAITyreCompound(driver, compounds)
    math.randomseed(os.clock() * driver.index)
    math.random()
    for i = 0, math.random(0, math.random(3)) do math.random() end
    local tyrevalue = compounds[math.random(1, #compounds)]
    physics.setAITyres(driver.index, tyrevalue)
    driver.tyreCompoundStart = tyrevalue
    driver.tyreCompoundsAvailable = compounds
end

local function getTrackTyreCompounds(driver)
    local trackID = ac.getTrackID()
    local carID = ac.getCarID(driver.index)
    local compoundsIni = ac.INIConfig.load(
                             ac.getFolder(ac.FolderID.ACApps) ..
                                 "/lua/RARE/data/tyre_compounds/" .. carID ..
                                 ".ini", ac.INIFormat.Default)

    driver.tyreCompoundMaterialTarget = compoundsIni:get('COMPOUNDS',
                                                         'COMPOUND_TARGET_MATERIAL',
                                                         "Unknown Compound Material Target")

    local compounds = string.split(compoundsIni:get(trackID, 'COMPOUNDS', "0"),
                                   ',')
    table.sort(compounds, function(a, b) return a < b end)

    log(driver.name .. " has " .. #compounds .. " compounds available")
    return compounds
end

local function setAIAlternateLevel(driver, driverIni)
    driver.aiLevel = driver.car.aiLevel
    driver.aiBrakeHint = ac.INIConfig.carData(driver.index, 'ai.ini'):get(
                             'PEDALS', 'BRAKE_HINT', 1)
    driver.aiThrottleLimitBase = math.lerp(0.5, 1,
                                           1 - ((1 - driver.aiLevel) / 0.3))
    driver.aiAggression = driver.car.aiAggression
    driverIni:setAndSave('AI_' .. driver.index, 'AI_LEVEL', driver.car.aiLevel)
    driverIni:setAndSave('AI_' .. driver.index, 'AI_THROTTLE_LIMIT',
                         driver.aiThrottleLimitBase)
    driverIni:setAndSave('AI_' .. driver.index, 'AI_AGGRESSION',
                         driver.car.aiAggression)
end

local function getAIAlternateLevel(driver, driverIni)
    driver.aiLevel = driverIni:get('AI_' .. driver.index, 'AI_LEVEL',
                                   driver.car.aiLevel)
    driver.aiThrottleLimitBase = driverIni:get('AI_' .. driver.index,
                                               'AI_THROTTLE_LIMIT', math.lerp(
                                                   0.5, 1, 1 -
                                                       ((1 - driver.car.aiLevel) /
                                                           0.3)))
    driver.aiAggression = driverIni:get('AI_' .. driver.index, 'AI_AGGRESSION',
                                        driver.car.aiAggression)
end

local function createDrivers(sim)
    local driverCount = ac.getSim().carsCount
    local driverIni = ac.INIConfig.load(ac.getFolder(ac.FolderID.ACApps) ..
                                            "/lua/RARE/data/drivers.ini",
                                        ac.INIFormat.Default)

    for i = 0, driverCount - 1 do
        DRIVERS[i] = Driver(i)
        local driver = DRIVERS[i]

        driver.tyreCompoundsAvailable = getTrackTyreCompounds(driver)
        -- setTyreCompoundColors(driver, driver.tyreCompoundsAvailable)

        if driver.car.isAIControlled then
            setAIFuelTankMax(sim, driver)
            setAITyreCompound(driver, driver.tyreCompoundsAvailable)

            if FIRST_LAUNCH then
                setAIAlternateLevel(driver, driverIni)
            else
                getAIAlternateLevel(driver, driverIni)
            end

            if RARECONFIG.data.AI.AI_RELATIVE_SCALING == 1 then
                driver.aiLevel = driver.aiLevel *
                                     RARECONFIG.data.AI.AI_RELATIVE_LEVEL / 100
                driver.aiThrottleLimitBase =
                    math.lerp(0.5, 1, 1 - ((1 - driver.aiLevel) / 0.3))
            end

            physics.setAILevel(driver.index, 1)
            physics.setAIAggression(driver.index, driver.aiAggression)
        end
    end

    log("Created " .. driverCount .. " drivers")
end

local function initDataDir()
    local rareDataDir = ac.getFolder(ac.FolderID.ACApps) .. "/lua/RARE/data"
    if not io.dirExists(rareDataDir) then io.createDir(rareDataDir) end
end

local function cspVersionCheck()
    log(SCRIPT_NAME .. " version: " .. SCRIPT_VERSION)
    log(SCRIPT_NAME .. " version: " .. SCRIPT_VERSION_CODE)
    log("CSP version: " .. ac.getPatchVersionCode())

    if not compatibleCspVersion() then
        ui.toast(ui.Icons.Warning,
                 "[RARE] Incompatible CSP version. CSP " .. CSP_MIN_VERSION ..
                     " " .. "(" .. CSP_MIN_VERSION_CODE .. ")" .. " required!")
        log("[WARN] Incompatible CSP version. CSP " .. CSP_MIN_VERSION .. " " ..
                "(" .. CSP_MIN_VERSION_CODE .. ")" .. " required!")
        return false
    end
end

local function loadSettings(sim)
    local configFile = "settings.ini"
    try(function()
        RARECONFIG = MappedConfig(ac.getFolder(ac.FolderID.ACApps) ..
                                      "/lua/RARE/" .. configFile, {
            RULES = {
                DRS_RULES = (ac.INIConfig.OptionalNumber == nil) and
                    ac.INIConfig.OptionalNumber or 1,
                DRS_ACTIVATION_LAP = (ac.INIConfig.OptionalNumber == nil) and
                    ac.INIConfig.OptionalNumber or 3,
                DRS_GAP_DELTA = (ac.INIConfig.OptionalNumber == nil) and
                    ac.INIConfig.OptionalNumber or 1000,
                DRS_WET_DISABLE = (ac.INIConfig.OptionalNumber == nil) and
                    ac.INIConfig.OptionalNumber or 1,
                DRS_WET_LIMIT = (ac.INIConfig.OptionalNumber == nil) and
                    ac.INIConfig.OptionalNumber or 15,
                VSC_RULES = (ac.INIConfig.OptionalNumber == nil) and
                    ac.INIConfig.OptionalNumber or 0,
                VSC_INIT_TIME = (ac.INIConfig.OptionalNumber == nil) and
                    ac.INIConfig.OptionalNumber or 300,
                VSC_DEPLOY_TIME = (ac.INIConfig.OptionalNumber == nil) and
                    ac.INIConfig.OptionalNumber or 300,
                RACE_REFUELING = (ac.INIConfig.OptionalNumber == nil) and
                    ac.INIConfig.OptionalNumber or 0
            },
            AI = {
                AI_FORCE_PIT_TYRES = (ac.INIConfig.OptionalNumber == nil) and
                    ac.INIConfig.OptionalNumber or 1,
                AI_AVG_TYRE_LIFE = (ac.INIConfig.OptionalNumber == nil) and
                    ac.INIConfig.OptionalNumber or 45,
                AI_AVG_TYRE_LIFE_RANGE = (ac.INIConfig.OptionalNumber == nil) and
                    ac.INIConfig.OptionalNumber or 15,
                AI_SINGLE_TYRE_LIFE = (ac.INIConfig.OptionalNumber == nil) and
                    ac.INIConfig.OptionalNumber or 30,
                AI_SINGLE_TYRE_LIFE_RANGE = (ac.INIConfig.OptionalNumber == nil) and
                    ac.INIConfig.OptionalNumber or 2.5,
                AI_ALTERNATE_LEVEL = (ac.INIConfig.OptionalNumber == nil) and
                    ac.INIConfig.OptionalNumber or 0,
                AI_RELATIVE_SCALING = (ac.INIConfig.OptionalNumber == nil) and
                    ac.INIConfig.OptionalNumber or 0,
                AI_RELATIVE_LEVEL = (ac.INIConfig.OptionalNumber == nil) and
                    ac.INIConfig.OptionalNumber or 100,
                AI_MGUK_CONTROL = (ac.INIConfig.OptionalNumber == nil) and
                    ac.INIConfig.OptionalNumber or 1
            },
            AUDIO = {
                MASTER = (ac.INIConfig.OptionalNumber == nil) and
                    ac.INIConfig.OptionalNumber or 100,
                DRS_BEEP = (ac.INIConfig.OptionalNumber == nil) and
                    ac.INIConfig.OptionalNumber or 50,
                DRS_FLAP = (ac.INIConfig.OptionalNumber == nil) and
                    ac.INIConfig.OptionalNumber or 50
            },
            NOTIFICATIONS = {
                X_POS = (ac.INIConfig.OptionalNumber == nil) and
                    ac.INIConfig.OptionalNumber or (sim.windowWidth / 2 - 360),
                Y_POS = (ac.INIConfig.OptionalNumber == nil) and
                    ac.INIConfig.OptionalNumber or 50,
                SCALE = (ac.INIConfig.OptionalNumber == nil) and
                    ac.INIConfig.OptionalNumber or 1,
                DURATION = (ac.INIConfig.OptionalNumber == nil) and
                    ac.INIConfig.OptionalNumber or 5
            },
            MISC = {
                PHYSICS_REBOOT = (ac.INIConfig.OptionalNumber == nil) and
                    ac.INIConfig.OptionalNumber or 1
            }
        })
        log("[Loaded] Config file: " .. ac.getFolder(ac.FolderID.ACApps) ..
                "/lua/RARE/" .. configFile)
        return true
    end, function(err)
        log("[ERROR] Failed to load config")
        return false
    end, function() end)

end

local function checkPhysics()
    if RARECONFIG.data.MISC.PHYSICS_REBOOT == 1 then setTrackSurfaces() end
end

local function loadDRSZones()
    -- Get DRS Zones from track data folder
    try(function()
        DRS_ZONES = DrsZones("drs_zones.ini")
        return true
    end, function(err)
        log("[WARN]" .. err)
        log("[WARN] Failed to load DRS Zones!")
    end, function() end)
end

--- Initialize RARE and returns initialized state
--- @return boolean
function initialize(sim)
    log(FIRST_LAUNCH and "First initialization" or "Reinitializing")

    cspVersionCheck()
    loadSettings(sim)
    checkPhysics()
    loadDRSZones()
    initDataDir()
    createDrivers(sim)

    log("[Initialized]")
    FIRST_LAUNCH = false
    return true
end
