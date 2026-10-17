--DROP TABLE IF EXISTS
DROP TABLE transactions;

CREATE TABLE transactions (
    Invoice nvarchar(20),
    StockCode nvarchar(20),
    Description nvarchar(255),
    Quantity int,
    InvoiceDate datetime2,
    Price decimal(10,2),
    CustomerID nvarchar(20),
    Country nvarchar(50),
    sourcesheet nvarchar(20)
);