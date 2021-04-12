# Change Log
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](http://keepachangelog.com/)
and this project adheres to [Semantic Versioning](http://semver.org/).

## [4.5.0] - 12/04/2021 
* Upgrade k8s-plugin to 3.9.0 (Add a configuration of certificates for communication between 
 external-tls init container and CertService API)

## [4.4.2] - 12/03/2021 
* Upgrade k8s-plugin to 3.8.0 (Switch to policy-lib 2.5.1 to fix base64 encoding issue during policy 
 configuration fetch)

## [4.4.1] - 09/03/2021 
* Upgrade k8s-plugin to 3.7.0 (Switch to py3 version of policy-lib 2.5.0)

## [4.4.0] - 26/02/2021 
* Upgrade k8s-plugin to 3.6.0 (Add integration with cert-manager. Enable creation of certificate custom resource
 instead cert-service-client container, when flag "CMPv2CertManagerIntegration" is enabled)

## [4.3.1] - 18/02/2021 
* Upgrade k8s-plugin to 3.5.3 (Fix bug with default mode format in ConfigMapVolumeSource)

## [4.3.0] - 12/02/2021 
* Upgrade k8s-plugin to 3.5.2

## [4.2.0] - 05/02/2021      
