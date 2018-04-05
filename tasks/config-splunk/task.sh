#!/bin/bash -ex

chmod +x om-cli/om-linux
CMD=./om-cli/om-linux

guid_cf=$($CMD -t https://$OPS_MGR_HOST -u $OPS_MGR_USR -p $OPS_MGR_PWD -k curl -p "/api/v0/staged/products" \
             | jq '.[] | select(.type == "cf") | .guid' | tr -d '"' | grep "cf-.*")
RESPONSE=`$CMD -t https://$OPS_MGR_HOST -u $OPS_MGR_USR -p $OPS_MGR_PWD -k curl -p /api/v0/deployed/products/${guid_cf}/credentials/.uaa.splunk_firehose_credentials`

SPLUNK_USERNAME=`echo $RESPONSE | jq '.credential.value.identity' | tr -d '"'`
SPLUNK_PASSWORD=`echo $RESPONSE | jq '.credential.value.password' | tr -d '"'`

PRODUCT_PROPERTIES=$(cat <<-EOF
{
  ".properties.api_endpoint": {
    "value": "$cf_api_endpoint"
  },
  ".properties.api_user": {
    "value": "$SPLUNK_USERNAME"
  },
  ".properties.api_password": {
    "value": {
      "secret": "$SPLUNK_PASSWORD"
    }
  },
  ".properties.skip_ssl_validation_cf": {
    "value": "$SKIP_CERT_VERIFY"
  }
}
EOF
)

function fn_other_azs {
  local azs_csv=$1
  echo $azs_csv | awk -F "," -v braceopen='{' -v braceclose='}' -v name='"name":' -v quote='"' -v OFS='"},{"name":"' '$1=$1 {print braceopen name quote $0 quote braceclose}'
}

BALANCE_JOB_AZS=$(fn_other_azs $OTHER_AZS)

PRODUCT_NETWORK_CONFIG=$(cat <<-EOF
{
  "singleton_availability_zone": {
    "name": "$SINGLETON_JOB_AZ"
  },
  "other_availability_zones": [
    $BALANCE_JOB_AZS
  ],
  "network": {
    "name": "$NETWORK_NAME"
  }
}
EOF
)


$CMD -t https://$OPS_MGR_HOST -u $OPS_MGR_USR -p $OPS_MGR_PWD -k configure-product -n $PRODUCT_IDENTIFIER -pn "$PRODUCT_NETWORK_CONFIG" -p "$PRODUCT_PROPERTIES"
