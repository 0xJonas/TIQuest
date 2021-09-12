# TIQuest (working title)

A game for the TI-83+/TI-84+ calculators.

## Building the project

The following tools are **required** to build and run the project:
* **GNU Make** to run the build script.
* [**Spasm-ng**](https://github.com/alberthdev/spasm-ng/releases) to assemble the program code.
* **Python 3** to run auxiliary scripts during the build.
* [**pillow library**](https://pillow.readthedocs.io/en/stable/index.html), used by some of the scripts that process graphical assets.
* [**MirageOS**](https://www.detachedsolutions.com/mirageos/) to run the project on the calculator/emulator.

The following tools are **optional**:
* [**GraphicsGale**](https://graphicsgale.com/us/) for editing the graphics.
* [**Wabbitemu**](http://wabbitemu.org/) to run the binary on your PC.

If you have installed the required tools, simply run `make` from the project's root directory. This creates the compiled binary file `TIQuest.8xp`.

## Installing on your calculator

1. Download and install [TI Connect](https://education.ti.com/en/products/computer-software/ti-connect-sw)
2. Download [MirageOS](https://www.detachedsolutions.com/mirageos/), if you do not have it installed on your calculator.
3. Connect your calculator to your PC via USB.
4. Open the TI Connect software and click on `Send To TI Device`.
5. In the new window, click the `Select Device`-Button at the top. Once your calculator has been detected, click `Select`.
6. Click the `browse` button at the top and select the binary file (`TIQuest.8xp`). If you do not have MirageOS installed, select that as well.
7. Click `Send to device` and wait for the transfer to complete.
8. On your calculator press the `APPS` button and start MirageOS. In MirageOS, navigate to and start TIQUEST by using the `2ND` and arrow keys.
