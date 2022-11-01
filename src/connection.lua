local connection = {}

local F1RegsData = ac.connect({
    ac.StructItem.key('F1RegsData'),
    connected = ac.StructItem.boolean(),
    scriptVersionId = ac.StructItem.int16(),
    drsEnabled = ac.StructItem.boolean(),
    drsAvailable = ac.StructItem.array(ac.StructItem.boolean(),32),
    carAhead = ac.StructItem.array(ac.StructItem.int16(),32),
    carAheadDelta = ac.StructItem.array(ac.StructItem.float(),32),
},false,ac.SharedNamespace.Shared)

function connection.storeRaceControlData(rc)
    F1RegsData.connected = true
    F1RegsData.scriptVersionId = SCRIPT_VERSION_ID
    F1RegsData.drsEnabled = DRS_ENABLED
end

function connection.storeDriverData(driver)
    F1RegsData.drsAvailable[driver.index] = driver.drsAvailable
    F1RegsData.carAhead[driver.index] = driver.carAhead
    F1RegsData.carAheadDelta[driver.index] = driver.carAheadDelta
end

return connection