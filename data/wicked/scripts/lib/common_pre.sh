#!/bin/bash

# permit to override above variables
config="${0//.sh/.conf}"
up_config=$(dirname "$config")/../$(basename "$config")
test -r "$up_config" && . "$up_config"
test -r "$config" && . "$config"


