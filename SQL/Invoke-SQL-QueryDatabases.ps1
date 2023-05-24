$SqlServers = 'x.database.windows.net', 'y.database.windows.net', 'z.database.windows.net'
$SqlAuthLogin = 'username'            # SQL Authentication login
$SqlAuthPw = 'password'     # SQL Authentication login password
$Query = "SELECT name FROM sys.databases WHERE name NOT IN ('master', 'tempdb', 'model', 'msdb')" # Get all relevant databases on the SQL server

# Loop through each sql server 
foreach ($SqlServer in $SqlServers) {
    # Switch statement to swap username for each sql server
    switch ($SqlServer) {
        'x.database.windows.net' { $SqlAuthLogin = 'Username for x' }
        'y.database.windows.net' { $SqlAuthLogin = 'Username for y' }
        'z.database.windows.net' { $SqlAuthLogin = 'Username for z' }
    }
    # Switch statement to swap password for each sql server
    switch ($SqlServer) {
        'x.database.windows.net' { $SqlAuthPw = 'Password for x' }
        'y.database.windows.net' { $SqlAuthPw = 'Password for y' }
        'z.database.windows.net' { $SqlAuthPw = 'Password for z' }
    }

    Write-Host $SqlServer "databases" -ForegroundColor Green

    $databases = Invoke-Sqlcmd  -ConnectionString "Data Source=$SqlServer; User Id=$SqlAuthLogin; Password =$SqlAuthPw" -Query "$Query"

    # Loop through each database and perform the SELECT statement
    foreach ($db in $databases) {
        $dbName = $db.name

        # Create a new connection string for the specific database
        $dbConnectionString = "Server=$SqlServer;Database=$dbName;User ID=$SqlAuthLogin;Password=$SqlAuthPw;Encrypt=True;TrustServerCertificate=False;Connection Timeout=30;"

        # Perform the SELECT statement
        $results = Invoke-SqlCmd -ConnectionString $dbConnectionString -Query "SELECT * FROM TABLE WHERE COLUMN = 'whatever'"

        # Output the results
        $results
        Write-Host ""
    }
}

