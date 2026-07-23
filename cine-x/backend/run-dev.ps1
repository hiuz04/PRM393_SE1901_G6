$ErrorActionPreference = "Stop"

$javaHome = "C:\Program Files\Java\jdk-21"
if (Test-Path $javaHome) {
    $env:JAVA_HOME = $javaHome
    $env:Path = "$env:JAVA_HOME\bin;$env:Path"
}

$mavenCandidates = @(
    "$env:USERPROFILE\.m2\wrapper\dists\apache-maven-3.9.16-bin\5grr65jo27hi51sujmtcldfovl\apache-maven-3.9.16\bin\mvn.cmd",
    "$env:USERPROFILE\.m2\wrapper\dists\apache-maven-3.9.15-bin\*\apache-maven-3.9.15\bin\mvn.cmd",
    "$env:USERPROFILE\.m2\wrapper\dists\apache-maven-3.9.14-bin\*\apache-maven-3.9.14\bin\mvn.cmd",
    "$env:USERPROFILE\.m2\wrapper\dists\apache-maven-3.9.12-bin\*\apache-maven-3.9.12\bin\mvn.cmd",
    "$env:USERPROFILE\.m2\wrapper\dists\apache-maven-3.8.6-bin\*\apache-maven-3.8.6\bin\mvn.cmd"
)

$maven = $null
foreach ($candidate in $mavenCandidates) {
    $match = Get-ChildItem -Path $candidate -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($match) {
        $maven = $match.FullName
        break
    }
}

if (-not $maven) {
    $pathMaven = Get-Command mvn -ErrorAction SilentlyContinue
    if ($pathMaven) {
        $maven = $pathMaven.Source
    }
}

if (-not $maven) {
    throw "Maven was not found. Install Maven or run 'flutter pub get' and backend build from an environment that has Maven."
}

Write-Host "Using Maven: $maven"
Write-Host "Using JAVA_HOME: $env:JAVA_HOME"
& $maven spring-boot:run
