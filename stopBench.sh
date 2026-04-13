#!/bin/bash

ALG_ID=${1:-"CMAES"}
PGID=$(cat "$ALG_ID"_pid.txt)

# First, send a polite termination signal to the entire process group
# The minus sign in front of PGID tells kill to target the whole group
kill -TERM -"$PGID"

# Wait 2 seconds to give processes a chance to exit cleanly
sleep 2

# If any processes remain, forcefully kill the entire process group
kill -KILL -"$PGID" 2>/dev/null
