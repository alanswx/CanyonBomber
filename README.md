# CanyonBomber
FPGA implementation by james10952001 of Canyon Bomber arcade game released by Kee Games in 1978
Port to MiSTer by Alan Steremberg

# Keyboard inputs :
```
   F1          : Coin + Start 1P
   F2          : Coin + Start 2P
   ctrl, space : Fire

   MAME/IPAC/JPAC Style Keyboard inputs:
     5           : Coin 1
     6           : Coin 2
     1           : Start 1 Player
     2           : Start 2 Players
     A           : Player 2 Fire


 Joystick support. (Converts the digital joystick to a simulated quadrature encoding)
```


Initial release:
-- There is still some cleanup of the code that can be done and a minor bug where occasionally there is a small glitch in the motion object as a ship hits the edge of the screen. I am not abslutely certain at this time that this is specific to the FPGA version and not a bug in the original hardware or code. 

# ROMs
```
                                *** Attention ***

ROM is not included. In order to use this arcade, you need to provide a correct ROM file.

Find this zip file somewhere. You need to find the file exactly as required.
Do not rename other zip files even if they also represent the same game - they are not compatible!
The name of zip is taken from M.A.M.E. project, so you can get more info about
hashes and contained files there.

To generate the ROM using Windows:
1) Copy the zip into "releases" directory
2) Execute bat file - it will show the name of zip file containing required files.
3) Put required zip into the same directory and execute the bat again.
4) If everything will go without errors or warnings, then you will get the a.*.rom file.
5) Copy generated a.*.rom into root of SD card along with the Arcade-*.rbf file

To generate the ROM using Linux/MacOS:
1) Copy the zip into "releases" directory
2) Execute build_rom.sh
3) Copy generated a.*.rom into root of SD card along with the Arcade-*.rbf file

To generate the ROM using MiSTer:
1) scp "releases" directory along with the zip file onto MiSTer:/media/fat/
2) Using OSD execute build_rom.sh
3) Copy generated a.*.rom into root of SD card along with the Arcade-*.rbf file
```

