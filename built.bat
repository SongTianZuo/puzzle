copy src\puzzle.bmp bin\
mkdir bin\sound
copy src\sound\bg.mid bin\sound\
copy src\sound\move.wav bin\sound\
copy src\sound\win.wav bin\sound\
fpc -FEbin src\puzzle.pas
copy src\puzzle.bmp bin\
del bin\puzzle.o
del bin\libimppuzzle.a