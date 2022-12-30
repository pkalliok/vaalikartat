#!/bin/bash

echo 'candidate_id;party_id;given_name;surname;official_sex;age_at_election;self_given_occupation;home_area_id;mother_tongue'
# piiritunnus,ehdokasnumero,pysyva_puoluetunniste,etunimi,sukunimi,virallinen_sukupuoli,ika_vaalipaivana,ammatti_arvo_toimi,kotikunta,aidinkieli
cut -d ';' -f '2,8,15,18,19,20,21,22,23,26' "$1" |
sort -u |
awk -F ';' '
	BEGIN { OFS=";" }
	1 { print $1 "_" $3, $2, $4, $5, $6, $7, $8, $9, $10 }
'
