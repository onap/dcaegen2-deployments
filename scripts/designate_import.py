#!/usr/bin/env python
# ============LICENSE_START=======================================================
# org.onap.dcae
# ================================================================================
# Copyright (c) 2017 AT&T Intellectual Property. All rights reserved.
# ================================================================================
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# 
#      http://www.apache.org/licenses/LICENSE-2.0
# 
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
# ============LICENSE_END=========================================================
#
# ECOMP is a trademark and service mark of AT&T Intellectual Property.

import designateclient
from designateclient.v2 import client as designate_client
from designateclient import shell

from keystoneauth1.identity import generic
from keystoneauth1 import session as keystone_session
import json
import socket
import sys
import yaml

def find_entry_by_name(entry_list, entry_name):
    for entry in entry_list:
        if entry['name'] == entry_name:
            return entry
    return none 



def main():
    if len(sys.argv) != 6 and len(sys.argv) != 2:
        print("Usgae:  {} input_file [auth_url username password tenant]".format(sys.argv[0]))
        exit(1)
    if len(sys.argv) == 6:
        print("Creating DNS records using record defs from {}, authurl {}, usernaem {}, tenant {}".format(
          sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[5]))
    else:
        print("Creating DNS records using record defs from {}, authurl {}, usernaem {}, tenant {}".format(
          shell.env('OS_AUTH_URL'), shell.env('OS_USERNAME'), shell.env('OS_PASSWORD'), shell.env('OS_PROJECT_NAME')))

    inputfilepath = sys.argv[1]
    auth = ""

    if len(sys.argv) == 2:
        auth = generic.Password(
          auth_url=shell.env('OS_AUTH_URL'),
          username=shell.env('OS_USERNAME'),
          password=shell.env('OS_PASSWORD'),
          project_name=shell.env('OS_PROJECT_NAME'),
          project_domain_id='default',
          user_domain_id='default')
    else:
        auth = generic.Password(
          auth_url=sys.argv[2],
          username=sys.argv[3],
          password=sys.argv[4],
          project_name=sys.argv[5],
          project_domain_id='default',
          user_domain_id='default')

    if not auth:
        print("Fail to get authenticated from OpenStack")
        exit(1)

    session = keystone_session.Session(auth=auth)
    client = designate_client.Client(session=session)

    zone_name = 'simpledemo.onap.org'
    zone_name_dot = zone_name + '.'

    zone_list = client.zones.list()
    print("before: \n{}".format(json.dumps(zone_list, indent=4)))

    zone = find_entry_by_name(entry_list = zone_list, entry_name = zone_name_dot)
    if zone:
        print("exitsing zone: zone id {}".format(zone['id']))
    else:
        zone = client.zones.create(zone_name_dot, email='lji@research.att.com')
        print("newly created zone: zone id {}".format(zone['id']))

    recordsets = client.recordsets.list(zone['id'])
    # delete all exitsing A and CNAME records under the zone_name
    for recordset in recordsets:
        if not recordset['name'].endswith(zone_name_dot):
            continue
        print("Deleting recordset {}".format(recordset['name']))
        if recordset['type'] == 'A':
            client.recordsets.delete(zone['id'], recordset['id'])
        elif recordset['type'] == 'CNAME':
            client.recordsets.delete(zone['id'], recordset['id'])


    with open(inputfilepath, 'r') as inputfile:
        records_to_add = yaml.load(inputfile)
        for key, value in records_to_add.iteritems():
           if not key.endswith(zone_name):
               continue
           try:
               socket.inet_aton(value)
               # take zone name out (including the . before it)
               key = key[:-(len(zone_name)+1)]
               print("Creating DNS A record for: {} - {}".format(key, value))
               rs = client.recordsets.create(zone['id'], key, 'A', [value])
           except:
               print()

        for key, value in records_to_add.iteritems():
           if not key.endswith(zone_name):
               continue
           try:
               socket.inet_aton(value)
           except:
               # take zone name out (and the . before it)
               key = key[:-(len(zone_name)+1)]
               if not value.endswith('.'):
                   value = value + '.'
               print("Creating DNS CNAME record for: {} - {}".format(key, value))
               rs = client.recordsets.create(zone['id'], key, 'CNAME', [value])

    recordsets = client.recordsets.list(zone['id'])
    print("before: \n{}".format(json.dumps(recordsets, indent=4)))

 
########################################
if __name__ == "__main__":
    main()

