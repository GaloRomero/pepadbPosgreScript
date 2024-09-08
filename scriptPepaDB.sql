--Load archaeological structures (structures)
--First we create the table without records
CREATE TABLE pepadb.structures (
    id VARCHAR,
	id_site NUMERIC,
    structure VARCHAR NULL,
	country VARCHAR,
	adm1 VARCHAR,
	adm2 VARCHAR, 
	millennium VARCHAR, 
	struc_type VARCHAR,
	x_coord NUMERIC,
	y_coord NUMERIC,
	PRIMARY KEY (id)
);

SELECT * FROM pepadb.structures

--Now we insert the data included in CSV file 
COPY pepadb.structures(id, id_site, structure, country, adm1, adm2, millennium, struc_type, x_coord, y_coord)
FROM 'C:\pepadbPosgreScript\csvStructures\structures.csv'
DELIMITER ','
CSV HEADER;

--We verify our data
SELECT * FROM pepadb.structures
ORDER BY id ASC

--Now, we include the geom column
ALTER TABLE pepadb.structures ADD COLUMN geom GEOMETRY(Point, 4326);
--Populate the geometry column with the points base on x_coord and y_coord
UPDATE pepadb.structures
SET geom = ST_SetSRID(ST_MakePoint(x_coord, y_coord), 4326);

--After this, we verify it has been include the geometry column
SELECT * FROM pepadb.structures
ORDER BY id ASC

--At this point we have to create 2 more tables: sites and records
--Sites table 
CREATE TABLE pepadb.sites (
    id NUMERIC,
    site VARCHAR NULL,
	PRIMARY KEY (id)
);

SELECT * FROM pepadb.sites

--Now we insert the data included in CSV file 
COPY pepadb.sites(id, site)
FROM 'C:\pepadbPosgreScript\csvSites\sites.csv'
DELIMITER ','
CSV HEADER;

--We verify our data
SELECT * FROM pepadb.sites

--Assign the field ‘id_site’ as a foreign key in the table ‘structures’
ALTER TABLE pepadb.structures
ADD CONSTRAINT fk_sites
FOREIGN KEY (id_site)
REFERENCES pepadb.sites (id); 

--Records table 
CREATE TABLE pepadb.records (
    id_inv VARCHAR,
	id_structure VARCHAR,
	type VARCHAR (150) NULL,
	raw_material VARCHAR (150) NULL,
	PRIMARY KEY (id_inv)
);

--DROP TABLE pepadb.records

--Now we insert the data included in CSV file 
COPY pepadb.records(id_inv, id_structure, type, raw_material)
FROM 'C:\pepadbPosgreScript\csvRecords\records.csv'
DELIMITER ','
CSV HEADER;

--We verify our data
SELECT * FROM pepadb.records

--We assign the field ‘id_structure’ as a foreign key in the table ‘records’
ALTER TABLE pepadb.records
ADD CONSTRAINT fk_structures
FOREIGN KEY (id_structure)
REFERENCES pepadb.structures (id);

---I check what structures found in the table ‘structures’ are not found in the table ‘records’
--As it does not return any rows, they are all
SELECT  *
FROM    pepadb.structures
WHERE   id NOT IN (SELECT id_structure FROM pepadb.records)

--1. GEOVIEWER LAYER 
--FREQUENCY TABLE OF RAW MATERIAL GROUPED BY ARCHAEOLOGICAL STRUCTURE

--CROSS JOIN between (cardinality 1-M) between ‘structures’ and ‘records’.
CREATE TABLE pepadb.struc_record AS 
SELECT pepadb.records.id_inv, pepadb.structures.id, pepadb.structures.id_site, pepadb.structures.structure, pepadb.structures.country, 
pepadb.structures.adm1, pepadb.structures.adm2, pepadb.structures.millennium, pepadb.structures.struc_type,
pepadb.records.type, pepadb.records.raw_material, pepadb.structures.geom
FROM pepadb.structures CROSS JOIN pepadb.records 
WHERE structures.id = records.id_structure;

--DROP TABLE pepadb.struc_record

SELECT * FROM pepadb.struc_record

ALTER TABLE pepadb.struc_record
ADD PRIMARY KEY (id_inv);

--Associate ‘records’ and ‘struc_record’.
ALTER TABLE pepadb.struc_record
ADD CONSTRAINT fk_struc_rec
FOREIGN KEY (id_inv)
REFERENCES pepadb.records (id_inv); 

--We see the different categories of the field ‘raw_material’.
SELECT DISTINCT (raw_material) FROM pepadb.struc_record
ORDER BY raw_material ASC

--We transform the data into a contingency table (also known as a pivot table) 
--where the categories in the raw_material column become columns showing the 
--frequency of each raw_material grouped by the corresponding fields.
CREATE TABLE pepadb.contingency_table AS 
SELECT
    id, structure, country, adm1, adm2, millennium, struc_type,
    COUNT(CASE WHEN raw_material = 'Amber' THEN 1 END) AS Amber,
    COUNT(CASE WHEN raw_material = 'Bone' THEN 1 END) AS Bone,
    COUNT(CASE WHEN raw_material = 'Ceramic' THEN 1 END) AS Ceramic,
	COUNT(CASE WHEN raw_material = 'Coral' THEN 1 END) AS Coral,
    COUNT(CASE WHEN raw_material = 'Fossil' THEN 1 END) AS Fossil,
    COUNT(CASE WHEN raw_material = 'Ivory' THEN 1 END) AS Ivory,
	COUNT(CASE WHEN raw_material = 'Lignite' THEN 1 END) AS Lignite,
    COUNT(CASE WHEN raw_material = 'Rock' THEN 1 END) AS Rock,
    COUNT(CASE WHEN raw_material = 'Seed' THEN 1 END) AS Seed,
	COUNT(CASE WHEN raw_material = 'Shell' THEN 1 END) AS Shell,
    COUNT(CASE WHEN raw_material = 'Wood' THEN 1 END) AS Wood,
	COUNT(*) AS n_items,
	geom
FROM
    pepadb.struc_record
GROUP BY
    id, structure, country, adm1, adm2, millennium, struc_type, geom;
	
--DROP TABLE pepadb.contingency_table

--We verify our data
SELECT * FROM pepadb.contingency_table 

--Asociamos 'contingency_table' y 'structures'
ALTER TABLE pepadb.contingency_table 
ADD CONSTRAINT fk_contingency_table
FOREIGN KEY (id)
REFERENCES pepadb.structures (id);

--2. DATABASE LAYER
--FREQUENCY TABLE OF RAW MATERIAL GROUPED BY ARCHAEOLOGICAL STRUCTURE

CREATE TABLE pepadb.database_table AS (
SELECT struc_record.id, struc_record.structure, struc_record.country, struc_record.adm1,
struc_record.adm2, struc_record.struc_type, struc_record.millennium, struc_record.type, struc_record.raw_material,
COUNT (struc_record.raw_material) as n_items
FROM pepadb.struc_record
GROUP BY struc_record.id, struc_record.structure, struc_record.country, struc_record.adm1,
struc_record.adm2, struc_record.struc_type, struc_record.millennium, struc_record.type, struc_record.raw_material
ORDER BY struc_record.id, struc_record.structure, struc_record.country, struc_record.adm1,
struc_record.adm2, struc_record.struc_type, struc_record.millennium, struc_record.type, struc_record.raw_material);

SELECT * FROM pepadb.database_table

--We verify our data
SELECT COUNT (DISTINCT (id)) FROM pepadb.database_table
SELECT SUM (n_items) FROM pepadb.database_table

--We transform our postgres object into JSON for data exchange purposes
COPY (
  SELECT json_agg(row_to_json(database_table)) :: text
  FROM pepadb.database_table
  WHERE database_table.id IS NOT NULL
) to 'C:\pepadbPosgreScript\json\database_table.json';
