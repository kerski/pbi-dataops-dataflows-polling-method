Feature: RawSourceExample

Background: Setup Connection to DFTest datast for the dataflow
    Given we have access to the DFTest file in the Workspace: "{WORKSPACE}"
    And we have access to the Dataflow: "RawSourceExample"    
    And we have the table called "MarvelSource"
    #And we can setup the table for testing

Scenario: Validate MarvelSource Schema
	Then there should be greater than 100 records returned
    And the values in "page_id" are unique
    And the values of "Year" matches this regex: "^\d{3}$"
	And the values of "ALIVE" matches this regex: "^(Living Characters|Deceased Characters|)$"
    And it should contain the schema defined as follows:
	| Name          | Type          |
	| page_id       | int64         |
	| name          | string        |
    | urlslug       | string        |
    | ALIVE         | string        |    
	