/*
   Description:    This function performs string hygiene based on the specified hygiene type.

   dbo.ufsUtilities_Hygiene_String(@pValue, 'Description')
   
*/
CREATE FUNCTION [dbo].[ufsUtilities_Hygiene_String]
(
    @pValue        NVARCHAR(MAX),
    @pHygieneType VARCHAR(100)
)
RETURNS NVARCHAR(MAX)
AS
BEGIN

    DECLARE @lnHygieneValue NVARCHAR(MAX);

    -- Replacement Options
    --SQL Prompt Formatting Off
    SET @lnHygieneValue = CASE @pHygieneType
                              WHEN 'DatabaseNameFS'                       THEN RTRIM(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(@pValue),'\',''),'/',''),':',''),'*',''),'?',''),'"',''),'<',''),'>',''),'|','')
                              WHEN 'DirectoryStructure'                   THEN REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(@pValue,'{DirectorySeparator}',''),'{ServerName}',''),'{InstanceName}',''),'{ServiceName}',''),'{ClusterName}',''),'{AvailabilityGroupName}',''),'{DatabaseName}',''),'{BackupType}',''),'{Partial}',''),'{CopyOnly}',''),'{Description}',''),'{BackupSetName}',''),'{Year}',''),'{Month}',''),'{Day}',''),'{Week}',''),'{Weekday}',''),'{Hour}',''),'{Minute}',''),'{Second}',''),'{Millisecond}',''),'{Microsecond}',''),'{MajorVersion}',''),'{MinorVersion}','')
                              --    DirectoryStructure, AvailabilityGroupDirectoryStructure are the same hygiene rules
                              --    FileName very close
                              --    Filename, AvailabilityGroupFileName are the same hygiene rules
                              WHEN 'AvailabilityGroupDirectoryStructure'  THEN REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(@pValue,'{DirectorySeparator}',''),'{ServerName}',''),'{InstanceName}',''),'{ServiceName}',''),'{ClusterName}',''),'{AvailabilityGroupName}',''),'{DatabaseName}',''),'{BackupType}',''),'{Partial}',''),'{CopyOnly}',''),'{Description}',''),'{BackupSetName}',''),'{Year}',''),'{Month}',''),'{Day}',''),'{Week}',''),'{Weekday}',''),'{Hour}',''),'{Minute}',''),'{Second}',''),'{Millisecond}',''),'{Microsecond}',''),'{MajorVersion}',''),'{MinorVersion}','') 
                              WHEN 'AvailabilityGroupFileName'            THEN REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(@pValue,'{DirectorySeparator}',''),'{ServerName}',''),'{InstanceName}',''),'{ServiceName}',''),'{ClusterName}',''),'{AvailabilityGroupName}',''),'{DatabaseName}',''),'{BackupType}',''),'{Partial}',''),'{CopyOnly}',''),'{Description}',''),'{BackupSetName}',''),'{Year}',''),'{Month}',''),'{Day}',''),'{Week}',''),'{Weekday}',''),'{Hour}',''),'{Minute}',''),'{Second}',''),'{Millisecond}',''),'{Microsecond}',''),'{FileNumber}',''),'{NumberOfFiles}',''),'{FileExtension}',''),'{MajorVersion}',''),'{MinorVersion}','') 
                              WHEN 'FileName'                             THEN REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(@pValue,'{DirectorySeparator}',''),'{ServerName}',''),'{InstanceName}',''),'{ServiceName}',''),'{ClusterName}',''),'{AvailabilityGroupName}',''),'{DatabaseName}',''),'{BackupType}',''),'{Partial}',''),'{CopyOnly}',''),'{Description}',''),'{BackupSetName}',''),'{Year}',''),'{Month}',''),'{Day}',''),'{Week}',''),'{Weekday}',''),'{Hour}',''),'{Minute}',''),'{Second}',''),'{Millisecond}',''),'{Microsecond}',''),'{FileNumber}',''),'{NumberOfFiles}',''),'{FileExtension}',''),'{MajorVersion}',''),'{MinorVersion}','') 
                              --   BackupSetName and Description are the same hygiene rules
                              WHEN 'BackupSetName'                        THEN LTRIM(RTRIM(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(ISNULL(@pValue,''),'\',''),'/',''),':',''),'*',''),'?',''),'"',''),'<',''),'>',''),'|','')))
                              WHEN 'Description'                          THEN LTRIM(RTRIM(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(ISNULL(@pValue,''),'\',''),'/',''),':',''),'*',''),'?',''),'"',''),'<',''),'>',''),'|','')))
                              ELSE NULL
                          END;
    --SQL Prompt Formatting On

    RETURN @lnHygieneValue;
END;
