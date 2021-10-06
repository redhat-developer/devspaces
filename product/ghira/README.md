# ghira, a Github to JIRA copy tool

Search for Github issues closed in the last 2 weeks, labelled with https://github.com/eclipse/che/labels/new%26noteworthy 
Create corresponding JIRAs in https://issues.redhat.com/browse/CRW to faciliate tracking/agile processes.

Note: Re-running this tool will not create duplicates, as a comment will be left in the GH issue to indicate a copy has already been created in JIRA.

## installation

Create virtualenv/pyenv and install requirments:

```
pyenv virtualenv 3.8.7 ghira
pyenv local ghira
pip install -r requirements.txt
```

Or

```
sudo dnf install -yq python3-virtualenv redhat-rpm-config gcc libffi-devel python3-devel openssl-devel cargo rust
cd path/to/codeready-workspaces/product/ghira
pip install -q --upgrade pip
virtualenv-3 .
. bin/activate
pip install -r requirements.txt
```

## execution

Secrets are injected through environment variables.  

```
export JIRA_USER="jirauser"
export JIRA_PASSWORD='jirauser_password'
export GITHUB_KEY="github_api_key"
```

Use these flags to control output:

```
--debug   Enable verbose mode 
--dryrun  Query for issues to create, but do not create JIRAs or update GH issues
```

Run as follows:
```
python3 ghira --dryrun
```
