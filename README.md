# LMP

LMP is a utility that aims to streamline the process of packaging a map and its assets. It can easily be configured to meet varied needs.

## Running LMP

After the quick task of configuring LMP (see following section), you can run ``path\to\lmp.ps1 mymap.rmf``. This will compile your map and put it, along all the custom assets it uses (excluding base ones already shipped with the game it is meant for), into a separate build folder.

> :warning: You need PowerShell 7 to run the script (``winget install --id Microsoft.Powershell --source winget``). You also need to allow the execution of custom scripts using ``Set-ExecutionPolicy unrestricted``.

## Minimum settings

You MUST configure it before using it. In order to do that, copy the ``default.lmp.json.example`` file and rename it to ``default.lmp.json``. Then modify it. You must provide at the very least the correct paths for the compilers.

    "compilers": {
        // …
        "bspExecutablePath": "C:/Users/user/Documents/crossedpaths/compilers/SC-BSP_x64.exe",
        "csgExecutablePath": "C:/Users/user/Documents/crossedpaths/compilers/SC-CSG_x64.exe",
        "radExecutablePath": "C:/Users/user/Documents/crossedpaths/compilers/SC-RAD_x64.exe",
        "visExecutablePath": "C:/Users/user/Documents/crossedpaths/compilers/SC-VIS_x64.exe",
        // …
    },

> All paths must use forward slashes "/" (and not backslashes "\").

You also must set ``assetsFolderPath`` and the ``list`` in ``wadsUsedByMap``. LMP will look for the WADs and the other assets your map uses into this directory, and copy the ones not already shipped with the base game or mod into the build folder. You do not need to have any base assets in ``assetsFolderPath``, apart from the WAD files your map uses. (Even base WADs must be included in this directory.)

It is also heavily recommended to provide a path for [MESS](https://github.com/pwitvoet/mess/releases/tag/1.1) and [Resguy](https://github.com/wootguy/resguy/releases). Download those if you don’t have them, then specify their paths in ``default.lmp.json``.

    "mess": {
        // …
        "executablePath": "C:/Users/l/Documents/crossedpaths/mess_1_2/MESS.exe",
        // …
    },
    // …
    "resguy": {
        // …
        "executablePath": "C:/Users/l/Documents/resguy_v9_windows_x64/resguy.exe",
        "ignoreFilePath": "C:/Users/l/Documents/resguy_v9_windows_x64/resguy_default_content.txt"
    },

MESS allows LMP to export your RMF directly into a MAP file and Resguy allows LMP to copy all the custom assets the map uses into a new build folder.

## -clean

By specifying the ``-clean`` parameter to LMP, you force LMP to use a brand new folder for this run.: ``path\to\lmp.ps1 mymap.rmf -clean``.

> This makes sure no files from any previous run is kept, leading to a lower build folder size. It is recommended for final releases.

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

### Updating assets before build

You can configure LMP to update your Wad before build as well as to update your sprites. See [WadMaker and SpriteMaker](https://github.com/pwitvoet/wadmaker) for their respective documentation.

    "spriteMaker": {
        // …
        "isEnabled": true,
        "executablePath": "C:/Users/l/Documents/crossedpaths/WadMaker_SpriteMaker_1.2/SpriteMaker.exe",
        "imagesFolderPath": "C:/Users/l/Documents/images/sprites"
    },
    "wadMaker": {
        // …
        "isEnabled": true,
        "executablePath": "C:/Users/l/Documents/crossedpaths/WadMaker_SpriteMaker_1.2/WadMaker.exe",
        "imagesFolderPath": "C:/Users/l/Documents/images/textures",
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
        "templatesFolderPath": "C:/Users/l/Documents/rmf/templates", // if you use MESS external templates
        "transformMapFiles": true
    },

## List of features

The following features can all be used at the same time, or activated separately. It depends on the configuration files passed to LMP.

 - Compile the map.
 - Copy all the assets the map uses into a separate build folder, ignoring assets shipped with the game.
 - Copy the map and its assets into the game folder.
 - Export the map from .rmf to .map using MESS, or use existing .map file.
 - Run MESS, allowing the use of MESS templates inside the map.
 - Automatically update the Wads using WadMaker before compilation.
 - Automatically update the sprites using SpriteMaker before compilation.

## Performance

Running compilation from a script is more efficient than running it from the map editor. Besides, LMP supports build time optimization using Resguy (ignore assets shipped wit the game), as well as the CSG ``-onlyents`` parameter. It also let WadMaker not do a full rebuild if the Wad wasn’t changed.

## Todo

 - Add option to automatically compile models before compilation.
 - Add GUI.

