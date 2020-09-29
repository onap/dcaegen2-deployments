########
# Copyright (c) 2018 Cloudify Platform Ltd. All rights reserved
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#        http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
#    * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#    * See the License for the specific language governing permissions and
#    * limitations under the License.

#!/usr/bin/env python

import subprocess
import json
import argparse
from flask_security.utils import encrypt_password
from manager_rest.flask_utils import setup_flask_app


def db_update_password(password):
    password = encrypt_new_password(password)
    password = password.replace('$', '\$')
    sql_command = "\"update users set password='" + password + "' where username='admin'\""
    cmd = "sudo -u postgres psql cloudify_db -c " + sql_command
    subprocess.Popen(cmd, stdout=subprocess.PIPE, shell=True)


def get_salt():
    with open('/opt/manager/rest-security.conf') as f:
        rest_security = json.load(f)

    return rest_security['hash_salt']


def encrypt_new_password(password):
    app = setup_flask_app(hash_salt=get_salt())
    with app.app_context():
        password = encrypt_password(password)
    return password


if __name__ == '__main__':

    parser = argparse.ArgumentParser(description=('Reset admin password in DB according to rest-security.conf'))
    parser.add_argument('-p', '--password', required=True, help='New admin password')
    args = parser.parse_args()

    db_update_password(args.password)
    print 'Password updated in DB!\n'
