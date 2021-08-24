# CE C Programming Toolchain/SDK (Files for BOS)
The CE C Software Development Kit incorporates a wide variety of tools and documentation in order to build programs in C natively for the TI-84 Plus CE / TI-83 Premium CE calculators series.

## Important Note
This extension requires the standard CE C toolchain to be installed.

## Installation
Copy the `bos` folder into your CEdev directory, or run `make` from the repo's root directory.

## Getting Started
See `makefile.bos` for makefile template.
The [header documentation](https://ce-programming.github.io/toolchain/files.html) will let you know about the available libload functions.

## Sending binaries
There's a few ways to send binaries to BOS.
To add the file to the ROM for use with CEmu: `python add_file_to_rom.py /path/on/computer /path/on/rom`
or use BOS Package manager to install from a local file for use on hardware. (NOT YET IMPLEMENTED)

## Help
Feel free to contact me on [Cemetech](https://www.cemetech.net/forum/profile.php?mode=viewprofile&u=18775)
