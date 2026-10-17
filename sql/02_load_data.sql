-- Imported retail_2009_2010.csv via DBeaver, then:
UPDATE transactions SET sourcesheet = '2009_2010' WHERE sourcesheet IS NULL;

-- Imported retail_2010_2011.csv via DBeaver, then:
UPDATE transactions SET sourcesheet = '2010_2011' WHERE sourcesheet IS NULL;