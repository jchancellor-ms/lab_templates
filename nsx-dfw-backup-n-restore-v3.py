#!/usr/bin/env python
# Requires Python 3.x

"""
NSX-T SDK Sample Code
Copyright 2017-2020 VMware, Inc.  All rights reserved
The BSD-2 license (the "License") set forth below applies to all
parts of the NSX-T SDK Sample Code project.  You may not use this
file except in compliance with the License.
BSD-2 License
Redistribution and use in source and binary forms, with or
without modification, are permitted provided that the following
conditions are met:
    Redistributions of source code must retain the above
    copyright notice, this list of conditions and the
    following disclaimer.
    Redistributions in binary form must reproduce the above
    copyright notice, this list of conditions and the
    following disclaimer in the documentation and/or other
    materials provided with the distribution.
THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND
CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES,
INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR
CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF
USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED
AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN
ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
POSSIBILITY OF SUCH DAMAGE.
"""

################################################################################
# Summary: Script to Back and restore NSX DFW policy, rules, groups, Services and context-profiles.
# Usage: python nsx-dfw-backup-n-restore.py [-h] --nsx-mgr-ip IP --operation OPERATION
#                                   [--user USER] [--password PASSWORD]
#                                   [--backupfileprefix BACKUPFILEPREFIX]
# Caveat: Prior to 3.1 Services Restore will fail with this script due to
#                 https://bugzilla.eng.vmware.com/show_bug.cgi?id=2616308
#                If you do not have user configured service then you are good and
#                 can comment out the restore service function.
# ##############################################################################

import requests
from requests.auth import HTTPBasicAuth
import json
from requests.packages.urllib3.exceptions import InsecureRequestWarning
import argparse
import re
import copy

################################################################################
###  Define Arguments for the script.
################################################################################

parser = argparse.ArgumentParser(description='NSX DFW Policy Backup & Restore- DFW Policies, Groups, Services & Profiles ')
parser.add_argument('--nsx-mgr-ip', dest="ip",
                   help="NSX Manager IP", required=True)
parser.add_argument('--operation', dest="operation",
                   help="What operation - backup, restore, or restore_by_object", required=True)
parser.add_argument('--user', dest="user",
                   help="NSX Username, default: admin",
                   default="admin", required=False)
parser.add_argument('--password', dest="password",
                   help="NSX Password, default: VMware!23VMware",
                   default="Admin!23Admin", required=False)
parser.add_argument('--backupfileprefix', dest="backupfileprefix",
                   help="Prefix backup file with- default nsx-dfw-<object-type>.json",
                   default="nsx", required=False)
parser.add_argument('--debug', dest="debug",
                   help="Enable debug mode to display API request/response details",
                   action='store_true', required=False)
args = parser.parse_args()

################################################################################
###  REST API function using python "requests" module
################################################################################
def rest_api_call (method, endpoint, data=None, ip=args.ip, user=args.user, password=args.password, debug=False):
    url = "https://%s%s" % (ip, endpoint)
    # To remove ssl-warnings bug. even with cert verification is set as false
    requests.packages.urllib3.disable_warnings(InsecureRequestWarning)
    headers = {
        'Content-Type': 'application/json',
        'Accept': 'application/json'
    }
    
    res = requests.request(
        method=method,
        url=url,
        auth=HTTPBasicAuth(user, password),
        headers=headers,
        data=data,
        verify=False
    )
    
    # Only show debug output if there's an error (non-200 status)
    if debug and res.status_code != 200:
        print("\n" + "="*80)
        print("API CALL DEBUG INFO (ERROR DETECTED)")
        print("="*80)
        print(f"Method: {method}")
        print(f"URL: {url}")
        print(f"User: {user}")
        print(f"Headers: {headers}")
        if data:
            print(f"\nRequest Body (first 5000 chars):")
            body_preview = data[:5000] + "..." if len(data) > 5000 else data
            print(body_preview)
            print(f"\nBody Length: {len(data)} characters")
        else:
            print("\nRequest Body: None")
        
        print("\n" + "-"*80)
        print("API RESPONSE DEBUG INFO")
        print("-"*80)
        print(f"Status Code: {res.status_code}")
        print(f"Reason: {res.reason}")
        if len(res.content) > 0:
            print(f"\nResponse Content (first 5000 chars):")
            content_str = res.content.decode('utf-8')
            content_preview = content_str[:5000] + "..." if len(content_str) > 5000 else content_str
            print(content_preview)
            print(f"\nContent Length: {len(res.content)} bytes")
        print("="*80 + "\n")
    
    try:
        res.raise_for_status()
    except requests.exceptions.HTTPError as e:
        if debug and res.status_code == 200:
            # Edge case: if we somehow get here with 200 status, show debug info
            print("\n" + "="*80)
            print("API ERROR DEBUG INFO")
            print("="*80)
            print(f"Error: {e}")
            print("="*80 + "\n")
        raise e
    if len(res.content) > 0:
        response = res.json()
        return response

################################################################################
###  Backup NSX DFW DFW L4 Services
################################################################################

def backup_nsx_dfw_services(backupfileprefix):
    backupfile = (backupfileprefix+'-services-bkup.json')
    # Send API Request to NSX Manager to get DFW Policy inventory
    #endpoint = "/policy/api/v1/infra?base_path=/infra/domains/default&type_filter=SecurityPolicy;Group"
    endpoint = "/policy/api/v1/infra?filter=Type-Service"
    res = rest_api_call(method= 'GET', endpoint = endpoint)
    with open(backupfile, 'w') as bkdata:
        # Save the resonse dictionary in python to a json file.
        # Use option indent to save json in more readable format
        json.dump(res, bkdata, indent=4)
    #  To Count number of Security Policy, Rules & Groups
    #  Open DFW backup file
    f = open(backupfile, "r")
    lines = f.readlines()
    f.close()
    print("\n   NSX DFW L4 services Backup saved as [%s]" % backupfile)

################################################################################
###  Backup NSX DFW L7 Profiles
################################################################################

def backup_nsx_dfw_context_profiles(backupfileprefix):
    backupfile = (backupfileprefix+'-context-profiles-bkup.json')
    # Send API Request to NSX Manager to get DFW Policy inventory
    #endpoint = "/policy/api/v1/infra?base_path=/infra/domains/default&type_filter=SecurityPolicy;Group"
    endpoint = "/policy/api/v1/infra?filter=Type-ContextProfile"
    res = rest_api_call(method= 'GET', endpoint = endpoint)
    with open(backupfile, 'w') as bkdata:
        # Save the resonse dictionary in python to a json file.
        # Use option indent to save json in more readable format
        json.dump(res, bkdata, indent=4)
    #  To Count number of Security Policy, Rules & Groups
    #  Open DFW backup file
    f = open(backupfile, "r")
    lines = f.readlines()
    f.close()
    print("\n   NSX DFW L7 context-profiles Backup saved as [%s]" % backupfile)

################################################################################
###  Backup NSX DFW Policy, Rules with GROUPS.
################################################################################

def backup_nsx_dfw_policy_n_group(backupfileprefix):
    backupfile = (backupfileprefix+'-policy-n-group-bkup.json')
    # Send API Request to NSX Manager to get DFW Policy inventory
    #endpoint = "/policy/api/v1/infra?base_path=/infra/domains/default&type_filter=SecurityPolicy;Group"
    endpoint = "/policy/api/v1/infra?filter=Type-Domain|SecurityPolicy|Rule|Group"
    res = rest_api_call(method= 'GET', endpoint = endpoint)
    with open(backupfile, 'w') as bkdata:
        # Save the resonse dictionary in python to a json file.
        # Use option indent to save json in more readable format
        json.dump(res, bkdata, indent=4)
    #  To Count number of Security Policy, Rules & Groups
    #  Open DFW backup file
    f = open(backupfile, "r")
    lines = f.readlines()
    f.close()
    # Count pattern "ChildSecurityPolicy" for Total Policy Count
    search_for_policy = 'ChildSecurityPolicy'
    # Count pattern "Rule_id for Total Policy Count
    search_for_rule = 'rule_id'
    # Count pattern "ChildGroup" for Total Policy Count
    search_for_group = 'ChildGroup'
    # Intialize counter variable
    pcount, rcount, gcount = 0, 0, 0
    for line in lines:
        line = line.strip().lower().split()
        for words in line:
            if words.find(search_for_policy.lower()) != -1:
                pcount +=1
        for words in line:
            if words.find(search_for_rule.lower()) != -1:
                rcount +=1
        for words in line:
            if words.find(search_for_group.lower()) != -1:
                gcount +=1
    print("\n   NSX DFW Policy & Group Backup saved as [%s]" % backupfile)
    print("\n   NSX DFW Backup has %s Policy, %s Rules, %s Group\n" % (pcount, rcount, gcount))

################################################################################
###  Restore NSX DFW L4 Services
################################################################################

def restore_nsx_dfw_services(backupfileprefix):
    backupfile = (backupfileprefix+'-services-bkup.json')
    # 'Read' JSON encoded data from backup file and convert to python dict
    with open(backupfile, 'r') as bkdata:
        backup_data = json.load(bkdata)
    # NSX API to send entire L4 Services config in one PATCH call with backupfile as body
    endpoint = "/policy/api/v1/infra"
    # Convert body to JSON string, as module needs the body as string.
    body = json.dumps(backup_data)
    try:
        rest_api_call(method='PATCH', endpoint = endpoint, data=body, debug=args.debug)
        print("\n   SUCCESS - NSX DFW L4 Services")
    except Exception as ex:
        err_res_cont = json.loads(ex.response.content)
        # Grep error_message to identify issue
        err_msg = err_res_cont["error_message"]
        print("\n    FAILURE - NSX DFW L4 Services with error: [%s]\n" %(err_msg))

################################################################################
###  Restore NSX DFW L7 Context-Profile
################################################################################

def restore_nsx_dfw_context_profiles(backupfileprefix):
    backupfile = (backupfileprefix+'-context-profiles-bkup.json')
    # 'Read' JSON encoded data from backup file and convert to python dict
    with open(backupfile, 'r') as bkdata:
        backup_data = json.load(bkdata)
    # NSX API to send entire L4 Services config in one PATCH call with backupfile as body
    endpoint = "/policy/api/v1/infra"
    # Convert body to JSON string, as module needs the body as string.
    body = json.dumps(backup_data)
    try:
        rest_api_call(method='PATCH', endpoint = endpoint, data=body, debug=args.debug)
        print("\n   SUCCESS - NSX DFW L7 Services Restore")
    except Exception as ex:
        err_res_cont = json.loads(ex.response.content)
        # Grep error_message to identify issue
        err_msg = err_res_cont["error_message"]
        print("\n    FAILURE - NSX DFW L7 Services Restore with error: [%s]\n" %(err_msg))

################################################################################
###  Restore NSX DFW Policy, Rules with GROUPS.
################################################################################

def restore_nsx_dfw_policy_n_group(backupfileprefix):
    backupfile = (backupfileprefix+'-policy-n-group-bkup.json')
    # 'Read' JSON encoded data from backup file and convert to python dict
    with open(backupfile, 'r') as bkdata:
        backup_data = json.load(bkdata)
    # NSX API to send entire Policy And Group config in one PATCH call with backupfile as body
    endpoint = "/policy/api/v1/infra"
    # Convert body to JSON string, as module needs the body as string.
    body = json.dumps(backup_data)
    #  To Count number of Security Policy, Rules & Groups
    #  Open DFW backup file
    f = open(backupfile, "r")
    lines = f.readlines()
    f.close()
    # Count pattern "ChildSecurityPolicy" for Total Policy Count
    search_for_policy = 'ChildSecurityPolicy'
    # Count pattern "Rule_id for Total Policy Count
    search_for_rule = 'rule_id'
    # Count pattern "ChildGroup" for Total Policy Count
    search_for_group = 'ChildGroup'
    # Intialize counter variable
    pcount, rcount, gcount = 0, 0, 0
    for line in lines:
        line = line.strip().lower().split()
        for words in line:
            if words.find(search_for_policy.lower()) != -1:
                pcount +=1
        for words in line:
            if words.find(search_for_rule.lower()) != -1:
                rcount +=1
        for words in line:
            if words.find(search_for_group.lower()) != -1:
                gcount +=1
    try:
        rest_api_call(method='PATCH', endpoint = endpoint, data=body, debug=args.debug)
        print("\n   SUCCESS - NSX DFW Policy & Group Restore: %s Policy, %s Rules, %s Group\n" % (pcount, rcount, gcount))
    except Exception as ex:
        err_res_cont = json.loads(ex.response.content)
        # Grep error_message to identify issue
        err_msg = err_res_cont["error_message"]
        print("\n    FAILURE - NSX DFW Policy & Group Restore with error: [%s]\n" %(err_msg))

def restore_nsx_dfw_services_by_service(backupfileprefix):
    backupfile = (backupfileprefix+'-services-bkup.json')
    # 'Read' JSON encoded data from backup file and convert to python dict
    with open(backupfile, 'r') as bkdata:
        backup_data = json.load(bkdata)
    endpoint = "/policy/api/v1/infra"

    #copy the original object
    body_headers = copy.deepcopy(backup_data)
    #remove the children to retain the headers
    del body_headers["children"]    
    #initialize the counters
    success, failure = 0, 0

    #recreate the children element for each child service and apply
    for child in backup_data['children']:
        #initialize the body as a copy of body_headers
        body = dict(body_headers)
        #append this child details
        body['children'] = [child]
        #convert to json for the API
        body_json = json.dumps(body)

        try:
            rest_api_call(method='PATCH', endpoint = endpoint, data=body_json, debug=args.debug)
            print("SUCCESS - NSX DFW L4 Services - %s " %(body['children'][0]['Service']['relative_path']))
            success += 1
        except Exception as ex:
            err_res_cont = json.loads(ex.response.content)
            # Grep error_message to identify issue
            err_msg = err_res_cont["error_message"]
            print("FAILURE - NSX DFW L4 Services %s with error: [%s]" %(body['children'][0]['Service']['relative_path'], err_msg))
            failure += 1

    print("Processed services with %s successes, and %s failures." %(success, failure))

def restore_nsx_dfw_policy_n_group_by_policy(backupfileprefix):
    backupfile = (backupfileprefix+'-policy-n-group-bkup.json')
    # 'Read' JSON encoded data from backup file and convert to python dict
    with open(backupfile, 'r') as bkdata:
        backup_data = json.load(bkdata)
    # NSX API to send entire Policy And Group config in one PATCH call with backupfile as body
    endpoint = "/policy/api/v1/infra"   
    #initialize the counters   
    group, security_policy = 0, 0
    success, failure = 0, 0

    #copy the original object so we can extract the headers
    body_headers = copy.deepcopy(backup_data)
    #remove the children list leaving only the header details
    del body_headers["children"][0]["Domain"]["children"]


    for child in backup_data["children"][0]["Domain"]["children"]:
        #copy the headers for this run
        body = body_headers.copy()
        #append the current element being added
        body["children"][0]["Domain"]["children"] = [child]
        #convert the full object to json for the API
        body_json = json.dumps(body)    
       
        #update the counters
        if child['resource_type'] == "ChildGroup":
            group +=1
        if child['resource_type'] == "ChildSecurityPolicy":
            security_policy +=1

        try:
            rest_api_call(method='PATCH', endpoint = endpoint, data=body_json, debug=args.debug)
            print("SUCCESS - NSX DFW Policy & Group Restore: type [%s] and id [%s] " % (child['resource_type'], child['id']))
            success += 1
        except Exception as ex:
            err_res_cont = json.loads(ex.response.content)
            # Grep error_message to identify issue
            err_msg = err_res_cont["error_message"]
            print("FAILURE - NSX DFW Policy & Group Restore  type [%s] and id [%s] with error: [%s]" %(child['resource_type'], child['id'], err_msg))
            failure += 1


    print("Processed %s groups and %s security policies with %s successes, and %s failures." %(group, security_policy, success, failure))


def restore_nsx_dfw_context_profiles_by_profile(backupfileprefix):
    backupfile = (backupfileprefix+'-context-profiles-bkup.json')
    # 'Read' JSON encoded data from backup file and convert to python dict
    with open(backupfile, 'r') as bkdata:
        backup_data = json.load(bkdata)
    # NSX API to send entire L4 Services config in one PATCH call with backupfile as body
    endpoint = "/policy/api/v1/infra"

    #copy the original object so we can extract the headers
    body_headers = copy.deepcopy(backup_data)
    #remove the children to retain the headers
    del body_headers["children"]
    #initialize the counters    
    success, failure = 0, 0

    #recreate the children element for each child service and apply
    for child in backup_data['children']:
        #initialize the body as a copy of body_headers
        body = dict(body_headers)
        #append the current child to the headers
        body['children'] = [child]
        #convert to json for the API
        body_json = json.dumps(body)

        try:
            rest_api_call(method='PATCH', endpoint = endpoint, data=body_json, debug=args.debug)
            print("SUCCESS - NSX DFW L7 Services Restore - %s " %(body['children'][0]['PolicyContextProfile']['relative_path']))
            success += 1
        except Exception as ex:
            err_res_cont = json.loads(ex.response.content)
            # Grep error_message to identify issue
            err_msg = err_res_cont["error_message"]
            print("FAILURE - NSX DFW L7 Services Restore %s with error: [%s]" %(body['children'][0]['PolicyContextProfile']['relative_path'], err_msg))
            failure += 1

    print("Processed services with %s successes, and %s failures." %(success, failure))


################################################################################
### Run "backup" or "restore" DFW policy backup based on user input to "--operation"
################################################################################

if __name__ == "__main__":
    if "backup" in args.operation:
        backup_nsx_dfw_services(args.backupfileprefix)
        backup_nsx_dfw_context_profiles(args.backupfileprefix)
        backup_nsx_dfw_policy_n_group(args.backupfileprefix)
    if "restore" in args.operation:
        # Prior to 3.1: Policy API bug with Service Patch call https://bugzilla.eng.vmware.com/show_bug.cgi?id=2616308
        #If you do not have user configured service then you are good and can disable the function.
        restore_nsx_dfw_services(args.backupfileprefix)
        restore_nsx_dfw_context_profiles(args.backupfileprefix)
        restore_nsx_dfw_policy_n_group(args.backupfileprefix)
    if "recover_by_object" in args.operation:
        restore_nsx_dfw_services_by_service(args.backupfileprefix)
        restore_nsx_dfw_context_profiles_by_profile(args.backupfileprefix)
        restore_nsx_dfw_policy_n_group_by_policy(args.backupfileprefix)
        


"""
Sample Script output:

Backup:

    bhatg@bhatg-a02 DFW % python nsx-dfw-backup-n-restore.py --nsx-mgr-ip 10.110.57.244 --operation backup

       NSX DFW L4 services Backup saved as [nsx-services-bkup.json]

       NSX DFW L7 context-profiles Backup saved as [nsx-context-profiles-bkup.json]

       NSX DFW Policy & Group Backup saved as [nsx-policy-n-group-bkup.json]

       NSX DFW Backup has 6 Policy, 37 Rules, 3 Group
    bhatg@bhatg-a02 DFW %

Restore:

    bhatg@bhatg-a02 DFW % python nsx-dfw-backup-n-restore.py --nsx-mgr-ip 10.110.57.244 --operation restore

       SUCCESS - NSX DFW L4 Services

       SUCCESS - NSX DFW L7 Services Restore

       SUCCESS - NSX DFW Policy & Group Restore: 6 Policy, 37 Rules, 3 Group

    bhatg@bhatg-a02 DFW %

"""