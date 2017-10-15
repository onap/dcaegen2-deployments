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

import os, sys
from sets import Set
from jinja2 import Environment, PackageLoader, FileSystemLoader, meta

'''
@contextfunction
def get_exported_names(context):
    return sorted(context.exported_vars)
'''

def build_context( jjt_directory ):
    context = {}
    for file in os.listdir(jjt_directory):
        if file.endswith(".txt"):
            with open(os.path.join(jjt_directory, file), 'r') as parameter_file:
                value = parameter_file.readline().rstrip()
                key = file.split('.txt', 1)[0]
                context[key] = value
    return context


def render_template(tpl_path, context):
    path, filename = os.path.split(tpl_path)
    return Environment(loader = FileSystemLoader(path)).get_template(filename).render(context)


def check_templates(jjt_directory, template_file_dir):
    all_variables = Set([])
    env = Environment(loader=FileSystemLoader(template_file_dir))

    
    for infname in os.listdir(template_file_dir):
        template_source = env.loader.get_source(env, infname)[0]
        parsed_content = env.parse(template_source)
        referenced_variables = meta.find_undeclared_variables(parsed_content)
        all_variables.update(referenced_variables)

    context_variables = Set(build_context(jjt_directory).keys())
    undefined_variables = all_variables - context_variables

    if undefined_variables:
        print("Error: referenced but unprovided variables: {}".format(undefined_variables))
        exit(1)
    else:
        print("All referenced template variables found.  Proceed with de-templating")
    

# using context provided in jjt_directory to de-tempatize blueprint inputs in in_directory to out_directory
def detemplate_bpinputs(jjt_directory, in_directory, out_directory):
    context = build_context(jjt_directory)

    for infname in os.listdir(in_directory):
        infpath = os.path.join(in_directory, infname)
        outfpath = os.path.join(out_directory, infname)
        with open(outfpath, 'w') as f:
            print ('detemplating {} to {}'.format(infpath, outfpath))
            inputs = render_template(infpath, context)
            f.write(inputs)

def main():
    if len(sys.argv) != 4:
        print("Usgae:  {} variable_def_dir template_dir template_output_dir".format(sys.argv[0]))
        exit(1)

    print("De-templatizing templates in {} using variable defs from {}, results in {}".format(sys.argv[1], sys.argv[2], sys.argv[3]))
    check_templates(sys.argv[1], sys.argv[2])
    detemplate_bpinputs(sys.argv[1], sys.argv[2], sys.argv[3])
    
 
########################################
if __name__ == "__main__":
    main()
