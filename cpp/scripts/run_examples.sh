#!/bin/bash

cd build
for file in ./*
do
  if [[ -f "$file" && -x "$file" ]]; then
    echo "Executing: $file"
    if ! "$file"; then
      echo "Error occurred while executing $file. Exiting script."
      exit 1
    fi
  fi
done
