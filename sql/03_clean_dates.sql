ALTER TABLE transactions ADD InvoiceDateTime datetime2;

UPDATE transactions
SET InvoiceDateTime = TRY_CONVERT(datetime2, InvoiceDate, 103);

SELECT COUNT(*) FROM transactions WHERE InvoiceDateTime IS NULL;