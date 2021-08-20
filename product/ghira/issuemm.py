#!/usr/bin/env python3
import sys
import os
import copy
import re
import json
import logging
import smtplib
import datetime
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart

from github import Github
import mattermost

GITHUB_KEY = os.environ.get("GITHUB_KEY")
GITHUB_REPO = "eclipse/che"

MATTERMOST_URL = os.environ.get("MATTERMOST_URL") or "https://mattermost.eclipse.org/api"
MATTERMOST_LOGIN = os.environ.get("MATTERMOST_LOGIN")
MATTERMOST_PW = os.environ.get("MATTERMOST_PW")
MATTERMOST_TEAM = os.environ.get("MATTERMOST_TEAM") or "eclipse"
MATTERMOST_CHANNEL = os.environ.get("MATTERMOST_CHANNEL") or "ghira_testing"

# LOG_LEVEL = logging.DEBUG
LOG_LEVEL = logging.INFO
class ExitOnErrorHandler(logging.StreamHandler):
    def emit(self, record):
        super().emit(record)
        if record.levelno in (logging.ERROR, logging.CRITICAL):
            raise SystemExit(-1)
logging.basicConfig(handlers=[ExitOnErrorHandler()], format='%(levelname)s: %(message)s', level=LOG_LEVEL)

DRY_RUN='--dryrun' in sys.argv
if DRY_RUN:
  logging.info("Dry run.  Nothing will be created.")

g = Github(GITHUB_KEY)
r = g.get_repo(GITHUB_REPO)
GITHUB_USER = g.get_user().login
mm = mattermost.MMApi(MATTERMOST_URL)
mm.login(MATTERMOST_LOGIN, MATTERMOST_PW)

# Retrieve Issues from github
d = datetime.datetime.now() - datetime.timedelta(days=3)
issue_search = {
  'state': 'open',
  'since': d
}
all_issues = r.get_issues(**issue_search)

# filter messages that need some attention
pending_issues = []
for i in all_issues:
  skip = False
  labels = []
  for l in i.raw_data['labels']:
    l = l['name']
    if l.startswith("area") or l.startswith("team") or l.endswith("need-triage"):
      skip = True
      break
  if skip:
    continue
  pending_issues.append(i)

# post message on matermost
if pending_issues:
  team = None
  for t in mm.get_teams():
    if t['name'] == MATTERMOST_TEAM:
      team = t
      break
  c = mm.get_channel_by_name(t['id'], MATTERMOST_CHANNEL)
  issue_urls = [i.raw_data['html_url'] for i in pending_issues]
  msg = "The following github issues need an area, team or to be triaged:\n - %s" % '\n - '.join(issue_urls)
  logging.info(msg)
  if not DRY_RUN:
    mm.create_post(c['id'], msg)