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



# the following removal steps are copied from Uninstall.ps1 - they are executed here for safety, in case for some reason Uninstall.ps1 hasn't been executed
# TODO: move the removal steps into a separate file and call from both scripts

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



# work out relative path to targets
$absolutePath = Join-Path $toolsPath "StyleCop.targets"
$absoluteUri = New-Object -typename System.Uri -argumentlist $absolutePath
$projectUri = New-Object -typename System.Uri -argumentlist $project.FullName
$relativeUri = $projectUri.MakeRelativeUri($absoluteUri)
$relativePath = [System.URI]::UnescapeDataString($relativeUri.ToString()).Replace([System.IO.Path]::AltDirectorySeparatorChar, [System.IO.Path]::DirectorySeparatorChar)

# add import
$import = $projectXml.CreateElement('Import', $namespace)
$import.SetAttribute('Condition', "Exists('$relativePath')")
$import.SetAttribute('Project', $relativePath)
$projectXml.Project.AppendChild($import)

# add StyleCopMSBuildCheckTargetsFile target
$target = $projectXml.CreateElement('Target', $namespace)
$target.SetAttribute('Name', 'StyleCopMSBuildCheckTargetsFile')

$message = "Failed to find file '$relativePath'. The StyleCop.MSBuild package is either missing or incomplete. If you are building manually using an IDE (e.g. Visual Studio), ensure that the package is present and then (IMPORTANT) reload the project in order to import the targets. Otherwise, ensure that the package is present and then restart the build."

$warning = $projectXml.CreateElement('Warning', $namespace)
$warning.SetAttribute('Condition', "!Exists('$relativePath') And `$(StyleCopTreatErrorsAsWarnings)!=false And `$(RestorePackages)!=true")
$warning.SetAttribute('Text', "$message")
$target.AppendChild($warning)

$error = $projectXml.CreateElement('Error', $namespace)
$error.SetAttribute('Condition', "!Exists('$relativePath') And `$(StyleCopTreatErrorsAsWarnings)==false And `$(RestorePackages)!=true")
$error.SetAttribute('Text', "$message")
$target.AppendChild($error)

$messageRestore = "Failed to find file '$relativePath'. The StyleCop.MSBuild package has not been restored. If you are building manually using an IDE (e.g. Visual Studio), restore the StyleCop.MSBuild package and then (IMPORTANT) reload the project in order to import the targets. If you are building manually without using an IDE, restore the StyleCop.MSBuild package and then restart the build. If this is an automated build (e.g. CI server), ensure that the build process restores the StyleCop.MSBuild package before the project is built."

$warningRestore = $projectXml.CreateElement('Warning', $namespace)
$warningRestore.SetAttribute('Condition', "!Exists('$relativePath') And `$(StyleCopTreatErrorsAsWarnings)!=false And `$(RestorePackages)==true")
$warningRestore.SetAttribute('Text', "$messageRestore")
$target.AppendChild($warningRestore)

$errorRestore = $projectXml.CreateElement('Error', $namespace)
$errorRestore.SetAttribute('Condition', "!Exists('$relativePath') And `$(StyleCopTreatErrorsAsWarnings)==false And `$(RestorePackages)==true")
$errorRestore.SetAttribute('Text', "$messageRestore")
$target.AppendChild($errorRestore)

$projectXml.Project.AppendChild($target)

# TODO: replace this with adding the target to InitialTargets to ensure it runs before package restore
# (using BuildDependsOn, if package restore is enabled after installation of StyleCop.MSBuild then package restore will run before StyleCopMSBuildCheckTargetsFile)
# add StyleCopMSBuildCheckTargetsFile target to BuildDependsOn property
$propertyGroup = $projectXml.CreateElement('PropertyGroup', $namespace)
$buildDependsOn = $projectXml.CreateElement('BuildDependsOn', $namespace)
$buildDependsOn.AppendChild($projectXml.CreateTextNode('StyleCopMSBuildCheckTargetsFile;$(BuildDependsOn);'))
$propertyGroup.AppendChild($buildDependsOn)
$projectXml.Project.AppendChild($propertyGroup)

# save changes
$projectXml.Save($project.FullName)