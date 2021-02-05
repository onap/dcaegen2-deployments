# Change Log
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](http://keepachangelog.com/)
and this project adheres to [Semantic Versioning](http://semver.org/).

## [1.1.0] - 2021-02-05:
In support of deploying DCAE service components using Helm, the Consul loader
has been enhanced to:
   -- Convert YAML configuration files to JSON before storing the configuration into Consul
   -- Provide an option to delete a Consul key so that a component's configuration can be
      removed from Consul when the component is undeployed.

This version also changes the base image for the container to the ONAP integration team's
Python image (integration-python:8.0.0).