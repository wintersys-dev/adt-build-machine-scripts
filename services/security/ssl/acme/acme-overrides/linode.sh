#!/bin/sh

set -x

# shellcheck disable=SC2034
dns_linode_info='Linode.com (Old)
Deprecated. Use dns_linode_v4
Site: Linode.com
'

########  Public functions #####################
#
#Usage: add  _acme-challenge.www.domain.com   "XKrxpRBosdIKFzxW_CT3KLZNf6q0HG9i01zxXp5CPBs"
dns_linode_v4_add() {
        full_domain=$1
        txtvalue=$2

        _domain="`/bin/echo "${full_domain}" | cut -d '.' -f 3-`"
        _sub_domain="`/bin/echo "${full_domain}" | cut -d '.' -f1`"

        _debug _sub_domain "$_sub_domain"
        _debug _domain "$_domain"

        _info "Adding record"

        BUILD_HOME="`/bin/cat /home/buildhome.dat`"
        TOKEN="`${BUILD_HOME}/helpers/services/GetVariableValue.sh TOKEN`"

        _domain_id="`curl -H "Authorization: Bearer $TOKEN" https://api.linode.com/v4/domains | jq -r '.data[] | select(.domain | contains("'$_domain'")).id'`"
        curl -s -X POST -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" -d '{ "type": "TXT", "name": "'"${_sub_domain}"'", "target": "'${txtvalue}'", "ttl_sec": 60 }' https://api.linode.com/v4/domains/${_domain_id}/records


        if ( [ "`curl -s -H "Authorization: Bearer $TOKEN" "https://api.linode.com/v4/domains/${_domain_id}/records" | jq -r '.data[] | select(.type == "TXT") | .target' | /bin/grep ${txtvalue}`" != "" ] )
        then
                _info "Added, OK"
                return 0
        fi

        if ( [ "${txtvalue}" = "" ] )
        then
                _err "No txt record provided, have you reached your certificate issuance limit?"
        else
                _err "Add txt record error"
        fi
        return 1
}


#fulldomain txtvalue
dns_linode_v4_rm() {
        full_domain=$1
        txtvalue=$2

        BUILD_HOME="`/bin/cat /home/buildhome.dat`"
        TOKEN="`${BUILD_HOME}/helpers/services/GetVariableValue.sh TOKEN`"

        _domain="`/bin/echo "${full_domain}" | cut -d '.' -f 3-`"
        _sub_domain="`/bin/echo "${full_domain}" | cut -d '.' -f1`"

        _domain_id="`curl -H "Authorization: Bearer $TOKEN" https://api.linode.com/v4/domains | jq -r '.data[] | select(.domain | contains("'$_domain'")).id'`"
        _record_id="`curl -s "https://api.linode.com/v4/domains/${_domain_id}/records" -H "Authorization: Bearer $TOKEN" | jq --arg sub "${_sub_domain}" -r '.data[] | select(.name == $sub) | .id'`"

        curl -s -X DELETE -H "Authorization: Bearer $TOKEN"  "https://api.linode.com/v4/domains/${_domain_id}/records/${_record_id}"

        if ( [ "`curl -H "Authorization: Bearer $TOKEN" https://api.linode.com/v4/domains | jq -r '.data[] | select(.domain | contains("'$_domain'")).id'`" != "" ] )
        then
                _info "Removed, OK"
                return 0
        fi

        _err "Remove txt record error."
        return 1

}
