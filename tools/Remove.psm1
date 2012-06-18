#  Copyright (c) Adam Ralph. All rights reserved.

function Remove-Changes {
    param(
        [parameter(Position = 0, Mandatory = $true)]
        [System.Xml.XmlDocument]$projectXml,
        
        [parameter(Position = 1, Mandatory = $true)]
        [string]$namespace
    )

    # remove from initial targets (was added in beta releases)
    $initialTargets = $projectXml.Project.GetAttribute('InitialTargets').Split(";", [System.StringSplitOptions]::RemoveEmptyEntries) | select -uniq | where {$_ -ne 'StyleCopMSBuildCheckTargetsFile'}
    if ($initialTargets)
    {
        $projectXml.Project.SetAttribute('InitialTargets', [string]::Join(";", $initialTargets))
    }
    else
    {
        $projectXml.Project.RemoveAttribute('InitialTargets')
    }

    # remove from properties (targets were added to BuildDependsOn in beta releases)
    $properties = Select-Xml "//msb:Project/msb:PropertyGroup/msb:PrepareForBuildDependsOn[contains(.,'StyleCopMSBuild')] | //msb:Project/msb:PropertyGroup/msb:BuildDependsOn[contains(.,'StyleCopMSBuild')]" $projectXml -Namespace @{msb = $namespace}
    if ($properties)
    {
        foreach ($property in $properties)
        {
            $propertyGroup = $property.Node.ParentNode
            $propertyGroup.RemoveChild($property.Node)
            if (!$propertyGroup.HasChildNodes)
            {
                $propertyGroup.ParentNode.RemoveChild($propertyGroup)
            }
        }
    }
    
    # remove targets
    $targets = Select-Xml "//msb:Project/msb:Target[contains(@Name,'StyleCopMSBuild')]" $projectXml -Namespace @{msb = $namespace}
    if ($targets)
    {
        foreach ($target in $targets)
        {
            $target.Node.ParentNode.RemoveChild($target.Node)
        }
    }

    # remove imports
    $imports = Select-Xml "//msb:Project/msb:Import[contains(@Project,'\StyleCop.MSBuild.')]" $projectXml -Namespace @{msb = $namespace}
    if ($imports)
    {
        foreach ($import in $imports)
        {
            $import.Node.ParentNode.RemoveChild($import.Node)
        }
    }
}