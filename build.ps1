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
# @todo Validate config file, check that code should throw error if config file is invalid or field is not specified

# Paths specified in the configuration file must not have trailing slashes.

param(
    [Parameter(Mandatory = $true, HelpMessage = "The filename of the map, without any extension.")] $mapname,
    [Parameter(Mandatory = $true, HelpMessage = "The filename of the LMP profile.")] $mainprofile,
    [parameter(ValueFromRemainingArguments = $true, HelpMessage="Paths to additional profiles.")] $profiles,
    [Parameter(HelpMessage = "Whether to compile in prod mode. If missing, defaults to dev mode.")] [switch] $prod,
    [Parameter(HelpMessage = "Whether to create a new folder for the build. If missing, defaults to generic build folder.")] [switch] $clean
)

Set-StrictMode -Version 3.0

$config = Get-Content -Raw $mainprofile | ConvertFrom-Json -AsHashTable
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
    if ($config.compile -and (Test-Path -Path "$($config.compileRadFileFld)/$mapname.rad")) {
        Copy-Item "$($config.compileRadFileFld)/$mapname.rad" -Destination .
    }

    if ($config._wadMaker -ne $null) {
        Invoke-Expression "$($config._wadMaker) -subdirs -nologfile $($config._wadMakerTexturesFld) $($config.assetFld)/$($config._wadMakerWadName)"
    }

    foreach ($wad in $config.wads) {
        Copy-Item "$($config.assetFld)/$wad" -Destination .
    }

    if ($config._sprMaker -ne $null) {
        Invoke-Expression "$($config._sprMaker) -subdirs -nologfile $($config._sprMakerFldToBuild) $($config.assetFld)/sprites"
    }

    # if ($config._studiomdl -ne $null -and $config.mdlToBuild -ne $null) {
    #     foreach ($smd in Get-ChildItem -Include '*.qc' -Path $config.mdlToBuild -Recurse) {
    #         Invoke-Expression "$($config._studiomdl) $($config.mdlToBuild)/$($smd.Name)"
    #     }
    #     foreach ($mdl in Get-ChildItem -Include '*.mdl' -Path $config.mdlToBuild) {
    #         Copy-Item $mdl -Destination $config.mdlFld
    #     }
    # }

    if ($config.map -eq $true) {
        if ($config.mapExporter -ceq "mess") {
            Copy-Item "$($config.mapRmfFld)/$mapname.rmf" -Destination .
            Invoke-Expression "$($config._mess) -dir $($config._messTemplatesFld) -log verbose $mapname.rmf $mapname.map"
            (Get-Content "$mapname.map") | Foreach-Object {
                $_
                if ($_ -like '"classname" "worldspawn"') {
                    '"wad" "' + ($config.wads -join ";") + '"'
                }
            } | Set-Content "$mapname.map"
        } elseif ($config.mapExporter -eq $null) {
            Copy-Item "$($config.mapRmfFld)/$mapname.map" -Destination .
        } else {
            throw "Invalid mapExporter value."
        }

        if ($config._mess -ne $null) {
            Invoke-Expression "$($config._mess) -dir $($config._messTemplatesFld) $($config._messParams) $mapname"
        }

        if ($config.prod -eq $true) {
            (Get-Content "$mapname.map") -Replace '"targetname" "mm_devmapstart"', '"targetname" "mm_devmapstart_dis"' | Set-Content "$mapname.map"
        }
    }

    if ($config.compile) {
        Invoke-Expression "$($config.compileCsg) $($config.compileCsgParams) $mapname"
        if (!($config.compileCsgParams -Match "-onlyents")) {
            Invoke-Expression "$($config.compileBsp) $($config.compileBspParams) $mapname"
            Invoke-Expression "$($config.compileVis) $($config.compileVisParams) $mapname"
            Invoke-Expression "$($config.compileRad) $($config.compileRadParams) $mapname"
        }
    } else {
        Copy-Item "$($config.assetFld)/maps/$mapname.bsp" -Destination .
    }

    New-Item -Name "release" -ItemType Directory -Force
    Set-Location "release"
    New-Item -Name "maps" -ItemType Directory -Force
    Copy-Item "../$mapname.bsp" -Destination "maps"

    if ($config._resguy -ne $null) {
        Copy-Item $config._resguyIgnore -Destination .
        Invoke-Expression "$($config._resguy) $mapname -missing" > "../$mapname.res.log"

        foreach ($l in Get-Content -Path "maps/$mapname.res") {
            if ($l -match '^\w+\.wad$') {
                Copy-Item "../$l" -Destination .
            } elseif ($l -match '^\w+') {
                New-Item -Path ([regex]::match($l, '^[\w/]+/').Groups[0].Value) -ItemType Directory -Force
                Copy-Item "$($config.assetFld)/$l" -Destination $l -Force
            }
        }
        Remove-Item ([regex]::match($config._resguyIgnore, '\w+\.txt$').Groups[0].Value) -Force
    }

    if (Test-Path -Path "$($config.assetFld)/maps/$mapname.cfg") {
        Copy-Item "$($config.assetFld)/maps/$mapname.cfg" -Destination "maps" -Force
    }

    if (Test-Path -Path "$($config.assetFld)/scripts") {
        Copy-Item "$($config.assetFld)/scripts" -Destination . -Force -Recurse
    }

    if ($config._releaseCopyFld -ne $null) {
        Copy-Item -Path "*" -Destination $config._releaseCopyFld -Force -Recurse
    }
} finally {
    Set-Location $pwd
}