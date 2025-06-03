<#
.SYNOPSIS
PowerShell profile script for enhanced Oh My Posh experience, module management, and custom utilities.

.DESCRIPTION
This profile script provides:
- Automatic update checks for the Oh My Posh profile from GitHub.
- Import and configuration of common PowerShell modules (Posh-Git, Terminal-Icons, PSReadLine).
- Oh My Posh theme initialization and environment variable setup.
- Azure CLI tab completion support.
- A suite of custom utility functions for system, network, Azure, and development tasks.

.FUNCTIONS
Register-PSProfile
    Reloads the current PowerShell profile.

Get-PSProfileTheme
    Displays the current Oh My Posh theme in use.

Get-PSProfileVersion
    Shows current and latest profile version information.

Update-PSProfile
    Downloads and applies the latest (or development) profile release from GitHub.

Update-WindowsApps
    Updates all installed Windows applications via winget (requires admin).

Get-MyPublicIP
    Retrieves public IP address and related information.

Get-SystemUptime
    Displays the system uptime and last reboot time.

Get-AzSystemUptime
    Fetches uptime for an Azure VM (Windows or Linux) using Azure CLI.

Remove-GitBranch
    Deletes local Git branches, with options for single or all branches.

Get-DnsResult
    Resolves DNS records for a given domain and record type.

Get-AksVersion
    Retrieves available Azure Kubernetes Service (AKS) versions for a region.

Get-NetConfig
    Calculates network address space details for a given CIDR.

Get-EolInfo
    Fetches end-of-life information for a specified product from endoflife.date.

.NOTES
- Requires PowerShell 7+ for some features.
- Some functions require external tools (az CLI, winget, git).
- Designed for use with Oh My Posh and compatible themes.
- Update checks are performed at most once per hour per session.

.AUTHOR
smoonlee (https://github.com/smoonlee)

.LINK
https://github.com/smoonlee/oh-my-posh-profile
#>

# Oh My Posh - Profile Release Version
$profileVersion = '3.2.0-dev'
$releaseUrl = "https://api.github.com/repos/smoonlee/oh-my-posh-profile/releases?per_page=1"

# Conditional API check (once per session, max every hour)
if (-not $global:LastProfileCheck -or $global:LastProfileCheck -lt (Get-Date).AddHours(-1)) {
    try {
        $headers = @{ "Accept" = "application/vnd.github+json"; "User-Agent" = "PowerShell" }
        $global:LatestRelease = Invoke-RestMethod -Uri $releaseUrl -Headers $headers -TimeoutSec 3 -ErrorAction Stop
        $global:LastProfileCheck = Get-Date

        if ($profileVersion -ne $global:LatestRelease[0].tag_name) {
            Write-Warning "[Oh My Posh] - Profile Update Available, Please run: Update-PSProfile"
        }
    }
    catch {
        Write-Warning "Failed to check for updates: $_"
    }
}

# Import PowerShell Modules
$modules = @('Posh-Git', 'Terminal-Icons', 'PSReadLine')
foreach ($module in $modules) {
    if (-not (Get-Module -Name $module -ListAvailable)) {
        Write-Warning "Module $module not found. Consider installing it."
        continue
    }
    Import-Module -Name $module -ErrorAction SilentlyContinue
}

# PSReadLine Configuration
if (Get-Module -Name PSReadLine) {
    Set-PSReadLineOption -EditMode Windows -PredictionSource History -PredictionViewStyle ListView -HistoryNoDuplicates -HistorySearchCursorMovesToEnd
    Set-PSReadLineKeyHandler -Key Tab -Function MenuComplete
    Set-PSReadLineKeyHandler -Key UpArrow -Function HistorySearchBackward
    Set-PSReadLineKeyHandler -Key DownArrow -Function HistorySearchForward
}

# Oh My Posh Configuration
$themePath = "$env:POSH_THEMES_PATH\quick-term-cloud.omp.json"
if (Test-Path $themePath -ErrorAction SilentlyContinue) {
    oh-my-posh init pwsh --config $themePath | Invoke-Expression
}
else {
    Write-Warning "Oh My Posh theme not found at: $themePath"
}

# Local Oh-My-Posh Configuration
$env:POSH_AZURE_ENABLED = $true
$env:POSH_GIT_ENABLED = $true

# Azure CLI Tab Completion
if (Get-Command az -ErrorAction SilentlyContinue) {
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
}

#
# Custom Functions

# Function - Reload PowerShell Session
function Register-PSProfile {
    try {
        Clear-Host
        . $PROFILE
        Write-Output "PowerShell profile reloaded successfully."
    }
    catch {
        Write-Warning "Failed to reload PowerShell profile: $_"
    }
}

# Function - Get PowerShell Profile Theme
function Get-PSProfileTheme {
    if (-not $env:POSH_THEME) {
        Write-Output "No theme set in POSH_THEME."
        return
    }

    $themeFile = Split-Path -Leaf $env:POSH_THEME
    Write-Output "Current Theme: $themeFile"
    Write-Output "Theme Path...: `e]8;;file://$env:POSH_THEME`e\$env:POSH_THEME`e]8;;`e\"
}

# Function - Get PowerShell Profile Version Information
function Get-PSProfileVersion {
    try {
        $releaseTag = if ($global:LatestRelease) { $global:LatestRelease[0].tag_name } else { "Unknown (run Update-PSProfile to fetch)" }
        $devReleaseTag = if ($global:LatestRelease -and $global:LatestRelease[0].prerelease) { $global:LatestRelease[0].tag_name } else { "No dev release available" }
        $currentThemeName = if ($env:POSH_THEME) { Split-Path -Leaf $env:POSH_THEME } else { "None" }

        [PSCustomObject]@{
            CurrentTheme          = $currentThemeName
            CurrentProfileVersion = $profileVersion
            LatestStableRelease   = $releaseTag
            LatestDevRelease      = $devReleaseTag
        } | Format-Table -AutoSize
    }
    catch {
        Write-Warning "Failed to fetch version info: $_"
    }
}

# Function - Update PowerShell Profile (OTA)
function Update-PSProfile {
    [CmdletBinding()]
    param (
        [switch]$devRelease
    )
    Set-StrictMode -Version Latest
    try {
        $releases = if ($global:LatestRelease) { $global:LatestRelease } else { Invoke-RestMethod -Uri $releaseUrl -Headers @{ "Accept" = "application/vnd.github+json"; "User-Agent" = "PowerShell" } -TimeoutSec 3 -ErrorAction Stop }
        $stableRelease = $releases | Where-Object { -not $_.prerelease } | Select-Object -First 1
        $devReleaseObj = $releases | Where-Object { $_.prerelease } | Select-Object -First 1

        if (-not $stableRelease) { Write-Warning "No stable releases found."; return }
        if ($devRelease -and -not $devReleaseObj) { Write-Warning "No development releases found."; return }

        $releaseTag = $stableRelease.tag_name
        $releaseNotes = $stableRelease.body
        $releaseUrl = $stableRelease.assets[0].browser_download_url

        if ($devRelease) {
            Write-Output "`n--- Using Development Release ---"
            $releaseTag = $devReleaseObj.tag_name
            $releaseNotes = $devReleaseObj.body
            $releaseUrl = $devReleaseObj.assets[0].browser_download_url
        }

        $currentThemeName = if ($env:POSH_THEME) { Split-Path -Leaf $env:POSH_THEME } else { "quick-term-cloud.omp.json" }
        Write-Output "Current Theme.........: $currentThemeName"
        Write-Output "Profile Version.......: $releaseTag"
        Write-Output "`nProfile Patch Notes:"
        Write-Output $releaseNotes

        Start-Sleep -Seconds 2
        Invoke-WebRequest -Uri $releaseUrl -OutFile $PROFILE -ErrorAction Stop

        $pwshProfile = Get-Content -Path $PROFILE -Raw -ErrorAction Stop
        $updatedPwshProfile = $pwshProfile -replace '(\\[^"]+\.omp\.json)', "\$currentThemeName"
        Set-Content -Path $PROFILE -Value $updatedPwshProfile -ErrorAction Stop

        Register-PSProfile
    }
    catch {
        Write-Error "Failed to update profile: $_"
    }
}

# Function - Update WinGet Applications
function Update-WindowsApps {
    if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        Write-Warning "This function must be run as an administrator."
        return
    }
    Write-Output "`nUpdating Windows Applications...`n"
    winget upgrade --include-unknown --all --silent --force
}

# Function - Get Public IP Address
function Get-MyPublicIP {
    try {
        $ipInfo = Invoke-RestMethod -Uri 'https://ipinfo.io' -TimeoutSec 3 -ErrorAction Stop
        if ($ipInfo) {
            [PSCustomObject]@{
                'Public IP' = $ipInfo.ip
                'Host Name' = $ipInfo.hostname
                'ISP'       = $ipInfo.org
                'City'      = $ipInfo.city
                'Region'    = $ipInfo.region
                'Country'   = $ipInfo.country
            } | Format-List
        }
        else {
            Write-Warning "No IP information received."
        }
    }
    catch {
        Write-Warning "Failed to retrieve public IP: $_"
    }
}

# Function - Get System Uptime
function Get-SystemUptime {
    try {
        $os = Get-CimInstance Win32_OperatingSystem -ErrorAction Stop
        $uptimeSpan = New-TimeSpan -Start $os.LastBootUpTime -End (Get-Date)
        [PSCustomObject]@{
            Hostname       = [System.Net.Dns]::GetHostName()
            Uptime         = "{0}d {1}h {2}m {3}s" -f $uptimeSpan.Days, $uptimeSpan.Hours, $uptimeSpan.Minutes, $uptimeSpan.Seconds
            LastRebootTime = $os.LastBootUpTime.ToString("yyyy-MM-dd HH:mm:ss")
        } | Format-List
    }
    catch {
        Write-Warning "Failed to retrieve system uptime: $_"
    }
}

function Get-AzSystemUptime {
    param (
        [string]$subscriptionId,
        [string]$resourceGroup,
        [string]$vmName
    )

    try {
        # Set subscription if provided
        if ($subscriptionId) {
            az login
            az account set --subscription $subscriptionId
            $currentSub = az account show --query name -o tsv
            Write-Output "[Azure] :: Using Subscription: $currentSub"
        }

        Write-Output "[Azure] :: Fetching VM OS type for '$vmName' in '$resourceGroup'..."
        $osType = az vm show --resource-group $resourceGroup --name $vmName --query 'storageProfile.osDisk.osType' -o tsv

        Write-Output "[Azure] :: OS Type: $osType" `r

        if ($osType -eq 'Windows') {
            $script = "`$uptime = New-TimeSpan -Start (Get-CimInstance Win32_OperatingSystem).LastBootUpTime ; Write-Host [Azure] :: Host Name...: `$env:COMPUTERNAME ; Write-Host [Azure] :: OS Version..: `$(Get-CimInstance Win32_OperatingSystem).Caption ; Write-Host [Azure] :: Uptime......: `$uptime.Days days, `$uptime.Hours hours, `$uptime.Minutes minutes, `$uptime.Seconds seconds ; Write-Host [Azure] :: Last Reboot.: `$(Get-CimInstance Win32_OperatingSystem).LastBootUpTime.ToString('yyyy-MM-dd HH:mm:ss')"

            $message = az vm run-command invoke `
                --resource-group $resourceGroup `
                --name $vmName `
                --command-id 'RunPowerShellScript' `
                --scripts "$script" `
                --query 'value[0].message' `
                -o tsv

            return $message
        }
        elseif ($osType -eq 'Linux') {
            $script = 'echo [Azure] :: Host Name...: $(hostname) ; echo [Azure] :: OS Version..: $(lsb_release -d | sed ''s/^Description:\s*//'') ; echo [Azure] :: Uptime......: $(uptime -p | sed ''s/^up\s*//'') ; echo [Azure] :: Last Reboot.: $(uptime -s)'

            $message = az vm run-command invoke `
                --resource-group $resourceGroup `
                --name $vmName `
                --command-id 'RunShellScript' `
                --scripts "$script" `
                --query 'value[0].message' `
                -o tsv

            # Extract only [stdout] content
            $cleanOutput = $message -split "`n" | Where-Object { $_ -match '^\[Azure\]' }

            return $cleanOutput -join "`n"
        }
        else {
            Write-Warning "[Azure CLI] :: Unsupported OS Type: $osType"
        }
    }
    catch {
        Write-Warning "[Azure CLI] :: Failed to fetch uptime: $_"
    }
}


# Function - Clean Git Branches
function Remove-GitBranch {
    param (
        [string]$defaultBranch = 'main',
        [string]$branchName,
        [switch]$all
    )
    try {
        $allBranches = git branch | ForEach-Object { $_.Trim() -replace '^\* ' } | Where-Object { $_ -notin @('master', 'main', 'prod', 'dev-main') }
        if (-not $allBranches) {
            $defaultBranchName = (git remote show origin | Select-String 'HEAD branch:').Line.Split(':')[-1].Trim()
            Write-Output "`nDefault Branch: $defaultBranchName"
            Write-Warning "No additional branches found."
            return
        }

        if ($all) {
            Write-Warning "Removing ALL local branches!"
            Write-Output 'Press any key to continue...'
            $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
            git checkout $defaultBranch -ErrorAction Stop
            foreach ($branch in $allBranches) {
                git branch -D $branch
            }
        }
        else {
            if (-not $branchName) { Write-Warning "Specify a branch name or use -all."; return }
            git branch -D $branchName
        }
    }
    catch {
        Write-Warning "Failed to delete branch(es): $_"
    }
}

# Function - Get DNS Record Information
function Get-DnsResult {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [ValidateSet('A', 'AAAA', 'CNAME', 'MX', 'NS', 'PTR', 'SOA', 'SRV', 'TXT')]
        [string]$recordType,
        [Parameter(Mandatory = $true, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [string]$domain
    )
    process {
        try {
            $result = Resolve-DnsName -Name $domain -Type $recordType -ErrorAction Stop
            $answer = $result | Where-Object { $_.Section -eq 'Answer' }
            if (-not $answer) {
                Write-Warning "No answer section found in DNS response for $domain."
                return
            }

            switch ($recordType) {
                'MX'   { $answer | Select-Object Name, Type, TTL, Preference, NameExchange | Format-Table -AutoSize }
                'NS'   { $answer | Select-Object Name, Type, TTL, NameHost | Format-Table -AutoSize }
                'SOA'  { $answer | Select-Object Name, Type, TTL, SerialNumber, PrimaryServer, ResponsiblePerson | Format-Table -AutoSize }
                'SRV'  { $answer | Select-Object Name, Type, TTL, Priority, Weight, Port, Target | Format-Table -AutoSize }
                'CNAME'{ $answer | Select-Object Name, Type, TTL, CanonicalName | Format-Table -AutoSize }
                'PTR'  { $answer | Select-Object Name, Type, TTL, PtrDomainName | Format-Table -AutoSize }
                'TXT'  { $answer | Select-Object Name, Type, TTL| Format-Table -AutoSize }
                default { $answer | Select-Object Name, Type, TTL, IPAddress | Format-Table -AutoSize }
            }
        }
        catch {
            Write-Warning "Failed to resolve DNS for $domain ($recordType): $_"
        }
    }
}

# Function - Get Azure Kubernetes Service Version
function Get-AksVersion {
    param (
        [Parameter(Mandatory = $false)]
        [ValidateSet('australiacentral', 'australiacentral2', 'australiaeast', 'australiasoutheast', 'brazilsouth', 'brazilsoutheast', 'canadacentral', 'canadaeast', 'centralindia', 'centralus', 'eastasia', 'eastus', 'eastus2', 'francecentral', 'germanynorth', 'germanywestcentral', 'japaneast', 'japanwest', 'koreacentral', 'koreasouth', 'northeurope', 'norwayeast', 'southafricanorth', 'southindia', 'southeastasia', 'switzerlandnorth', 'uaenorth', 'uksouth', 'ukwest', 'westcentralus', 'westeurope', 'westus', 'westus2', 'westus3')]
        [string]$location,
        [switch]$aksReleaseCalendar,
        [ValidateSet('table', 'json', 'yaml')]
        [string]$outputFormat = 'table'
    )
    if (-not (Get-Command az -ErrorAction SilentlyContinue)) {
        Write-Warning "Azure CLI is not installed."
        return
    }
    if ($aksReleaseCalendar) {
        Start-Process "https://learn.microsoft.com/en-us/azure/aks/supported-kubernetes-versions?tabs=azure-cli#aks-kubernetes-release-calendar"
        return
    }
    try {
        az aks get-versions --location $location --output $outputFormat
    }
    catch {
        Write-Warning "Failed to fetch AKS versions: $_"
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
    try {
        $baseIP, $prefix = $cidr -split '/'
        $prefix = [int]$prefix
        if ($baseIP.Contains(':')) {
            Write-Warning "IPv6 is not supported in this function."
            return
        }

        function ConvertTo-IntIPv4 ($ip) {
            $i = 0
            ($ip.Split('.') | ForEach-Object { [int]$_ -shl (8 * (3 - $i++)) }) -join '+' | Invoke-Expression
        }
        function ConvertTo-IPv4 ($int) {
            (3..0 | ForEach-Object { ($int -shr (8 * $_) -band 255) }) -join '.'
        }

        $baseInt = ConvertTo-IntIPv4 $baseIP
        $networkSize = [math]::Pow(2, 32 - $prefix)
        $subnetMask = ([math]::Pow(2, 32) - [math]::Pow(2, 32 - $prefix))
        $networkInt = $baseInt -band $subnetMask

        if ($showIpv4CidrTable) {
            $cidrTable = for ($p = $prefix; $p -le 32; $p++) {
                $size = [math]::Pow(2, 32 - $p)
                [PSCustomObject]@{
                    CIDR       = "$baseIP/$p"
                    SubnetMask = ConvertTo-IPv4 ([math]::Pow(2, 32) - [math]::Pow(2, 32 - $p))
                    TotalHosts = [int]($size - 2)
                }
            }
            return $cidrTable | Format-Table -AutoSize
        }

        if ($azure) {
            $firstUsableIP = ConvertTo-IPv4 ($networkInt + 4)
            $lastUsableIP = ConvertTo-IPv4 ($networkInt + $networkSize - 2)
            $usableHostCount = $networkSize - 4
        }
        else {
            $firstUsableIP = ConvertTo-IPv4 ($networkInt + 1)
            $lastUsableIP = ConvertTo-IPv4 ($networkInt + $networkSize - 2)
            $usableHostCount = $networkSize - 2
        }

        if ($showSubnets) {
            $subnetPrefix = 24
            $subnetSize = [math]::Pow(2, 32 - $subnetPrefix)
            $subnets = while ($networkInt -lt ($networkInt + $networkSize)) {
                $subnetEnd = [math]::Min($networkInt + $subnetSize - 1, $networkInt + $networkSize - 1)
                if ($subnetEnd -gt $networkInt) {
                    "Subnet: $(ConvertTo-IPv4 ($networkInt + 1)) - $(ConvertTo-IPv4 $subnetEnd)"
                }
                $networkInt += $subnetSize
            }
            return $subnets
        }

        [PSCustomObject]@{
            IPClass          = switch -Regex ($baseIP.Split('.')[0]) { '^(1[0-9]|[1-9][0-9]|12[0-6])$' { 'A' } '^(12[8-9]|1[3-8][0-9]|19[0-1])$' { 'B' } '^(19[2-9]|2[0-1][0-9]|22[0-3])$' { 'C' } default { 'Unknown' } }
            CIDR             = $cidr
            NetworkAddress   = ConvertTo-IPv4 $networkInt
            FirstUsableIP    = $firstUsableIP
            LastUsableIP     = $lastUsableIP
            BroadcastAddress = ConvertTo-IPv4 ($networkInt + $networkSize - 1)
            UsableHostCount  = $usableHostCount
            SubnetMask       = ConvertTo-IPv4 $subnetMask
        } | Format-List
    }
    catch {
        Write-Warning "Failed to process network config: $_"
    }
}

# Function - Get End of Life Information
function Get-EolInfo {
    param (
        [Parameter(Mandatory = $true)]
        [ValidateSet("akeneo-pim", "alibaba-ack", "alibaba-dragonwell", "almalinux", "alpine-linux", "amazon-cdk", "amazon-corretto", "amazon-eks", "amazon-glue", "amazon-linux", "amazon-neptune", "amazon-rds-mariadb", "amazon-rds-mysql", "amazon-rds-postgresql", "android", "angular", "angularjs", "ansible", "ansible-core", "ant", "antix", "apache-activemq", "apache-airflow", "apache-apisix", "apache-camel", "apache-cassandra", "apache-couchdb", "apache-flink", "apache-groovy", "apache-hadoop", "apache-hop", "apache-http-server", "apache-kafka", "apache-lucene", "apache-maven", "apache-nifi", "apache-pulsar", "apache-spark", "apache-struts", "apache-subversion", "api-platform", "apple-watch", "arangodb", "argo-cd", "artifactory", "aws-lambda", "azul-zulu", "azure-devops-server", "azure-kubernetes-service", "backdrop", "bamboo", "bazel", "beats", "bellsoft-liberica", "big-ip", "bigbluebutton", "bitbucket", "blender", "bootstrap", "bun", "caddy", "cakephp", "calico", "centos", "centos-stream", "centreon", "cert-manager", "cfengine", "chef-infra-client", "chef-infra-server", "chef-inspec", "citrix-vad", "ckeditor", "clamav", "cnspec", "cockroachdb", "coder", "coldfusion", "composer", "confluence", "consul", "containerd", "contao", "contour", "controlm", "cortex-xdr", "cos", "couchbase-server", "craft-cms", "dbt-core", "dce", "debian", "deno", "dependency-track", "devuan", "django", "docker-engine", "dotnet", "dotnetfx", "drupal", "drush", "eclipse-jetty", "eclipse-temurin", "elasticsearch", "electron", "elixir", "emberjs", "envoy", "erlang", "eslint", "esxi", "etcd", "eurolinux", "exim", "express", "fairphone", "fedora", "ffmpeg", "filemaker", "firefox", "fluent-bit", "flux", "forgejo", "fortios", "freebsd", "gatekeeper", "gerrit", "ghc", "gitlab", "go", "goaccess", "godot", "google-kubernetes-engine", "google-nexus", "gorilla", "graalvm-ce", "gradle", "grafana", "grafana-loki", "grails", "graylog", "greenlight", "grunt", "gstreamer", "guzzle", "haproxy", "harbor", "hashicorp-packer", "hashicorp-vault", "hbase", "horizon", "ibm-aix", "ibm-i", "ibm-semeru-runtime", "icinga", "icinga-web", "intel-processors", "internet-explorer", "ionic", "ios", "ipad", "ipados", "iphone", "isc-dhcp", "istio", "jekyll", "jenkins", "jhipster", "jira-software", "joomla", "jquery", "jquery-ui", "jreleaser", "julia", "kde-plasma", "keda", "keycloak", "kibana", "kindle", "kirby", "kong-gateway", "kotlin", "kubernetes", "kubernetes-csi-node-driver-registrar", "kubernetes-node-feature-discovery", "kuma", "kyverno", "laravel", "ldap-account-manager", "libreoffice", "lineageos", "linux", "linuxmint", "log4j", "logstash", "looker", "lua", "macos", "mageia", "magento", "mandrel", "mariadb", "mastodon", "matomo", "mattermost", "mautic", "mediawiki", "meilisearch", "memcached", "micronaut", "microsoft-build-of-openjdk", "mongodb", "moodle", "motorola-mobility", "msexchange", "mssqlserver", "mulesoft-runtime", "mxlinux", "mysql", "neo4j", "neos", "netapp-ontap", "netbsd", "nextcloud", "nextjs", "nexus", "nginx", "nix", "nixos", "nodejs", "nokia", "nomad", "notepad-plus-plus", "numpy", "nutanix-aos", "nutanix-files", "nutanix-prism", "nuxt", "nvidia", "nvidia-gpu", "nvm", "office", "oneplus", "openbsd", "openjdk-builds-from-oracle", "opensearch", "openssl", "opensuse", "opentofu", "openvpn", "openwrt", "openzfs", "opnsense", "oracle-apex", "oracle-database", "oracle-graalvm", "oracle-jdk", "oracle-linux", "oracle-solaris", "ovirt", "pangp", "panos", "pci-dss", "perl", "photon", "php", "phpbb", "phpmyadmin", "pixel", "pixel-watch", "plesk", "plone", "pnpm", "podman", "pop-os", "postfix", "postgresql", "postmarketos", "powershell", "privatebin", "proftpd", "prometheus", "protractor", "proxmox-ve", "puppet", "python", "qt", "quarkus-framework", "quasar", "rabbitmq", "rails", "rancher", "raspberry-pi", "react", "react-native", "red-hat-openshift", "redhat-build-of-openjdk", "redhat-jboss-eap", "redhat-satellite", "redis", "redmine", "rhel", "robo", "rocket-chat", "rocky-linux", "ros", "ros-2", "roundcube", "rtpengine", "ruby", "rust", "salt", "samsung-galaxy-tab", "samsung-galaxy-watch", "samsung-mobile", "sapmachine", "scala", "sharepoint", "shopware", "silverstripe", "slackware", "sles", "solr", "sonar", "sourcegraph", "splunk", "spring-boot", "spring-framework", "sqlite", "squid", "steamos", "surface", "suse-manager", "svelte", "symfony", "tails", "tarantool", "telegraf", "terraform", "tomcat", "traefik", "tvos", "twig", "typo3", "ubuntu", "umbraco", "unity", "unrealircd", "valkey", "varnish", "vcenter", "veeam-backup-and-replication", "veeam-backup-for-microsoft-365", "veeam-one", "virtualbox", "visionos", "visual-cobol", "visual-studio", "vitess", "vmware-cloud-foundation", "vmware-harbor-registry", "vmware-srm", "vue", "vuetify", "wagtail", "watchos", "weakforced", "weechat", "windows", "windows-embedded", "windows-nano-server", "windows-server", "windows-server-core", "wireshark", "wordpress", "xcp-ng", "yarn", "yocto", "zabbix", "zentyal", "zerto", "zookeeper")][string]$productName,
        [switch]$activeSupport,
        [switch]$ltsSupport
    )
    try {
        $eolInfo = Invoke-RestMethod -Uri "https://endoflife.date/api/$productName" -TimeoutSec 3 -ErrorAction Stop
        $currentDate = Get-Date

        foreach ($entry in $eolInfo) {
            if ($entry.eol -eq "false") { $entry.eol = $null }
        }

        if ($ltsSupport) { $eolInfo = $eolInfo | Where-Object { $_.lts -eq $true } }
        if ($activeSupport) {
            $eolInfo = $eolInfo | Where-Object { [string]::IsNullOrEmpty($_.eol) -or ($_.eol -match 'False') -or (($_.eol -match '^\d{4}-\d{2}-\d{2}$') -and ([DateTime]$_.eol -gt $currentDate)) }
        }

        $eolInfo | Sort-Object { try { [datetime]$_.releaseDate } catch { Get-Date "1900-01-01" }} -Descending | Format-Table -AutoSize
    }
    catch {
        Write-Warning "Failed to fetch EOL info for $($productName): $_"
    }
}
