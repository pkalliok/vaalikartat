#!/bin/bash

sed -ne "/^$1:$/,/^[^ ]/{;s/^ *datasource: //p;}" dbconfig.yml
