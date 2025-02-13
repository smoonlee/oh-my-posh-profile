
$profileVersion = '3.2.0-dev'

# GitHub Repository Details
$gitRepositoryUrl = "https://api.github.com/repos/smoonlee/oh-my-posh-profile/releases"

$releases = Invoke-RestMethod -Uri $gitRepositoryUrl
$latestReleaseTag = $($($releases | Where-Object { $_.prerelease -eq $false } | Sort-Object -Unique)[0]).tag_name

# Profile Update Checker
if ($profileVersion -ne $latestReleaseTag) {
    Write-Warning "[Oh My Posh] - Profile Update Available, Please run: Update-PSProfile"
}

# Import PowerShell Modules
$modules = @('Posh-Git', 'Terminal-Icons', 'PSReadLine')
$modules | ForEach-Object { Import-Module -Name $_ -ErrorAction SilentlyContinue }

# PSReadLine Configuration
Set-PSReadLineOption -EditMode 'Windows'
Set-PSReadLineOption -PredictionSource 'History'
Set-PSReadLineOption -PredictionViewStyle 'ListView'
Set-PSReadLineOption -HistoryNoDuplicates:$True
Set-PSReadLineOption -HistorySearchCursorMovesToEnd
Set-PSReadLineKeyHandler -Key 'Tab' -Function 'MenuComplete'
Set-PSReadLineKeyHandler -Key 'UpArrow' -Function 'HistorySearchBackward'
Set-PSReadLineKeyHandler -Key 'DownArrow' -Function 'HistorySearchForward'

# Oh My Posh Configuration
$themePath = "$env:POSH_THEMES_PATH\quick-term-cloud.omp.json"
oh-my-posh init powershell --config $themePath | Invoke-Expression

# Local Oh-My-Posh Configuration
$env:POSH_AZURE_ENABLED = $true
$env:POSH_GIT_ENABLED = $true

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

#
# Custom Function Below

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
    $themeLink = "`e]8;;$themePath$`e\$themeFile`e]8;;`e\"

    Write-Output "Current Theme: $themeLink"
}

function Update-PSProfile {
    param (
        [switch] $devRelease
    )

    $currentThemeName = $($env:POSH_THEME | Split-Path -Leaf)
    Write-Output `r "Current Theme............: $currentThemeName"
    Write-Output "Current Profile Version..: $profileVersion"

    if ($devRelease) {
        Write-Output "" # Required for Verbose Spacing
        Write-Warning "[Oh My Posh] - Development Build Profile Update!!"

        $devReleaseTag = $($($releases | Where-Object { $_.prerelease -eq $true } | Sort-Object -Unique)[0]).tag_name
        $devReleaseNotes = $($($releases | Where-Object { $_.prerelease -eq $true } | Sort-Object -Unique)[0]).body
        $devReleaseUrl = $($($releases | Where-Object { $_.prerelease -eq $true } | Sort-Object -Unique)[0]).assets.browser_download_url

        # Download Development Oh My Posh Profile
        Invoke-WebRequest -Method 'Get' -Uri $devReleaseUrl -Out $PROFILE

        # Update New Profile with Current Theme
        $pwshProfile = Get-Content -Path $PROFILE -Raw

        # Reload Profile (Register-PSProfile)

        return
    }

    # Download Latest Profile
    Invoke-WebRequest -Method 'Get' -Uri $pwshProfile -OutFile $PROFILE
}


# Function - Update WinGet Applications
function Update-WindowsApps {
    if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltinRole] "Administrator")) {
        Write-Warning "This function must be run as an administrator."
        return
    }

    Write-Output `r "Updating Windows Applications..." `r
    winget upgrade --include-unknown --all --silent --force
}

# Get Public IP Address
function Get-MyPublicIP {
    try {
        $ipInfo = Invoke-RestMethod -Uri 'https://ipinfo.io' -TimeoutSec 5

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
        [string] $subscriptionId,
        [string] $resourceGroup,
        [string] $vmName
    )


    # Set subscription only if different from current context
    if ($subscriptionId -and ((Get-AzContext).Subscription.Id -ne $subscriptionId)) {
        Set-AzContext -SubscriptionId $subscriptionId | Out-Null
        $subFriendlyName = (Get-AzContext).Subscription.Name
        Write-Output "[Azure] :: Using Azure Subscription: $subFriendlyName"
    }

    # Fetch VM details once to avoid multiple API calls
    $vm = Get-AzVM -ResourceGroupName $resourceGroup -Name $vmName
    $osType = $vm.StorageProfile.OsDisk.OsType

    Write-Output "[Azure] :: Fetching System Uptime for $vmName in $resourceGroup..."

    # Determine OS and execute corresponding command
    if ($osType -eq 'Windows') {
        $response = Invoke-AzVMRunCommand -ResourceGroupName $resourceGroup -Name $vmName -CommandId 'RunPowerShellScript' -ScriptString @'
        $uptime = New-TimeSpan -Start (Get-CimInstance Win32_OperatingSystem).LastBootUpTime
        Write-Output "[Azure] :: Hostname: $(hostname)"
        Write-Output "[Azure] :: Uptime: $($uptime.Days) days, $($uptime.Hours) hours, $($uptime.Minutes) minutes, $($uptime.Seconds) seconds"
        Write-Output "[Azure] :: Last Reboot Time: $((Get-CimInstance Win32_OperatingSystem).LastBootUpTime.ToString('dd/MM/yyyy HH:mm:ss'))"
'@

        return $response.Value[0].Message
    }
    elseif ($osType -eq 'Linux') {
        $response = Invoke-AzVMRunCommand -ResourceGroupName $resourceGroup -Name $vmName -CommandId 'RunShellScript' -ScriptString @'
        echo "[Azure] :: Hostname: $(hostname)"
        echo "[Azure] :: Uptime: $(uptime -p)"
        echo "[Azure] :: Last Reboot Time: $(uptime -s)"
'@

        return $response.Value[0].Message.Trim()
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

    # Get all local branches and clean them up (trim and remove active branch marker)
    $allBranches = git branch | ForEach-Object { $_.Trim() } | Where-Object { $_ -notmatch '^\* ' }

    # Filter out default, main, prod, and dev-main branches
    $allBranches = $allBranches | Where-Object { $_ -notmatch 'master | main | prod |dev-main' }

    # Handle case where there are no branches to clean
    if ($allBranches.Count -eq 0) {
        Write-Output ""  # Empty line for script spacing
        $defaultBranchName = (git remote show origin | Select-String -Pattern 'HEAD branch:').ToString().Split(':')[-1].Trim()
        Write-Output "Default Branch: $defaultBranchName"
        Write-Warning "No additional branches found"
        return
    }

    # Proceed with cleaning branches
    if ($all) {
        Write-Output ""  # Empty line for script spacing
        Write-Warning "This will remove ALL local branches in the repository!"
        Write-Output 'Press any key to continue...'
        $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')

        # Ensure we checkout to a safe branch (default or main)
        Write-Output "`r[Git] :: Switching to default branch"
        if ($defaultBranch) {
            git checkout $defaultBranch
        }
        else {
            git checkout main
        }

        # Start the branch clean-up process
        Write-Output "`r[Git] :: Cleaning up branches"
        foreach ($branch in $allBranches) {
            try {
                git branch -D $branch
            }
            catch {
                Write-Warning "Failed to delete branch $branch"
            }
        }
    }
    else {
        # If $branchName is provided, delete that specific branch
        try {
            git branch -D $branchName
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
        Write-Output "Az CLI is not installed. Please install Azure CLI to use this function." -ForegroundColor Red
        return
    }

    # If aksReleaseCalendar is specified, open the release calendar page
    if ($aksReleaseCalendar) {
        Start-Process "https://learn.microsoft.com/en-us/azure/aks/supported-kubernetes-versions?tabs=azure-cli#aks-kubernetes-release-calendar"
        return
    }

    # Fetch AKS versions for the given location with selected output format
    $output = az aks get-versions --location $location --output $outputFormat

    # Display the result
    Write-Output $output
}

# Function - Get Network Address Space
function Get-NetConfig {
    param (
        [string]$cidr,
        [switch]$showSubnets,
        [switch]$showIpv4CidrTable,
        [switch]$azure
    )

    # Load System.Numerics for BigInteger support
    Add-Type -AssemblyName 'System.Numerics'

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

        # Convert base IP to integer
        $baseInt = ConvertTo-IntIPv4 -ip $baseIp
        $cidrTable = @()

        for ($prefix = $basePrefix; $prefix -le 32; $prefix++) {
            $subnetSize = [math]::Pow(2, (32 - $prefix))
            $networkInt = $baseInt -band (([math]::Pow(2, 32) - 1) - ([math]::Pow(2, 32 - $prefix) - 1))
            $subnetMask = ConvertTo-IPv4 -int $subnetSize
            $totalHosts = [int]($subnetSize - 2)  # Remove leading zeros

            $cidrTable += [PSCustomObject]@{
                CIDR       = "$baseIp/$prefix"
                SubnetMask = $subnetMask
                TotalHosts = $totalHosts
            }
        }

        return $cidrTable
    }

    # Function to convert prefix length to IPv4 subnet mask
    function ConvertTo-SubnetMaskIPv4 {
        param ($prefix)
        $maskInt = ([math]::Pow(2, $prefix) - 1) * [math]::Pow(2, 32 - $prefix)
        ConvertTo-IPv4 -int $maskInt
    }

    # Function to determine IPv4 class
    function Get-IPv4Class {
        param ($ip)
        $firstOctet = [int]$ip.Split('.')[0]
        switch ($firstOctet) {
            { $_ -ge 1 -and $_ -le 126 } { return 'A' }
            { $_ -ge 128 -and $_ -le 191 } { return 'B' }
            { $_ -ge 192 -and $_ -le 223 } { return 'C' }
            default { return 'Unknown' }
        }
    }

    # Extract base IP and prefix length
    $baseIP, $prefix = $cidr -split '/'
    $prefix = [int]$prefix

    $isIPv6 = $baseIP.Contains(':')

    if ($showIpv4CidrTable) {
        # Generate CIDR table for IPv4
        return (New-CidrTable -baseIp $baseIP -basePrefix $prefix) | Format-Table -AutoSize
    }

    if ($azure) {
        # Azure specific logic for usable IPs
        if ($isIPv6) {
            Write-Output "Azure networking for IPv6 is not yet supported."
        }
        else {
            $baseInt = ConvertTo-IntIPv4 -ip $baseIP
            $subnetMask = [math]::Pow(2, 32 - $prefix)

            # Network calculation
            $networkInt = $baseInt -band $subnetMask

            # For Azure, first usable IP is +4 due to reserved IPs (.0, .1, .2, .3)
            $firstUsableIP = ConvertTo-IPv4 -int ($networkInt + 4)
            $lastUsableIP = ConvertTo-IPv4 -int ($networkInt + $subnetMask - 2)
            $broadcastAddress = ConvertTo-IPv4 -int ($networkInt + $subnetMask - 1)

            $usableHostCount = $subnetMask - 4

            return [PSCustomObject]@{
                IPClass          = Get-IPv4Class -ip $baseIP
                CIDR             = $cidr
                NetworkAddress   = ConvertTo-IPv4 -int $networkInt
                FirstUsableIP    = $firstUsableIP
                LastUsableIP     = $lastUsableIP
                BroadcastAddress = $broadcastAddress
                UsableHostCount  = $usableHostCount
                SubnetMask       = ConvertTo-SubnetMaskIPv4 -prefix $prefix
            }
        }
    }

    if ($isIPv6) {
        # IPv6 logic
        Write-Output "IPv6 logic is still a placeholder for future use."
    }
    else {
        # IPv4 logic for non-Azure cases
        $baseInt = ConvertTo-IntIPv4 -ip $baseIP
        $networkSize = [math]::Pow(2, 32 - $prefix)
        $subnetMask = ([math]::Pow(2, 32) - [math]::Pow(2, 32 - $prefix))

        $networkInt = $baseInt -band $subnetMask

        if ($showSubnets) {
            # Show subnets within this range
            $subnetPrefix = 24
            $subnetSize = [math]::Pow(2, 32 - $subnetPrefix)

            $currentSubnetInt = $networkInt
            $subnets = @()

            while ($currentSubnetInt -lt $networkInt + $networkSize) {
                $subnetStart = $currentSubnetInt
                $subnetEnd = [math]::Min($currentSubnetInt + $subnetSize - 1, $networkInt + $networkSize - 1)

                if ($subnetEnd -gt $subnetStart) {
                    $subnetStartIP = ConvertTo-IPv4 -int ($subnetStart + 1)
                    $subnetEndIP = ConvertTo-IPv4 -int ($subnetEnd - 1)

                    $subnets += "Subnet: $subnetStartIP - $subnetEndIP"
                }

                $currentSubnetInt = $currentSubnetInt + $subnetSize
            }

            return $subnets
        }
        else {
            # Output results for standard IPv4
            return [PSCustomObject]@{
                IPClass          = Get-IPv4Class -ip $baseIP
                CIDR             = $cidr
                NetworkAddress   = ConvertTo-IPv4 -int $networkInt
                FirstUsableIP    = ConvertTo-IPv4 -int ($networkInt + 1)
                LastUsableIP     = ConvertTo-IPv4 -int ($networkInt + $networkSize - 2)
                BroadcastAddress = ConvertTo-IPv4 -int ($networkInt + $networkSize - 1)
                UsableHostCount  = ($networkSize - 2).ToString()
                SubnetMask       = ConvertTo-SubnetMaskIPv4 -prefix $prefix
            }
        }
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
    $eolInfo = Invoke-RestMethod -Uri $eolUrl

    $currentDate = Get-Date

    # Ensure 'eol' values are properly handled
    foreach ($entry in $eolInfo) {
        if ($entry.eol -eq "false") {
            $entry.eol = $null
        }
    }

    # Apply LTS filter if requested
    if ($ltsSupport) {
        $eolInfo = $eolInfo | Where-Object { $_.lts -eq $true }
    }

    # Apply Active Support filter if requested
    if ($activeSupport) {
        $eolInfo = $eolInfo | Where-Object {
            # Ensure 'eol' is not 'false' before converting to [DateTime]
            ([string]::IsNullOrEmpty($_.eol)) -or ($_.eol -match "^\d{4}-\d{2}-\d{2}$" -and [DateTime]$_.eol -gt $currentDate)
        }
    }

    # Sort results, moving entries with null EOL to the bottom
    $eolInfo = $eolInfo | Sort-Object { if ($_.eol -match "^\d{4}-\d{2}-\d{2}$") { [DateTime]$_.eol } else { [DateTime]::MaxValue } } -Descending

    return $eolInfo
}
