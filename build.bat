@echo off

set AppName=Editor
set Code=%cd%

set Opts=-show-timings -collection:shared=%code%\code -build-mode:exe -debug -warnings-as-errors -verbose-errors

if not exist build mkdir build
pushd build
odin build %code%\code -out:%AppName%.exe %Opts%
popd

popd
