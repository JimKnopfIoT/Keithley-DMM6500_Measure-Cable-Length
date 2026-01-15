# Keithley-DMM6500_Measure-Cable-Length
Script for Keithley DMM6500 / DMM7510 to measure cable length.

## The Process
I was curious to see if I could measure the length of a cable relatively accurately with my Keithley DMM6500. I usually use a LiteVNA for this. It uses the Time Domain Reflectometry (TDR) method. I can't program myself, but I recently discovered Claude Code and Vibe Coding. I asked Claude if it could write me a script for the device with TDR functionality. After checking the documentation, Claude concluded that the DMM6500 is more than 1000 times too slow for this due to the relay switching when changing functions.

However, Claude suggested instead determining the length relatively accurately by measuring the capacity and resistance of known cable types. 
Unfortunately, Claude was unable to capture screenshots from the DMM6500 using SCPI commands during the iterative process. I have already let Claude use such SCPI commands on other devices for which he wrote scripts for me, for example for the EEZ-BB3 power supply. But Claude found a way to cut out a canvas section of the display from the DMM6500's web interface in order to evaluate this information. This allowed Claude to see for himself what was not yet working and what errors were currently present. I have also stored the script here.

## How it works
The script can be started from the USB drive. Cables with at least two wires or coaxial cables can be measured. Connect the cable to the Hi/Lo sockets.  After startup, it asks for the cable type and size. The size is specified in AWG, followed by the cross-sectional area and then the equivalent cross-sectional area that we (localy) commonly use. My DUT was a 4 mm² speaker cable. It is exactly 9.28 m long. The value measured with the script is surprisingly accurate. I have not yet tested other cables.

Once you have specified the cable type and size, the script checks whether the cables far-end is open. If not, a message appears telling you to open it. The script then measures the capacity. You are then prompted to short the far-end to measure Resistance. You can skip this if you don't want to measure the Resistance. It uses the stored values to calculate the approximate length of the cable. 

Keep in mind, on DMM6500 and DMM7510 after exiting a script, it is in IDLE Mode (look at the top right corner). You have to set it to Continous Mode by hand. 

## Images
<p align="center">
<img src="Bildschirmfoto vom 2026-01-14 20-36-50.jpg" width="220"> 
<img src="Bildschirmfoto vom 2026-01-14 20-37-06.jpg" width="220">
<img src="Bildschirmfoto vom 2026-01-14 20-37-25.jpg" width="220">
</p>  
<p align="center">
<img src="Bildschirmfoto vom 2026-01-14 20-38-54.jpg" width="220">
<img src="Bildschirmfoto vom 2026-01-14 20-37-38.jpg" width="220"> 
<img src="Bildschirmfoto vom 2026-01-14 20-37-53.jpg" width="220">

</p>  
<p align="center">
<img src="Bildschirmfoto vom 2026-01-14 20-38-25.jpg" width="220">
<img src="Bildschirmfoto vom 2026-01-14 20-39-30.jpg" width="220">
<img src="Bildschirmfoto vom 2026-01-14 20-39-50.jpg" width="220">
</p>  
<p align="center">
<img src="Bildschirmfoto vom 2026-01-14 20-40-05.jpg" width="220">
</p>  

