# Change Log
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](http://keepachangelog.com/)
and this project adheres to [Semantic Versioning](http://semver.org/).

## [2.4.1] - 2023-10-10
* [DCAEGEN2-3400] Update Docker base image to node.js 18.x (the latest LTS release).
* Update README to eliminate references to dcaemod and the old dcaegen2 platform services,
  which are no longer being deployed and which had separate instances of the healthcheck service.

## [2.4.0] - 2021-12-08
* [DCAEGEN2-2959] Add healthchecking for microservices deployed after DCAE installation.

## [2.3.0] - 2021-11-15
* [DCAEGEN2-2983] Update Docker base image to node.js 16.x (the latest LTS release).
* [DCAEGEN2-2958] Make sure all logging is directed to stdout/stderr. Enhance logging:
   * Add a timestamp to every log entry.
   * Make a log entry when the application starts.
   * Make a single log entry (instead of 2) for each outbound k8s API call.
