 ########################################
 # Checkpoint CIS Benchmarking Script   #
 # Dated 19/0/2025 - Designer MAJ       #
 ########################################
 # Requires 2 feeder files to function  #
 # $PWD\sbenchmarking.csv               #
 # $PWD\_commands.txt                   #
 ########################################
 function Find-DataPos {
    param ([string]$StartPattern,[string]$Content)

    $regex = [regex]::Escape($StartPattern) + '.*?\b b'
    $match = [regex]::Match($Content, $regex, 'Singleline, Multiline')
    return $match.value
}

function Find-Phrase {
        param ([string]$FilePath,[string]$Phrase)
        $i = 0;Get-Content $FilePath | ForEach-Object {$i++;$pos = $_.IndexOf($Phrase);if ($pos -ge 0) {[PSCustomObject]@{LineNumber = ($i-1);Position = $pos;LineText = $_}}}
}


function Get-InterfaceStatus {
        param ([string]$FilePath)

        $data = Get-Content -Path $FilePath -Raw
        $interfaces = $data -split "Interface " | Where-Object { $_ -imatch "^(eth|lo|mgmt)" }

        $results = foreach ($block in $interfaces) {
                $lines = $block -split "`n" | ForEach-Object { $_.Trim() }
                $iface = $lines[0]
                $state = ($lines | Where-Object { $_ -like "state *" }) -replace "state ", ""
                $linkState = ($lines | Where-Object { $_ -like "link-state *" }) -replace "link-state ", ""
                $isUp = if ($state -eq "on" -and $linkState -eq "link down") { $false } else { $true }
                [PSCustomObject]@{Interface = $iface;State     = $state;LinkState = $linkState;IsUp      = $isUp}
        }
        return $results
}

function Find-editDataPos {
    param ([string]$StartPattern,[string]$Content)

    $regex = [regex]::Escape($StartPattern) + '.*?\bnext\b'
    $match = [regex]::Match($Content, $regex, 'Singleline, Multiline')
    return $match.value
}

function Write-CritialError {param ([string]$Text);$esc = [char]27; Write-Host "$esc[5;37;41m $Text $esc[0m"}


function Does-FileExists {
        param ([string]$FilePath)
        if (Test-Path $FilePath) {Write-Host -f green "$FilePath ✔️"; return $true} else { Write-Host -f red "$FilePath ❌";return $false}
}

function txt2excel{
        #This function and formats data passedti it from the array $data 
        #then creates and formats the excel doemnt before saving it in the curremt directory
        
        param ([string]$hostname,[string]$serialnumber,[PSCustomObject]$data,[string]$filepath)
        $postfix        =       Get-Date -format yyyyMMdd_HHmm
        $excelpath      =       "$($PWD)\$($hostname)_$($postfix).xlsx"
    
     
        write-host "Output >> $($excelPath)"
        
        # Create Excel COM object
        $excel = New-Object -ComObject Excel.Application
        $excel.Visible = $false
        $excel.ErrorCheckingOptions.NumberAsText = $false
        $workbook = $excel.Workbooks.Add()
        $worksheet = $workbook.Worksheets.Item(1)
        $worksheet.Cells.Item(1, 2).Value2 = "Firewall Hostname"
        $worksheet.Cells.Item(1, 3).Value2 = $hostname
        $worksheet.Cells.Item(2, 2).Value2 = "Firewall Serial Number"
        $worksheet.Cells.Item(2, 3).Value2 = $serialnumber
        $worksheet.Cells.Item(3, 1).Value2 = "#"
        $worksheet.Cells.Item(3, 2).Value2 = "Control"
        $worksheet.Cells.Item(3, 3).Value2 = "Level 1or 2"
        $worksheet.Cells.Item(3, 4).Value2 = "Status"                             
        $worksheet.Range("A3:D3").Interior.ColorIndex   =       3       #Red
        $worksheet.Range("A3:D3").Font.ColorIndex       =       2       #White
 
        $row = 4
        foreach ($line in $data) {
                $fields = $line -split ","
                        # [int]$counter = ([int]$fields[0]+1)
                        if ($fields[3] -gt 0){$worksheet.Cells.Item($row, 1).value2                                     =       "'$($fields[0])" } #    Column 1  
                        $worksheet.Cells.Item($row, 2).value2                                                           =       $fields[1]         #    Column 2 
                        if ($fields[3] -gt 0){$worksheet.Cells.Item($row, 3).value2                                     =       $fields[2]}        #    Column 3     
                        $worksheet.Cells.Item($row, 4).value2                                                           =       $fields[3]         #    Column 4
                        if ($fields[2] -eq 0){$worksheet.Range("A$($row):D$($row)").Interior.ColorIndex                 =       15 }  
                        if ($fields[3] -match '^COMPLIANT'){$worksheet.Range("D$($row):D$($row)").Interior.ColorIndex       =       4}  
                        if ($fields[3] -match '^NON-COMPLIANT'){$worksheet.Range("D$($row):D$($row)").Interior.ColorIndex   =       3}               
                $row++
        }
        $worksheet.Cells.Item(($row+1),2).value2                        =       "Dated $((Get-Date).ToString('dddd, dd MMMM yyyy HH:mm'))"
        $x      =   $worksheet.usedRange.Font.Name                      =       "Fujitsu Infinity Pro"
        $x      =   $worksheet.UsedRange.Font.Size                      =       11
        $x      =   $worksheet.UsedRange.EntireColumn.AutoFit()
        $x      =   $worksheet.Cells.EntireColumn.VerticalAlignment     =       -4160     # -4160 corresponds to xlTop (top alignment)
        $x      =   $worksheet.Cells.EntireColumn.HorizontalAlignment   =       -4131    # -4131 corresponds to xlLeft (left alignment)
        $x      =   $worksheet.Name                                     =       $hostname
        $x      =   $worksheet.Range("A:A").NumberFormat                =       "@"




        # Find last used row in column C
        $x      =      $worksheet.Range("C3", "C100").HorizontalAlignment   =   -4108       # -4108 corresponds to xcenter (lcenter alignment)
        #$x      =   $worksheet.Range("d10", "d90").HorizontalAlignment   =   -4108       # -4108 corresponds to xcenter (lcenter alignment)

        #Save and close
        $workbook.Saveas($excelPath)
        $workbook.Close($false)
        $excel.Quit()

        # Release COM objects
        [System.Runtime.Interopservices.Marshal]::ReleaseComObject($worksheet)      | Out-Null
        [System.Runtime.Interopservices.Marshal]::ReleaseComObject($workbook)       | Out-Null
        [System.Runtime.Interopservices.Marshal]::ReleaseComObject($excel)          | Out-Null
        [GC]::Collect()
        [GC]::WaitForPendingFinalizers()
        IF ($_exop_){Start-Process   $excelpath}
}

function ProcessData {
        param ([string]$filelocation)
        #this function collects the raw data from the show full-configuration

        $commands       =       $null
        $data           =       Get-Content "$PWD\_commands.txt"  
        $patterns       =       $data| Where-Object { $_ -notmatch "#" }
        $results        =       Get-Content $filelocation
        $rawresults     =       Get-Content $filelocation -raw
        $serialnumber   =       (((Get-Content "$($filelocation)")[1]) -split " ")[1]
        $osver           =      (((($results | Where-Object { $_ -match '#config-version' }) -split "=")[1]) -split ":")[0]
        $status         =       @()
        $controls       =       @()
        $display        =       @()
        $CR             =       [char]13 + [char]10

        $display        =       Import-Csv -Path "$PWD\_benchmarking.csv"      # Assumes a CSV with "Control" and "Level" columns
        
        # Use the imported data directly
        $_pos_          =       (Find-Phrase -FilePath $filelocation -Phrase $patterns[0]).linenumber
        $hostname       =       ($results[($_pos_+1)]).toupper()
        
        #Serial Number
        $_pos_          =       (Find-Phrase -FilePath $filelocation -Phrase "Serial Number").linenumber
        $serialnumber    =      ($results[($_pos_)] -split " ")[-1]

        #1.1 password-controls min-password-length > 14
        #Ensure Minimum Password Length is set to 14 or higher
        $_pos_          =       (Find-Phrase -FilePath $filelocation -Phrase $patterns[4]).linenumber     
        $reply          =       ($results[($_pos_+1)] -split " ")[-1]                                                            
        if([int]$reply -ge 14)     {$status  +="COMPLIANT"}else{$status+="NON-COMPLIANT ($($reply))"};$status+=$CR   

        #1.2 show password-controls complexity = on
        #Ensure Disallow Palindromes is selected
        $_pos_          =       (Find-Phrase -FilePath $filelocation -Phrase $patterns[5]).linenumber     
        $reply          =       ($results[($_pos_+1)] -split " ")[-1]                                                            
        if([string]$reply -eq "on" )  {$status  +="COMPLIANT"}else{$status+="NON-COMPLIANT ($($reply))"};$status+=$CR   

        #1.3 show password-controls complexity > 3
        #Ensure Password Complexity is set to 3 
        $_pos_          =       (Find-Phrase -FilePath $filelocation -Phrase $patterns[6]).linenumber     
        $reply          =       ($results[($_pos_+1)] -split " ")[-1]                                                            
        if([int]$reply -ge 3)   {$status  +="COMPLIANT"}else{$status+="NON-COMPLIANT ($($reply))"};$status+=$CR   

        #1.4.1 show password-controls history-checking = on
        #Ensure Check for Password Reuse is selected and History Length is set to 12 or more
        $_pos_          =       (Find-Phrase -FilePath $filelocation -Phrase $patterns[7]).linenumber     
        $reply          =       ($results[($_pos_+1)] -split " ")[-1]                                                            
        if([string]$reply -eq "on" )    {$status  +="COMPLIANT"}else{$status+="NON-COMPLIANT ($($reply))"};$status+=$CR   

        #1.4.2 show password-controls history-length >12
        #Ensure Check for Password Reuse is selected and History Length is set to 12 or more
        $_pos_          =       (Find-Phrase -FilePath $filelocation -Phrase $patterns[8]).linenumber     
        $reply          =       ($results[($_pos_+1)] -split " ")[-1]               
        if([int]$reply -gt 12 )    {$status  +="COMPLIANT"}else{$status+="NON-COMPLIANT ($($reply))"};$status+=$CR   

        #1.5 Ensure Password Expiration is set to 90 days
        #show password-controls password-expiration
        $_pos_          =       (Find-Phrase -FilePath $filelocation -Phrase $patterns[9]).linenumber     
        $reply          =       ($results[($_pos_+1)] -split " ")[-1]            
        if($reply -is [string]){$status+="NON-COMPLIANT ($($reply))";$status+=$CR}else{if([int]$reply -le 90 ){$status  +="COMPLIANT"}else{$status+="NON-COMPLIANT ($($reply))"};$status+=$CR}

        #1.6 Ensure Warn users before password expiration is set to 7 days
        #show password-controls expiration-warning-days
        $_pos_          =       (Find-Phrase -FilePath $filelocation -Phrase $patterns[10]).linenumber     
        $reply          =       ($results[($_pos_+1)] -split " ")[-1]               
        if([int]$reply -gt 7 )    {$status  +="COMPLIANT"}else{$status+="NON-COMPLIANT ($($reply))"};$status+=$CR   

        #1.7 Ensure Lockout users after password expiration is set to 1
        #show password-controls expiration-lockout-days
        $_pos_          =       (Find-Phrase -FilePath $filelocation -Phrase $patterns[11]).linenumber     
        $reply          =       ($results[($_pos_+1)] -split " ")[-1]               
        if($reply -is [string]){$status+="NON-COMPLIANT ($($reply))";$status+=$CR}else{if([int]$reply -le 90 ){$status  +="COMPLIANT"}else{$status+="NON-COMPLIANT ($($reply))"};$status+=$CR}

        #1.8 show password-controls deny-on-nonuse enable
        #Ensure Deny access to unused accounts is selected
        $_pos_          =       (Find-Phrase -FilePath $filelocation -Phrase $patterns[12]).linenumber     
        $reply          =       ($results[($_pos_[0]+1)] -split " ")[-1]      
        if([string]$reply -eq "on" )    {$status  +="COMPLIANT"}else{$status+="NON-COMPLIANT ($($reply))"};$status+=$CR 

        #1.9 show password-controls deny-on-nonuse allowed-days
        #Ensure Days of non-use before lock-out is set to 30
        $_pos_          =       (Find-Phrase -FilePath $filelocation -Phrase $patterns[13]).linenumber     
        $reply          =       ($results[($_pos_+1)] -split " ")[-1]      
        if([int]$reply -ge 30 )    {$status  +="COMPLIANT"}else{$status+="NON-COMPLIANT ($($reply))"};$status+=$CR   

        #1.10 show password-controls force-change-when
        #Ensure Force users to change password at first login after password was changed from Users page is selected
        $_pos_          =       (Find-Phrase -FilePath $filelocation -Phrase $patterns[14]).linenumber     
        $reply          =       ($results[($_pos_+1)] -split " ")[-1]      
        if([string]$reply -match "yes" )    {$status  +="COMPLIANT"}else{$status+="NON-COMPLIANT ($($reply))"};$status+=$CR 

        #1.11 show password-controls deny-on-fail enable
        #Ensure Deny access after failed login attempts is selected
        $_pos_          =       (Find-Phrase -FilePath $filelocation -Phrase $patterns[15]).linenumber     
        $reply          =       ($results[($_pos_+1)] -split " ")[-1]         
        if([string]$reply -eq "on" )    {$status  +="COMPLIANT"}else{$status+="NON-COMPLIANT ($($reply))"};$status+=$CR 

        #1.12 show password-controls deny-on-fail failures-allowed
        #Ensure Maximum number of failed attempts allowed is set to 5 or fewer
        $_pos_          =       (Find-Phrase -FilePath $filelocation -Phrase $patterns[16]).linenumber     
        $reply          =       ($results[($_pos_+1)] -split " ")[-1]      
        if([string]$reply -le 5 )    {$status  +="COMPLIANT"}else{$status+="NON-COMPLIANT ($($reply))"};$status+=$CR           

        #1.13 show password-controls deny-on-fail allow-after
        #Ensure Allow access again after time is set to 300 or more seconds
        $_pos_          =       (Find-Phrase -FilePath $filelocation -Phrase $patterns[17]).linenumber     
        $reply          =       ($results[($_pos_[0]+1)] -split " ")[-1]      
        if([int]$reply -le 300 )    {$status  +="COMPLIANT"}else{$status+="NON-COMPLIANT ($($reply))"};$status+=$CR       

        #2.1.1 show configuration message
        #Ensure 'Login Banner' is set
        $_pos_          =      (Find-Phrase -FilePath $filelocation -Phrase $patterns[18]).linenumber      
        $reply          =       ($results[($_pos_+1)])             
        if([string]$reply -match "on" )    {$status  +="COMPLIANT"}else{$status+="NON-COMPLIANT ($($reply))"};$status+=$CR   

        #2.1.2 set message motd
        #Ensure 'Message Of The Day (MOTD)' is set
        $_pos_          =       (Find-Phrase -FilePath $filelocation -Phrase $patterns[19]).linenumber    
        $reply          =       ($results[($_pos_)])             
        if([string]$reply -match "off" )    {$status  +="COMPLIANT"}else{$status+="NON-COMPLIANT ($($reply))"};$status+=$CR  

        #2.1.3 show core-dump status
        #Ensure Core Dump is enabled
        $_pos_          =       (Find-Phrase -FilePath $filelocation -Phrase $patterns[20]).linenumber     
        $reply          =       ($results[($_pos_[0]+1)])             
        if([string]$reply -match "enabled" )    {$status  +="COMPLIANT"}else{$status+="NON-COMPLIANT ($($reply))"};$status+=$CR   
        
        #2.1.4 show config-state
        #Ensure Config-state is saved
        $_pos_          =       (Find-Phrase -FilePath $filelocation -Phrase $patterns[21]).linenumber     
        $reply          =       ($results[($_pos_[0]+1)])             
        if([string]$reply -match "saved" )    {$status  +="COMPLIANT"}else{$status+="NON-COMPLIANT "};$status+=$CR   
        
        #2.1.5 show interfaces
        #Ensure unused interfaces are disabled
        $reply          =       Get-InterfaceStatus -FilePath $filelocation
        if((($reply | where-Object {$_.IsUp -eq $false}).count) -gt 0){$status  +="NON-COMPLIANT"}else{$status  +="COMPLIANT"};$status+=$CR   

        #2.1.6 show dns 
        #Ensure DNS server is configured
        $_pos_          =       (Find-Phrase -FilePath $filelocation -Phrase "DNS server").linenumber
        $dns=$null;foreach ($pos in $_pos_) {$dns+=((($results[$pos]) -split "DNS Server")[-1]).trim()} 
        if ($dns){$status  +="COMPLIANT"}else{$status  +="NON-COMPLIANT"};$status+=$CR 

        #2.1.7 show ipv6-state
        #Ensure IPv6 is disabled if not used
        $_pos_          =       (Find-Phrase -FilePath $filelocation -Phrase $patterns[40]).linenumber     
        $reply          =       ($results[($_pos_+1)])             
        if([string]$reply -match "Disabled" )    {$status  +="COMPLIANT"}else{$status+="NON-COMPLIANT ($($reply))"};$status+=$CR  

        #2.1.8  show hostname
        #Ensure Host Name is set
        if ($hostname) {$status  +="COMPLIANT"}else{$status+="NON-COMPLIANT"};$status+=$CR  

        #2.1.9 show net-access telnet
        # Ensure Telnet is disabled
        $_pos_          =       (Find-Phrase -FilePath $filelocation -Phrase $patterns[41]).linenumber     
        $reply          =       ($results[($_pos_+1)])             
        if([string]$reply -match "off" )    {$status  +="COMPLIANT"}else{$status+="NON-COMPLIANT ($($reply))"};$status+=$CR   

        #2.1.10 show dhcp server status
        #Ensure DHCP is disabled
        $_pos_          =       (Find-Phrase -FilePath $filelocation -Phrase $patterns[42]).linenumber     
        $reply          =       ($results[($_pos_[-1]+1)])             
        if([string]$reply -match "disabled" )    {$status  +="COMPLIANT"}else{$status+="NON-COMPLIANT ($($reply))"};$status+=$CR   
     
        #2.2.1 show snmp agent
        #Ensure SNMP agent is disabled
        $_pos_          =       (Find-Phrase -FilePath $filelocation -Phrase $patterns[22]).linenumber     
        $reply          =       ($results[($_pos_[0]+1)[-1]] -split " ")[-1]         
        if([string]$reply -match "disabled" )    {$status  +="COMPLIANT"}else{$status+="NON-COMPLIANT ($($reply))"};$status+=$CR   
  
        #2.2.2 show snmp agent-version
        #Ensure SNMP version is set to v3-Only
        $_pos_          =       (Find-Phrase -FilePath $filelocation -Phrase $patterns[23]).linenumber     
        $reply          =       ($results[($_pos_+1)])             
        if([string]$reply -match "v3-Only" )    {$status  +="COMPLIANT"}else{$status+="NON-COMPLIANT ($($reply))"};$status+=$CR 

        #2.2.3 show snmp traps enabled-traps             
        #Ensure SNMP traps is enabled
        $_pos_          =       (Find-Phrase -FilePath $filelocation -Phrase $patterns[24]).linenumber     
        $enabledTraps = @()
        for ($i = ($_pos_+1); $i -lt $results.Count; $i++) {if ( $results[$i+1] -match '^show ') {break};$enabledTraps +=$results[$i].Trim()}
        if ($enabledTraps)  {$status  +="COMPLIANT";$status+=$CR }else{$status+="NON-COMPLIANT"}

        #2.2.4 show snmp traps receivers
        #Ensure SNMP traps receivers is set
        $_pos_          =       (Find-Phrase -FilePath $filelocation -Phrase $patterns[30]).linenumber     
        $reply          =       ($results[($_pos_+1)])   
        if([string]$reply -notmatch "No" )    {$status  +="COMPLIANT"}else{$status+="NON-COMPLIANT ($($reply))"};$status+=$CR 

        #2.3.1 show ntp active
        #Ensure NTP is enabled and IP address is set for Primary and Secondary NTP server
        $_pos_          =       (Find-Phrase -FilePath $filelocation -Phrase $patterns[46]).linenumber     
        $reply          =       ($results[($_pos_[0]+1)])   
        if([string]$reply -match "Yes" )    {$status  +="COMPLIANT"}else{$status+="NON-COMPLIANT ($($reply))"};$status+=$CR 

        #2.3.2 Ensure timezone is properly configured
        #show timezone
        $_pos_          =       (Find-Phrase -FilePath $filelocation -Phrase $patterns[29]).linenumber     
        $reply          =       ($results[($_pos_+1)])   
        if([string]$reply -match "Europe/London" )    {$status  +="COMPLIANT"}else{$status+="NON-COMPLIANT ($($reply))"};$status+=$CR 

        #2.4.1 show backup last-successful
        #Ensure 'System Backup' is set. (Automated)
        $_pos_          =       (Find-Phrase -FilePath $filelocation -Phrase $patterns[28]).linenumber    
        $backupstats    =       @()
        for ($i = ($_pos_+1); $i -lt $results.Count; $i++) {if ( $results[$i+1] -match '^show ') {break};$backupstats +=$results[$i].Trim()}
        $backupstats    =       $backupstats -split "`n" | Where-Object { $_.Trim() -ne "" } 
        if ($backupstats.count -gt 0)  {$status  +="COMPLIANT";$status+=$CR }else{$status+="NON-COMPLIANT"}

        #2.4.2 show snapshots
        #Ensure 'Snapshot' is set
        $_pos_          =       (Find-Phrase -FilePath $filelocation -Phrase $patterns[45]).linenumber
        $snapshots      =       @()
        for ($i = ($_pos_+1); $i -lt $results.Count; $i++) {if ( $results[$i+1] -match '^show ') {break};$snapshots +=$results[$i].Trim()}
        $snapshots      =       $snapshots -split $CR | Where-Object { $_.Trim() -ne "" } 
        if ($snapshots.count -gt 2)  {$status  +="COMPLIANT";}else{$status+="NON-COMPLIANT"};$status+=$CR

        #2.4.3 
        #Configuring Scheduled Backups
        $_pos_          =       (Find-Phrase -FilePath $filelocation -Phrase $patterns[50]).linenumber
        if([int]$_pos_ -eq 0){$status+="Check Restorepoint";$status+=$CR}
            
        #2.5.1 show inactivity-timeout
        #Ensure CLI session timeout is set to less than or equal to 10 minutes
        $_pos_          =       (Find-Phrase -FilePath $filelocation -Phrase $patterns[25]).linenumber    
        $reply          =       ($results[($_pos_+1)] -split " ")[-1]      
        if([int]$reply -le 10 )    {$status  +="COMPLIANT"}else{$status+="NON-COMPLIANT  ($($reply))"};$status+=$CR  

        #2.5.2 show web session-timeout
        #Ensure Web session timeout is set to less than or equal to 10 minutes
        $_pos_          =       (Find-Phrase -FilePath $filelocation -Phrase $patterns[26]).linenumber    
        $reply          =       ($results[($_pos_+1)] -split " ")[-1]      
        if([int]$reply -le 10 )    {$status  +="COMPLIANT"}else{$status+="NON-COMPLIANT"};$status+=$CR 
        
        #2.5.3 
        #Ensure Client Authentication is secured.
        $dollar         =      [char]36 
        $status         +=      "Check '$($dollar)FWDIR/conf/fwauthd.conf'";$status+=$CR 

        #2.5.4 show aaa tacacs-servers state
        #Ensure Radius or TACACS+ server is configured
        $_pos_          =       (Find-Phrase -FilePath $filelocation -Phrase $patterns[31]).linenumber    
        $reply          =       ($results[($_pos_+1)])             
        if([string]$reply -match "off" )    {$status  +="COMPLIANT"}else{$status+="NON-COMPLIANT"};$status+=$CR   

        #2.5.5 show allowed-client all 
        #Ensure allowed-client is set to those necessary for device management
        $_pos_          =       (Find-Phrase -FilePath $filelocation -Phrase $patterns[33]).linenumber    
        $allowedclients =       @()
        for ($i = ($_pos_+1); $i -lt $results.Count; $i++) {if ( $results[$i+1] -match '^show ') {break};$allowedclients +=$results[$i].Trim()}
        $allowedclients =       $allowedclients -split $CR | Where-Object { $_.Trim() -ne "" } 
        $dataLines      =       $allowedclients | Select-Object -Skip 1
        $clients        =       foreach ($line in $dataLines) {$parts = $line -split '\s{2,}';[PSCustomObject]@{Type  = $parts[0];Address = $parts[1];MaskLength = if ($parts.Count -gt 2) { $parts[2] } else { "N/A" }}}
        if ($clients |  Where-Object { $_.Type -eq 'Host' -and $_.Address -eq 'Any' }) {$status  +="NON-COMPLIANT (Host/Any Located)"}else{$status+="COMPLIANT"};$status+=$CR
             
        #2.6.1 show syslog mgmtauditlogs
        #Ensure mgmtauditlogs is set to on
        $_pos_          =       (Find-Phrase -FilePath $filelocation -Phrase $patterns[47]).linenumber   
        $reply          =       ($results[($_pos_+1)] -split " ")[-1]    
        if([string]$reply -match "enabled"){$status  +="COMPLIANT"}else{$status+="NON-COMPLIANT  ($($reply))"};$status+=$CR  

        #2.6.2 show syslog auditlog
        #Ensure auditlog is set to permanent
        $_pos_          =       (Find-Phrase -FilePath $filelocation -Phrase $patterns[48]).linenumber   
        $reply          =       ($results[($_pos_[0]+1)] -split " ")[-1]    
        if([string]$reply -match "permanent"){$status  +="COMPLIANT"}else{$status+="NON-COMPLIANT  ($($reply))"};$status+=$CR  

        #2.6.3 show syslog cplogs
        #Ensure cplogs is set to on
        $_pos_          =       (Find-Phrase -FilePath $filelocation -Phrase $patterns[49]).linenumber   
        $reply          =       ($results[($_pos_+1)] -split " ")[-1]    
        if([string]$reply -notmatch "disabled"){$status  +="COMPLIANT"}else{$status+="NON-COMPLIANT ($($reply))"};$status+=$CR  

        for($i=1;$i -le 20;$i++){$status+="Manual Action $($CR)"}
        $formattedstatus=       @()
        $status         =       $status -split "`n" | ForEach-Object {$line = $_.Trim();if ($line -ne "") {$formattedstatus+=$line}}
        $status         =       $formattedstatus

        $results        = @()
        $counter=0

        foreach ($line in $display)
        {       
                if ($line.level -gt 0){$results +=      "$($line.num),$($line.control),$($line.level),$($status[$counter]) $($CR)";$counter++}
                else
                {$results +=    "$($line.num),$($line.control),$($line.level)$($CR)"}
        }

        $data   =       [PSCustomObject]@{hostname = $hostname;serialnumber = $serialnumber;results = $results}
        return  $data
}

function process_the_data
{
        param ([string]$filelocation,[int]$_tab_)
        write-host "Input << $($PWD)\$($filelocation)"         
        $stopwatch  = [System.Diagnostics.Stopwatch]::StartNew()
        ####################################################
        $stopwatch.Start()
        $output         =       ProcessData $filelocation
        $results        =       ($output.results).trim()
        $delta          =       (($stopwatch.Elapsed.TotalSeconds).ToString('F2'));$stopwatch.Reset()
        write-host      -f green "Processed Fortigate CIS Benchmarking in $($delta) secs"
        #####################################################
        $stopwatch.Start()
        $xlsxoutput     =       txt2excel $output.hostname $output.serialnumber $results
        $delta          =       (($stopwatch.Elapsed.TotalSeconds).ToString('F2'));$stopwatch.Reset()
        write-host      -f green "Processed $($output.hostname) in $($delta) secs"
        write-host ""
}

#MAIN LOOP
cls
$_tab_          =       $false
$_exop_         =       $false
if ($args.count -gt 0){
        for ($i=0;$i -lt $args.count;$i++){
                if ($args[$i] -eq "-tab"){$_tab_=$True}
                if ($args[$i] -eq "-exop"){$_exop_=$True}
        }
}

$txtsrc         =   Get-ChildItem -Path "$PWD" -Filter *.txt | Where-Object {$_.Name -notlike "_*"} | Select-Object -ExpandProperty Name
$_fc_           =   $txtsrc.count
write-host      -b DarkYellow -f black "                                          "
write-host      -b DarkYellow -f black " Checkpoint Conversion Script             "
Write-host      -b DarkYellow -f black " CIS Benchmarking                         "
write-host      -b DarkYellow -f black " Version 0.b1 [MAJ/RO/SS/PC]              "    
write-host      -b DarkYellow -f black "                                          "
$requiredFiles = @("$PWD\_benchmarking.csv","$PWD\_commands.txt    ")

$allExist = $true
foreach ($file in $requiredFiles) {if (-not (Does-FileExists $file)) {$allExist = $false}}
if (!$allExist){Write-CritialError  -b red -f white  "      CONFIGURATION FILES MISSING!      " ;break}  

if (!$txtsrc){Write-CritialError  -b red -f   white  "            NO FILES FOUND!             " ;break}        
$textsrc        =       "$($PWD)\$($txtsrc)"   ;write-host  

write-host      -f green "$($txtsrc.count) Text files located in $($PWD)"
if ($txtsrc.count -eq 1){process_the_data $txtsrc  }
if ($txtsrc.count -gt 1){$counter=0;do{process_the_data $txtsrc[$counter] ;$counter++}Until ($counter -ge $txtsrc.Count)}
