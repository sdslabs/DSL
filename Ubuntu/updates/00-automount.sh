#!/bin/bash

#  00-automount.sh
#  Ubuntu
#
#  Created by Kanav Gupta on 16/01/21.
#  

echo """\
[Unit]
Description=Automount disks according to disk labels

[Service]
ExecStart=/opt/sdslabs/automount.sh

[Install]
WantedBy=multi-user.target
""" > /etc/systemd/system/automount.service

mkdir -p /opt/sdslabs

echo """\
#!/bin/bash

for disk in /dev/disk/by-label/*; do
    label=\"\$(basename \$disk)\"
    mkdir -p \"/mnt/\$label\"
    mount \"\$disk\" \"/mnt/\$label\"
    chown default \"/mnt/\$label\"
    chgrp default \"/mnt/\$label\"
done
""" > /opt/sdslabs/automount.sh

chmod +x /opt/sdslabs/automount.sh
systemctl enable automount.service
