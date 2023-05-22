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
# @todo Verify JSON schema

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
$inputMapAbsolutePath = $null

# Creating and populating $mapName, $inputFileExtension, and $inputMapFld
if ($inputMapPath -ceq "-") {
    Write-Output "LMP: No map was specified."
} elseif (Test-Path -LiteralPath $inputMapPath) {
    $mapName, $inputFileExtension = ([regex]::match($inputMapPath, "\w+\.(bsp|rmf|map)$").Groups[0].Value).Split(".")
    if ($mapName -eq $null -or $inputFileExtension -eq $null) {
        throw "LMP: $inputMapPath not a valid file name."
    }

    $inputMapAbsolutePath = Convert-Path -LiteralPath $inputMapPath
    $inputMapFld = $inputMapAbsolutePath.Substring(0, $inputMapAbsolutePath.Length - $mapName.Length - 1 - $inputFileExtension.Length)
} else {
    throw "LMP: $inputMapPath not found."
}

# Creating and populating $config
if (!(Test-Path -LiteralPath "$PSScriptRoot/default.lmp.json")) {
    throw "LMP: $PSScriptRoot/default.lmp.json not found. You must copy default.lmp.json.example into default.lmp.json and modify the example values."
}

$config = Get-Content -Raw "$PSScriptRoot/default.lmp.json" | ConvertFrom-Json -AsHashTable

if (Test-Path -LiteralPath "$inputMapFld/$mapName.lmp.json") {
    $additionalJsonConfigs += "$inputMapFld/$mapName.lmp.json"
}

foreach ($jsonConfig in $additionalJsonConfigs) {
    $additionalConfig = Get-Content -Raw $jsonConfig | ConvertFrom-Json -AsHashTable
    if (!$?) {
        throw "LMP: Could not read $jsonConfig."
    }
    foreach ($setting in $additionalConfig.GetEnumerator()) {
        if ($setting.Value.GetType().Name -ceq "OrderedHashtable" -and ($config[$setting.Name] -ne $null)) {
            foreach ($subSetting in $setting.Value.GetEnumerator()) {
                $config[$setting.Name][$subSetting.Name] = $subSetting.Value
            }
        } else {
            $config[$setting.Name] = $setting.Value
        }
    }
}

# IF SpriteMaker is enabled
if ($config.spriteMaker -ne $null -and $config.spriteMaker.isEnabled) {
    Write-Output "LMP: Generating sprites with SpriteMaker."
    Invoke-Expression "$($config.spriteMaker.executablePath) -subdirs -nologfile $($config.spriteMaker.imagesFolderPath) $($config.assetsFolderPath)/sprites"
    if (!$?) {
        Throw "LMP: SpriteMaker failed."
    }
}

# IF WadMaker is enabled
if ($config.wadMaker -ne $null -and $config.wadMaker.isEnabled -and ($config.wadMaker.wadsToBuild -ne $null)) {
    foreach ($wad in $config.wadMaker.wadsToBuild) {
        Write-Output "LMP: Updating $($wad.filename)."
        Invoke-Expression "$($config.wadMaker.executablePath) $($clean ? "-full" : " ") -subdirs -nologfile $($wad.imageFldPath) $($config.assetsFolderPath)/$($wad.filename)"
        if (!$?) {
            Throw "LMP: WadMaker failed."
        }
    }
}

# if ($config._studiomdl -ne $null -and $config.mdlToBuild -ne $null) {
#     foreach ($smd in Get-ChildItem -Include '*.qc' -Path $config.mdlToBuild -Recurse) {
#         Invoke-Expression "$($config._studiomdl) $($config.mdlToBuild)/$($smd.Name)"
#     }
#     foreach ($mdl in Get-ChildItem -Include '*.mdl' -Path $config.mdlToBuild) {
#         Copy-Item $mdl -Destination $config.mdlFld
#     }
# }

if ($mapName -ne $null) {
    Write-Output "LMP: Beginning map build."
    $runFldName = "lmp_$mapName"
    $userPwd = Get-Location

    # Remove existing folder, if it exists, in $clean mode
    if ($clean) {
        if (Test-Path -LiteralPath $runFldName -PathType Container) {
            Write-Output "LMP: Removing existing $runFldName folder."
            Remove-Item -Force -LiteralPath $runFldName -Recurse
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

    try {
        # Move into run folder
        Write-Output "LMP: Moving into $runFldName."
        Set-Location $runFldName
        if (!$?) {
            Throw "LMP: Could not move into $runFldName."
        }

        if ($inputFileExtension -ceq "rmf") {
            # IF the input map is an RMF file, export it to map.
            Write-Output "LMP: Using MESS to export $mapName.rmf to $mapName.map."

            if ($config.mess -eq $null) {
                Throw "LMP: A MESS executable MUST be specified in the configuration file to export the RMF to .map."
            }

            # Copy input RMF file into the build folder
            Copy-Item -LiteralPath "$inputMapFld/$mapName.rmf" -Force
            if (!$?) {
                throw 'LMP: Failed to copy RMF into the build folder.'
            }

            # Run MESS on the input RMF file
            if ($config.mess.templatesFolderPath -ne $null -and $config.mess.transformMapFiles) {
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
                throw 'LMP: Failed to add the WAD files to the MAP file.'
            }
        } elseif ($config.mess -ne $null -and $config.mess.transformMapFiles -eq $true -and $inputFileExtension -cne "map") {
            # IF the input map is a MAP file and the MESS executable is specified and transformMapFiles is set to true, run MESS on MAP file
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



        # IF the input map isn’t a BSP file
        if (-not ($inputFileExtension -ceq "bsp")) {
            # IF removeDevEntities is set to true, disable mm_devmapstart
            if ($config.removeDevEntities -eq $true -and (-not ($inputFileExtension -ceq "bsp"))) {
                Write-Output "LMP: Renaming mm_devmapstart to mm_devmapstart_dis to disable it (not in dev mode)."
                (Get-Content "$mapName.map") -Replace '"targetname" "mm_devmapstart"', '"targetname" "mm_devmapstart_dis"' | Set-Content "$mapName.map"
            }

            # Compile the map
            Write-Output "LMP: Compiling the map."

            # Copy Wads into run folder
            foreach ($wad in $config.wadsUsedByMap.list) {
                Write-Output "LMP: Copying $wad into $runFldName."
                Copy-Item -LiteralPath "$($config.assetsFolderPath)/$wad" -Force
            }

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
            if ($inputMapFld -ceq (Get-Location)) {
                Copy-Item -LiteralPath $inputMapAbsolutePath -Force
                if (!$?) {
                    throw 'LMP: Could not copy existing BSP into the run folder.'
                }
            } else {
                Write-Output "LMP: BSP already in run folder."
            }
        }

        # Create build folder and move into it
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
            Invoke-Expression "$($config.resguy.executablePath) $mapName -extra -missing" > "..\resguy_all.log"
            if (!$?) {
                Throw 'LMP: Resguy failed generating a .RES file on the first run.'
            }

            if ($config.additionalAssets -ne $null) {
                Write-Output "LMP: Copying additional assets."
                foreach ($asset in $config.additionalAssets) {
                    New-Item -Path ([regex]::match($asset, '^[\w/]+/').Groups[0].Value) -Force -ItemType Directory
                    Copy-Item -LiteralPath "$($config.assetsFolderPath)/$asset" -Destination $asset -Force
                    if (!$?) {
                        Write-Error "LMP: Failed copying $asset into build folder."
                    }
                    Write-Output "LMP: Copied $asset into build folder."
                }
                Write-Output "LMP: Done copying additional assets."
            }

            if (Test-Path -LiteralPath "$($config.assetsFolderPath)/maps/$mapName.cfg") {
                Copy-Item -LiteralPath "$($config.assetsFolderPath)/maps/$mapName.cfg"-Destination "maps"
            }

            if (Test-Path -LiteralPath "maps/$mapName.res") {
                foreach ($l in Get-Content -Path "maps/$mapName.res") {
                    if ($l -match '^([a-zA-Z0-9_]+\/)*[a-zA-Z0-9_]+\.[a-zA-Z0-9_]+$') {
                        if ($l -match '^[a-zA-Z0-9_]+\.wad$') {
                            Copy-Item -LiteralPath "$($config.assetsFolderPath)/$l" -Force
                            if (!$?) {
                                Write-Error "LMP: Failed to copy WAD file $l into the build folder."
                            }
                        } elseif (($l -ceq "maps/$mapName.bsp") -or ($l -ceq "maps/$mapName.res")) {
                            Write-Output "LMP: Ignoring $l"
                        } else {
                            New-Item -Path ([regex]::match($l, '^[\w/]+/').Groups[0].Value) -Force -ItemType Directory
                            Copy-Item -LiteralPath "$($config.assetsFolderPath)/$l" -Destination $l -Force
                            if (!$?) {
                                Write-Error "LMP: Failed to copy $l into the build folder."
                            }
                        }
                    }
                }
            } else {
                Write-Output "LMP: No RES assets were copied because the map doesn’t use any."
            }

            # Re-generate the RES file without admin files and let Resguy detect missing files.
            Invoke-Expression "$($config.resguy.executablePath) $mapName -missing" > "..\resguy.log"
            if (!$?) {
                Throw 'LMP: Resguy failed generating a .RES file on the second run.'
            }
            Get-Content "..\resguy.log"

            Remove-Item ([regex]::match($config.resguy.ignoreFilePath, '\w+\.txt$').Groups[0].Value)
            Write-Output "LMP: Done with copying RES assets into the build folder. Check the resguy.log file for more information."
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
    }
}

Write-Output "LMP: Done."