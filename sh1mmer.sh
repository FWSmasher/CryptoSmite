if [ -f "/usr/sbin/sh1mmer_main.sh" ];
then
    /bin/bash /usr/sbin/sh1mmer_main.sh
else
    echo "This is for non-legacy shims only"
    exit 0
fi