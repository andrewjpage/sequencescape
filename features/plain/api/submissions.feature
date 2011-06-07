@api @json @submission @allow-rescue @submission_api 
Feature: Interacting with submissions through the API
  Background:
    Given all of this is happening at exactly "16-September-2010 13:45:00+01:00"

    Given I am using version "0_5" of a legacy API
    
    
    Given I have an "active" study called "Testing submission creation"
    And the UUID for the study "Testing submission creation" is "22222222-3333-4444-5555-000000000000"

    Given I have a project called "Testing submission creation"
    And the UUID for the project "Testing submission creation" is "22222222-3333-4444-5555-000000000001"

    Given the UUID for the submission template "Library creation - Paired end sequencing" is "00000000-1111-2222-3333-444444444444"
    And the UUID of the next submission created will be "11111111-2222-3333-4444-555555555555"

    Given the UUID for the request type "Library creation" is "99999999-1111-2222-3333-000000000000"
    And the UUID for the request type "Paired end sequencing" is "99999999-1111-2222-3333-000000000001"
    
    

  Scenario: Listing all of the submissions that exist if there aren't any
    When I GET the API path "/submissions"
    Then the JSON should be an empty array

  Scenario: Listing all of the submissions that exist for a submission without assets
    Given I have a submission created with the following details based on the template "Library creation - Paired end sequencing":
      | study   | 22222222-3333-4444-5555-000000000000 |
      | project | 22222222-3333-4444-5555-000000000001 |
      | assets  | 33333333-4444-5555-6666-000000000001 |


    When I GET the API path "/submissions"
    Then ignoring "internal_id" the JSON should be:
      """
      [
        { 
          "submission":
          {
            "uuid": "11111111-2222-3333-4444-555555555555",
            "created_at": "2010-09-16T13:45:00+01:00",
            "updated_at": "2010-09-16T13:45:00+01:00",
            "created_by": "user",
            "template_name":"Library creation - Paired end sequencing",
            "state": "building",
            "study_name": "Testing submission creation",
            "study_uuid": "22222222-3333-4444-5555-000000000000",
            "project_name": "Testing submission creation", 
            "project_uuid": "22222222-3333-4444-5555-000000000001"
          }
        }
      ]
      """

  Scenario: Retrieving the JSON for a submission that does not exist
    When I GET the API path "/submissions/00000000-1111-2222-3333-444444444444"
    Then the HTTP response should be "404 Not Found"

  Scenario: Retrieving the JSON for a particular submission with 3 assets
    Given I have a submission created with the following details based on the template "Library creation - Paired end sequencing":
      | study   | 22222222-3333-4444-5555-000000000000 |
      | project | 22222222-3333-4444-5555-000000000001 |
      | assets  | 33333333-4444-5555-6666-000000000001 |
      
    Given 3 sample tubes exist with names based on "sampletube" and IDs starting at 1
      And all sample tubes have sequential UUIDs based on "33333333-4444-5555-6666"
      And the sample tubes are part of submission "11111111-2222-3333-4444-555555555555"

    When I GET the API path "/submissions/11111111-2222-3333-4444-555555555555"
    Then ignoring "internal_id" the JSON should be:
      """
        { 
          "submission":
          {
            "uuid": "11111111-2222-3333-4444-555555555555",
            "created_at": "2010-09-16T13:45:00+01:00",
            "updated_at": "2010-09-16T13:45:00+01:00",
            "created_by": "user",
            "template_name":"Library creation - Paired end sequencing",
            "state": "building",
            "study_name": "Testing submission creation",
            "study_uuid": "22222222-3333-4444-5555-000000000000",
            "project_name": "Testing submission creation", 
            "project_uuid": "22222222-3333-4444-5555-000000000001",
            "asset_uuids": [  
              "33333333-4444-5555-6666-000000000001",
              "33333333-4444-5555-6666-000000000002",
              "33333333-4444-5555-6666-000000000003"
            ]
          }
        }
      """
