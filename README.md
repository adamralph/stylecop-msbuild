# What

See [Introducing StyleCop.MSBuild](http://adamralph.com/2012/04/17/introducing-stylecop-msbuild/) for an introduction to StyleCop.MSBuild.

This is the project site for the StyleCop.MSBuild package only. For information about the main StyleCop project and for raising feature requests or ideas about StyleCop itself (e.g. C# 6 support), see the [StyleCop project site](http://stylecop.codeplex.com/).

### C# 6 (or later)

StyleCop is a re-packaging of the [official StyleCop project](http://stylecop.codeplex.com/). Currently, StyleCop does not support C# 6, which means StyleCop.MSBuild does not support it either. For more information on C# 6 support, see the [StyleCop project](http://stylecop.codeplex.com/).

# Where

Download the StyleCop.MSBuild package from [the NuGet gallery](http://nuget.org/packages/StyleCop.MSBuild). For update notifications, follow [@adamralph](https://twitter.com/#!/adamralph).

# How

Come and chat to fellow developers about StyleCop and StyleCop.MSBuild in the [StyleCop JabbR chat room](https://jabbr.net/#/rooms/stylecop).

# Tips

* To run StyleCop analysis *before* other build steps, e.g. compilation, code analysis, etc. you can add the following to your .csproj file directly after the import of the StyleCop targets:

```
  <PropertyGroup>
    <BuildDependsOn>$([MSBuild]::Unescape($(BuildDependsOn.Replace(";StyleCop", "").Insert($(BuildDependsOn.IndexOf("BeforeBuild;")),"StyleCop;"))))</BuildDependsOn>
  </PropertyGroup>
```

* StyleCop.MSBuild may not run on a new machine with only the latest MSBuild and or Visual Studio installed. If you see a build failure complaining about a missing assembly 'Microsoft.Build.Utilities.v3.5', try installing '.NET Framework 3.5' from Windows features.
