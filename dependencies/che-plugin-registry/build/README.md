# Build

This tool is currently generating data at build time so we can remove all plug-ins from the v3/plugins folder that are VS Code Extensions

This tool generates:
- v3/plugins/**/meta.yaml and v3/plugins/**/latest.txt based on the file `che-theia-plugins.yaml``
- v3/che-theia/featured.json which defines the recommended plug-ins when no plug-in is set in che-theia
- v3/che-theia/recommendations/<language>.json with recommendations per language

## Help

There is a command that is invoked in the Dockerfile to generate these files
Script used is `generate_vscode_extensions.sh` 
