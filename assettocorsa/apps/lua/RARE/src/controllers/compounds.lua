local compounds = {}

local function setTyreCompoundsColor(driver)
    local extensionDir = ac.getFolder(ac.FolderID.ContentCars) .. "/" ..
                             ac.getCarID(driver.index) .. "/extension/"
    local driverCompound = driver.car.compoundIndex

    local compoundHardness = ""

    if tonumber(driver.tyreCompoundsAvailable[1]) == driverCompound then
        compoundHardness = 'SOFT'
    elseif tonumber(driver.tyreCompoundsAvailable[2]) == driverCompound then
        compoundHardness = 'MEDIUM'
    elseif tonumber(driver.tyreCompoundsAvailable[3]) == driverCompound then
        compoundHardness = 'HARD'
    else
        return
    end

    local compoundTexture = extensionDir .. compoundHardness .. ".dds"
    local compoundBlurTexture = extensionDir .. compoundHardness .. "_Blur.dds"

    ac.findNodes('carRoot:' .. driver.index):findMeshes('material:' ..
                                                            driver.tyreCompoundMaterialTarget)
        :setMaterialTexture('txDiffuse', compoundTexture)
    ac.findNodes('carRoot:' .. driver.index):findMeshes('material:' ..
                                                            driver.tyreCompoundMaterialTarget)
        :setMaterialTexture('txBlur', compoundBlurTexture)

    log(os.clock() .. " " .. driver.name .. " " .. driver.index .. " " ..
            compoundHardness .. " " .. driver.tyreCompoundMaterialTarget)
end

function compounds.update(sim)
    if sim.isInMainMenu then
        local driver = DRIVERS[0]
        if driver.car.compoundIndex < tonumber(driver.tyreCompoundsAvailable[1]) then
            ac.setSetupSpinnerValue('COMPOUND', driver.tyreCompoundsAvailable[1])
        elseif driver.car.compoundIndex >
            tonumber(driver.tyreCompoundsAvailable[3]) then
            ac.setSetupSpinnerValue('COMPOUND', driver.tyreCompoundsAvailable[3])
        end
    end
    if not sim.isSessionStarted or sim.isInMainMenu then
        for i = 0, #DRIVERS do
            local driver = DRIVERS[i]
            setTyreCompoundsColor(driver)
        end
    else
        for i = 0, #DRIVERS do
            local driver = DRIVERS[i]
            if driver.car.isInPit then setTyreCompoundsColor(driver) end
        end
    end
end

return compounds
