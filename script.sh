#!/bin/bash    

sudo apt-get update
sudo apt-get install -y curl        
sudo apt install -y gettext-base
sudo apt install -y moreutils    
sudo curl -u ${CIRCLE_PREVIOUS_BUILD_NUM}: -X POST --header "Content-Type: application/json" -d '{ 
    "branch": "develop", 
    "parameters": { 
    "destroy_test_dev": true, 
    "run_infra_build": false
    } 
 }' https://circleci.com/api/v2/project/gh/kbcbals/circleci-lambda/pipeline
