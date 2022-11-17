#!/bin/bash

index=${1}
port=${2}

ip=$(hostname -I | cut -d ' ' -f $index | tr -d ' ')

echo "$ip:$port"
