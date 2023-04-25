#!/bin/bash
#
# Purpose: Initial commands to run every time regardless of mode

if [ "$DEBUG" == "true" ]; then
    echo "Retrieving worker size..."
    df -h
fi