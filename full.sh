#!/opt/homebrew/bin/bash

set -e 

echo "Try to get current release notes ..."
curl --silent -L \
  -H "Accept: application/vnd.github+json" \
  -H "Authorization: Bearer ${{ secrets.GITHUB_TOKEN }}" \
  -H "X-GitHub-Api-Version: 2022-11-28" \
  https://api.github.com/repos/mboguslawsk/test_repo/releases/tags/v1.0.0 | jq --raw-output '.' > release_notes.json

echo -e "Done ...\n"

echo "\nTry to get artifacts for the current run ..."
curl -L \
  -H "Accept: application/vnd.github+json" \
  -H "Authorization: Bearer ${{ secrets.GITHUB_TOKEN }}" \
  -H "X-GitHub-Api-Version: 2022-11-28" \
  https://api.github.com/repos/mboguslawsk/test_repo/actions/runs/19767974011/artifacts | jq '.artifacts' > artifacts.json
echo -e "Done ...\n"

echo "Creating releasse note .txt file"
jq --raw-output .body < release_notes.json > release_body.txt

echo -e "Done ...\n"

echo "Try to append RFC addresses to the end ..."


echo -e "Start. Go through the artifacts\n"

for artifact in $( jq -c '.[]' < artifacts.json ); do
    ARTIFACT_NAME=$( echo $artifact | jq -r '.name')
    echo -e "================== Current artifact name is $ARTIFACT_NAME ==================\n"
    if [[ $ARTIFACT_NAME =~ CHG ]]; then
        echo -e "--- This artifact is good $ARTIFACT_NAME\n"
        ARTIFACT_ID=$( echo $artifact | jq '.id' )
        echo -e "--- Artifact ID is good $ARTIFACT_ID\n"
        mkdir $ARTIFACT_NAME
        curl -L --silent \
            -H "Accept: application/vnd.github+json" \
            -H "Authorization: Bearer ${{ secrets.GITHUB_TOKEN }}" \
            -H "X-GitHub-Api-Version: 2022-11-28" \
            https://api.github.com/repos/mboguslawsk/test_repo/actions/artifacts/$ARTIFACT_ID/zip \
            --output "$ARTIFACT_NAME/$ARTIFACT_NAME-file.zip"
        echo -e "--- Artifact $ARTIFACT_NAME downloaded\n"

        echo -e "--- EXTRACTING IT $ARTIFACT_NAME\n"
        unzip "$ARTIFACT_NAME/$ARTIFACT_NAME-file.zip" -d $ARTIFACT_NAME
        echo -e "\n--- Extracted ...\n"

        echo -e "\n--- Getting info from the file ...\n"
        CHANGE_URL=$(jq -r '."major-change"."output"."change-url"' < $ARTIFACT_NAME/*.json)
        CHANGE_NR=$(jq -r '."major-change"."output"."change-nr"' < $ARTIFACT_NAME/*.json)
        
        if [[ $ARTIFACT_NAME =~ prod ]]; then
            ENVIRONMENT="PROD"
        elif [[ $ARTIFACT_NAME =~ beta ]]; then
            ENVIRONMENT="BETA"
        else
            ENVIRONMENT="ENVIRONMENT"
        fi
        echo -e "\n--- Save the info  ...\n"
        echo "Try to append RFC addresses to the end ..."
        echo -e "\n## :rocket: $ENVIRONMENT CHG Created: [$CHANGE_NR]($CHANGE_URL)\n" >> release_body.txt
    else
        echo -e "--- This artifact is NOT good $ARTIFACT_NAME\n"
    fi
done



echo -e "Done ...\n"

RELEASE_ID=$( jq .id < release_notes.json )
NEW_NOTE_WITH_RFC=$( jq --raw-input -s . < release_body.txt)


echo "Try to update release notes ..."
echo "Release id is $RELEASE_ID"

echo $NEW_NOTE_WITH_RFC


curl -L \
  -X PATCH \
  -H "Accept: application/vnd.github+json" \
  -H "Authorization: Bearer ${{ secrets.GITHUB_TOKEN }}" \
  -H "X-GitHub-Api-Version: 2022-11-28" \
  https://api.github.com/repos/mboguslawsk/test_repo/releases/$RELEASE_ID\
  -d "{
    \"body\": $NEW_NOTE_WITH_RFC
  }"

echo -e "Done ...\n"