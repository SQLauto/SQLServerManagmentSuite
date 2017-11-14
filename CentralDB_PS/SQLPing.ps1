param(
	[string]$SQLInst="P-SEC-DBS001\PRDM11A",
	[string]$Centraldb="CentralDB"
	)
[System.Reflection.Assembly]::LoadWithPartialName('Microsoft.SqlServer.SMO') | out-null
[System.Reflection.Assembly]::LoadWithPartialName('Microsoft.SqlServer.ConnectionInfo') | out-null
[System.Reflection.Assembly]::LoadWithPartialName('Microsoft.SqlServer.SqlWmiManagement') | out-null

#http://poshcode.org/2813
function Write-Log {   
            #region Parameters
                    [cmdletbinding()]
                    Param(
                            [Parameter(ValueFromPipeline=$true,Mandatory=$true)] [ValidateNotNullOrEmpty()]
                            [string] $Message,
                            [Parameter()] [ValidateSet(“Error”, “Warn”, “Info”)]
                            [string] $Level = “Info”,
                            [Parameter()]
                            [Switch] $NoConsoleOut,
                            [Parameter()]
                            [String] $ConsoleForeground = 'White',
                            [Parameter()] [ValidateRange(1,30)]
                            [Int16] $Indent = 0,     
                            [Parameter()]
                            [IO.FileInfo] $Path = ”$env:temp\PowerShellLog.txt”,                           
                            [Parameter()]
                            [Switch] $Clobber,                          
                            [Parameter()]
                            [String] $EventLogName,                          
                            [Parameter()]
                            [String] $EventSource,                         
                            [Parameter()]
                            [Int32] $EventID = 1,
                            [Parameter()]
                            [String] $LogEncoding = "ASCII"                         
                    )                   
            #endregion
            Begin {}
            Process {
                    try {                  
                            $msg = '{0}{1} : {2} : {3}' -f (" " * $Indent), (Get-Date -Format “yyyy-MM-dd HH:mm:ss”), $Level.ToUpper(), $Message                           
                            if ($NoConsoleOut -eq $false) {
                                    switch ($Level) {
                                            'Error' { Write-Error $Message }
                                            'Warn' { Write-Warning $Message }
                                            'Info' { Write-Host ('{0}{1}' -f (" " * $Indent), $Message) -ForegroundColor $ConsoleForeground}
                                    }
                            }
                            if ($Clobber) {
                                    $msg | Out-File -FilePath $Path -Encoding $LogEncoding -Force
                            } else {
                                    $msg | Out-File -FilePath $Path -Encoding $LogEncoding -Append
                            }
                            if ($EventLogName) {
                           
                                    if (-not $EventSource) {
                                            $EventSource = ([IO.FileInfo] $MyInvocation.ScriptName).Name
                                    }
                           
                                    if(-not [Diagnostics.EventLog]::SourceExists($EventSource)) {
                                            [Diagnostics.EventLog]::CreateEventSource($EventSource, $EventLogName)
                            }
                                $log = New-Object System.Diagnostics.EventLog  
                                $log.set_log($EventLogName)  
                                $log.set_source($EventSource)                       
                                    switch ($Level) {
                                            “Error” { $log.WriteEntry($Message, 'Error', $EventID) }
                                            “Warn”  { $log.WriteEntry($Message, 'Warning', $EventID) }
                                            “Info”  { $log.WriteEntry($Message, 'Information', $EventID) }
                                    }
                            }
                    } catch {
                            throw “Failed to create log entry in: ‘$Path’. The error was: ‘$_’.”
                    }
            }    
            End {}    
            <#
                    .SYNOPSIS
                            Writes logging information to screen and log file simultaneously.    
                    .DESCRIPTION
                            Writes logging information to screen and log file simultaneously. Supports multiple log levels.     
                    .PARAMETER Message
                            The message to be logged.     
                    .PARAMETER Level
                            The type of message to be logged.                         
                    .PARAMETER NoConsoleOut
                            Specifies to not display the message to the console.                        
                    .PARAMETER ConsoleForeground
                            Specifies what color the text should be be displayed on the console. Ignored when switch 'NoConsoleOut' is specified.                  
                    .PARAMETER Indent
                            The number of spaces to indent the line in the log file.     
                    .PARAMETER Path
                            The log file path.                  
                    .PARAMETER Clobber
                            Existing log file is deleted when this is specified.                   
                    .PARAMETER EventLogName
                            The name of the system event log, e.g. 'Application'.                   
                    .PARAMETER EventSource
                            The name to appear as the source attribute for the system event log entry. This is ignored unless 'EventLogName' is specified.                   
                    .PARAMETER EventID
                            The ID to appear as the event ID attribute for the system event log entry. This is ignored unless 'EventLogName' is specified.     
                    .EXAMPLE
                            PS H:\Temp\> Write-Log -Message "It's all good!" -Path H:\Temp\MyLog.log -Clobber -EventLogName 'Application'     
                    .EXAMPLE
                            PS H:\Temp\> Write-Log -Message "Oops, not so good!" -Level Error -EventID 3 -Indent 2 -EventLogName 'Application' -EventSource "My Script"     
                    .INPUTS
                            System.String     
                    .OUTPUTS
                            No output.                           
                    .NOTES
                            Revision History:
                                    2011-03-10 : Andy Arismendi - Created.
                                    2011-07-23 : Will Steele - Updated.
            #>
    }
#http://poshtips.com/measuring-elapsed-time-in-powershell/

$ElapsedTime = [System.Diagnostics.Stopwatch]::StartNew()
$displayOutput = "SQLPing Script Started at $(get-date)"
write-log -Message "$displayOutput" -NoConsoleOut -Clobber -Path S:\CentralDB\Errorlog\SQLPing.log
write-output $displayOutput

$cn = new-object system.data.sqlclient.sqlconnection(“server=$SQLInst;database=$CentralDB;Integrated Security=true;”);
$cn.Open()
$cmd = $cn.CreateCommand()
$query = "SELECT DISTINCT ServerName, InstanceName FROM [Svr].[ServerList] WHERE   SQLPing = 'True' AND (PingSnooze IS NULL OR PingSnooze <= GETDATE()) AND ((MaintStart IS NULL) or (MaintEnd IS NULL) or (GETDATE() NOT BETWEEN MaintStart AND MaintEnd ))"
$cmd.CommandText = $query
$reader = $cmd.ExecuteReader()
while($reader.Read()) 
{	
    $server = $reader['ServerName']	
    $instance = $reader['InstanceName']    
    $SQLServerConnection = ""
    if ($instance -match "\\") {$SQLServerConnection = $instance} else {$SQLServerConnection = $server + "\" +  $instance}	

	$res = new-object Microsoft.SqlServer.Management.Common.ServerConnection($SQLServerConnection)
	$resp = $false
            
	if ($res.ProcessID -ne $null) 
    {
		$resp = $true
        $displayOutput = $SQLServerConnection + " successfully connected at $(get-date)."
        write-log -Message "$displayOutput" -NoConsoleOut -Path S:\CentralDB\Errorlog\SQLPing.log
        write-output $displayOutput
        $res.Disconnect()
    }
    else
    {
        $displayOutput = $SQLServerConnection + " unable to connect at $(get-date)."
        write-log -Message "$displayOutput" -NoConsoleOut -Path S:\CentralDB\Errorlog\SQLPing.log
        write-output $displayOutput
        $res.Disconnect()
		Send-MailMessage -To "jsg.sqldbaz3@gov.ab.ca" -From "jsg.sqldbaz3@gov.ab.ca" -SmtpServer "mail.secure.ds" -Subject "CentralDB: Unable to connect to $instance" -body "Unable to connect to $instance Instance. Please make sure if you are able to RDP to the box and Check SQL Services. "
	}

}
$displayOutput = "Total Elapsed Time: $($ElapsedTime.Elapsed.ToString())"
write-log -Message "$displayOutput" -NoConsoleOut -Path S:\CentralDB\Errorlog\SQLPing.log 
write-output $displayOutput	