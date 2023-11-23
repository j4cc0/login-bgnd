#!/bin/bash

SCRIPT="$(basename $0 | sed 's/\..*$//')"
USEBGND="${1}"
IMGDIR="/root/images"
GREETERCONF="/etc/lightdm/lightdm-gtk-greeter.conf"
SIZE=$(xrandr 2>/dev/null | grep '[0-9]x[0-9]* ' | head -n 1 | awk '{print $1}')
#SIZE="3840x2160"
#SIZE="3840"
TMPFILE=$(mktemp)
NEOFETCHPNG="${IMGDIR}/neofetch.png"
NEOFETCH="${IMGDIR}/neofetch-transparent.png"
NEOFETCHSIZED="${IMGDIR}/neofetch-transparent-sized.png"
PATTERN="${IMGDIR}/bgnd-2b-bb.png"
BGND="${IMGDIR}/background.png"
BGNDLOGIN="/usr/share/wallpapers/login-background.png"
NEOFETCHCONF="/etc/neofetch/config.conf"
MYLOCK="/run/login-bgnd.pid"

if [ -f "$MYLOCK" ]; then
        exit 1
fi
touch "$MYLOCK"

logger -t "$SCRIPT" "====<[ Running $SCRIPT ]>===="

if [ "x${SIZE}x" = "xx" ]; then
        SIZE="1440x900"
fi
logger -t "$SCRIPT" "[+] Now using $SIZE"

if [ ! -d "$IMGDIR" ]; then
        logger -t "$SCRIPT" "[-] $IMGDIR is not a directory or does not exist. Aborted" >&2
        exit 1
fi

if [ ! -r "$USEBGND" ]; then
        if [ ! -r "$PATTERN" ]; then
                logger -t "$SCRIPT" "[-] Missing $PATTERN or not readable. Aborted" >&2
                exit 1
        fi
fi

# Wait for IP networking to come online
while [ "x$(ip -4 -o route 2>/dev/null | xargs echo)x" = "xx" ]
do
        logger -t "$SCRIPT" "[-] Waiting for IP routing"
        sleep 5
done

# Wait for DNS nameresolving to work
while [ "x$(host ip.me 2>/dev/null | xargs echo)x" = "xx" ]
do
        logger -t "$SCRIPT" "[-] Waiting for DNS lookups to work"
        sleep 5
done

# Write system info
neofetch --config "$NEOFETCHCONF" --ip_host "https://ip.me/" --ip_timeout 30 > "$TMPFILE" 2>/dev/null
if [ ! -s "$TMPFILE" ]; then
        logger -t "$SCRIPT" "[-] neofetch has no useful result. Aborted"
        exit 1
fi

if [ -f "$NEOFETCHPNG" ]; then
        mv "$NEOFETCHPNG" "${NEOFETCHPNG}.PREV"
fi

# Create png from system info
ansilove -q -c 142 -o "$NEOFETCHPNG" "$TMPFILE" 2>/dev/null
rm -f "$TMPFILE"
if [ ! -s "$NEOFETCHPNG" ]; then
        logger -t "$SCRIPT" "[-] Converting neofetch to $NEOFETCHPNG has no useful result. Aborted"
        exit 1
fi

if [ -f "${NEOFETCHPNG}.PREV" ]; then
        OLDHASH=$(b2sum "${NEOFETCHPNG}.PREV" | awk '{print $1}')
        NEWHASH=$(b2sum "$NEOFETCHPNG" | awk '{print $1}')
        if [ "x${OLDHASH}x" = "x${NEWHASH}x" ]; then
                logger -t "$SCRIPT" "[!] neofetch information didn't change. No need to update. Exiting"
                exit 0
        fi
        rm -f "${NEOFETCHPNG}.PREV" &>/dev/null
fi
logger -t "$SCRIPT" "[+] Proceeding to create $BGNDLOGIN"

# Give png transparent background
convert "$NEOFETCHPNG" -transparent black "$NEOFETCH"
if [ ! -s "$NEOFETCH" ]; then
        logger -t "$SCRIPT" "[-] Adding transparency to $NEOFETCH has no useful result. Aborted"
        exit 1
fi

# Create login background of proper size
if [ ! -f "$BGND" ]; then
        if [ -r "$USEBGND" ]; then
                logger -t "$SCRIPT" "[+] Using $USEBGND for background"
                convert "$USEBGND" -resize "$SIZE" "$BGND"
        else
                logger -t "$SCRIPT" "[+] Using $PATTERN for background"
                convert -size "$SIZE" xc: -tile "$PATTERN" -draw "color 0,0 reset" "$BGND"
        fi
else
        logger -t "$SCRIPT" "[i] $BGND already exists"
fi

# Stretch png to login background size
if [ ! -s "$BGND" ]; then
        logger -t "$SCRIPT" "[-] Background $BGND has no useful result. Aborted"
        exit 1
fi
SIZEX1=$(file -L "$BGND" | sed 's/^.* \([0-9]*\) x [0-9]*, .*$/\1/')
SIZEX=$((SIZEX1 / 3 * 2))
convert "$NEOFETCH" -resize "${SIZEX}x" "$NEOFETCHSIZED"
if [ ! -s "$NEOFETCHSIZED" ]; then
        logger -t "$SCRIPT" "[-] Resized neofetch $NEOFETCHSIZED has no useful result. Aborted"
        exit 1
fi

# Combine login background with transparent system info
convert -composite -gravity southeast "$BGND" "$NEOFETCHSIZED" "$BGNDLOGIN"
if [ ! -s "$BGNDLOGIN" ]; then
        logger -t "$SCRIPT" "[-] Creating background $BGNDLOGIN has no useful result. Aborted"
        exit 1
fi

# Remove obsolete generated files
rm -f "$NEOFETCH" "$NEOFETCHSIZED"

# Replace background image reference in greeter config
#logger -t "$SCRIPT" sed -i "s@^background = .*\$@background = ${BGNDLOGIN}@"
sed -i "s@^background = .*\$@background = ${BGNDLOGIN}@" "$GREETERCONF" || \
        { logger -t "$SCRIPT" "[-] Unable to set background in $GREETERCONF. Aborted"; exit 1; }


rm -f "$MYLOCK"

logger -t "$SCRIPT" "====<[ Exit $SCRIPT ]>===="

exit 0
