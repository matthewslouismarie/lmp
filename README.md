# LMP

LMP is a simple command-line utility that automates the cumbersome, error-prone process of compiling and packaging a map. It can easily be configured to meet varied needs.

![LMP workflow](lmp.webp)

## List of features

The following features can all be used at the same time, or activated separately. It depends on the configuration files passed to LMP.

 - Compiling the map.
 - Copying all the assets the map uses into a separate build folder, ignoring assets already included with the game.
 - Automatically updating the Wads using WadMaker before compilation.
 - Automatically updating the sprites using SpriteMaker before compilation.
 - Exporting the map from .rmf to .map using [MESS](https://github.com/pwitvoet/mess), or use existing .map file.
 - Copying the map and its assets into the game folder.
 - Running MESS, allowing the use of [MESS](https://github.com/pwitvoet/mess) templates inside the map.
 - Using the default configuration, customising only the settings you need to change in one or more separate JSON files.

## Running LMP

After the quick task of configuring LMP (see following section), you can run ``path\to\lmp.ps1 mymap.rmf``. This will compile your map, build your custom used assets, and put them (excluding base assets already included with the game, and the ones not used by the map), into a separate build folder.

> :warning: You need PowerShell 7 to run the script (``winget install --id Microsoft.Powershell --source winget``). You also need to allow the execution of custom scripts using ``Set-ExecutionPolicy unrestricted``.

### -clean

By specifying the ``-clean`` parameter to LMP, you force LMP to use a brand new folder for this run.: ``path\to\lmp.ps1 mymap.rmf -clean``.

> This makes sure no files from any previous run is kept, leading to a lower build folder size. It is recommended for final releases.

## Basic configuration

There are a few settings that must be configured before running LMP for the first time.

You MUST configure LMP before using it. In order to do that, copy the ``default.lmp.json.example`` file and rename it to ``default.lmp.json``. Then modify it.

### "compilers"

You must provide at the very least the correct paths for the compilers.

    "compilers": {
        "bspExecutablePath": "C:/Users/user/Documents/crossedpaths/compilers/SC-BSP_x64.exe",
        "csgExecutablePath": "C:/Users/user/Documents/crossedpaths/compilers/SC-CSG_x64.exe",
        "radExecutablePath": "C:/Users/user/Documents/crossedpaths/compilers/SC-RAD_x64.exe",
        "visExecutablePath": "C:/Users/user/Documents/crossedpaths/compilers/SC-VIS_x64.exe",
        // …
    },

> All paths must use forward slashes "/" (and not backslashes "\").

### "assetsFolderPath" and "wadsUsedByMap"

You also must set ``assetsFolderPath``. LMP will look for the WADs and the other assets your map uses into this directory, and copy the ones not already shipped with the base game or mod into the build folder. You do not need to have any base assets in ``assetsFolderPath``, **apart from the WAD used by your map**. (All the WADs must be included in this directory, this is because they are required for compilation.)

Specify the list of all of the WAD files in the ``list`` in ``wadsUsedByMap``

    "wadsUsedByMap": {
        "description": "MANDATORY.",
        "list": [
            "halflife.wad"
        ]
    }

### MESS and Resguy

It is also heavily recommended to provide a path for [MESS](https://github.com/pwitvoet/mess/releases/tag/1.1) and [Resguy](https://github.com/wootguy/resguy/releases). Download those if you don’t have them, then specify their paths in ``default.lmp.json``.

    "mess": {
        // …
        "executablePath": "C:/Users/user/Documents/crossedpaths/mess_1_2/MESS.exe",
        // …
    },
    // …
    "resguy": {
        // …
        "executablePath": "C:/Users/user/Documents/resguy_v9_windows_x64/resguy.exe",
        "ignoreFilePath": "C:/Users/user/Documents/resguy_v9_windows_x64/resguy_default_content.txt"
    },

MESS allows LMP to export your RMF directly into a MAP file and Resguy allows LMP to copy all the custom assets the map uses into a new build folder.

## Additional settings

If you have any question, just look up the ``default.example.lmp.json`` file for a complete reference of the available options, and ``onlyents.example.lmp.json`` for an example of how you can override just certain settings.

### Creating a configuration file specific to your map

If you do not want to modify the global ``default.lmp.json``, you can create a secondary JSON file containing only the settings you want to override. You then only need to put it into the same folder as your map with the name ``yourmap.lmp.json``.

### Creating a configuration file for certain profiles (fast compile, release build, etc.)

You can also create any number of arbitrary JSON configuration files and pass them to LMP explicitely, by specifying their paths after the path to your map: ``path\to\lmp.ps1 mymap.rmf onlyents.json``.

    {
        "compilers": {
            "csgParams": "-onlyents"
        }
    }

You can pass as many configuration files as you want. If a setting is defined twice, the configuration file that was specified list will have priority.

### Updating assets before build

You can configure LMP to update your Wad before build as well as to update your sprites. See [WadMaker and SpriteMaker](https://github.com/pwitvoet/wadmaker) for their respective documentation.

    "spriteMaker": {
        // …
        "isEnabled": true,
        "executablePath": "C:/Users/user/Documents/crossedpaths/WadMaker_SpriteMaker_1.2/SpriteMaker.exe",
        "imagesFolderPath": "C:/Users/user/Documents/images/sprites"
    },
    "wadMaker": {
        // …
        "isEnabled": true,
        "executablePath": "C:/Users/user/Documents/crossedpaths/WadMaker_SpriteMaker_1.2/WadMaker.exe",
        "imagesFolderPath": "C:/Users/user/Documents/images/textures",
        "wadToBuildFilename": "mywad.wad"
    },

### Copying build to the game folder

If you want to be able to play directly at your map after the build was finished, specify your game or mod folder in ``copyAfterBuild``.

    "copyAfterBuild": {
        // …
        "destinationFolderPath": "C:/Program Files (x86)/Steam/steamapps/common/Sven Co-op/svencoop_addon"
    },

### Removing dev entities

If you want to automatically disable any multi_manager named "mm_devmapstart" that you would use only for dev builds, set ``removeDevEntities`` to true.

### MESS templating engine

If you also want to use the MESS templating engine, specify the other MESS settings.

    "mess": {
        // …
        "templatesFolderPath": "C:/Users/user/Documents/rmf/templates", // if you use MESS external templates
        "transformMapFiles": true
    },

## Performance

Running compilation from a script is more efficient than running it from the map editor. Besides, LMP supports build time optimization using Resguy (ignore assets shipped wit the game), as well as the CSG ``-onlyents`` parameter. It also let WadMaker not do a full rebuild if the Wad wasn’t changed.

## Todo

 - Add option to automatically compile models before compilation.
 - Add GUI.
