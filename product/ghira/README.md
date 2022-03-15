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
cd path/to/devspaces/product/ghira
pip install -q --upgrade pip
virtualenv-3 .
. bin/activate
pip install -r requirements.txt
```

## execution

Secrets are injected through environment variables.  

```
export JIRA_EMAIL="jirauser@email.address"
export JIRA_TOKEN='jirauser_personal_access_token'
export GITHUB_TOKEN="github_api_token"
```

To create a new token, go to https://id.atlassian.com/manage-profile/security/api-tokens and log in as the above user (with password)

Use these flags to control output:

```
--debug     Enable verbose mode 
--dryrun    Query for issues to create, but do not create JIRAs or update GH issues
--weeks n   Limit query to the last n weeks (default: 2)
```

Run as follows:
```
python3 ghira --dryrun
```
