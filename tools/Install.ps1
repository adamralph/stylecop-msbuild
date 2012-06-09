#  Copyright (c) Adam Ralph. All rights reserved.

param($installPath, $toolsPath, $package, $project)

# remove content hook from project and delete file
$hookName = "StyleCop.MSBuild.ContentHook.txt"
$project.ProjectItems.Item($hookName).Remove();
Split-Path $project.FullName -parent | Join-Path -ChildPath $hookName | Remove-Item

# save any unsaved changes to project before we start messing about with project file
$project.Save()

# read in project XML
$projectXml = [xml](Get-Content $project.FullName)
$namespace = 'http://schemas.microsoft.com/developer/msbuild/2003'

# remove current StyleCopMSBuildCheckTargetsFile targets
$nodes = @(Select-Xml "//msb:Project/msb:Target[@Name='StyleCopMSBuildCheckTargetsFile']" $projectXml -Namespace @{msb = $namespace} | Foreach {$_.Node})
if ($nodes)
{
    foreach ($node in $nodes)
    {
        $node.ParentNode.RemoveChild($node)
    }
}

# remove current import nodes
$nodes = @(Select-Xml "//msb:Project/msb:Import[contains(@Project,'\StyleCop.MSBuild.')]" $projectXml -Namespace @{msb = $namespace} | Foreach {$_.Node})
if ($nodes)
{
    foreach ($node in $nodes)
    {
        $node.ParentNode.RemoveChild($node)
    }
}

# work out relative path to targets
$absolutePath = Join-Path $toolsPath "StyleCop.targets"
$absoluteUri = New-Object -typename System.Uri -argumentlist $absolutePath
$projectUri = New-Object -typename System.Uri -argumentlist $project.FullName
$relativeUri = $projectUri.MakeRelativeUri($absoluteUri)
$relativePath = [System.URI]::UnescapeDataString($relativeUri.ToString()).Replace('/', '\');

# add StyleCopMSBuildCheckTargetsFile target
$target = $projectXml.CreateElement('Target', $namespace)
$target.SetAttribute('Name', 'StyleCopMSBuildCheckTargetsFile')
$error = $projectXml.CreateElement('Error', $namespace)
$error.SetAttribute('Condition', "!Exists('$relativePath')")
$error.SetAttribute('Text', "The StyleCop.MSBuild package is either incomplete or missing. Failed to find file '$relativePath'.")
$target.AppendChild($error)
$projectXml.Project.AppendChild($target)

# add StyleCopMSBuildCheckTargetsFile to initial targets
$initialTargets = $projectXml.Project.GetAttribute('InitialTargets').Split(";", [System.StringSplitOptions]::RemoveEmptyEntries) + 'StyleCopMSBuildCheckTargetsFile' | select -uniq
$projectXml.Project.SetAttribute('InitialTargets', [string]::Join(";", $initialTargets))

# add new import
$import = $projectXml.CreateElement('Import', $namespace)
$import.SetAttribute('Condition', "Exists('$relativePath')")
$import.SetAttribute('Project', $relativePath)
$projectXml.Project.AppendChild($import)

# save changes
$projectXml.Save($project.FullName)