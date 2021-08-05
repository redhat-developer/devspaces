# ghira

Search for github issues and create corresponding jira issues.  Running multiple
times will not create duplicates.  A github comment will be left in the issue as a 
tag to determine if it already has a corresponding jira issue.


## installation

Create virtualenv/pyenv and install requirments:

```
pyenv virtualenv 3.8.7 ghira
pyenv local ghira
pip install -r requirements.txt
```

## execution

Secrets are injected through environment variables.  Currently only one parameter '--dryrun'
which can be used to run without creating anything.

```
export JIRA_USER="jirauser"
export JIRA_PASSWORD='jirauser_password'
export GITHUB_KEY="github_api_key"
ghira --dryrun
```