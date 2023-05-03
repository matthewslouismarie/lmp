# LMP: Package a map and its dependencies into a folder.
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
    [Parameter(Mandatory = $true, HelpMessage = "The map filename, excluding any extension (e.g. mymap).")] $mapname,
    [Parameter(Mandatory = $true, HelpMessage = "The path to the main JSON configuration file (e.g. hl.json).")] $mainprofile,
    [parameter(ValueFromRemainingArguments = $true, HelpMessage="Paths to additional profiles (e.g. nores.json, fastcompile.json, etc.).")] $profiles,
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

$runFldName = $clean ? "lmp_$(Get-Date -Format FileDateTimeUniversal)_$mapname" : "lmp_$mapname"
$userPwd = Get-Location

try {
    # Create a folder assigned with this run
    Write-Output "LMP: Moving into $runFldName."
    New-Item -Name $runFldName -Force -ItemType Directory
    Set-Location $runFldName

    if ($config.compile -and (Test-Path -Path "$($config.compileRadFileFld)/$mapname.rad")) {
        Write-Output "LMP: Copying $mapname.rad into $runFldName."
        Copy-Item "$($config.compileRadFileFld)/$mapname.rad" -Destination . -Force
    }

    if ($config._wadMaker -ne $null) {
        Write-Output "LMP: Updating $($config._wadMakerWadName)."
        Invoke-Expression "$($config._wadMaker) -subdirs -nologfile $($config._wadMakerTexturesFld) $($config.assetFld)/$($config._wadMakerWadName)"
    }

    foreach ($wad in $config.wads) {
        $resguyIgnore = ($config._resguyIgnore -ne $null) ? (Get-Content $config._resguyIgnore) : $null
        if ($resguyIgnore -ne $null -and $resguyIgnore.Contains($wad)) {
            Write-Output "LMP: Ignoring $wad."
        } else {
            Write-Output "LMP: Copying $wad into $runFldName."
            Copy-Item "$($config.assetFld)/$wad" -Destination . -Force
        }
    }

    if ($config._sprMaker -ne $null) {
        Write-Output "LMP: Generating sprites with SpriteMaker."
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
            Write-Output "LMP: Using MESS to export $mapname.rmf to $mapname.map."
            Copy-Item "$($config.mapRmfFld)/$mapname.rmf" -Destination . -Force
            Invoke-Expression "$($config._mess) -dir $($config._messTemplatesFld) -log verbose $mapname.rmf $mapname.map"
            (Get-Content "$mapname.map") | Foreach-Object {
                $_
                if ($_ -like '"classname" "worldspawn"') {
                    '"wad" "' + ($config.wads -join ";") + '"'
                }
            } | Set-Content "$mapname.map"
        } elseif ($config.mapExporter -eq $null) {
            Write-Output "LMP: Copying existing $mapname.map into $runFldName."
            Copy-Item "$($config.mapRmfFld)/$mapname.map" -Destination . -Force
        } else {
            throw "Invalid mapExporter value."
        }

        if ($config._mess -ne $null) {
            Write-Output "LMP: Running MESS on $mapname.map."
            Invoke-Expression "$($config._mess) -dir $($config._messTemplatesFld) $($config._messParams) $mapname"
        }

        if ($config.prod -eq $true) {
            Write-Output "LMP: Renaming mm_devmapstart to mm_devmapstart_dis to disable it (prod mode)."
            (Get-Content "$mapname.map") -Replace '"targetname" "mm_devmapstart"', '"targetname" "mm_devmapstart_dis"' | Set-Content "$mapname.map"
        }
    }

    if ($config.compile) {
        Write-Output "LMP: Compiling the map."
        Invoke-Expression "$($config.compileCsg) $($config.compileCsgParams) $mapname"
        if (!($config.compileCsgParams -Match "-onlyents")) {
            Invoke-Expression "$($config.compileBsp) $($config.compileBspParams) $mapname"
            Invoke-Expression "$($config.compileVis) $($config.compileVisParams) $mapname"
            Invoke-Expression "$($config.compileRad) $($config.compileRadParams) $mapname"
        } else {
            Write-Output "LMP: -onlyents: Only CSG was called."
        }
    } else {
        Write-Output "LMP: Compilation deactivated, copying existing $mapname.bsp into $runFldName."
        Copy-Item "$($config.assetFld)/maps/$mapname.bsp" -Destination . -Force
    }

    New-Item -Name "build" -Force -ItemType Directory
    Set-Location "build"
    Write-Output "LMP: build folder created."
    New-Item -Name "maps" -Force -ItemType Directory
    Copy-Item "../$mapname.bsp" -Destination "maps" -Force
    Write-Output "LMP: BSP copied to the build folder."

    if ($config._resguy -ne $null) {
        Write-Output "LMP: Copying assets used by the map into the build folder"

        Copy-Item $config._resguyIgnore -Destination . -Force
        Invoke-Expression "$($config._resguy) $mapname -extra -missing" > $null

        if (Test-Path -Path "maps/$mapname.res") {
            foreach ($l in Get-Content -Path "maps/$mapname.res") {
                if (!($l -match '^\w+\.(bsp|res)$')) {
                    if ($l -match '^\w+\.wad$') {
                        Copy-Item "../$l" -Destination . -Force
                    } elseif ($l -match '^\w+') {
                        New-Item -Path ([regex]::match($l, '^[\w/]+/').Groups[0].Value) -Force -ItemType Directory
                        Copy-Item "$($config.assetFld)/$l" -Destination $l -Force
                    }
                }
            }
        } else {
            Write-Output "LMP: No assets were copied because the map doesn’t use any."
        }

        # Re-generate the RES file without admin files and let Resguy detect missing files.
        Invoke-Expression "$($config._resguy) $mapname -missing" > "..\resguy.log"
        Get-Content "..\resguy.log"

        Remove-Item ([regex]::match($config._resguyIgnore, '\w+\.txt$').Groups[0].Value)
        Write-Output "LMP: Done with copying assets into the build folder. Check the resguy.log file for more information."
    }

    if ($config._buildCopyFld -ne $null) {
        Write-Output "LMP: Copying the map and its assets to the game folder."
        Copy-Item -Path "*" -Destination $config._buildCopyFld -Force -Recurse
    }
} finally {
    Set-Location $userPwd
    Write-Output "LMP: Done."
}