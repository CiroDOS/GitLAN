[CmdletBinding()]
param (
    [switch]$push,
    [string]$o,
    [switch]$status,
    [switch]$commit,
    [switch]$a,
    [string]$m,
    [string]$clone,
    [string]$branch,
    [string]$add
)

if ($clone) {
    #  $SERVER = $clone.Split("\")[2]
    #  $USER = $clone.Split("\")[3]
    $REPO = $clone.Split("\")[4]

    Write-Host "Clonning Files..."

    $repoPath = $PWD.Path + "\$REPO"

    if (Test-Path -Path $repoPath) {
        Write-Error "The path already exists"
        exit
    }
    
    New-Item -ItemType Directory -Path $repoPath > $null

    $linkFile = "<repository>
    <name>$REPO</name>
    <location>$repoPath</location>
    <link-file>$repoPath\.sgit\link.xml</link-file>
    <sgit-folder>$repoPath\.sgit</sgit-folder>
    <server-location>$clone</server-location>
</repository>"

    Write-Host "Creating git files & utilities...`n"

    New-Item -ItemType Directory -Path "$repoPath\.sgit" > $null
    (Get-Item "$repoPath\.sgit").Attributes = "Directory,Hidden" # Hide the sgit folder

    Set-Content -Value $linkFile -Path "$repoPath\.sgit\link.xml" > $null

    New-Item -ItemType Directory -Path "$repoPath\.sgit\commands\" > $null

    Set-Content -Value "@ECHO OFF
Set /p branch_name=`"Branch name: `"
mkdir ..\..\%branch_name%" -Path "$repoPath\.sgit\commands\generate_new_branch.bat"

    Write-Host "Downloading resources..."

    $Files = [string] (C:\Windows\System32\cmd.exe /c "dir $clone\tree /a-d /b /s")
    $branchs = [string] (C:\Windows\System32\cmd /c "dir $clone\tree /ad /b")

    $latestCommit = @()
    ForEach ($branch in $branchs) {
        $latestCommit += [string] (Get-Content -Path "$clone\tree\$branch\latest.dat")
        New-Item -ItemType Directory -Path "$repoPath\$branch" > $null
        Write-Host "    Downloading branch contents: $branch; [===100%===]"
    }

    Write-Host "`nReady to copy files!"

    ForEach ($File in ($Files.Split(" "))) {
        
        $gitignore = (Invoke-Expression -Command "$SGIT_FOLDER\gitignore.ps1 -File $File") -eq "1"

        if ($gitignore -ne $True) {
            ForEach ($branch in $branchs) {
                ForEach ($latcommit in $latestCommit) {
                    if (($File -like "*$branch*") -and ($File -like ("*$latcommit*"))) {   
                        Copy-Item -Path $File -Destination "$repoPath\$branch" > $null
                        Write-Host "    Copying file: $File; [===100%===]"
                    }
                }
            }
        }
    }

    Write-Host "`nFinished!"

    exit
}

if ($branch) {
    if ($branch -eq "--list") {
        $branchs = [string] (C:\Windows\System32\cmd /c "dir $REPOSITORY_HOME /ad /b")
        
        ForEach ($branch_e in $branchs.Split(" ")) {
            if ($branch_e -ne ".sgit") {
                if ($PWD.Path -like "*$branch_e*") {
                    Write-Host ("     * " + $branch_e.ToLower())
                }
                else {
                    Write-Host ("     " + $branch_e.ToLower())
                }
            }
        }
        
    }
        else
    {
        Set-Location $REPOSITORY_HOME\$branch
    }
    exit
}

if ($status) {
    $gitignorePath = [string] ([xml] (Get-Content -Path "$REPOSITORY_HOME\.sgit\link.xml")).repository."server-location" + "\gitignore.ps1"

    $TreeViewCommand = @("dir", "/a-d /b /s")
    $TreeFiles = [string] (C:\Windows\System32\cmd.exe /c ($TreeViewCommand[0] + " $REPOSITORY_HOME " + $TreeViewCommand[1]))
    $OriginTreeFiles = [string] (C:\Windows\System32\cmd.exe /c ($TreeViewCommand[0] + " " + [string] ([xml] (Get-Content -Path "$REPOSITORY_HOME\.sgit\link.xml")).repository."server-location" + "\tree " + $TreeViewCommand[1]))

    $TreeFilesArray = @()
    $OriginTreeFilesArray = @()

    ForEach ($File in ($TreeFiles.Split(" "))) {
        $gitignore = (Invoke-Expression -Command "$gitignorePath -File $File") -eq "1"

        if ($gitignore -ne $True) {
            $TreeFilesArray += $File
        }
    }

    ForEach ($File in ($OriginTreeFiles.Split(" "))) {
        $gitignore = ([string](Invoke-Expression -Command "$gitignorePath -File $File")) -eq "1" 

        if ($gitignore -ne $True) {
            $OriginTreeFilesArray += $File
        }
    }

    $DiferentFiles = @()
    for ($i = 0; $i -lt $TreeFilesArray.Count; $i++) {
        if ((Get-FileHash -Algorithm SHA512 -Path $TreeFilesArray[$i]).Hash -ne (Get-FileHash -Algorithm SHA512 -Path $OriginTreeFilesArray[$i]).Hash) {
            $DiferentFiles += $TreeFilesArray[$i]
        }
    }

    
    Write-Host "    You can update these files with: git push -o <origin>"
    ForEach ($DiferentFile in $DiferentFiles) {
        Write-Host "        - $DiferentFile"
    }
    
    exit
}

if ($push) {
    if ($o) {
        $DestinationPath = [string] ([xml] (Get-Content -Path "$REPOSITORY_HOME\.sgit\link.xml")."server-location") + "\requests"
        Compress-Archive -Path "$REPOSITORY_HOME\$o" -CompressionLevel Optimal -DestinationPath $DestinationPath 
    }
    else {
        Write-Error "No arguments entered"
    }
}