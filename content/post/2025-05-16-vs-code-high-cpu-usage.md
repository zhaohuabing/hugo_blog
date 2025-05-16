---
layout:     post

title:      "Fixing High CPU Usage in VS Code"
subtitle:   ""
author:     "Huabing Zhao"
date:       2025-05-16
description: "A small shell script to limit CPU usage of node processes in VS Code remote server."

tags:
    - VSCode
categories:
    - Tech
---

## VS Code Constantly Freezing

I’ve been using VS Code for a long time, and it’s usually rock solid. Recently, though, I started working with the [Rmote-SSH](https://code.visualstudio.com/docs/remote/ssh) extension to connect to a remote Ubuntu server — a more powerful machine I spun up in the cloud to offload dev workloads from my laptop.

But not long after, I noticed VS Code was frequently freezing, lagging, and even dropping SSH connections. The same thing was happening in Cursor and Windsurf, which makes sense since they’re both VS Code forks under the hood.

## Diagnosing the Problem

At first, I assumed the culprit was a flaky network between my laptop and the remote server. But after SSH’ing in and running `top`, I noticed something else entirely: several node processes were spiking CPU.

That makes sense in hindsight. VS Code uses Node.js to run many of its extensions — things like autocompletion, linting, formatting, and debugging. And each of those extensions can spawn one or more node processes.

Here’s a snapshot of what I saw:

```bash
    PID USER      PR  NI    VIRT    RES    SHR S  %CPU  %MEM     TIME+ COMMAND
1769144 ubuntu    20   0   75.4g 434172  60288 R 120.3   0.7     2w+3d node
 325323 ubuntu    20   0   84.4g 805156  16320 R 106.6   1.2     4w+1d node
 558513 ubuntu    20   0   52.7g 875896  56540 R 105.6   1.3    4d+10h node
1216323 ubuntu    20   0   74.4g   1.6g  16512 R 105.6   2.5     2w+2d node
 330045 ubuntu    20   0   84.7g   1.0g  16320 R 104.3   1.7     3w+5d node
2527930 ubuntu    20   0   41.4g 247436  50304 S  10.6   0.4  41:52.21 node
2803800 ubuntu    20   0   41.4g 232376  55104 S   9.6   0.4   5:14.43 node
```

## A Simple Fix: Throttle the Node Processes

To prevent VS Code from freezing, I wrote a small shell script that uses cpulimit to restrict each node process to 50% CPU usage.

Here’s the script:

```bash
CPU_LIMIT=50
CHECK_INTERVAL=10
SEEN_PIDS_FILE="/tmp/cpu-limited-node-pids"

# Create the file if it doesn't exist
touch "$SEEN_PIDS_FILE"

while true; do
  # Get all currently running node PIDs
  for PID in $(pgrep -x node); do
    # Skip if this PID is already tracked
    if ! grep -q "^$PID$" "$SEEN_PIDS_FILE"; then
      echo "Applying cpulimit to PID $PID"
      cpulimit -p $PID -l $CPU_LIMIT -b
      echo $PID >> "$SEEN_PIDS_FILE"
    fi
  done

  # Clean up the list by removing dead PIDs
  TMP_FILE=$(mktemp)
  while read PID; do
    if ps -p $PID > /dev/null; then
      echo $PID >> "$TMP_FILE"
    fi
  done < "$SEEN_PIDS_FILE"
  mv "$TMP_FILE" "$SEEN_PIDS_FILE"

  sleep $CHECK_INTERVAL
done
```

After running the script, CPU usage of node processes was limited to 50%, and the VS Code was no longer freezing.

```bash
    PID USER      PR  NI    VIRT    RES    SHR S  %CPU  %MEM     TIME+ COMMAND
 330045 ubuntu    20   0   84.4g 770784  16320 T  56.8   1.2     3w+5d node
 325323 ubuntu    20   0   84.3g 736824  16320 T  54.8   1.1     4w+1d node
 558513 ubuntu    20   0   52.7g 899112  56540 T  51.8   1.4    4d+11h node
1216323 ubuntu    20   0   74.0g   1.2g  16512 R  50.5   1.8     2w+2d node
1769144 ubuntu    20   0   75.3g 349628  60288 T  48.8   0.5     2w+3d node
2527930 ubuntu    20   0   41.4g 259240  50304 S  11.3   0.4  48:04.50 node
2803800 ubuntu    20   0   41.4g 234040  55104 S   2.7   0.4  10:23.41 node
```

## The Result

Since applying this fix, VS Code has been smooth — no more freezing, and the SSH connection is stable. If you’re running into similar issues with high CPU usage in VS Code (or Cursor, or Windsurf), give this a shot. It’s a simple and effective workaround while we wait for upstream performance improvements.
