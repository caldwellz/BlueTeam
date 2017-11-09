@echo off
tasm32 -ml -m5 -q wkillcx
tlink32 -Tpe -ap -x -c  wkillcx,wkillcx.exe,,import32,,
del wkillcx.obj
