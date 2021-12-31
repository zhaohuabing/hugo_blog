---
layout:     post
title:      "Docker Tips"
subtitle:   ""
description: ""
excerpt: ""
date:       2018-02-09 10:00:00
author:     "赵化冰"
image:     "/img/docker.jpg"
published: true
showtoc: false 
tags:
    - Docker
categories: [ Tech ]
---

# Allow none-root users

```bash
sudo groupadd docker
sudo gpasswd -a $USER docker
newgrp docker
```

# Solve "no space left on device"

## ubuntu

```bash
sudo vi /etc/docker/daemon.json
```

```josn
{
        "storage-driver": "devicemapper",
        "storage-opts": [
                "dm.basesize=40G"
        ]
}
```

## Mac

Docker -> settings -> Resources -> Disk Image Size