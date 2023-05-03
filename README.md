# LMP

LMP is a utility that aims to streamline the process of packaging a map and its assets. It can easily be configured to meet varied needs.

From any directory, you can run ``.\lmp.ps1 mymap fullbuild.json``

``fullbuild.json`` is the path to your main configuration file. You can specify more if you want to, for instance you could have: ``.\lmp.ps1 mymap fullbuild.json onlyents.json``, with the ``onlyents.json`` file overriding just one parameter (namely ``compileCsgParams``).

> :warning: You need PowerShell 7 to run the script (``winget install --id Microsoft.Powershell --source winget``). You also need to allow the execution of custom scripts using ``Set-ExecutionPolicy unrestricted``.

## Features:

The following features can all be used at the same time, or activated separately. It depends on the configuration files passed to LMP.

 - Compile the map and copy all the assets it uses into a separate build folder, ignoring assets shipped with the game.
 - Copy the map and its assets into the game folder.
 - Export the map from RMF to MAP using MESS.
 - Compile the map.
 - Run MESS, allowing the use of MESS templates inside the map.
 - Automatically update the WADs using WadMaker before compilation.
 - Automatically update the sprites using SpriteMaker before compilation.

## Configuration file

Configuration files are JSON files. The order in which you specify the configuration files to LMP matters, the latter will override the former.

When a parameter is optional, you can specify ``null`` as the value (without apostrophes).

Look up the ``fullbuild.json`` and ``nocompile.json`` for examples.

A complete configuration file looks like this:

    {
        "mess": "Optional. The path to the MESS executable.",
        "messParams": "Optional, if mess is specified.",
        "messTemplatesFld": "Path to the MESS templates. Optional, if mess is specified.",
        "buildCopyFld": "Optional, if you want LMP to copy the map and its assets into your game folder.",
        "resguy": "Optional. Path to Resguy to generate RES file. Necessary if you want LMP to copy all the assets used by the map into the build folder.",
        "resguyIgnore": "Optional, but mandatory if resguy is specified. List of all the default content already shipped with the game, and excluded from the res file.",
        "sprMaker": "Optional, if you want to generate sprites from images before compilation.",
        "sprMakerFldToBuild": "Mandatory if sprMaker is specified. The path to the folder containing the images from which SpriteMaker will generate the sprites.",
        "wadMaker": "Optional. Path to WadMaker. Generate a Wad file from images before compilation.",
        "wadMakerTexturesFld": "Mandatory if wadMaker is specified. The path to the folder containing the images from which WadMaker will generate the Wad file.",
        "wadMakerWadName": "Mandatory if wadMaker is specified. Name of the Wad to build.",
        "assetFld": "Mandatory. Path to the folder containing all the assets. Assets in this folder must be organized in the traditional way: \"sprites\", \"models\", \"sound\", \"scripts\" as well as WAD in the main folder",
        "compile": "Mandatory, whether to compile the map (true or false).",
        "compileBsp": "If compile is set to true. Path to the BSP executable.",
        "compileBspParams": "If compile is set to true.",
        "compileCsg": "If compile is set to true. Path to the CSG executable.",
        "compileCsgParams": "If compile is set to true.",
        "compileRad": "If compile is set to true. Path to the RAD executable.",
        "compileRadFileFld": "If compile is set to true. Path to the .RAD file.",
        "compileRadParams": "If compile is set to true.",
        "compileVis": "If compile is set to true. Path to the VIS executable.",
        "compileVisParams": "If compile is set to true.",
        "map": "Mandatory. Whether to export the RMF file to the MAP format.",
        "mapExporter": "Mandatory if \"map\" is set to true. Can eitheir be \"mess\" or be null. If null, it will use the existing map file.",
        "mapRmfFld": "Mandatory if \"map\" is set to true. The folder in which the RMF file is.",
        "prod": "Whether to compile in prod mode. If set to true, it will disable any entity named \"mm_devmapstart/".",
        "wads": [
            "Mandatory. List of WAD files the map uses."
        ]
    }