#  Copyright (c) Adam Ralph. All rights reserved.

param($installPath, $toolsPath, $package, $project)

Import-Module (Join-Path $toolsPath "Remove.psm1")

# remove content hook from project and delete file
$hookName = "StyleCop.MSBuild.ContentHook.txt"
$project.ProjectItems.Item($hookName).Remove();
Split-Path $project.FullName -parent | Join-Path -ChildPath $hookName | Remove-Item

# save removal of content hook and any other unsaved changes to project before we start messing about with project file
$project.Save()

# read project XML
$projectXml = New-Object System.Xml.XmlDocument
$projectXml.Load($project.FullName)
$namespace = 'http://schemas.microsoft.com/developer/msbuild/2003'

# remove previous changes - executed here for safety, in case for some reason Uninstall.ps1 hasn't been executed
Remove-Changes $projectXml $namespace

# determine relative path to targets
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

# add target
$target = $projectXml.CreateElement('Target', $namespace)
$target.SetAttribute('Name', 'StyleCopMSBuildTargetsNotFound')

$message = "Failed to import StyleCop.MSBuild targets from '$relativePath'. The StyleCop.MSBuild package was either missing or incomplete when the project was loaded. If you are building manually using an IDE (e.g. Visual Studio), restore the package manually and then reload the project. If you are building manually without using an IDE, restore the package manually and then restart the build. If this is an automated build (e.g. CI server), ensure that the build process restores the package before the project is built. Note that 'standard' NuGet package restore (during build) does not work with this package because the package needs to be present before the project is loaded."

$warning = $projectXml.CreateElement('Warning', $namespace)
$warning.SetAttribute('Condition', "`$(StyleCopTreatErrorsAsWarnings)!=false")
$warning.SetAttribute('Text', $message)
$target.AppendChild($warning)

$error = $projectXml.CreateElement('Error', $namespace)
$error.SetAttribute('Condition', "`$(StyleCopTreatErrorsAsWarnings)==false")
$error.SetAttribute('Text', $message)
$target.AppendChild($error)

$projectXml.Project.AppendChild($target)

# inject target into build
$propertyGroup = $projectXml.CreateElement('PropertyGroup', $namespace)
$dependsOn = $projectXml.CreateElement('PrepareForBuildDependsOn', $namespace)
$dependsOn.SetAttribute('Condition', "!Exists('$relativePath')")
$dependsOn.AppendChild($projectXml.CreateTextNode('StyleCopMSBuildTargetsNotFound;$(PrepareForBuildDependsOn)'))
$propertyGroup.AppendChild($dependsOn)
$projectXml.Project.AppendChild($propertyGroup)

# save changes
$projectXml.Save($project.FullName)