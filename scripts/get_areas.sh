#!/bin/bash

echo 'area_id;part_of_area_id;area_type;name_fi;name_sv'
# piiritunnus,kuntatunnus,tyyppi,aluetunnus,nimi_fi,nimi_sv
cut -d ';' -f '2,3,4,5,16,17' "$1" |
sort -u |
awk -F';' '
	BEGIN { OFS=";" }
	$3 == "A" { print $2 "_" $4, $2, "area", $5, $6 }
	$3 == "K" { print $2, $1, "municipality", $5, $6 }
	$3 == "V" { print $1, "", "district", $5, $6 }
'
