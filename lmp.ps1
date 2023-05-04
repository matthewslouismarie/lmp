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
    [Parameter(Mandatory = $true, HelpMessage = "The path to the map (e.g. mymap.rmf, mymap.map or mymap.bsp). Behaviour changes based on the extension!")] $inputMapPath,
    [Parameter(ValueFromRemainingArguments = $true, HelpMessage="Paths to additional configuration files (e.g. nores.json, fastcompile.json, etc.).")] $additionalJsonConfigs,
    [Parameter(HelpMessage = "Whether to create a new folder for the build. If missing, defaults to generic build folder.")] [switch] $clean
)

Set-StrictMode -Version 3.0

$mapName = $null
$inputFileExtension = $null
$inputMapFld = $null

if (Test-Path -LiteralPath $inputMapPath) {
    $mapName, $inputFileExtension = ([regex]::match($inputMapPath, "\w+\.(bsp|rmf|map)$").Groups[0].Value).Split(".")
    if ($mapName -eq $null -or $inputFileExtension -eq $null) {
        throw "LMP: $inputMapPath not a valid file name."
    }

    $inputMapFld = (Convert-Path -LiteralPath $inputMapPath.Substring(0, $inputMapPath.Length - $mapName.Length - 1 - $inputFileExtension.Length))
} else {
    throw "LMP: $inputMapPath not found."
}

if (!(Test-Path -LiteralPath "$PSScriptRoot/default.lmp.json")) {
    throw "LMP: $PSScriptRoot/default.lmp.json not found. You must copy default.lmp.json.example into default.lmp.json and modify the example values."
}

$config = Get-Content -Raw "$PSScriptRoot/default.lmp.json" | ConvertFrom-Json -AsHashTable

if (Test-Path -LiteralPath "$inputMapFld/$mapName.lmp.json") {
    $additionalJsonConfigs += "$inputMapFld/$mapName.lmp.json"
}

foreach ($jsonConfig in $additionalJsonConfigs) {
    $additionalConfig = Get-Content -Raw $jsonConfig | ConvertFrom-Json -AsHashTable
    foreach ($setting in $additionalConfig.GetEnumerator()) {
        if ($setting.Value -eq $null) {
            $config[$setting.Name] = $setting.Value
        } elseif ($setting.Value.GetType().Name -ceq "OrderedHashtable") {
            foreach ($subSetting in $setting.Value.GetEnumerator()) {
                $config[$setting.Name][$subSetting.Name] = $subSetting.Value
            }
        } else {
            $setting.Value.GetType().Name
            $config[$setting.Name] = $setting.Value
        }
    }
}

$runFldName = "lmp_$mapName"
$userPwd = Get-Location

try {
    # Remove existing folder, if it exists, in $clean mode
    if ($clean) {
        if (Test-Path -LiteralPath $runFldName -PathType Container) {
            Write-Output "LMP: Removing existing $runFldName folder."
            Remove-Item -Force -Path $runFldName -Recurse
            if (!$?) {
                Throw "LMP: Could not delete existing $runFldName."
            }
        }
    }

    # Create folder for the run if it doesn’t exist
    if (!(Test-Path -LiteralPath $runFldName -PathType Container)) {
        Write-Output "LMP: Creating new $runFldName folder."
        New-Item -Name $runFldName -Force -ItemType Directory
    }

    # Move into run folder
    Write-Output "LMP: Moving into $runFldName."
    Set-Location $runFldName
    if (!$?) {
        Throw "LMP: Could not move into $runFldName."
    }

    # If SpriteMaker is enabled
    if ($config.spriteMaker -ne $null -and $config.spriteMaker.isEnabled) {
        Write-Output "LMP: Generating sprites with SpriteMaker."
        Invoke-Expression "$($config.spriteMaker.executablePath) -subdirs -nologfile $($config.spriteMaker.imagesFolderPath) $($config.assetsFolderPath)/sprites"
        if (!$?) {
            Throw "LMP: SpriteMaker failed."
        }
    }

    # If WadMaker is enabled
    if ($config.wadMaker -ne $null -and $config.wadMaker.isEnabled) {
        Write-Output "LMP: Updating $($config.wadMaker.wadToBuildFilename)."
        Invoke-Expression "$($config.wadMaker.executablePath) $($clean ? "-full" : " ") -subdirs -nologfile $($config.wadMaker.imagesFolderPath) $($config.assetsFolderPath)/$($config.wadMaker.wadToBuildFilename)"
        if (!$?) {
            Throw "LMP: WadMaker failed."
        }
    }

    # Copy Wads into run folder
    foreach ($wad in $config.wadsUsedByMap.list) {
        Write-Output "LMP: Copying $wad into $runFldName."
        Copy-Item -LiteralPath "$($config.assetsFolderPath)/$wad" -Force
    }

    # if ($config._studiomdl -ne $null -and $config.mdlToBuild -ne $null) {
    #     foreach ($smd in Get-ChildItem -Include '*.qc' -Path $config.mdlToBuild -Recurse) {
    #         Invoke-Expression "$($config._studiomdl) $($config.mdlToBuild)/$($smd.Name)"
    #     }
    #     foreach ($mdl in Get-ChildItem -Include '*.mdl' -Path $config.mdlToBuild) {
    #         Copy-Item $mdl -Destination $config.mdlFld
    #     }
    # }

    # If the input file is an .rmf file, export it to map.
    if ($inputFileExtension -ceq "rmf") {
        Write-Output "LMP: Using MESS to export $mapName.rmf to $mapName.map."

        if ($config.mess -eq $null -or $config.mess.executablePath -eq $null) {
            Throw "LMP: A MESS executable MUST be specified in the configuration file to export the RMF to .map."
        }

        # Copy input RMF file into the build folder
        Copy-Item -LiteralPath "$inputMapFld/$mapName.rmf" -Force
        if (!$?) {
            throw 'LMP: Failed to copy RMF into the build folder.'
        }

        # Run MESS on the input RMF file
        if ($config.mess.templatesFolderPath -ne $null) {
            Invoke-Expression "$($config.mess.executablePath) -dir $($config.mess.templatesFolderPath) -log verbose $mapName.rmf $mapName.map"
        } else {
            Invoke-Expression "$($config.mess.executablePath) -log verbose $mapName.rmf $mapName.map"
        }
        if (!$?) {
            throw 'LMP: MESS failed to export the map to a MAP file.'
        }

        # Add list of used WADs in the exported MAP file
        (Get-Content "$mapName.map") | Foreach-Object {
            $_
            if ($_ -like '"classname" "worldspawn"') {
                '"wad" "' + ($config.wadsUsedByMap.list -join ";") + '"'
            }
        } | Set-Content "$mapName.map"
        if (!$?) {
            throw 'LMP: Failed to add the WADs to the MAP file.'
        }
    }

    # Run MESS if MESS executable is specified and if it wasn’t run during rmf export to map
    if ($config.mess -ne $null -and $config.mess.transformMapFiles -ne $null -and $inputFileExtension -cne "rmf") {
        Write-Output "LMP: Running MESS on $mapName.map."
        if ($config.mess.templatesFolderPath -ne $null) {
            Invoke-Expression "$($config.mess.executablePath) -dir $($config.mess.templatesFolderPath) $($config.mess.params) $mapName"
        } else {
            Invoke-Expression "$($config.mess.executablePath) $($config.mess.params) $mapName"
        }
        if (!$?) {
            throw 'LMP: MESS did not execute correctly.'
        }
    }

    # Disable mm_devmapstart when removeDevEntities is enabled
    if ($config.removeDevEntities -eq $true) {
        Write-Output "LMP: Renaming mm_devmapstart to mm_devmapstart_dis to disable it (not in dev mode)."
        (Get-Content "$mapName.map") -Replace '"targetname" "mm_devmapstart"', '"targetname" "mm_devmapstart_dis"' | Set-Content "$mapName.map"
    }

    # Compile the map if input file isn’t a .bsp file.
    if (-not ($inputFileExtension -ceq "bsp")) {
        Write-Output "LMP: Compiling the map."

        if (Test-Path -LiteralPath "$inputMapFld/$mapName.rad") {
            Write-Output "LMP: RAD file detected. Copying it to run folder."
            Copy-Item -LiteralPath "$inputMapFld/$mapName.rad" -Force
            if (!$?) {
                throw 'LMP: Could not copy RAD file into the build folder.'
            }
        }

        Invoke-Expression "$($config.compilers.csgExecutablePath) $($config.compilers.csgParams) $mapName"
        if (!($config.compilers.csgParams -Match "-onlyents")) {
            Invoke-Expression "$($config.compilers.bspExecutablePath) $($config.compilers.bspParams) $mapName"
            Invoke-Expression "$($config.compilers.visExecutablePath) $($config.compilers.visParams) $mapName"
            Invoke-Expression "$($config.compilers.radExecutablePath) $($config.compilers.radParams) $mapName"
        } else {
            Write-Output "LMP: -onlyents: Only CSG was called."
        }
        if (!$?) {
            throw 'LMP: There was an error during compilation.'
        }
    } else {
        Write-Output "LMP: Map already compiled. Copying existing $mapName.bsp into $runFldName."
        Copy-Item -LiteralPath "$($config.assetsFolderPath)/maps/$mapName.bsp" -Force
        if (!$?) {
            throw 'LMP: Could not copy existing BSP into the build folder.'
        }
    }

    # Create build folder
    Write-Output "LMP: Creating build folder."
    New-Item -Name "build" -Force -ItemType Directory
    Set-Location "build"
    if (!$?) {
        throw 'LMP: Could not move into build folder.'
    }

    # Copy BSP into the build folder
    Write-Output "LMP: Copying BSP into the build folder."
    New-Item -Name "maps" -Force -ItemType Directory
    Copy-Item -LiteralPath "../$mapName.bsp" -Destination "maps" -Force
    if (!$?) {
        throw 'LMP: Could not move BSP into the build folder.'
    }

    # If Resguy is set, generate RES file and copy assets into the build folder
    if ($config.resguy -ne $null -and $config.resguy.isEnabled) {
        Write-Output "LMP: Copying assets used by the map into the build folder using Resguy."

        Copy-Item -LiteralPath $config.resguy.ignoreFilePath -Force
        Invoke-Expression "$($config.resguy.executablePath) $mapName -extra -missing" > $null
        if (!$?) {
            Throw 'LMP: Resguy failed generating a .RES file on the first run.'
        }

        if (Test-Path -Path "maps/$mapName.res") {
            foreach ($l in Get-Content -Path "maps/$mapName.res") {
                if (!($l -match '^\w+\.(bsp|res)$')) {
                    if ($l -match '^\w+\.wad$') {
                        Copy-Item -LiteralPath "../$l" -Force
                    } elseif ($l -match '^\w+') {
                        New-Item -Path ([regex]::match($l, '^[\w/]+/').Groups[0].Value) -Force -ItemType Directory
                        Copy-Item -LiteralPath "$($config.assetsFolderPath)/$l" -Destination $l -Force
                    }
                    Throw "LMP: Failed to copy $l into the build folder."
                }
            }
        } else {
            Write-Output "LMP: No assets were copied because the map doesn’t use any."
        }

        # Re-generate the RES file without admin files and let Resguy detect missing files.
        Invoke-Expression "$($config.resguy.executablePath) $mapName -missing" > "..\resguy.log"
        if (!$?) {
            Throw 'LMP: Resguy failed generating a .RES file on the second run.'
        }
        Get-Content "..\resguy.log"

        Remove-Item ([regex]::match($config.resguy.ignoreFilePath, '\w+\.txt$').Groups[0].Value)
        Write-Output "LMP: Done with copying assets into the build folder. Check the resguy.log file for more information."
    }

    # If the config specifies a file to which the build must be copied
    if ($config.copyAfterBuild.destinationFolderPath -ne $null) {
        Write-Output "LMP: Copying the map and its assets to the game folder."
        Copy-Item -Path "*" -Destination $config.copyAfterBuild.destinationFolderPath -Force -Recurse
        if (!$?) {
            Throw "LMP: Could not copy all the files into the game folder."
        }
    }
} finally {
    Set-Location $userPwd
    Write-Output "LMP: Done."
}