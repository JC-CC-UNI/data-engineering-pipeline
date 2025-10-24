CREATE TABLE demo.dbo.CLIENTS (
        client_id INT,
        name VARCHAR(50),
        created_date DATE,
);
GO

EXEC sys.sp_cdc_enable_table
@source_schema = N'dbo',
@source_name   = N'CLIENTS',
@role_name     = NULL,
@supports_net_changes = 0
GO
