CREATE TABLE transactions (
	Invoice nvarchar(20),
	Stock_Code nvarchar(20),
	Description nvarchar(255),
	Quantity int,
	Invoice_Date datetime2,
	Price decimal(10,2),
	Customer_ID nvarchar(20),
	Country nvarchar(50),
	sourcesheet nvarchar(20)
)