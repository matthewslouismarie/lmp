# LMP

LMP is a utility that aims to streamline the process of packaging a map and its assets. It can easily be configured to meet varied needs.

From any directory, you can run ``path\to\lmp.ps1 mymap {myconfig.json}``

Replace ``{myconfig.json}`` by the path to your main configuration file. You can specify more if you want to, for instance you could have: ``.\lmp.ps1 mymap fullbuild.json onlyents.json``, with the ``onlyents.json`` file overriding just one parameter (namely ``compileCsgParams``).

> :warning: You need PowerShell 7 to run the script (``winget install --id Microsoft.Powershell --source winget``). You also need to allow the execution of custom scripts using ``Set-ExecutionPolicy unrestricted``.

## Features:

The following features can all be used at the same time, or activated separately. It depends on the configuration files passed to LMP.

 - Compile the map.
 - Copy all the assets the map uses into a separate build folder, ignoring assets shipped with the game.
 - Copy the map and its assets into the game folder.
 - Export the map from .rmf to .map using MESS, or use existing .map file.
 - Run MESS, allowing the use of MESS templates inside the map.
 - Automatically update the Wads using WadMaker before compilation.
 - Automatically update the sprites using SpriteMaker before compilation.

## Configuration file

Configuration files are JSON files. The order in which you specify the configuration files to LMP matters, the latter individual values will override the former’s.

When a parameter is optional, you can specify ``null`` as the value (without apostrophes).

Look up the ``fullbuild.json`` and ``nocompile.json`` for examples.

A complete configuration file looks like this:

``mess``: Optional. The path to the [MESS](https://github.com/pwitvoet/mess) executable.
``messParams``: Only if ``mess`` is specified. Parameters for MESS if ``mess``.
``messTemplatesFld``: Only if ``mess`` is specified. Path to the MESS templates.
``buildCopyFld``: Optional. Specify the game folder (e.g. the path to svencoop_addon) if you want LMP to copy the map and its assets into your game folder.
``resguy``: Optional. Path to [Resguy executable (download link)](https://github.com/wootguy/resguy/releases) to generate RES file. Necessary if you want LMP to copy all the assets used by the map into the build folder.
``resguyIgnore``: Only if ``resguy`` is specified. List of all the default content already shipped with the game, and excluded from the res file. Resguy can generate this file for you, see ``resguy.exe -h``.
``sprMaker``: Optional. Path to the [SpriteMaker executable (download link)](https://github.com/pwitvoet/wadmaker/releases). If you want to generate sprites from images before compilation.
``sprMakerFldToBuild``: Only if ``sprMaker`` is specified. The path to the folder containing the images from which SpriteMaker will generate the sprites.
``wadMaker``: Optional. Path to the [WadMaker executable (download link)](https://github.com/pwitvoet/wadmaker/releases). Generate a Wad file from images before compilation.
``wadMakerTexturesFld``: Only if ``wadMaker`` is specified. The path to the folder containing the images from which WadMaker will generate the Wad file.
``wadMakerWadName``: Only if ``wadMaker`` is specified. Name of the Wad to build.
``assetFld``: **Mandatory.** Path to the folder containing all the assets. Assets in this folder must be organized in the traditional way: "sprites", "models", "sound", "scripts" as well as Wads in the root folder.
``compile``: **Mandatory.** Whether to compile the map (``true`` or ``false``).
``compileBsp``: Only if ``compile`` is set to ``true``. Path to the BSP executable.
``compileBspParams``: Only if ``compile`` is set to ``true``.
``compileCsg``: Only if ``compile`` is set to ``true``. Path to the CSG executable.
``compileCsgParams``: Only if ``compile`` is set to ``true``.
``compileRad``: Only if ``compile`` is set to ``true``. Path to the RAD executable.
``compileRadFileFld``: Only if ``compile`` is set to ``true``. Path to the .rad file.
``compileRadParams``: Only if ``compile`` is set to ``true``.
``compileVis``: Only if ``compile`` is set to ``true``. Path to the VIS executable.
``compileVisParams``: Only if ``compile`` is set to ``true``.
``map``: **Mandatory.** Whether to export the .rmf file to the .map format.
``mapExporter``: Only if ``map`` is set to ``true``. Can either be ``"mess"`` or be ``null``. If ``null``, it will use the existing .map file. (Make sure it exists!)
``mapRmfFld``: Only if ``map`` is set to ``true``. The folder in which the .rmf file is.
``prod``: **Mandatory.** Whether to compile in prod mode. If set to true, it will disable any entity named ``"mm_devmapstart``.
``wads``: **Mandatory.** List of the filenames of all the Wads the map uses.

## Performance

Running compilation from a script is more efficient than running it from the map editor. Besides, LMP supports build time optimization using Resguy (ignore assets shipped wit the game), as well as the CSG ``-onlyents`` parameter. It also let WadMaker not do a full rebuild if the Wad wasn’t changed.

## Todo

 - Add option to automatically compile models before compilation.
 - Add GUI.