# DONE allow using the map file directly
# DONE support for MESS
# DONE Remove useless files from RES
# DONE default values for config
# DONE profile
# DONE return to original directory always
# compile sprites
# compile smd
# GUI
# DONE Remove dev entities

# Paths specified in the configuration file must not have trailing slashes.

param(
    [Parameter(Mandatory = $true, HelpMessage = "The filename of the map, without any extension.")] $mapname,
    [Parameter(Mandatory = $true, HelpMessage = "The filename of the configuration file.")] $json,
    [Parameter(HelpMessage = "Whether to compile in prod mode. If missing, defaults to dev mode.")] [switch] $prod,
    [Parameter(HelpMessage = "Whether to create a new folder for the build. If missing, defaults to generic build folder.")] [switch] $clean,
    [parameter(ValueFromRemainingArguments = $true, HelpMessage="Paths to additional profiles.")] $profiles
)

Set-StrictMode -Version 3.0

$config = Get-Content -Raw $json | ConvertFrom-Json -AsHashTable
foreach ($p in $profiles) {
    $subconfig = Get-Content -Raw $p | ConvertFrom-Json -AsHashTable
    foreach ($c in $subconfig.GetEnumerator()) {
        $config[$c.Name] = $c.Value
    }
}

# Create a build assigned with this run
$build = $clean ? "build_$(Get-Date -Format FileDateTimeUniversal)_$mapname" : "build_$mapname"
New-Item -Name $build -ItemType Directory -Force
$pwd = Get-Location
Set-Location $build
try {
    if (Test-Path -Path "$($config.radFld)/$mapname.rad") {
        Copy-Item "$($config.radFld)/$mapname.rad" -Destination .
    }

    if ($config.wadToBuild -ne $null) {
        Invoke-Expression "$($config.wadmaker) -subdirs -nologfile $($config.texturesFld) $($config.wadFld)/$($config.wadToBuild)"
    }
    foreach ($wad in $config.wads) {
        Copy-Item "$($config.wadFld)/$wad" -Destination .
    }

    if ($config.assetSprToBuildFld -ne $null) {
        Invoke-Expression "$($config.spritemaker) -subdirs -nologfile $($config.assetSprToBuildFld) $($config.assetSprFld)"
    }

    # if ($config.studiomdl -ne $null -and $config.mdlToBuild -ne $null) {
    #     foreach ($smd in Get-ChildItem -Include '*.qc' -Path $config.mdlToBuild -Recurse) {
    #         Invoke-Expression "$($config.studiomdl) $($config.mdlToBuild)/$($smd.Name)"
    #     }
    #     foreach ($mdl in Get-ChildItem -Include '*.mdl' -Path $config.mdlToBuild) {
    #         Copy-Item $mdl -Destination $config.mdlFld
    #     }
    # }

    if ($config.mapExporter -ceq "mess") {
        Copy-Item "$($config.rmfFld)/$mapname.rmf" -Destination .
        Invoke-Expression "$($config.mess) -dir $($config.messTemplatesFld) -log verbose $mapname.rmf $mapname.map"
        (Get-Content "$mapname.map") | Foreach-Object {
            $_
            if ($_ -like '"classname" "worldspawn"') {
                '"wad" "' + ($config.wads -join ";") + '"'
            }
        } | Set-Content "$mapname.map"
    } elseif ($config.mapExporter -ceq $null) {
        Copy-Item "$($config.rmfFld)/$mapname.map" -Destination .
    }

    if ($prod) {
        (Get-Content "$mapname.map") -Replace '"targetname" "mm_devmapstart"', '"targetname" "mm_devmapstart_dis"' | Set-Content "$mapname.map"
    }

    Invoke-Expression "$($config.mess) -dir $($config.messTemplatesFld) $($config.messParams) $mapname"
    Invoke-Expression "$($config.csg) $($config.csgParams) $mapname"
    Invoke-Expression "$($config.bsp) $($config.bspParams) $mapname"
    Invoke-Expression "$($config.vis) $($config.visParams) $mapname"
    Invoke-Expression "$($config.rad) $($config.radParams) $mapname"

    New-Item -Name "release" -ItemType Directory -Force
    Set-Location "release"
    New-Item -Name "maps" -ItemType Directory -Force
    Copy-Item "../$mapname.bsp" -Destination "maps"
    Copy-Item $config.resguyIgnore -Destination .
    Invoke-Expression "$($config.resguy) $mapname -missing"

    foreach ($l in Get-Content -Path "maps/$mapname.res") {
        if ($l -match '^\w+\.wad$') {
            Copy-Item "../$l" -Destination .
        } elseif ($l -match '^\w+') {
            New-Item -Path ([regex]::match($l, '^[\w/]+/').Groups[0].Value) -ItemType Directory -Force
            Copy-Item "$($config.assetFld)/$l" -Destination $l -Force
        }
    }

    Remove-Item ([regex]::match($config.resguyIgnore, '\w+\.txt$').Groups[0].Value) -Force

    if ($config.assetCfgFld -ne $null) {
        Copy-Item "$($config.assetCfgFld)/$mapname.cfg" -Destination "maps" -Force
    }

    if ($config.assetScriptFld -ne $null) {
        Copy-Item "$($config.assetScriptFld)" -Destination . -Force -Recurse
    }

    if ($config.releaseCopyFld -ne $null) {
        Copy-Item -Path "*" -Destination $config.releaseCopyFld -Force -Recurse
    }
} finally {
    Set-Location $pwd
}