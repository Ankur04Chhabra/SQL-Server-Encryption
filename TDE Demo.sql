use master
go

Create Database TestTDE on Primary
(
	Name=N'TestTDE',
	FileName=N'S:\TDE\TestTDE.mdf',
	Size=10240KB,
	Filegrowth =10240KB
)

Log on
(
	Name=N'TestTDE_log',
	FileName=N'S:\TDE\TestTDE_log.ldf',
	Size=10240KB,
	Filegrowth =10240KB
)



use TestTDE
go

Create table TB_Test_TDE
(
	ID int,
	Name varchar(50)
)

insert into TB_Test_TDE
select 1,'TDE'
union all
select 2,'Row Level Encryption'
union all
select 3,'Always Encryption'
union all
select 4,'Encryption Security'



Create table TB_Test_TDE_Warehouse
(
	ID int,
	Name varchar(70)
)

go

Create Procedure TDE_Get_Warehouse_Reords
(
	@start_value int,
	@target_value int

)
as
begin
			while(@start_value<=@target_value)
			begin
					insert into TB_Test_TDE_Warehouse values(@start_value,'Name Start With  '+convert(varchar(10),@start_value))
					set @start_value=@start_value + 1
			end		
end


exec TDE_Get_Warehouse_Reords 10001,1000000

go


select COUNT(*) from dbo.TB_Test_TDE_Warehouse
select * from dbo.TB_Test_TDE

go

Backup database TestTDE to disk='S:\TDE\TestTDE_unENC.bak' with init, compression


use master

go
-- Create Database master key in master database 
Create master key Encryption by password='TestTDE@1234'
select * from sys.symmetric_keys


-- Create Certificates in master database which is ebcrypted by DMK
Create Certificate MyTDECertificate with Subject='My TDE Certificate'

select * from sys.certificates where name not like '%##'


-- Create Database encryption key
use TestTDE
go

Create database encryption key
with Algorithm =AES_128
Encryption by Server Certificate MyTDECertificate

go

/*

Warning: The certificate used for encrypting the database encryption key has not been backed up. 
You should immediately back up the certificate and the private key associated with the certificate. 
If the certificate ever becomes unavailable or if you must restore or attach the database on another server, 
you must have backups of both the certificate and the private key or you will not be able to open the database.

*/
use master
go

Backup Certificate MyTDECertificate
To file ='S:\TDE\MyTDECertificate_Backup.cer'
with private key(file='S:\TDE\MyTDECertificate_Private_key.pvk', encryption by password='India@1234')


-- Check for backup of private key

select name,pvt_key_encryption_type_desc,issuer_name,pvt_key_last_backup_date 
from sys.certificates where name not like '%##'

-- Set Encryption on on database
Alter database TestTDE set Encryption on


select db.name,db.is_encrypted,ek.encryption_state,ek.key_algorithm,ek.percent_complete,ek.key_length 
from sys.databases as db
left outer join sys.dm_database_encryption_keys as ek
on db.database_id=ek.database_id


Backup database TestTDE to disk='S:\TDE\TestTDE_Encrypted_Backup.bak' with init, compression

--- On another Server

Restore filelistonly from disk='c:\TestTDE_Encrypted_Backup.bak' 


Create master key Encryption by password='TestTDE@1234'



Create Certificate MyTDECertificate
from file='c:\MyTDECertificate_Backup.cer'
with private key (file='c:\MyTDECertificate_Private_key.pvk', decryption by password='India@1234')


select * from sys.certificates where name not like '%##'

Restore filelistonly from disk='c:\TestTDE_Encrypted_Backup.bak' 

USE [master]
RESTORE DATABASE [TestTDE] FROM  DISK = N'C:\TestTDE_Encrypted_Backup.bak' 
WITH  FILE = 1,  
MOVE N'TestTDE' TO N'C:\Program Files\Microsoft SQL Server\MSSQL11.MSSQLSERVER\MSSQL\DATA\TestTDE.mdf',  
MOVE N'TestTDE_log' TO N'C:\Program Files\Microsoft SQL Server\MSSQL11.MSSQLSERVER\MSSQL\DATA\TestTDE_log.ldf',  
NOUNLOAD,  STATS = 5