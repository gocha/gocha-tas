Generic EmuLua Libraries
========================

Lua libraries mainly for [BizHawk](https://code.google.com/p/bizhawk/).

List of scripts
---------------

More descriptions might be found in each source codes.

### Tools

- bizhawk-multitrack.lua: Provides a function to handle multiplayers' input one by one.

### Modules

The following scripts does not work as a standalone tool.

- pretty-tostring.lua: Overrides `tostring` and provides pretty print for table.
- bizhawk-pretty-print.lua: Adapts `pretty-tostring` to console output functions.
- bizhawk-pckeystate.lua: Provides a class to fetch keyboard inputs and a hotkey function.

Multitrack recording
--------------------

BizHawk has a built-in multitrack recording function, but it does not work sometimes. So I created my own version.

It can capture recent input (in defined length in the source code) when you hit the hotkey. You can reuse the remembered input and start recording for new player's input. Follow these steps:

1. Load bizhawk-multitrack.lua and (re)start a movie recording
2. Create a savestate at where you want to start rerecording
3. Do 1-player's input, then press "Capture Input" hotkey (Ctrl+Shift+At by default)
4. Load the savestate and press "Toggle Track Input #1" hotkey (Ctrl+Shift+1 by default)
5. Do 2-player's input, 1-player's input should be reproduced by script
6. If you have more players, recapture the result and do the next player as well
7. Turn all track inputs off when you have finished all inputs
