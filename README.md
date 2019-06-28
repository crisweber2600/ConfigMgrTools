# ConfigMgrTools

The PowerShell script covers the following items
- Pull down the latest code of the branch that you specify
- Get all of the CI's from ConfigMgr
- Check every Folder from GIT for CI info
    - Get that specific CI from all of the CIs pulled in Step 2
    - Remove script signing, and white space from discover and remediation
    - Compare discovery and remediation scripts from GIT to CM
    - If any differences than update the discovery and remediation scripts in the CIs SDMPackageXML
    - Push the code into CM
- Profit