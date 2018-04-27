.PHONY: download clean import run
CD := $(shell pwd)
clean:
	rm -rf downloads/*
process: process.rb
	rm -rf build && ruby process.rb
download: downloads/csv/oakland_candidates.csv downloads/csv/oakland_committees.csv \
	downloads/csv/oakland_referendums.csv downloads/csv/oakland_name_to_number.csv \
	download-BRK-2017 download-BRK-2018
download-BRK-%:
	ruby ssconvert.rb downloads/efile_BRK_$(subst download-BRK-,,$@).xlsx 'downloads/csv/efile_BRK_$(subst download-BRK-,,$@)_%{sheet}.csv'
import: dropdb createdb 496 497 A-Contributions B1-Loans B2-Loans C-Contributions \
		D-Expenditure E-Expenditure F-Expenses F461P5-Expenditure F465P3-Expenditure \
		F496P3-Contributions G-Expenditure H-Loans I-Contributions Summary
	csvsql --doublequote --db postgresql:///disclosure-backend --insert downloads/csv/oakland_candidates.csv
	echo 'ALTER TABLE "oakland_candidates" ADD COLUMN id SERIAL PRIMARY KEY;' | psql disclosure-backend
	csvsql --doublequote --db postgresql:///disclosure-backend --insert downloads/csv/oakland_referendums.csv
	echo 'ALTER TABLE "oakland_referendums" ADD COLUMN id SERIAL PRIMARY KEY;' | psql disclosure-backend
	csvsql --doublequote --db postgresql:///disclosure-backend --insert downloads/csv/oakland_name_to_number.csv
	csvsql --doublequote --db postgresql:///disclosure-backend --insert downloads/csv/oakland_committees.csv
	echo 'ALTER TABLE "oakland_committees" ADD COLUMN id SERIAL PRIMARY KEY;' | psql disclosure-backend
	echo 'CREATE TABLE "office_elections" (id SERIAL PRIMARY KEY, name VARCHAR(255), election_name VARCHAR(255));' | psql disclosure-backend
	echo 'CREATE TABLE "calculations" (id SERIAL PRIMARY KEY, subject_id integer, subject_type varchar(30), name varchar(40), value jsonb);' | psql disclosure-backend
	./bin/make_view
	./bin/remove_duplicate_transactions
dropdb:
	dropdb disclosure-backend || true
createdb:
	createdb disclosure-backend
496 497 A-Contributions B1-Loans B2-Loans C-Contributions D-Expenditure E-Expenditure F-Expenses F461P5-Expenditure F465P3-Expenditure F496P3-Contributions G-Expenditure H-Loans I-Contributions Summary:
	csvstack downloads/csv/efile_*_$@.csv | csvsql --db postgresql:///disclosure-backend --tables $@ --insert
	./bin/clean $@
	./bin/latest_only $@
downloads/csv/oakland_candidates.csv:
	mkdir -p downloads/csv downloads/raw
	# 2018 candidates
	wget -q -O- \
		'https://docs.google.com/spreadsheets/d/e/2PACX-1vRZNbqOzI3TlelO3OSh7QGC1Y4rofoRPs0TefWDLJvleFkaXq_6CSWgX89HfxLYrHhy0lr4QqUEryuc/pub?gid=0&single=true&output=csv' | \
	sed -e '1s/ /_/g' | \
	sed -e '1s/[^a-zA-Z,_]//g' > downloads/csv/oakland_candidates.csv
downloads/csv/oakland_referendums.csv:
	mkdir -p downloads/csv downloads/raw
	# 2018 referendums
	wget -q -O- \
		'https://docs.google.com/spreadsheets/d/e/2PACX-1vRZNbqOzI3TlelO3OSh7QGC1Y4rofoRPs0TefWDLJvleFkaXq_6CSWgX89HfxLYrHhy0lr4QqUEryuc/pub?gid=608094632&single=true&output=csv' | \
	sed -e '1s/ /_/g' | \
	sed -e '1s/[^a-zA-Z,_]//g' > downloads/csv/oakland_referendums.csv
	
downloads/csv/oakland_name_to_number.csv:
	mkdir -p downloads/csv
	wget -q -O- \
		'https://docs.google.com/spreadsheets/d/e/2PACX-1vRZNbqOzI3TlelO3OSh7QGC1Y4rofoRPs0TefWDLJvleFkaXq_6CSWgX89HfxLYrHhy0lr4QqUEryuc/pub?gid=102954444&single=true&output=csv' | \
	sed -e '1s/ /_/g' | \
	sed -e '1s/[^a-zA-Z,_]//g' > $@
downloads/csv/oakland_committees.csv:
	mkdir -p downloads/csv
	wget -q -O- \
		'https://docs.google.com/spreadsheets/d/e/2PACX-1vRZNbqOzI3TlelO3OSh7QGC1Y4rofoRPs0TefWDLJvleFkaXq_6CSWgX89HfxLYrHhy0lr4QqUEryuc/pub?gid=145882925&single=true&output=csv' | \
	sed -e '1s/ /_/g' | \
	sed -e '1s/[^a-zA-Z,_]//g' > $@
run:
	bundle exec ruby server.rb
