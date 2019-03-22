#!/usr/bin/env python
#============LICENSE_START==========================================================
# org.onap.dcae
# ==================================================================================
# Copyright (c) 2019 AT&T Intellectual Property. All rights reserved.
# ==================================================================================
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
# ============LICENSE_END===========================================================
#
import sys
import yaml
from sqlalchemy.orm.attributes import flag_modified
from manager_rest.flask_utils import setup_flask_app
from manager_rest.constants import PROVIDER_CONTEXT_ID
from manager_rest.storage import get_storage_manager, models


def main(dry_run, rules_file):

    with setup_flask_app().app_context():
        sm = get_storage_manager()
        ctx = sm.get(models.ProviderContext, PROVIDER_CONTEXT_ID)
        print 'Resolver rules before update:'
        print yaml.safe_dump(ctx.context['cloudify']['import_resolver']['parameters']['rules'])

        if dry_run:
            return

        with open(rules_file, 'r') as rules:
            new_rules = yaml.load(rules)
        ctx.context['cloudify']['import_resolver']['parameters']['rules'] = new_rules
        print '\nResolver rules to update:'
        print yaml.safe_dump(new_rules)
        flag_modified(ctx, 'context')
        sm.update(ctx)
        print '\nProvide Context Saved'
        print '\nResolver rules after update:'
        print yaml.safe_dump(ctx.context['cloudify']['import_resolver']['parameters']['rules'])


if __name__ == '__main__':
    if len(sys.argv) < 2:
        print 'Must provide path to yaml file containing new rules or --dry-run'
        exit(1)

    main(sys.argv[1]=='--dry-run', sys.argv[1])