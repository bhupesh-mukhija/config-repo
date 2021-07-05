function handleSfdxResponse() {
    echo $1
    local RESPONSE=$1
    echo "$(echo $RESPONSE | jq -r ".status")"
    if [ "$(echo $RESPONSE | jq -r ".status")" = "1" ]
    then
        echo "******* SFDX Command Failed *******"
        echo $QUERY_RESPONSE | jq
        STACK=$(echo $RESPONSE | jq -r ".name,.message,.stack")
        sendNotification --statuscode $(echo $RESPONSE | jq -r ".status") \
            --message "$(echo $RESPONSE | jq -r ".name"): $(echo $RESPONSE | jq -r ".message")" \
            --details "$(echo $RESPONSE | jq -r ".stack")"
    fi
}