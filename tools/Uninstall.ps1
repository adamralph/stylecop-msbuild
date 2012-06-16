#  Copyright (c) Adam Ralph. All rights reserved.

param($installPath, $toolsPath, $package, $project)

# save any unsaved changes before we start messing about with the project file on disk
$project.Save()

# read in project XML
$projectXml = New-Object System.Xml.XmlDocument
$projectXml.Load($project.FullName)
$namespace = 'http://schemas.microsoft.com/developer/msbuild/2003'

# remove addition(s) of StyleCopMSBuildCheckTargetsFile target to BuildDependsOn property
$buildDependsOns = Select-Xml "//msb:Project/msb:PropertyGroup/msb:BuildDependsOn[contains(.,'StyleCopMSBuildCheckTargetsFile')]" $projectXml -Namespace @{msb = $namespace}
if ($buildDependsOns)
{
    foreach ($buildDependsOn in $buildDependsOns)
    {
        $propertyGroup = $buildDependsOn.Node.ParentNode
        $propertyGroup.RemoveChild($buildDependsOn.Node)
        if (!$propertyGroup.HasChildNodes)
        {
            $propertyGroup.ParentNode.RemoveChild($propertyGroup)
        }
    }
}

# remove StyleCopMSBuildCheckTargetsFile target(s)
$targets = Select-Xml "//msb:Project/msb:Target[@Name='StyleCopMSBuildCheckTargetsFile']" $projectXml -Namespace @{msb = $namespace}
if ($targets)
{
    foreach ($target in $targets)
    {
        $target.Node.ParentNode.RemoveChild($target.Node)
    }
}

# remove import(s)
$imports = Select-Xml "//msb:Project/msb:Import[contains(@Project,'\StyleCop.MSBuild.')]" $projectXml -Namespace @{msb = $namespace}
if ($imports)
{
    foreach ($import in $imports)
    {
        $import.Node.ParentNode.RemoveChild($import.Node)
    }
}

# save changes
$projectXml.Save($project.FullName)