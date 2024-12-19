#!/bin/bash

for file in $(ls 0[0,1,2,3]*.sql); do
    echo $file
done