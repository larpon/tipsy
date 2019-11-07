# Tipsy

A simple (experimental) productivity tool written in [v](https://vlang.io/).

How tipsy works:
1. Extract information (title, pid, window id etc.) from active X11 window
2. Generate a meaningful context keyword set
3. Write the context keywords to disk for clients to build meaningful output from

Currently tipsy only work on X11/Linux hosts.

## Features
* An easy way to show your own notes in context based on your active application(s)
* Multiple running context extractors and clients supported

## Dependencies
`xdotool`, `sed`

## Install

Make sure you have [v installed](https://github.com/vlang/v#installing-v-from-source).

Building `tipsy` (context extractor)
```
git clone git@github.com:larpon/tipsy.git
cd tipsy
v -o bin/tipsy tipsy.v
```

Building `syncs` (sample context data viewer)
```
v -o bin/syncs clients/syncs.v
```

## Usage

Right now tipsy need a directory with a file for each process name you want to provide a context for:
```
mkdir ~/tips
echo "This is tipsy's context" > ~/tips/tipsy
echo "Konsole tips'n'tricks" > ~/tips/konsole
echo "Stuff for nvim" > ~/tips/nvim
```

Some processes run sub-processes in them (like a terminal or AppImage etc.).
To try and extract context from sub-processes you currently need to specify which sub-processes tipsy should try and match context for:
```
echo "konsole" > ~/tips/parents.tipsy
```

Run tipsy (extractor)
```
bin/tipsy --tips ~/tips
```

Run syncs (sample client)
```
bin/syncs --tips ~/tips
```
