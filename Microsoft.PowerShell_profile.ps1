<# Optimized PowerShell Profile Script #>

# Define Profile Version and URL
$pwshProfile = '3.2.1-dev'
$pwshProfileUrl = "https://api.github.com/repos/smoonlee/oh-my-posh-profile/releases"

# Profile Update Checker
$cachePath = "$env:LOCALAPPDATA\PSProfile\releases.json"
if (Test-Path $cachePath) {
    if ((Get-Date) -lt (Get-Item $cachePath).LastWriteTime.AddDays(1)) {
        $releases = Get-Content $cachePath | ConvertFrom-Json
    }
    else {
        $releases = Invoke-RestMethod -Method 'Get' -Uri $pwshProfileUrl -ErrorAction SilentlyContinue
        if ($releases) {
            $releases | ConvertTo-Json -Depth 10 | Set-Content $cachePath
        }
    }
}
else {
    $releases = Invoke-RestMethod -Method 'Get' -Uri $pwshProfileUrl -ErrorAction SilentlyContinue
    if ($releases) {
        New-Item -ItemType File -Path $cachePath -Force | Out-Null
        $releases | ConvertTo-Json -Depth 10 | Set-Content $cachePath
    }
}


$latestReleaseTag = ($releases | Where-Object { -not $_.prerelease } | Select-Object -First 1).tag_name
if ($pwshProfile -ne $latestReleaseTag) {
    Write-Warning "[Oh My Posh] - Profile Update Available, Please run: Update-PSProfile"
}

# Import PowerShell Modules (Only if not already loaded)
$modules = @('Posh-Git', 'Terminal-Icons', 'PSReadLine')
forEach ($module in $modules) {
    Import-Module -Name $module -ErrorAction SilentlyContinue
}

# PSReadLine Configuration
Set-PSReadLineOption -EditMode 'Windows'
Set-PSReadLineOption -PredictionSource 'History'
Set-PSReadLineOption -PredictionViewStyle 'ListView'
Set-PSReadLineOption -HistoryNoDuplicates:$True
Set-PSReadLineOption -HistorySearchCursorMovesToEnd
Set-PSReadLineKeyHandler -Key 'Tab' -Function 'MenuComplete'
Set-PSReadLineKeyHandler -Key 'UpArrow' -Function 'HistorySearchBackward'
Set-PSReadLineKeyHandler -Key 'DownArrow' -Function 'HistorySearchForward'

# Oh My Posh Configuration (Check if theme file exists)
$themePath = "$env:POSH_THEMES_PATH\quick-term-cloud.omp.json"
if (Test-Path $themePath) {
    oh-my-posh init powershell --config $themePath | Invoke-Expression
}

# Local Oh-My-Posh Configuration
$env:POSH_AZURE_ENABLED = $true
$env:POSH_GIT_ENABLED = $true

#
# PowerShell Functions
####

# Function - Azure CLI Tab Completion
# Microsoft Docs - https://learn.microsoft.com/en-us/cli/azure/install-azure-cli-windows?tabs=azure-cli&pivots=winget#enable-tab-completion-in-powershell
Register-ArgumentCompleter -Native -CommandName az -ScriptBlock {
    param($commandName, $wordToComplete, $cursorPosition)
    $completion_file = New-TemporaryFile
    $env:ARGCOMPLETE_USE_TEMPFILES = 1
    $env:_ARGCOMPLETE_STDOUT_FILENAME = $completion_file
    $env:COMP_LINE = $wordToComplete
    $env:COMP_POINT = $cursorPosition
    $env:_ARGCOMPLETE = 1
    $env:_ARGCOMPLETE_SUPPRESS_SPACE = 0
    $env:_ARGCOMPLETE_IFS = "`n"
    $env:_ARGCOMPLETE_SHELL = 'powershell'
    az 2>&1 | Out-Null
    Get-Content $completion_file | Sort-Object | ForEach-Object {
        [System.Management.Automation.CompletionResult]::new($_, $_, "ParameterValue", $_)
    }
    Remove-Item $completion_file, Env:\_ARGCOMPLETE_STDOUT_FILENAME, Env:\ARGCOMPLETE_USE_TEMPFILES, Env:\COMP_LINE, Env:\COMP_POINT, Env:\_ARGCOMPLETE, Env:\_ARGCOMPLETE_SUPPRESS_SPACE, Env:\_ARGCOMPLETE_IFS, Env:\_ARGCOMPLETE_SHELL
}

# Function - Reload PowerShell Session, Keeping Windows Terminal running.
function Register-PSProfile {
    Clear-Host
    # https://stackoverflow.com/questions/11546069/refreshing-restarting-powershell-session-w-out-exiting
    Get-Process -Id $PID | Select-Object -ExpandProperty Path | ForEach-Object { Invoke-Command { & "$_" } -NoNewScope }
}

# Function - Get PowerShell Profile Theme
function Get-PSProfileTheme {
    if ($null -eq $env:POSH_THEME) {
        Write-Output "No theme set in POSH_THEME."
        return
    }

    $themePath = Split-Path -Parent $env:POSH_THEME
    $themeFile = Split-Path -Leaf $env:POSH_THEME
    $themeLink = "`e]8;;$themePath`e\$themeFile`e]8;;`e\"

    Write-Output `r "Current Theme: $themeLink"
}

# Function - Get PowerShell Profile Version Information
function Get-PSProfileVersion {
    $stableRelease = $releases | Where-Object { -not $_.prerelease } | Select-Object -First 1 -Property tag_name
    $devRelease = $releases | Where-Object { $_.prerelease } | Select-Object -First 1 -Property tag_name

    $currentThemeName = Split-Path -Leaf $env:POSH_THEME
    Write-Output `r "Current Theme...............: $currentThemeName"
    Write-Output "Current Profile Version.....: $pwshProfile`n"

    if ($stableRelease) {
        Write-Output "Latest Stable Release.......: $($stableRelease.tag_name)"
    }
    else {
        Write-Output "Latest Stable Release.......: Not available"
    }

    if ($devRelease) {
        Write-Output "Latest Dev Release..........: $($devRelease.tag_name)"
    }
    else {
        Write-Output "Latest Dev Release..........: Not available"
    }
}

# Function - Update PowerShell Profile (OTA)
function Update-PSProfile {
    param (
        [switch] $devRelease
    )

    Set-StrictMode -Version Latest

    # Select latest stable and dev releases
    $stableRelease = $releases | Where-Object { -not $_.prerelease } | Select-Object -First 1
    $devReleaseObj = $releases | Where-Object { $_.prerelease } | Select-Object -First 1

    # Ensure variables exist to prevent errors
    if (-not $stableRelease) { Write-Warning "No stable releases found."; return }
    if ($devRelease -and -not $devReleaseObj) { Write-Warning "No development releases found."; return }

    # Extract values
    $release = if ($devRelease) {
        Write-Warning "--- Using Development Release ---"
        $devReleaseObj
    }
    else {
        $stableRelease
    }

    $releaseTag = $release.tag_name
    $releaseNotes = $release.body
    $releaseUrl = $release.assets.browser_download_url

    # Get current theme
    $currentThemeName = $env:POSH_THEME | Split-Path -Leaf
    Write-Output "Current Theme.........: $currentThemeName"
    Write-Output "Profile Version.......: $releaseTag"

    # Display Patch Notes
    Write-Output `r "Profile Patch Notes:"
    Write-Output $releaseNotes

    Start-Sleep -Seconds 4

    # Download new profile
    try {
        Invoke-WebRequest -Uri $releaseUrl -OutFile $PROFILE -ErrorAction Stop
    }
    catch {
        Write-Error "Failed to download profile: $_"
        return
    }

    # Update theme reference
    (Get-Content -Path $PROFILE -Raw) -replace '(\\[^"]+\.omp\.json)', "\$currentThemeName" |
    Set-Content -Path $PROFILE

    # Reload profile
    Register-PSProfile
}

# Function - Update WinGet Applications
function Update-WindowsApps {
    if (-not ([Security.Principal.WindSowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltinRole] "Administrator")) {
        Write-Warning "This function must be run as an administrator."
        return
    }

    Write-Output `r "Updating Windows Applications..." `r
    winget upgrade --include-unknown --all --silent --force
}

# Function - Get Public IP Address
function Get-MyPublicIP {
    try {
        $ipInfo = Invoke-RestMethod -Method 'Get' -Uri 'https://ipinfo.io' -TimeoutSec 5

        if ($ipInfo -and $ipInfo.ip) {
            [PSCustomObject]@{
                'Public IP' = $ipInfo.ip
                'Host Name' = $ipInfo.hostname
                'ISP'       = $ipInfo.org
                'City'      = $ipInfo.city
                'Region'    = $ipInfo.region
                'Country'   = $ipInfo.country
            }
        }
        else {
            Write-Warning "Received an unexpected response from $ApiUrl"
        }
    }
    catch [System.Net.WebException] {
        Write-Warning "Network error: $_"
    }
    catch {
        Write-Warning "Failed to retrieve public IP information: $_"
    }
}

# Function - Get System Uptime
function Get-SystemUptime {

    # Function to convert uptime seconds into a readable format
    function ConvertTo-ReadableTime {
        param (
            [int]$Seconds
        )
        $uptime = New-TimeSpan -Seconds $Seconds
        return "{0} days, {1} hours, {2} minutes, {3} seconds" -f $uptime.Days, $uptime.Hours, $uptime.Minutes, $uptime.Seconds
    }

    # Get system details
    $os = Get-CimInstance Win32_OperatingSystem
    $uptimeSpan = New-TimeSpan -Start $os.LastBootUpTime -End (Get-Date)

    # Create and return an object for structured output
    [PSCustomObject]@{
        Hostname       = [System.Net.Dns]::GetHostName()
        Uptime         = ConvertTo-ReadableTime -Seconds $uptimeSpan.TotalSeconds
        LastRebootTime = $os.LastBootUpTime.ToString("yyyy-MM-dd HH:mm:ss")
    } | Format-List
}

# Function - Get Azure Virtual Machine System Uptime
function Get-AzSystemUptime {
    param (
        [string]$subscriptionId,
        [string]$resourceGroup,
        [string]$vmName
    )

    # Check and set subscription context
    $currentSub = az account show --query id -o tsv
    if ($subscriptionId -and ($currentSub -ne $subscriptionId)) {
        az account set --subscription $subscriptionId | Out-Null
        $subFriendlyName = az account show --query name -o tsv
        Write-Output "[Azure] :: Using Azure Subscription: $subFriendlyName"
    }

    # Get VM OS type
    $osType = az vm show --resource-group $resourceGroup --name $vmName --query "storageProfile.osDisk.osType" -o tsv
    Write-Output "[Azure] :: Fetching System Uptime for $vmName in $resourceGroup..."

    if ($osType -eq "Windows") {
        $response = az vm run-command invoke `
            --resource-group $resourceGroup `
            --name $vmName `
            --command-id "RunPowerShellScript" `
            --scripts @'
$uptime = New-TimeSpan -Start (Get-CimInstance Win32_OperatingSystem).LastBootUpTime
Write-Output "[Azure] :: Hostname: $env:COMPUTERNAME"
Write-Output "[Azure] :: Uptime: $($uptime.Days) days, $($uptime.Hours) hours, $($uptime.Minutes) minutes, $($uptime.Seconds) seconds"
Write-Output "[Azure] :: Last Reboot Time: $((Get-CimInstance Win32_OperatingSystem).LastBootUpTime.ToString('dd/MM/yyyy HH:mm:ss'))"
'@ `
            --query "value[0].message" -o tsv

        return $response
    }
    elseif ($osType -eq "Linux") {
        $response = az vm run-command invoke `
            --resource-group $resourceGroup `
            --name $vmName `
            --command-id "RunShellScript" `
            --scripts @'
echo "[Azure] :: Hostname: $(hostname)"
echo "[Azure] :: Uptime: $(uptime -p)"
echo "[Azure] :: Last Reboot Time: $(uptime -s)"
'@ `
            --query "value[0].message" -o tsv

        return $response.Trim()
    }
    else {
        Write-Warning "[Azure] :: Unsupported OS Type: $osType"
    }
}

# Function - Clean Git Branches
function Remove-GitBranch {
    param (
        [string] $defaultBranch,
        [string] $branchName,
        [switch] $all
    )

    # Get all local branches excluding the active branch
    $allBranches = git branch --format="%(refname:short)" | Where-Object { $_ -notmatch '^(master|main|prod|dev-main)$' }

    # Handle case where there are no branches to clean
    if (-not $allBranches) {
        $defaultBranchName = (git symbolic-ref refs/remotes/origin/HEAD | ForEach-Object { $_ -replace 'refs/remotes/origin/', '' }).Trim()
        Write-Output "Default Branch: $defaultBranchName"
        Write-Warning "No additional branches found"
        return
    }

    if ($all) {
        Write-Warning "This will remove ALL local branches in the repository!"
        Write-Output 'Press any key to continue...'
        $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')

        # Checkout to the default branch
        Write-Output "[Git] :: Switching to default branch"
        git checkout $defaultBranch -q 2>$null

        # Delete all branches in one command for efficiency
        Write-Output "[Git] :: Cleaning up branches"
        git branch -D $allBranches -q 2>$null
    }
    elseif ($branchName) {
        # Delete the specified branch
        try {
            git branch -D $branchName -q 2>$null
        }
        catch {
            Write-Warning "Failed to delete branch $branchName"
        }
    }
}

# Function - Get DNS Record Information
function Get-DnsResult {
    param (
        [Parameter(Mandatory = $true)]
        [ValidateSet(
            'A', 'A_AAAA', 'AAAA', 'AFSDB', 'ANY', 'CNAME', 'DHCID', 'DNSKEY', 'DS', 'DNAME', 'HINFO', 'ISDN',
            'MD', 'MF', 'MINFO', 'MX', 'MR', 'NSEC', 'NSEC3', 'NSEC3PARAM', 'NULL', 'OPT', 'PTR', 'RP', 'RRSIG',
            'SRV', 'SOA', 'TXT', 'WINS', 'WKS', 'X25', 'NS', 'RT', 'UNKNOWN', 'MB', 'MG', 'MR'
        )]
        [string]$recordType,

        [Parameter(Mandatory = $true)]
        [string]$domain
    )

    try {
        # Resolving the DNS record with a custom timeout
        $result = Resolve-DnsName -Name $domain -Type $recordType

        if ($result) {
            # Returning results in a structured way
            return $result
        }
        else {
            Write-Warning "No DNS record found for $domain with type $recordType."
        }
    }
    catch {
        Write-Error "Failed to resolve DNS for domain $domain. Error: $_"
    }
}

# Function - Get Azure Kubernetes Service Version
function Get-AksVersion {
    param (
        [Parameter(Mandatory = $false)]
        [ValidateSet(
            "australiacentral", "australiacentral2", "australiaeast", "australiasoutheast", "brazilsouth", "brazilsoutheast",
            "canadacentral", "canadaeast", "canadawest", "centralindia", "centralus", "centraluseuap", "eastasia", "eastus",
            "eastus2", "eastus3", "eastus2euap", "francecentral", "francesouth", "germanynorth", "germanywestcentral",
            "indiawest", "japaneast", "japanwest", "koreacentral", "koreasouth", "northeurope", "northindia", "norwayeast",
            "norwaywest", "saopaulo", "southafricanorth", "southafricawest", "southindia", "southeastasia", "switzerlandnorth",
            "switzerlandwest", "ukwest", "uksouth", "uaecentral", "uaenorth", "westeurope", "westindia", "westus", "westus2",
            "westus3", "westcentralus", "centralus", "canadacentral", "northcentralus", "southcentralus", "australiacentral",
            "australiacentral2"
        )]
        [string]$location,

        [Parameter(Mandatory = $false)]
        [switch]$aksReleaseCalendar,

        [Parameter(Mandatory = $false)]
        [ValidateSet('table', 'json', 'yaml')]
        [string]$outputFormat = 'table'  # Default output format is table
    )

    # Check if az CLI is installed
    if (-not (Get-Command az -ErrorAction SilentlyContinue)) {
        Write-Error "Az CLI is not installed. Please install Azure CLI to use this function."
        return
    }

    # Open the release calendar if requested
    if ($aksReleaseCalendar) {
        Start-Process "https://learn.microsoft.com/en-us/azure/aks/supported-kubernetes-versions?tabs=azure-cli#aks-kubernetes-release-calendar"
        return
    }

    # Validate location parameter
    if (-not $location) {
        Write-Error "Location is required unless --aksReleaseCalendar is specified."
        return
    }

    # Fetch AKS versions for the given location
    try {
        Write-Output "Checking AKS Versions, Be right back..."
        $output = az aks get-versions --location $location --output $outputFormat --only-show-errors
        Write-Output $output
    }
    catch {
        Write-Error "Failed to fetch AKS versions: $_"
    }
}

# Function - Get Network Address Space
function Get-NetConfig {
    param (
        [string]$cidr,
        [switch]$showSubnets,
        [switch]$showIpv4CidrTable,
        [switch]$azure
    )

    # Function to convert IPv4 address to integer
    function ConvertTo-IntIPv4 {
        param ($ip)
        $i = 0
        $ip.Split('.') | ForEach-Object {
            [int]$_ -shl (8 * (3 - $i++))
        } | Measure-Object -Sum | Select-Object -ExpandProperty Sum
    }

    # Function to convert integer to IPv4 address
    function ConvertTo-IPv4 {
        param ($int)
        $bytes = 3..0 | ForEach-Object { ($int -shr 8 * $_) -band 255 }
        return ($bytes -join '.')
    }

    # Function to generate a CIDR table
    function New-CidrTable {
        param (
            [string]$baseIp,
            [int]$basePrefix
        )

        $cidrTable = for ($prefix = $basePrefix; $prefix -le 32; $prefix++) {
            $subnetSize = [math]::Pow(2, (32 - $prefix))
            [PSCustomObject]@{
                CIDR       = "$baseIp/$prefix"
                SubnetMask = ConvertTo-SubnetMaskIPv4 -prefix $prefix
                TotalHosts = [int]($subnetSize - 2)
            }
        }

        return $cidrTable
    }

    # Function to convert prefix length to IPv4 subnet mask
    function ConvertTo-SubnetMaskIPv4 {
        param ($prefix)
        ConvertTo-IPv4 -int ([math]::Pow(2, 32) - [math]::Pow(2, 32 - $prefix))
    }

    # Function to determine IPv4 class
    function Get-IPv4Class {
        param ($ip)
        switch ([int]$ip.Split('.')[0]) {
            { $_ -ge 1 -and $_ -le 126 } { return 'A' }
            { $_ -ge 128 -and $_ -le 191 } { return 'B' }
            { $_ -ge 192 -and $_ -le 223 } { return 'C' }
            default { return 'Unknown' }
        }
    }

    # Extract base IP and prefix length
    $baseIP, $prefix = $cidr -split '/'
    $prefix = [int]$prefix

    $baseInt = ConvertTo-IntIPv4 -ip $baseIP
    $networkSize = [math]::Pow(2, 32 - $prefix)
    $subnetMask = ([math]::Pow(2, 32) - [math]::Pow(2, 32 - $prefix))
    $networkInt = $baseInt -band $subnetMask

    if ($showIpv4CidrTable) {
        return (New-CidrTable -baseIp $baseIP -basePrefix $prefix) | Format-Table -AutoSize
    }

    if ($azure) {
        return [PSCustomObject]@{
            IPClass          = Get-IPv4Class -ip $baseIP
            CIDR             = $cidr
            NetworkAddress   = ConvertTo-IPv4 -int $networkInt
            FirstUsableIP    = ConvertTo-IPv4 -int ($networkInt + 4)   # Azure reserves first 4 IPs
            LastUsableIP     = ConvertTo-IPv4 -int ($networkInt + $networkSize - 2)  # Last usable before broadcast
            BroadcastAddress = ConvertTo-IPv4 -int ($networkInt + $networkSize - 1)
            UsableHostCount  = $networkSize - 5  # Azure removes 5 IPs from usable range
            SubnetMask       = ConvertTo-SubnetMaskIPv4 -prefix $prefix
        }
    }

    if ($showSubnets) {
        $subnetPrefix = 24
        $subnetSize = [math]::Pow(2, 32 - $subnetPrefix)

        $subnets = for ($currentSubnetInt = $networkInt; $currentSubnetInt -lt ($networkInt + $networkSize); $currentSubnetInt += $subnetSize) {
            $subnetStart = $currentSubnetInt
            $subnetEnd = [math]::Min($currentSubnetInt + $subnetSize - 1, $networkInt + $networkSize - 1)

            [PSCustomObject]@{
                SubnetStart = ConvertTo-IPv4 -int ($subnetStart + 1)
                SubnetEnd   = ConvertTo-IPv4 -int ($subnetEnd - 1)
            }
        }

        return $subnets
    }

    return [PSCustomObject]@{
        IPClass          = Get-IPv4Class -ip $baseIP
        CIDR             = $cidr
        NetworkAddress   = ConvertTo-IPv4 -int $networkInt
        FirstUsableIP    = ConvertTo-IPv4 -int ($networkInt + 1)
        LastUsableIP     = ConvertTo-IPv4 -int ($networkInt + $networkSize - 2)
        BroadcastAddress = ConvertTo-IPv4 -int ($networkInt + $networkSize - 1)
        UsableHostCount  = $networkSize - 2
        SubnetMask       = ConvertTo-SubnetMaskIPv4 -prefix $prefix
    }
}

# Function - Get End of Life Information
function Get-EolInfo {
    param (
        [Parameter(Mandatory = $true)]
        [ValidateSet(
            "akeneo-pim", "alibaba-dragonwell", "almalinux", "alpine", "amazon-cdk", "amazon-corretto",
            "amazon-eks", "amazon-glue", "amazon-linux", "amazon-neptune", "amazon-rds-mariadb",
            "amazon-rds-mysql", "amazon-rds-postgresql", "android", "angular", "angularjs", "ansible",
            "ansible-core", "antix", "apache", "apache-activemq", "apache-airflow", "apache-apisix",
            "apache-camel", "apache-cassandra", "apache-couchdb", "apache-flink", "apache-groovy",
            "apache-hadoop", "apache-hop", "apache-kafka", "apache-lucene", "apache-spark",
            "apache-struts", "api-platform", "apple-watch", "arangodb", "argo-cd", "artifactory",
            "aws-lambda", "azul-zulu", "azure-devops-server", "azure-kubernetes-service", "backdrop",
            "bazel", "beats", "bellsoft-liberica", "big-ip", "blender", "bootstrap", "bun", "cakephp",
            "calico", "centos", "centos-stream", "centreon", "cert-manager", "cfengine", "chef-infra-client",
            "chef-infra-server", "chef-inspec", "citrix-vad", "ckeditor", "clamav", "cnspec", "cockroachdb",
            "coder", "coldfusion", "composer", "confluence", "consul", "containerd", "contao", "contour",
            "controlm", "cortex-xdr", "cos", "couchbase-server", "craft-cms", "dbt-core", "dce", "debian",
            "dependency-track", "devuan", "django", "docker-engine", "dotnet", "dotnetfx", "drupal", "drush",
            "eclipse-jetty", "eclipse-temurin", "elasticsearch", "electron", "elixir", "emberjs", "envoy",
            "erlang", "eslint", "esxi", "etcd", "eurolinux", "exim", "fairphone", "fedora", "ffmpeg",
            "filemaker", "firefox", "fluent-bit", "flux", "forgejo", "fortios", "freebsd", "gerrit", "ghc",
            "gitlab", "go", "goaccess", "godot", "google-kubernetes-engine", "google-nexus", "gorilla",
            "graalvm", "gradle", "grafana", "grafana-loki", "grails", "graylog", "gstreamer", "haproxy",
            "harbor", "hashicorp-packer", "hashicorp-vault", "hbase", "horizon", "ibm-aix", "ibm-i",
            "ibm-semeru-runtime", "icinga", "icinga-web", "intel-processors", "internet-explorer", "ionic",
            "ios", "ipad", "ipados", "iphone", "isc-dhcp", "istio", "jekyll", "jenkins", "jhipster",
            "jira-software", "joomla", "jquery", "jquery-ui", "jreleaser", "julia", "kde-plasma", "keda",
            "keycloak", "kibana", "kindle", "kirby", "kong-gateway", "kotlin", "kubernetes",
            "kubernetes-csi-node-driver-registrar", "kubernetes-node-feature-discovery", "kuma", "kyverno",
            "laravel", "libreoffice", "lineageos", "linux", "linuxmint", "log4j", "logstash", "looker", "lua",
            "macos", "mageia", "magento", "mandrel", "mariadb", "mastodon", "matomo", "mattermost", "mautic",
            "maven", "mediawiki", "meilisearch", "memcached", "micronaut", "microsoft-build-of-openjdk",
            "mongodb", "moodle", "motorola-mobility", "msexchange", "mssqlserver", "mulesoft-runtime",
            "mxlinux", "mysql", "neo4j", "neos", "netbsd", "nextcloud", "nextjs", "nexus", "nginx", "nix",
            "nixos", "nodejs", "nokia", "nomad", "numpy", "nutanix-aos", "nutanix-files", "nutanix-prism",
            "nuxt", "nvidia", "nvidia-gpu", "nvm", "office", "oneplus", "openbsd", "openjdk-builds-from-oracle",
            "opensearch", "openssl", "opensuse", "opentofu", "openvpn", "openwrt", "openzfs", "opnsense",
            "oracle-apex", "oracle-database", "oracle-jdk", "oracle-linux", "oracle-solaris", "ovirt", "pangp",
            "panos", "pci-dss", "perl", "photon", "php", "phpbb", "phpmyadmin", "pixel", "pixel-watch", "plesk",
            "pnpm", "podman", "pop-os", "postfix", "postgresql", "postmarketos", "powershell", "privatebin",
            "prometheus", "protractor", "proxmox-ve", "puppet", "python", "qt", "quarkus-framework", "quasar",
            "rabbitmq", "rails", "rancher", "raspberry-pi", "react", "react-native", "readynas",
            "red-hat-openshift", "redhat-build-of-openjdk", "redhat-jboss-eap", "redhat-satellite", "redis",
            "redmine", "rhel", "robo", "rocket-chat", "rocky-linux", "ros", "ros-2", "roundcube", "ruby",
            "rust", "salt", "samsung-mobile", "sapmachine", "scala", "sharepoint", "shopware", "silverstripe",
            "slackware", "sles", "solr", "sonar", "sourcegraph", "splunk", "spring-boot", "spring-framework",
            "sqlite", "squid", "steamos", "subversion", "surface", "suse-manager", "svelte", "symfony", "tails",
            "tarantool", "telegraf", "terraform", "tomcat", "traefik", "tvos", "twig", "typo3", "ubuntu",
            "umbraco", "unity", "unrealircd", "valkey", "varnish", "vcenter", "veeam-backup-and-replication",
            "visionos", "visual-cobol", "visual-studio", "vmware-cloud-foundation", "vmware-harbor-registry",
            "vmware-srm", "vue", "vuetify", "wagtail", "watchos", "weechat", "windows", "windows-embedded",
            "windows-nano-server", "windows-server", "windows-server-core", "wireshark", "wordpress", "xcp-ng",
            "yarn", "yocto", "zabbix", "zentyal", "zerto", "zookeeper"
        )]
        [string]$productName,

        [Parameter()]
        [switch]$activeSupport,

        [Parameter()]
        [switch]$ltsSupport
    )

    $eolUrl = "https://endoflife.date/api/$productName"
    try {
        $eolInfo = Invoke-RestMethod -Uri $eolUrl -ErrorAction Stop
    }
    catch {
        Write-Error "Failed to fetch EOL information for $(productName): $_"
        return
    }

    $currentDate = Get-Date

    # Filter and sort in a single pipeline for better performance
    $eolInfo = $eolInfo | Where-Object {
        ($ltsSupport -and $_.lts -eq $true) -or
        ($activeSupport -and (
            -not [string]::IsNullOrEmpty($_.eol) -and
            ($_.eol -match "^\d{4}-\d{2}-\d{2}$" -and [DateTime]$_.eol -gt $currentDate)
        )) -or
        (-not $ltsSupport -and -not $activeSupport)
    } | Sort-Object {
        if ($_.eol -match "^\d{4}-\d{2}-\d{2}$") { [DateTime]$_.eol } else { [DateTime]::MaxValue }
    } -Descending

    return $eolInfo
}
