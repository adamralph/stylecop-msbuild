param($installPath, $toolsPath, $package, $project)

# remove and delete content hook
$hookName = "StyleCop.MSBuild.ContentHook.SafeToDelete.txt"
$project.ProjectItems.Item($hookName).Remove();
[System.IO.FILE]::Delete([System.IO.PATH]::COMBINE([System.IO.PATH]::GETDIRECTORYNAME($project.FullName), $hookName))

# save any unsaved changes before we start messing about with the project file on disk
$project.Save()

# read in project XML
$projectXml = [xml](Get-Content $project.FullName)
$namespace = 'http://schemas.microsoft.com/developer/msbuild/2003'

# remove old imports
$nodes = @(Select-Xml "//msb:Project/msb:Import[contains(@Project,'\packages\StyleCop.MSBuild.')]" $projectXml -Namespace @{msb = $namespace} | Foreach {$_.Node})
if ($nodes)
{
    foreach ($node in $nodes)
    {
        $parentNode = $node.ParentNode
        [void]$parentNode.RemoveChild($node)
    }
}

# work out relateive path to targets
$absolutePath = [System.IO.PATH]::COMBINE($toolsPath, "StyleCop.targets")
$absoluteUri = New-Object -typename System.Uri -argumentlist $absolutePath
$projectUri = New-Object -typename System.Uri -argumentlist $project.FullName
$relativeUri = $projectUri.MakeRelativeUri($absoluteUri)
$relativePath = [System.URI]::UnescapeDataString($relativeUri.ToString());
$relativePath = $relativePath.Replace('/', [System.IO.PATH]::DirectorySeparatorChar);

# add new import
$import = $projectXml.CreateElement('Import', $namespace)
$import.SetAttribute('Project', $relativePath)
$projectXml.Project.AppendChild($import)

# save changes
$projectXml.Save($project.FullName)