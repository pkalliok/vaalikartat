#!/bin/bash

echo candidate_id,party_id,given_name,surname,official_sex,age_at_election,self_given_occupation,home_id,mother_tongue
# piiritunnus,ehdokasnumero,pysyva_puoluetunniste,etunimi,sukunimi,virallinen_sukupuoli,ika_vaalipaivana,ammatti_arvo_toimi,kotikunta,aidinkieli
csvcut -S -d ';' -c '2,15,8,18,19,20,21,22,23,26' "$1" |
sort -u |
sed 's/,/_/'
