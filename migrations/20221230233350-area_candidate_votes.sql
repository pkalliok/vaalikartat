
-- +migrate Up

CREATE TABLE area (
	area_id TEXT PRIMARY KEY,
	part_of_area_id TEXT NULL REFERENCES area(area_id),
	area_type TEXT NOT NULL,
	name_fi TEXT NOT NULL,
	name_sv TEXT NOT NULL
);

CREATE INDEX ON area(area_type);
CREATE INDEX ON area(part_of_area_id);

CREATE TABLE candidate (
	candidate_id TEXT PRIMARY KEY,
	party_id INTEGER NOT NULL,
	given_name TEXT NOT NULL,
	surname TEXT NOT NULL,
	official_sex INTEGER NOT NULL,
	age_at_election INTEGER NOT NULL,
	self_given_occupation TEXT NOT NULL,
	home_area_id TEXT NOT NULL,
	mother_tongue TEXT NOT NULL
);

CREATE INDEX ON candidate(party_id);
CREATE INDEX ON candidate(official_sex);
CREATE INDEX ON candidate(age_at_election);
CREATE INDEX ON candidate(home_area_id);
CREATE INDEX ON candidate(mother_tongue);

CREATE TABLE area_candidate_votes (
	candidate_id TEXT NOT NULL REFERENCES candidate(candidate_id),
	area_id TEXT NOT NULL REFERENCES area(area_id),
	prevotes INTEGER NOT NULL DEFAULT 0,
	election_votes INTEGER NOT NULL DEFAULT 0,
	votes INTEGER NOT NULL DEFAULT 0,
	prevotes_pct REAL NOT NULL DEFAULT 0.0,
	election_votes_pct REAL NOT NULL DEFAULT 0.0,
	votes_pct REAL NOT NULL DEFAULT 0.0,
	PRIMARY KEY (candidate_id, area_id)
);

-- +migrate Down

DROP TABLE area_candidate_votes;
DROP TABLE candidate;
DROP TABLE area;

