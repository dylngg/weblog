Earlier today I was doing some dirty scripting with `rsync` and `ssh` where I was attempting to launch an interactive command on a remote machine over SSH, while syncing the temporary files created from that command down to my Macbook. The script looked a little like this:

```
#!/bin/bash
target="$1"
remotecmd="..."
sync() {
    while true; do
        rsync -a "$target:/tmp/.remotecmd/" `pwd`
        sleep 3
    done
}

echo "Spawning off syncing agent..."
sync &

echo "Launching $remotecmd..."
ssh -t "$target" "cd /tmp/.remotecmd && $remotecmd"
```

It's not the prettiest, but you get the gist of it. It worked for my purposes and I continued on my merry way.

Which brings me to a not too long ago when I was closing out my Terminal sessions for the day and decided I wanted to clean up some of those pesky files that were synced down. A simple `rm` of the files will do I thought, so I did this:

```
$ ls
tmpfile1
tmpfile2
tmpfile3
$ rm tmpfile1 tmpfile2 tmpfile3
```

Then I ran `ls` again to make sure I got everything:

```
$ ls
tmpfile1
tmpfile2
tmpfile3
```

Huh? My first instinct without thinking much was just to try harder, so I did that by blindly running `rm -f`, thinking automatically that of course that'll fix it.

```
$ rm -f tmpfile1 tmpfile2 tmpfile3
$ ls
tmpfile1
tmpfile2
tmpfile3
```

Nope. I then thought about why that might be for a second and realized that I probably accidentally left `rsync` running in the background when I `ctl-c`'d my dirty script. Naturally knowing a thing or two about UNIX commands, my quick solution was to use `pkill -9` to clean up the leftover processes:

```
$ pkill -9 -U $UID rsync
$ rm tmpfile1 tmpfile2 tmpfile3
```

_(The -U flag causes pkill to only kill processes owned by the given UID)_

It didn't work. The strange thing is that the `rsync` daemons are like Hydra heads—literally reappearing after I kill them!

```
$ ps aux | grep rsync
dylngg           18728   0.0  0.0  4298384    620 s006  U+    now      0:00.00 grep rsync
root             18669   0.0  0.0  4287656   2696   ??  Ss    5s ago   0:00.01 /opt/bin/daemondo --label=rsyncd --start-cmd ...
dylngg           18398   0.0  0.0  4298268   2300   ??  S     5s ago   0:00.01 ssh -l pi 10.0.0.3 rsync --server ...
dylngg           18396   0.0  0.0  4291992   1644   ??  S     5s ago   0:00.01 rsync -a pi@10.0.0.3:/tmp/.remotecmd/ ...
```

Perhaps since `pkill` defaults to matching against the process name, rather than all the arguments, I wasn't killing everything? I see a `ssh ... rsync --server` in my `ps` output, so I tried `pkill -f -9 -U $UID rsync` and obviously that also didn't work.

Okay. I'm starting to get paranoid. I know there's a thing called `rsyncd` that does `rsync` stuff as a root daemon, so maybe that's it? On my MacBook that's the `/opt/bin/daemondo` process in the `ps` output because I use [MacPorts](https://www.macports.org). (Hint: I literally have no idea what `rsyncd` does) My solution:

```
$ sudo pkill -9 -f rsync
$ sudo rm -rf tmpfile1 tmpfile2 tmpfile3
```

It's a bit heavy handed since I'll kill any other `rsync` processes, but at this point I'm fine with that. _[sudo](https://xkcd.com/149/) certainly has my back right!?_

```
$ ls
tmpfile1
tmpfile2
tmpfile3
```

Nope.

<br>

At this point I'm almost at a loss, nearly resigned to letting the all mighty `rsync` continue to ensure I have garbage on my disk until I reboot the machine and can clean up the mess I have made. That is, until I remembered an important lesson taught to me by a mentor a year or so back: processes in UNIX are hierarchical, meaning they are spawned off by a parent process and when that parent process dies, the now orphan process is inherited by the root of all processes—`init`. So in my case when my script exits, either `init` keeps respawning `rsync` (unlikely) or I have a parent process respawning `rsync`.

It's at this point that I realize that my script is running a `sync` function in the background without killing it when the main script exits. It dawns on me that perhaps functions in bash can be independent processes when the main process exits. This would mean that on exit the `sync` function will simply get adopted by `init` and continue running. Furthermore with my script, attempting to kill `rsync` will always fail because the parent process—the `sync` bash function—keeps respawning `rsync` every 3 seconds after rsync dies! The neat `pstree` command shows this:

```
$ pstree -s rsync
-+= 00001 root /sbin/launchd
 |-+- 04722 dylngg /bin/bash ./dirty.sh pi@10.0.0.3
 | \-+- 20513 dylngg rsync -a pi@10.0.0.3:/tmp/.remotecmd/ ...
 |   \--- 20516 dylngg ssh -l pi 10.0.0.3 rsync --server ...
 \-+= 20382 root /opt/bin/daemondo --label=rsyncd --start-cmd ...
   \--- 20383 root (bash)
```

_(The -s flag filters down the tree to only include rsync and it's ancestors)_

So the super simple and now plainly obvious solution (while still blindly killing all `rsync` processes) is to do the following:

```
$ pkill -9 -f dirty.sh
$ pkill -9 rsync
```

Which fixed the problem! Yay!

I guess the lesson here is that you should a) reap all your background processes in shell scripts, shells won't do that for you and b) be wary of the fact that functions in bash scripts can be considered their own processes and also won't be reaped by the shell when they run in the background and the shell exits. That lesson was quite informative albeit very annoying.
