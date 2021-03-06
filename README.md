# Packman

![](resources/images/logo.png)

Much like the classic arcade game of a similar name, this game brings a fun
way to help maintain pace and increase distance. The object of the game is
to collect as many dots as possible before being eaten by a ghost or before
quitting the activity. If your current speed slows down too much for longer
than 5 seconds, the ghost will take a life. You have a total of 3 lives before
losing the game.

![](resources/images/main.png)
![](resources/images/game_play_with_ghost.png)
![](resources/images/game_over.png)

## Future features

* surprise ghosts
  * when enabled, a ghost will randomly appear in front of you and you must
    turn around and run in the opposite direction to escape the ghost.
* bonus mode
  * after collecting X dots, you will have the ability to enter "bonus mode"
    which gives you the opportunity to chase the ghosts. If you maintain
    a faster speed for X number of seconds then you will have "caught" the
    ghost and will be awarded X number of bonus dots.
* Chasing ghost increases speed
  * when enabled, the chasing ghost will randomly increase its speed 
    causing you to increase your speed in order to avoid being caught
    for X number of seconds.

## Development

Download and install the Garmin Connect IQ SDK if you haven't already. Edit 
the `CONNECT_IQ_SDK_DIR` in `build.py` to point to the SDK's installation
directory. Start up the simulator. Then, run `build.py -d <device name>`.
For example, for the Forerunner 920xt
```
$ build.py -d fr920xt
```

This will build the binaries and place them in the `bin/` directory then
push them to the simulator where you should see the main game screen.

Run `build.py -h` for help and other available options.


## Changelog

* v0.2 - Tested on some hardware
  * Add checks for the Attention tones and vibrations
  * Hardware devices do not currently support ActivityRecording so
    the session recording has been commented out.
  * There is a bug with setting a variable to one of the Attention
    tone enums, so the enums are used directly.

* v0.1 - Initial Release
  * Basic app setup. Simple game logic.