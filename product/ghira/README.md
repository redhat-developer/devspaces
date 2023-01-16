# ghira, a Github to JIRA copy tool

Search for Github issues closed in the last 2 weeks, labelled with https://github.com/eclipse/che/labels/new%26noteworthy 
Create corresponding JIRAs in https://issues.redhat.com/browse/CRW to faciliate tracking/agile processes.

Note: Re-running this tool will not create duplicates, as a comment will be left in the GH issue to indicate a copy has already been created in JIRA.

## installation

1. install venv

```
curl https://pyenv.run | bash
```

The follow install instructions on console, to add to ~/.bashrc

3. Create virtualenv and install requirements:

```
sudo dnf install -yq python3-virtualenv redhat-rpm-config gcc libffi-devel python3-devel openssl-devel cargo rust
cd path/to/devspaces/product/ghira
pip install -q --upgrade pip
virtualenv .
. bin/activate
pip install -r requirements.txt
```

## execution

Secrets are injected through environment variables.  

```
export JIRA_EMAIL="jiralint-codeready@redhat.com"          # this may change since this bot is no longer able to login as of Jan 12 2023 to create a new token
export JIRA_TOKEN="$(cat jira-jiralint-token)"             # see https://gitlab.cee.redhat.com/codeready-workspaces/crw-jenkins/-/blob/master/secrets/jira-jiralint-token
export GITHUB_TOKEN="$(cat crw_devstudio-release-token)"   # see https://gitlab.cee.redhat.com/codeready-workspaces/crw-jenkins/-/blob/master/secrets/crw_devstudio-release-token
```

To create a new token, go to https://id.atlassian.com/manage-profile/security/api-tokens and log in as the above user (with password)

Use these flags to control output:

```
--debug     Enable verbose mode 
--dryrun    Query for issues to create, but do not create JIRAs or update GH issues
--days n    Limit query to the last n days (default: 14)
--weeks n   Limit query to the last n weeks
--limit x   Limit query within the date range to no more than x results
```

Run as follows:
```
python3 ghira --days 5 --limit 3 --dryrun --debug 
```
