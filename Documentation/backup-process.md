# Backup Process Overview

## Table of Contents

1. [Backup Process](#backup-process)
    1. [Security Notes](#security-notes)
    1. [Restoring a Dataflow](#restoring-a-dataflow)

## Backup Process

Using the method, dataflows are polled for changes at regular intervals and commit those changes to an <a href="https://learn.microsoft.com/en-us/azure/devops/repos/get-started/what-is-repos?view=azure-devops" target="_blank">Azure Repo</a> (see Figure 1).

![Figure 1](./images/backup-process.png)

*Figure 1 - Illustrates the high-level polling process and components used to backup dataflows to Git.*
<br/>
This polling process is driven by two YAML files:

1) **Dataflow-Polling-and-Backup-Schedule-Dev** - This file runs on a scheduled interval and kicks off the second YAML file. The setup will prevent an infinite loop from occurring in future iterations of this solution when we want a branch update to trigger a continuous integration (CI) process (hint: it involves my favorite topic).

2) **Dataflow-Polling-and-Backup** - This file runs the Start-DataflowBackup.ps1 process, which includes:

-   Loading and installing the appropriate PowerShell modules.

-   Logging into the Power BI Service using an account (see security notes).

-   Retrieving the list of Power BI dataflows.

-   Checking if the Azure Repo (I also use the term repo and repository synonymously with Azure Repo) has the dataflow. If not, it adds the dataflow to the repository. If the dataflow does exist, the script inspects the "modifiedTime" properties to review timestamps. If they do not match, we commit a new version to the repository.

![Figure 2](./images/yaml.png)

*Figure 2 - Illustrates how two YAML files implement the Polling Method.*

### Security Notes

The polling method is dependent on two major security components:

1) A Premium Per User (PPU) account that can log in to the Power BI service and access the workspace housing the dataflows.

2) A Personal Access Token (PAT) that can access the repository storing the dataflows.

### Restoring a dataflow

To revert to a prior dataflow, download the JSON file from the repository and import it into your Power BI workspace. If the dataflow already exists, it will append a number to the end of the new one. You'll have to delete the old one and relink any dependencies...a pain, but at least you have a version to restore.