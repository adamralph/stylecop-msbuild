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

$messageMissing = "Failed to import StyleCop.MSBuild targets from '$relativePath'. The StyleCop.MSBuild package was either missing or incomplete when the project was loaded. Ensure that the package is present and then restart the build. If you are using an IDE (e.g. Visual Studio), reload the project before restarting the build."
$messageRestore = "Failed to import StyleCop.MSBuild targets from '$relativePath'. The StyleCop.MSBuild package was either missing or incomplete when the project was loaded. To fix this, restore the package and then restart the build. If you are using an IDE (e.g. Visual Studio), you may need to reload the project before restarting the build. Note that regular NuGet package restore (during build) does not work with this package because the package needs to be present before the project is loaded. If this is an automated build (e.g. CI server), ensure that the build process restores the StyleCop.MSBuild package before the project is built."
$messagePresent = "Failed to import StyleCop.MSBuild targets from '$relativePath'. The StyleCop.MSBuild package was either missing or incomplete when the project was loaded. To fix this, restart the build. If you are using an IDE (e.g. Visual Studio), reload the project before restarting the build. Note that when using regular NuGet package restore (during build) the package will not be available for the initial build because the package needs to be present before the project is loaded. If package restore executes successfully in the intitial build then the package will be available for subsequent builds. If this is an automated build (e.g. CI server), you may want to ensure that the build process restores the StyleCop.MSBuild package before the initial build."

$warningMissing = $projectXml.CreateElement('Warning', $namespace)
$warningMissing.SetAttribute('Condition', "!Exists('$relativePath') And `$(RestorePackages)!=true And `$(StyleCopTreatErrorsAsWarnings)!=false")
$warningMissing.SetAttribute('Text', $messageMissing)
$target.AppendChild($warningMissing)

$errorMissing = $projectXml.CreateElement('Error', $namespace)
$errorMissing.SetAttribute('Condition', "!Exists('$relativePath') And `$(RestorePackages)!=true And `$(StyleCopTreatErrorsAsWarnings)==false")
$errorMissing.SetAttribute('Text', $messageMissing)
$target.AppendChild($errorMissing)

$warningRestore = $projectXml.CreateElement('Warning', $namespace)
$warningRestore.SetAttribute('Condition', "!Exists('$relativePath') And `$(RestorePackages)==true And `$(StyleCopTreatErrorsAsWarnings)!=false")
$warningRestore.SetAttribute('Text', $messageRestore)
$target.AppendChild($warningRestore)

$errorRestore = $projectXml.CreateElement('Error', $namespace)
$errorRestore.SetAttribute('Condition', "!Exists('$relativePath') And `$(RestorePackages)==true And `$(StyleCopTreatErrorsAsWarnings)==false")
$errorRestore.SetAttribute('Text', $messageRestore)
$target.AppendChild($errorRestore)

$warningPresent = $projectXml.CreateElement('Warning', $namespace)
$warningPresent.SetAttribute('Condition', "Exists('$relativePath') And `$(StyleCopTreatErrorsAsWarnings)!=false")
$warningPresent.SetAttribute('Text', $messagePresent)
$target.AppendChild($warningPresent)

$errorPresent = $projectXml.CreateElement('Error', $namespace)
$errorPresent.SetAttribute('Condition', "Exists('$relativePath') And `$(StyleCopTreatErrorsAsWarnings)==false")
$errorPresent.SetAttribute('Text', $messagePresent)
$target.AppendChild($errorPresent)

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