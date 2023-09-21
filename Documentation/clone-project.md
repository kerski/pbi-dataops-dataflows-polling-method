# Cloning a Project
This serves as a guide for clong this project.

# Table of Contents

1. [Getting Started](#getting-started)
1. [Prerequisites](#prerequisites)
1. [Clone Project](#clone-project)

# Getting Started
##	Prerequisites

- Complete [installation instructions](README.md)

### Desktop
- If you're not familiar with Git, please see Lessons 1-2 on <a href="https://www.simplilearn.com/tutorials/git-tutorial/git-tutorial-for-beginner" target="_blank">this site</a>.
- Download and install <a href="https://code.visualstudio.com/">Visual Studio Code</a>.

### Azure DevOps
-  Signed up for <a href="https://docs.microsoft.com/en-us/azure/devops/user-guide/sign-up-invite-teammates?view=azure-devops" target="_blank">Azure DevOps</a>.

## Clone Project
Azure DevOps is a product that can host a repository (a.k.a. repo).  This repo is the central area where the Power BI dataflows and other files related to this project are stored.  In order to make updates to these files you need to "clone" the project to your local machine. This operates similarly to how OneDrive files in the cloud appear in a folder on your laptop.  Please follow the instructions below to clone the project.

1. Navigate to the project created during the installation steps located on the Azure DevOps site. Click on the Repos section and select the Clone button (outlined in orange in the image below).  

2. Click the "Clone in VS Code" button.

![Clone Repository](./images/clone-repository.png)

3. You may be prompted by a couple of pop-ups.  Please accept.

![Clone Popup](./images/clone-popup.png)

4. Next you will be prompted to select where you want to clone the repository on your computer.  Please select an appropriate location.  One suggestion would be to have a folder called "Git" and then place this project there.

5. If all goes well, Visual Studio Code will open and you will be prompted to open the project.  I suggest clicking the "Open in New Window" button.

![Clone Message](./images/clone-message.png)

6. From Visual Studio Code click the terminal menu option and select "New Terminal".

![Terminal](./images/terminal.png)

7. From the terminal run: "Get-ChildItem -Path '.' -Recurse | Unblock-File"

This will allow us to run the Powershell scripts locally

8. From the terminal run: "git checkout development". 

![Git Checkout](./images/git-checkout.png)

This will move you to the development branch where you should be performing your updates.  You can verify that you are in the right branch by looking at the bottom right of Visual Studio.  If you see "development", you've successfully completed this step.

![Git Checkout](./images/part-x-branch.png)

9. Your project is now setup for developing.  Sometimes Visual Studio code will ask you if you want to call Git Fetch on your behalf.  Choose yes and this will provide updates from the repository in Azure DevOps.

