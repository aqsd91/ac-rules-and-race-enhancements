& "$PSScriptRoot\build.ps1"

$ac_dir = "D:\Games\steamapps\common\"

Copy-Item "$PSScriptRoot\assettocorsa\" -Destination $ac_dir -Recurse -Force