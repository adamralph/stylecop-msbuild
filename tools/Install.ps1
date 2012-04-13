param($installPath, $toolsPath, $package, $project)

# remove and delete content hook
$hook = "StyleCop.MSBuild.Deleteme.txt"
$project.ProjectItems.Item($hook).Remove();
[System.IO.FILE]::Delete([System.IO.PATH]::COMBINE([System.IO.PATH]::GETDIRECTORYNAME($project.FullName), $hook))

# add import to project file
$targetsPath = [System.IO.PATH]::COMBINE($toolsPath, "StyleCop.targets")
# TODO: open the file, play with the XML, save the file