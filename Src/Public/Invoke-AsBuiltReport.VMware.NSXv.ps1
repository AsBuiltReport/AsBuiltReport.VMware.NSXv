function Invoke-AsBuiltReport.VMware.NSXv {
    <#
    .SYNOPSIS
        PowerShell script which documents the configuration of VMware NSX-V in Word/HTML/XML/Text formats
    .DESCRIPTION
        Documents the configuration of VMware NSX-V in Word/HTML/XML/Text formats using PScribo.
    .NOTES
        Version:        0.1.2
        Author:         Matt Allford
        Twitter:        @mattallford
        Github:         mattallford
        Credits:        Iain Brighton (@iainbrighton) - PScribo module

    .LINK
        https://github.com/tpcarman/As-Built-Report
    #>

    #region Script Parameters
    [CmdletBinding()]
    param (
        [String[]] $Target,
        [pscredential] $Credential,
		$StylePath
    )
    
    # If custom style not set, use default style
    if (!$StylePath) {
        & "$PSScriptRoot\..\..\AsBuiltReport.VMware.NSXv.Style.ps1"
    }
    
    foreach ($Server in $Target){
        $script:NSXManager = $null
        Try { 
            $script:NSXManager = Connect-NsxServer -vCenterServer $Server -Credential $Credential -ErrorAction Stop
        } Catch { 
            Write-Verbose "Unable to connect to NSX Manager for the vCenter Server $Server."
        }

        if ($NSXManager) {
            #Gather information about the NSX environment which are used in later sections within the script
            $script:NSXControllers = Get-NsxController
            $script:NSXEdges = Get-NsxEdge
            $script:NSXLogicalRouters = Get-NsxLogicalRouter
            $script:NSXFirewallSections = Get-NSXFirewallSection
            $script:NSXLogicalSwitches = Get-NSXLogicalSwitch
            $script:NSXFirewallExclusionList = Get-NsxFirewallExclusionListMember
            $script:NSXSecurityGroups = Get-NsxSecurityGroup
            $script:NSXSegmentIDs = Get-NSXSegmentIdRange
            $script:NSXTransportZones = Get-NsxTransportZone
            $script:NSXIPSets = Get-NsxIpSet
            $script:NSXMacSets = Get-NsxMacSet

            #Create major section in the output file for VMware NSX
            section -Style Heading2 'NSX' {
                Paragraph 'The following section provides a summary of the VMware NSX configuration.'
                BlankLine
                #Provide a summary of the NSX Environment
                $NSXSummary = [PSCustomObject] @{
                    'NSX Manager Address' = $NSXManager.Server
                    'NSX Manager Version' = $NSXManager.Version
                    'NSX Manager Build Number' = $NSXManager.BuildNumber
                    'NSX Controller Count' = $NSXControllers.count
                    'NSX Edge Count' = $NSXEdges.count
                    'NSX Logical Router Count' = $NSXLogicalRouters.count
                    'NSX Distributed Firewall Sections' = $NSXFirewallSections.count
                    'NSX Logical Switch Count' = $NSXLogicalSwitches.count
                    'NSX Security Group Count' = $NSXSecurityGroups.count
                    'NSX Segment ID Count' = $NSXSegmentIDs.count
                    'NSX Transport Zone Count' = $NSXTransportZones.count
                    'NSX IP Set Count' = $NSXIPSets.count
                }
                $NSXSummary | Table -Name 'NSX Information' -List

                #If this NSX Manager has Controllers, provide a summary of the NSX Controllers
                if ($NSXControllers) {
                    section -Style Heading3 'Controllers' {
                        $NSXControllerSettings = foreach ($NSXController in $NSXControllers) {
                            [PSCustomObject] @{
                                Name = $NSXController.Name
                                ID = $NSXController.ID
                                'IP Address' = $NSXController.IPAddress
                                Status = $NSXController.Status
                                Version = $NSXController.Version
                                'Is Universal' = $NSXController.IsUniversal
                            }
                        }
                        $NSXControllerSettings | Table -Name 'NSX controller Information'
                    }
                }

                if ($NSXSegmentIDs) {
                    Section -Style Heading3 'Segment IDs' {
                        $NSXSegmentIDSettings = foreach ($NSXSegmentID in $NSXSegmentIDs) {
                            [PSCustomObject]@{
                                'Segment ID' = $NSXSegmentID.id
                                'Segment Name' = $NSXSegmentID.name
                                'Segment ID Pool Begin' = $NSXSegmentID.Begin
                                'Segment ID Pool End' = $NSXSegmentID.end
                                'Is Universal' = $NSXSegmentID.IsUniversal
                            }
                        }
                        $NSXSegmentIDSettings | Table -Name 'NSX Segment IDs'
                    }
                }

                if ($NSXTransportZones) {
                    Section -Style Heading3 'Transport Zones' {
                        $NSXTransportZoneSettings = foreach ($NSXTransportZone in $NSXTransportZones){
                            [PSCustomObject]@{
                                Name = $NSXTransportZone.Name
                                'Is Universal' = $NSXTransportZone.isUniversal
                                Description = $NSXTransportZone.Description
                                'Replication Mode' = $NSXTransportZone.ControlPlaneMode
                                'Attached Clusters' = $NSXTransportZone.clusters.cluster.cluster.name
                                'Associated Logical Switch #' = $NSXTransportZone.virtualwirecount
                                'CDO Mode Enabled' = $NSXTransportZone.CDOModeEnabled
                            }
                        }
                        $NSXTransportZoneSettings | Table -Name 'Transport Zones'
                    }
                }

                if ($NSXLogicalSwitches){
                    Section -Style Heading3 'Logical Switches' {
                        $NSXLogicalSwitchSettings = foreach ($NSXLogicalSwitch in $NSXLogicalSwitches){
                            $BackingPortGroup = $NSXLogicalSwitch | Get-NsxBackingPortGroup
                            $VMsAttachedToLogicalSwitch = $BackingPortGroup | Get-VM
                            [PSCustomObject]@{
                                Name = $NSXLogicalSwitch.Name
                                ID = $NSXLogicalSwitch.ObjectID
                                'Is Universal' = $NSXLogicalSwitch.IsUniversal
                                Description = $NSXLogicalSwitch.Description
                                'Control Plane Mode' = $NSXLogicalSwitch.ControlPlaneMode
                                'Attached VM #' = $VMsAttachedToLogicalSwitch.count
                            }
                        }
                        $NSXLogicalSwitchSettings | Table -Name 'Logical Switches'
                    }
                }

                #Create report section for NSX Edges
                Section -Style Heading3 'Edges' {
                    #Loop through each Edge to collect information
                    foreach ($NSXEdge in $NSXEdges) {
                        Section -Style Heading4 $NSXEdge.Name {
                            $NSXEdgeSettings = [PSCustomObject] @{
                                Name = $NSXEdge.Name
                                ID = $NSXEdge.ID
                                Version = $NSXEdge.Version
                                Status = $NSXEdge.Status
                                Type = $NSXEdge.Type
                                'Connected VNICs' = $NSXEdge.edgeSummary.numberOfConnectedVnics
                                'Edge Status' = $NSXEdge.edgeSummary.edgeStatus
                                'Is Universal' = $NSXEdge.isUniversal
                                'Edge HA Enabled' = $NSXEdge.features.highAvailability.enabled
                                'Deploy Appliance' = $NSXEdge.appliances.deployAppliances
                                'Appliance Size' = $NSXEdge.appliances.ApplianceSize
                                'Syslog Enabled' = $NSXEdge.features.syslog.enabled
                                'SSH Enabled' = $NSXEdge.cliSettings.remoteAccess
                                'Edge Autoconfiguration Enabled' = $NSXEdge.autoConfiguration.enabled
                                'FIPS Enabled' = $NSXEdge.EnableFIPS
                                'NAT Enabled' = $NSXEdge.features.Nat.enabled
                                'Layer 2 VPN Enabled' = $NSXEdge.features.l2Vpn.enabled
                                'DNS Enabled' = $NSXEdge.features.dns.enabled
                                'SSL VPN Enabled' = $NSXEdge.features.sslvpnConfig.enabled
                                'Firewall Enabled' = $NSXEdge.features.firewall.enabled
                                'IPSEC VPN Enabled' = $NSXEdge.features.ipsec.enabled
                                'Load Balancer Enabled' = $NSXEdge.features.loadBalancer.enabled
                                'DHCP Server Enabled' = $NSXEdge.features.dhcp.enabled
                                'Layer 2 Bridges Enabled' = $NSXEdge.features.bridges.enabled
                            }
                            $NSXEdgeSettings | Table -Name "NSX Edge Information" -List

                            #Loop through all of the vNICs attached to the NSX edge and output information to the report
                            #Show only connected NICs if using Infolevel 1, but show all NICs is InfoLevel is 2 or greater
                            Section -Style Heading5 "vNIC Settings" {
                                $NSXEdgeVNICSettings = foreach ($NSXEdgeVNIC in $NSXEdge.vnics.vnic) {
                                    [PSCustomObject] @{
                                        Label = $NSXEdgeVNIC.Label
                                        'VNIC Number' = $NSXEdgeVNIC.index
                                        Name = $NSXEdgeVNIC.Name
                                        MTU = $NSXEdgeVNIC.mtu
                                        Type = $NSXEdgeVNIC.Type
                                        Connected = $NSXEdgeVNIC.IsConnected
                                        'Portgroup Name' = $NSXEdgeVNIC.portgroupName
                                    }
                                }
                                $NSXEdgeVNICSettings | Table -Name "NSX Edge VNIC Information"
                            }

                            #Check to see if NAT is enabled on the NSX Edge. If it is, export NAT Rules
                            $NSXEdgeNATRules = $NSXEdge | Get-NsxEdgeNat | Get-NsxEdgeNatRule
                            if ($NSXEdgeNATRules) {
                                Section -Style Heading5 "NAT Rules" {
                                    $SNATRules = $NSXEdgeNATRules | Where-Object {$_.Action -eq "snat"}
                                    $DNATRules = $NSXEdgeNATRules | Where-Object {$_.Action -eq "dnat"}
									if ($SNATRules){
										Section -Style Heading6 "SNAT Rules" {
											$SNATRuleConfig = foreach ($SNATRule in $SNATRules) {
												[PSCustomObject] @{
													'Rule ID' = $SNATRule.RuleId
													Action = $SNATRule.Action
													Enabled = $SNATRule.Enabled
													Description = $SNATRule.Description
													RuleType = $SNATRule.RuleType
													EdgeNIC = $SNATRule.vnic
													OriginalAddress = $SNATRule.OriginalAddress
													OriginalPort = $SNATRule.OriginalPort
													TranslatedAddress = $SNATRule.TranslatedAddress
													TranslatedPort = $SNATRule.TranslatedPort
													Protocol = $SNATRule.Protocol
													'SNAT Destination Address' = $SNATRule.snatMatchDestinationAddress
													'SNAT Destination Port' = $SNATRule.snatMatchDestinationPort
													'Logging Enabled' = $SNATRule.loggingEnabled
												}
											}
											$SNATRuleConfig | Table -Name "SNAT Rules" -List -ColumnWidths 50, 50
										}
									}#end if $SNATRules
									if ($DNATRules){
										Section -Style Heading6 "DNAT Rules" {
											$DNATRuleConfig = foreach ($DNATRule in $DNATRules) {
												[PSCustomObject] @{
													'Rule ID' = $DNATRule.RuleId
													Action = $DNATRule.Action
													Enabled = $DNATRule.Enabled
													Description = $DNATRule.Description
													RuleType = $DNATRule.RuleType
													EdgeNIC = $DNATRule.vnic
													OriginalAddress = $DNATRule.OriginalAddress
													OriginalPort = $DNATRule.OriginalPort
													TranslatedAddress = $DNATRule.TranslatedAddress
													TranslatedPort = $DNATRule.TranslatedPort
													Protocol = $DNATRule.Protocol
													'DNAT Source Address' = $DNATRule.dnatMatchSourceAddress
													'DNAT Source Port' = $DNATRule.dnatMatchSourcePort
													'Logging Enabled' = $DNATRule.loggingEnabled
												}
											}
											$DNATRuleConfig | Table -Name "DNAT Rules" -List -ColumnWidths 50, 50
										}
									}#end if $DNATRules
                                }#end Section -Style Heading5 "NAT Rules"
                            }#End $NSXEdgeNATRules

                            #Check to see if Layer2 VPN is enabled on the NSX Edge. If it is, export the L2 VPN information
                            if ($NSXEdge.features.l2Vpn.enabled) {

                            }

                            #Check to see if DNS is enabled on the NSX Edge. If it is, export the DNS information
                            if ($NSXEdge.features.dns.enabled -eq "true") {
                                Section -Style Heading5 "DNS Settings" {
                                    $NSXEdgeDNSSettings = [PSCustomObject]@{
                                        'Edge Interface' = $NSXEdge.features.dns.listeners.vnic
                                        'DNS Servers' = ($NSXEdge.features.dns.dnsViews.dnsView.forwarders.IpAddress -join ", ")
                                        'Cache Size' = $NSXEdge.features.dns.cachesize
                                        'Logging Enabled' = $NSXEdge.features.dns.logging.enable
                                        'Logging Level' = $NSXEdge.features.dns.logging.loglevel
                                    }
                                    $NSXEdgeDNSSettings | Table -Name "$($NSXEdge.Name) DNS Configuration"
                                }
                            }

                            #Check to see if the SSL VPN is enabled on the NSX Edge. If it is, export the SSL VPN information
                            if ($NSXEdge.features.sslvpnConfig.enabled) {

                            }

                            #Check to see if the Edge is deployed with high availability. If it is, export the HA information
                            if ($NSXEdge.features.highAvailability.enabled) {

                            }

                            #Check to see if routing is enabled on the NSX Edge. If it is, export the routing information
                            if ($NSXEdge.features.routing.enabled) {

                            }
                            if ($NSXEdge.features.gslb.enabled) {

                            }
                            if ($NSXEdge.features.firewall.enabled) {

                            }
                            if ($NSXEdge.features.ipsec.enabled) {

                            }
                            if ($NSXEdge.features.loadbalancer.enabled) {

                            }
                            if ($NSXEdge.features.dhcp.enabled) {

                            }
                            if ($NSXEdge.features.bridges.enabled) {

                            }

                            #Check to see if Syslog is enabled on the NSX Edge. If it is, export the Syslog information
                            if ($NSXEdge.features.syslog.enabled -eq "true") {
                                Section -Style Heading5 "Syslog Settings" {
                                    $NSXEdgeSyslogSettings = [PSCustomObject]@{
                                        'Syslog Protocol' = $NSXEdge.features.Syslog.Protocol
                                        'Syslog Servers' = ($NSXEdge.features.Syslog.ServerAddresses.ipAddress -join ", ")
                                    }
                                    $NSXEdgeSyslogSettings | Table -Name "$($NSXEdge.Name) Syslog Settings"
                                }
                            }
                        }
                    }#End NSX Edge foreach loop
                }#End NSX Edge Settings

                Section -Style Heading3 'Distributed Firewall' {
                    #Check to see if any VMs are excluded from the NSX Distributed Firewall, and if they are, list them here
                    if ($NSXFirewallExclusionList) {
                        Section -Style Heading4 "Distributed Firewall Exclusion List" {
                            $NSXFirewallExclusionList | Select-Object Name | table -Name "Distributed Firewall Exclusion List"
                        }
                    }
                    #Document the NSX DFW Sections
                    if ($NSXFirewallSections) {
                        Section -Style Heading4 "DFW Firewall Sections" {
                            $NSXFirewallSectionSettings = foreach ($NSXFirewallSection in $NSXFirewallSections) {
                                [PSCustomObject]@{
                                    Name = $NSXFirewallSection.Name
                                    ID = $NSXFirewallSection.ID
                                    Stateless = $NSXFirewallSection.Stateless
                                    Type = $NSXFirewallSection.Type
                                    '# of Rules' = $NSXFirewallSection.rule.count
                                    'Enable TCP Strict' = $NSXFirewallSection.tcpStrict
                                    'Enable User Identity at Source' = $NSXFirewallSection.useSid
                                }
                            }
                            $NSXFirewallSectionSettings | table -Name "DFW Firewall Section Information" -List -ColumnWidths 50, 50
                        }

                        #For each Section in the DFW, loop through to get information about each rule within the secion and document each rule
                        foreach ($NSXFirewallSection in $NSXFirewallSections) {
                            #Get all NSX Rules for the current section
                            $NSXDFWRules = $NSXFirewallSection | Get-NsxFirewallRule 
                            if ($NSXDFWRules) {
                                Section -Style Heading4 "$($NSXFirewallSection.name) Firewall Rules" {
                                    $NSXDFWRuleInfo = foreach ($NSXDFWRule in $NSXDFWRules) {
                                        #Check to see if the current rule is enabled or disabled
                                        if ($NSXDFWRule.Disabled -eq "true") {
                                            $NSXDFWRuleStatus = "Disabled"
                                        } elseif ($NSXDFWRule.Disabled -eq "false") {
                                            $NSXDFWRuleStatus = "Enabled"
                                        }

                                        # If there is no source, the source must be any. Else specify the source.
                                        if (!$NSXDFWRule.Sources.Source.Name) {
                                            $NSXDFWRuleSource = "Any"
                                        } else {
                                            $NSXDFWRuleSource = ($NSXDFWRule.Sources.Source.Name -join ", ")
                                        }

                                        # If there is no destination, the destination must be any. Else specify the destination.
                                        if (!$NSXDFWRule.Destinations.Destination.Name) {
                                            $NSXDFWRuleDestination = "Any"
                                        } else {
                                            $NSXDFWRuleDestination = ($NSXDFWRule.Destinations.Destination.Name -join ", ")
                                        }

                                        # If there is no service, the service must be any. Else specify the service
                                        if (!$NSXDFWRule.Services.service.name) {
                                            $NSXDFWServiceName = "Any"
                                        } Else {
                                            $NSXDFWServiceName = ($NSXDFWRule.Services.service.name -join ", ")
                                        }

                                        [PSCustomObject]@{
                                            Name = $NSXDFWRule.Name
                                            ID = $NSXDFWRule.id
                                            Status = $NSXDFWRuleStatus
                                            Action = $NSXDFWRule.Action
                                            Direction = $NSXDFWRule.Direction
                                            'Packet Type' = $NSXDFWRule.PacketType
                                            'Source' = $NSXDFWRuleSource
                                            'Source Type' = ($NSXDFWRule.Sources.Source.Type -join ", ")
                                            'Source Negate' = $NSXDFWRule.Sources.Excluded
                                            'Destination' = $NSXDFWRuleDestination
                                            'Destination Type' = ($NSXDFWRule.Destinations.Destination.Type -join ", ")
                                            'Destination Negate' = $NSXDFWRule.Destinations.Excluded
                                            'Service Name' = $NSXDFWServiceName
                                            'Applied To' = $NSXDFWRule.appliedToList.appliedTo.name
                                            'Log Enabled' = $NSXDFWRule.Logged
                                        }
                                    }
                                    $NSXDFWRuleInfo | table -Name "DFW Firewall Rules"
                                }
                            }

                        }#End Foreach NSX Firewall Sections
                    }#End if NSX Firewall Sections
                }#End NSX Distributed Firewall Section

                #This block of code retrieves information about synamic and static NSX Security groups
                if ($NSXSecurityGroups) {
                    Section -Style Heading3 'Security Groups' {
                        Section -Style Heading4 'Security Group Summary' {
                            #Create empty arrays that are used in the foreach loops below
                            $NSXSecurityGroupSummary = @()
                            $StaticNSXSecurityGroups = @()
                            $DynamicNSXSecurityGroups = @()
                            foreach ($NSXSecurityGroup in $NSXSecurityGroups) {
                                if ($NSXSecurityGroup.dynamicMemberDefinition) {
                                    $NSXSecurityGroupHashTable = [Ordered]@{
                                        'Name' = $NSXSecurityGroup.name
                                        'Scope' = $NSXSecurityGroup.scope.name
                                        'Is Universal' = $NSXSecurityGroup.IsUniversal
                                        'Inheritance Allowed' = $NSXSecurityGroup.InheritanceAllowed
                                        'Object ID' = $NSXSecurityGroup.objectID
                                        'Group Type' = "Dynamic"
                                    }
                                    $NSXSecurityGroupObject = New-Object PSObject -Property $NSXSecurityGroupHashTable
                                    $NSXSecurityGroupSummary += $NSXSecurityGroupObject
                                    #Add the security group to the list of Dynamic security groups
                                    $DynamicNSXSecurityGroups += $NSXSecurityGroup
                                } else {
                                    $NSXSecurityGroupHashTable = [Ordered]@{
                                        'Name' = $NSXSecurityGroup.name
                                        'Scope' = $NSXSecurityGroup.scope.name
                                        'Is Universal' = $NSXSecurityGroup.IsUniversal
                                        'Inheritance Allowed' = $NSXSecurityGroup.InheritanceAllowed
                                        'Object ID' = $NSXSecurityGroup.objectID
                                        'Group Type' = "Static"
                                    }
                                    $NSXSecurityGroupObject = New-Object PSObject -Property $NSXSecurityGroupHashTable
                                    $NSXSecurityGroupSummary += $NSXSecurityGroupObject
                                    #Add the security group to the list of Static security groups
                                    $StaticNSXSecurityGroups += $NSXSecurityGroup
                                }
                            }
                            #Export the information regarding both dynamic and static security groups
                            $NSXSecurityGroupSummary | table -Name "Security Groups"

                            #If there are any static security groups in the environment, export specific information about the security groups, including the membership
                            if ($StaticNSXSecurityGroups) {
                                section -Style Heading5 'Static Security Groups' {
                                    $StaticNSXSecurityGroupSettings = foreach ($StaticNSXSecurityGroup in $StaticNSXSecurityGroups) {
                                        [PSCustomObject]@{
                                            Name = $StaticNSXSecurityGroup.Name
                                            Description = $StaticNSXSecurityGroup.Description
                                            Members = ($StaticNSXSecurityGroup.member.Name -join ", ")
                                        }
                                    }
                                    $StaticNSXSecurityGroupSettings | table -Name "Static Security Group Membership"
                                }
                            }

                            #If there are any dynamic security groups in the environment, export specific information about the security groups, including the dynamic criteria
                            if ($DynamicNSXSecurityGroups) {
                                section -Style Heading5 'Dynamic Security Groups' {
                                    $DynamicNSXSecurityGroupSettings = foreach ($DynamicNSXSecurityGroup in $DynamicNSXSecurityGroups) {
                                        [PSCustomObject]@{
                                            Name = $DynamicNSXSecurityGroup.Name
                                            Operator = $DynamicNSXSecurityGroup.dynamicMemberDefinition.DynamicSet.DynamicCriteria.Operator
                                            Key = $DynamicNSXSecurityGroup.dynamicMemberDefinition.DynamicSet.DynamicCriteria.Key
                                            Criteria = $DynamicNSXSecurityGroup.dynamicMemberDefinition.DynamicSet.DynamicCriteria.Criteria
                                            Value = $DynamicNSXSecurityGroup.dynamicMemberDefinition.DynamicSet.DynamicCriteria.Value
                                        }
                                    }
                                    $DynamicNSXSecurityGroupSettings | table -Name "Dynamic Security Group Membership"
                                }
                            }
                        }
                    }#End Section Security Groups
                }#End if NSXSecurityGroups

                if ($NSXIPSets){
                    Section -Style Heading3 'IP Sets' {
                        $NSXIPSetConfiguration = foreach ($NSXIPSet in $NSXIPSets){
                            [PSCustomObject]@{
                                Name = $NSXIPSet.Name
                                ID = $NSXIPSet.ObjectID
                                Description = $NSXIPSet.Description
                                'Is Universal' = $NSXIPSet.IsUniversal
                                'Inheritance Allowed' = $NSXIPSet.InheritanceAllowed
                                Members = ($NSXIPSet.Value -join ", ")
                            }
                        }
                        $NSXIPSetConfiguration | Table -Name 'IP Sets'
                    }#End Section IP Sets
                }#End if NSX IP Sets

                if ($NSXMacSets){
                    Section -Style Heading3 'Mac Sets' {
                        $NSXMacSetConfiguration = foreach ($NSXMacSet in $NSXMacSets){
                            [PSCustomObject]@{
                                Name = $NSXMacSet.Name
                                ID = $NSXMacSet.ObjectID
                                Description = $NSXMacSet.Description
                                'Is Universal' = $NSXMacSet.IsUniversal
                                'Inheritance Allowed' = $NSXMacSet.InheritanceAllowed
                                Members = ($NSXMacSet.Value -join ", ")
                            }
                        }
                        $NSXMacSetConfiguration | Table -Name 'Mac sets'
                    }#End Section Mac sets
                }#End if NSX Mac Sets

            }
            #Disconnect from the NSX Manager Server
            Disconnect-NsxServer
        }
    }
}