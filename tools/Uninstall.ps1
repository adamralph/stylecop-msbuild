#  Copyright (c) Adam Ralph. All rights reserved.

param($installPath, $toolsPath, $package, $project)

Import-Module (Join-Path $toolsPath "Remove.psm1")

# save any unsaved changes before we start messing about with the project file on disk
$project.Save()

# read project XML
$projectXml = New-Object System.Xml.XmlDocument
$projectXml.Load($project.FullName)
$namespace = 'http://schemas.microsoft.com/developer/msbuild/2003'

# remove changes
Remove-Changes $projectXml $namespace

# save changes
$projectXml.Save($project.FullName)