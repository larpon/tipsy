# Tipsy

A simple (experimental) productivity tool written in [V](https://vlang.io/).

(Currently tipsy only work on X11/Linux hosts).

## Why

Have you tried working in several different applications each day?

Going to and from many different applications each day make you forget each application's
hotkeys and special features really quick. You get lost and forget what you where
doing while searching online for an answer.

* How do I playback an animation in `blender`?
* How do I switch buffers in `vim`?
* The hotkeys for deattaching a `screen` session?

When you switch to a new new application you have to switch context mentally as well.
It can thus become a little tedious to remember how you usually do `X` thing in `Y` application.

It would be nice if you could just have your personal notes changing along when you move your workflow to the next application, right?

This is exactly the problem tipsy try to solve.

How tipsy works:
1. Extract information (window title, pid, window id etc.) from active X11 window.
2. Generate a meaningful context keyword set (application name, working directory, etc.).
3. Write the context keywords to disk for clients to build meaningful output from.

## Features
* Dead simple
* Easy way to show your own notes in context based on your active application (context).
* Multiple running context extractors and clients supported.

## Dependencies
`xdotool`, `sed`

## Install

Make sure you have [v installed](https://github.com/vlang/v#installing-v-from-source).

Building `tipsy` (context extractor).
```
git clone git@github.com:larpon/tipsy.git
cd tipsy
v -o bin/tipsy tipsy.v
```

Building `syncs` (sample context data viewer).
```
v -o bin/syncs clients/syncs.v
```
`syncs` is a sample client that will show your tips in a terminal window.

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

Run tipsy (extractor).
```
bin/tipsy --tips ~/tips
```

Run syncs (sample client).
```
bin/syncs --tips ~/tips
```
