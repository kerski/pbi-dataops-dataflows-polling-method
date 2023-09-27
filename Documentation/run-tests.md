# Building and Running Tests
These instructions define how to run tests locally and the taxonomy of the tests.

## Table of Contents

1. [Testing Structure](#getting-started)
    - [.feature file](#feature-file)
    - [.steps.ps1 file](#stepsps1-file)
        - [Background Tests](#background-tests)
        - [Schema Tests](#schema-tests)
        - [Content Tests](#content-tests)

2. [Running Tests](#running-tests)

## The Testing Structure

Building and running tests are based on the Behavior Drive Development
(BDD) concept. Pester Version 4's implementation of the Gherkin language
facilitates BDD testing by defining tests through written narratives and
acceptance criteria.

Building tests are based on two files:

### .feature file

This is the plain language explanation of the tests to be performed.  The screenshot below provides an example.

![Sample Feature](./images/feature-example.png)

### .steps.ps1 file

Each sentence in the feature file is backed by a ".steps.ps1" with the
same name as the feature file.

Since we want to take advantage of the same PowerShell code to run
similar schema and content tests, all ".steps.ps1" files reference the file
"Test-Support.steps.ps1".

The Test-Support.steps.ps1 file supports the following test cases:

#### Background Tests

##### Given 'that we have access to the DFTest file in the Workspace: "{Workspace}"'
Verifies that the workspace is accessible and the appropriate testing dataset exists in the workspace.

##### And 'we have access to the Dataflow: "DataflowName"'
Verifies that the dataflow exists and extracts the contents of the dataflow (as json)

##### And 'we have the table called "Table"'
Verifies that the table exists in the dataflow (and wasn't renamed for some reason)

##### And 'we can setup the table for testing'
This is the most critical steps in testing because this test:
- Updates the parameters of the testing dataset to point to the appropriate workspace and dataflow.
- Issues a synchronous dataset refresh and tests if the dataset successfully refreshes.

#### Schema Tests

##### Then "it should {Contain or Match} the schema defined as follows:"
This test accepts a table of information with the columns Name, Type, and Format such as:

	| Name          | Type  | Format |
	| Alignment     | string|        |

- Name: This is the name of the column.
- Type: This is the type of the column.
- Format: This is the format of the column.  You can leave this blank if format does not need to be tested.

This test accepts a parameter {Contain or Match}. If the parameter
entered is 'Contain' then this test will make sure each column exists
and matches the type and format. If the parameter entered is 'Match'
then this test will make sure the table has all the columns defined in
the test, that each column exists, and that each column matches the type
and format. The 'Match' value is strict and makes sure no new columns
exist in the dataset compared to the defined table in the feature file.

#### Content Tests

##### And 'the values of "{ColumnName}" matches this regex: "{Regex}"'
This function accepts the {ColumnName} parameter and {Regex} parameter.  This verifies that the column in the table passes the regular expression.  The Regular Expression format follows the [.Net Regular Expressions format](https://learn.microsoft.com/en-us/dotnet/standard/base-types/regular-expressions). 

##### And 'the values in "{ColumnName}" are unique'
This function accepts the {ColumnName} parameter and validates that are values in that column are unique.

##### And 'there should be {Comparison} than {Count} records returned'
This function accepts the {Comparison} parameter and {Count} parameter.  The {Comparison} parameter can be the following values:

 - exactly
 - less than
 - less than or equal to
 - greater than 
 - greater than or equal to

The {Count} parameter should be a number.

This test makes sure the number of records in the table meets expectation.  This is a good test to make sure tables aren't empty or test filters weren't left inadvertently.


##### And 'all tests should pass for the DAX query: {Test File}'
This function accepts the {Test File} parameter.  The {Test File} parameter is the name of the DAX file located in the dataflows folder.

This test executes the DAX query against the test dataset and inspects the test results return from the DAX Query.

The DAX query needs to output the following schema:

| Test Name                   | Expected Value  | Actual Value | Passed |
|:-----------------------------|:-------------|:------------------|:-------------|
| Text describing the test | The expected value in the appropriate format (e.g., number, boolean) | The actual value of the DAX calculation | A boolean indicated true if the test passed.  Otherwise the value is false.|

## Running Tests

This project has a script called "Run-DFTests.ps1" that exists at the root of the project.

This script allows you to run the tests you created for each Power BI dataflow.  Here are the steps:

1. Within Visual Studio Code, open your project folder.

2. Then within Visual Studio Code click the terminal menu option and select "New Terminal".

![Terminal](./images/new-terminal.png)

3. Then from the terminal enter the command './Run-DFTests.ps1 -Dataflow "{DataflowName}"'. Replace {DataflowName} which the name of the dataflow you wish to test.

![Run DFTests.ps1](./images/run-df-tests.png)

NOTE: During the course of the testing, you may be prompted to log into Office via pop-ups at least twice. This is to authenticate you with the Power BI Service.

5. If the test cases pass, then you will see in the terminal a confirmation of success with a message "SUCCESS: All test cases passed."

![Success DFTests](./images/success-run-df-tests.png)

6. If a test fails, then you will see in the terminal which test cases failed (see example).

![Failed PBITests](./images/failed-run-pbi-tests.png)

### Running a Specific Test

If you do not want to run a specific test, you can do so by following these steps:

1. Then from the terminal enter the command ./Run-DFTests.ps1 -Dataflow "{DataflowName}" -Feature "{FeatureName}"

![Run DFTests For Specific Test](./images/run-specific-test.png)

The command takes two parameters:

- Dataflow - The name of the Power BI Dataflow to test
- Feature - The name of the feature file to run for the test.  You don't need to add the suffix .feature.