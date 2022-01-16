#!/bin/bash

if [[ $(date +%u) -gt 5 ]]; then
  if  getent group admin | cut -d ':' -f4 | grep -wq "${PAM_USER}"; then
      exit 0
  else
      exit 1
  fi
else
  exit 0
fi  
