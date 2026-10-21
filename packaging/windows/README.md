# Windows packaging

`Ginkgo.iss` builds the single-file Inno Setup installer from an already verified portable release bundle. The workflow passes the extracted bundle through `/DBundleDir` and packages the installer for the existing `windows-v0.1.0-alpha.4` release.

`ChineseSimplified.isl` is the official Inno Setup Simplified Chinese language file, vendored from `jrsoftware/issrc` commit `1893601e5a3271000579777df8f347eb4df664cb` (Inno Setup 6.5.0+). Its maintainer and translation attribution are retained in the file header. Keeping it in the repository makes installer builds independent of the language files bundled with a particular Chocolatey package.
