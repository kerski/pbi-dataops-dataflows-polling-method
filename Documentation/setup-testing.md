# Building and Running Tests
These instructions setup testing for local users and for the pipeline.

## Table of Contents

1. [Setting up the Dataset for User Testing](#setting-up-the-dataset-for-user-testing)
2. [Setting up the Dataset for the Pipeline](#setting-up-the-dataset-for-the-pipeline)

## Setting up the Dataset for User Testing
In order to be able to test locally, you need to have a test dataset in the workspace that houses your dataflows.  The following describes how to setup the test dataset for a new user:

1. In PowerShell Terminal, enter the "$env:USERNAME". Copy that text for use later in these instructions.

![Username](./images/username.png)

2. Go to the workspace that houses your dataflow and then click on a dataflow you will be testing. Copy the Workspace ID (circled in orange below) and Dataflow ID (outlined in red below) and save for use later in these instructions.

![Workspace ID and Dataflow ID](./images/url-example.png)

3. Open the template file labeled DFTest-ServiceAccount.pbit located in this project's path "TestingScripts\Custom\Templates"

![Template](./images/dftest-serviceaccount.png)

4. A template popup will appear.

![Template Popup](./images/template-popup.png)

5. When the template's popup appears enter the Workspace ID and Dataflow ID you copied in step 2.  Enter "XYZ" in the text box for Run_ID.  Then press load.

![Template Popup Filled out](./images/template-popup-2.png)

6. When the template loads the data, go to File and select Save As.  Enter the name "DFTest-{USERNAME}" and replace "{USERNAME} with the username you copied in step 1.

![Save Template](./images/save-template.png)

7. Publish to the workspace which houses your dataflows.  If you do not know how to publish this file, please read the instructions: [Publish datasets and reports from Power BI Desktop](https://learn.microsoft.com/en-us/power-bi/create-reports/desktop-upload-desktop-files)

8. You can now follow the instructions to [run tests locally](./run-tests.md).

## Setting up the Dataset for the Pipeline
To be able to test in the Azure DevOps pipeline, you need to repeat the steps described in [Setting up the Dataset for User Testing](#setting-up-the-dataset-for-user-testing), and use the user account that was provided during the [Installation Instructions](./README.md#Installation-Steps).  During step 6, please name the file as DFTest-ServiceAccount.pbix.
