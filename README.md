# Tipsy

A simple (experimental) productivity tool written in [v](https://vlang.io/).

How tipsy work:
1. Extracts information from active X11 window(s)
2. Try to generate a meaningful context set
3. Write the context to disk for clients to build meaningful context output from

Currently tipsy only work on X11/Linux hosts.

## Features
* An easy way to show your own notes in context based on your active application(s)
* Multiple running context extractors and clients supported

## Dependencies
`xdotool`, `sed`

## Install

Make sure you have [v installed](https://github.com/vlang/v#installing-v-from-source).

Building the context extractor (`tipsy`)
```
git clone git@github.com:larpon/tipsy.git
cd tipsy
v -o bin/tipsy tipsy.v
```

Building the sample context data viewer (`syncs`)
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

Run extractor
```
bin/tipsy --tips ~/tips
```

Run sample client
```
bin/syncs --tips ~/tips
```
