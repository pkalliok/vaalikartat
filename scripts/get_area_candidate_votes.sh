#!/bin/bash

echo 'candidate_id;area_id;prevotes;election_votes;votes;prevotes_pct;election_votes_pct;votes_pct'
# piiritunnus,kuntatunnus,tyyppi,aluetunnus,ehdokasnumero,ennakkoaanet,vaalipaivaaanet,aanet,ennakkoaaniosuus,vaalipaivaaaniosuus,aaniosuus
cut -d ';' -f '2,3,4,5,15,33,34,35,36,37,38' "$1" |
LC_NUMERIC=C awk -F';' '
	BEGIN { OFS=";" }
	$3 == "A" { area_id = $2 "_" $4 }
	$3 == "K" { area_id = $2 }
	$3 == "V" { area_id = $1 }
	1 { print $1 "_" $5, area_id, $6, $7, $8, $9*0.1, $10*0.1, $11*0.1 }
' |
sort
