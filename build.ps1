# DONE allow using the map file directly
# DONE support for MESS
# DONE Remove useless files from RES
# DONE default values for config
# DONE profile
# DONE return to original directory always
# compile sprites
# compile smd
# GUI
# Remove dev entities

param(
    [Parameter(Mandatory = $true)]$mapname,
    [Parameter(Mandatory = $true)]$json,
    [switch]$clean,
    [parameter(ValueFromRemainingArguments = $true)] $profiles
)

Set-StrictMode -Version 3.0

$config = Get-Content -Raw $json | ConvertFrom-Json -AsHashTable
foreach ($p in $profiles) {
    $subconfig = Get-Content -Raw $p | ConvertFrom-Json -AsHashTable
    foreach ($c in $subconfig.GetEnumerator()) {
        $config[$c.Name] = $c.Value
    }
}

$build = $clean ? "build_$(Get-Date -Format FileDateTimeUniversal)_$mapname" : "build_$mapname"
New-Item -Name $build -ItemType "directory" -Force
$pwd = Get-Location
Set-Location $build
try {
    if (Test-Path -Path "../rad/$mapname.rad") {
        Copy-Item "../rad/$mapname.rad" -Destination .
    }

    foreach ($wad in $config.wads) {
        Copy-Item "../wad/$wad" -Destination .
    }
    if ($config.wadToBuild -ne $null) {
        Invoke-Expression "$($config.wadmaker) -nologfile ../textures wad/$($config.wadToBuild)"
    }

    if ($config.studiomdl -ne $null -and $config.mdlToBuild -ne $null) {
        foreach ($smd in Get-ChildItem -Include '*.qc' -Path $config.mdlToBuild -Recurse) {
            Invoke-Expression "$($config.studiomdl) $($config.mdlToBuild)/$($smd.Name)"
        }
        foreach ($mdl in Get-ChildItem -Include '*.mdl' -Path $config.mdlToBuild) {
            Copy-Item $mdl -Destination $config.mdlFolder
        }
    }

    if ($config.mapExporter -ceq "mess") {
        Copy-Item "../rmf/$mapname.rmf" -Destination .
        Invoke-Expression "$($config.mess) -log verbose $mapname.rmf $mapname.map"
        (Get-Content "$mapname.map") | Foreach-Object {
            $_
            if ($_ -like '"classname" "worldspawn"') {
                '"wad" "' + ($config.wads -join ";") + '"'
            }
        } | Set-Content "$mapname.map"
    } elseif ($config.mapExporter -ceq $null) {
        Copy-Item "../rmf/$mapname.map" -Destination .
    }

    Invoke-Expression "$($config.mess) -dir ../rmf $($config.messParams) $mapname"
    Invoke-Expression "$($config.csg) $($config.csgParams) $mapname"
    Invoke-Expression "$($config.bsp) $($config.bspParams) $mapname"
    Invoke-Expression "$($config.vis) $($config.visParams) $mapname"
    Invoke-Expression "$($config.rad) $($config.radParams) $mapname"

    New-Item -Name "release" -Type "directory" -Force
    Set-Location "release"
    New-Item -Name "maps" -Type "directory" -Force
    Copy-Item "../$mapname.bsp" -Destination "maps"
    Copy-Item $config.resguyIgnore -Destination .
    Invoke-Expression "$($config.resguy) $mapname -missing"

    foreach ($l in Get-Content -Path "maps/$mapname.res") {
        if ($l -match '^\w+\.wad$') {
            Copy-Item "../$l" -Destination .
        } elseif ($l -match '^\w+') {
            Copy-Item "../../$l" -Destination $l -Force
        }
    }

    if ($config.releaseFolder -ne $null) {
        Copy-Item -Path "*" -Destination $config.releaseFolder -Force -Recurse
    }
} finally {
    Set-Location $pwd
}