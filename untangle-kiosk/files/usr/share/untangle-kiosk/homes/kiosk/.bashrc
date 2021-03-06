XORG_CONF_SAFE=xorg-untangle-safe.conf

print_warning() {
    for i in $(seq 50) ; do echo ; done
    cat <<EOF
The server has failed to properly detect correct video and monitor settings.

There are several things to try:
1) Restarting the server and select a different video-mode boot option from the boot menu.
2) Use a different monitor (restart the server after switching monitors).
3) Use a different video card (if applicable).
4) Change the BIOS video card settings (if applicable).

EOF
    for i in $(seq 10) ; do echo ; done
}

if [ `tty` = "/dev/tty1" ] ; then
    for i in $(seq 3) ; do

        # kill any running X processes
        ps aux | awk '/^(xinit|X|startx)/ { print $2 }' | xargs kill -9 2> /dev/null

        #
        # Special handling for some video cards
        # This is used if we know our appliances (u50) don't support the default
        # We can force video-safe-mode
        #
        # n10=$(lspci | grep "Intel Corporation N10 Family Integrated Graphics Controller (rev 02)")
        # if [ -z "$n10" ] ; then
        #    export XORGCONFIG=$XORG_CONF_SAFE
        # fi

        #
        # Use video-safe-mode xorg config only if we were passed "force-video-safe" via grub
        # 
        forceVideoSafe=$(grep force-video-safe /proc/cmdline)
        if [ -n "$forceVideoSafe" ] ; then
            export XORGCONFIG=$XORG_CONF_SAFE
        fi

        # Start X
        startx -- vt7
        # If X returns, something has gone wrong

        # Print this warning to console to let the user know X is failing
        print_warning
        sleep 5

        # If we have failed for 2 attempts already, try safe mode on the next try
        if [ $i -gt 2 ] ; then
            export XORGCONFIG=$XORG_CONF_SAFE
        fi

    done
fi


# 
# Sleep forever so that they do not automatically get a shell prompt
# You can easily ctrl-C this to get the bash shell
#
while true; do
    print_warning
    sleep 60
done
